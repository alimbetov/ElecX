# Test execution

Toolchain: `/Users/ruslanalimbetov/Documents/electra/flutter-sdk/bin/{flutter,dart}`. Commands executed from audit worktree; local raw evidence is outside Git at `ElecX-p12-r3-evidence-20261110` beside the worktree. Checksums: EVIDENCE_MANIFEST.json.

| Command / phase | Actual result |
|---|---|
| git status --short --branch; git rev-parse HEAD; git fetch origin | baseline 4811b57d; existing changes preserved |
| flutter --version; dart --version; flutter doctor -v; flutter devices | 3.47.7 / 3.13.5; macOS available |
| flutter pub get | PASS; lockfile unchanged |
| dart format --output=none --set-exit-if-changed lib test | PASS, 927 files, 0 changes |
| flutter analyze | PASS baseline and each fix/final; no issues |
| D1 RED | FAIL expected: deleted route retained qualification |
| D2 RED | FAIL expected: wrong mapped room accepted VALID |
| D3 RED | FAIL expected: captured elevation 0 instead of 100 |
| Focused GREEN after D1 | 3; related six suites together 32 PASS |
| Focused GREEN after D2 | 11 PASS |
| Focused GREEN after D3 | 11 PASS |
| Extended mutation/persistence/migration suite | 27 PASS |
| flutter test after three production fixes | 2099 PASS, 2m29s |
| flutter test integration_test/path_provider_macos_smoke_test.dart -d macos | 1 PASS; infrastructure smoke, not production UI substitute |
| flutter run -d macos -t lib/main.dart | real native build/runtime PASS; manual production UI evidence separately recorded |

## Required focused suites run independently

Each command was `flutter test test/<name>_test.dart`, with its own process, exit code and log.

| Suite | Count | Result |
|---|---|---|
| p12_spatial_routing_combinations_test.dart | 5 | PASS |
| p12_interlevel_vertical_core_route_test.dart | 3 | PASS |
| p12_three_room_physical_route_projection_test.dart | 5 | PASS |
| slab_route_persistence_qualification_test.dart | 2 | PASS |
| boundary_penetration_route_integration_test.dart | 11 | PASS |
| p7a66_route_anchor_persistence_test.dart | 6 | PASS |

The early full-suite attempt overlapped introduction of the intentional RED regression and is not valid baseline qualification. It is superseded by the stable 2099-test GREEN run after all three production fixes. Audit-harness errors (one nonexistent test filename; later duplicate local helper name) were corrected and rerun; neither is counted as a product defect or PASS. Raw evidence retains the actual failure/green phases. Expanded matrix adds assertions to an existing interlevel fixture, so top-level test count is unchanged; three regression scenarios were added, not three new test registrations.

After the final additional test-only matrix, formatter/analyzer and 27 focused tests passed. Exact final PR SHA must additionally pass all six GitHub workflows; live/final snapshot is recorded in PR and MERGE_QUALIFICATION.md, never inferred from baseline CI. No skip is counted as PASS.

## 2026-11-13 rerun after target integration and D4

- D4 RED: expected STALE, actual VALID (`active-geometry-red.log`).
- D4 and related workspace/document/UI suites: 19 PASS (`active-geometry-green.log`).
- Full suite: **2105 PASS**, 2m31s (`full.log`); includes six guided-authoring tests from the updated target.
- Analyzer: no issues (`analyze.log`).
- Initial format check exposed upstream `cable_authoring_guidance_test.dart` formatting. Formatting-only commit `3e08c506`; final formatter PASS (`format-final.log`). No assertions changed after the full-suite run.
- Production native `flutter --no-version-check run --no-pub -d macos -t lib/main.dart`: build/start PASS. Initial version-check startup stall was interrupted and rerun with these flags; not classified as a product failure.

Raw logs and native evidence: `ElecX-p12-r3-evidence-20261113` beside the worktree. CI for previous PR head `6d34641b2b24519df396d244fc88493eec8f266c` was independently verified: all six workflows SUCCESS; this does not qualify the new head.
