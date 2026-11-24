#!/usr/bin/env python3
"""Veyra hotspot bridge for linux-wifi-hotspot/create_ap.

The existing NetworkManager hotspot profile remains the local settings store,
but create_ap handles AP creation/removal. Credentials are sent over stdin so
they are not placed in the privileged command's argv.
"""
import sys
sys.dont_write_bytecode = True

import glob
import json
import os
import re
import shutil
import signal
import subprocess
import time
from pathlib import Path


class Fail:
    returncode = 1
    stdout = ""
    stderr = "command failed"


def run(cmd, timeout=10, input_text=None):
    try:
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            input=input_text,
            env={**os.environ, "LC_ALL": "C"},
        )
    except Exception as e:
        f = Fail()
        f.stderr = str(e)
        return f


def config_dir():
    return Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config")) / "quickshell"


def prefs_path():
    return config_dir() / "hotspot_backend.json"


def example_prefs_paths():
    return [
        config_dir() / "hotspot_backend.json.example",
        Path(__file__).resolve().parents[3] / "hotspot_backend.json.example",
    ]


DEFAULT_PROFILE = "VeyraHotspot"


def read_prefs():
    candidates = [prefs_path(), *example_prefs_paths()]
    for candidate in candidates:
        if not candidate.is_file():
            continue
        try:
            data = json.loads(candidate.read_text(encoding="utf-8"))
            return data if isinstance(data, dict) else {}
        except Exception:
            continue
    return {}


def preferred_profile():
    profile = read_prefs().get("hotspotProfile")
    if isinstance(profile, str) and profile.strip():
        return profile.strip()
    return DEFAULT_PROFILE


