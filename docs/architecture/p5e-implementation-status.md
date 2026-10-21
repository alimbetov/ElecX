# P5E Room Surface Navigator — implementation status

Branch: `feat/project-structure-authoring`

Executable qualification SHA:

```text
e699b7244ececf75b3371b9097e3f3f3c4ca7a18
```

## Status

**P5E implementation: DONE + HARDENED on Flutter qualification.**

The macOS Desktop workflow remains part of the branch closure gate. This status record must not be read as a claim that macOS passed until that workflow reports success for the qualified code line.

## Production architecture

P5E is a local surface-orientation aid for exactly one canonical-selected Room.

```text
ProjectNavigationState.selectedSpaceId
            │
            ▼
CanonicalEditorWorkspaceBinding
            │ exact SpaceId -> legacy Space binding
            ▼
EditorController.selectedSpace
            │
            ▼
RoomSurfaceNavigatorProjection
            │
            ├── Plan
            ├── Floor
            ├── Ceiling
            └── Wall 1..N
```

The navigator owns no independent Room, polygon, wall or opening model. Its 2.5D geometry is derived from `EditorController.selectedSpace`; wall engineering dimensions are derived through the existing room-surface resolver.

## Useful engineering UX delivered

The selected Room now exposes one collapsible Room Surface Navigator with:

- explicit Room name and plan extents in metres;
- current surface text in addition to visual highlighting;
- a lightweight 2.5D enclosure projection;
- direct click/tap selection of Floor, Ceiling and visible Wall planes;
- Plan / Floor / Ceiling controls;
- Wall 1..N controls derived from the real polygon edge count;
- previous/next Wall navigation independent of horizontal button visibility;
- Wall labels and derived wall lengths (`Wn · Lm`);
- transient pointer hover preview that never commits an editor surface;
- keyboard-focused mini-view navigation: Left/Right walls, Up ceiling, Down floor, Escape clears transient hover;
- normal Tab/Shift+Tab reachability of controls and 48dp button minimums;
- the same semantic commands in the compact/mobile drawer path.

## Correctness hardening

### Surface navigation is not engineering dirty state

`showPlan`, `showFloor`, `showCeiling`, `showWall` and surface-to-surface navigation now emit a narrowly classified transient surface-navigation notification.

`UnifiedWorkspaceEditorScreen` excludes that notification from:

- project revision increments;
- Saved -> Modified transitions;
- recovery autosave scheduling;
- structural shell rebuilds.

The canvas and Room Surface Navigator listen directly to the editor controller, so surface navigation still updates immediately without rebuilding the Project Navigator.

A production regression test proves a saved document remains `Saved` through Floor -> Wall -> Plan navigation.

### Stale wall selection fails closed

If a geometry change removes the currently addressed transitional wall index, the Room Surface Navigator does not silently bind that number to another physical wall. It validates again post-frame and falls back deterministically to Plan when the stale condition remains true.

### Arbitrary polygon rooms

Wall count is derived from the selected Room boundary. L-shaped and >4-wall rooms are qualified without a rectangular/four-wall assumption. Wall traversal uses the real boundary count.

### Single source of truth

Surface selection is always applied through the existing `EditorController` surface commands. Canvas/editor selection and Room Surface Navigator therefore share one active surface state rather than synchronized widget booleans.

## Qualification matrix

| Scenario | Qualification |
| --- | --- |
| RSN01 no Room -> hidden | `room_surface_navigator_test.dart`, production wiring |
| RSN02 selected Room -> one RSN | production wiring |
| RSN03 canonical selected `SpaceId` affinity | production + integration wiring |
| RSN04 Floor activation | direct control + 2.5D hit test |
| RSN05 Ceiling activation | direct control + 2.5D hit test |
| RSN06 exact Wall N activation | wall controls + 2.5D wall hit test |
| RSN07 editor/canvas surface -> RSN highlight | `room_surface_navigator_test.dart` |
| RSN08 Plan action | unit + production tests |
| RSN09 understandable without color | current-surface text, labels, semantics |
| RSN10 >4 polygon walls | L-shaped qualification |
| RSN11 no four-wall hardcode | L-shaped qualification |
| RSN12 collapse preserves Room/surface | shell/widget qualification |
| RSN13 expand restores current projection | shell/widget qualification |
| RSN14 collapse/expand does not dirty project | production wiring qualification |
| RSN15 hover creates no mutation/Undo/surface commit | hover qualification |
| RSN16 stale removed wall fails closed | `room_surface_navigator_stale_wall_test.dart` |
| RSN17 Room switch rebuilds selected projection | integration hardening |
| RSN18 local wall navigation preserves Project-tree location | integration hardening |
| RSN19 keyboard reach + activation | integration Tab/Space + focused mini-view arrows |
| RSN20 compact/mobile uses same semantics | compact drawer integration |
| RSN21 no previews for non-selected Rooms | one RSN below the canonical tree |
| RSN22 no independent room geometry state | production implementation boundary |
| RSN23 no Web/browser-specific path | native Flutter implementation only |

## Regression suites

Primary P5E suites:

```text
test/room_surface_navigator_test.dart
test/room_surface_navigator_stale_wall_test.dart
test/room_surface_navigator_production_wiring_test.dart
test/room_surface_navigator_integration_hardening_test.dart
```

For executable qualification SHA `e699b7244ececf75b3371b9097e3f3f3c4ca7a18`, Flutter workflow #1985 passed:

```text
dart format                         PASS
flutter analyze / verification      PASS
flutter analyze / quality           PASS
flutter test / verification         PASS
flutter test / quality              PASS
```

## Deliberate P5E -> P7 boundary

P5E does **not** introduce a persisted external wall identity.

`wallIndex` remains a transitional runtime address scoped to the exact canonical-selected `SpaceId`. It is never promoted to a durable engineering identity by the Room Surface Navigator.

The following remain P7 responsibilities:

- stable `BoundaryEdgeId` ownership;
- edge lineage across polygon edits/split/merge;
- durable wall-host identity;
- opening/component host migration after boundary edits;
- wall-host persistence and remapping.

This prevents P5E navigation UX from prematurely creating a second wall/domain model.

## Closure criterion

P5E is ready to hand off to the next architecture stage when the final code-qualified branch line has both complete Flutter and macOS Desktop workflow success. Any later production code change in P5E reopens that gate.
