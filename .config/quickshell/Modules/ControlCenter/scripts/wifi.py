#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import re
import subprocess
import os
import tempfile
from concurrent.futures import ThreadPoolExecutor

UUID_RE = re.compile(r"[0-9a-fA-F-]{36}")
WIFI_TYPES = ("802-11-wireless", "wifi")
PSK_MGMT = ("wpa-psk", "sae", "wpa-psk sae", "sae wpa-psk")


def _read_stdin_secret():
    """Read a secret supplied on stdin. Never taken from argv."""
    try:
        return sys.stdin.read().rstrip("\r\n")
    except Exception:
        return ""


def store_psk_dbus(profile_uuid, password):
    """Store a Wi-Fi PSK in the NetworkManager profile over D-Bus.

    Secrets sent via nmcli's argv land in world-readable /proc/<pid>/cmdline
    for the lifetime of the call, so storage goes over the private system
    bus instead. Falls back to nmcli's argv path when D-Bus/NM is unusable.
    """
    try:
        import dbus
    except ImportError:
        return False, "dbus-python is unavailable"
    try:
        bus = dbus.SystemBus()
        settings = dbus.Interface(
            bus.get_object(
                "org.freedesktop.NetworkManager",
                "/org/freedesktop/NetworkManager/Settings",
            ),
            "org.freedesktop.NetworkManager.Settings",
        )
        path = settings.GetConnectionByUuid(profile_uuid)
        conn = dbus.Interface(
            bus.get_object("org.freedesktop.NetworkManager", path),
            "org.freedesktop.NetworkManager.Settings.Connection",
        )
        current = dict(conn.GetSettings())
        wsec = dict(current.get("802-11-wireless-security", {}))
        wsec["psk"] = dbus.String(password)
        wsec["psk-flags"] = dbus.UInt32(0)
        current["802-11-wireless-security"] = dbus.Dictionary(wsec, signature="sv")
        conn.Update(current)
        return True, ""
    except Exception as exc:
        return False, str(exc)


def add_connection_dbus(ssid, password):
    """Create a WPA-PSK profile over D-Bus (secret stays off argv).

    Returns (uuid, error). uuid is None when the D-Bus path is unusable.
    """
    try:
        import dbus
    except ImportError:
        return None, "dbus-python is unavailable"
    try:
        bus = dbus.SystemBus()
        settings = dbus.Interface(
            bus.get_object(
                "org.freedesktop.NetworkManager",
                "/org/freedesktop/NetworkManager/Settings",
            ),
            "org.freedesktop.NetworkManager.Settings",
        )
        path = settings.AddConnection(
            {
                "connection": dbus.Dictionary(
                    {
                        "type": dbus.String("802-11-wireless"),
                        "id": dbus.String(ssid),
                    },
                    signature="sv",
                ),
                "802-11-wireless": dbus.Dictionary(
                    {
                        "ssid": dbus.ByteArray(ssid.encode("utf-8")),
                        "mode": dbus.String("infrastructure"),
                    },
                    signature="sv",
                ),
                "802-11-wireless-security": dbus.Dictionary(
                    {
                        "key-mgmt": dbus.String("wpa-psk"),
                        "psk": dbus.String(password),
                        "psk-flags": dbus.UInt32(0),
                    },
                    signature="sv",
                ),
                "ipv4": dbus.Dictionary({"method": dbus.String("auto")}, signature="sv"),
                "ipv6": dbus.Dictionary({"method": dbus.String("auto")}, signature="sv"),
            }
        )
        conn = dbus.Interface(
            bus.get_object("org.freedesktop.NetworkManager", path),
            "org.freedesktop.NetworkManager.Settings.Connection",
        )
        return str(conn.GetSettings()["connection"]["uuid"]), ""
    except Exception as exc:
        return None, str(exc)


# ---------------------------------------------------------------- helpers


def run(args, timeout=8):
    """Run a command with a bounded timeout; never raises."""
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(
            args, 124, "", f"NetworkManager operation timed out after {timeout} seconds."
        )
    except OSError as exc:
        return subprocess.CompletedProcess(args, 127, "", str(exc))


def emit(obj):
    print(json.dumps(obj), flush=True)


def split_nmcli_fields(line):
    """Split nmcli terse output while respecting escaped colons/backslashes."""
    fields, current = [], []
    escaped = False
    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(char)
    if escaped:
        current.append("\\")
    fields.append("".join(current))
    return fields


