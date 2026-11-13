# Advanced routing native evidence

Baseline 9f15d9854d1a43c70d3d7f5d8b787dda4f459c31. See the final report in docs/qualification/desktop-uat/MULTI_SURFACE_ROUTING_FINAL_REPORT.md.

Native PNGs are retained locally in screenshots/ and intentionally excluded from this commit (about 6.6 MiB). manifest.json records their filenames, sizes and SHA-256. This is not a remote artifact upload; a fresh clone will not contain the PNGs. AX text, runtime/test logs, UI-created geometry and read-only persistence audits are tracked. before-restart.json contains only this synthetic acceptance project, never seeded back into the app. Acceptance IDs DB/S/L are aliases mapped to actual IDs in reopen-comparison.json.

Quit verification: after Flutter run sessions detached, native application menu Quit was invoked without a subsequent app observation; `ps -ax -o pid=,command= | rg '[/]elecx.app/Contents/MacOS/elecx'` returned exit 1/no output. Then a fresh `flutter run -d macos -t lib/main.dart` reopened the project. Earlier failed sandbox process lookups and blank accessibility states are not used as termination evidence.
