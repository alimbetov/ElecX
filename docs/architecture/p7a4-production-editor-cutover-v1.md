# P7A-4 Production Editor Cutover v1

## Purpose

P7A-4 moves room-wall navigation and editor selection from durable `wallIndex`
assumptions to stable canonical `BoundaryEdgeId` identity without rewriting the
legacy editor in one unsafe step.

The core rule is:

```text
BoundaryEdgeId = engineering identity
wall ordinal   = transient projection into the legacy canvas API
```

No native platform owns alternative topology or wall identity semantics.

## Production boundary

The transitional editor still exposes:

```text
RoomSurfaceRef.wall(legacySpaceId, wallIndex)
EditorController.showWall(wallIndex)
```

P7A-4 does not treat those integer values as identity. A strict bridge resolves:

```text
canonical SpaceBoundaryTopology
             +
materialized legacy EngineeringSpace polygon
             |
             v
CanonicalRoomBoundaryProjection
             |
             +-- BoundaryEdgeId A <-> transient ordinal 0
             +-- BoundaryEdgeId B <-> transient ordinal 1
             +-- BoundaryEdgeId C <-> transient ordinal 2
             +-- BoundaryEdgeId D <-> transient ordinal 3
```

Conversion to `int` happens only at the final call into the legacy controller.

## Exact materialization invariant

The first production cutover deliberately does not perform geometric guessing.
For canonical edge at ordered position `i`:

```text
canonical.start == legacy.vertices[i]
canonical.end   == legacy.vertices[(i + 1) % count]
```

The following all fail closed:

- canonical/legacy Space mismatch;
- missing canonical topology;
- different wall counts;
- reordered canonical IDs without matching legacy materialization;
- changed geometry on either side;
- invalid canonical topology;
- stale or missing legacy selected room.

There is no nearest-edge matching, cyclic rotation inference, direction reversal
or wall-label matching in this slice. Such recovery would risk attaching a
stable identity to the wrong physical surface.

## Stable selection

The editor-facing selection adapter exposes:

```text
CanonicalRoomSurfaceSelection
  kind: plan | floor | ceiling | wall
  boundaryEdgeId: BoundaryEdgeId?  // authoritative for wall
  wallOrdinal: int?                // compatibility projection only
```

Wall actions accept `BoundaryEdgeId`:

```text
BoundaryEdgeId
    |
    v
projection.ordinalForEdgeId(...)
    |
    v
EditorController.showWall(int)
```

Previous/next navigation rotates through canonical `orderedEdgeIds`; the
integer ordinal is resolved again at the legacy boundary for each action.

Unknown/stale `BoundaryEdgeId` fails closed and does not change editor state.

## Scope boundary with P7A-5

P7A-4 changes navigation/selection identity only.

These legacy hosts remain intentionally unchanged until P7A-5:

- `ArchitecturalOpening.hostWall`;
- `EngineeringSpace.wallProfiles`;
- wall-hosted components;
- cable endpoints;
- route anchors.

P7A-4 must not claim those objects are migrated merely because wall navigation
has stable identity. P7A-5 will migrate them using explicit
`BoundaryTopologyChangeSet` lineage and geometry-aware remap rules.

## Cutover slices

### P7A-4.1 - strict boundary projection

Implemented:

- `CanonicalRoomBoundaryProjection`;
- `CanonicalEditorWallProjection`;
- bidirectional `BoundaryEdgeId <-> wall ordinal` lookup;
- exact geometry/materialization validation;
- fail-closed typed exceptions;
- qualification for >4-wall rooms and geometry/order drift.

### P7A-4.2 - stable selection adapter

Implemented:

- `CanonicalRoomSurfaceSelectionAdapter`;
- active legacy ordinal projects to stable `BoundaryEdgeId`;
- wall selection APIs accept stable IDs;
- previous/next rotate canonical edge ordering;
- unknown edge IDs leave editor state unchanged.

### P7A-4.3 - production resolver

Implemented:

- `CanonicalRoomSurfaceCutover.resolve(...)`;
- requires exact canonical Space, topology, binding and selected legacy room;
- missing canonical topology never falls back to durable ordinal semantics.

### P7A-4.4 - Room Surface Navigator wiring

Next:

- build the cutover adapter from the active canonical runtime;
- make navigator wall targets carry `BoundaryEdgeId`;
- keep `W1`, `W2`, ... as labels only;
- stale edge selection falls back to Plan;
- keyboard/mouse/touch invoke the same stable-edge action;
- navigation remains non-dirty.

### P7A-4.5 - canonical topology edit path

After navigator wiring:

- route boundary geometry edits through `ProjectMutationSession`;
- require `expectedVersion`;
- validate topology and geometry;
- emit explicit lineage;
- atomically commit or cancel;
- no widget directly mutates canonical stores.

## Native-platform invariant

The bridge is pure Dart and uses integer millimetres plus typed canonical IDs.
Mouse, trackpad, keyboard, touch and stylus are input mechanisms only. They must
all resolve to the same `BoundaryEdgeId` selection/mutation semantics.

No Windows/Linux/mobile placeholder services or platform-specific boundary
models are introduced by P7A-4.
