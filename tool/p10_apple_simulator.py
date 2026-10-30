"""Bounded native P10 qualification with retained simulator/Flutter diagnostics."""

import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import threading

LOGS = Path("build/p10-apple-diagnostics")


def run(command, name, timeout):
    LOGS.mkdir(parents=True, exist_ok=True)
    print(f"P10 {name}: {command!r} (timeout {timeout}s)", flush=True)
    with (LOGS / f"{name}.log").open("w") as log:
        with subprocess.Popen(
            command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", start_new_session=True,
        ) as process:
            def stream():
                for line in process.stdout:
                    log.write(line)
                    log.flush()
                    print(line, end="", flush=True)

            reader = threading.Thread(target=stream, daemon=True)
            reader.start()
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                print(f"P10 {name}: timed out; stopping process group", flush=True)
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    pass
                # A descendant (simctl/VM service) may outlive its parent.
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=10)
                reader.join(timeout=5)
                raise
            reader.join(timeout=5)
            if code:
                raise subprocess.CalledProcessError(code, command)
    return (LOGS / f"{name}.log").read_text()


def choose_simulator(inventory, form):
    if form not in ("iOS", "iPadOS"):
        raise ValueError("P10_FORM must be iOS or iPadOS")
    runtimes = {
        r["identifier"]: r for r in inventory["runtimes"]
        if r.get("isAvailable") and ".iOS-" in r["identifier"]
    }
    prefix = "iPad" if form == "iPadOS" else "iPhone"
    candidates = [
        (runtimes[runtime], device)
        for runtime, devices in inventory["devices"].items()
        if runtime in runtimes
        for device in devices
        if device.get("isAvailable") and device["name"].startswith(prefix)
    ]
    if not candidates:
        raise ValueError(f"Required {form} simulator is unavailable")
    # Newest installed available runtime, then model name/UDID. Never depend on
    # simctl dictionary/list order. Record the exact runner model/runtime.
    def order(candidate):
        runtime, device = candidate
        version = [int(n) for n in re.findall(r"\d+", runtime["version"])]
        version += [0] * (4 - len(version))
        return tuple(-n for n in version), device["name"], device["udid"]

    runtime, device = sorted(candidates, key=order)[0]
    return {"runtime": runtime["identifier"], "version": runtime["version"],
            "name": device["name"], "udid": device["udid"], "state": device["state"]}


def main(action):
    LOGS.mkdir(parents=True, exist_ok=True)
    if action == "select":
        raw = run(["xcrun", "simctl", "list", "--json"], "inventory", 60)
        selected = choose_simulator(json.loads(raw), os.environ["P10_FORM"])
        (LOGS / "selected.json").write_text(json.dumps(selected, indent=2))
        print(f"P10 selected: {selected}", flush=True)
        with open(os.environ["GITHUB_ENV"], "a") as output:
            output.write(f"P10_SIMULATOR_UDID={selected['udid']}\n")
        return
    udid = os.environ["P10_SIMULATOR_UDID"]
    if action == "boot":
        selected = json.loads((LOGS / "selected.json").read_text())
        if selected["state"] != "Booted":
            run(["xcrun", "simctl", "boot", udid], "boot", 90)
        run(["xcrun", "simctl", "bootstatus", udid, "-b"], "bootstatus", 300)
    elif action == "drive":
        run(["flutter", "drive", "--verbose",
             "--driver=test_driver/p10_semantic_parity_driver.dart",
             "--target=integration_test/p10_native_semantic_parity_test.dart",
             "-d", udid], "flutter-drive", 1200)
    elif action == "diagnose":
        probes = [
            (["xcrun", "simctl", "list", "--json"], "failure-inventory", 30),
            (["xcodebuild", "-version"], "xcode", 30),
            (["xcrun", "simctl", "spawn", udid, "log", "show", "--last", "8m",
              "--style", "compact", "--predicate",
              'process == "Runner" OR process == "debugserver" OR process == "SpringBoard"'],
             "simulator-processes", 60),
            (["xcrun", "simctl", "io", udid, "screenshot", str(LOGS / "screen.png")],
             "screenshot", 20),
        ]
        for command, name, timeout in probes:
            try:
                run(command, name, timeout)
            except (OSError, subprocess.SubprocessError) as error:
                print(f"P10 diagnostic {name}: {error}", flush=True)
    elif action == "shutdown":
        run(["xcrun", "simctl", "shutdown", udid], "shutdown", 30)
    else:
        raise ValueError(f"Unknown action: {action}")


if __name__ == "__main__":
    try:
        main(sys.argv[1])
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"P10 native qualification failed: {error}", file=sys.stderr, flush=True)
        sys.exit(1)
