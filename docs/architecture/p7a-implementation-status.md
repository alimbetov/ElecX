# P7A Stable Boundary Topology — implementation status

Branch: `feat/project-structure-authoring`

## Current status

**P7A: IN PROGRESS.**

P7A-1 domain foundation and P7A-2 canonical aggregate ownership have landed. P7A is not yet closed because persistence/migration, production editor cutover, hosted-object migration and final hardening are still pending.

## Landed

### P7A-1 domain foundation

Implemented:

- stable `BoundaryEdgeId` remains the durable edge identity;
- platform-independent `BoundaryPointMm`;
- canonical `ProjectBoundaryEdge` scoped to exact `SpaceId`;
- ordered `SpaceBoundaryTopology` for one exterior loop;
- topology validation for ownership, continuity and closure;
- explicit edge lineage: `preserved`, `split`, `merged`, `created`, `removed`;
- fail-closed host remap decisions;
- duplicate source/result lineage rejection;
- qualification tests for preserved/split/merge/remove and invalid loops.

Primary implementation:

```text
lib/src/domain/boundary_topology.dart
```

Primary qualification:

```text
test/p7a_boundary_topology_test.dart
```

### P7A-2 canonical aggregate ownership

Implemented:

- `ProjectEntityStores.boundaries` is now authoritative canonical state keyed by `SpaceId`;
- aggregate validation rejects dangling boundary owners and store-key/owner mismatches;
- aggregate validation includes `SpaceBoundaryTopology.validate()` failures;
- duplicate `BoundaryEdgeId` ownership across spaces is rejected;
- `ProjectIndex` exposes `boundary(SpaceId)`, `boundaryEdge(BoundaryEdgeId)` and `spaceByBoundaryEdgeId`;
- boundary state participates in `ProjectEntityDiff`;
- edge geometry changes report affected stable `BoundaryEdgeId` values;
- boundary order/topology changes report the owning `SpaceId` as updated;
- simultaneous Space + boundary creation/removal keeps added/updated/removed diff sets disjoint;
- undo/redo captures boundary topology because it is part of `ProjectMutableState.stores`;
- invalid topology candidates fail before `_current` is replaced;
- legacy stores-only commands preserve existing boundary topology;
- P6 semantic commands preserve existing boundary topology when rebuilding canonical stores.

Primary implementation:

```text
lib/src/domain/project_aggregate.dart
lib/src/application/project/project_mutation.dart
lib/src/application/project/project_space_semantics_commands.dart
```

Primary qualification:

```text
test/p7a_aggregate_ownership_test.dart
```

## Safety invariant now established

The following is forbidden as a durable migration rule:

```text
old wallIndex N -> new wallIndex N
```

Only a lineage record may explain what happened to an old `BoundaryEdgeId`.

Hosted objects behave as follows:

```text
preserved -> retain exact BoundaryEdgeId
split     -> requires geometry-aware remap
merged    -> requires geometry-aware remap
removed   -> detached/conflict
unknown   -> fail closed
```

Aggregate ownership adds a second invariant:

```text
ProjectAggregateRoot
  -> ProjectEntityStores.boundaries[SpaceId]
      -> SpaceBoundaryTopology
          -> BoundaryEdgeId...
```

There is no platform-specific copy of topology and no durable wall-index ownership path.

## Remaining P7A slices

```text
P7A-1 domain foundation             IMPLEMENTED
P7A-2 canonical aggregate ownership IMPLEMENTED / qualification running
P7A-3 persistence + legacy migration PENDING
P7A-4 production editor cutover      PENDING
P7A-5 hosted-object migration        PENDING
P7A-6 full hardening/qualification   PENDING
```

## Boundary with later stages

Not part of P7A:

- P7B vertical topology;
- P7C typical-floor lineage;
- P8 Wizard/generation;
- Windows/Linux/Android/iOS/iPadOS runner setup.

Pending platform runners do not block P7A development. P7A domain semantics remain platform-independent across macOS, Windows, Linux, Android, iOS and iPadOS.

## Next implementation target

After P7A-2 qualification is green, proceed with **P7A-3 persistence + legacy migration**:

1. extend canonical document codec with stable boundary topology;
2. persist exact `BoundaryEdgeId` values and ordered edge membership;
3. deterministically migrate legacy room polygons into boundary identities;
4. prove migration runs once and save/reopen preserves IDs;
5. reject corrupt topology documents fail-closed;
6. keep the document schema identical across all supported native platforms.
