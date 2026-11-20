# ElecX R4 — Room Semantic / Room Dimensions / Distance Guides Technical Re-Audit

Date: 2026-11-20  
Branch: `feat/r4-first-complete-apartment-wiring` (the sole working branch)  
Disposition: **P0/P1 verification pending on final SHA; no merge to main**

## Scope audited
- `EngineeringInspectorPanel` — Room Semantic disclosure UI.
- `RoomDimensionsDialog`, `UnifiedEditorIconToolbar`, `UnifiedWorkspaceEditorScreen`, `EditorController` — room authoring.
- `RoomRectangleAuthoringService` and canonical timeline / persistence owner.
- `DynamicWallDimensionsOverlay` — fade, hold, lifecycle.
- Corresponding automated and production UI regression tests.

## Evidence and defects

Previous full GitHub Actions run `44785856684` (`d56964e123d9256ee3fdc2d2a88af3b069173e2f`) recorded **2145 passing tests and 4 failing tests**. It is not a release PASS.

| Severity | Evidence | Root cause / remediation |
| --- | --- | --- |
| P1 | `room_dimensions_toolbar_integration_test.dart` expected user label but got `Комната 1` | Legacy `EditorController.addRectangleRoom` ignored a dialog name. Added named optional argument and passed explicit result.name from the dialog. |
| P1 | `pre_p12_production_reachability_qualification_test.dart` could not find original `Комната (R)` toolbar control | The toolbar switched to explicit dimensions dialog while the qualified production UI regression still exercised two-click authoring. Updated the regression to use the real dialog, assert canonical commit and preserve Undo/Redo coverage. |
| P1 | `dynamic_wall_dimensions_overlay_test.dart` post-fade snapshot remained in widget tree | Cleanup relied on status/post-frame timing. Added cancellable, duration-bound cleanup that is reset on hold, selection change, scene change and dispose. |
| P1 / quality | CI formatter discrepancies and unused import after test migration | Applied exact `dart-format.diff` from GitHub Actions; removed stale `SpatialCanvas` test import. |

### Architectural review

1. Room Semantic is a **transient, collapsed-by-default** panel section; expanding/collapsing must not modify project state, selection, canonical revision or save status.
2. New room authoring form accepts width, length, x/y in **model mm**, with validation (minimum 300 mm). In canonical runtime it uses the **existing** `RoomRectangleAuthoringService`, `wizardMutations`, commit history and supplied persistence callbacks; do not write directly to the legacy project under an active canonical owner.
3. Legacy fallback must preserve user-given name and remain compatible with the legacy two-click rectangle authoring API. Explicit dimensions control is a separate input path; keyboard selection of the older tool remains available where implemented.
4. Distance Guides are **noninteractive, nonpersistent annotations**. Hold/fade timers must never outlive the widget or recreate stale room geometry. This qualification does not assert that measurement from physical device footprints is available: it currently measures the installation anchor.
5. No changes to `main`; no new branches; R4 Native Golden Journey continues to require independent real GUI proof.

### Required verification

```sh
git switch feat/r4-first-complete-apartment-wiring
git rev-parse HEAD
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/room_semantics_collapse_and_dimensions_test.dart
flutter test test/room_dimensions_toolbar_integration_test.dart
flutter test test/pre_p12_production_reachability_qualification_test.dart
flutter test test/dynamic_wall_dimensions_overlay_test.dart
flutter test
flutter run -d macos -t lib/main.dart
```

Record CI results from **the exact final SHA**, not an earlier passing intermediate revision. The previous pass/fail figures above are **historic evidence**, not the acceptance result. Qualify actual native desktop (Room Semantic toggle, room with specified 4200x3600 mm and name, save/reopen, canonical Undo/Redo, Distance hold/deselect) with screenshots and GUI evidence. Until those gates pass, status is **PARTIAL / NATIVE NOT QUALIFIED**.