def unescape(value):
    return value.replace("\\:", ":").replace("\\\\", "\\")


# --------------------------------------------------------- saved profiles


def _profile_details(item):
    profile_uuid, profile_name = item
    res = run(
        [
            "nmcli", "-g",
            "802-11-wireless.ssid,802-11-wireless-security.key-mgmt",
            "connection", "show", "uuid", profile_uuid,
        ],
        timeout=5,
    )
    lines = res.stdout.split("\n") if res.returncode == 0 else []
    ssid = unescape(lines[0]).strip() if len(lines) > 0 else ""
    key_mgmt = lines[1].strip().lower() if len(lines) > 1 else ""
    ssid = ssid or profile_name
    can_change_password = key_mgmt in PSK_MGMT

    # Inspect the secret internally; never include its value in JSON output.
    has_password = False
    if can_change_password:
        secret_result = run(
            [
                "nmcli", "--show-secrets", "-g",
                "802-11-wireless-security.psk",
                "connection", "show", "uuid", profile_uuid,
            ],
            timeout=5,
        )
        secret = (
            secret_result.stdout.strip()
            if secret_result.returncode == 0 else ""
        )
        has_password = bool(secret and secret != "--")

    return {
        "ssid": ssid,
        "profile_name": profile_name or ssid,
        "profile_uuid": profile_uuid,
        "can_change_password": can_change_password,
        "key_mgmt": key_mgmt,
        "has_password": has_password,
    }


def get_saved_wifi_profiles():
    """Saved wireless profiles, independent of what's in range."""
    res = run(["nmcli", "-t", "-f", "UUID,TYPE,NAME", "connection", "show"])
    if res.returncode != 0:
        return []

    items = []
    for line in res.stdout.splitlines():
        if not line:
            continue
        f = split_nmcli_fields(line)
        if len(f) < 3:
            continue
        if f[1].strip() in WIFI_TYPES and f[0].strip():
            items.append((f[0].strip(), f[2].strip()))

    if not items:
        return []
    with ThreadPoolExecutor(max_workers=8) as pool:
        return list(pool.map(_profile_details, items))


def saved_by_ssid():
    """Map SSIDs to profiles, preferring a profile with a stored PSK."""
    out = {}
    for profile in get_saved_wifi_profiles():
        ssid = profile["ssid"]
        current = out.get(ssid)
        if current is None or (
            profile["has_password"] and not current["has_password"]
        ):
            out[ssid] = profile
    return out


# ------------------------------------------------------------ device/status


def get_wifi_device():
    res = run(["nmcli", "-t", "-f", "DEVICE,TYPE", "device"], timeout=5)
    for line in res.stdout.splitlines():
        f = split_nmcli_fields(line)
        if len(f) >= 2 and f[1] == "wifi":
            return f[0]
    return None


def _is_connected_state(state):
    state = (state or "").strip().lower()
    return state == "connected" or state.startswith("connected (")


def _looks_like_vpn(device, device_type, connection):
    """Identify active tunnel/VPN devices without mistaking Proton's kill switch for a tunnel."""
    values = [str(x or "").strip().lower() for x in (device, device_type, connection)]
    joined = " ".join(values)
    if "killswitch" in joined or "kill-switch" in joined or "kill switch" in joined:
        return False
    if values[1] in ("vpn", "wireguard", "tun", "tap"):
        return True
    if values[0].startswith(("proton", "wg", "tun", "tap", "vpn")):
        return True
    return any(token in joined for token in ("proton vpn", "protonvpn", "openvpn", "wireguard", "private internet access"))


