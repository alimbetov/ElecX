# P6 Space Semantics — technical audit and hardening v1

Branch: `feat/project-structure-authoring`

Audited baseline SHA:

```text
f775239c57ae0d67d2cc49619ac3c0a20c88bf3c
```

## Verdict

**P6 is not implemented on the audited baseline.**

The branch contains the accepted architectural decisions and P1–P5 foundation, but the canonical aggregate still owns only sites, buildings, levels, structural zones and spaces. `ProjectSpaceEntity` has `id`, `levelId`, and `name`; there is no canonical `SpaceUsage`, opening store, adjacency store or overlay-classification store. The canonical schema is still v2 and serializes only the existing P1–P5 stores.

Therefore P6 must not be treated as a small UI extension. It is a cross-cutting canonical-domain stage and is accepted only when domain ownership, validation, P3 mutation/diff/undo, persistence/migration, indexes and destructive dependency checks land together.

## Non-negotiable P6 → P7 boundary

P6 owns semantic space information and topology that does not require durable boundary-edge identity:

```text
P6
├── SpaceUsage
├── OpeningId + opening semantics/connectivity
├── Space adjacency
└── overlay classifications
```

P7 owns durable wall/boundary hosting:

```text
P7
├── BoundaryEdgeId ownership
├── edge lineage across polygon edits
├── preserved/split/merged/created/removed edge mapping
├── durable opening host edge
├── wall-hosted component migration
└── route/surface host remapping
```

P6 MUST NOT introduce a persisted `wallIndex` foreign key. Existing editor `wallIndex` state remains transitional compatibility data only.

## Audit findings

### P0 — canonical P6 stores are absent

`ProjectEntityStores` currently contains only:

```text
sites
buildings
levels
zones
spaces
```

Adding P6 entities outside this consistency boundary would violate the one-authoritative-state rule and would make them invisible to canonical graph validation, P3 authoritative diff, Undo/Redo and persistence.

Required hardening: P6 entities become first-class canonical stores before UI authoring is added.

### P0 — P3 authoritative diff does not know P6

`ProjectEntityDiff.between()` currently compares only the five existing stores. `UndoRecord` and semantic no-op detection depend on that diff.

Required hardening:

- `SpaceUsage` must participate in `ProjectSpaceEntity` equality/diff;
- opening, adjacency and overlay stores must participate in `ProjectEntityDiff`;
- one P6 semantic action increments `LocalProjectVersion` exactly once;
- preview/no-op/failure must not create history;
- Undo/Redo must restore all P6 semantics exactly.

### P0 — canonical codec does not persist P6

`CanonicalProjectDocumentCodec` is schema v2 and serializes only metadata/orientation/sites/buildings/levels/zones/spaces.

Required hardening: schema v3 with deterministic v2 → v3 migration.

Migration defaults:

```text
SpaceUsage       -> unknown
openings         -> []
adjacencies      -> []
overlays         -> []
```

Do not infer `SpaceUsage` from translated names such as "Спальня", "Bedroom" or display labels unless a future migration has explicit provenance proving the mapping.

### P1 — destructive commands must gain P6 dependency awareness

`RemoveSpaceCommand` is currently dependency-safe only for P4 structural stores and explicitly notes that future P6/P7/P11 domains must extend it.

Once P6 exists, a Space cannot be removed while it is referenced by:

- a canonical opening;
- an adjacency relation;
- an overlay classification;
- any later domain reference.

Implicit cascade is forbidden unless the user action explicitly defines a multi-entity semantic command and its complete diff is previewed/validated.

### P1 — structural zone and overlay classification must never be conflated

`ProjectStructuralZoneEntity` represents exclusive structural ownership/grouping. P6 overlays are many-to-many engineering classifications.

A Space may be structurally owned by one Apartment/Common/Technical grouping and simultaneously belong to multiple overlays such as:

```text
Fire compartment FC-03
ACS/security SEC-02
Electrical distribution DB-A
Telecom/network NET-01
Lighting control LZ-04
```

Overlay membership must not reuse `ZoneId` or `ProjectStructuralZoneEntity`.

### P1 — legacy adjacency helper is not canonical adjacency

