# ElecX P9 → P17 Execution Roadmap v1

Status: **AUTHORITATIVE EXECUTION ROADMAP FOR P9..P17**

This document is subordinate to:

- `project-composition-foundation-decisions-v1.md` — authoritative P0..P17 ordering;
- `elecx-generate-refine-roadmap-principle-v1.md` — authoritative product invariant.

It does not renumber or replace P9..P17. It expands those phases into an executable development path with stage contracts, parallel enabling tracks, qualification gates and merge criteria.

---

## 1. Product objective

ElecX follows one product loop:

```text
GENERATE FIRST
      ↓
ENGINEER REFINES
      ↓
DEPENDENCIES PROPAGATE
      ↓
MANUAL DECISIONS ARE PRESERVED
      ↓
ONLY IMPACTED ENGINEERING STATE IS RECALCULATED
```

The end-to-end target is:

```text
P9   Apartment baseline
        ↓
P10  Building / Cottage / Residential-complex composition
        ↓
P11  Generalized EngineeringGraph
        ├──────── Equipment Catalog track
        ├──────── Normative / constraint evidence track
        └──────── Dependency / impact semantics foundation
        ↓
P12  Engineering Auto-Configuration
     POWER / LIGHTING / LAN / CCTV / ACS / FIRE
        ↓
P13  Auto-Placement
        ↓
P14  Auto-Routing
        ↓
P15  Impact Analysis + Selective Regeneration
     + Manual Override Preservation
        ↓
P16  Production Persistence
        ↓
P17  Native Cross-Platform Qualification
```

The generated result is never a disposable picture. It becomes ordinary canonical project state that remains editable by the engineer.

---

## 2. Roadmap rules

### R-01 — One canonical model

Manual, generated and imported/promoted entities share the same canonical model. No P9+ generator may create a parallel project representation.

### R-02 — Preview before mutation

Generation, placement, routing and regeneration use:

```text
request
→ candidate
→ validate
→ semantic diff
→ preview
→ stale-version check
→ atomic ProjectChangeSet
→ one UndoRecord
```

### R-03 — Stable identity

Generated entities receive stable typed identities at the reservation/materialization boundary. Pure browsing/ranking does not allocate canonical IDs.

### R-04 — Determinism

For identical semantic inputs and explicit algorithm/catalog versions, supported platforms produce equivalent ordered semantic results.

### R-05 — Engineering semantics precede UI

No UI-specific representation may become engineering authority. SVG, Flutter widgets, canvas coordinates and localized labels are projections only.

### R-06 — Manual authority

Regeneration cannot silently overwrite manual entities, user overrides, locks or explicit suppressions.

### R-07 — Local edits are local by default

A room/wall/device/route edit creates an impact set. It must not imply whole-project regeneration unless the dependency graph proves that scope.

### R-08 — Fail closed

When identity, geometry, topology, evidence, hosting, compatibility or normative state is ambiguous, mutation is blocked rather than guessed.

---

# 3. Critical path and parallel tracks

The critical path is P9→P17, but not all work is strictly serial.

```text
                         ┌──── Equipment Catalog ────────┐
                         │                               │
P9 ──→ P10 ──→ P11 ─────┼──→ P12 ──→ P13 ──→ P14 ──→ P15 ──→ P16 ──→ P17
                         │                               │
                         ├──── Normative Evidence ───────┤
                         │                               │
                         └──── Parametric Edit/Impact ───┘
```

Parallel tracks may advance early, but they cannot bypass the stage gates below.

---

# 4. P9 — Apartment Generator 1..10

## Purpose

Generate a deterministic, semantically valid, editable apartment baseline from a small parameter set and a familiar topology family.

## Required output contract

P9 must hand P10/P11:

```text
Apartment StructuralZone
Spaces with SpaceUsage
stable semantic generation keys
integer-mm room geometry
stable boundary topology after materialization
real openings
semantic adjacency
wet-core semantics
exterior exposure semantics
entry/access graph
editable canonical geometry
field-aware generation provenance
```

