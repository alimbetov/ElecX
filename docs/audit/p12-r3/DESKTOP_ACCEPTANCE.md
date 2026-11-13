# Native macOS production acceptance

Date 2026-11-10. Production runtime was built from audit worktree with `flutter run -d macos -t lib/main.dart` after production-fix commit 13e32a7f. Later changes are tests/reports only. No seeded controller/test-only entrypoint was used for the acceptance app.

Used the existing `ElecX Multi-Surface Routing Acceptance` project previously created through production UI, ID `project-hnz7xi8qfs-ha7o3x8y3wbh`. Its 9 components and local Wall→Ceiling route are genuine saved UI data, not the 3-level domain fixture. Original synthetic project snapshot was preserved before Save.

| Journey | Result | Native evidence |
|---|---|---|
| main.dart startup, PIN, Hub | PASS | 01-production-hub.png |
| Open existing project, ceiling route | PASS | 02-ceiling-route.png |
| Switch to Wall and see other span | PASS | 03-wall-route.png |
| Routing tool, explicit source/target ports | PASS for controls | 04-validation.ax.txt |
| Impossible jump from wall mid-height to ceiling | PASS rejection | Complete explicit ports then Finish: physical transition diagnostic, no route committed; 04-impossible-transition-rejected.png |
| Cross-room loads | BLOCKED, honest diagnostics | UI lists 7 compatible loads but states electrical compatibility does not confirm a physical passage; canonical adjacency/construction/approved transition required |
| Cancel draft, Save | PASS | schema v9, one original route retained |
| Quit, process gone, main.dart restart, Open | PASS | audit executable process filter returned exit 1/no matches before restart; 05-reopened-route.png |
| Repeated Save after Reopen | PASS | native-reopen-comparison.json: components/routes/building identical, original route IDs/geometry retained |
| Missing slabs after migration | PASS fail-closed storage | canonicalSlabs remains {}, never reconstructed |
| P12 read-only diagnostics | PASS safety state | 06-p12-safety-review.png; source absent, 0 P11/P12/RCD, Apply unavailable |
| Three-level Slab/Core route authoring and qualification statuses | BLOCKED | No complete authoring/status journey exposed in inspected editor; no GUI VALID claim based on seeded domain fixture |

Verdict: basic native editor smoke PASS; full requested multi-level Desktop qualification PARTIAL/BLOCKED. Domain persistence/qualification regressions are green but cannot satisfy this missing native journey. Automatic path_provider integration smoke passed separately (1 test). No full production main.dart integration harness for three-level authoring was fabricated.

Screenshots and raw logs are kept locally in `/Users/ruslanalimbetov/Documents/electra/ElecX-p12-r3-evidence-20261110/`; manifest hashes are committed, temporary logs/build artifacts are not. This is a local evidence location, not an uploaded artifact URL.

## 2026-11-13 production runtime rerun

Rebuilt/reran the real `lib/main.dart` after D4 changes and integration of target `981dfe59`. PIN/Hub PASS. Hub contained a newer user autosave (13 components, one route, revision 28); it was left untouched. Created a separate empty project through the production UI (the displayed default name remained «Новый проект»), drew a 5.40 × 3.30 m room and activated the cable tool. The new Source / Path / Receiver guidance and surface/Cancel controls rendered at the normal desktop size; empty-draft Finish remained disabled. Escape returned to SELECT. Evidence: `01-native-guided-cable-start.png` and matching AX text in the Nov13 evidence directory.

This rerun verifies startup and initial guidance only. It does not prove completed routing, compact-window layout, or native three-level qualification. D4 is verified by production-controller regression, not a claimed native status inspection. Full three-level Desktop gate remains BLOCKED; previous Nov10 Save/Reopen evidence remains historical.
