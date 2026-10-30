# P10 Building / Cottage / Residential-Complex Composition Specification v1

Status: **DRAFT — IMPLEMENTATION CONTRACT FOR P10**

Branch: `feat/p10-building-residential-composition`

Baseline: `main@88ee6fcec506272139014946b511385eb73a0460`

## 1. Authority and relationship to existing specifications

This document elaborates P10 from the authoritative P9→P17 execution roadmap. It does not renumber the roadmap and does not replace the existing project-composition foundation decisions.

It is subordinate to, in order of authority:

1. `docs/architecture/native-project-portability-and-sync.md`
2. `docs/architecture/project-composition-foundation-decisions-v1.md`
3. `docs/architecture/elecx-generate-refine-roadmap-principle-v1.md`
4. `docs/architecture/elecx-p9-p17-execution-roadmap-v1.md`
5. `docs/architecture/project-composition-generation-v1.md`

P10 inherits all accepted PRE-P10 contracts: canonical ownership, typed identity, atomic mutation, preview/diff, provenance, deterministic generation, persistence/recovery and fail-closed behavior.

## 2. P10 purpose

P10 composes qualified P9 apartment/space generation into complete residential architectural structures:

```text
Project
└── Site
    ├── Building / Cottage / Service Building
    │   ├── Levels
    │   ├── Structural Zones
    │   ├── Spaces
    │   ├── Openings / adjacency / boundaries
    │   ├── Vertical Cores
    │   └── Service-entry / infrastructure anchors
    └── Outdoor / shared site anchors
```

P10 is a **composition stage**, not an engineering-design stage.

The result of P10 must be ordinary canonical project state that can be edited manually, saved, reopened, undone/redone and later consumed by P11/P12.

## 3. Stage boundary

### 3.1 P9 owns

P9 owns apartment-scale generation:

- apartment topology family;
- room/space semantics;
- geometry;
- openings and adjacency;
- apartment generation provenance;
- deterministic candidate ranking;
- apartment preview/diff/materialization.

P10 must consume P9 contracts. P10 must not fork or duplicate the apartment generator.

### 3.2 P10 owns

P10 owns architectural/site composition:

- building/site generation parameters;
- building templates;
- level-stack generation;
- typical-floor definitions and instances;
- placement of apartment instances on a Level;
- common corridors/halls;
- vertical circulation/core composition;
- detached-house composition;
- residential tower composition;
- residential-complex / multi-building Site composition;
- architectural service/infrastructure anchors;
- P10 preview/diff/atomic materialization;
- P10 generation lineage and provenance;
- P10 qualification and Golden Journeys.

### 3.3 P11 owns

P11 owns generalized engineering connectivity and source topology.

P10 may provide physical anchors for future systems but must not create authoritative P11 engineering topology.

### 3.4 P12 owns

P12 owns engineering starter generation, sizing/selection/calculation and discipline-specific generated content for POWER/LIGHTING/LAN/CCTV/ACS/FIRE.

P10 must never claim that an electrical-room candidate, generator area or PV/inverter area already represents a designed engineering system.

## 4. Explicit non-goals

P10 does not implement:

- cable/device/equipment sizing;
- protection selection;
- circuit synthesis;
- load calculations;
- lighting calculations;
- equipment catalog selection;
- normative compliance verdicts beyond P10 structural constraints;
- final auto-placement of engineering devices;
- physical cable routing;
- selective engineering regeneration;
- backend/cloud collaboration semantics.

Those belong to P11+.

## 5. Product typologies in scope

P10 shall support the following composition families through one shared canonical contract:

```text
DetachedHouse / Cottage
ResidentialTower
MultiStoreyResidentialBuilding
ResidentialComplex / ЖК
MultiBuildingSite
```

The model shall also support composition of:

- basements;
- ground/plinth levels;
- residential levels;
- technical levels;
- roofs;
- common corridors and elevator halls;
- stair/elevator/service shafts;
- parking/service buildings;
- outdoor/service zones;
- service entries;
- future-source physical anchors.