## Work packages

```text
P9.1  typed request / normalization / fingerprints
P9.2  versioned topology catalog
P9.3  topology-family grammars
P9.4  deterministic integer area fitting
P9.5  adjacency / wet-core / semantic qualification
P9.6  graph-aware deterministic geometry
P9.7  candidate scoring + diversity ranking
P9.8  vector/native preview projection
P9.9  ApartmentWizardProvider
P9.10 P8 Preview/Diff integration
P9.11 atomic canonical materialization
P9.12 generation provenance
P9.13 qualification / Golden Journey
```

## Immediate implementation path

The active critical sequence is:

```text
P9.6 GraphAware Geometry V2
  ↓
close 1..10 geometry/access/exposure/appendage corpus
  ↓
P9.7 scoring/ranking
  ↓
P9.8 renderer
  ↓
P9.9 Wizard provider
  ↓
P9.10 Preview/Diff
  ↓
P9.11 materialization
  ↓
P9.12 provenance
  ↓
P9.13 Golden Journey
```

## P9 hard gates

P9-G1 — every supported 1..10-room request class has at least one accepted geometry path.

P9-G2 — openPlan, separate kitchen and kitchenLiving remain semantically distinct.

P9-G3 — all required access relations become real openings/open passages and post-packing reachability is preserved.

P9-G4 — required shared-boundary minimums and exposure assignments survive geometry.

P9-G5 — no overlap/self-intersection/invalid host is accepted.

P9-G6 — same versions + same request produce the same ordered candidates/fingerprints on supported platforms.

P9-G7 — Apply creates one Zone + Spaces + Boundaries + Openings + adjacency + provenance atomically.

P9-G8 — Undo/Redo/Save/Reopen preserve exact canonical identities and semantic fingerprint.

P9-G9 — generated apartment remains editable; P9 does not create a special immutable wizard-only object.

## P9 exit

`P9 = ACCEPTED FOR MERGE` only after P9.13 Golden Journey and full CI are green.

---

# 5. P10 — Building / Cottage / Residential-Complex Generator

## Purpose

Compose qualified apartment/space generators into real site/building structures without losing canonical ownership or editability.

## P10 scope

```text
Detached house / cottage
multi-storey residential building
residential tower
residential complex / ЖК
multi-building Site
typical floors
multiple apartments per floor
common corridors / halls
stairs / elevators / shafts
technical floors
basements
roof
parking/service buildings
outdoor/service zones
service entries
```

## Proposed work packages

```text
P10.1 BuildingGenerationParameters
P10.2 BuildingTemplateCatalog
P10.3 Level-stack generator
P10.4 TypicalFloorDefinition + instance generation
P10.5 Apartment packing/composition on Level
P10.6 Common-space / corridor / core composition
P10.7 Cottage / detached-house generator
P10.8 Residential-tower generator
P10.9 Residential-complex / multi-building Site composition
P10.10 service entries / outdoor infrastructure anchors
P10.11 Preview/Diff + atomic materialization
P10.12 provenance / lineage
P10.13 qualification / Golden Journeys
```

## Important distinction

P10 owns **composition**, not engineering design.

P10 may create architectural/service anchors such as:

```text
electrical-room candidate space
telecom/server room
fire control room
service entry
generator area
PV/inverter area
vertical riser/core
```

but P12 decides engineering starter content.

## External power/source readiness

P10 must provide physical/site anchors for later P11/P12 support of:

```text
Grid
Transformer / substation
Generator
UPS
Battery energy storage
PV / Solar
Inverter
EV charging / bidirectional source where supported
```

P10 does not calculate or size those systems; it guarantees that the canonical project can host them.

## P10 hard gates

P10-G1 — every generated Building/Level/Space has stable typed ownership.

P10-G2 — typical-floor instances own independent IDs; no shared mutable aliases.

P10-G3 — apartment instances from P9 remain individually editable.

P10-G4 — multi-building projects allow repeated display level numbers without identity collision.