`AdjacentRoomBuilder` is a geometric construction helper that creates a neighbouring `EngineeringSpace`. It does not represent persisted semantic/topological adjacency and must not become the P6 source of truth.

### P1 — legacy opening geometry cannot define durable wall identity

Legacy editor openings and wall profiles still use transient wall indexes. P6 may preserve opening identity, dimensions and semantic connectivity, but durable edge hosting and host remapping stay P7.

## Target canonical model

### P6A — SpaceUsage

Add canonical persisted `SpaceUsage` to `ProjectSpaceEntity`.

Minimum vocabulary:

```text
unknown
bedroom
livingRoom
kitchen
kitchenLiving
diningRoom
bathroom
wc
showerRoom
entranceHall
corridor
commonHall
wardrobe
storage
pantry
laundry
balcony
loggia
terrace
office
study
garage
parking
electricalRoom
serverRoom
telecomRoom
fireControlRoom
utilityRoom
mechanicalRoom
stairwell
elevatorHall
elevatorShaft
serviceShaft
commercial
commonArea
```

`SpaceUsage` is independent of structural `SpaceType`.

Required command:

```text
SetSpaceUsageCommand
```

Same value is a semantic no-op.

### P6B — canonical openings before BoundaryEdgeId

Introduce stable `OpeningId` canonical records without durable wall-index ownership.

Recommended P6 contract:

```text
ProjectOpeningEntity
├── OpeningId id
├── LevelId levelId
├── connectedSpaceIds        // one = exterior/unresolved side; two = internal
├── OpeningKind
├── widthMm
├── heightMm
├── sillOrBaseElevationMm
└── semantic attributes
```

Opening identity survives dimension and semantic edits.

P6 MUST NOT persist:

```text
wallIndex
polygonEdgeIndex
listPosition
```

P7 later enriches the opening with stable `BoundaryEdgeId` host ownership without replacing `OpeningId`.

### P6C — canonical adjacency

Introduce an explicit stable relation, preferably `SpaceAdjacencyId`.

Conceptual contract:

```text
ProjectSpaceAdjacencyEntity
├── SpaceAdjacencyId id
├── SpaceId spaceAId
├── SpaceId spaceBId
├── SpaceAdjacencyKind
└── OpeningId? openingId
```

Invariants:

- no self-loop;
- both Spaces exist;
- unordered pair is normalized for duplicate detection;
- horizontal adjacency requires compatible level ownership;
- explicit vertical adjacency may cross levels;
- an opening-backed adjacency may reference only an opening whose connected Spaces match the same pair;
- duplicate equivalent adjacency relations are rejected fail-closed.

Adjacency is semantic/topological state. It must not be recomputed from localized labels.

### P6D — overlay classifications

Introduce stable `OverlayClassificationId` and an independent store.

Conceptual contract:

```text
ProjectOverlayClassificationEntity
├── OverlayClassificationId id
├── OverlayDiscipline discipline
├── OverlayKind kind
├── code/name
├── Set<SpaceId> spaceIds
└── extensible properties/provenance later
```

Recommended disciplines:

```text
fire
securityAcs
electrical
telecom
lighting
other
```

Recommended typed kinds include:

```text
fireCompartment
smokeZone
evacuationZone
accessZone
securityZone
restrictedArea
distributionZone
emergencySupplyZone
networkZone
telecomZone
lightingControlZone
custom
```

Membership is many-to-many.

## Required canonical store and index changes

Target `ProjectEntityStores`:

```text
sites
buildings
levels
zones              // structural only
spaces              // includes SpaceUsage
openings
adjacencies
overlays
```

Target hot-path indexes:

```text
openingsBySpaceId
adjacenciesBySpaceId
overlaysBySpaceId
```

The selected-room inspector/generation path must not full-scan all project entities on every rebuild.

## Candidate graph validation

Extend `ProjectAggregateValidator` with fail-closed issues for:

- dangling opening Space/Level references;
- invalid opening cardinality;
- dangling adjacency endpoints;
- adjacency self-loop;
- duplicate normalized adjacency;
- opening-backed adjacency mismatch;
- dangling overlay Space references;
- invalid cross-level membership where the overlay contract is level-scoped;
- structural-zone exclusivity remaining intact independently of overlays.

`CandidateGraphValidator` continues to be the commit gate; widgets do not repair invalid P6 graphs.

