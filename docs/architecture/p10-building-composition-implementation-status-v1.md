# P10 implementation status

Date: 2026-10-29

Branch: `feat/p10-building-residential-composition`

Implementation contract: [P10 specification](p10-building-residential-composition-spec-v1.md).

## Delivered capabilities

| Package | Implementation | Evidence |
| --- | --- | --- |
| P10.1 | Immutable normalized building request, explicit versions and semantic fingerprint | `test/p10_building_generation_parameters_test.dart` |
| P10.2 | Immutable versioned catalog and exact template binding | `test/p10_building_template_catalog_test.dart` |
| P10.3 | Integer-mm level stacks and independent canonical identity reservations | `test/p10_building_level_stack_generator_test.dart` |
| P10.4 | Immutable typical-floor definitions, instance lineage, detach, overrides, tombstones and persistence | Three `test/p10_typical_floor*_test.dart` suites |
| P10.5 | P9 slot generation, rigid apartment placement, collision/access/shared-boundary checks, nested child lineage and v15 persistence | Three `test/p105_*_test.dart` suites |
| P10.6 — COMPLETE | Versioned common/core input, pure common/core generator, reserved canonical materialization, explicit horizontal/vertical access topology, typed VerticalCore hosts and v16 persistence | `test/p106_*_test.dart` suites |

P10.1–P10.3 passed repository-wide GitHub verification/quality on
`184bd8297489a5379257b72a2beb15b69c7b08ae`.

P10.4 implementation commit: `b1685203c10810081a92db9c33da1421efd1bd16`.
Local verification: 1658 tests passed in the full repository suite; the final
targeted P10.4 run passed 17 scenarios. `flutter analyze`, formatting of all 773
Dart files, and `git diff --check` passed. GitHub exact-SHA acceptance is separate
from these local results.