No typology may use a separate parallel project representation.

## 6. Canonical ownership rules

P10 mutations must target `ProjectAggregateRoot` / canonical entity stores.

The following are forbidden as new P10 production authority:

- `String`-concatenated persistent IDs;
- `levelNumber` as a foreign key;
- one mutable object reused by multiple typical-floor instances;
- direct widget-side rebuilding of a Building or Site graph;
- a separate `ComposedBuilding` graph that diverges from the canonical aggregate;
- direct persistence from the generator.

Existing `building_composition.dart`, `cottage_site_builder.dart` and `residential_tower_builder.dart` are transitional/reference implementations. They may be used for behavioral comparison or migration tests, but P10 production code must not deepen their legacy identity/ownership patterns.

## 7. Canonical identities

P10 shall use existing typed identities and add new typed IDs only where a real persistent identity is missing.

Required identities include at least:

```text
ProjectId
SiteId
BuildingId
LevelId
ZoneId
SpaceId
BoundaryEdgeId
OpeningId
VerticalCoreId
ServiceEntryId
GenerationId
TemplateId
```

P10 may introduce dedicated typed identities for persisted composition concepts such as:

```text
TypicalFloorDefinitionId
SiteAnchorId
OutdoorZoneId
PropertyLotId
```

if those concepts cannot safely use an existing identity type.

Identity rules:

- IDs are stable and allocated through the canonical `EntityIdFactory` boundary;
- display names/codes/numbers never become identity;
- every instantiated level/apartment/space/core owns independent IDs;
- rename, renumber and reclassification preserve identity;
- preview-only draft IDs remain scoped to the candidate until commit;
- reservation/materialization uses deterministic semantic generation keys plus injected ID allocation, not string concatenation.

## 8. P10 canonical semantic model

P10 shall compose, not duplicate, the canonical hierarchy:

```text
ProjectAggregateRoot
├── Site
│   ├── BuildingId references
│   ├── outdoor/service anchors
│   └── optional lots/site zones
├── Buildings
│   ├── LevelIds
│   ├── VerticalCoreIds
│   └── composition lineage
├── Levels
│   ├── ZoneIds
│   ├── SpaceIds
│   ├── elevation/order/kind
│   └── typical-floor instance lineage
├── Structural Zones
│   ├── apartment
│   ├── common
│   ├── technical
│   ├── parking
│   ├── utility
│   └── service
├── Spaces
│   ├── ProjectSpaceType
│   ├── SpaceUsage
│   └── canonical geometry/boundary topology
├── Openings / adjacency
├── Vertical Cores
├── Service Entries / physical infrastructure anchors
└── Generation State / Provenance
```

P10 must not require the engineering graph to be populated.

## 9. BuildingGenerationParameters

P10.1 shall introduce an immutable typed input contract conceptually equivalent to:

```dart
final class BuildingGenerationParameters {
  final BuildingCompositionKind kind;
  final SiteId siteId;
  final String displayName;
  final SitePlacement placement;
  final LevelStackParameters levelStack;
  final TypicalFloorSelection? typicalFloor;
  final CommonCoreParameters commonCore;
  final ServiceAnchorParameters serviceAnchors;
  final BuildingTemplateRef? template;
  final int schemaVersion;
  final String generatorVersion;
}
```

The actual API may differ, but the semantics must remain explicit and typed.

All semantically relevant parameters participate in a normalized request fingerprint.

No localized label may drive generation logic.

## 10. BuildingTemplateCatalog

P10.2 shall provide a versioned architectural composition catalog.

A building template describes composition constraints, not live mutable project entities.

Conceptual contents:

```text
BuildingTemplate
- TemplateId
- templateVersion
- typology
- allowed level roles
- default floor-to-floor heights
- typical-floor definitions
- core definitions
- common-space rules
- service-anchor rules
- optional site-placement rules
- compatibility metadata
```

Template rules:

- immutable/versioned after publication;
- no persistent project IDs inside a reusable template;
- deterministic serialization/fingerprint;
- candidate generation records template identity/version in provenance;
- changing catalog version cannot silently mutate an already committed project.

