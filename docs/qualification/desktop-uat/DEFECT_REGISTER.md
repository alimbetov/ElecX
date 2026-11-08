# Desktop defect register

Severity measures the requested user journey, not whether a feature was promised in an earlier milestone. Planned P12 scope gaps are explicitly distinguished from regressions. Screenshot filenames refer to `artifacts/desktop-uat/screenshots/`.

## D01 — P2 — Circuit inspector overflows and hides actions

- Screen: desktop right inspector and compact end drawer.
- Reproduce: create a room; place board and socket; connect socket to board; inspect connected load at 1280×800. Include canonical room semantics and warnings. Full screen also reproduces.
- Expected: warnings and load/cable/protection actions remain reachable by scrolling; catalog retains usable space.
- Actual: yellow/black RenderFlex overflow; “BOTTOM OVERFLOWED BY 135 PIXELS” in the 1280×800 view; action buttons below the viewport. Full screen still overflows by 31 px.
- Evidence: `13-connected-load-overflow.png`, `17-editor-fullscreen.png`, `19-reopened-properties.png`.
- Cause: unbounded natural-height semantics/overview/circuit children precede an Expanded equipment panel in a constrained Column.
- Dart: `lib/src/features/editor/unified_workspace_editor_screen.dart`, new `engineering_inspector_panel.dart`; existing `room_circuit_panel.dart` content exposes the issue.
- Fix: shared bounded, scrollable context section above independently scrollable equipment/selection panel, reused in desktop and drawer.
- Status: FIXED; 3 widget regression cases pass; native GUI retest evidence recorded in FINAL_REPORT.

## D02 — P2 — Primary structural buttons are disabled without explanation

- Screen: PROJECT navigator.
- Reproduce: create/open canonical production project, select site/building/level; inspect `+ Building`, `+ Level`, `+ Room`.
- Expected: usable dialogs/actions or an explanation and link to supported wizard/rectangle workflow.
- Actual: disabled buttons; creating rooms requires discovering the unlabeled rectangle toolbar tool and two-click interaction.
- Screenshot: `06-project-tree.png`, `09-editor-1280x800.png`.
- Cause: `CanonicalEditorProductionHandle` does not provide `requestBuilding/requestLevel/requestRoom`; navigator requires these callbacks. This is a production UI integration gap, not a proven regression.
- Dart: `canonical_editor_production_bootstrap.dart`, `canonical_editor_production_runtime.dart`, `canonical_project_navigator.dart`, `project_structure_authoring_controls.dart` (all under lib/src/features/editor).
- Proposed fix: wire validated request dialogs to existing canonical authoring and ownership callbacks; for Room expose the existing geometry-authoring path and explain why a geometryless Room cannot yet open. Qualify navigation/materialization and save/reopen together. Do not generate fake room boundaries in a dialog.
- Status: OPEN. Existing rectangle and wizard alternatives work; wiring structural entity creation alone would not complete geometry/materialization acceptance.

## D03 — P2 — Requested project metadata and naming workflow incomplete

- Screen: New Project, navigator, room semantics inspector.
- Reproduce: create project; look for Residential type and Apartment electrical design purpose; select room/site/level and look for rename.
- Expected: meaningful project metadata and discoverable naming of Site, Floor 1, Living Room, Kitchen, Bedroom, Bathroom.
- Actual: project name only; wizard has a building name, but no Type/Purpose; manually drawn rooms use Комната N, and no rename action was found in inspected navigator/semantics/context UI.
- Screenshot: `03-new-project.png`, `10-room-created.png`, `11-four-rooms.png`.
- Cause: minimal creation request contains only name/mode; semantics UI edits usage, not identity names. CUA text injection limits are separate and are not evidence of a product name-entry regression.
- Dart: `features/projects/project_hub_screen.dart`, `features/editor/canonical_project_navigator.dart`, `features/editor/space_semantics_inspector.dart` (under lib/src).
- Proposed fix: add supported metadata fields only through established aggregate/schema contracts, and qualified name editing through the existing canonical mutation owner. This session does not alter persistence schema.
- Status: OPEN, product scope gap.

## D04 — P1 — P12 engineering review cannot be completed through production UI

