# P10 implementation status

Date: 2026-10-30

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
| P10.7 — COMPLETE | Reserved detached building, level stack, slabs, internal cores, physical common opening hosts and production persistence lifecycle | `test/p107_cottage*_test.dart` |
| P10.8 — COMPLETE | Tower shell, multiple P9 apartments per repeated residential floor, independent typical-floor lineage and one parent Apply | `test/p108_*_test.dart` |
| P10.9 — COMPLETE | Mixed cottage/tower Site composition, independent IDs, explicit Building-local → Site transforms, collision checks, shared typed anchors and v17 persistence | Four `test/p109_*_test.dart` suites |
| P10.10 — COMPLETE | Ten typed service/infrastructure anchor purposes, explicit Site/Space/wall hosts, live P7 physical binding, atomic mutation and v18 persistence | Four `test/p1010_*_test.dart` suites |
| P10.11 — COMPLETE | Site-level production Wizard, immutable composition candidate, canonical Preview/Diff, architecture plus explicit anchors in one reserved Apply, shared owner and strengthened Q13–Q16 | Four `test/p1011_*_test.dart` suites plus P8 bootstrap regression |
| P10.12 — COMPLETE | Parent → floor → P9 evidence, field overrides, deletion tombstones, local reconciliation and additive v19 persistence | `test/p1012*_test.dart` suites |
| P10.13 — IMPLEMENTED | Q01–Q20 traceability, large Golden Journeys, recovery, seven native semantic artifacts and exact-SHA A–H acceptance | `qualification_test/p10_p1013*_test.dart`, `.github/workflows/p10-final-acceptance.yml`; acceptance remains bound to each run's SHA |

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
v15. P10.6 introduced the additive v16 common/core codec. The current default
native repository uses v18, preserving v1–v17 read support. Older codecs fail closed when a snapshot
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

## P10.7 cottage acceptance

