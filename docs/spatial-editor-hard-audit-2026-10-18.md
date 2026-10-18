# ElecX spatial editor hard audit — 2026-10-18

## Scope

Audit of `feat/spatial-editor-foundation` from UI/UX, Flutter architecture, CAD interaction, rendering correctness and scalability perspectives.

## Severity summary

### P0 defects found and remediated

1. **Adaptive editor CI regression**
   - analyzer failed on flow-control lint in the new adaptive shell;
   - adaptive shell is now hardened with explicit blocks and clearer interaction state.

2. **False Undo/Redo affordance**
   - desktop AppBar exposed working-looking Undo/Redo buttons without a command history implementation;
   - removed from the active UI until command history exists.

3. **Opening editor regression**
   - adaptive Inspector lost the existing door/window type editor;
   - restored explicit `Door / Window` editing while retaining position, width, height and sill controls.

4. **Mutable-controller CustomPainter repaint bug**
   - painters compared old/new values through the same mutable controller instance;
   - this could suppress required repaints after selection/draft/opening changes;
   - plan and surface painters now capture immutable repaint snapshots/fingerprints.

5. **Wall-profile model/render mismatch**
   - wall notches, beams and sloped profiles existed in the model but wall elevation still painted a rectangle;
   - wall elevation now renders the actual persisted profile and clips grid, openings and cable route to it.

6. **Touch navigation parity gap**
   - Tablet/Mobile had responsive layout but not native CAD viewport navigation;
   - plan and surface canvases now support two-finger pan + pinch zoom through the same `WorldCamera` contract.
   - tap execution moved from `onTapDown` to `onTapUp` so a pinch does not accidentally create/select geometry.

### P1 UX improvements applied

- mobile/tablet editor menu exposes Snap and Dimensions state;
- route draft can be cleared from the global editor menu and Inspector;
- mobile viewport controls are compact and no longer consume a wide horizontal overlay;
- navigator explicitly shows selected room state and room count;
- “new room” action returns to Plan before activating room creation;
- Inspector has proper empty states rather than blank panels;
- wall/opening sections expose counts and stronger hierarchy;
- canvas context badge includes room + active surface + tool + snap state;
- status bar includes dimensions and route state;
- adjacent-room dialog explains direction and available host-wall length.

## Architecture decisions retained

- one project/domain model for Desktop, Tablet and Mobile;
- integer millimetres remain the persisted engineering coordinate system;
- `WorldCamera` remains the single viewport transform abstraction;
- plan/surface views remain projections of the same room/surface topology;
- invalid opening geometry is rejected before model mutation;
- spatial culling and semantic LOD remain in the render path.

## Remaining high-value work

1. Introduce a shared `EditorViewportController` so keyboard/toolbar commands and canvas-local controls operate the exact same camera instance.
2. Implement command history and only then restore Undo/Redo affordances.
3. Add direct manipulation handles for openings, room vertices and wall-profile vertices.
4. Integrate `SnapEngine` into cursor hover/placement with visible snap markers.
5. Improve custom-profile navigation so ceiling transitions follow the actual sloped/stepped top contour rather than the rectangular extent.
6. Add widget/golden tests for Desktop/Tablet/Mobile shells and profile rendering.
7. Eliminate repository-wide historical `dart format` debt so the strict quality gate can become green without a formatter mutation step.

## Manual acceptance pass

### Desktop

- resize window to >= 1180 px;
- navigator + CAD + inspector remain simultaneously visible;
- select room, wall and opening; verify edits repaint immediately;
- middle mouse pans; wheel zooms around cursor;
- custom wall profile is visibly non-rectangular.

### Tablet

- width 700–1179 px;
- navigator and inspector use drawers;
- two-finger pan and pinch zoom do not create geometry;
- Snap/Dimensions remain accessible through editor menu.

### Mobile

- width < 700 px;
- canvas remains primary surface;
- bottom toolbar switches tools;
- two-finger pan and pinch zoom work on plan and wall/floor/ceiling views;
- selected room/surface/tool remains visible through context badge;
- inspector remains accessible without permanently reducing canvas area.