def get_status():
    """Return independent Wi-Fi, Ethernet, and VPN status from NetworkManager."""
    radio = run(["nmcli", "radio", "wifi"], timeout=5).stdout.strip() == "enabled"
    connected_ssid = "Disconnected"
    wifi_connection = ""
    wifi_device = ""
    wifi_connected = False
    ethernet_connection = ""
    ethernet_device = ""
    ethernet_connected = False
    vpn_connection = ""
    vpn_device = ""
    vpn_active = False

    # A single NetworkManager device query feeds both the Wi-Fi tile and the
    # compact network overview. The overview remains useful when Wi-Fi is off.
    res = run(
        ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"],
        timeout=5,
    )
    if res.returncode == 0:
        candidates = []
        for line in res.stdout.splitlines():
            if not line:
                continue
            fields = split_nmcli_fields(line)
            if len(fields) < 4:
                continue

            device, device_type, state, connection = [part.strip() for part in fields[:4]]
            if not _is_connected_state(state):
                continue

            normalized_type = device_type.lower()
            if normalized_type in ("wifi", "802-11-wireless"):
                if not wifi_connected:
                    wifi_connected = True
                    wifi_connection = connection
                    wifi_device = device
                    connected_ssid = connection or "Connected"
            elif normalized_type in ("ethernet", "802-3-ethernet"):
                if not ethernet_connected:
                    ethernet_connected = True
                    ethernet_connection = connection
                    ethernet_device = device

            if _looks_like_vpn(device, device_type, connection):
                # Prefer the actual tunnel (for example proton0) over a
                # companion/kill-switch device if NetworkManager lists both.
                candidate = {
                    "device": device,
                    "connection": connection or device,
                    "priority": 0 if normalized_type in ("vpn", "wireguard", "tun", "tap") else 1,
                }
                candidates.append(candidate)

        if candidates:
            selected = sorted(candidates, key=lambda item: item["priority"])[0]
            vpn_active = True
            vpn_device = selected["device"]
            vpn_connection = selected["connection"]

    # Some NetworkManager plugins expose VPN active profiles more clearly in
    # `connection show --active` than in the device table. Use it only as a
    # fallback; this does not execute or alter any connection.
    if not vpn_active:
        active = run(
            ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"],
            timeout=5,
        )
        if active.returncode == 0:
            for line in active.stdout.splitlines():
                fields = split_nmcli_fields(line)
                if len(fields) < 3:
                    continue
                name, connection_type, device = [part.strip() for part in fields[:3]]
                if _looks_like_vpn(device, connection_type, name):
                    vpn_active = True
                    vpn_connection = name or device
                    vpn_device = device
                    break

    return {
        "radio": radio,
        "connected_ssid": connected_ssid,
        "wifi_connected": wifi_connected,
        "wifi_connection": wifi_connection,
        "wifi_device": wifi_device,
        "ethernet_connected": ethernet_connected,
        "ethernet_connection": ethernet_connection,
        "ethernet_device": ethernet_device,
        "vpn_active": vpn_active,
        "vpn_connection": vpn_connection,
        "vpn_device": vpn_device,
    }


# --------------------------------------------------------------------- scan


def list_networks(rescan, saved):
    """Returns a sorted list, or None if nmcli failed (so callers keep old data)."""
    cmd = [
        "nmcli", "-t", "-f", "SSID,SIGNAL,IN-USE,SECURITY",
        "device", "wifi", "list", "--rescan", "yes" if rescan else "no",
    ]
    res = run(cmd, timeout=15 if rescan else 8)
    if res.returncode != 0:
        return None

    networks, seen = [], {}
    for line in res.stdout.splitlines():
        if not line:
            continue
        f = split_nmcli_fields(line)
        if len(f) < 4:
            continue
        ssid = f[0].strip()
        if not ssid:
            continue
        try:
            signal = int(f[1])
        except ValueError:
            signal = 0
        in_use = f[2].strip() == "*"
        security = f[3].strip()
        if security == "--":
            security = ""

        if ssid in seen:
            n = networks[seen[ssid]]
            n["signal"] = max(n["signal"], signal)
            n["active"] = n["active"] or in_use
            n["saved"] = n["saved"] or in_use
            continue

        seen[ssid] = len(networks)
        profile = saved.get(ssid, {})
        networks.append(
            {
                "ssid": ssid,
                "signal": signal,
                "active": in_use,
                "saved": in_use or bool(profile),
                "security": security,
                "profile_uuid": profile.get("profile_uuid", ""),
                "can_change_password": profile.get(
                    "can_change_password", False
                ),
                "has_password": profile.get("has_password", False),
            }
        )

    networks.sort(
        key=lambda x: (not x["active"], not x["saved"], -x["signal"], x["ssid"].lower())
    )
    return networks


def scan(rescan):
    """Print cached results immediately, then fresh ones if a rescan was asked.

    Each result is one JSON line; the QML SplitParser replaces the list per line.
    A failed scan prints nothing, so the previous list stays on screen.
    """
    saved = saved_by_ssid()
    cached = list_networks(False, saved)
    if cached is not None:
        emit(cached)
    if rescan:
        fresh = list_networks(True, saved)
        if fresh is not None:
            emit(fresh)


# ------------------------------------------------------------------ connect