def write_prefs(data):
    path = prefs_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + f".{os.getpid()}.tmp")
    fd = os.open(str(tmp), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
        os.chmod(path, 0o600)
    finally:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass


def nm_get(profile, field, secrets=False):
    cmd = ["nmcli"]
    if secrets:
        cmd.append("-s")
    cmd += ["-g", field, "connection", "show", profile]
    res = run(cmd)
    return res.stdout.strip().replace("\\:", ":") if res.returncode == 0 else ""


def is_active(profile):
    if not profile or not shutil.which("nmcli"):
        return False
    out = run(["nmcli", "-t", "-f", "NAME", "connection", "show", "--active"]).stdout
    names = [line.replace("\\:", ":") for line in out.splitlines()]
    return profile in names


def create_ap_path():
    return shutil.which("create_ap")


def pkexec_path():
    return shutil.which("pkexec")


def backend_available():
    return bool(create_ap_path() and pkexec_path())


def backend_message():
    if not create_ap_path():
        return "Install linux-wifi-hotspot first (AUR package)."
    if not pkexec_path():
        return "pkexec is missing. Install polkit and make sure a graphical Polkit agent is running."
    return ""


def network_interfaces():
    try:
        return sorted(n for n in os.listdir("/sys/class/net") if n and n != "lo")
    except Exception:
        return []


def wifi_interfaces():
    found = []
    if shutil.which("nmcli"):
        res = run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"], timeout=5)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                parts = line.split(":")
                if len(parts) >= 3 and parts[1] == "wifi" and parts[0] not in found:
                    found.append(parts[0])
    if not found and shutil.which("iw"):
        res = run(["iw", "dev"], timeout=4)
        for line in res.stdout.splitlines():
            m = re.match(r"\s*Interface\s+(\S+)\s*$", line)
            if m and m.group(1) not in found:
                found.append(m.group(1))
    return found


def default_wifi_interface():
    devices = wifi_interfaces()
    if not devices:
        return ""
    if shutil.which("nmcli"):
        res = run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"], timeout=5)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                parts = line.split(":")
                if len(parts) >= 3 and parts[1] == "wifi" and parts[2].startswith("connected"):
                    if parts[0] in devices:
                        return parts[0]
    # Prefer a managed Wi-Fi interface to the virtual AP interface, if iw can tell us.
    if shutil.which("iw"):
        res = run(["iw", "dev"], timeout=4)
        current = ""
        modes = {}
        for line in res.stdout.splitlines():
            m = re.match(r"\s*Interface\s+(\S+)\s*$", line)
            if m:
                current = m.group(1)
                modes.setdefault(current, "")
            elif current:
                m = re.match(r"\s*type\s+(\S+)\s*$", line)
                if m:
                    modes[current] = m.group(1)
        for name in devices:
            if modes.get(name) != "AP":
                return name
    return devices[0]


def default_internet_interface():
    if shutil.which("ip"):
        res = run(["ip", "route", "get", "1.1.1.1"], timeout=4)
        if res.returncode == 0:
            m = re.search(r"\bdev\s+(\S+)", res.stdout)
            if m and m.group(1) != "lo":
                return m.group(1)
        res = run(["ip", "-o", "route", "show", "default"], timeout=4)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                m = re.search(r"\bdev\s+(\S+)", line)
                if m and m.group(1) != "lo":
                    return m.group(1)
    return ""


VPN_INTERFACE_RE = re.compile(
    r"^(?:proton\d*|pvpn[a-z0-9_-]*|tun\d*|wg\d*|wgcf\d*|nordlynx|mullvad[a-z0-9_-]*|warp[a-z0-9_-]*|vpn\d*)$",
    re.IGNORECASE,
)


def vpn_interface():
    """Return a likely active VPN tunnel interface, preferring the current route."""
    interfaces = network_interfaces()
    candidates = [name for name in interfaces if VPN_INTERFACE_RE.match(name)]
    if not candidates:
        return ""

    # When NetworkManager knows a VPN device, require it to be connected. This
    # avoids offering a stale Proton interface after the VPN was disconnected.
    nm_states = {}
    if shutil.which("nmcli"):
        res = run(["nmcli", "-t", "-f", "DEVICE,STATE", "device", "status"], timeout=5)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                parts = line.split(":", 1)
                if len(parts) == 2:
                    nm_states[parts[0]] = parts[1].strip().lower()
    nm_known = [name for name in candidates if name in nm_states]
    if nm_known:
        candidates = [name for name in candidates if name not in nm_states or nm_states[name].startswith("connected")]
        if not candidates:
            return ""

    current_route = default_internet_interface()
    if current_route in candidates:
        return current_route

    # Prefer Proton's interface for this setup, then familiar Linux tunnel names.
    priorities = ["proton0", "pvpn0", "nordlynx", "tun0", "wg0", "mullvad0", "warp0"]
    for name in priorities:
        if name in candidates:
            return name

    # For interfaces not managed by NetworkManager, require the link to be UP.
    if shutil.which("ip"):
        for name in candidates:
            if name in nm_states:
                continue
            link = run(["ip", "-o", "link", "show", "dev", name], timeout=4)
            if link.returncode == 0 and re.search(r"<[^>]*\bUP\b", link.stdout):
                return name
    return ""


def ufw_route_rule_sync(internet_iface):
    """Update the one Veyra hotspot forwarding route in a single Polkit call.

    The actual privileged work is performed by a root-owned, narrowly scoped
    helper installed under /usr/local/libexec. Calling pkexec once avoids the
    rapid sequence of separate authorization dialogs that made the GUI prompt
    disappear on some sessions.
    """
    if not shutil.which("ufw"):
        return True, "UFW is not installed; no UFW route rule was changed."

    pkexec = pkexec_path()
    helper = Path("/usr/local/libexec/veyra-hotspot-ufw-route")
    if not pkexec:
        return False, "pkexec is unavailable, so the UFW hotspot route could not be updated."
    if not helper.is_file() or not os.access(helper, os.X_OK):
        return False, "The Veyra UFW routing helper is not installed. Install the optional privileged helper using the project instructions, or disable UFW route synchronization."

    target = internet_iface or "NONE"
    result = run([pkexec, str(helper), "set-egress", target], timeout=90)
    details = (result.stderr or result.stdout or "").strip()
    if result.returncode != 0:
        if result.returncode in (126, 127):
            return False, "Polkit authorization did not complete; the existing UFW route was left unchanged. Try again, or report if the password dialog still closes. " + details
        return False, "Could not update the UFW hotspot route; the existing rule was left unchanged. " + details
    return True, details or ("UFW hotspot forwarding is restricted to " + (internet_iface or "No Internet") + ".")


def running_instances():
    """Inspect create_ap's documented world-readable /tmp pid/interface markers.

    create_ap's current upstream script checks for root even for --list-running,
    so do not run that status command as an unprivileged UI user.
    """
    result = []
    for path in glob.glob("/tmp/create_ap.*.conf.*"):
        if not os.path.isdir(path):
            continue
        base = os.path.basename(path)
        m = re.match(r"^create_ap\.(.+)\.conf\.[^/]+$", base)
        if not m:
            continue
        physical = m.group(1)
        try:
            pid_text = Path(path, "pid").read_text(encoding="utf-8").strip()
            pid = int(pid_text)
            if pid <= 1 or not Path(f"/proc/{pid}").exists():
                continue
            try:
                ap_iface = Path(path, "wifi_iface").read_text(encoding="utf-8").strip() or physical
            except Exception:
                ap_iface = physical
            result.append({"pid": pid, "physical": physical, "ap": ap_iface, "confdir": path})
        except Exception:
            continue
    # Deduplicate stale globs around one live pid and return newest first.
    unique = {}
    for item in result:
        unique[item["pid"]] = item
    return sorted(unique.values(), key=lambda item: os.path.getmtime(item["confdir"]), reverse=True)


def choose_instance(instances, preferred_wifi=""):
    if preferred_wifi:
        for item in instances:
            if item["physical"] == preferred_wifi or item["ap"] == preferred_wifi:
                return item
    return instances[0] if instances else None


def selected_interfaces():
    prefs = read_prefs()
    wifis = wifi_interfaces()
    default_wifi = default_wifi_interface()
    wifi = prefs.get("wifiInterface", "")
    if wifi not in wifis:
        wifi = default_wifi
    internet = prefs.get("internetInterface", "AUTO")
    if internet not in ("AUTO", "NONE") and internet not in network_interfaces():
        internet = "AUTO"
    resolved_internet = default_internet_interface() if internet == "AUTO" else ("" if internet == "NONE" else internet)
    return wifis, wifi, internet, resolved_internet


def interface_summary(wifi="", internet=""):
    if not wifi:
        wifi = default_wifi_interface()
    if internet is None:
        internet = default_internet_interface()
    if internet == "AUTO":
        internet = default_internet_interface()
    if internet == "NONE":
        return f"Wi-Fi: {wifi or 'not detected'} · no Internet sharing"
    if not internet:
        return f"Wi-Fi: {wifi or 'not detected'} · no default Internet route"
    route_note = " (current default route; includes VPN if routed there)" if internet == default_internet_interface() else ""
    return f"Wi-Fi: {wifi or 'not detected'} · Internet: {internet}{route_note}"


def interface_options():
    wifis, selected_wifi, selected_internet, resolved_internet = selected_interfaces()
    adapters = network_interfaces()
    internet_options = ["AUTO", "NONE", *adapters]
    internet_labels = {
        "AUTO": "Automatic (default route)",
        "NONE": "No Internet sharing",
    }
    print(json.dumps({
        "wifi": wifis,
        "selectedWifi": selected_wifi,
        "defaultWifi": default_wifi_interface(),
        "internet": internet_options,
        "internetLabels": internet_labels,
        "selectedInternet": selected_internet,
        "defaultInternet": default_internet_interface(),
        "vpnInterface": vpn_interface(),
        "backendAvailable": backend_available(),
        "message": backend_message(),
        "interfaceSummary": interface_summary(selected_wifi, selected_internet if selected_internet == "NONE" else resolved_internet),
    }, ensure_ascii=False))


def save_interfaces(wifi, internet):
    available_wifi = wifi_interfaces()
    if wifi and wifi not in available_wifi:
        print(json.dumps({"success": False, "message": "Selected Wi-Fi adapter is no longer available."}))
        return
    available_net = network_interfaces()
    if internet not in ("AUTO", "NONE") and internet not in available_net:
        print(json.dumps({"success": False, "message": "Selected Internet interface is no longer available."}))
        return

    resolved_internet = default_internet_interface() if internet == "AUTO" else ("" if internet == "NONE" else internet)
    prefs = read_prefs()
    old_choice = prefs.get("internetInterface", "AUTO")
    old_resolved = default_internet_interface() if old_choice == "AUTO" else ("" if old_choice == "NONE" else old_choice)
    target_key = resolved_internet or "NONE"

    # The previous version did not store the last applied UFW egress. In that
    # case, trust its saved source when the resolved interface is unchanged;
    # this avoids prompting on purely cosmetic/unchanged selections.
    last_egress = prefs.get("ufwEgress")
    if last_egress is not None:
        needs_route_update = last_egress != target_key
    else:
        needs_route_update = old_resolved != resolved_internet

    firewall_message = ""
    if needs_route_update:
        ok, firewall_message = ufw_route_rule_sync(resolved_internet)
        if not ok:
            print(json.dumps({"success": False, "message": firewall_message}, ensure_ascii=False))
            return

    if wifi:
        prefs["wifiInterface"] = wifi
    else:
        prefs.pop("wifiInterface", None)
    prefs["internetInterface"] = internet or "AUTO"
    prefs["ufwEgress"] = target_key
    write_prefs(prefs)

    message = "Interface choices saved. "
    if firewall_message:
        message += firewall_message
    else:
        message += "No firewall change was needed; the existing route already matches this source."
    if running_instances():
        message = "Interface choices saved. Turn the hotspot off and on to apply them. " + (firewall_message or "The current route already matches this source.")
    print(json.dumps({"success": True, "message": message}, ensure_ascii=False))


def status(profile=None):
    profile = profile or preferred_profile()
    instances = running_instances()
    prefs = read_prefs()
    selected_wifi = prefs.get("wifiInterface") or default_wifi_interface()
    active_instance = choose_instance(instances, selected_wifi)
    available = backend_available()
    message = backend_message()
    backend = "linux-wifi-hotspot" if active_instance else ("NetworkManager" if is_active(profile) else "linux-wifi-hotspot")
    active = bool(active_instance) or is_active(profile)
    if active_instance:
        selected_wifi = active_instance["physical"]
        internet_pref = prefs.get("internetInterface", "AUTO")
        resolved_internet = default_internet_interface() if internet_pref == "AUTO" else ("" if internet_pref == "NONE" else internet_pref)
        summary = interface_summary(selected_wifi, "NONE" if internet_pref == "NONE" else resolved_internet)
    else:
        wifis, selected_wifi, selected_internet, resolved_internet = selected_interfaces()
        summary = interface_summary(selected_wifi, selected_internet if selected_internet == "NONE" else resolved_internet)
        if active and not active_instance:
            message = "The old NetworkManager hotspot is active. Turn it off first, or press the tile to stop it before starting linux-wifi-hotspot."
    print(json.dumps({
        "success": True,
        "active": active,
        "backend": backend,
        "backendAvailable": available,
        "profile": profile,
        "message": message,
        "interfaceSummary": summary,
        "wifiInterface": selected_wifi,
        "internetInterface": resolved_internet if active_instance else selected_interfaces()[3],
    }, ensure_ascii=False))


def info(profile=None):
    profile = profile or preferred_profile()
    instances = running_instances()
    wifis, preferred_wifi, preferred_internet, resolved_internet = selected_interfaces()
    active_instance = choose_instance(instances, preferred_wifi)
    wifi = active_instance["physical"] if active_instance else preferred_wifi
    summary_internet = "NONE" if preferred_internet == "NONE" else resolved_internet
    print(json.dumps({
        "ssid": nm_get(profile, "802-11-wireless.ssid"),
        "psk": nm_get(profile, "802-11-wireless-security.psk", True),
        "active": bool(active_instance) or is_active(profile),
        "backendAvailable": backend_available(),
        "profile": profile,
        "vpnInterface": vpn_interface(),
        "backend": "linux-wifi-hotspot" if active_instance else "NetworkManager",
        "message": backend_message(),
        "interfaceSummary": interface_summary(wifi, summary_internet),
    }, ensure_ascii=False))


def parse_station_dump(iface):
    if not iface or not shutil.which("iw"):
        return {}
    res = run(["iw", "dev", iface, "station", "dump"], timeout=5)
    stations = {}
    current = None
    for line in res.stdout.splitlines():
        match = re.match(r"Station\s+([0-9a-fA-F:]{17})", line)
        if match:
            current = match.group(1).lower()
            stations[current] = {"mac": current, "ip": "", "name": "", "signal": None}
            continue
        if current and "signal:" in line:
            signal = re.search(r"(-?\d+)\s*dBm", line)
            if signal:
                stations[current]["signal"] = int(signal.group(1))
    return stations


def lease_info(confdir):
    items = {}
    for lease_path in [Path(confdir, "dnsmasq.leases"), Path(confdir, "dnsmasq-leasefile")]:
        try:
            with lease_path.open(encoding="utf-8", errors="replace") as stream:
                for line in stream:
                    parts = line.split()
                    # dnsmasq lease format: expiry MAC IP hostname client-id
                    if len(parts) >= 4 and re.fullmatch(r"[0-9a-fA-F:]{17}", parts[1]):
                        mac = parts[1].lower()
                        items[mac] = {"ip": parts[2], "name": "" if parts[3] == "*" else parts[3]}
        except Exception:
            continue
    return items


def clients(profile=None):
    profile = profile or preferred_profile()
    instances = running_instances()
    selected_wifi = read_prefs().get("wifiInterface", "")
    active_instance = choose_instance(instances, selected_wifi)
    if active_instance:
        iface = active_instance["ap"]
        stations = parse_station_dump(iface)
        leases = lease_info(active_instance["confdir"])
        # Neighbor data can provide an address if dnsmasq has not written a lease yet.
        if shutil.which("ip"):
            neigh = run(["ip", "neigh", "show", "dev", iface], timeout=4).stdout
            for line in neigh.splitlines():
                parts = line.split()
                if len(parts) >= 3 and "lladdr" in parts:
                    ip_addr = parts[0]
                    mac = parts[parts.index("lladdr") + 1].lower()
                    if ":" not in ip_addr and mac in stations:
                        stations[mac]["ip"] = ip_addr
        for mac, info in leases.items():
            if mac in stations:
                stations[mac]["ip"] = info["ip"]
                stations[mac]["name"] = info["name"]
        print(json.dumps(sorted(stations.values(), key=lambda item: item["mac"]), ensure_ascii=False))
        return

    # Compatibility fallback while an old NetworkManager hotspot is still active.
    dev = nm_get(profile, "GENERAL.DEVICES").split(",")[0].strip()
    stations = parse_station_dump(dev)
    names = {}
    try:
        with open("/var/lib/NetworkManager/dnsmasq-%s.leases" % dev, encoding="utf-8") as stream:
            for line in stream:
                parts = line.split()
                if len(parts) >= 4:
                    names[parts[1].lower()] = "" if parts[3] == "*" else parts[3]
    except Exception:
        pass
    for mac, item in stations.items():
        item["name"] = names.get(mac, "")
    print(json.dumps(sorted(stations.values(), key=lambda item: item["mac"]), ensure_ascii=False))


def set_cfg(profile, ssid, psk):
    profile = profile or preferred_profile()
    ssid = ssid.strip()
    if not ssid or len(ssid.encode("utf-8")) > 32:
        print(json.dumps({"success": False, "message": "Name must be 1-32 UTF-8 bytes"}))
        return
    if not (8 <= len(psk) <= 63):
        print(json.dumps({"success": False, "message": "Password must be 8-63 characters"}))
        return
    r = run([
        "nmcli", "connection", "modify", profile,
        "802-11-wireless.ssid", ssid,
        "802-11-wireless-security.key-mgmt", "wpa-psk",
        "802-11-wireless-security.psk", psk,
    ])
    if r.returncode != 0:
        print(json.dumps({"success": False, "message": (r.stderr or "Could not save").strip()}))
        return
    if running_instances() or is_active(profile):
        msg = "Saved. Turn the hotspot off and on to apply the new credentials."
    else:
        msg = "Saved"
    print(json.dumps({"success": True, "message": msg}))


def hotspot_log_path():
    cache_home = Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache"))
    cache_dir = cache_home / "quickshell"
    cache_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        cache_dir.chmod(0o700)
    except OSError:
        pass
    return cache_dir / "veyra-create-ap.log"


def hotspot_log_tail(path, psk="", max_lines=18, max_chars=2200):
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    text = "\n".join(line for line in lines[-max_lines:] if line.strip())
    if psk:
        text = text.replace(psk, "••••••••")
    if len(text) > max_chars:
        text = "…" + text[-max_chars:]
    return text.strip()


def start(profile=None):
    profile = profile or preferred_profile()
    create_ap = create_ap_path()
    pkexec = pkexec_path()
    if not create_ap:
        print(json.dumps({"success": False, "active": False, "message": backend_message()}))
        return
    if not pkexec:
        print(json.dumps({"success": False, "active": False, "message": backend_message()}))
        return
    running = running_instances()
    if running:
        item = choose_instance(running, read_prefs().get("wifiInterface", ""))
        print(json.dumps({"success": False, "active": True, "message": f"A linux-wifi-hotspot instance is already active on {item['physical']}."}))
        return
    ssid = nm_get(profile, "802-11-wireless.ssid")
    psk = nm_get(profile, "802-11-wireless-security.psk", True)
    if not ssid or len(ssid.encode("utf-8")) > 32:
        print(json.dumps({"success": False, "active": False, "message": "Set a hotspot name (1-32 UTF-8 bytes) and save it first."}))
        return
    if not (8 <= len(psk) <= 63):
        print(json.dumps({"success": False, "active": False, "message": "Set a hotspot password of 8-63 characters and save it first."}))
        return
    prefs = read_prefs()
    wifi_candidates = wifi_interfaces()
    wifi = prefs.get("wifiInterface", "")
    if wifi not in wifi_candidates:
        wifi = default_wifi_interface()
    if not wifi:
        print(json.dumps({"success": False, "active": False, "message": "No Wi-Fi adapter was found. Check `iw dev` and NetworkManager."}))
        return
    internet_pref = prefs.get("internetInterface", "AUTO")
    if internet_pref == "AUTO":
        internet = default_internet_interface()
    elif internet_pref == "NONE":
        internet = ""
    else:
        internet = internet_pref if internet_pref in network_interfaces() else ""
        if not internet:
            print(json.dumps({"success": False, "active": False, "message": "The selected Internet interface disappeared. Choose another interface."}))
            return

    # UFW is synchronized when an interface selection changes. For older
    # preferences without this marker, trust the previous version's saved rule
    # rather than opening a second Polkit dialog immediately before create_ap.
    # If a marked preference has drifted, repair it now.
    saved_egress = prefs.get("ufwEgress")
    current_egress_key = internet or "NONE"
    if saved_egress is not None and saved_egress != current_egress_key:
        firewall_ok, firewall_message = ufw_route_rule_sync(internet)
        if not firewall_ok:
            print(json.dumps({"success": False, "active": False, "message": firewall_message}, ensure_ascii=False))
            return
        prefs["ufwEgress"] = current_egress_key
        write_prefs(prefs)

    # Clear a previously active NetworkManager hotspot profile before handing the
    # adapter to create_ap. Do not disconnect the normal Internet profile.
    if is_active(profile):
        legacy = run(["nmcli", "connection", "down", profile], timeout=15)
        if legacy.returncode != 0:
            print(json.dumps({"success": False, "active": True, "message": (legacy.stderr or "Could not stop the old NetworkManager hotspot.").strip()}))
            return
        time.sleep(1.0)

    # Do NOT use create_ap --daemon here. Upstream daemon mode relaunches
    # create_ap before it reads SSID/passphrase from stdin; the detached shell
    # can therefore lose these credentials. Keep create_ap in the foreground
    # and detach the whole process group from Quickshell instead.
    cmd = [pkexec, create_ap]
    if internet:
        cmd.extend([wifi, internet])
    else:
        cmd.extend(["-n", wifi])

    log_path = hotspot_log_path()
    try:
        log_fd = os.open(str(log_path), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(log_fd, "ab", buffering=0) as log_stream:
            proc = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=log_stream,
                stderr=subprocess.STDOUT,
                start_new_session=True,
                env={**os.environ, "LC_ALL": "C"},
            )
            try:
                if proc.stdin is not None:
                    proc.stdin.write(f"{ssid}\n{psk}\n".encode("utf-8"))
                    proc.stdin.close()
            except (BrokenPipeError, OSError):
                # The process may have exited early; the log below explains why.
                try:
                    if proc.stdin is not None and not proc.stdin.closed:
                        proc.stdin.close()
                except OSError:
                    pass
    except Exception as exc:
        print(json.dumps({"success": False, "active": False,
                          "message": f"Could not launch create_ap: {exc}"}, ensure_ascii=False))
        return

    # create_ap stays in the foreground, so its pid/config markers and log stay
    # valid until the user stops the hotspot. Wait for hostapd's AP-ENABLED line
    # rather than treating the early marker as proof that startup succeeded.
    for _ in range(40):
        time.sleep(0.5)
        current = running_instances()
        log_text = hotspot_log_tail(log_path, psk=psk, max_lines=60, max_chars=12000)
        if any(item["physical"] == wifi for item in current) and "AP-ENABLED" in log_text:
            current_state = read_prefs()
            current_state["wifiInterface"] = wifi
            # Keep AUTO as a preference; do not freeze the current route (e.g. ProtonVPN) in config.
            current_state["internetInterface"] = internet_pref if internet_pref in ("AUTO", "NONE") else internet
            current_state["ufwEgress"] = internet or "NONE"
            write_prefs(current_state)
            summary = interface_summary(wifi, internet if internet else "NONE")
            print(json.dumps({"success": True, "active": True,
                              "message": "Hotspot started with linux-wifi-hotspot.",
                              "interfaceSummary": summary,
                              "logPath": str(log_path)}, ensure_ascii=False))
            return
        exit_code = proc.poll()
        if exit_code is not None:
            details = hotspot_log_tail(log_path, psk=psk)
            msg = details or f"create_ap exited before the access point became active (exit code {exit_code})."
            print(json.dumps({"success": False, "active": False, "message": msg,
                              "logPath": str(log_path)}, ensure_ascii=False))
            return

    # No AP-ENABLED marker within the startup window. Stop only the process group
    # that this helper launched, then surface the captured log instead of guessing.
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError, OSError):
        pass
    details = hotspot_log_tail(log_path, psk=psk)
    msg = "Timed out waiting for create_ap to enable the access point."
    if details:
        msg += "\n\nLast create_ap log lines:\n" + details
    print(json.dumps({"success": False, "active": False, "message": msg,
                      "logPath": str(log_path)}, ensure_ascii=False))