P10-G5 — vertical cores and service entries use stable IDs and physical anchors.

P10-G6 — one generation action = one candidate/diff/atomic commit/Undo.

P10-G7 — Save/Reopen preserves full multi-building semantic fingerprint.

---

# 6. Equipment Catalog — mandatory parallel track

Equipment Catalog is not a numbered replacement for P11/P12. It is a cross-cutting enabling subsystem that must reach `CATALOG_READY_FOR_P12` before P12 can be considered production-ready.

## Start point

Begin during late P10 / early P11 so that P12 is not blocked by catalog design.

## Canonical model

```text
Manufacturer
EquipmentFamily
EquipmentModel
TechnicalParameters
Ports / media capabilities
Dimensions
Mounting constraints
Electrical characteristics
Environmental limits
Compatibility rules
Normative attributes / evidence references
Price records
Availability records
Data-source provenance
Catalog version
```

## Catalog requirements

- extensible parameter schema without losing typed core engineering fields;
- manufacturer/model identity separated from display name;
- versioned technical data;
- source/evidence provenance;
- explicit unknown/indeterminate values rather than guessed defaults;
- compatibility queries usable by P12/P13/P14;
- offline/local cache support;
- price/availability are mutable commercial data and do not redefine technical identity;
- generated project persists chosen model identity and the evidence/version used for selection.

## Suggested catalog work packages

```text
CAT-1 domain identity + taxonomy
CAT-2 technical parameter schema
CAT-3 ports/media/capabilities
CAT-4 dimensions/mounting/environment
CAT-5 compatibility rules
CAT-6 price/availability/provenance
CAT-7 repository/import API
CAT-8 query/ranking API
CAT-9 qualification corpus
```

## Catalog gate before P12

`CATALOG_READY_FOR_P12` requires deterministic queries for at least the component classes used by the first P12 POWER/LIGHTING vertical slice.

---

# 7. P11 — Generalized EngineeringGraph

## Purpose

Create the machine-readable engineering dependency backbone shared by all disciplines and later by impact analysis.

## Core model

```text
EngineeringGraph
├── EngineeringNode / Component
├── Port
├── LogicalEdge
│   ├── controls
│   ├── suppliedBy
│   ├── memberOf
│   ├── communicatesWith
│   ├── protects
│   └── other typed relations
├── Circuit / Loop / Segment
├── MediaConnection
└── references to PhysicalRoute (P14)
```

## Media must be extensible

Initial media include:

```text
AC power
DC power
lighting control
dry contact
Ethernet
PoE
optical fibre
coax
RS-485 / field bus
fire loop
security/access bus
```

Do not encode every discipline as a cable route.

## P11 work packages

```text
P11.1 typed Node/Port/Edge identities
P11.2 media and capability model
P11.3 circuit/loop/group abstractions
P11.4 graph invariants + compatibility validation
P11.5 cross-discipline extension contract
P11.6 source/supply topology model
P11.7 dependency-edge semantics for future impact analysis
P11.8 graph diff/fingerprint/persistence contract
P11.9 Equipment Catalog adapters
P11.10 qualification corpus
```

## Source topology

P11 must represent multiple supply sources without forcing them into one utility-grid assumption:

```text
Grid
Generator
UPS
Battery
PV / inverter
Transformer
multiple source / transfer topology
```

Actual sizing/selection remains discipline-specific P12 logic.

## P11 hard gates

P11-G1 — logical topology is independent from physical routing.

P11-G2 — incompatible port/media/direction relations fail closed.

P11-G3 — graph identity survives component rename/move/reroute.

P11-G4 — graph supports POWER/LIGHTING/LAN/CCTV/ACS/FIRE without discipline-specific forked graph stores.

P11-G5 — dependency relation types are sufficient for P15 impact traversal.

P11-G6 — Equipment Catalog component capabilities map into graph ports deterministically.

---

# 8. Normative / constraint evidence — parallel track

Engineering automation may use product presets and heuristics, but must not present them as statutory compliance unless evidence exists.