def connect(ssid, password=None):
    profiles = get_saved_wifi_profiles()
    before = {p["profile_uuid"] for p in profiles}

    matches = [p for p in profiles if p["ssid"] == ssid]
    matches.sort(key=lambda p: (
        not p.get("can_change_password", False),
        p.get("profile_name") != ssid,
    ))
    match = matches[0] if matches else None

    success = False
    output = ""

    if password and "\n" in password or password and "\r" in password:
        emit({
            "success": False,
            "output": "A Wi-Fi password cannot contain a newline.",
        })
        return

    if match and password and match.get("can_change_password"):
        # Supply the typed secret just for this activation. Do not overwrite
        # the existing saved password unless NetworkManager connects.
        secret_path = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8",
                prefix="quickshell-wifi-", delete=False,
            ) as secret_file:
                secret_path = secret_file.name
                os.chmod(secret_path, 0o600)
                secret_file.write(
                    "802-11-wireless-security.psk:" + password + "\n"
                )

            res = run([
                "nmcli", "connection", "up",
                "uuid", match["profile_uuid"],
                "passwd-file", secret_path,
            ], timeout=45)
        except OSError as exc:
            res = subprocess.CompletedProcess(
                ["nmcli", "connection", "up"], 1, "",
                f"Could not prepare a private password file: {exc}",
            )
        finally:
            if secret_path:
                try:
                    os.unlink(secret_path)
                except OSError:
                    pass

        if res.returncode == 0:
            # Persist the accepted password only after successful activation.
            saved_ok, saved_err = store_psk_dbus(match["profile_uuid"], password)
            if not saved_ok:
                print(
                    f"wifi.py: D-Bus secret store failed ({saved_err}); "
                    "falling back to nmcli argv.",
                    file=sys.stderr,
                )
                saved = run([
                    "nmcli", "connection", "modify",
                    "uuid", match["profile_uuid"],
                    "802-11-wireless-security.psk", password,
                    "802-11-wireless-security.psk-flags", "0",
                ], timeout=10)
                saved_ok = saved.returncode == 0

            success = True
            output = "Connected successfully."
            if not saved_ok:
                output = (
                    "Connected, but NetworkManager could not save the new "
                    "password. You may need to save it again."
                )
        else:
            output = res.stderr.strip() or res.stdout.strip()
            output = (
                "Connection failed. The password may be incorrect. "
                "Please try again."
                + (f"\nDetails: {output}" if output else "")
            )

    elif match and not password:
        res = run([
            "nmcli", "connection", "up",
            "uuid", match["profile_uuid"],
        ], timeout=45)
        success = res.returncode == 0
        output = res.stdout.strip() or res.stderr.strip()

    else:
        if password:
            new_uuid, dbus_err = add_connection_dbus(ssid, password)
            if new_uuid:
                res = run([
                    "nmcli", "connection", "up", "uuid", new_uuid,
                ], timeout=45)
            else:
                print(
                    f"wifi.py: D-Bus profile creation failed ({dbus_err}); "
                    "falling back to nmcli argv.",
                    file=sys.stderr,
                )
                res = run(
                    ["nmcli", "device", "wifi", "connect", ssid,
                     "password", password],
                    timeout=45,
                )
        else:
            res = run(["nmcli", "device", "wifi", "connect", ssid], timeout=45)
        success = res.returncode == 0
        output = res.stdout.strip() or res.stderr.strip()

    # Clean up only newly-created profiles after failed first-time attempts.
    if not success and not match:
        for profile in get_saved_wifi_profiles():
            if profile["profile_uuid"] not in before:
                run([
                    "nmcli", "connection", "delete",
                    "uuid", profile["profile_uuid"],
                ], timeout=8)

    emit({"success": success, "output": output or (
        "Connected successfully." if success else "Could not connect."
    )})

# --------------------------------------------------------- password / forget



def get_password(profile_uuid):
    """Reveal a stored WPA-Personal secret only on explicit request."""
    if not UUID_RE.fullmatch(profile_uuid):
        emit({"success": False, "output": "Invalid saved profile ID."})
        return

    profile = next(
        (p for p in get_saved_wifi_profiles()
         if p["profile_uuid"] == profile_uuid),
        None,
    )
    if not profile:
        emit({"success": False, "output": "Saved profile not found."})
        return

    if not profile["can_change_password"]:
        emit({
            "success": False,
            "output": "This profile does not use a supported personal Wi-Fi password.",
        })
        return

    result = run([
        "nmcli", "--show-secrets", "-g",
        "802-11-wireless-security.psk",
        "connection", "show", "uuid", profile_uuid,
    ], timeout=8)

    password = result.stdout.rstrip("\r\n")
    if result.returncode != 0 or not password or password == "--":
        emit({
            "success": False,
            "output": "No password is stored in this profile.",
        })
        return

    # This value is emitted only when the user explicitly requests Show.
    emit({"success": True, "password": password})


