# Multi-surface routing acceptance — 2026-11-09

Baseline: `9f15d9854d1a43c70d3d7f5d8b787dda4f459c31`, branch `feat/p12a8-engineering-preview-diff`, macOS 15.6 arm64, Flutter 3.47.7 / Dart 3.13.5. Worktree `ElecX-desktop-uat`; original checkout and its changes preserved. No merge to main. Baseline analyze passed; 2070 tests passed. Additional focused P12/manual-routing regression: 11 tests passed. Native production-entry integration journey passed (see logs/native-bootstrap-settled.txt). Ordinary GUI was rebuilt and launched with `flutter run -d macos -t lib/main.dart`; screenshots are actual native captures.

## Verdicts

| Area | Verdict | Meaning |
|---|---|---|
| Desktop UX | PARTIAL | Five exact rooms and nine correctly hosted objects can be created, saved and reopened; full apartment engineering cannot be completed. |
| Multi-Surface Cable Routing | BLOCKED | Local Wall→Ceiling control works; required cross-room routes lack qualified passages and upstream UI connectivity. |
| EngineeringGraph Integrity | PARTIAL | Local prototype endpoints, deletion cascade, undo and persistence checked; canonical C-01…04 never created. |
| P12 Engineering Review | PARTIAL | Production read-only entry and honest safety diagnostics work; authoritative proposal and stale-proposal GUI journey unavailable. |

## Project and geometry

Project `ElecX Multi-Surface Routing Acceptance`, building `Residential Building A`, `Level 1`, project ID `project-hnz7xi8qfs-ha7o3x8y3wbh`. Project and rectangles were created by a native integration harness tapping production widgets/canvas and entering form text; no repository/domain seeding. Subsequent equipment, routing and adversarial actions used native GUI. Room names remain default production labels: Room 1 = Corridor 6×1.5 m, Room 2 = Living 5×4, Room 3 = Bedroom 4×3.5, Room 4 = Kitchen 4×3, Room 5 = Bathroom 2.5×2. Read-only audit verifies exact dimensions, shared geometric edges and no positive-area overlap. Geometric contact does not establish canonical adjacency. Inspector says “No canonical openings / No canonical adjacency”; wall editor says unavailable.

DB/S/L names below are acceptance aliases, not claimed persisted labels. Actual component IDs and default labels are in `reopen-comparison.json` and `before-restart.json`. DB-01 is Wall 1 in Corridor; S-01…04 are Wall 1 in their rooms (300 mm); L-01…04 are Ceiling hosts. Lighting catalog records system `lighting`; no assertion that UI authored a canonical POWER discipline/circuit.

## Required routes: no false PASS

| Route | UI | Canonical model | Persistence | Evidence / severity |
|---|---|---|---|---|
| ROUTE-01 Floor→Living→Wall | BLOCKED | BLOCKED | BLOCKED | 05,09,10; P1 R-D01/R-D02 |
| ROUTE-02 Ceiling→Kitchen→Wall | BLOCKED | BLOCKED | BLOCKED | 03,05,08; same missing upstream/passages; complete path not authored |
| ROUTE-03 Corridor→Living→Bedroom | BLOCKED | BLOCKED | BLOCKED | 02,10; no qualified boundary passages |
| ROUTE-04 Floor→Wall→Ceiling→Living | BLOCKED | BLOCKED | BLOCKED | 07–10; local transition control is not this route |
| ROUTE-05 branched lighting | BLOCKED | BLOCKED | BLOCKED | 07,12; no four-load canonical C-03/junction topology authored |

Evidence numbers refer to PNG prefixes in the artifact manifest. Shared blocker evidence is intentional: five full routes were NOT executed or persisted. Canonical model BLOCKED describes acceptance of these instances, not absence of every domain capability in source.

## Positive control and geometry

