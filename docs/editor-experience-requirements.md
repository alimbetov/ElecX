# ElecX Spatial Editor — professional UX requirements

## Product intent

ElecX Spatial Editor is a desktop-first engineering workspace for creating the architectural context required by electrical design. It must feel closer to a focused CAD workstation than to a generic drawing canvas while remaining substantially easier to learn than general-purpose CAD.

The editor is built around one spatial source of truth:

`Project -> Site -> Building -> Level -> Space -> Surface -> Engineering objects`.

Plan, floor, ceiling and wall elevations are projections of the same model. No view may create an independent copy of room or opening geometry.

## UX principles

1. **Directness** — the engineer should select the object that is visible and edit its engineering properties without searching through unrelated dialogs.
2. **Predictability** — every geometry operation has deterministic anchoring, units, validation and undo semantics.
3. **Context preservation** — switching Plan/Floor/Ceiling/Wall never loses the selected room or physical identity of hosted objects.
4. **Millimetre precision** — persisted geometry is integer millimetres. Pixels exist only in the viewport.
5. **Progressive complexity** — basic room/opening work is obvious; advanced snapping, constraints and routing appear only when needed.
6. **Desktop speed** — keyboard and mouse workflows are first-class. Repetitive engineering actions must not require modal navigation.
7. **Model before paint** — dimensions, guides, openings and routes are model-backed or model-derived. Painter output is never the source of truth.
8. **Safe editing** — invalid geometry is rejected before mutation and the user is told why.

## P0 — spatial authoring workflow

### Project navigator

The left navigator must make the current context obvious:

- Site;
- Building;
- Level;
- Spaces on the active level;
- selected space;
- room dimensions at a glance.

Selecting a space must preserve a single selection model shared by the canvas, surface navigator and inspector.

### Room creation

Two creation paths are required:

1. **Free rectangular room** — define two snapped points on plan.
2. **Adjacent room** — choose a host room wall and create a new room from a shared wall segment.

Adjacent-room creation requires:

- host wall;
- offset from host-wall start;
- shared boundary length;
- outward depth;
- minimum dimension validation;
- no artificial gap between shared boundaries.

Future extension: select a wall directly on plan and expose a `+` affordance on hover.

### Surface navigation

For one selected space expose:

- Plan;
- Floor;
- Ceiling;
- Wall 1..N.

Edge navigation remains physical:

- wall top -> ceiling;
- wall bottom -> floor;
- wall side -> adjacent wall;
- floor/ceiling boundary -> matching wall.

### Doors and windows

Doors/windows are hosted wall objects. The editor must support:

- add door;
- add window;
- select opening;
- offset from wall start;
- width;
- height;
- sill / elevation from finished floor;
- delete;
- render consistently in plan and wall elevation.

Validation must reject openings extending beyond wall length or height.

P1 direct manipulation adds drag handles for opening edges and centre while preserving the same validation contract.

## P0 — desktop interaction contract

Required keyboard behaviour:

- `V` — Select;
- `R` — rectangular room on Plan;
- `G` — guide;
- `C` — cable route;
- `Esc` — cancel active draft and return to Select;
- `+` / `=` — zoom in;
- `-` — zoom out;
- `0` — reset zoom;
- `Delete` — delete selected opening when an opening is selected.

Every tool must expose its current mode visually. The status bar must report active surface, grid, snap state, zoom and route length when applicable.

## P0 — inspector contract

The right inspector is contextual, not a generic property dump.

### Space selected

Show:

- type;
- X/Y extents;
- reference origin;
- local grid.

### Wall selected

Show:

- wall identity;
- length;
- height;
- previous/next wall navigation;
- hosted openings;
- add Door / Window actions.

### Opening selected

Show editable numeric fields with millimetre units and explicit apply semantics:

- type;
- wall offset;
- width;
- height;
- sill height;
- delete.

Invalid edits must leave the previous model state intact.

## P1 — CAD interaction quality

The next interaction kernel must provide:

- pan;
- cursor-centred zoom;
- fit level;
- fit room;
- fit selection;
- screen/world transform owned by a ViewportController;
- endpoint snap;
- midpoint snap;
- centre snap;
- intersection snap;
- perpendicular snap;
- nearest-point snap;
- wall snap;
- persistent and temporary guides;
- hover snap marker and snap type label;
- cursor coordinates in active local frame.

Snap resolution must use a screen-space acquisition radius so behaviour stays stable across zoom levels.

## P1 — direct manipulation

Objects that may be directly dragged must first have command semantics:

- opening move;
- opening resize;
- room edge move;
- room vertex move;
- route point move.

A drag previews candidate geometry; model mutation occurs through a validated command. Every completed command is undoable.

## P1 — dimensions and constraints

Dimensions are associative model projections.

For rectangles, editing width/height may use a deterministic fixed-edge policy. For arbitrary polygons, dimension editing must wait for an explicit constraint model supporting at least:

- fixed point;
- fixed edge;
- distance;
- horizontal;
- vertical;
- parallel;
- perpendicular;
- coincident.

The editor must never silently guess which polygon vertex to move.

## P1 — command/history foundation

All geometry-changing actions converge on commands so the same operations can later power undo/redo, persistence, collaboration and audit history.

Examples:

- `AddRoom`;
- `AddAdjacentRoom`;
- `MoveRoomEdge`;
- `AddOpening`;
- `UpdateOpening`;
- `DeleteOpening`;
- `AddRoutePoint`;
- `TransitionRouteSurface`.

## P2 — engineering workspace integration

Only after the spatial editor interaction kernel is stable should the main electrical authoring layers be added:

- sockets;
- switches;
- luminaires;
- junction boxes;
- panels;
- cable routes;
- circuits;
- equipment catalogue bindings;
- engineering calculations.

These objects reference spatial surfaces; they must not create a parallel geometry model.

## Acceptance scenarios

The spatial foundation is suitable for Desktop Preview when an engineer can complete all of these without editing raw data:

1. Open a project and identify building, level and rooms immediately.
2. Create a room from two points.
3. Select an existing room and create a precisely dimensioned adjacent room from one wall.
4. Move between Plan, Floor, Ceiling and every wall without losing context.
5. Add a door and window to a wall.
6. Change each opening's position, width, height and sill height and see both plan and elevation update.
7. Attempt invalid opening geometry and observe that the model remains unchanged.
8. Start a cable route on a wall, transition to floor/ceiling/adjacent wall and retain route continuity.
9. Perform core tool/zoom operations from keyboard without leaving the canvas.
10. Pass `dart format`, `flutter analyze` and `flutter test` on the exact branch HEAD.
