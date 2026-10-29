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
| P10.6 foundation — IN PROGRESS | Typed architectural VerticalCore usage, stable `LevelId -> SpaceId` host bindings, fail-closed ownership/continuity, mutation/Undo semantics and v16 persistence | `test/p106_vertical_core_hosts_test.dart` |

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

## P10.6 foundation and current boundary

The canonical `ProjectVerticalCore` now has additive architectural usage semantics
and immutable `LevelId -> SpaceId` host bindings while retaining the established
P7 physical core kind. Architectural cores require one distinct canonical host
Space per served LevelId. Aggregate and authoring validation fail closed on
missing buildings/levels/spaces, cross-building levels, wrong-level hosts and
invalid physical continuity.

Host bindings and architectural usage participate in `ProjectEntityDiff`, so
host-only or usage-only updates are real canonical mutations and are covered by
Preview/Commit/Undo/Redo. Destructive Space removal explicitly reports a bound
VerticalCore as a blocker. Level display renumbering preserves the stable
VerticalCoreId, LevelIds and host bindings, covering the identity requirement of
P10-Q08 without using `levelNumber` as a foreign key.

Schema v16 persists only the additive P10 building-core semantics above the v15
canonical payload. The v16 codec reconstructs a single canonical VerticalCore
graph on load and validates it. Pre-v16 codecs reject snapshots containing P10.6
core semantics, preventing silent downgrade/data loss.

P10.6 is **not complete** yet. The branch still needs the production common/core
composition command/generator that materializes common corridors/halls,
stair/elevator/service/riser host Spaces, technical/service candidate Spaces,
boundaries, openings and explicit access/vertical adjacency from one immutable
reserved candidate. Consequently P10-Q07 is still open. The P10.11 building
Wizard/UI remains deliberately out of P10.6.

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
- P10-Q08 targeted coverage: VerticalCore identity/LevelId/host binding survives
  display level renumbering while aggregate continuity remains valid.
- P10.6 hardening coverage: wrong-level/dangling hosts, host-only and usage-only
  mutation diffs, Undo/Redo, destructive host blockers, v16 round-trip and
  fail-closed pre-v16 persistence.

The P10.6 hardening tests are present in the branch; exact-SHA GitHub acceptance
must be checked on the current HEAD before treating them as qualified. Cross-
platform P10 acceptance, dedicated P10 CI gates and the final Q01–Q20 closure
matrix remain P10.13 work.

## Remaining work

1. Complete P10.6 common/core composition and close P10-Q07 end-to-end.
2. P10.7 cottage composition.
3. P10.8 residential tower composition.
4. P10.9 multi-building site composition.
5. P10.10 service/infrastructure anchors.
6. P10.11 building candidate Preview/Diff plus atomic materialization and Wizard.
7. P10.12 building/site generation provenance and lineage closure.
8. P10.13 Q01–Q20, Golden Journeys, cross-platform and exact-SHA acceptance.

P10 is not ready for merge or P11 handoff until those remaining contracts are
closed and the final exact-SHA qualification is green.
