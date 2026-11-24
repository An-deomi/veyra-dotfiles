import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Modules/ControlCenter/scripts"))
import hotspot


class FreshInstallFallbackTests(unittest.TestCase):
    def test_hotspot_falls_back_to_example_when_local_json_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            cfg_dir = Path(tmp) / "quickshell"
            cfg_dir.mkdir(parents=True)
            (cfg_dir / "hotspot_backend.json.example").write_text(
                json.dumps({
                    "wifiInterface": "",
                    "internetInterface": "AUTO",
                    "ufwEgress": "",
                    "hotspotProfile": "ExampleHotspot",
                }),
                encoding="utf-8",
            )
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp}):
                prefs = hotspot.read_prefs()
                self.assertEqual(prefs.get("hotspotProfile"), "ExampleHotspot")
                self.assertEqual(prefs.get("internetInterface"), "AUTO")

                (cfg_dir / "hotspot_backend.json").write_text(
                    json.dumps({"hotspotProfile": "LocalHotspot", "internetInterface": "NONE"}),
                    encoding="utf-8",
                )
                local_prefs = hotspot.read_prefs()
                self.assertEqual(local_prefs.get("hotspotProfile"), "LocalHotspot")
                self.assertEqual(local_prefs.get("internetInterface"), "NONE")

    def test_update_veyra_prefs_creates_file_when_absent(self):
        with tempfile.TemporaryDirectory() as tmp:
            res = subprocess.run(
                [
                    sys.executable,
                    "-B",
                    str(ROOT / "Core/Services/scripts/update_veyra_prefs.py"),
                    json.dumps({"screen_shader": "vibrance", "shadow_glow_enabled": True}),
                ],
                env={**os.environ, "XDG_CONFIG_HOME": tmp},
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            created = Path(tmp) / "hypr" / "veyra-settings.lua"
            self.assertTrue(created.is_file())
            text = created.read_text(encoding="utf-8")
            self.assertIn('screen_shader = "vibrance"', text)
            self.assertIn("shadow_glow_enabled = true", text)

    def test_emoji_scripts_work_without_external_emoji_module(self):
        for rel in ("emoji/get_emoji.py", "Modules/Launcher/scripts/get_emoji.py"):
            res = subprocess.run(
                [sys.executable, "-B", str(ROOT / rel)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(res.returncode, 0, f"{rel} failed: {res.stderr}")
            items = json.loads(res.stdout)
            self.assertGreater(len(items), 1000)
            sample = items[0]
            self.assertIn("e", sample)
            self.assertIn("n", sample)
            self.assertIn("a", sample)
            self.assertIn("g", sample)


if __name__ == "__main__":
    unittest.main()