This parallel track provides:

```text
NormativeProfile
RuleId
jurisdiction/profile
source document + revision
applicability conditions
input evidence
result PASS / FAIL / INDETERMINATE
explanation
```

Initial profiles may include KZ and later IEC/EU mappings, but profile coverage must be explicit rather than implied.

Rules used by P12/P13/P14 distinguish:

```text
hard safety / normative constraint
engineering design constraint
product preset
optimization preference
```

`INDETERMINATE` is a first-class result when evidence is insufficient.

---

# 9. P12 — Engineering Auto-Configuration

## Purpose

Produce an explainable engineering starter baseline immediately after architectural composition.

## Disciplines

```text
POWER
LIGHTING
LAN
CCTV
ACS
FIRE
```

Additional systems may later plug into the same P11 framework.

## Shared generator architecture

Each discipline implements a shared contract conceptually similar to:

```text
EngineeringGenerationRequest
  project context
  SpaceUsage / geometry
  engineering profile
  Equipment Catalog snapshot/version
  normative/constraint profile
  existing manual/locked state
        ↓
DisciplineGenerator
        ↓
EngineeringCandidate
  logical graph mutations
  equipment selections
  calculations/evidence
  warnings/indeterminate results
  generation keys/provenance
        ↓
validate → diff → preview → apply
```

## P12 vertical-slice order

Recommended order:

```text
P12A POWER
P12B LIGHTING
P12C LAN
P12D CCTV
P12E ACS
P12F FIRE
P12G cross-discipline qualification
```

POWER and LIGHTING should establish the shared generation framework first because they exercise load, circuit, protection, cable and room semantics strongly.

## POWER baseline

At minimum:

```text
source topology
boards
load groups
circuits
protective-device intent
cable intent/specification
phase/load metadata where applicable
calculation evidence
```

Support for generator/PV/UPS/BESS starts as explicit source topology and grows by qualified rules; no source is silently assumed equivalent to grid supply.

## LIGHTING baseline

At minimum:

```text
SpaceUsage-driven lighting demand
luminaire groups
switch/control intent
circuits
mounting-host requirements
calculation evidence / assumptions
```

## LAN/CCTV/ACS/FIRE

Generators create logical topology and component requirements first. Physical placement and routing are P13/P14 responsibilities.

## P12 hard gates

P12-G1 — every generated object has a stable `generationKey`.

P12-G2 — generation is idempotent under identical versions/input.

P12-G3 — all equipment selections cite Catalog identity/version/evidence.

P12-G4 — missing technical evidence yields warning/INDETERMINATE, never fabricated PASS.

P12-G5 — discipline generation cannot mutate unrelated disciplines without a declared dependency.

P12-G6 — Preview/Diff is understandable at engineering-semantic level, not only raw entity changes.

---

# 10. P13 — Auto-Placement

## Purpose

Convert P12 logical/component requirements into qualified physical hosts and positions.

## Inputs

```text
SpaceUsage
room geometry
BoundaryEdgeId / slabs / ceilings
openings
wall construction/thickness
wet zones
facade/exterior semantics
service entries
vertical cores
Equipment Catalog dimensions/mounting rules
normative/design constraints
existing manual/locked objects
```

## Placement result

Placement is a proposal, not an unconditional mutation.

```text
ComponentPlacementCandidate
  component/generation key
  stable host
  position/orientation
  mounting evidence
  constraint results
  score/reasons
```

## P13 work packages

```text
P13.1 host taxonomy
P13.2 placement constraints
P13.3 candidate generation
P13.4 feasibility filtering
P13.5 scoring / optimization
P13.6 collision / clearance validation
P13.7 preview/diff/apply
P13.8 manual lock/override interaction
P13.9 discipline qualification
```

## P13 hard gates

- no generated component without a valid physical host;
- no placement based only on screen coordinates;
- manual/locked placement is preserved;
- same semantic geometry + versions gives deterministic candidate ordering;
- all rejected placements have explainable reasons.

---

# 11. P14 — Route Topology / Auto-Routing