## 11. Level-stack generation

P10.3 shall generate explicit `LevelId`-backed level stacks.

A level is defined semantically by:

```text
LevelId          stable identity
LevelOrdinal     physical/display order
LevelCode        B2 / B1 / 01 / 02 / RF / custom
ProjectLevelKind basement / ground / residential / technical / roof
ElevationMm      physical Z coordinate
floorToFloorMm   vertical interval
```

Requirements:

- `levelNumber` remains compatibility/display metadata only;
- repeated level numbers/codes in different buildings are valid;
- elevation ordering is validated independently from display numbering;
- generated levels have deterministic semantic generation keys;
- invalid/ambiguous level stacks fail before mutation;
- basements, technical levels and roof are first-class roles.

## 12. Typical-floor definition and instances

P10.4 shall formalize typical floors as lineage, not aliasing.

Conceptual model:

```text
TypicalFloorDefinition
- definitionId
- template identity/version
- semantic generation keys
- structural-zone pattern
- apartment placement slots
- common/core geometry contract

FloorInstance
- LevelId
- definitionId
- generationKey
- independent entity IDs
- overridden properties / detached state
```

Rules:

- every instance owns independent Level/Zone/Space/Boundary/Opening IDs;
- no pointer/shared mutable aliases across floors;
- current-floor edits do not affect linked floors unless an explicit propagation command is used;
- later propagation is diff-based and respects field-aware overrides;
- detaching a floor preserves current canonical entities and IDs;
- deleting a definition does not invalidate already materialized detached project state.

P10 only needs enough propagation semantics to prove safe typical-floor lineage. Full selective dependency regeneration remains P15.

## 13. Apartment packing/composition on Level

P10.5 shall compose P9 apartment candidates into a Level.

The generator shall not reimplement P9 room generation.

Conceptual flow:

```text
Level composition request
→ apartment slot definitions
→ P9 candidate requests
→ accepted apartment candidates
→ transform into level-local coordinates
→ compose common/core zones
→ validate collisions/topology/access
→ P10 candidate
```

Rules:

- apartment instances receive independent canonical IDs;
- P9 generation keys/provenance remain traceable under P10 lineage;
- transforms are deterministic integer-mm transforms;
- apartment internal geometry/topology remains semantically equivalent after transform;
- common/shared boundaries are explicitly materialized/reconciled, not inferred from display coincidence;
- apartments remain individually editable after commit;
- replacing one apartment candidate may not silently mutate unrelated apartments.

## 14. Common-space and core composition

P10.6 shall create common architectural/service space required for a usable building composition.

Supported canonical semantics include:

```text
common corridor
common hall
elevator hall
stairwell
elevator shaft
service shaft
electrical riser space
low-current / telecom riser space
technical room candidate
electrical-room candidate
server/telecom-room candidate
fire-control-room candidate
utility/service room
```

The word `candidate` is normative where P10 is only reserving architectural space for future engineering use.

P10 shall guarantee structural ownership, access/topology and stable host identities. It shall not generate equipment inside these spaces.

## 15. Vertical cores

Vertical cores are first-class canonical topology.

P10 shall use the production `ProjectVerticalCore` / `VerticalCoreId` model keyed by `LevelId` nodes.

Each core shall have:

- stable `VerticalCoreId`;
- one owning `BuildingId`;
- explicit served `LevelId` nodes;
- optional host `SpaceId` per level where applicable;
- footprint/transition-anchor semantics where required by the canonical model;
- a typed core kind;
- deterministic lineage/provenance when generated.

Generation must fail closed on:

- cross-building LevelId references;
- disconnected mandatory core sequence;
- duplicate/conflicting core identities;
- missing required host spaces;
- invalid vertical continuity.

## 16. Detached-house / cottage generator

P10.7 shall provide a production generator for a detached house/cottage.

Minimum qualified capabilities:

