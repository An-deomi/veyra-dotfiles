import sys
import unittest
from pathlib import Path
from unittest.mock import mock_open, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Scripts/system"))
import get_lock_stats


class LockStatsTests(unittest.TestCase):
    def test_cpu_tick_parser_handles_aggregate_line(self):
        data = "cpu  10 2 3 40 5 6 7 8 0 0\ncpu0 1 0 1 4\n"
        with patch("builtins.open", mock_open(read_data=data)):
            total, idle = get_lock_stats.read_cpu_ticks()
        self.assertEqual(total, 81)
        self.assertEqual(idle, 45)

    def test_memory_parser_uses_memavailable(self):
        data = "MemTotal:       8388608 kB\nMemAvailable:   4194304 kB\n"
        with patch("builtins.open", mock_open(read_data=data)):
            used, total = get_lock_stats.read_memory()
        self.assertEqual(used, 4.0)
        self.assertEqual(total, 8.0)

    def test_sample_outputs_only_lock_screen_fields(self):
        with patch.object(get_lock_stats, "read_cpu_ticks", return_value=(200, 80)), \
             patch.object(get_lock_stats, "read_memory", return_value=(3.0, 8.0)), \
             patch.object(get_lock_stats, "read_uptime", return_value="1h 2m"):
            output, current = get_lock_stats.sample((100, 50))
        self.assertEqual(current, (200, 80))
        self.assertEqual(output["system"]["cpu_usage"], 70.0)
        self.assertEqual(output["system"]["mem_used_gb"], 3.0)
        self.assertEqual(output["system"]["uptime"], "1h 2m")
        self.assertEqual(set(output), {"system"})


if __name__ == "__main__":
    unittest.main()
