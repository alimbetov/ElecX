# Room Surface Navigator v1

## Status

Required native UX/interaction contract for `feat/project-structure-authoring`.

This specification complements:

- `docs/architecture/native-project-portability-and-sync.md`
- `docs/architecture/project-structure-authoring-v1.md`
- `docs/architecture/project-navigator-current-location-v1.md`
- `docs/architecture/project-composition-foundation-decisions-v1.md`
- `docs/architecture/project-variant-qualification-v1.md`

ElecX remains strictly native-only: macOS, Windows, Linux, Android, iOS and iPadOS. Web/browser runtime is out of scope.

## Objective

When a room/space is selected, the user must be able to understand not only **where they are in the project hierarchy**, but also **which physical room surface is currently being edited**.

The Project Navigator answers:

```text
WHERE AM I?
Project → Site → Building → Level → Zone → Room
```

The Room Surface Navigator answers:

```text
WHAT SURFACE AM I EDITING?
Plan / Floor / Ceiling / Wall N
```

The main editor answers:

```text
WHAT AM I EDITING ON THAT SURFACE?
components / openings / routes / dimensions / geometry
```

These responsibilities must remain separate.

## Desktop baseline

The Room Surface Navigator is a single lightweight panel attached to the current selected room, not an embedded 3D card inside every room node in the hierarchy.

Recommended desktop composition:

```text
LEFT PANEL

PROJECT
├── Site
│   └── Building A
│       └── Floor 2
│           └── Bedroom  ← CURRENT ROOM

[ + Building ]
[ + Level ] [ + Room ]
[ Wizard ]

────────────────────────

ROOM NAVIGATOR
[ interactive lightweight 2.5D room ]

Current surface:
Wall 3

[ Plan ] [ Floor ] [ Ceiling ]
```

The panel may be collapsed by the user.

## Visibility rule

The Room Surface Navigator:

- is shown only when a canonical room/space suitable for surface editing is selected;
- is hidden when no room is selected;
- may remain collapsed according to user shell/session preference;
- must not allocate or own project geometry;
- must not dirty the engineering project merely because it is shown, hidden or collapsed.

Visibility/collapse state is transient UI/session state unless a future shell-preference decision explicitly persists it outside engineering project semantics.

## Lightweight 2.5D representation

The navigator displays a lightweight 2.5D/axonometric representation generated from canonical room geometry.

It is not a second 3D/BIM model.

Initial implementation should prefer a lightweight renderer such as `CustomPainter` or an equivalent native Flutter projection over a heavyweight 3D engine.

The model must be derived from canonical data such as:

```text
EngineeringSpace.boundary
RoomReferenceFrame
room/clear height when available
wall profiles
architectural openings
active RoomSurfaceRef
```

No independent room geometry state is permitted inside the Room Surface Navigator.

## Supported surfaces

The navigation model must support at least:

```text
Plan
Floor
Ceiling
Wall 0..N-1
```

Wall count is derived from canonical polygon boundary geometry.

The implementation must not assume that every room has exactly four walls.

Polygonal, L-shaped and other valid multi-edge rooms must remain representable:

```text
EngineeringSpace.boundary.vertices
        ↓
derive boundary edges
        ↓
Wall 0
Wall 1
...
Wall N-1
```

Curved/segmented wall support may be added later without changing the navigator's ownership model.

## Current surface highlighting

Exactly one current editable surface/context is visually emphasized when the editor is in a surface-specific mode.

Examples:

```text
Current surface: Floor
Current surface: Ceiling
Current surface: Wall 3
```

The 2.5D representation must clearly highlight the active surface.

Highlighting must not rely on color alone. Combine visual treatment with at least one of:

- outline/stroke;
- marker/icon;
- label;
- text state;
- accessibility semantics.

Example accessible labels:

```text
Wall 3, current surface
Floor, current surface
Ceiling, current surface
```

## Bidirectional synchronization

The Room Surface Navigator and main editor use one navigation/surface-selection source of truth.