- one Site containing one detached Building;
- one or more above-ground levels;
- optional basement;
- optional technical/roof role;
- internal stair/core where required;
- exterior/service-entry anchors;
- outdoor/site anchor support;
- save/reopen/undo/redo/provenance.

The cottage generator must use the same candidate/preview/materialization architecture as tower/complex generation.

## 17. Residential tower generator

P10.8 shall provide a production residential-tower generator.

Capabilities:

- basement stack;
- ground level;
- repeated residential levels;
- optional technical level;
- roof;
- multiple apartment zones per typical floor;
- common corridor/hall;
- stair/elevator cores;
- electrical/low-current service core anchors;
- future engineering-room/service-entry anchors.

The implementation must not use `servedLevelNumbers` or generated string IDs as persistent authority.

## 18. Residential-complex / multi-building Site composition

P10.9 shall compose multiple independent buildings into one Site.

Requirements:

- every Building owns independent typed IDs;
- same display level codes/numbers across buildings are valid;
- building placement uses deterministic site-local coordinates and orientation;
- building footprints may not overlap unless an explicit future supported relation permits it;
- shared outdoor/service infrastructure may reference multiple buildings by `BuildingId`;
- site composition does not collapse multiple buildings into one building workspace;
- navigator/editor projections remain unambiguous by typed identity.

The minimum Golden Journey shall contain at least three buildings, including repeated display level numbers between buildings.

## 19. Service entries and future-source readiness

P10.10 shall create physical/service anchors for later engineering stages.

Examples:

```text
electrical service entry
telecom/fiber entry
fire backbone entry
intercom/CCTV backbone entry
generator area
transformer/substation area
PV/inverter area
battery/UPS area
EV charging area
external-lighting feeder anchor
```

Rules:

- P10 anchors are architectural/site objects or service-entry references, not selected engineering equipment;
- each anchor has stable typed identity and stable owning Site/Building/Level/Space references as applicable;
- anchor meaning is explicit; no generic unlabeled point is used as engineering authority;
- P10 performs no source sizing, protection selection, transfer logic or circuit synthesis;
- P11/P12 may later attach engineering topology to these anchors.

## 20. Candidate generation pipeline

All P10 generators shall use one production pipeline:

```text
normalized request
→ request fingerprint
→ template/catalog resolution
→ structural candidate generation
→ P9 apartment sub-candidates where required
→ deterministic composition
→ canonical structural validation
→ candidate fingerprint
→ semantic diff against live project
→ preview
→ stale LocalProjectVersion check
→ atomic ProjectChangeSet
→ one UndoRecord
→ canonical dirty/recovery transition
```

Preview generation shall be side-effect free.

Candidate browsing/ranking shall not allocate committed canonical IDs prematurely.

## 21. Candidate contract

P10.11 shall expose a typed candidate contract conceptually equivalent to:

```text
BuildingCompositionCandidate
- request fingerprint
- candidate fingerprint
- generator version
- template identity/version
- proposed canonical entities
- apartment sub-generation lineage
- warnings / validation evidence
- deterministic ranking metadata where multiple candidates exist
```

The candidate shall be an independent immutable proposal, not a second long-lived project store.

## 22. Preview / diff requirements

P10 uses the existing P8/P9 semantic preview architecture.

Preview must summarize changes at composition semantics, for example:

```text
ADD Building A
ADD 18 Levels
ADD 72 Apartment Zones
ADD 4 Vertical Cores
ADD 1 Electrical Service Entry
ADD 1 Generator Area Anchor
```

The preview shall also permit drill-down to canonical entity changes where supported.

Cancel, validation failure and stale-version failure leave the canonical fingerprint unchanged.

## 23. Atomic materialization

One accepted P10 generation operation shall produce one atomic canonical commit and one Undo record.

Examples:

```text
Generate cottage           → one Undo
Generate tower             → one Undo
Generate 3-building ЖК     → one Undo
Instantiate floors 2..16   → one Undo when part of one confirmed generation action
```

No partial Building/Level/Space/core state may remain after a failed commit.

## 24. Provenance and lineage