## Purpose

Materialize physical routing for P11 logical connections after P13 supplies physical endpoints.

## Routing pipeline

```text
logical engineering topology
→ source/target physical anchors
→ host-surface/channel graph
→ wall/slab/vertical-core/site transitions
→ route candidates
→ hard feasibility constraints
→ normative/design constraints
→ cost vector/ranking
→ PhysicalRoute candidate
→ preview/diff/apply
```

## P14 work packages

```text
P14.1 generalized routing graph
P14.2 route channels / trays / conduits / surfaces
P14.3 wall/slab penetration model
P14.4 vertical-core transitions
P14.5 site/outdoor transitions
P14.6 capacity/fill/segregation constraints
P14.7 multi-object route optimization
P14.8 cost vector and explainable ranking
P14.9 manual waypoints/locks
P14.10 reroute on topology change
P14.11 qualification / performance
```

## P14 hard gates

- PhysicalRoute never substitutes for logical EngineeringGraph relation;
- cross-space/cross-level transitions require explicit physical evidence;
- cable/route identity survives qualified geometry edits where logical identity is unchanged;
- manual mandatory waypoints and locks are preserved;
- no teleport across wall/slab/core/site boundary.

---

# 12. P15 — Impact Analysis + Selective Regeneration

## Purpose

Deliver the main long-term ElecX differentiator: generated engineering state remains maintainable after professional manual refinement.

## Canonical state classes

The exact final enum may differ, but the system must distinguish concepts equivalent to:

```text
GENERATED_BASELINE
GENERATED_MODIFIED
MANUAL
MANUAL_OVERRIDE
USER_SUPPRESSED_GENERATED
LOCKED
PROPAGATED
STALE / DIRTY
REQUIRES_REVIEW / CONFLICT
```

## Impact flow

```text
ProjectChangeSet
      ↓
ImpactAnalyzer
      ↓
DependencyGraph traversal
      ↓
ImpactSet
  directly changed
  transitively affected
  unaffected
      ↓
SelectiveRecalculation
      ↓
RegenerationCandidate
      ↓
ADD / UPDATE / PRESERVE / REMOVE / CONFLICT
      ↓
Preview / engineer decision / atomic apply
```

## Examples

```text
wall moved
  → hosted openings/components may move
  → affected route endpoints/lengths dirty
  → voltage-drop/cable quantity evidence dirty
  → unrelated FIRE loop preserved

manual breaker replacement
  → equipment choice preserved
  → compatibility/protection evidence revalidated
  → generator cannot silently restore old model

generated socket removed by engineer
  → suppression recorded
  → regeneration does not silently recreate it
```

## Associative geometry integration

Generated room geometry is ordinary editable geometry. Boundary movement may propagate through coupled rooms according to explicit policy.

Required concepts:

```text
MoveBoundaryCommand
ResizeSpace intent
ChangeWallThicknessCommand
GeometryConstraintGraph
pushChain
resizeNeighbor
pushUntilLock
user-driven vs propagated consequences
```

Stable `BoundaryEdgeId` is preserved for pure moves/resizes that do not change topology.

## P15 work packages

```text
P15.1 field-aware provenance
P15.2 override/suppression/lock semantics
P15.3 dependency/impact graph
P15.4 dirty-state propagation
P15.5 selective recalculation
P15.6 selective regeneration diff
P15.7 conflict model
P15.8 associative geometry propagation
P15.9 hosted object propagation
P15.10 selective reroute/revalidate
P15.11 qualification / adversarial edits
```

## P15 hard gates

P15-G1 — manual entities and overrides survive regeneration by default.

P15-G2 — unrelated engineering disciplines remain byte/semantically untouched where no dependency exists.

P15-G3 — all propagated modifications are explainable back to their driver change.

P15-G4 — conflicts are explicit; no silent winner.

P15-G5 — regeneration remains previewable, atomic and undoable.

---

# 13. P16 — Production Persistence

## Purpose

