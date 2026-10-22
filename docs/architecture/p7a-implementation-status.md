# P7A Stable Boundary Topology — implementation status

Branch: `feat/project-structure-authoring`

## Current status

**P7A: IN PROGRESS.**

P7A-1 domain foundation and P7A-2 canonical aggregate ownership are implemented and hardened. P7A-3 persistence foundation is now implemented with canonical schema v4, durable `BoundaryEdgeId` owner tombstones and deterministic legacy polygon conversion. Full legacy editor cutover remains intentionally fail-closed until the remaining legacy engineering domains can be migrated losslessly.

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

- `ProjectEntityStores.boundaries` is authoritative canonical state keyed by `SpaceId`;
- aggregate validation rejects dangling boundary owners and store-key/owner mismatches;
- aggregate validation includes `SpaceBoundaryTopology.validate()` failures;
- duplicate active `BoundaryEdgeId` ownership across spaces is rejected;
- `ProjectIndex` exposes `boundary(SpaceId)`, `boundaryEdge(BoundaryEdgeId)` and `spaceByBoundaryEdgeId`;
- boundary state participates in `ProjectEntityDiff`;
- edge geometry changes report affected stable `BoundaryEdgeId` values;
- boundary order/topology changes report the owning `SpaceId` as updated;
- simultaneous Space + boundary creation/removal keeps added/updated/removed diff sets disjoint;
- undo/redo captures boundary topology because it is part of `ProjectMutableState.stores`;
- invalid topology candidates fail before `_current` is replaced;
- legacy stores-only commands preserve existing boundary topology;
- P6 semantic commands preserve existing boundary topology when rebuilding canonical stores;
- a `BoundaryEdgeId` cannot change historical owning `SpaceId` across mutations.

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

### P7A-3 persistence foundation

Implemented:

- canonical document schema advanced to **v4**;
- exact `BoundaryEdgeId`, `SpaceId`, ordered edge membership and millimetre geometry are persisted;
- durable `BoundaryEdgeIdentityRegistry` stores every issued edge owner, including retired/tombstoned edges;
- mutation commit automatically carries the monotonic registry into canonical engineering metadata;
- undo/redo restores topology but does not delete historical edge-owner tombstones;
- codec persists the union of historical registry entries and currently active boundaries;
- decode fails closed when an active edge is missing from the registry or registry ownership conflicts with topology;
- canonical v1/v2/v3 migrate to v4 with empty P7A state rather than inventing topology;
- deterministic `LegacyBoundaryPolygonMigration` converts one legacy polygon to stable P7A topology;
- a duplicated closing polygon vertex is normalized without changing generated edge identities;
- the same project/space/polygon produces exactly the same IDs on repeated migration;
- the same geometry in another `SpaceId` produces different identities;
- full legacy editor v1..v4 migration remains fail-closed because engineering P2 state, wall-index resume state and other legacy domains are not yet losslessly represented.

Primary implementation:

```text
lib/src/domain/boundary_edge_identity_registry.dart
lib/src/application/project/project_mutation.dart
lib/src/serialization/project/canonical_project_document_codec.dart
lib/src/serialization/project/legacy_boundary_polygon_migration.dart
```

Primary qualification:

```text
test/p7a_persistence_migration_test.dart
test/canonical_project_document_codec_test.dart
```

## Safety invariants now established

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

Historical ownership is monotonic:

```text
BoundaryEdgeId E -> Space A

E active in Space A       allowed
E retired                  allowed
E restored in Space A      allowed
E reused in Space B        forbidden
```

The owner ledger survives:

```text
commit -> save -> close -> reopen
```

so process restart cannot weaken the identity invariant.

Aggregate ownership remains:

```text
ProjectAggregateRoot
  -> ProjectEntityStores.boundaries[SpaceId]
      -> SpaceBoundaryTopology
          -> BoundaryEdgeId...

ProjectEngineeringMetadata
  -> BoundaryEdgeIdentityRegistry
      -> active + tombstoned BoundaryEdgeId ownership
```

There is no platform-specific copy of topology, registry or persistence schema and no durable wall-index ownership path.

## Remaining P7A slices

```text
P7A-1 domain foundation              IMPLEMENTED
P7A-2 canonical aggregate ownership  DONE + HARDENED
P7A-3 persistence foundation         IMPLEMENTED / qualification running
P7A-3 full legacy cutover            BLOCKED ON LOSSLESS DOMAIN COVERAGE
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

Pending platform runners do not block P7A development. P7A domain semantics and schema v4 remain platform-independent across macOS, Windows, Linux, Android, iOS and iPadOS.

## Next implementation target

After P7A-3 qualification is green, proceed with **P7A-4 production editor cutover** in controlled slices:

1. project existing room polygon geometry through canonical `SpaceBoundaryTopology`;
2. replace durable wall-index references with `BoundaryEdgeId` where P7A ownership is available;
3. keep wall index only as transient UI projection order;
4. route edits through canonical mutation sessions and explicit lineage;
5. do not migrate legacy P2/wall-host state until a lossless host-remap contract is available;
6. preserve identical engineering semantics across all native targets.
