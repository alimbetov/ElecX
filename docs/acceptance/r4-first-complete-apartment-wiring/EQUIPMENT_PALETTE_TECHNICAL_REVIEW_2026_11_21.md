# ElecX R4 — Equipment Matrix Technical Re-Audit

**Branch:** `feat/r4-first-complete-apartment-wiring` (sole working branch)  
**Release:** HOLD; no new branch, no merge to `main`  
**Scope:** Horizontal Equipment Matrix, Engineering Inspector, palette drag-and-drop onto plan/surface, keyboard accessibility.

## Baseline and exact evidence

- Before fixes, GitHub Actions workflow `44798611297` at `7ae44d7261a15bffda43aa551e270c779db3ccf7` finished **FAIL** in both `quality` and `verification`: 2149 tests passed, 2 failed.
- Failed tests: `horizontal_equipment_palette_test.dart` (search `socket.general` returned an empty group), and `room_surface_navigator_integration_hardening_test.dart` (Tab traversal budget exhausted before reaching the floor navigation button).
- GitHub Actions workflow `44799980163` at `8ad4c8af7e78f77f39bbb9a51200dc5d3a8e5253` subsequently returned **SUCCESS**, 2151/2151 tests PASS on both jobs, after adding catalog-ID search and broadening the keyboard traversal regression coverage.
- **IMPORTANT:** The PASS above is for that exact SHA, **not** the subsequent drag validation and integration tests. Do not apply its result to a newer commit.

## Technical fixes and rationale

| Severity | Issue | Change |
|---|---|---|
| P1 | Palette search did not cover internal catalog IDs, diverging from existing vertical catalog | Search by `entry.id` in addition to name/code, preserving case-insensitive matching |
| P1 | Horizontal palette adds legitimate focusable controls, invalidating an old fixed Tab budget | Extended Tab traversal regression to 180 attempts; requires separate human keyboard UX check because making the test pass alone is insufficient |
| P1 | Plan wall drop checked openings only by exact `RoomSurfaceRef` equality, missing mixed canonical/legacy hosts | Match same-space boundary IDs or validated wall ordinal; reject structural opening hit |
| P1 | No negative proof that locked electrical layers reject palette drops | Added locked-layer drag regression |
| P1 | No test for drag onto apartment plan, only active surface | Added filtered distribution board drag/drop integration on `SpatialCanvas` |
| Quality | Formatter gate repeatedly rejected new files | Applied exact `dart-format.diff` corrections |

## Architectural findings

1. The horizontal palette reuses `ComponentCatalogSession`; it must not create a competing catalog, duplicate equipment definitions or persist presentation state in project data.
2. Desktop Inspector uses `EngineeringInspectorPanel(showCatalog: false)`. The old vertical catalog remains for compact/mobile `endDrawer`; this is intentional responsive behavior.
3. `EditorShellState.equipmentPaletteExpanded` is transient, suppressed in Focus mode; toggling must not affect project revision, undo, connection graphs or persistence.
4. `EquipmentPaletteDragData` holds only `catalogId`; drop must re-fetch the authorized catalog item and validate active surface, geometry, electrical layer lock/visibility, wall profiles and physical openings.
5. `CatalogComponentPlacement.placeCatalogComponent` is the only commit path for dropped equipment. It uses P2 command history; verify saved project and Undo/Redo separately.
6. The current plan drop chooses a wall if near a valid segment, otherwise places only on explicitly compatible floor/ceiling surfaces. Known outstanding UX gaps: no visible INVALID drop ghost, no documented nearest-wall preference in ambiguous corners, and incomplete live native drop evidence. These are not claimed PASS.
7. Keyboard reachability is demonstrated by automated Tab traversal after accommodating new controls, but target acquisition effort and screen-reader flow need native accessibility qualification.

## Required gate matrix

| Gate | Evidence required |
|---|---|
| EQ-01 | Expand/collapse palette, groups and horizontal scrolling without canvas resize errors |
| EQ-02 | Search by name, code and catalog ID; group filters stable |
| EQ-03 | Drag socket onto compatible wall, correct physical position and retained componentTypeId |
| EQ-04 | Drag floor-compatible item onto plan inside room |
| EQ-05 | Reject locked/hidden electrical layer, structural opening, invalid host, outside plan |
| EQ-06 | Keyboard Tab from shell to Room Surface Navigator, Space activates selected surface without excessive effort |
| EQ-07 | Correct Undo/Redo; save and reopen retains equipment and coordinates |
| EQ-08 | Native macOS mouse drag with accurate drop position, zoom/pan; no regressions to ports, cable routes or Room Semantic |
| EQ-09 | Same-SHA `dart format`, `flutter analyze`, P8 NFR and full `flutter test` GREEN in both CI jobs |

## Mandatory native check

```bash
git switch feat/r4-first-complete-apartment-wiring
git rev-parse HEAD
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/horizontal_equipment_palette_test.dart
flutter test test/room_surface_navigator_integration_hardening_test.dart
flutter test
flutter run -d macos -t lib/main.dart
```

Record screenshots/video of: horizontal scrolling, category/group collapse, valid wall drop, invalid opening drop, floor-plan drop, save/reopen and keyboard navigation. If GUI is unavailable, status is `NATIVE NOT QUALIFIED`.

**Release decision:** keep `main` on HOLD until all listed mandatory automated checks and full R4 Native Golden Journey are evidenced on the exact integration SHA.