def set_password(profile_uuid, password):
    if not UUID_RE.fullmatch(profile_uuid):
        emit({"success": False, "output": "Invalid saved profile ID."})
        return

    profile = next(
        (p for p in get_saved_wifi_profiles() if p["profile_uuid"] == profile_uuid),
        None,
    )
    if not profile:
        emit({"success": False, "output": "Saved profile not found."})
    elif not profile["can_change_password"]:
        emit({"success": False, "output": "Use NetworkManager settings to edit this security type."})
    elif not password:
        emit({"success": False, "output": "Enter a new password first."})
    else:
        saved_ok, dbus_err = store_psk_dbus(profile_uuid, password)
        if saved_ok:
            success, output = True, ""
        else:
            print(
                f"wifi.py: D-Bus secret store failed ({dbus_err}); "
                "falling back to nmcli argv.",
                file=sys.stderr,
            )
            result = run(
                [
                    "nmcli", "connection", "modify", "uuid", profile_uuid,
                    "802-11-wireless-security.psk", password,
                    "802-11-wireless-security.psk-flags", "0",
                ],
                timeout=10,
            )
            success = result.returncode == 0
            output = result.stdout.strip() or result.stderr.strip()
        emit(
            {
                "success": success,
                "output": output
                or ("Password saved. Reconnect to use it." if success else "Could not save the new password."),
            }
        )


def forget(target):
    if target.startswith("uuid:"):
        candidate = target[5:]
        if not UUID_RE.fullmatch(candidate):
            emit({"success": False, "output": "Invalid saved profile ID."})
            return
        profile_uuid = candidate
    else:
        profiles = get_saved_wifi_profiles()
        matches = [p for p in profiles if p["profile_name"] == target] or [
            p for p in profiles if p["ssid"] == target
        ]
        if len(matches) == 1:
            profile_uuid = matches[0]["profile_uuid"]
        elif len(matches) > 1:
            emit({"success": False, "output": "Multiple saved profiles match. Select the exact profile."})
            return
        else:
            emit({"success": False, "output": "Saved Wi-Fi profile not found."})
            return

    result = run(["nmcli", "connection", "delete", "uuid", profile_uuid], timeout=10)
    success = result.returncode == 0
    output = result.stdout.strip() or result.stderr.strip()
    emit(
        {
            "success": success,
            "output": output
            or ("Saved network removed." if success else "NetworkManager could not remove this profile."),
        }
    )


# --------------------------------------------------------------------- main


def main():
    argv = sys.argv[1:]
    action = argv[0] if argv else "scan"

    if action == "status":
        emit(get_status())
    elif action == "saved":
        emit(get_saved_wifi_profiles())
    elif action == "scan":
        scan(argv[1] != "no" if len(argv) > 1 else True)
    elif action == "toggle-radio":
        new_state = "off" if get_status()["radio"] else "on"
        run(["nmcli", "radio", "wifi", new_state])
        emit({"radio": new_state == "on"})
    elif action == "connect" and len(argv) > 1:
        if len(argv) > 2 and argv[2] == "--stdin":
            password = _read_stdin_secret() or None
        else:
            password = argv[2] if len(argv) > 2 else None
        connect(argv[1], password)
    elif action == "get-password" and len(argv) > 1:
        get_password(argv[1])
    elif action == "set-password" and len(argv) > 1:
        if len(argv) > 2 and argv[2] == "--stdin":
            password = _read_stdin_secret()
        else:
            password = argv[2] if len(argv) > 2 else ""
        set_password(argv[1], password)
    elif action == "disconnect":
        dev = get_wifi_device()
        if dev:
            run(["nmcli", "device", "disconnect", dev])
        elif len(argv) > 1:
            run(["nmcli", "connection", "down", "id", argv[1]])
        emit({"success": True})
    elif action == "forget" and len(argv) > 1:
        forget(argv[1])
    else:
        scan(True)


if __name__ == "__main__":
    main()
