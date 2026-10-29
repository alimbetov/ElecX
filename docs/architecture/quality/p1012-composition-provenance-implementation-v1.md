# P10.12 composition provenance implementation

Date: 2026-10-29
Branch: `feat/p10-building-residential-composition`

The P10.12 implementation extends `ProjectEngineeringMetadata.generationProvenanceRegistry`.
It creates no additional geometry, mutation, history, persistence or recovery owner.
Acceptance is evaluated on the exact source SHA by the P10 final-acceptance workflow;
this implementation note is not an independent CI receipt.

## Production boundary

Cottage, tower, Site composition, service-anchor composition and Building Wizard
commands explicitly implement `CompositionProvenanceSource`. The existing
`ReservedProjectMutationCoordinator` decorates an opted-in top-level command with
`ProvenanceReservedProjectCommand` before reserving identities. One additional
`GenerationId` is allocated through its existing `EntityIdFactory` for that preview.
Internal child `buildCandidate` calls remain composition primitives; they do not
create duplicate parent ownership. The frozen result includes the parent evidence,
and Apply does not regenerate candidates or allocate replacement identities.

One parent describes one confirmed composition operation, including a multi-building
operation. Its semantic reservation paths identify independent Building, Level, Zone,
Space, BoundaryEdge, Opening, adjacency, Slab, VerticalCore, typical-floor definition
and service/shared-anchor identities. Paths are generation keys, never persistent
identity encodings. Existing objects receiving an initial explicit Site placement are
not relabeled as newly generated objects.

The parent stores generator version, frozen normalized request and its SHA-256,
selected candidate fingerprint and exact template/catalog bindings. Custom
parameter-only lower-level cottage requests retain their actual absence of a
published template; no template history is invented. The production Wizard binds
published templates explicitly. P10.5 parent IDs and fingerprints link to unchanged
P9 child manifests. Their generated identities must belong to the P10 parent.

## Editing and deletion

Only canonical-field baseline hashes are retained, not another mutable entity graph.
Ordinary canonical edits mark affected generated fields, including Building placement,
Level attributes, names, geometry edges, core coverage/hosts, anchor purposes and P7
wall bindings. P9 and typical-floor tracking continues independently in the same
registry. Parent input/template/member evidence is immutable. An immutable-evidence
fingerprint detects persisted changes to the original member/baseline set.

Deletion uses the existing dependency-safe production commands. Required hosts,
children and physical dependencies still block unsafe deletion. After explicit
removal of dependencies, removed semantic slots retain their exact typed identity
and baseline as tombstones. Ordinary Create commands cannot reclaim a tombstoned
identity. Undo/Redo restores the complete before/after evidence with exact IDs.

Canonical candidate/session validation rejects invalid parent identity, project/Site
ownership, duplicate generated members, dangling or multiply owned child lineage,
inconsistent field hashes and active/tombstoned state.

## Persistence

`CompositionProvenanceAwareCanonicalProjectDocumentCodec` is additive schema v19
above the existing v18 chain and is the native repository default. It serializes
parent evidence into the existing registry on load. v1–v18 remain readable without
fabricated P10 parent provenance. Older writers reject current P10 parent data,
and disguised v19 payloads fail closed. There is no feature-local file I/O.

## Qualification

`test/p1012_composition_provenance_test.dart` covers Q17/Q18 for all three Wizard
families, full parent/member coverage, original request/candidate fingerprints,
independent manual overrides, anchor name/host overrides, strict v19 rejection,
historical migration, dependency-ordered Space → Zone → Level → Building deletion,
tombstone ID-reuse rejection, persistence and exact Undo/Redo. Existing P10.7–P10.11
round trips now use the current v19 writer; historical codec fixtures explicitly
project pre-v19 data and current-state downgrade remains rejected.

The P10.13 closure matrix maps this evidence to exact-SHA CI jobs and the larger
Golden Journeys. Full P10 acceptance additionally requires native semantic parity.