P10.12 shall extend existing generation provenance without creating a parallel provenance system.

Required traceability:

```text
GenerationId
P10 generator/version
BuildingTemplate TemplateId/version
request fingerprint
candidate fingerprint
entity generationKey
Building/Level/Zone/Space/Core/Anchor generated identities
P9 child generation lineage for apartment instances
field-aware overrides after manual editing
removed generation keys/tombstones where supported by current provenance contract
```

Rules:

- P10 parent lineage never replaces P9 apartment lineage;
- manually editing one generated apartment/space records overrides without invalidating unrelated lineage;
- deleting a generated entity follows existing provenance/tombstone semantics;
- undo/redo restores exact provenance state expected by the canonical mutation contract.

## 25. Determinism

P10 generation shall be deterministic for identical semantic inputs and explicit versions.

Determinism includes:

- normalized request fingerprint;
- selected template/version;
- level ordering/elevations;
- apartment slot ordering;
- site placement ordering;
- common/core composition;
- candidate fingerprint;
- semantic output ordering.

Persistent UUID-like IDs may be allocated at materialization, but qualification shall compare normalized semantic generation keys/fingerprints where raw allocated identity values are intentionally non-deterministic.

Supported platforms must produce equivalent ordered semantic candidates.

## 26. Geometry and coordinate systems

P10 composition geometry shall use integer millimetres.

Required frames:

```text
Site-local frame
Building-local frame
Level-local frame
Apartment/subcandidate local frame
```

Transforms between frames must be explicit, deterministic and testable.

No floating UI/canvas coordinate may become canonical engineering authority.

Building site placement shall include explicit translation and orientation. Orientation must reuse canonical site/project north semantics rather than invent a second compass model.

## 27. Structural validation

Before preview eligibility and again before commit, the candidate shall pass structural validation including at least:

- unique typed identity within candidate scope;
- valid Site→Building ownership;
- valid Building→Level ownership;
- valid Level→Zone/Space ownership;
- no duplicate exclusive structural-zone membership;
- valid boundary topology;
- valid openings/adjacency;
- no illegal geometry overlaps within composition rules;
- valid LevelId-based vertical cores;
- valid service-entry/anchor references;
- valid typical-floor lineage;
- no cross-building aliasing;
- provenance integrity;
- deterministic candidate fingerprint.

Ambiguity fails closed.

## 28. Failure policy

P10 shall fail closed on:

- stale local project version;
- unknown or incompatible template version;
- unresolved P9 apartment subcandidate failure;
- invalid building/site placement;
- apartment/common/core collision;
- invalid access topology;
- dangling LevelId/SpaceId/BuildingId reference;
- ambiguous host mapping;
- provenance inconsistency;
- persistence/materialization failure;
- platform semantic divergence.

A failure message exposed to UI shall not leak internal/private exception text.

## 29. Persistence and recovery

P10 committed state shall use the existing canonical persistence owner and codecs.

Required round trip:

```text
Generate
→ Preview
→ Apply
→ Save
→ Close
→ Reopen
→ Edit generated entity
→ Save
→ Close
→ Reopen
```

The round trip must preserve:

- multi-building hierarchy;
- typed IDs;
- level identity/order/elevation;
- apartment/common/core composition;
- boundary/opening/adjacency semantics;
- service anchors;
- typical-floor lineage;
- generation provenance and overrides;
- canonical semantic fingerprint.

P10 must not add feature-local file I/O.

## 30. UI / Wizard contract

The initial P10 wizard shall be parameter-driven and preview-first.

Conceptual user flow:

```text
Choose composition family
→ choose/build template
→ configure level stack
→ configure typical floor/apartment mix
→ configure cores/common areas
→ configure service/site anchors
→ Generate candidates
→ inspect preview/diff
→ Apply or Cancel
```

The wizard shall not mutate canonical project state during parameter editing or candidate browsing.

Minimum UI-visible parameters shall be domain-backed; UI labels/ordering are presentation only.

## 31. Work packages and Definition of Done

### P10.1 — BuildingGenerationParameters

