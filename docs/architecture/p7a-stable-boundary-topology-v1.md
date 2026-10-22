# P7A — Stable Boundary Topology / BoundaryEdgeId v1

Branch: `feat/project-structure-authoring`

## Status

P7A establishes durable horizontal boundary identity before vertical topology (P7B), typical-floor lineage (P7C), or Project Wizard generation (P8).

This stage starts from the P6-qualified canonical project baseline. Windows/Linux/Android/iOS/iPadOS executable runners are not prerequisites for P7A, but every P7A domain contract is platform-independent from its first implementation.

## Problem being removed

The transitional editor can address room walls by polygon/list index:

```text
wallIndex = 0
wallIndex = 1
wallIndex = 2
...
```

That is acceptable for temporary rendering/navigation only. It is not a durable engineering identity.

After polygon editing, split, merge, vertex insertion or edge removal, the same list index can represent a physically different wall. Persisting engineering hosts by index would therefore allow silent corruption such as:

```text
socket -> wallIndex 2
window -> wallIndex 2
cable anchor -> wallIndex 2
```

silently moving to another physical wall after a geometry edit.

P7A replaces that ownership assumption with stable `BoundaryEdgeId`.

## Canonical v1 model

The first executable slice intentionally supports one ordered exterior boundary per `SpaceId`:

```text
SpaceId
  |
  +-- ordered BoundaryEdgeId A
  +-- ordered BoundaryEdgeId B
  +-- ordered BoundaryEdgeId C
  +-- ordered BoundaryEdgeId D
```

Each canonical edge owns:

```text
BoundaryEdgeId
SpaceId
start point in millimetres
end point in millimetres
```

Coordinates are domain values and never Flutter `Offset`, screen pixels, pointer coordinates or platform-specific types.

### Why no BoundaryLoopId in the first slice

P7A starts with the minimum identity needed to remove `wallIndex` as durable ownership. Introducing a persistent loop identity before multiple exterior/interior loops are actually required would expand the migration surface without improving current host safety.

Interior void/hole loops may be added later while preserving all existing `BoundaryEdgeId` values and lineage semantics.

## Boundary invariants

A valid `SpaceBoundaryTopology` must satisfy:

1. at least three ordered edges;
2. every ordered edge id resolves to a canonical edge;
3. every edge belongs to the exact `SpaceId` owning the topology;
4. no edge id appears twice in the ordered boundary;
5. no canonical edge is silently left outside the ordered boundary;
6. `edge[i].end == edge[i+1].start`;
7. last edge end equals first edge start;
8. edge store key equals `ProjectBoundaryEdge.id`;
9. zero-length edges are rejected.

Invalid candidate topology fails closed before it can become authoritative project state.

## Stable identity rule

Geometry changes do not imply identity replacement automatically.

If one physical/logical edge survives an edit, its `BoundaryEdgeId` is preserved even when its order/index changes.

Example:

```text
Before
[0:A] [1:B] [2:C] [3:D]

After vertex/order operation
[0:D] [1:A] [2:B] [3:C]
```

The durable identities remain `A/B/C/D`. A UI wall number is only a projection of current order.

## Required topology lineage

Every committed topology mutation that changes edge identity must emit explicit lineage.

Supported outcomes:

```text
preserved   1 old -> same 1 edge id
split       1 old -> 2..N new edge ids
merged      2..N old -> 1 new edge id
created     0 old -> 1..N new edge ids
removed     1..N old -> 0 new edge ids
```

The same source edge may not appear in multiple lineage records. The same result edge may not appear in multiple lineage records.

This makes the change set deterministic and prevents downstream systems from guessing identity from array position.

## Hosted-object migration contract

P7A establishes fail-closed host remapping semantics.

### Preserved

```text
old edge A -> edge A
```

Hosted objects may retain `BoundaryEdgeId A` directly.

### Split

```text
old edge A -> edge B + edge C
```

The system MUST NOT select B or C from wall number/order.

The host enters `requiresGeometricRemap` with B/C as explicit candidates. A later geometry-aware migration step must prove which candidate contains the host position or report a conflict.

### Merge

```text
old A + old B -> new C
```

Even though the result identity is unambiguous, hosted coordinates/profile offsets may change. The host therefore enters `requiresGeometricRemap` rather than being silently rewritten.