Required behavior:

```text
User clicks Wall 2 in Room Surface Navigator
→ canonical/editor surface-selection command executes
→ editor opens/selects Wall 2
→ Room Surface Navigator highlights Wall 2
```

and:

```text
User selects Wall 3 from canvas/editor controls
→ active RoomSurfaceRef changes
→ Room Surface Navigator highlights Wall 3
```

Do not implement independent widget booleans that attempt to synchronize afterward.

## Interaction contract

Minimum supported interactions:

```text
click/tap room wall      → select Wall N
click/tap floor          → select Floor
click/tap ceiling        → select Ceiling
Plan button              → return to Plan
Floor button             → select Floor
Ceiling button           → select Ceiling
```

Desktop may additionally support:

```text
double click Wall N      → open/focus wall elevation if that command exists
hover surface            → transient preview only
```

Hover must never mutate engineering state or create Undo history.

A surface change is navigation/editor state, not an engineering geometry mutation by itself.

## Wall identity

A wall selection must be anchored to canonical room-boundary semantics, not screen position.

Initial implementations may address walls through a stable boundary-edge reference associated with the selected `SpaceId`, for example conceptually:

```text
RoomSurfaceRef(
  spaceId,
  surfaceKind = wall,
  boundaryEdgeRef
)
```

Long-term architecture must allow wall identity to survive geometry editing where the logical wall survives.

A raw viewport index must not become an external persisted engineering identity.

If current runtime still uses edge indices transitionally, the adapter must remain scoped to canonical room geometry and must not create a second wall model in the navigator.

## Openings and component hints

The initial v1 mini-view may show only room enclosure/surfaces.

The architecture may later project lightweight hints for:

```text
doors/windows
selected electrical component
route endpoint
active cable attachment
wall profile differences
```

These are projections only and must be derived from existing canonical editor/domain state.

The mini-view must not become a second editing canvas for full component manipulation in v1.

## Project tree relationship

The Room Surface Navigator must not be repeated inside every room tree node.

Rejected layout:

```text
Room 101
└── embedded 2.5D preview
Room 102
└── embedded 2.5D preview
Room 103
└── embedded 2.5D preview
```

Reasons:

- excessive vertical tree growth;
- poor discoverability in large projects;
- unnecessary rendering/rebuild cost;
- hierarchy and surface navigation become visually conflated;
- poor mobile ergonomics.

Required principle:

```text
Project tree          = structural location
Room Surface Navigator = local surface orientation
Canvas                 = engineering editing
```

## Collapsible behavior

Desktop Room Surface Navigator is collapsible.

Requirements:

- collapse does not change selected Room;
- collapse does not change current surface;
- expanding restores projection from current canonical/editor state;
- no geometry or engineering data is serialized because of collapse/expand;
- expensive rendering work should be suspended or minimized while collapsed.

## Mobile/tablet adaptation

Mobile/tablet uses the same semantic surface-selection commands with adaptive presentation.

Recommended behavior:

```text
iPad/tablet
→ collapsible side/bottom panel or wide sheet

Phone
→ bottom sheet / full-width compact surface navigator
```

A compact mobile form may show:

```text
[ 2.5D mini room ]
Current: Wall 3
[ Plan ] [ Floor ] [ Ceiling ]
```

The canonical selected Room and `RoomSurfaceRef` semantics remain identical to desktop.

No Web-specific implementation is required or implied.

## Keyboard accessibility

Desktop must support keyboard operation.

Minimum semantics:

```text
Tab / Shift+Tab   move focus between Room Navigator controls
Enter / Space     activate focused surface/control
Arrow keys        may cycle surfaces when the mini-view has explicit focus
Escape            leaves transient hover/preview without changing committed selection
```

Keyboard focus is not the same as current surface selection.

Moving focus alone must not silently change the editor's active surface unless an explicit navigation mode documents that behavior.

Every interactive surface must expose an accessible label.

## Performance requirements

The mini-view is intentionally lightweight.

It must not:

- instantiate a full 3D scene engine per room;
- render previews for every room in the project tree;
- deep-copy the project or room graph for hover;
- rebuild the whole Project Navigator when only the active surface changes;
- perform expensive hidden rendering while collapsed.

Target update path:

```text
SurfaceSelectionChange
→ update active-surface projection
→ repaint Room Surface Navigator only
```

Structural room geometry changes invalidate only the relevant room projection/cache.

## State ownership

Canonical engineering/project data may include:

```text
SpaceId
room polygon/geometry
room height/profile data
wall/opening geometry
ProjectNorth where applicable
```

Editor/navigation state may include:

```text
selected SpaceId
active RoomSurfaceRef
view mode
```

Transient Room Surface Navigator UI state includes:

```text
collapsed/expanded
hovered mini-view surface
keyboard-focus target
mini-view camera/orientation preference if treated as shell state
```

Transient navigator state must not alter project revision or engineering meaning.

## Failure behavior

Surface activation is fail-closed.

Reject/ignore activation when:

- selected `SpaceId` no longer exists;
- target wall/surface is no longer valid after geometry mutation;
- surface belongs to another room than the active room;
- stale mini-view state references a removed boundary edge.

After room geometry changes invalidate the current wall, the editor must choose a deterministic valid fallback such as Plan, rather than silently binding to another wall index.

## Qualification scenarios

Mandatory Room Surface Navigator qualification cases:

```text
RSN01 navigator hidden when no Room is selected
RSN02 selecting a Room reveals one Room Surface Navigator
RSN03 Room Navigator uses canonical selected SpaceId
RSN04 Floor click activates Floor in editor
RSN05 Ceiling click activates Ceiling in editor
RSN06 Wall N click activates the exact canonical wall surface
RSN07 canvas Wall selection updates Room Navigator highlight
RSN08 Plan action returns editor to Plan
RSN09 current surface is understandable without color alone
RSN10 polygon room with >4 walls renders/selects all Wall N surfaces
RSN11 L-shaped room does not fall back to four-wall hardcode
RSN12 collapse preserves selected Room and current surface
RSN13 expand restores projection from current editor state
RSN14 collapse/expand does not dirty project
RSN15 hover does not create engineering mutation or Undo record
RSN16 stale removed wall fails closed to deterministic fallback
RSN17 switching Room rebuilds projection only for newly selected Room
RSN18 project-tree current location remains unchanged by local wall navigation
RSN19 keyboard can reach and activate Plan/Floor/Ceiling/Wall controls
RSN20 mobile compact/sheet version invokes same surface-selection semantics
RSN21 large project does not render mini-views for non-selected rooms
RSN22 no independent room geometry state exists in Room Surface Navigator
RSN23 no Web/browser-specific path is introduced
```

## Merge blockers

The corresponding implementation stage is blocked if:

- the Room Surface Navigator owns an independent geometry/model copy;
- every room node renders its own active mini-view;
- rectangular/four-wall assumptions prevent valid polygon-room navigation;
- canvas and mini-view can disagree about active surface;
- wall activation is based only on viewport position/index without canonical room reference;
- collapse/visibility changes dirty engineering project state;
- keyboard/screen-reader users cannot determine or change current surface;
- ordinary surface selection rebuilds the entire project tree;
- stale wall selection silently rebinds to an unrelated wall;
- a Web/browser-specific surface-navigation model is added.

## Non-negotiable conclusion

The Room Surface Navigator is a lightweight, optional native orientation aid for the **single currently selected room**.

It provides a 2.5D projection of canonical room geometry, clearly highlights the current editable surface and supports bidirectional surface navigation with the main editor.

It is not a second room model, not a full 3D editor, not a preview embedded in every tree row and not persisted as engineering data.

The intended UX is:

```text
PROJECT NAVIGATOR
→ where am I in the project?

ROOM SURFACE NAVIGATOR
→ which surface of this room am I editing?

MAIN CANVAS
→ what engineering content am I editing there?
```
