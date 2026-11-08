# Multi-room journey matrix

Baseline and project: see MULTI_SURFACE_ROUTING_FINAL_REPORT.md. PASS is limited to observed behavior.

| Journey | Result | Evidence |
|---|---|---|
| Production project/building/Level 1 forms | PASS | native-bootstrap-settled.txt, target-project.json |
| Five exact rectangles, no overlap | PASS | 02, ui-created-geometry.json |
| Named semantic rooms / DB-01 aliases | PARTIAL | Default room/object names retained; aliases only in audit |
| One board on Corridor wall | PASS | 04 |
| Four wall sockets | PASS | before-restart.json host audit; 05 |
| Four ceiling lights | PASS | 06,07, host audit |
| C-01…04 canonical POWER membership | BLOCKED | same-room board picker, P12 count 0 |
| Shared upstream across rooms | BLOCKED | 05; room_circuit_panel / connectLoadToBoard guard |
| Wall and Ceiling local control rendering | PASS | 07,08,13,14 |
| Floor local draft | PARTIAL | 09; rejected invalid commit |
| Cross-room draft continuation | BLOCKED | 10; room selection cancels draft |
| Plan equipment/route overview | FAIL | 15, no overlay in observed Plan view |
| Full-route one-action selection | NOT EXECUTED | No claim from source alone |
| All-board routes / circuit distinction | BLOCKED | No required canonical circuits |
| Invalid route commit | PASS | 09 AX diagnostic |
| Delete connected light/cascade | PASS, prototype | 11, delete-load-audit.json |
| Undo / Redo / restore / save | PASS, prototype | exact restored entities audit |
| Board change / wall deletion / host move | NOT EXECUTED | Follow-up required |
| Incompatible circuits / duplicate connection | NOT EXECUTED | canonical circuits unavailable |
| P12 diagnostics before/after P2 edits | PASS, read-only | 03,12: canonical v6 unchanged, honest 0 P11 |
| Stale authoritative proposal | BLOCKED | no production provider |
| Full process exit, main.dart restart, reopen | PASS | process audit + 13–15 + reopen-comparison.json |
| Required five routes | BLOCKED | prerequisite failures, not five successful creations |

NOT EXECUTED is a coverage label, not an acceptance verdict. Route-layer verdicts are in the final report.