def stop(profile=None):
    profile = profile or preferred_profile()
    instances = running_instances()
    if instances:
        prefs = read_prefs()
        item = choose_instance(instances, prefs.get("wifiInterface", ""))
        pkexec = pkexec_path()
        create_ap = create_ap_path()
        if not pkexec or not create_ap:
            print(json.dumps({"success": False, "active": True, "message": backend_message()}))
            return
        res = run([pkexec, create_ap, "--stop", item["physical"]], timeout=30)
        if res.returncode != 0:
            msg = (res.stderr or res.stdout or "Could not stop the hotspot.").strip()
            print(json.dumps({"success": False, "active": True, "message": msg}, ensure_ascii=False))
            return
        for _ in range(20):
            time.sleep(0.25)
            if not any(entry["physical"] == item["physical"] for entry in running_instances()):
                print(json.dumps({"success": True, "active": False, "message": "Hotspot stopped."}))
                return
        print(json.dumps({"success": True, "active": False, "message": "Stop requested; adapter cleanup may still be finishing."}))
        return
    if is_active(profile):
        res = run(["nmcli", "connection", "down", profile], timeout=15)
        if res.returncode == 0:
            print(json.dumps({"success": True, "active": False, "message": "Old NetworkManager hotspot stopped. The next start will use linux-wifi-hotspot."}))
        else:
            print(json.dumps({"success": False, "active": True, "message": (res.stderr or "Could not stop the old hotspot.").strip()}))
        return
    print(json.dumps({"success": True, "active": False, "message": "Hotspot is already off."}))


