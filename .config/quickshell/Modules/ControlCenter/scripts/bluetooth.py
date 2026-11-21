#!/usr/bin/env python3
"""Veyra Bluetooth helper backed by BlueZ D-Bus and bluetoothctl.

Commands emit JSON so Quickshell can show adapter/device state and explain
connection failures without parsing terminal-oriented output in QML.
"""
import sys
sys.dont_write_bytecode = True

import json
import re
import subprocess
import time

MAC_RE = re.compile(r"^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")


def _empty_status(error="", adapter_available=False):
    return {
        "adapter_available": adapter_available,
        "adapter_name": "",
        "powered": False,
        "discovering": False,
        "connected_device": "",
        "connected_count": 0,
        "paired_count": 0,
        "devices": [],
        "error": error,
    }


def get_devices():
    try:
        import dbus
    except ImportError:
        return _empty_status("Python D-Bus bindings are missing (python-dbus).")

    try:
        bus = dbus.SystemBus()
        manager = dbus.Interface(
            bus.get_object("org.bluez", "/"),
            "org.freedesktop.DBus.ObjectManager",
        )
        objects = manager.GetManagedObjects()
    except Exception:
        return _empty_status(
            "BlueZ is unavailable. Check that the Bluetooth service is running."
        )

    adapters = []
    for path, ifaces in objects.items():
        props = ifaces.get("org.bluez.Adapter1")
        if props is not None:
            adapters.append((str(path), props))

    if not adapters:
        return _empty_status("No Bluetooth adapter was detected.")

    # Prefer the powered adapter if multiple controllers exist.
    adapters.sort(key=lambda item: not bool(item[1].get("Powered", False)))
    adapter_path, adapter_props = adapters[0]
    adapter_name = str(
        adapter_props.get("Alias")
        or adapter_props.get("Name")
        or adapter_props.get("Address")
        or "Bluetooth adapter"
    )
    powered = bool(adapter_props.get("Powered", False))
    discovering = bool(adapter_props.get("Discovering", False))

    devices = []
    connected_device = ""
    for path, ifaces in objects.items():
        # Avoid mixing devices belonging to a different adapter/controller.
        if not str(path).startswith(adapter_path + "/"):
            continue
        d = ifaces.get("org.bluez.Device1")
        if d is None:
            continue

        mac = str(d.get("Address", ""))
        if not mac:
            continue
        name = str(d.get("Alias") or d.get("Name") or mac)
        connected = bool(d.get("Connected", False))
        paired = bool(d.get("Paired", False))
        icon = str(d.get("Icon", ""))
        battery = None
        battery_props = ifaces.get("org.bluez.Battery1")
        if battery_props is not None and "Percentage" in battery_props:
            try:
                battery = max(0, min(100, int(battery_props["Percentage"])))
            except (TypeError, ValueError):
                battery = None

        rssi = None
        if "RSSI" in d:
            try:
                rssi = int(d["RSSI"])
            except (TypeError, ValueError):
                rssi = None

        if connected and not connected_device:
            connected_device = name
        devices.append({
            "mac": mac,
            "name": name,
            "connected": connected,
            "paired": paired,
            "icon": icon,
            "battery": battery,
            "rssi": rssi,
            "path": str(path),
        })

    devices.sort(key=lambda d: (not d["connected"], not d["paired"], d["name"].casefold()))
    return {
        "adapter_available": True,
        "adapter_name": adapter_name,
        "powered": powered,
        "discovering": discovering,
        "connected_device": connected_device,
        "connected_count": sum(1 for d in devices if d["connected"]),
        "paired_count": sum(1 for d in devices if d["paired"]),
        "devices": devices,
        "error": "",
    }


