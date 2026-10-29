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

P10.1–P10.3 passed repository-wide GitHub verification/quality on
`184bd8297489a5379257b72a2beb15b69c7b08ae`.

P10.4 implementation commit: `b1685203c10810081a92db9c33da1421efd1bd16`.
Local verification: 1658 tests passed in the full repository suite; the final
targeted P10.4 run passed 17 scenarios. `flutter analyze`, formatting of all 773
Dart files, and `git diff --check` passed. GitHub exact-SHA acceptance is separate
from these local results.

## P10.4 ownership and lifecycle

Definitions and instances belong to the existing
`ProjectEngineeringMetadata.generationProvenanceRegistry`. A definition records
an immutable template reference, semantic slots and an ID-free canonical floor
pattern fingerprint. Geometry and structural entities remain owned exclusively
by `ProjectEntityStores`.

`RegisterTypicalFloorCommand` binds already materialized canonical floors after
checking complete slot coverage, matching patterns, typed ownership and identity
independence. It does not generate or copy apartment geometry. Generation and
placement are P10.5 work; the building Wizard/atomic generation pipeline remains
P10.11 work.

Ordinary canonical commands record field overrides and deletion tombstones in
the affected instance. Detach preserves canonical entities and identities. A
definition can be removed only after all its instances are detached. There is
no implicit propagation between floors; full selective propagation belongs to
P15.

The canonical persistence codec advances to v14, preserving v1–v13 read support.
The default native repository uses this codec. Older v12/v13 provenance codecs
reject P10 lineage rather than silently dropping it. P9 child manifests and
entity provenance remain intact.

## Qualification scope

- P10-Q04: independent Level/Zone/Space/Boundary/Opening/adjacency identities;
  one-floor edits, sibling isolation, detach, deletion, stale failure and Undo/Redo.
- Strict v14 round trips, old-schema migration, malformed/unknown field rejection,
  and Save → Reopen → Edit → Save → Reopen through the production persistence owner.
- Real P9 apartment generation retains child lineage, and a room edit records
  both its P9 field override and its P10 floor override.
- Fingerprint utility extraction preserves existing P9 candidate identities.

These are local Linux qualification scenarios. Cross-platform P10 acceptance,
the dedicated P10 CI gates and the final exact-SHA closure matrix remain P10.13
work. Check the current branch's GitHub Actions result before treating its HEAD
as qualified; this document does not substitute for exact-SHA CI evidence.

## Remaining work

P10.5–P10.13 are not implemented: multi-apartment level composition, common/core
composition, cottage/tower/site generators, service anchors, the full Wizard
preview/apply pipeline, parent/child generation provenance and final qualification.
P10 is not ready for merge or P11 handoff.
