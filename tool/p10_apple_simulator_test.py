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
    def test_selection_is_independent_of_inventory_order_and_unavailable_runtime(self):
        inventory = {
            "runtimes": [
                {"identifier": "sim.iOS-26-2", "version": "26.2", "isAvailable": True},
                {"identifier": "sim.iOS-26-1", "version": "26.1", "isAvailable": True},
                {"identifier": "sim.iOS-27-0", "version": "27.0", "isAvailable": False},
            ],
            "devices": {
                "sim.iOS-26-1": [self.device("old", "iPad Old")],
                "sim.iOS-27-0": [self.device("unavailable", "iPad New")],
                "sim.iOS-26-2": [self.device("b", "iPad B"),
                                  self.device("phone", "iPhone A"),
                                  self.device("a", "iPad A")],
            },
        }
        selected = subject.choose_simulator(inventory, "iPadOS")
        self.assertEqual(selected["udid"], "a")
        self.assertEqual(selected["runtime"], "sim.iOS-26-2")
        reversed_inventory = json.loads(json.dumps(inventory))
        reversed_inventory["runtimes"].reverse()
        reversed_inventory["devices"] = {
            k: list(reversed(v)) for k, v in reversed(list(inventory["devices"].items()))
        }
        self.assertEqual(subject.choose_simulator(reversed_inventory, "iPadOS"), selected)
        self.assertEqual(subject.choose_simulator(inventory, "iOS")["udid"], "phone")
        with self.assertRaises(ValueError):
            subject.choose_simulator({"runtimes": [], "devices": {}}, "iPadOS")
        with self.assertRaises(ValueError):
            subject.choose_simulator(inventory, "unknown")

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


if __name__ == "__main__":
    unittest.main()
