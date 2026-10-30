import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import p10_apple_simulator as subject


class AppleSimulatorTest(unittest.TestCase):
    def test_pinned_selection_is_order_independent_and_has_no_profile_fallback(self):
        inventory = {
            "runtimes": [
                {"identifier": "sim.iOS-26-2", "version": "26.2", "isAvailable": True},
                {"identifier": "sim.iOS-26-1", "version": "26.1", "isAvailable": True},
                {"identifier": "sim.iOS-27-0", "version": "27.0", "isAvailable": False},
            ],
            "devices": {
                "sim.iOS-26-1": [self.device("old", "iPad Old")],
                "sim.iOS-27-0": [self.device("unavailable", "iPad A")],
                "sim.iOS-26-2": [self.device("b", "iPad B"),
                                  self.device("phone", "iPhone A"),
                                  self.device("z", "iPad A"), self.device("a", "iPad A")],
            },
        }
        def choose(data=inventory, form="iPadOS", runtime="sim.iOS-26-2", model="iPad A"):
            return subject.choose_simulator(data, form, runtime, model)

        selected = choose()
        self.assertEqual(selected["udid"], "a")
        self.assertEqual(selected["runtime"], "sim.iOS-26-2")
        reversed_inventory = json.loads(json.dumps(inventory))
        reversed_inventory["runtimes"].reverse()
        reversed_inventory["devices"] = {
            k: list(reversed(v)) for k, v in reversed(list(inventory["devices"].items()))
        }
        self.assertEqual(choose(reversed_inventory), selected)
        self.assertEqual(choose(form="iOS", model="iPhone A")["udid"], "phone")
        inventory["runtimes"][2]["isAvailable"] = True
        self.assertEqual(choose(), selected)  # Newer image runtime is irrelevant.
        with self.assertRaises(ValueError):
            choose({"runtimes": [], "devices": {}})
        with self.assertRaises(ValueError):
            choose(form="unknown")
        with self.assertRaises(ValueError):
            choose(model="missing")
        with self.assertRaises(ValueError):
            choose(model="iPhone A")
        inventory["runtimes"][0]["isAvailable"] = False
        with self.assertRaises(ValueError):
            choose()  # Never substitute another OS for the required profile.

    @staticmethod
    def device(udid, name):
        return {"udid": udid, "name": name, "isAvailable": True, "state": "Shutdown"}

    def test_runner_retains_output_and_rejects_failed_or_timed_out_probe(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(subject, "LOGS", Path(directory)):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertIn("ready", subject.run(
                        [sys.executable, "-c", "print('ready')"], "ok", 5))
                    with self.assertRaises(subprocess.CalledProcessError):
                        subject.run([sys.executable, "-c", "print('failed');exit(7)"],
                                    "failed", 5)
                    with self.assertRaises(subprocess.TimeoutExpired):
                        subject.run([sys.executable, "-u", "-c",
                                     "import time;print('launching');time.sleep(10)"],
                                    "hang", 0.2)
                self.assertIn("failed", (Path(directory) / "failed.log").read_text())
                self.assertIn("launching", (Path(directory) / "hang.log").read_text())

    def test_cleanup_permission_race_retains_original_timeout_and_stops_owned_child(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(subject, "LOGS", Path(directory)):
                with patch.object(subject.os, "killpg", side_effect=PermissionError("EPERM")):
                    with contextlib.redirect_stdout(io.StringIO()):
                        with self.assertRaises(subprocess.TimeoutExpired):
                            subject.run([sys.executable, "-u", "-c",
                                         "import time;print('booting');time.sleep(10)"],
                                        "permission-race", 0.2)
                self.assertIn("booting", (Path(directory) / "permission-race.log").read_text())


if __name__ == "__main__":
    unittest.main()