P10.5 implementation commit: `40ccf152e5d4bba43e8745acb7adb35b0846d026`.
Local verification: 20 new P10.5 tests and all 1678 repository tests passed.
`flutter analyze`, formatting of all 782 Dart files, and `git diff --check` passed.
Both `verification` and `quality` passed on that exact implementation SHA:
[GitHub Actions run 40840856854](https://github.com/alimbetov/ElecX/actions/runs/40840856854).

P10.6 implementation lineage includes the versioned input contract
`8eb552391bdf0f2cc36a4705de5295fd40939456`, common/core generator and reserved
materialization `d9c920efaff5d5ebcf5101c10036eca6da09e075`, Q07/Q08 qualification
`a7a768af145ae8b78c164f0c708c7566207ea4c1`, and the final purity-fixture
qualification correction `09c13e6a46a7997603d3ab8d9956040ac7ade42c`.
Both `verification` and `quality` passed on exact SHA
`09c13e6a46a7997603d3ab8d9956040ac7ade42c` in
[GitHub Actions run 40863815760](https://github.com/alimbetov/ElecX/actions/runs/40863815760).
The repository-wide verification suite completed with 1696 tests passed; formatting,
`flutter analyze`, the P8 NFR reference gate and P8 accessibility/i18n acceptance
were also green.

## P10.4 ownership and lifecycle

Definitions and instances belong to the existing
`ProjectEngineeringMetadata.generationProvenanceRegistry`. A definition records
an immutable template reference, semantic slots and an ID-free canonical floor
pattern fingerprint. Geometry and structural entities remain owned exclusively
by `ProjectEntityStores`.

`RegisterTypicalFloorCommand` binds already materialized canonical floors after
checking complete slot coverage, matching patterns, typed ownership and identity
independence. It does not generate or copy apartment geometry. Apartment generation
and placement are supplied by P10.5; the building Wizard generation pipeline remains
P10.11 work.

Ordinary canonical commands record field overrides and deletion tombstones in
the affected instance. Detach preserves canonical entities and identities. A
definition can be removed only after all its instances are detached. There is
no implicit propagation between floors; full selective propagation belongs to
P15.

Typical-floor lineage uses the v14 codec layer. P10.5 composition lineage uses
v15. The current default native repository uses the additive v16 common/core
codec, preserving v1–v15 read support. Older codecs fail closed when a snapshot
contains P10.6 building-core semantics instead of silently dropping typed core
usage or host-space bindings. P9 child manifests and entity provenance remain
intact.

## P10.5 composition contract

`LevelApartmentCompositionGenerator` consumes the existing P9 candidate service
through an explicit composition entry point. P9 still owns normalization,
catalog selection, room generation, geometry qualification and ranking. The
ordinary P9 provider continues to reject a nonempty Level.

Each immutable apartment slot binds an exact P9 selection to a stable semantic
key, display name, integer-grid translation, clockwise quarter-turn and existing
common corridor/hall SpaceId. The composition command rejects collisions,
missing/ambiguous entry hosts, door-interval conflicts and occupied engineering
targets. Shared boundaries and apartment access become explicit canonical
adjacency; entry openings have canonical hosts on both sides.

One parent reservation supplies independent P9 child reservations without
allocating IDs during candidate generation. The existing shared preview/commit
coordinator applies the whole composition as one Undo record. Cancel and stale
confirmation leave canonical state unchanged. Parent composition manifests,
P9 child generation IDs, placement transforms and the hash-checked frozen input
are persisted in the existing provenance owner. Manual apartment edits preserve
unrelated apartments, and removed parent relations retain tombstones.

This stage supplies composition into an existing common-space layout.
Materialization is additive; it does not silently replace already committed
apartments. The new Wizard remains P10.11.

## P10.6 common/core composition contract

The P10.6 input contract is explicitly versioned. Legacy `CommonCoreParameters`
v1 preserves its existing canonical JSON and fingerprints. The v2 contract adds
electrical/telecom riser counts plus typed common/service candidate-space policy,
and the new semantics participate in the normalized building request fingerprint.
The P10.6 production generator accepts the v2 contract and fails closed on an
unsupported legacy request rather than silently applying new defaults.

`BuildingCommonCoreCompositionGenerator` is a pure generator. It produces an
immutable, ID-free common/core plan containing common/service/technical spaces,
horizontal opening proposals, vertical adjacency proposals and typed vertical-core
proposals. It does not mutate the input `ProjectAggregateRoot` and does not allocate
persistent identities.

One `BuildingCommonCoreCompositionCommand` implements the shared
`ReservedProjectCommand` contract. Its `MutationIdentityReservation` allocates all
`ZoneId`, `SpaceId`, `BoundaryEdgeId`, `OpeningId`, `SpaceAdjacencyId` and
`VerticalCoreId` values before candidate materialization. The resulting candidate
is committed through the existing canonical mutation timeline as one atomic Undo
boundary; candidate generation itself remains side-effect free.

The materialized architecture includes generated common corridor/common hall and
elevator-hall spaces, stair/elevator/service core hosts, electrical and telecom
riser spaces, and policy-controlled technical/electrical/telecom/fire-control/
utility candidate rooms. These are architectural reservations only: P10.6 does
not create panels, circuits, loads, devices or engineering routing.

Horizontal connectivity is explicit canonical topology rather than geometric
contact. P10-Q07 composes a real P9 apartment through P10.5 against a corridor
created by P10.6 and proves the apartment entry reaches that generated common
space through an actual opening/access relation. Core-host spaces on adjacent
levels receive typed `SpaceAdjacencyKind.vertical` relationships.

The canonical `ProjectVerticalCore` has additive architectural usage semantics
and immutable `LevelId -> SpaceId` host bindings while retaining the established
P7 physical core kind. Architectural cores require one distinct canonical host
Space per served LevelId. Aggregate and authoring validation fail closed on
missing buildings/levels/spaces, cross-building levels, wrong-level hosts and
invalid physical continuity. Physical continuity is evaluated from canonical
LevelId/slab topology, never from display `levelNumber`.

Host bindings and architectural usage participate in `ProjectEntityDiff`, so
host-only or usage-only updates are real canonical mutations and are covered by
Preview/Commit/Undo/Redo. Destructive Space removal explicitly reports a bound
VerticalCore as a blocker. P10-Q08 qualifies a generated core through schema-v16
Save → Reopen → level display renumber → Undo → Redo while preserving the exact
`VerticalCoreId`, `LevelId` set and host `SpaceId` bindings.

Schema v16 persists only the additive P10 building-core semantics above the v15
canonical payload. The v16 codec reconstructs a single canonical VerticalCore
graph on load and validates it. Pre-v16 codecs reject snapshots containing P10.6
core semantics, preventing silent downgrade/data loss.

The failed Flutter #4760 run on `2151333afa3882c976b1f85dcf03ddcc7540cb3d`
identified a qualification-fixture identity mistake: the purity test created a
fresh `ProjectAggregateRoot` on each getter access and then compared stores with
`same()`. No production mutation defect was present. The fixture was corrected
to generate and verify against one aggregate instance in
`09c13e6a46a7997603d3ab8d9956040ac7ade42c`; the subsequent exact-SHA run was
fully green.

P10.6 intentionally adds no building Wizard/UI. Building candidate Preview/Diff
and Wizard orchestration remain P10.11 scope.

## Qualification scope

- P10-Q04: independent Level/Zone/Space/Boundary/Opening/adjacency identities;
  one-floor edits, sibling isolation, detach, deletion, stale failure and Undo/Redo.
- Strict v14 round trips, old-schema migration, malformed/unknown field rejection,
  and Save → Reopen → Edit → Save → Reopen through the production persistence owner.
- Real P9 apartment generation retains child lineage, and a room edit records
  both its P9 field override and its P10 floor override.
- Fingerprint utility extraction preserves existing P9 candidate identities.
- P10-Q05: at least two real P9 apartments, all four quarter-turns, exact geometry,
  independent identities, explicit shared/access topology and nested lineage.
- P10-Q06: one-apartment edits, single composition Undo/Redo, cancellation, stale
  confirmation and Save → Reopen → Edit → Save → Reopen through the production owner.
- Strict v15 migration/round trips and rejection of unknown fields/versions,
  tampered transforms, mismatched child lineage and lossy old-codec operations.
- P10.6A: v1 byte-compatible canonical request plus v2 electrical/telecom riser and
  candidate-space policy fingerprinting in `test/p106_common_core_parameters_test.dart`.
- P10.6B-D: pure ID-free generation, one reserved complete materialization, one
  Undo/Redo boundary and fail-closed physical continuity in
  `test/p106_common_core_composition_test.dart`.
- P10-Q07: real P10.6 generated corridor plus P10.5 apartment composition reaches
  common access through explicit opening topology in
  `test/p106_common_access_topology_test.dart`.
- P10-Q08: VerticalCore identity/LevelId/host binding survives display renumbering,
  schema-v16 Save/Reopen and Undo/Redo in `test/p106_vertical_core_hosts_test.dart`
  and `test/p106_common_core_lifecycle_test.dart`.
- P10.6 hardening: wrong-level/dangling hosts, host-only and usage-only mutation
  diffs, destructive host blockers, v16 round-trip and fail-closed pre-v16
  persistence.

P10.6 exact-SHA qualification is accepted on
`09c13e6a46a7997603d3ab8d9956040ac7ade42c` / GitHub Actions run `40863815760`.
Cross-platform P10 acceptance, dedicated P10 CI gates and the final Q01–Q20 closure
matrix remain P10.13 work.

## Remaining work

1. P10.7 cottage composition.
2. P10.8 residential tower composition.
3. P10.9 multi-building site composition.
4. P10.10 service/infrastructure anchors.
5. P10.11 building candidate Preview/Diff plus atomic materialization and Wizard.
6. P10.12 building/site generation provenance and lineage closure.
7. P10.13 Q01–Q20, Golden Journeys, cross-platform and exact-SHA acceptance.

P10.1–P10.6 are complete. P10 is not ready for merge or P11 handoff until the
remaining P10.7–P10.13 contracts are closed and final exact-SHA qualification is
green.