UI connected Corridor light to Corridor board: prototype `circuit-1`, `cable-1`, `route-1`, source `component-1-db-general/power-out`, target `component-9-light-general/power-in`. Wall local (3000,1500)→(3000,3000); Ceiling (3000,0)→(3000,750), mm. Physical length 1500+750=2250 mm, reserve 5%=2362.5 mm; UI rounds 2.25/2.36 m. Both surfaces share SpaceId. Existing surface transforms represent the common wall-top/ceiling-edge point; independent 3D numerical validation was not executed. No penetration/vertical-core legs. Route and endpoint IDs are stable; segments have no dedicated ID and anchorIds are empty. Ordered list provides segment order, not canonical CircuitId on each segment. This does not meet the requested stable segment/circuit contract.

Wall and Ceiling segments remain visible before/after restart. Floor has no segment in this control. Plan shows room geometry but no equipment/route overlay in the observed view (15). Full-route selection, all-board routing and distinct canonical-circuit visualization remain unqualified.

## Save / Quit / Reopen

Saved via UI. Cmd+Q was attempted; process verification was inconclusive while multiple Flutter sessions were active. Detached those sessions, used native Quit menu, then exact executable process check returned no matches (exit 1). Started main.dart again, unlocked, opened the matching 9-component/1-route project. Do not interpret earlier blank AX or a failed sandbox process lookup as proof of termination.

| Object | Before Save | After reopen | Result |
|---|---|---|---|
| DB-01 | component-1-db-general, Wall, 3000/1500 | identical | PASS |
| C-01…04 | absent | absent | BLOCKED |
| ROUTE-01…05 | absent | absent | BLOCKED |
| Local control | route-1/cable-1/prototype circuit-1 | identical | PASS, limited scope |
| Surface transitions | local Wall→Ceiling, 2 segments | identical | PASS, limited scope |
| Components | 9, positions/hosts/ports/IDs | identical | PASS |
| Rooms | 5, exact polygons | identical | PASS |
| P12 Review | canonical v6; 0 circuits/selections/RCD; source absent | no canonical proposal created | PARTIAL; post-restart dialog not rechecked |

Read-only JSON comparison: entire `building` and `p2` structures equal before/after restart. This verifies retained file content plus successful native loading; no fabricated cross-room objects were inserted.

## Adversarial coverage and limits

Invalid manual Wall→Floor draft was rejected on Save with explicit compatible-port / physically-confirmed-transition diagnostic; draft retained. Selecting another room cancelled the uncommitted draft. Deleting connected L-04 removed route and prototype bundle: persisted 8 components/0 routes/0 bundles. Undo restored exact original components/routes/bundles, Redo removed again, Undo restored then Save. Reopen confirmed no loss.

Not executed: changing upstream board, deleting a qualified routed wall, moving a load to another wall, incompatible canonical circuits, forced duplicate connection, stale authoritative P12 proposal. These depend on unavailable canonical authoring or need dedicated follow-up; they are NOT PASS. Existing connected-load panel replaces Connect with group controls, but this alone does not qualify duplicate prevention.

## Seven product answers

1. A single engineer can draw the five-room shell and place equipment; cannot complete the specified apartment design through this UI.
2. Common-board routes from different rooms were blocked; same-room control works.
3. One Wall→Ceiling route survives restart; general cross-room/multi-surface persistence is unqualified.
4. Penetration/opening domain mechanisms exist; this UI-created apartment has no qualified canonical passages.
5. Requested four-light branching is unqualified/blocked; binary routes are not junction topology.
6. Source has physical transition/penetration validation, canonical engineering circuits and P12 snapshot gates; their complete authoring/provider journey is not available in this acceptance instance.
7. See architecture contract: canonical ownership, UI circuit membership/upstream, construction passages, stable segment identity and junction integration, dependency invalidation and authoritative proposal source.

No runtime safety, sqlite3, SHA verification, persistence schema or production Apply changes. No unsafe “remove same-room guard” patch. This change supplies reproducible UI regression and honest acceptance artifacts; it does not implement missing routing architecture.