The cottage implementation and boundary qualification are present on
`6342155cefc1808ef8a85f1e6dcf5c6edd200594`; both repository CI jobs passed in
[run 40869799821](https://github.com/alimbetov/ElecX/actions/runs/40869799821).
A follow-up inspection identified missing durable hosts for generated common
openings. The earlier Q07 fixture used a corridor without common openings, so
it did not expose the integration failure when a real common/core layout was
adopted by P10.5.

`921f71ba2b6eaf6332661a38adfa8557bd3fdfaa` binds every common opening to the same
physical interval on both canonical boundaries, strengthens Q07 with an actual
common hall, and qualifies P10-Q09 through the production persistence owner:
Generate → Preview → Apply → Save → Reopen → Edit → Undo → Redo → Save → Reopen.
Both `verification` and `quality` passed on that exact SHA in
[run 40872137194](https://github.com/alimbetov/ElecX/actions/runs/40872137194).

The cottage's v2 common/core contract, single-building Site scope and supported
level limits are explicit. Physical service/outdoor anchors remain P10.10;
building-wide generation provenance remains P10.12. Pending anchor intent is
retained in the immutable candidate and its semantic fingerprint. These stages
are not claimed complete by cottage acceptance.

## P10.8 residential tower contract

`ResidentialTowerCompositionGenerator` binds an exact published tower template,
uses the existing P10.3 level stack and shared building-shell materializer, and
places accepted P9 apartments along a deterministic corridor. It supports a
basement stack, ground, at least two repeated residential levels, optional
technical level and roof. Stair, elevator, electrical riser and telecom riser
cores are required; service shafts and candidate technical rooms use the P10.6
policy. The current strategy uses an axis-aligned footprint and integer-grid
placements; envelope overflow and unsupported rotation fail closed.

P9 now has an explicit Site exploration entry point. Before new LevelIds exist,
its transient projection uses the existing Site as its host. It does not invent
placeholder LevelIds. Candidate generation, qualification, ranking and exact
P9 identities use the same pipeline as ordinary apartment generation. Tower
materialization copies architectural P9 output, not engineering equipment.

Cottage and tower share `BuildingShellCompositionCommand`; tower does not fork
the structural/core materialization implementation. Independent child identity
reservations are combined into one immutable parent reservation without further
allocation during Apply. The existing canonical session commits the complete
building, floors, cores and apartments as one Undo record.

Each residential floor retains its P10.5 parent → P9 child manifests and registers
an independent P10.4 instance of one immutable typical-floor definition. Canonical
entities own geometry exclusively. Field edits record both P9 and typical-floor
overrides while preserving sibling floors. Existing schema v16 persists the
result, including cores, hosts and apartment/floor lineage; no new codec or
parallel persistence owner is introduced.

P10.8 implementation commit: `7ed194c3ea2cadc7e2b4364eb703db1f928c79ff`.
Local targeted qualification passed 37 scenarios, including 15 new P10.8 tests,
cottage regression and P9 identity/projection regression. All 1718 repository
tests passed; analyzer is clean and all 800 Dart files are formatted.
Both `verification` and `quality` passed on that exact implementation SHA in
[GitHub Actions run 40873583159](https://github.com/alimbetov/ElecX/actions/runs/40873583159),
including formatting, analyzer, P8 reference/accessibility/i18n gates and the
repository-wide test suite.

P10-Q10 qualifies the actual production chain through the persistence owner:
Generate → Preview → Apply → Save → Reopen → Edit → Undo → Redo → Save → Reopen.
Level display renumbering preserves typed core coverage and hosts. Independent
P9 and typical-floor overrides survive re-save/reopen without changing sibling
floors. Negative qualification covers stale/cancelled previews, unsupported
versions, missing mandatory cores, invalid floor selections, reservation aliases,
foreign/occupied Sites and overflowing apartment geometry.

## P10.9 multi-building Site contract

`SiteCompositionGenerator` combines the existing production cottage/tower
commands into one immutable candidate. Building slots and shared-anchor requests
are normalized by semantic key. The generator allocates no persistent IDs.
One parent reservation combines independent child reservations; Apply uses the
same canonical session, version, dirty state, persistence owner and Undo stack.
Append is explicit and preserves existing buildings and their canonical IDs.
Ordinary standalone cottage/tower entry points retain their empty-Site guard.

`ProjectEngineeringMetadata.siteLayout` is the single owner of BuildingId-keyed
physical placement values and shared architectural anchors. It does not duplicate
the Building/Level/Space graph. Canonical room, boundary, slab and core geometry
remains Building-local. `ProjectSiteLayoutProjection` applies explicit reversible
integer-mm translation and quarter-turn orientation to the Site view. Orientation
uses `ProjectEngineeringNorth`'s canonical clockwise-from-+Y convention; composing
or moving a building does not reset Project North or modify P9 geometry/baselines.

Positive-area footprint overlap, unsupported angles, invalid coordinate ranges,
foreign ownership and geometry outside a declared local footprint fail closed.
Boundary contact is legal. New composition into an existing Site requires known
placements for all existing buildings; legacy coordinates are never guessed.
`UpdateBuildingSitePlacementCommand` changes only the physical transform and is
a real metadata mutation with Undo/Redo. Shared Site anchors own stable
`ServiceEntryId` values, explicit meaning, a Site-local point and at least two
served `BuildingId` references. They reserve shared service/access locations;
system-specific service anchors are delivered by P10.10; engineering equipment
belongs to later stages.
Shared references block implicit Building deletion, and deleting an unreferenced
empty Building removes its placement on the same canonical Undo boundary.

Schema v17 stores only additive placement/shared-anchor metadata above the v16
canonical graph. It strictly validates versions, coordinate-frame declaration,
types, duplicate identities, ownership and spatial integrity. Read support for
v1–v16 preserves existing state without inferred placements. Older codecs reject
new placement metadata instead of silently dropping it. The default native
repository used v17 at P10.9 acceptance; P10.10 advances it to v18.

P10-Q11 uses one real P10.8 tower plus two P10.7 cottages, repeated floor number/code
`1` / `01`, independent geometry/host identities, different Site rotations and
shared anchors serving all three buildings. Navigator and editor context are
qualified by typed identity. The production owner journey covers Generate →
Preview → Apply → Save → Reopen → Edit → Undo → Redo → Save → Reopen; unrelated
buildings and existing P9/typical-floor lineage remain independent. Cancellation,
stale confirmation and a failure injected after all child candidates have been
materialized leave live state/history unchanged.

P10.9 implementation commit: `58a52d14fbf71390d63943b3a112b3497279026c`.
The final precision fix is `036b4d7f1ca4863cdf47b2f1fda10811e90a2b8f`.
P10.9 adds 24 tests; all 1742 repository tests passed after the precision fix,
including the existing cottage/tower/P9 suites. Analyzer is clean; all 810 lib/test
Dart files plus the standalone coordinate probe are formatted.

Review of the canonical coordinate boundary exposed a JavaScript precision
failure: absolute shoelace products near 1e9 mm could turn a 10×10 mm footprint
into zero area. Area now uses coordinates relative to a polygon vertex before
multiplication. Integer semantics and existing P9 identities are preserved.
`qualification_test/p109_site_coordinate_smoke.dart` passed in the Dart VM and
as optimized JavaScript executed by Node at both positive and negative coordinate
limits. This is targeted numeric-kernel evidence; full cross-platform acceptance
remains P10.13.

Both `verification` and `quality` passed on exact SHA
`036b4d7f1ca4863cdf47b2f1fda10811e90a2b8f` in
[GitHub Actions run 40878600998](https://github.com/alimbetov/ElecX/actions/runs/40878600998),
including formatting, analyzer, P8 reference/accessibility/i18n gates and the
repository-wide test suite.

## P10.10 service/infrastructure anchor contract

`ServiceAnchorCompositionGenerator` materializes ten explicitly typed purposes:
electrical, telecom/fiber, fire backbone and intercom/CCTV wall entries;
generator, transformer/substation, PV/inverter, battery/UPS and EV areas; and
external-lighting feeder anchors. These reserve architectural attachment
locations without selected equipment, supply capacity, protection, circuits,
transfer logic or engineering routes.

Immutable anchors belong to the existing `ProjectEngineeringMetadata.siteLayout`
and use stable `ServiceEntryId` identities. Site anchors carry explicit served
`BuildingId` references and a Site-local point. Space anchors carry exact
Building/Level/Space ownership, a Building-local point and height above the
physical Level. The four entry purposes require a durable wall host. Their
canonical entity stores ownership and height, while the existing P7
`BoundaryHostedObjectRegistry` exclusively owns the `BoundaryEdgeId` and offset.
There is no cached wall XY or parallel physical host store.

`ProjectServiceAnchorResolver` provides live local/Site positions and physical
elevation for subsequent P11/P12 attachment. P7 edge splits remap the same
physical binding while preserving the exact ServiceEntryId and point. Building
placement changes project local points through the existing Site transform;
display level renumbering does not change physical ownership or elevation.

The generator consumes P10.1's selected anchor intent only with complete explicit
locations. It allocates no persistent identities, normalizes semantic keys and
uses the existing reserved preview/session pipeline for one atomic Apply and
one Undo record. Ordinary update/rebind/remove commands preserve identities and
use the same session, dirty state and persistence owner. Destructive Space and
Building removal reports anchor dependencies instead of silently cascading them.
Appending another P10.9 building preserves existing anchors and wall hosts.

Canonical validation rejects dangling/cross-owner references, missing or invalid
wall bindings, out-of-room points, invalid height/offset, points inside opening
voids or outside an explicit wall profile, duplicate physical anchors, orphan
wall bindings and outdoor points inside placed buildings. Empty selection is a
no-op; cancelled, stale and failed previews do not publish partial metadata.

Schema v18 persists the typed anchors and restores wall references into the same
P7 registry on load. Versions v1–v17 remain readable without inferred locations.
Unknown/missing fields, unsupported versions/purposes, duplicate IDs (including
collisions with P10.9 shared anchors) and invalid joins fail closed. Older codecs
reject lossy writes and disguised v18 data. P9 and typical-floor lineage remain
unchanged; generalized building/site provenance is still P10.12 work.

P10-Q12 qualifies all ten purposes on a real three-building P10.9 Site through
the production persistence owner: Apply → Save → Reopen → Edit → Undo → Redo →
Save → Reopen, preserving exact typed ownership, physical hosts and sibling
architecture. Additional qualification covers P7 split migration, explicit
rebind, display renumbering, Site movement and append, and failure atomicity.
P10.10 implementation commit: `e7c03c5f6700ef4099030b37a7db68e5f712f29d`.
All 25 new P10.10 tests and all 1767 repository tests passed locally; the full
local run used `flutter test --no-pub --concurrency=2`. Analyzer is clean,
all 821 lib/test Dart files are formatted, and `git diff --check` passed.
Both `verification` and `quality` passed on that exact implementation SHA in
[GitHub Actions run 40889113252](https://github.com/alimbetov/ElecX/actions/runs/40889113252),
including the default-concurrency repository test suites, formatting, analyzer
and the P8 reference/accessibility/i18n gates.

## P10.11 production Wizard and atomic Preview/Diff

Site-level Building Wizard now opens the P10 provider through the existing shared
runtime port. The Site node action remains available when a Level is active;
apartment generation retains its own engineering capability guard. New Project
startup remains on the P8 Basic Building Wizard and preserves its compatibility
seed/binding.

The P10 screen exposes cottage, tower and mixed complex input, exact published
templates, physical level stacks, apartment mix, common/core layout, explicit
Site placement and service/shared anchors. Existing unplaced buildings need
explicit coordinates and footprint dimensions. P10.9 owns placement/collision
rules and P10.10 owns physical service-anchor validation/binding.

One ID-free composition proposal freezes request/candidate fingerprints,
versions, exact templates and P9 selection evidence. A combined reservation
materializes the existing P10 architecture and explicitly selected anchors into
one canonical candidate. The screen renders Site/floor views and semantic counts
from that frozen candidate; canonical Diff supports typed cores, slabs, anchors,
physical wall hosts and placement fields. Apply uses the shared mutation session,
version, persistence owner and Undo stack. Parameter edits, Back, Cancel, stale
and failed Apply discard prepared reservations.

The strengthened Q13–Q16 suites cover all three composition families, including a
fault injected in the shared canonical commit after validation/change-set
construction but before state/history publication. The production-handle UI test
qualifies owner identity, explicit legacy placement, one Apply, Undo/Redo and
save/reopen. P8 startup and responsive/error-privacy regressions are covered.

Audit findings and gate evidence are recorded in
[the P10.11 production wiring audit](quality/p1011-production-wiring-audit-v1.md).
The focused qualification passed 41 tests, including 32 new scenarios. All 1803
repository tests passed locally; analyzer, formatting of all 832 lib/test Dart
files and `git diff --check` are clean.

P10.11 implementation acceptance SHA: `b38b76d35d3dcb70a2caf157233684bfb030a2e1`.
Both `quality` and `verification` passed on that exact SHA in
[GitHub Actions run 40928831209](https://github.com/alimbetov/ElecX/actions/runs/40928831209),
including full repository tests and P8 reference/accessibility/i18n gates.
The earlier `ca5739af` baseline is not used as acceptance evidence.

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

## P10.12 and P10.13 implementation

P10.12 now records complete composition parent evidence in the existing registry
and reserved mutation boundary. The native repository uses additive schema v19,
retaining v1–v18 reads and rejecting lossy downgrades. Parent → P10.5 → P9 lineage,
field overrides, physical host edits, tombstones and exact Undo/Redo are covered in
`test/p1012_composition_provenance_test.dart`. See
[the implementation note](quality/p1012-composition-provenance-implementation-v1.md).

P10.13 adds the Q01–Q20 closure matrix, production lifecycle fixtures with 16 repeated
tower floors and a mixed 408-Space Site, persistence failure/retry qualification,
static ownership checks and a dedicated A–H native CI workflow. The workflow
requires Linux/macOS/Windows plus native Android phone/tablet and iOS/iPadOS
semantic artifacts. See [the closure matrix](quality/p10-qualification-closure-matrix-v1.md).

## Final audit and acceptance evidence

The original P10.12/P10.13 implementation passed all A–H gates, including seven
native artifacts and their semantic equality, on
`cc76ba4aa197bda7b33f58737338cb844ac98248` in
[P10 run 40937863491, attempt 2](https://github.com/alimbetov/ElecX/actions/runs/40937863491/attempts/2).
The regular repository `quality` and `verification` jobs passed that same SHA in
[run 40937863289](https://github.com/alimbetov/ElecX/actions/runs/40937863289).
The first iPadOS attempt timed out after the Xcode build without reaching the
test; the second completed the actual native test. It is not evidence of a
reproducible generator defect.

The follow-up audit fixes parent provenance allocation on local edits: one room
rename now replaces 1 of 598 records and 0 baseline maps, instead of all 598.
Actual store and metadata diffs drive indexed reconciliation; immutable evidence,
unaffected records/manifests and exact history remain preserved. New regressions
cover metadata-only placement/anchor/P7 host edits, independent compositions,
advisory-ID omission, repeated overrides, frozen Apply and fail-closed tampering.
One projected root replaces root construction inside each manifest iteration.

Apple qualification now has separate boot/Drive timeouts, bounded process-group
cleanup with permission-race handling, pinned iOS 26.4 reference profiles
(iPhone 17 Pro / iPad Pro 13-inch M5), retained verbose logs and
bounded failure diagnostics. These remediation changes require their own green
exact-SHA acceptance; the older green SHA cannot qualify newer source.

Windows setup also uses the existing exact Flutter 3.47.7 pin directly in native
P10 and inherited P9 desktop/parity jobs. This removes the YAML-parser install
dependency that failed with Chocolatey HTTP 503/504 before compilation. SDK
version guards and all build, semantic equality and final acceptance gates remain
mandatory.

Implementation exists for P10.1–P10.13. Final acceptance is determined by the
P10-H artifact and repository `quality`/`verification` on the same exact SHA;
this status document does not substitute for unfinished or failing CI jobs.

A main-branch merge is separate from feature implementation. P11 formal handoff
requires a green post-merge exact-SHA acceptance run. CAD frame-time/FPS
qualification is a separate measured performance gate; the large P10 fixtures
establish composition/lifecycle coverage, not GPU timing guarantees.
