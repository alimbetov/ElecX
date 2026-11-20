# UX-DIST-01 — Dynamic Wall Dimensions, implementation audit

**Branch:** `feat/r4-first-complete-apartment-wiring`  
**Status:** **IMPLEMENTED PARTIALLY; NATIVE NOT QUALIFIED**  
**Specification:** `UX_D1_DYNAMIC_WALL_DIMENSIONS.md` (Light CAD R1).  
**Development date:** 2026-11-20

## Implemented source changes

| Area | File | Evidence |
|---|---|---|
| Exact directional geometry | `lib/src/features/editor/wall_distance_guide_calculator.dart` | Ray-to-segment intersections against actual room polygon; first wall, concave support, skip zero length, optional opening veto |
| Plan integration | `lib/src/features/editor/editable_spatial_canvas.dart` | Selected component and valid drag preview → `PlanComponentMoveProjection.planPointFor` → `WallDistanceGuideCalculator` → drawing |
| Lightweight CAD | `lib/src/features/editor/cad_dimension_painter.dart` | Optional `lightweight`, `boxedLabel`, `opacity`; old call-site defaults unchanged |
| Transient overlay | `lib/src/features/editor/dynamic_wall_dimensions_overlay.dart` | Fade-in, deselect delay, hold snapshot, slow release fade, post-fade removal, `IgnorePointer`, clip to viewport, world camera projection |
| Hold state | `lib/src/features/editor/editor_controller.dart` | Ephemeral `ValueNotifier<bool>`, excluded from project serialization, cleared on edit cancellation, disposed |
| Toolbar | `lib/src/features/editor/unified_icon_toolbar.dart` | Independent momentary Distance button; pointer down/up/cancel, Space key down/up and application lifecycle release; existing persistent `dimensionsVisible` toggle retained |
| Tests | `test/wall_distance_guide_calculator_test.dart` | Rectangle, wall-mounted zero dimension, concave polygon, diagonal wall, invalid source, opening veto |
| Tests | `test/dynamic_wall_dimensions_overlay_test.dart` | Last valid snapshot held through deselect, fade and cleanup after release/deselect |

## Geometry declaration

The current `ElectricalComponentPlacement` has a surface-local **installation anchor**, `rotationDegrees`, type, label and electrical metadata, but **no proven physical outline/footprint**. Therefore the implementation intentionally measures from the **installation anchor** and draws a small `От точки установки` annotation. It would be false to call these dimensions clearances from physical device edges. The pure calculation API is isolated so a real footprint model can be added later without changing the drawing or hold machinery.

No change to cable paths, EngineeringGraph semantics, project persistence or domain revision is intended by the drawing features. Wall intersections that land on known door/window openings are suppressed instead of projecting past the opening.

## Requirement qualification

| Acceptance | Status | Notes |
|---|---|---|
| DW-01 Selection, 2–4 guides | CODE IMPLEMENTED | Desktop visual pending |
| DW-02 Exact physical footprint | BLOCKED | Footprint not in domain model; anchor-based substitute explicitly labelled |
| DW-03 Deselect fade | CODE IMPLEMENTED | Widget test added |
| DW-04 Hold pressed | CODE IMPLEMENTED | Native input not yet verified |
| DW-05 Release fade | CODE IMPLEMENTED | Widget test added |
| DW-06 Keyboard/focus/lifecycle | CODE IMPLEMENTED | Native keyboard qualification pending |
| DW-07 Moving device | CODE IMPLEMENTED | Valid preview recomputes guides; native dragging pending |
| DW-08 Pan/zoom | CODE IMPLEMENTED | World camera projection; native verification pending |
| DW-09 Concave/diagonal geometry | CODE IMPLEMENTED | Pure golden tests |
| DW-10 Opening/host rules | CODE IMPLEMENTED | Opening veto and no zero-length guide; full native qualification pending |
| DW-11 Light CAD visual/readability | NOT TESTED | Requires real macOS dark/light screenshots |
| DW-12 Port/cable/undo regression | NOT TESTED NATIVE | Overlay is pointer-ignored; R4 Golden Journey required |
| DW-13 Scene/dispose | CODE IMPLEMENTED | Verify in native lifecycle |
| DW-14 Persistence | NOT TESTED E2E | No new serialized properties |
| DW-15 Same-SHA CI | PENDING | Check latest `Flutter` Quality + Verification on exact SHA |
| DW-16 macOS native | NOT TESTED | No local macOS GUI access in current authoring environment |

## Test commands (required before release)

```sh
git switch feat/r4-first-complete-apartment-wiring
git rev-parse HEAD
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/wall_distance_guide_calculator_test.dart
flutter test test/dynamic_wall_dimensions_overlay_test.dart
flutter test
flutter run -d macos -t lib/main.dart
```

Capture native screenshots/video for selected, moved, deselected, held Distance, released Distance, dark/light themes and a full R4 apartment. Do not declare PASS without native evidence.

**Release gate:** `UX-DIST PARTIAL` until DW-02 physical dimension semantics are resolved and actual native E2E/CI proof is complete. **NO MERGE TO MAIN; NO NEW BRANCH.**