def diagnostics(profile=None):
    profile = profile or preferred_profile()
    checks = []
    create_ap = create_ap_path()
    pkexec = pkexec_path()
    checks.append({
        "ok": bool(create_ap),
        "label": "linux-wifi-hotspot",
        "detail": create_ap or "create_ap not found (install the AUR package)",
    })
    checks.append({
        "ok": bool(pkexec),
        "label": "Polkit helper",
        "detail": pkexec or "pkexec not found (install polkit and run a Polkit agent)",
    })
    ssid = nm_get(profile, "802-11-wireless.ssid")
    psk = nm_get(profile, "802-11-wireless-security.psk", True)
    checks.append({
        "ok": bool(ssid),
        "label": "NetworkManager profile",
        "detail": profile if ssid else f"{profile} is missing or has no SSID",
    })
    checks.append({
        "ok": 8 <= len(psk) <= 63,
        "label": "Hotspot password",
        "detail": "configured" if psk else "not set",
    })
    wifi = read_prefs().get("wifiInterface") or default_wifi_interface()
    checks.append({
        "ok": bool(wifi),
        "label": "Wi-Fi adapter",
        "detail": wifi or "no wireless interface found",
    })
    active = bool(running_instances()) or is_active(profile)
    checks.append({
        "ok": True,
        "label": "Hotspot state",
        "detail": "on" if active else "off",
    })
    print(json.dumps({"success": True, "profile": profile, "checks": checks}, ensure_ascii=False))