def _run_ctl(*args, timeout=20):
    try:
        return subprocess.run(
            ["bluetoothctl", *args],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except FileNotFoundError:
        return None
    except subprocess.TimeoutExpired as exc:
        # Preserve partial output so the UI can display a useful failure.
        out = exc.stdout or ""
        err = exc.stderr or ""
        if isinstance(out, bytes):
            out = out.decode(errors="replace")
        if isinstance(err, bytes):
            err = err.decode(errors="replace")
        return subprocess.CompletedProcess(
            ["bluetoothctl", *args], 124, out, (err + " Command timed out.").strip()
        )


def _result_text(result):
    if result is None:
        return "bluetoothctl is not installed."
    return "\n".join(part.strip() for part in (result.stdout, result.stderr) if part and part.strip())


def _looks_failed(result):
    if result is None or result.returncode != 0:
        return True
    text = _result_text(result).casefold()
    return any(token in text for token in (
        "failed to", "failed:", "org.bluez.error", "no default controller",
        "not available", "not ready", "authentication canceled", "operation aborted",
    ))


def _find_device(status, mac):
    return next((device for device in status.get("devices", []) if device["mac"].casefold() == mac.casefold()), None)


def _wait_for_state(mac, key, expected, attempts=8, interval=0.4):
    latest = get_devices()
    for _ in range(attempts):
        device = _find_device(latest, mac)
        if device is not None and bool(device.get(key)) is expected:
            return latest, device
        time.sleep(interval)
        latest = get_devices()
    return latest, _find_device(latest, mac)


def _emit_action(ok, message, **extra):
    result = {"ok": bool(ok), "message": str(message)}
    result.update(extra)
    print(json.dumps(result))
    return 0 if ok else 1


def do_status():
    print(json.dumps(get_devices()))


def do_scan():
    try:
        import signal
        import dbus
        from dbus.mainloop.glib import DBusGMainLoop
        from gi.repository import GLib
    except ImportError:
        print(json.dumps({"event": "error", "message": "Scanning needs Python D-Bus and GLib bindings."}), flush=True)
        sys.exit(1)

    DBusGMainLoop(set_as_default=True)
    try:
        bus = dbus.SystemBus()
        manager = dbus.Interface(
            bus.get_object("org.bluez", "/"),
            "org.freedesktop.DBus.ObjectManager",
        )
        objects = manager.GetManagedObjects()
        adapters = [
            (str(path), props)
            for path, ifaces in objects.items()
            if (props := ifaces.get("org.bluez.Adapter1")) is not None
        ]
        if not adapters:
            print(json.dumps({"event": "error", "message": "No Bluetooth adapter was detected."}), flush=True)
            return
        adapters.sort(key=lambda item: not bool(item[1].get("Powered", False)))
        adapter_path, adapter_props = adapters[0]
        if not bool(adapter_props.get("Powered", False)):
            print(json.dumps({"event": "error", "message": "Bluetooth is turned off. Turn it on before scanning."}), flush=True)
            return
        adapter = dbus.Interface(
            bus.get_object("org.bluez", adapter_path), "org.bluez.Adapter1"
        )
    except Exception:
        print(json.dumps({"event": "error", "message": "Could not reach the Bluetooth adapter."}), flush=True)
        return

    loop = GLib.MainLoop()

    def on_term(signum, frame):
        try:
            adapter.StopDiscovery()
        except Exception:
            pass
        loop.quit()

    signal.signal(signal.SIGTERM, on_term)
    signal.signal(signal.SIGINT, on_term)

    def emit():
        data = get_devices()
        if data.get("error"):
            print(json.dumps({"event": "error", "message": data["error"]}), flush=True)
            return True
        print(json.dumps({"event": "devices", "devices": data.get("devices", [])}), flush=True)
        return True

    try:
        try:
            adapter.StartDiscovery()
        except Exception as exc:
            # BlueZ can report InProgress if another application has initiated
            # discovery. In that case still observe and display the scan results.
            if "inprogress" not in str(exc).casefold() and "in progress" not in str(exc).casefold():
                print(json.dumps({"event": "error", "message": "Bluetooth scan could not start."}), flush=True)
                return
        print(json.dumps({"event": "scan", "state": "started"}), flush=True)
        emit()
        GLib.timeout_add(1000, emit)
        GLib.timeout_add_seconds(90, loop.quit)
        loop.run()
    finally:
        try:
            adapter.StopDiscovery()
        except Exception:
            pass
        print(json.dumps({"event": "scan", "state": "finished"}), flush=True)


def do_toggle_power():
    status = get_devices()
    if not status.get("adapter_available"):
        return _emit_action(False, status.get("error") or "No Bluetooth adapter is available.")

    want_powered = not bool(status.get("powered", False))
    action = "on" if want_powered else "off"
    result = _run_ctl("power", action, timeout=12)
    if result is None:
        return _emit_action(False, "bluetoothctl is not installed.")

    latest = get_devices()
    if bool(latest.get("powered")) == want_powered:
        return _emit_action(True, "Bluetooth turned " + ("on." if want_powered else "off."), powered=want_powered)

    detail = _result_text(result)
    message = detail.splitlines()[-1] if detail else "Bluetooth power change did not take effect."
    return _emit_action(False, message, powered=bool(latest.get("powered")))


def do_toggle_connect(mac):
    if not MAC_RE.fullmatch(mac):
        return _emit_action(False, "Invalid Bluetooth device address.", mac=mac)

    status = get_devices()
    if not status.get("adapter_available"):
        return _emit_action(False, status.get("error") or "No Bluetooth adapter is available.", mac=mac)
    if not status.get("powered"):
        return _emit_action(False, "Bluetooth is turned off. Turn it on and try again.", mac=mac)

    device = _find_device(status, mac)
    if device is not None and device.get("connected"):
        result = _run_ctl("disconnect", mac, timeout=15)
        if result is None:
            return _emit_action(False, "bluetoothctl is not installed.", mac=mac)
        latest, _ = _wait_for_state(mac, "connected", False, attempts=5, interval=0.3)
        if not bool((_find_device(latest, mac) or {}).get("connected", False)):
            return _emit_action(True, "Disconnected from " + (device.get("name") or mac) + ".", mac=mac, connected=False)
        detail = _result_text(result)
        return _emit_action(False, detail.splitlines()[-1] if detail else "Could not disconnect the device.", mac=mac, connected=True)

    # New devices need pairing before connect; the old helper only issued
    # `bluetoothctl connect`, which often fails for genuinely new devices.
    if device is not None and not device.get("paired"):
        # Register a no-input/no-output agent for common Just-Works pairing.
        # Devices that require a PIN/passkey or numeric confirmation still need
        # a desktop agent capable of handling that interaction.
        pair_result = _run_ctl("--agent", "NoInputNoOutput", "pair", mac, timeout=45)
        if pair_result is None:
            return _emit_action(False, "bluetoothctl is not installed.", mac=mac)
        after_pair, paired_device = _wait_for_state(mac, "paired", True, attempts=5, interval=0.4)
        if paired_device is None or not paired_device.get("paired"):
            detail = _result_text(pair_result)
            message = detail.splitlines()[-1] if detail else "Pairing did not complete. Make sure the device is in pairing mode."
            return _emit_action(False, message, mac=mac, paired=False, connected=False)
        # BlueZ's bluetoothctl pair operation also attempts to trust/connect.
        # Only issue another connect if the device is still not connected.
        device = paired_device
        if device.get("connected"):
            return _emit_action(True, "Connected to " + (device.get("name") or mac) + ".", mac=mac, paired=True, connected=True)

    result = _run_ctl("connect", mac, timeout=25)
    if result is None:
        return _emit_action(False, "bluetoothctl is not installed.", mac=mac)
    latest, connected_device = _wait_for_state(mac, "connected", True, attempts=8, interval=0.4)
    if connected_device is not None and connected_device.get("connected"):
        name = connected_device.get("name") or mac
        return _emit_action(True, "Connected to " + name + ".", mac=mac, paired=bool(connected_device.get("paired")), connected=True)

    detail = _result_text(result)
    message = detail.splitlines()[-1] if detail else "Could not connect. Check that the device is nearby and available."
    return _emit_action(False, message, mac=mac, paired=bool((connected_device or {}).get("paired", False)), connected=False)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: bluetooth.py [status|scan|toggle-power|toggle-connect <mac>]")
        sys.exit(1)

    command = sys.argv[1]
    if command == "status":
        do_status()
    elif command == "scan":
        do_scan()
    elif command == "toggle-power":
        do_toggle_power()
    elif command == "toggle-connect":
        if len(sys.argv) < 3:
            sys.exit(1)
        sys.exit(do_toggle_connect(sys.argv[2]))