- Screen: POWER group inspector / project wizard.
- Reproduce: create board and socket, connect group, enter power/protection, look for P12 evidence selection, typed Engineering Diff, consistency/safety review and production Apply explanation.
- Expected: discoverable read-only P12 review, diagnostics, and an explanation of blocked Apply.
- Actual: prototype group forms and warnings exist, but no P12 preview/diff/safety-review UI route was found. `Расчёт` is disabled without a visible adjacent reason. User cannot finish the specified evidence-backed engineering review.
- Screenshot: `17-editor-fullscreen.png`, `19-reopened-properties.png`.
- Cause/evidence: `EngineeringProposalDiff`, `EngineeringReservedProjectCommand`, safety/evidence gates exist in application/domain; no corresponding P12 feature-screen references found. Apartment preview requires a source-backed engineering pipeline; production bootstrap does not fabricate it.
- Dart: `lib/src/application/project/engineering/engineering_proposal_diff.dart`, `engineering_reserved_project_command.dart`, `lib/src/features/editor/room_circuit_panel.dart`, `canonical_editor_production_bootstrap.dart`; `lib/src/features/projects/apartment_engineering_preview_panel.dart` is a separate P9 surface.
- Proposed fix: next sprint, wire read-only review to authoritative inputs/evidence and typed canonical projections; show exact missing gates and next actions. Keep `readyToApply == false` until qualified.
- Status: OPEN — PLANNED P12 CAPABILITY GAP, NOT a regression or a request to unblock Apply. Current architecture contract explicitly marks Apply unqualified. Completing this requires authenticated evidence/runtime composition and is outside a safe layout/navigation fix.

## D05 — P2 — Large canvas HUD obscures component controls

- Screen: surface editor at 1280×800.
- Reproduce: select placed board/socket, inspect lower-left nudge controls and bottom-right placement/status HUD.
- Expected: selected-component actions and canvas targets remain unobstructed.
- Actual: large status/placement HUD extends across the component control card; room-wall content near the bottom is covered. The message-heavy inspector further reduces useful context.
- Screenshot: `12-board-inspector.png`, `13-connected-load-overflow.png`.
- Cause: independently positioned lower overlays do not coordinate their occupied area.
- Dart: `unified_workspace_editor_screen.dart`, `engineering_placement_cursor_hud.dart`, `surface_canvas.dart` under lib/src/features/editor.
- Proposed fix: a shared responsive overlay area, compact/collapsible status HUD and reserved component-action region; qualify pointer hit targets at 800 and 1280 widths.
- Status: OPEN. Not changed alongside the inspector fix because placement cursor interaction and component nudge hit targets need their own qualification.

## D06 — P2 — First-access instructions do not say how to obtain a PIN

- Screen: quick unlock.
- Reproduce: launch as a new engineer with no previous account/PIN.
- Expected: explain the actual prototype action (any four digits) or provide PIN enrollment/help.
- Actual: four placeholders and “local quick unlock” explanation, no enrollment or explicit entry instructions; code accepts any four digits. Auditor used 1234 through the real keyboard.
- Screenshot: `02-pin.png`.
- Cause/Dart: `lib/src/features/auth/pin_unlock_screen.dart`, `lib/src/features/app_shell_localizations.dart`.
- Proposed fix: explain the prototype behavior clearly without implying authentication or changing security semantics.
- Status: OPEN, onboarding copy gap.

## D07 — P3 — Mixed UI languages and internal vocabulary

- Screen: Russian hub → English wizard → mixed-language CAD inspector.
- Reproduce: create project on en-KZ macOS; inspect labels and warnings.
- Expected: a consistent locale and engineer-facing terminology.
- Actual: Проекты / Create building / ROOM SEMANTICS / Canonical wall editor недоступен / SELECT READY. Recovery timestamp exposes microseconds.
- Screenshot: `01-project-hub.png`, `04-preview-empty.png`, `12-board-inspector.png`.
- Cause/Dart: hardcoded strings across `project_hub_screen.dart`, `space_semantics_inspector.dart`, `device_catalog_panel.dart`, `room_circuit_panel.dart`, localization classes.
- Proposed fix: route strings through localization, translate unavailable reasons into next actions, format dates.
- Status: OPEN.

## D08 — P2 — Compact engineering drawer has no visible opening action

- Screen: editor at 800×628 logical points.
- Reproduce: open a project with a selected/connected load in a compact window; look for engineering properties and group actions.
- Expected: an explicit button opens the configured right inspector drawer.
- Actual: Scaffold has an endDrawer, but custom AppBar actions suppress the automatic drawer button; the equipment toolbar opens a placement menu instead. Inspector actions cannot be discovered without resizing or knowing the edge gesture.
- Screenshot: `05-empty-editor.png` (compact toolbar) and post-fix evidence in SCREENSHOT_INDEX.
- Cause/Dart: `lib/src/features/editor/unified_workspace_editor_screen.dart`, `_WorkspaceAppBar` explicit actions with no compact inspector action.
- Fix: explicit compact `project-inspector-open` button using the existing Scaffold endDrawer. No change to discipline/circuit semantics.
- Status: FIXED; widget navigation regression plus native integration coverage, and GUI retest.

Counts: P0 0; P1 1 (planned capability gap); P2 6 (2 fixed, 4 open); P3 1 open. No P0/data-loss regression observed. No claim that every subsystem was exhaustively tested.
