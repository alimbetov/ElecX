# P7A Stable Boundary Topology — implementation status

Branch: `feat/project-structure-authoring`

## Current status

**P7A: IN PROGRESS.**

The first executable domain slice has landed. P7A is not yet closed because canonical aggregate ownership, persistence/migration, production editor cutover and hosted-object migration are still pending.

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

Architecture contract:

```text
docs/architecture/p7a-stable-boundary-topology-v1.md
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

This prevents opening/component/cable hosts from silently moving to a physically different wall after polygon mutation.

## Remaining P7A slices

```text
P7A-2 canonical aggregate ownership   PENDING
P7A-3 persistence + legacy migration  PENDING
P7A-4 production editor cutover       PENDING
P7A-5 hosted-object migration          PENDING
P7A-6 full hardening/qualification    PENDING
```

## Boundary with later stages

Not part of P7A:

- P7B vertical topology;
- P7C typical-floor lineage;
- P8 Wizard/generation;
- Windows/Linux/Android/iOS/iPadOS runner setup.

Pending platform runners do not block P7A development. P7A domain semantics remain platform-independent.

## Next implementation target

Proceed with **P7A-2 canonical aggregate ownership**:

1. add boundary edge/topology stores to canonical project state;
2. index them by stable identity/space ownership;
3. extend graph validation;
4. include topology in fingerprint/change detection;
5. prove failed/stale mutations leave authoritative topology unchanged.