Persist the complete production project efficiently and transactionally for large real projects while keeping application/domain layers storage-agnostic.

## Target

```text
Application/domain
      ↓
ProjectRepository
      ↓
DriftProjectRepository
      ↓
SQLite
```

Legacy JSON remains import/compatibility, not the final editable store.

## Persisted domains

At minimum:

```text
project/site/building hierarchy
levels/zones/spaces
boundary topology/constructions
openings/adjacency
vertical/slab topology
engineering graph
components/ports/circuits/loops
physical routes/penetrations
catalog selection references
calculation/normative evidence
provenance/overrides/suppressions/locks
impact/dirty state where durable
navigation resume state
schema/version metadata
```

## P16 work packages

```text
P16.1 normalized Drift schema
P16.2 transactional repository
P16.3 indexes/query projections
P16.4 migration framework
P16.5 legacy JSON import
P16.6 crash/recovery semantics
P16.7 large-project performance
P16.8 corruption/isolation diagnostics
P16.9 backup/export boundary
```

## P16 gates

- one canonical mutation persists transactionally;
- interrupted write cannot expose half a ProjectChangeSet;
- migrations preserve canonical semantic fingerprint;
- large-project local edits do not require rewriting one giant blob;
- repository API remains independent of Drift/SQLite in feature code.

---

# 14. P17 — Native Cross-Platform Qualification

## Purpose

Prove that desktop/tablet/mobile clients preserve the same project and engineering semantics while allowing platform-appropriate interaction.

## Supported native classes

```text
D1 Desktop
  Windows / macOS / Linux

T1 Tablet
  iPadOS / Android tablet

M1 Mobile
  iOS / Android phone
```

## Functional product profile

```text
Desktop
  primary professional authoring
  full precision editing
  keyboard/mouse/trackpad

Tablet
  full Wizard/review
  practical authoring
  touch/stylus/external keyboard

Phone
  Wizard/review/apply
  lightweight inspection/editing
  not primary detailed CAD authoring
```

## Non-negotiable semantic invariant

For identical semantic request/catalog/generator/scoring versions, platform class must not change generated engineering meaning.

UI may change layout and input modality, but must not call a simpler mobile engineering algorithm.

## Qualification matrix

At minimum:

```text
390x844 / 844x390 phone
768x1024 / 1024x768 tablet
1366x1024 large tablet
1280x720 compact desktop
1440x900 standard desktop
1920x1080 desktop
```

Test:

```text
portrait/landscape
safe areas
48dp touch targets
mouse/trackpad/touch/stylus
keyboard focus
external tablet keyboard
text scaling
screen readers
reduced motion
no hover dependency
save/reopen semantic fingerprint
candidate ordering/fingerprint parity
```

## P17 gates

P17-G1 — same project opens with equivalent canonical fingerprint on all supported native platforms.

P17-G2 — P9/P10/P12 candidate semantic ordering is platform-independent where versions are equal.

P17-G3 — desktop/tablet/mobile interaction differences never enter canonical engineering fingerprints.

P17-G4 — no Web/browser business/persistence runtime is introduced.

---

# 15. Recommended branch / delivery sequence

Do not implement P9..P17 as one long-lived mega-branch.

Recommended feature sequence:

```text
feat/p9-apartment-topology-generator                ACTIVE

feat/p10-building-generation-foundation
feat/p10-typical-floor-composition
feat/p10-residential-complex-generation

feat/equipment-catalog-foundation
feat/equipment-catalog-query-ranking

feat/p11-engineering-graph-foundation
feat/p11-source-topology
feat/p11-impact-dependency-contract

feat/p12-power-generation
feat/p12-lighting-generation
feat/p12-lan-generation
feat/p12-cctv-generation
feat/p12-acs-generation
feat/p12-fire-generation
feat/p12-cross-discipline-qualification

feat/p13-auto-placement-foundation
feat/p13-placement-optimization

feat/p14-routing-graph
feat/p14-auto-routing
feat/p14-routing-qualification

feat/p15-provenance-overrides
feat/p15-impact-analysis
feat/p15-selective-regeneration
feat/p15-associative-geometry

feat/p16-drift-repository
feat/p16-project-migration
feat/p16-large-project-qualification

feat/p17-native-qualification
```