Deliver:

- typed immutable request contract;
- normalization;
- validation;
- semantic fingerprint;
- tests for invalid/edge inputs.

Done when equivalent semantic inputs normalize to identical request fingerprints on supported platforms.

### P10.2 — BuildingTemplateCatalog

Deliver:

- versioned template identity;
- immutable template definitions;
- deterministic lookup/fingerprint;
- compatibility checks;
- qualification fixtures.

Done when a candidate records exact template identity/version and unsupported versions fail closed.

### P10.3 — Level-stack generator

Deliver:

- basement/ground/residential/technical/roof roles;
- explicit elevations/order/codes;
- typed LevelId materialization mapping;
- deterministic generation keys.

Done when same display number in different buildings never collides and renumbering does not change LevelId.

### P10.4 — TypicalFloorDefinition + instances

Deliver:

- definition model;
- instance lineage;
- independent canonical IDs;
- detach/override-safe semantics;
- tests proving no mutable aliasing.

### P10.5 — Apartment packing/composition

Deliver:

- P9 adapter/integration;
- deterministic slot transforms;
- multi-apartment Level composition;
- collision/access validation;
- nested lineage.

Done when every apartment remains independently editable and retains P9 semantic integrity.

### P10.6 — Common-space / corridor / core composition

Deliver:

- common structural zones/spaces;
- corridor/hall connectivity;
- core host spaces;
- technical/service-room candidates.

### P10.7 — Cottage generator

Deliver production candidate generation + qualification for detached-house composition.

### P10.8 — Residential tower generator

Deliver production candidate generation + qualification for multi-storey residential tower composition.

### P10.9 — Residential-complex / multi-building Site

Deliver production multi-building candidate generation, site placement and shared site-anchor composition.

### P10.10 — Service entries / outdoor infrastructure anchors

Deliver stable physical anchors for P11/P12 integration without engineering sizing/content.

### P10.11 — Preview/Diff + atomic materialization

Deliver production P8/P9-integrated preview, stale check, atomic ProjectChangeSet and single Undo.

### P10.12 — Provenance / lineage

Deliver nested P10→P9 lineage, override-safe provenance, deletion/tombstone consistency and persistence.

### P10.13 — Qualification / Golden Journeys

Deliver exact-SHA qualification and full CI gates described below.

## 32. Mandatory qualification scenarios

P10 qualification IDs shall use `P10-Qxx`.

### P10-Q01 — Request normalization

Equivalent semantic requests produce the same normalized request fingerprint.

### P10-Q02 — Level identity

Renumber/relabel a generated level and prove `LevelId` and dependent references remain unchanged.

### P10-Q03 — Cross-building repeated level numbers

Two buildings may both contain Level `1` / code `01` without any identity/navigation collision.

### P10-Q04 — Typical-floor independence

Edit one instantiated floor and prove sibling floors are unchanged unless explicit propagation is requested.

### P10-Q05 — P9 apartment integrity

Compose at least two P9-generated apartments on one floor and prove each apartment keeps valid geometry/topology/provenance after placement transform.

### P10-Q06 — Apartment editability

Edit one generated apartment space after P10 commit and prove unrelated apartment instances remain unchanged.

### P10-Q07 — Common access topology

Every apartment requiring common access connects to the generated common corridor/hall through explicit opening/access topology.

### P10-Q08 — Vertical-core identity

A stair/elevator/service core references `LevelId`, survives level display renumbering and preserves continuity validation.

### P10-Q09 — Cottage Golden Journey

Generate → preview → apply → save → reopen → edit → undo/redo → re-save/reopen for a detached house.

### P10-Q10 — Tower Golden Journey

Qualify a tower containing at minimum basement, ground/common, repeated residential levels, vertical cores and roof/technical semantics.

### P10-Q11 — Multi-building Golden Journey

Qualify a Site containing at least three buildings with repeated level display numbers and independent IDs.

### P10-Q12 — Service-anchor persistence

Service entries/outdoor future-source anchors survive save/reopen with exact typed ownership.