### Removed

```text
old A -> removed
```

The host becomes detached/conflicted. It must not attach to the edge now occupying the old list index.

### Unknown lineage

A pre-mutation hosted edge without lineage is an invalid mutation result and fails closed.

## Opening/component/cable implications

P7A is the identity foundation for later canonical relationships such as:

```text
OpeningId   -> BoundaryEdgeId
ComponentId -> BoundaryEdgeId
Route anchor -> BoundaryEdgeId
Cable endpoint -> BoundaryEdgeId
Wall profile -> BoundaryEdgeId
```

This first slice does not migrate every existing editor subsystem to those relationships immediately. Migration is staged so the existing production editor remains functional while canonical ownership becomes authoritative.

No new durable feature may introduce another `wallIndex` foreign key during that transition.

## Mutation protocol

A full P7A topology edit will use the existing canonical project mutation protocol:

```text
read LocalProjectVersion N
        |
build candidate topology
        |
validate geometry/topology
        |
compute BoundaryTopologyChangeSet
        |
validate hosted-object migration/conflicts
        |
compare expectedVersion == N
        |
atomic canonical commit N+1
        |
publish ProjectChangeSet + UndoRecord
```

No widget owns `BoundaryEdgeId` generation/remapping rules.

## Cross-platform contract

P7A domain semantics are identical on:

```text
macOS
Windows
Linux
Android
iOS
iPadOS
```

Mouse, touch, stylus, keyboard and trackpad may produce different edit gestures, but they must produce the same candidate topology and lineage for the same geometric edit.

No P7A identity depends on:

- platform name;
- screen size;
- pointer device;
- file path;
- SQLite row id;
- wall label;
- wall list index;
- translated display text.

## P7A implementation slices

### P7A-1 — domain identity foundation

- canonical `ProjectBoundaryEdge`;
- ordered `SpaceBoundaryTopology`;
- topology validation;
- explicit lineage model;
- fail-closed hosted-object remap decisions;
- unit qualification.

### P7A-2 — aggregate ownership

- add canonical boundary stores/indexes to project aggregate;
- validate `SpaceId` ownership through aggregate validator;
- include boundary changes in project fingerprints/change sets;
- ensure failed candidate commits do not mutate authoritative state.

### P7A-3 — persistence/migration

- serialize canonical edge identities/topology;
- deterministic migration for legacy polygons;
- save/reopen identity equality;
- legacy projects receive stable identities exactly once and keep them afterwards.

### P7A-4 — production editor cutover

- adapt Room Surface Navigator from durable wall index assumptions to `BoundaryEdgeId` projection;
- route boundary geometry edits through canonical mutation;
- preserve current UI wall labels as presentation only;
- fail closed on stale selected/hosted edges.

### P7A-5 — hosted-object migration

- openings;
- wall profiles;
- wall-hosted components;
- cable/route anchors where applicable;
- explicit split/merge conflict handling.

### P7A-6 — hardening/qualification

- split/merge/remove acceptance matrix;
- undo/redo identity restoration;
- stale-version rejection;
- save/reopen;
- corrupt/legacy migration cases;
- Flutter qualification;
- current macOS Desktop qualification;
- portability invariants retained for pending native platform runners.

## Explicit non-goals

P7A does not implement:

- P7B vertical cores/risers/level transition topology;
- P7C typical-floor definition/instance lineage;
- P8 Project Wizard generation;
- Windows/Linux/mobile runner setup;
- browser/Web behavior;
- automatic arbitrary host relocation after destructive geometry edits.

## P7A closure gate

P7A is `DONE + HARDENED` only when:

```text
- BoundaryEdgeId is persisted canonical identity;
- wallIndex is presentation/transitional only;
- topology edits emit validated lineage;
- split/merge/remove cannot silently move hosted objects;
- canonical aggregate owns boundary topology;
- save/reopen preserves identities;
- legacy polygon migration is deterministic;
- undo/redo preserves/reverts topology identity atomically;
- production wall navigation resolves through stable identity;
- current Flutter + macOS qualification gates pass.
```

P7B may be designed in parallel, but P7A identity rules must not be bypassed by vertical or generated topology.
