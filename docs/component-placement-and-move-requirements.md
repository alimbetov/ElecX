# Component placement and movement UX requirements

## Goal

ElecX must expose one engineering interaction model for placing and moving components on room surfaces while adapting input ergonomics for desktop mouse/keyboard, tablet stylus/touch and mobile touch.

The persisted model remains surface-local millimetres. Screen pixels and device-specific gestures are input adapters only.

## Canonical interaction model

```text
catalog selection / selected component
              ↓
      PlacementSession / MoveSession
              ↓
      raw pointer / keyboard input
              ↓
            SnapEngine
              ↓
 validation + live engineering dimensions
              ↓
             preview
              ↓
       commit / cancel / repeat
```

### Invariants

1. A component is always bound to one `RoomSurfaceRef`.
2. Placement and movement never persist viewport pixels.
3. Preview mutation must be reversible until commit.
4. `Esc` cancels the active placement/move interaction.
5. `Enter` commits the current valid placement/move interaction.
6. Invalid positions are visible but cannot be committed.
7. Cross-surface movement is explicit. A wall-only socket cannot silently jump to floor or ceiling.
8. The same placement/move domain session is used by mouse, keyboard, stylus and touch.
9. Snap and dimension overlays use the current draft position, not the last persisted position.
10. Placement from `ComponentCatalog V2` preserves the canonical `componentTypeId`.

## Desktop

### Placement

1. Select equipment in the right catalog.
2. ElecX activates a placement cursor on a compatible surface.
3. Mouse move updates the ghost symbol through `viewportToSurface → SnapEngine → placementCursor.moveTo`.
4. Click commits the current valid position.
5. Repeated placement may remain active when Repeat is enabled.
6. `Esc` exits placement.

### Movement

- single click selects;
- drag starts `ComponentMoveSession`;
- drag shows ghost/preview, snap and dimensions;
- mouse-up commits;
- `Esc` restores original position;
- arrow keys nudge by the current precision step;
- Shift+arrow uses a coarse step;
- fine-step control is exposed for precision editing.

## Tablet

- stylus behaves like precise pointer input;
- touch uses larger hit targets and larger snap acquisition radius;
- one-finger drag moves a selected component;
- the preview may be offset from the finger so the object remains visible;
- two-finger pan/zoom must not destroy the active move session;
- release commits the valid preview;
- exact X/Y/height correction remains available through the contextual bottom editor.

## Mobile

- tap selects;
- long-press or explicit Move action starts a move session;
- dragging provides coarse positioning with magnetic snap;
- selected components expose a precision bottom editor with X/Y or X/height fields;
- the bottom editor exposes nudge controls and step presets;
- the touch target is substantially larger than the rendered electrical symbol;
- the canvas must auto-pan when the active pointer approaches an edge during drag.

## Adaptive interaction policy

Do not scatter `if (isMobile)` checks through canvas code. Input ergonomics are resolved by `EditorInteractionPolicy`.

Required policy values:

- hit target radius;
- snap acquisition radius;
- default precision/nudge step;
- coarse nudge step;
- whether pointer preview offset is required;
- whether a precision pad is shown by default;
- edge auto-pan activation inset.

Input modes:

```text
mouseKeyboard
stylus
touch
```

## Snap priority

The placement/move resolver may consider:

1. installation guide;
2. explicit project guide;
3. endpoint / vertex;
4. midpoint / center axis;
5. nearby component alignment;
6. grid;
7. raw pointer position.

Snap candidates must be surfaced visually with an engineering label such as `GUIDE 300`, `CENTER`, `GRID 100`.

## Live measurements

### Wall component

For socket, switch, wall luminaire, CCTV camera, ACS reader and similar devices show, when useful:

- height above finished floor;
- clearance to ceiling;
- nearest left/right wall/profile boundary;
- nearest door/window/beam boundary;
- distance to nearby selected/aligned component;
- distance to active installation guide.

### Ceiling component

For luminaire, AP, camera, detector and similar devices show:

- X/Y clearance to nearest room boundaries;
- distance to room center axes;
- distance to nearby aligned components;
- grid spacing when placing repeated arrays.

The measurement resolver and dimension layout engine are shared with architectural opening/beam dimensions.

## Repeat placement

Repeat placement is required for high-frequency electrical authoring.

```text
select Socket
  ↓
place #1
place #2
place #3
  ↓
Esc
```

Repeat is a placement-session option, not a separate tool. The canonical component type and active surface remain in the session after commit when enabled.

## Bottom editor

After selecting a placed component, the bottom editor provides exact values without forcing the user to drag precisely.

Desktop/tablet example:

```text
SOCKET S-12
POSITION          MOUNTING          VALIDATION
X      1250 mm    H      300 mm     ✓ valid

[Cancel] [Save]
```

Mobile adds large nudge controls and precision step presets.

Changes follow the same transactional pattern as door/window/beam editing: draft → preview → validate → save/discard.

## Surface compatibility

Catalog entries define allowed surfaces. Examples:

- `power.socket.general` → wall only;
- `lighting.luminaire.general` → ceiling and wall.

Selecting a catalog item may navigate to a compatible surface, but a move operation does not silently change surfaces. Surface transfer is a separate explicit command.

## Acceptance scenarios

### A. Socket on wall

- choose Socket from catalog;
- wall becomes active if required;
- initial preview uses preferred mounting height 300 mm;
- pointer/stylus/touch movement updates preview and dimensions;
- click/tap/Enter commits `componentTypeId=power.socket.general`;
- component can be selected and moved with the same snap/measurement model.

### B. Light on ceiling

- choose Light from catalog;
- ceiling becomes active when appropriate;
- preview starts near room center;
- center-axis/grid snaps are visible;
- click/tap/Enter commits `componentTypeId=lighting.luminaire.general`.

### C. Touch precision

- select existing component;
- start move by long press or Move action;
- drag to approximate position;
- snap radius is touch-sized;
- bottom precision controls correct the final millimetre coordinates;
- Save commits one history command.

### D. Cancel

- start placement or movement;
- change preview position;
- press Esc / Cancel;
- no new component is added or original component position is restored exactly.