### P10-Q13 — Preview cancel is side-effect free

Candidate generation + preview + cancel leaves canonical fingerprint/version/dirty state unchanged.

### P10-Q14 — Stale candidate fail-closed

Mutate live project after candidate creation and prove Apply rejects the stale candidate without partial mutation.

### P10-Q15 — Atomic failure

Inject a post-validation/pre-commit or owner failure and prove no partially generated hierarchy survives.

### P10-Q16 — Single Undo/Redo

One accepted building generation action is reverted and restored by exactly one semantic Undo/Redo transaction.

### P10-Q17 — Provenance round trip

Nested P10 and P9 generation lineage survives save/reopen and manual override recording.

### P10-Q18 — Delete/Undo/Redo generated entity

Delete a generated Level/Zone/Space/anchor through production command semantics and prove provenance/tombstone behavior and exact undo/redo restoration.

### P10-Q19 — Cross-platform determinism

The same fixture/version set yields equivalent ordered candidate semantic fingerprints on all supported native platforms.

### P10-Q20 — No legacy authority

Qualification/static architecture test proves P10 production generation does not persist through transitional `ComposedBuilding`/string-ID/level-number ownership paths.

## 33. Mandatory Golden Journey fixtures

The qualification corpus shall contain at least these fixtures.

### GJ-COTTAGE-01

```text
Site
└── Cottage
    ├── optional basement
    ├── ground
    ├── upper residential level
    ├── stair core
    └── electrical + telecom service anchors
```

### GJ-TOWER-01

```text
Site
└── Residential Tower
    ├── B2 / B1
    ├── ground/common
    ├── repeated residential floors
    │   ├── multiple apartments
    │   ├── common corridor
    │   └── elevator/stair/service cores
    ├── technical level
    └── roof
```

The qualification fixture should exercise at least 16 repeated residential floors even if the generator supports a wider range.

### GJ-COMPLEX-01

```text
Site
├── Building A
├── Building B
├── Building C
├── shared outdoor/service anchors
└── repeated display level numbers across buildings
```

At least one building shall differ in level stack/template to prove the Site is not a clone-only structure.

## 34. CI gates

P10 shall add dedicated qualification CI only when qualification tests exist.

Target gates:

```text
P10-A Domain / application qualification
P10-B Cottage Golden Journey
P10-C Tower Golden Journey
P10-D Multi-building Golden Journey
P10-E Persistence / recovery / provenance
P10-F Preview / stale / atomicity
P10-G Cross-platform semantic determinism
P10-H Exact-SHA final acceptance
```

Existing repository-wide Flutter verification/quality checks remain mandatory.

P10 is not merge-ready while any required hard gate is failing, cancelled, queued or running on the exact acceptance SHA.

## 35. Performance and scalability constraints

P10 shall avoid whole-project deep-copy behavior as a runtime ownership strategy.

Qualification/performance fixtures shall include a residential-complex project large enough to exercise:

- multiple buildings;
- repeated floors;
- multiple apartments per floor;
- hundreds of spaces;
- multiple vertical cores.

Required architectural behavior:

- indexed lookup by typed IDs;
- candidate graph independent from live project;
- targeted copy-on-write/change-set materialization;
- no UI rebuild requirement proportional to every project entity for a local selection change;
- no algorithm whose correctness depends on Map/Set iteration order.

Hard numeric latency budgets should be introduced only with a controlled reference environment and measurement evidence; P10 v1 does not invent unsupported timing numbers.

## 36. Native platform scope

P10 remains native-only:

```text
Windows
macOS
Linux
Android
iOS
iPadOS
```

No Web/browser production path shall be added.

Cross-platform qualification compares semantic results, not byte-for-byte persistence ordering.

## 37. Security / robustness considerations

Although P10 is local architectural generation, generated/imported template data must be treated as untrusted input at validation boundaries.

Requirements:

- bounded counts/dimensions before expensive generation;
- no unchecked recursion from template nesting;
- reject unknown template/schema versions;
- fail closed on malformed references;
- user-visible errors are sanitized;
- generation failure never corrupts the canonical persisted project.