## P3 command families

Minimum application commands:

```text
SetSpaceUsage

CreateOpening
UpdateOpening
RemoveOpening

CreateAdjacency
UpdateAdjacency
RemoveAdjacency

CreateOverlayClassification
RenameOverlayClassification
AssignSpaceToOverlay
RemoveSpaceFromOverlay
RemoveOverlayClassification
```

Bulk user actions may intentionally create one multi-entity candidate, for example:

```text
Create fire compartment + assign 8 Spaces
    -> one validated candidate
    -> one LocalProjectVersion increment
    -> one ProjectChangeSet
    -> one UndoRecord
```

## Persistence v3

Canonical schema v3 must encode P6 state deterministically and sort entity collections/ID sets consistently for stable semantic fingerprinting.

Migration chain remains explicit:

```text
v1 -> v2 (Project North migration)
v2 -> v3 (P6 semantic stores)
```

Future/unknown malformed enum values fail closed until an explicit compatibility rule is defined.

Round-trip equality must cover all P6 semantics, not only entity count.

## Legacy adapter rule

Legacy editor state remains a compatibility projection.

Safe promotion before P7 may copy only semantics that can be proven without guessing, for example:

- stable/opening identity when explicitly bound;
- dimensions;
- connected canonical Space identities when known.

It must not promote a legacy `wallIndex` into canonical durable ownership.

## P6 qualification matrix

| Gate | Required proof |
| --- | --- |
| P6Q01 | new/migrated SpaceUsage defaults to `unknown` |
| P6Q02 | SetSpaceUsage is one canonical commit |
| P6Q03 | setting the same usage is a no-op |
| P6Q04 | localized Space name never infers usage |
| P6Q05 | OpeningId survives semantic/dimension update |
| P6Q06 | canonical P6 serialization contains no wallIndex |
| P6Q07 | opening with dangling Space fails closed |
| P6Q08 | opening connectivity cardinality is validated |
| P6Q09 | adjacency self-loop rejected |
| P6Q10 | duplicate unordered adjacency rejected |
| P6Q11 | opening-backed adjacency must match opening Spaces |
| P6Q12 | one Space may belong to multiple overlays |
| P6Q13 | structural-zone exclusivity remains unchanged |
| P6Q14 | dangling overlay Space rejected |
| P6Q15 | RemoveSpace reports all P6 blockers; no hidden cascade |
| P6Q16 | one semantic P6 action -> one version/change-set/undo |
| P6Q17 | Undo/Redo restores P6 entities and usage exactly |
| P6Q18 | schema v3 round-trip preserves all P6 semantics |
| P6Q19 | v2 -> v3 yields usage unknown + empty P6 stores |
| P6Q20 | malformed/unsupported P6 persisted values fail closed |
| P6Q21 | P6 ProjectIndex projections equal canonical stores |
| P6Q22 | semantic fingerprint changes when P6 semantics change |
| P6Q23 | no durable wallIndex reference is introduced |
| P6Q24 | P7 can add BoundaryEdgeId hosting without replacing OpeningId |
| P6Q25 | selected-room P6 projections use indexes, not project-wide scans |

## Implementation sequence

The safe implementation order is:

```text
P6A  IDs + SpaceUsage + semantic entity contracts
P6B  ProjectEntityStores + validator + ProjectIndex
P6C  P3 diff + commands + destructive dependency hardening
P6D  canonical codec schema v3 + migration
P6E  legacy compatibility adapters/projections
P6F  inspector/authoring UX
P6G  P6Q01..P6Q25 full qualification + native CI
```

Do not start with UI dropdowns or direct legacy editor mutations.

## Acceptance status

At audited baseline `f775239c57ae0d67d2cc49619ac3c0a20c88bf3c`:

```text
P5E                        DONE + native-qualified
P6 architecture contract  HARDENED by this audit
P6 production code         NOT IMPLEMENTED
P6 qualification           NOT STARTED
P7 BoundaryEdgeId lineage  intentionally deferred
```

P6 may be marked DONE only after the complete canonical/persistence/mutation path and P6Q matrix pass. The existence of legacy `SpaceType`, editor openings or `AdjacentRoomBuilder` does not satisfy P6.