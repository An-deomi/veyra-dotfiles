import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Scripts/system"))
import battery_details


class BatteryDetailsTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.addCleanup(self.temp_dir.cleanup)

    @staticmethod
    def no_upower():
        return {"available": False}

    def make_battery(self, name="BAT0"):
        battery = self.root / name
        battery.mkdir()
        (battery / "type").write_text("Battery\n", encoding="utf-8")
        (battery / "present").write_text("1\n", encoding="utf-8")
        return battery

    def test_reads_cycle_count_capacity_voltage_and_temperature(self):
        battery = self.make_battery()
        values = {
            "manufacturer": "Dell",
            "model_name": "DV9NT",
            "cycle_count": "420",
            "energy_full_design": "42920000",
            "energy_full": "26455000",
            "voltage_now": "7431000",
            "temp": "315",
        }
        for key, value in values.items():
            (battery / key).write_text(value + "\n", encoding="utf-8")

        result = battery_details.collect_battery_details(self.root, self.no_upower)
        self.assertTrue(result["available"])
        self.assertEqual(result["manufacturer"], "Dell")
        self.assertEqual(result["model"], "DV9NT")
        self.assertEqual(result["cycleCount"], 420)
        self.assertEqual(result["designCapacityWh"], 42.92)
        self.assertEqual(result["fullCapacityWh"], 26.45)
        self.assertEqual(result["voltage"], 7.431)
        self.assertEqual(result["temperatureC"], 31.5)

    def test_falls_back_to_charge_and_design_voltage_for_capacity(self):
        battery = self.make_battery()
        (battery / "charge_full_design").write_text("5800000\n", encoding="utf-8")
        (battery / "voltage_min_design").write_text("7400000\n", encoding="utf-8")

        result = battery_details.collect_battery_details(self.root, self.no_upower)
        self.assertEqual(result["designCapacityWh"], 42.92)

    def test_upower_fills_design_capacity_and_health_when_sysfs_omits_them(self):
        battery = self.make_battery()
        (battery / "model_name").write_text("DV9NT\n", encoding="utf-8")
        (battery / "voltage_now").write_text("7431000\n", encoding="utf-8")
        upower = {
            "available": True,
            "manufacturer": "LGC",
            "model": "DV9NT",
            "designCapacityWh": 42.92,
            "fullCapacityWh": 26.455,
            "healthPercentage": 61.6,
            "cycleCount": 310,
            "voltage": 7.43,
            "temperatureC": 31.0,
            "source": "UPower",
        }
        result = battery_details.collect_battery_details(self.root, lambda: upower)
        self.assertEqual(result["designCapacityWh"], 42.92)
        self.assertEqual(result["healthPercentage"], 61.6)
        self.assertEqual(result["model"], "DV9NT")
        self.assertEqual(result["voltage"], 7.431)  # sysfs takes precedence
        self.assertIn("UPower", result["source"])

    def test_parses_upower_cli_properties(self):
        output = """
  native-path:          BAT0
  vendor:               LGC-LGC8.82
  model:                DELL DV9NT
  energy-full:          26.455 Wh
  energy-full-design:   42.920 Wh
  capacity:             61.6379%
  charge-cycles:        310
  voltage:              7.431 V
  temperature:          31.0 degrees C
"""
        result = battery_details.parse_upower_info(output)
        self.assertEqual(result["designCapacityWh"], 42.92)
        self.assertEqual(result["fullCapacityWh"], 26.45)
        self.assertEqual(result["healthPercentage"], 61.6)
        self.assertEqual(result["cycleCount"], 310)
        self.assertEqual(result["voltage"], 7.431)
        self.assertEqual(result["temperatureC"], 31.0)

    def test_skips_absent_battery_and_returns_unavailable(self):
        battery = self.make_battery()
        (battery / "present").write_text("0\n", encoding="utf-8")
        self.assertEqual(battery_details.collect_battery_details(self.root, self.no_upower), {"available": False})

    def test_ignores_non_battery_power_supplies(self):
        mains = self.root / "AC"
        mains.mkdir()
        (mains / "type").write_text("Mains\n", encoding="utf-8")
        self.assertEqual(battery_details.collect_battery_details(self.root, self.no_upower), {"available": False})

    def test_upower_reader_queries_battery_endpoint(self):
        def fake_run(args, **kwargs):
            if args == ["upower", "-e"]:
                return type("Result", (), {"returncode": 0, "stdout": "/org/freedesktop/UPower/devices/battery_BAT0\n"})()
            return type("Result", (), {
                "returncode": 0,
                "stdout": "  energy-full-design: 42.920 Wh\n  energy-full: 26.455 Wh\n  capacity: 61.6%\n",
            })()

        result = battery_details.collect_upower_details(fake_run)
        self.assertEqual(result["designCapacityWh"], 42.92)
        self.assertEqual(result["healthPercentage"], 61.6)


if __name__ == "__main__":
    unittest.main()