## 38. Implementation sequencing

Recommended critical path:

```text
P10.1 Parameters
  ↓
P10.2 Template Catalog
  ↓
P10.3 Level Stack
  ↓
P10.4 Typical Floors
  ↓
P10.5 P9 Apartment Composition
  ↓
P10.6 Common/Core Composition
  ├──→ P10.7 Cottage
  └──→ P10.8 Tower
          ↓
       P10.9 Multi-building Site
          ↓
       P10.10 Service Anchors
          ↓
       P10.11 Preview/Atomic Apply
          ↓
       P10.12 Provenance
          ↓
       P10.13 Qualification
```

P10.7 and P10.8 may progress in parallel after the shared composition primitives are qualified.

## 39. Commit discipline

Keep implementation evidence auditable:

```text
feat(p10): domain/application capability
fix(p10): proven production defect
refactor(p10): behavior-preserving structural change
 test(p10): qualification/regression only
ci(p10): CI gate only
docs(p10): specification/evidence only
```

Do not mix speculative production changes into qualification commits.

A failed qualification first determines whether the failure is:

1. qualification/test defect;
2. infrastructure failure;
3. proven production defect.

Only case 3 justifies a production fix.

## 40. P10 hard gates

The roadmap hard gates are expanded as follows.

### P10-G1 — Stable canonical ownership

Every generated Building/Level/Zone/Space/Core/Anchor has stable typed ownership and passes canonical aggregate validation.

### P10-G2 — Typical-floor independence

Typical-floor instances own independent IDs and no shared mutable aliases.

### P10-G3 — P9 apartment editability

P9 apartment instances remain independently editable after P10 composition.

### P10-G4 — Multi-building identity

Repeated display level numbers/codes across buildings never cause identity, navigation, persistence or host collisions.

### P10-G5 — Stable cores and service anchors

Vertical cores and service entries use stable typed IDs and physical anchors suitable for later P11/P12 attachment.

### P10-G6 — Preview and atomic mutation

One accepted generation action follows candidate→diff→preview→stale-check→atomic commit and produces one Undo record.

### P10-G7 — Persistence

Save/Reopen preserves the complete multi-building canonical semantic fingerprint and generation lineage.

### P10-G8 — Determinism

Equivalent inputs/versions yield equivalent candidate semantics across supported platforms.

### P10-G9 — Fail-closed integrity

No invalid hierarchy, ambiguous host, stale candidate or partial generation is committed.

### P10-G10 — P11/P12 readiness without leakage

P10 output contains sufficient stable physical/site anchors for P11/P12 but contains no falsely authoritative engineering design produced by P10.

## 41. P10 exit criteria

P10 may be declared `ACCEPTED FOR MERGE` only when all of the following are true on one exact SHA:

```text
P10.1..P10.13 implemented or explicitly closed by accepted scope decision
P10-Q01..P10-Q20 green
Cottage Golden Journey green
Tower Golden Journey green
Multi-building Golden Journey green
Persistence/recovery/provenance green
Preview/stale/atomicity green
Cross-platform semantic determinism green
repository-wide analyze/test/format/quality green
no known open P10 blocker defect
closure/evidence matrix maps each hard gate to test + CI job + exact SHA
```

After merge to `main`, a post-merge exact-SHA acceptance run shall be green before P11 is formally unblocked.

## 42. Architectural conclusion

P10 is the first stage where ElecX must prove that P9 apartment generation scales into a real canonical multi-building project without falling back to transitional single-building/string-ID shortcuts.

The P10 production contract is therefore:

```text
P9 qualified apartment semantics
        ↓
P10 deterministic architectural composition
        ↓
canonical Site / Building / Level / Zone / Space / Core / Anchor state
        ↓
preview + atomic commit + provenance + persistence
        ↓
ordinary editable project state
        ↓
P11/P12-ready physical composition
```

No parallel project model, no shared mutable typical floors, no level-number identity, and no engineering-design leakage are permitted.
