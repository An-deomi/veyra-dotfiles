#!/usr/bin/env python3
"""Read optional battery hardware details from sysfs and UPower.

This is a one-shot helper invoked when the Battery panel opens or when the
user presses Refresh. Kernel sysfs is preferred for hardware-specific values;
UPower CLI fills gaps such as energy-full-design on systems where the kernel
exposes energy_full but omits energy_full_design.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any

POWER_SUPPLY_ROOT = Path("/sys/class/power_supply")
_NUMBER_RE = re.compile(r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)")


def read_text(directory: Path, attribute: str) -> str | None:
    try:
        value = (directory / attribute).read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return None
    return value or None


def read_number(directory: Path, attribute: str) -> float | None:
    value = read_text(directory, attribute)
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def first_number(value: str | None) -> float | None:
    if not value:
        return None
    match = _NUMBER_RE.search(value)
    if not match:
        return None
    try:
        return float(match.group(0))
    except ValueError:
        return None


def temperature_celsius(raw: float | None) -> float | None:
    if raw is None:
        return None
    # Linux power_supply sysfs normally reports tenths of a degree Celsius;
    # some drivers expose millidegrees instead.
    return raw / 1000.0 if abs(raw) >= 10000 else raw / 10.0


def parse_upower_info(output: str) -> dict[str, Any]:
    """Parse `upower -i` output with LC_ALL=C (keys remain stable)."""
    values: dict[str, str] = {}
    for line in output.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip().lower().replace("_", "-")] = value.strip()

    def numeric(key: str) -> float | None:
        return first_number(values.get(key))

    design_wh = numeric("energy-full-design")
    full_wh = numeric("energy-full")
    health = numeric("capacity")
    cycle_count = numeric("charge-cycles")
    voltage = numeric("voltage")
    temperature = numeric("temperature")

    # UPower reports voltage in volts and energy values in Wh.
    return {
        "available": True,
        "manufacturer": values.get("vendor") or None,
        "model": values.get("model") or None,
        "cycleCount": int(cycle_count) if cycle_count is not None and cycle_count >= 0 else None,
        "voltage": round(voltage, 3) if voltage is not None and voltage > 0 else None,
        "temperatureC": round(temperature, 1) if temperature is not None and temperature > 0 else None,
        "designCapacityWh": round(design_wh, 2) if design_wh is not None and design_wh > 0 else None,
        "fullCapacityWh": round(full_wh, 2) if full_wh is not None and full_wh > 0 else None,
        "healthPercentage": round(health, 1) if health is not None and 0 < health <= 100 else None,
        "source": "UPower",
    }


def collect_upower_details(run=subprocess.run) -> dict[str, Any]:
    """Return UPower's detailed battery properties when the CLI is available."""
    env = os.environ.copy()
    env["LC_ALL"] = "C"
    try:
        listing = run(
            ["upower", "-e"], capture_output=True, text=True, check=False,
            timeout=3, env=env,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {"available": False}

    if listing.returncode != 0:
        return {"available": False}

    devices = [
        line.strip() for line in listing.stdout.splitlines()
        if line.strip() and "battery" in line.lower() and "displaydevice" not in line.lower()
    ]
    for device in devices:
        try:
            result = run(
                ["upower", "-i", device], capture_output=True, text=True,
                check=False, timeout=3, env=env,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        if result.returncode == 0:
            parsed = parse_upower_info(result.stdout)
            if parsed.get("designCapacityWh") or parsed.get("fullCapacityWh") or parsed.get("model"):
                return parsed
    return {"available": False}


def collect_battery_details(
    root: Path = POWER_SUPPLY_ROOT,
    upower_reader=collect_upower_details,
) -> dict[str, Any]:
    """Merge kernel and UPower data, preferring direct sysfs measurements."""
    try:
        candidates = sorted(root.glob("*"))
    except OSError:
        candidates = []

    sysfs: dict[str, Any] = {"available": False}
    for directory in candidates:
        if read_text(directory, "type") != "Battery":
            continue
        if read_text(directory, "present") == "0":
            continue

        design_energy = read_number(directory, "energy_full_design")
        if design_energy is not None and design_energy > 0:
            design_capacity_wh = design_energy / 1_000_000.0
        else:
            design_charge = read_number(directory, "charge_full_design")
            design_voltage = read_number(directory, "voltage_min_design")
            design_capacity_wh = (
                design_charge * design_voltage / 1_000_000_000_000.0
                if design_charge and design_voltage and design_charge > 0 and design_voltage > 0
                else None
            )

        full_energy = read_number(directory, "energy_full")
        full_capacity_wh = (
            full_energy / 1_000_000.0
            if full_energy is not None and full_energy > 0
            else None
        )

        cycle_count = read_number(directory, "cycle_count")
        voltage = read_number(directory, "voltage_now")
        if voltage is not None:
            voltage /= 1_000_000.0

        raw_temperature = read_number(directory, "temp")
        if raw_temperature is None:
            raw_temperature = read_number(directory, "temp_now")
        temperature = temperature_celsius(raw_temperature)

        sysfs = {
            "available": True,
            "device": directory.name,
            "manufacturer": read_text(directory, "manufacturer"),
            "model": read_text(directory, "model_name") or read_text(directory, "model"),
            "cycleCount": int(cycle_count) if cycle_count is not None and cycle_count >= 0 else None,
            "voltage": round(voltage, 3) if voltage is not None and voltage > 0 else None,
            "temperatureC": round(temperature, 1) if temperature is not None else None,
            "designCapacityWh": round(design_capacity_wh, 2) if design_capacity_wh else None,
            "fullCapacityWh": round(full_capacity_wh, 2) if full_capacity_wh else None,
            "source": "Kernel",
        }
        break

    try:
        upower = upower_reader()
    except Exception:
        # Hardware information is optional; never let it break the control center.
        upower = {"available": False}

    merged: dict[str, Any] = {"available": bool(sysfs.get("available") or upower.get("available"))}
    for key in (
        "device", "manufacturer", "model", "cycleCount", "voltage",
        "temperatureC", "designCapacityWh", "fullCapacityWh", "healthPercentage",
    ):
        merged[key] = sysfs.get(key) if sysfs.get(key) not in (None, "") else upower.get(key)

    sources = []
    if sysfs.get("available"):
        sources.append("kernel")
    if upower.get("available"):
        sources.append("UPower")
    merged["source"] = " + ".join(sources) if sources else None
    return merged if merged["available"] else {"available": False}


def main() -> None:
    print(json.dumps(collect_battery_details(), separators=(",", ":")))


if __name__ == "__main__":
    main()
