import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Core/Services/scripts"))
import game_mode


class GameModeProfileTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {"VEYRA_GAME_MODE_STATE_DIR": self.temp_dir.name})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.addCleanup(self.temp_dir.cleanup)

    def mock_result(self, stdout="balanced", returncode=0, stderr=""):
        return type("Result", (), {"stdout": stdout, "stderr": stderr, "returncode": returncode})()

    @patch.object(game_mode, "_run_powerprofilesctl")
    def test_apply_saves_original_profile_and_sets_performance(self, run_profile):
        run_profile.side_effect = [self.mock_result("power-saver\n"), self.mock_result("")]
        result = game_mode.apply_mode()
        self.assertEqual(result["status"], "applied")
        self.assertEqual(game_mode._read_saved_profile(), "power-saver")
        self.assertEqual(run_profile.call_args_list[0].args, ("get",))
        self.assertEqual(run_profile.call_args_list[1].args, ("set", "performance"))

    @patch.object(game_mode, "_run_powerprofilesctl")
    def test_apply_does_not_replace_restore_point_while_performance_active(self, run_profile):
        game_mode._save_profile("balanced")
        run_profile.side_effect = [self.mock_result("performance\n"), self.mock_result("")]
        result = game_mode.apply_mode()
        self.assertEqual(result["status"], "applied")
        self.assertEqual(game_mode._read_saved_profile(), "balanced")

    @patch.object(game_mode, "_run_powerprofilesctl")
    def test_apply_migrates_legacy_restore_point_only_while_performance_active(self, run_profile):
        legacy_path = Path(self.temp_dir.name) / "veyra_prev_power_profile"
        legacy_path.write_text("balanced\n", encoding="ascii")
        with patch.object(game_mode, "_legacy_state_file", return_value=legacy_path):
            run_profile.side_effect = [self.mock_result("performance\n"), self.mock_result("")]
            result = game_mode.apply_mode()
        self.assertEqual(result["status"], "applied")
        self.assertEqual(game_mode._read_saved_profile(), "balanced")
        self.assertFalse(legacy_path.exists())

    @patch.object(game_mode, "_run_powerprofilesctl")
    def test_revert_without_state_does_not_guess_balanced(self, run_profile):
        result = game_mode.revert_mode()
        self.assertEqual(result["status"], "skipped")
        run_profile.assert_not_called()

    @patch.object(game_mode, "_run_powerprofilesctl")
    def test_revert_restores_and_removes_valid_state(self, run_profile):
        game_mode._save_profile("power-saver")
        run_profile.return_value = self.mock_result("")
        result = game_mode.revert_mode()
        self.assertEqual(result["status"], "reverted")
        self.assertEqual(result["restored_profile"], "power-saver")
        run_profile.assert_called_once_with("set", "power-saver")
        self.assertFalse(game_mode._state_file().exists())

    @patch.object(game_mode, "_run_powerprofilesctl")
    def test_failed_restore_keeps_state_for_retry(self, run_profile):
        game_mode._save_profile("balanced")
        run_profile.return_value = self.mock_result(returncode=1, stderr="daemon unavailable")
        result = game_mode.revert_mode()
        self.assertEqual(result["status"], "error")
        self.assertTrue(game_mode._state_file().exists())

    @patch.object(game_mode, "_run_powerprofilesctl")
    def test_apply_does_not_switch_when_profile_service_is_unavailable(self, run_profile):
        run_profile.return_value = self.mock_result(returncode=1, stderr="not running")
        result = game_mode.apply_mode()
        self.assertEqual(result["status"], "error")
        self.assertFalse(game_mode._state_file().exists())
        run_profile.assert_called_once_with("get")


if __name__ == "__main__":
    unittest.main()
