# Desktop user journey matrix

Date: 2026-11-08, Asia/Almaty. Baseline: `b4c4a85749d0ca3a9e912ad6256862078052f055`.
Native GUI observations and Flutter integration automation are distinguished. “Partial” never means the full requested acceptance case passed.
Screenshots are under `../../../artifacts/desktop-uat/screenshots/` from this directory (see SCREENSHOT_INDEX.md).

| Step | UI available | Executed | Result | Screenshot | Defects |
|---|---|---|---|---|---|
| Launch | Yes: local four-digit quick unlock, hub | Native close/relaunch, keyboard 1234 | PASS; real window and interactions confirmed | 02-pin, 01-project-hub | D06 |
| Create Project | Name and blank/demo/building wizard; no Type/Purpose | Native attempt; named creation additionally covered by native integration test | PARTIAL: requested metadata unavailable; CUA text insertion was unreliable, not counted as a product failure | 03-new-project | D03 |
| Site | Existing site tree node and Site Building Wizard icon | Native tree navigation | PARTIAL: no UI path found to name site Residential Site | 06-project-tree | D02, D03 |
| Building | New project building wizard; Site composition wizard entry | Native basic wizard generated/applied default building; native test uses Building A | PASS for basic wizard; advanced Site composition wizard not exercised end to end | 04-preview-empty, 06-project-tree; native test log | D02 |
| Rooms | Rectangle toolbar tool works via TWO corner clicks | Native four rooms, selection, Floor/Wall; integration test uses UI drawing | PARTIAL: four default names; no discoverable rename path to requested room names | 10-room-created, 11-four-rooms | D02, D03 |
| 2D Editor | Grid, snap, dimensions, selection, surface navigation, zoom controls | Native rectangles, dimensions, Plan/Floor/Wall, viewport resizing; zoom/pan retest recorded in report | PASS for exercised core; contextual right click produced no menu | 09-editor-1280x800, 10-room-created, 17-editor-fullscreen | D01, D05, D08 |
| POWER | Equipment filter, board/load placement, connect-to-board group, load/protection forms | Native board + socket + group + route + 1000 W/230 V + QF-1/16 A/2P | PARTIAL: P/U indicator and warnings work; cable dialog is a text specification, sizing button disabled; P12 selection preview absent | 12-board-inspector, 13-connected-load-overflow, 14-cable-dialog, 15-protection-dialog | D01, D04 |
| Preview | Building Preview/Changes; source-backed Apartment/P12 features have different readiness | Native basic wizard observation; integration generation and hidden Diff assertion | PARTIAL: building wizard is available; no production P12 Engineering Preview/Diff review route found | 04-preview-empty; native test log | D04 |
| Save/Reopen | Save icon, hub, persisted projects | Native save → Cmd+Q → fresh launch → unlock → open project | PASS for tested data: four rooms, board, socket, one route/group, load power and protection retained | 18-restarted-hub, 19-reopened-properties (+ AX transcript) | No data loss observed |

Strict matrix: 4 PASS, 5 PARTIAL, 0 unqualified PASS for the complete apartment electrical design scenario. P12 Production Apply was not invoked or bypassed. The ordinary geometry wizard Apply and user-entered prototype group protection are distinct from P12 production approval.


## Advanced routing retest — 2026-11-09

See [Multi-surface routing acceptance](MULTI_SURFACE_ROUTING_FINAL_REPORT.md) on baseline 9f15d985. P12 toolbar review now exists (supersedes earlier missing-entry finding); source remains unavailable and Apply blocked. Five-room/nine-component/local Wall→Ceiling save-reopen verified; required cross-room/canonical branching acceptance BLOCKED. Earlier basic UAT observations remain historical, not proof of advanced routing.