Branch names are planning defaults; exact branch decomposition may change without changing the P9..P17 phase order.

---

# 16. Stage-entry / stage-exit contract matrix

| Phase | Must receive | Must produce before exit |
|---|---|---|
| P9 | P6/P7/P8 semantics + stable mutation | editable apartment canonical candidate/materialization |
| P10 | qualified P9 structural units | editable multi-level/multi-building composition |
| P11 | P10 canonical project + catalog capabilities | generalized logical engineering/dependency graph |
| Catalog | component taxonomy/evidence sources | deterministic technical selection/query API |
| P12 | P11 + Catalog + constraint profiles | explainable engineering starter baseline |
| P13 | P12 components + canonical hosts | qualified physical placements |
| P14 | P11 logical edges + P13 anchors | qualified PhysicalRoutes |
| P15 | provenance + dependency graph + changesets | selective impact/recalculation/regeneration |
| P16 | complete canonical domains | transactional scalable local persistence |
| P17 | production semantics/UI | cross-platform equivalence evidence |

No stage is accepted solely because its happy-path UI works.

---

# 17. Program-level Golden Journey

The complete P9→P17 program should ultimately prove this scenario:

```text
1. Create Project
2. Select similar apartment/building topology
3. Enter trusted baseline parameters
4. Generate apartment/building candidate
5. Preview/Diff and Apply
6. Generate POWER/LIGHTING/LAN/CCTV/ACS/FIRE starter state
7. Auto-place qualified equipment
8. Auto-route qualified connections
9. Engineer changes real room dimension / wall thickness
10. Coupled geometry propagates according to explicit policy
11. Hosted objects follow stable hosts where valid
12. Only impacted calculations/routes become dirty
13. Engineer removes one generated device
14. Engineer replaces one generated equipment model manually
15. Selective regeneration preserves suppression/manual replacement
16. Preview explains every propagated/regenerated change
17. Apply is one atomic project mutation per semantic action
18. Undo/Redo preserves identity
19. Save/Close/Reopen preserves canonical semantic fingerprint
20. Open same project on another supported native platform
21. Engineering semantics remain equivalent
```

This Golden Journey is the program-level definition of the ElecX product direction.

---

# 18. Current execution priority — 2026-10-25

The active phase is P9.

Current immediate sequence:

```text
1. P9.6 GraphAware Geometry V2
2. close current geometry corpus blockers
3. green P9.6 access/exposure/appendage qualification
4. P9.7 candidate scoring/diversity
5. P9.8 preview renderer
6. P9.9 Wizard provider
7. P9.10 P8 semantic Preview/Diff integration
8. P9.11 canonical materialization
9. P9.12 provenance
10. P9.13 Golden Journey
11. merge P9
12. start P10 + Equipment Catalog foundation in parallel
```

P10 must not begin by copying P9 geometry internals. It consumes qualified P9 contracts.

P12 must not begin as a set of unrelated discipline-specific object generators. It consumes P11 generalized graph + Equipment Catalog + explicit constraint evidence.

P15 must not be postponed conceptually until the end: P9-P14 contracts must preserve the identities, generation keys, provenance and dependencies that P15 will need.

---

# 19. Decision summary

The development path is therefore:

```text
P9   generate one editable apartment well
P10  compose editable buildings/sites from qualified structural generators
P11  make engineering dependencies machine-readable and discipline-extensible
CAT  make real equipment selectable from typed, versioned evidence
P12  generate explainable engineering baseline
P13  place it physically
P14  route it physically
P15  keep it correct after the engineer changes reality
P16  persist it at production scale
P17  prove the same engineering semantics across native platforms
```

The strategic success criterion is not maximum automation percentage. It is the shortest safe path from a familiar topology to a professionally corrected, explainable and maintainable engineering project.