def toggle(profile=None):
    profile = profile or preferred_profile()
    if running_instances() or is_active(profile):
        stop(profile)
    else:
        start(profile)


def main():
    args = sys.argv[1:]
    if not args:
        print(json.dumps({"success": False, "message": "Missing command."}))
    elif args[0] == "info":
        info(args[1] if len(args) >= 2 else None)
    elif args[0] == "status":
        status(args[1] if len(args) >= 2 else None)
    elif args[0] == "interfaces":
        interface_options()
    elif args[0] == "set-interfaces" and len(args) >= 3:
        save_interfaces(args[1], args[2])
    elif args[0] == "clients":
        clients(args[1] if len(args) >= 2 else None)
    elif args[0] == "set" and len(args) >= 4:
        set_cfg(args[1], args[2], args[3])
    elif args[0] == "start":
        start(args[1] if len(args) >= 2 else None)
    elif args[0] == "stop":
        stop(args[1] if len(args) >= 2 else None)
    elif args[0] == "toggle":
        toggle(args[1] if len(args) >= 2 else None)
    elif args[0] == "diagnostics":
        diagnostics(args[1] if len(args) >= 2 else None)
    else:
        print(json.dumps({"success": False, "message": "Unknown hotspot command."}))


if __name__ == "__main__":
    main()
