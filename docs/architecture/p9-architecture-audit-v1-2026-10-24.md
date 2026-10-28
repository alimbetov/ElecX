# P9 Apartment Topology Generator — Architecture Audit v1

Date: 2026-10-24  
Branch: `feat/p9-apartment-topology-generator`  
Base: `main@c397302f183d023e4bdd670ac0c8b46c6fad994a`

## Disposition

```text
P8 Wizard platform readiness     PASS
P6 semantic-space readiness     PASS
P7 boundary-topology readiness  PASS
P9 specification readiness      PASS
P9 runtime implementation       NOT STARTED
P9.0 exit disposition           GO TO P9.1
```

No architectural blocker was found that requires redesigning the P8 transaction/preview model.

Two bounded integration adaptations are mandatory during P9:

1. P9.10 must extend the P8 semantic diff projection so `ZoneId`/`SpaceId` are presented as real apartment/space changes instead of generic `other` IDs.
2. P9.12 must add/complete persisted generation provenance for apartment template/family/seed identity; this is a planned P9 canonical extension, not a second state model.

---

# Audit evidence

## Existing Wizard contract

`lib/src/application/project/wizard/wizard_contracts.dart` already provides:

```text
WizardTargetContext
NewProjectWizardTarget
SiteWizardTarget
BuildingWizardTarget
LevelWizardTarget
WizardParameters
WizardProvider
TypedWizardProvider<P>
WizardGenerationContext
WizardProviderRegistry
```

`WizardParameters` is intentionally extensible for later P9/P10 providers, and `TypedWizardProvider<P>` provides the required typed adapter.

## Existing canonical apartment semantics

`ProjectAggregateRoot` already owns canonical stores for:

```text
levels
zones
spaces
openings
adjacencies
overlays
boundaries
```

`ProjectStructuralZoneKind.apartment` already exists.

`ProjectSpaceEntity` already separates:

```text
ProjectSpaceType
SpaceUsage
```

The required apartment usages already exist, including:

```text
bedroom
livingRoom
kitchen
kitchenLiving
bathroom
wc
showerRoom
entranceHall
corridor
wardrobe
storage
balcony
loggia
```

## Existing adjacency/opening semantics

`ProjectSpaceAdjacencyEntity` provides typed symmetric adjacency by stable `SpaceId` and supports:

```text
sharedBoundary
opening
openPassage
vertical
```

`ProjectOpeningEntity` provides stable `OpeningId`, `LevelId`, kind, dimensions and connected spaces.

## Existing stable boundary topology

P7 already provides:

```text
BoundaryPointMm
BoundaryEdgeId
ProjectBoundaryEdge
SpaceBoundaryTopology
BoundaryTopologyChangeSet
BoundaryEdgeLineage
```

Canonical coordinates are integer millimetres and do not depend on Flutter screen coordinates.

## Existing identity reservation

`MutationIdentityReservation` and `ReservedEntityIdKind` can reserve all entity classes needed by P9, including:

```text
zone
space
opening
spaceAdjacency
boundaryEdge
generation
template
```

`ReservedProjectCommand` already enforces:

```text
reserveIdentities()
buildCandidate()
validateReservation()
semanticOperations()
```

Therefore P9 can reserve the complete apartment identity graph before preview and commit the exact frozen candidate.

---

# P9.0 audit matrix

## A01 — Does P9 reuse TypedWizardProvider rather than create a new Wizard API?

Status: `CLOSED`

Evidence:

```text
TypedWizardProvider<P extends WizardParameters>
WizardProviderRegistry
```

are already production P8 contracts. P9 SHALL implement:

```text
ApartmentWizardProvider
  extends TypedWizardProvider<ApartmentWizardParameters>
```

No alternative Wizard API is justified.

---

## A02 — Is LevelWizardTarget sufficient for apartment insertion?

Status: `CLOSED`

`LevelWizardTarget` contains:

```text
ProjectId
SiteId
BuildingId
LevelId
LocalProjectVersion
```

This is sufficient to validate full canonical ownership and stale-version semantics for apartment insertion into an existing level.

New-project apartment startup is a composition concern, not a reason to weaken the target contract. It must reuse the P8 startup flow and arrive at an explicit canonical Level target before apartment materialization, unless one single reserved composite command safely includes the required Building/Level creation.

---

## A03 — Is StructuralZone.apartment represented canonically?

Status: `CLOSED`

Current canonical model contains:

```text
ProjectStructuralZoneKind.apartment
ProjectStructuralZoneEntity
ProjectEntityStores.zones
```

No new apartment-only ownership graph is required.

---

## A04 — Are required SpaceUsage values available?

Status: `CLOSED`

`SpaceUsage` already includes the semantic vocabulary required by P9. P9 may add a new usage only when a real semantic gap is demonstrated; it must never infer usage from RU/EN display names.

---

## A05 — Is adjacency representable canonically?

Status: `CLOSED`

`ProjectSpaceAdjacencyEntity` and `SpaceAdjacencyKind` provide canonical stable-ID adjacency.

P9 template constraints such as `required/preferred/forbidden` remain generator-level policy, while realized selected-candidate adjacency can be materialized through canonical adjacency entities where applicable.

---

## A06 — Is stable BoundaryEdgeId available at materialization time?

Status: `CLOSED`

P7 `SpaceBoundaryTopology` is already canonical and uses integer millimetres plus durable `BoundaryEdgeId`.

This is sufficient for P9 rectilinear candidate materialization without introducing `wallIndex` identity.

P9 MUST allocate boundary IDs through the mutation reservation rather than candidate preview generation.

---

## A07 — Can one ReservedProjectCommand reserve the full apartment graph?

Status: `CLOSED`

Required reservation kinds already exist:

```text
zone
space
opening
spaceAdjacency
boundaryEdge
generation
template
```

P9 should use deterministic semantic reservation slots, e.g.:

```text
zone:apartment
space:entrance
space:living
space:bedroom:1
space:bathroom:1
edge:space:living:1
adjacency:entrance:living
```

One selected apartment can therefore be committed as one canonical mutation and one Undo record.

---

## A08 — Can P8 semantic diff present apartment changes meaningfully?

Status: `ADAPTER`

The P8 diff engine is architecturally reusable but its current projector has product-specific presentation for only:

```text
SiteId
BuildingId
LevelId
```

Other entity types currently fall back to a generic `WizardDiffEntityCategory.other` and ID-based title.

P9.10 MUST extend the projector/presenter contract for at least:

```text
ZoneId → Apartment StructuralZone
SpaceId → semantic SpaceUsage + display name
OpeningId where materialized
SpaceAdjacencyId where user-facing relevance exists
```

This is a presentation/projector extension. The canonical `ProjectSemanticOperation` and frozen preview lifecycle do not require redesign.

Acceptance requirement:

```text
P9 Preview/Diff must not show only raw ZoneId/SpaceId values to the user.
```

---

## A09 — Can save/reopen preserve P9 semantics and provenance?

Status: `ADAPTER`

Canonical P6/P7 stores already own the structural entities P9 needs. P8 Golden Journey has already qualified the canonical persistence owner for the Wizard lifecycle.

P9 adds a new requirement: template/family/variant/generator provenance must survive save/reopen.

P9.12 therefore owns a bounded canonical persistence extension for generation provenance if the current persisted generation model does not yet carry all required fields.

Rules:

```text
provenance belongs to canonical project state/persistence;
not to SVG;
not to widget state;
not to an external sidecar cache.
```

This is not a blocker to P9.1–P9.11 design but is a blocker to final P9 acceptance if not completed.

---

## A10 — Are apartment candidate previews independent of permanent IDs?

Status: `CLOSED`

P8 already separates draft candidate generation from `MutationIdentityReservation`.

P9 candidate identity SHALL therefore be based on:

```text
catalogVersion
templateId/templateVersion
familyId
variantSeedId
normalized parameters
canonicalized candidate geometry/topology fingerprint
```

Permanent `ZoneId`, `SpaceId`, `BoundaryEdgeId` values do not participate in topology-card identity.

---

## A11 — Can target Level ownership be validated fail-closed?

Status: `CLOSED`

The target carries typed Project/Site/Building/Level identity, and `ProjectAggregateValidator` already validates hierarchy relationships such as level/building ownership, zone/level ownership and space/level ownership.

`ApartmentWizardProvider` / reserved command must additionally verify the exact target relation before candidate commit.

Foreign/missing target must return a typed blocker, never fallback to an active UI index.

---

## A12 — Does P9 avoid legacy identity assumptions?

Status: `CLOSED`

The current canonical foundation already uses typed IDs for persistent relationships.

P9 is explicitly forbidden from using as identity:

```text
levelNumber
room number
array/list index
tree path
localized name
SVG element index
screen position
```

Display numbering may exist only as attributes/projection.

---

# Additional findings

## F01 — P8 preview scene is Basic-Building-specific

Severity: `EXPECTED EXTENSION`

`BasicBuildingWizardPreviewProjector` is deliberately a P8 provider projection. P9 should not overload its building-section semantics.

Resolution:

```text
P9.8 introduces ApartmentVectorScene / ApartmentVectorSceneProjector;
P9.10 binds selected P9 candidate to P8 prepared preview lifecycle;
P8 transaction semantics remain unchanged.
```

## F02 — Current P8 diff entity categories are too coarse for P9

Severity: `MANDATORY P9.10 WORK`

Current categories:

```text
site
building
level
other
```

P9 should either:

1. extend the category vocabulary with `zone`, `space`, `opening`, or
2. introduce a provider-neutral entity presenter that supplies typed titles/fields while preserving filtering compatibility.

Preferred direction: provider-neutral canonical entity presenter. This is more reusable for P10/P12 than adding apartment-only branching.

## F03 — Geometry should use canonical integer millimetres from the beginning

Severity: `DESIGN DECISION`

Because P7 already exposes `BoundaryPointMm`, P9 geometry generation should avoid a float-first canonical representation.

Recommended:

```text
area fitting may use exact/decimal calculation internally;
materializable geometry coordinates are integer millimetres;
vector rendering scales from millimetres to display coordinates;
SVG is never the source of those millimetres.
```

## F04 — Shared boundaries require explicit policy

Severity: `P9.6 DESIGN REQUIREMENT`

`SpaceBoundaryTopology` is owned per `SpaceId`. Adjacent rooms may therefore carry geometrically coincident edges with different durable edge IDs unless a higher shared-wall registry links them.

P9.6 must define one of two explicit v1 policies:

```text
A. paired coincident room edges + canonical adjacency entity;
or
B. shared construction/wall relation using existing P7 registries.
```

It must not assume identical coordinates alone are durable shared-wall identity.

Preferred P9 v1 policy:

```text
per-space durable BoundaryEdgeId + explicit ProjectSpaceAdjacencyEntity;
coincident geometry validated;
shared-wall construction linkage added only through existing canonical registry if required by downstream host semantics.
```

This keeps P9 bounded while preserving P7 identity rules.

---

# Risks entering implementation

| Risk | Level | Required control |
|---|---:|---|
| combinatorial candidate explosion | High | bounded templates/seeds/Top-N |
| SVG accidentally becoming source of truth | High | one-way vector projection tests |
| geometry valid visually but topologically invalid | High | hard geometry + adjacency validation |
| P8 diff showing raw IDs | Medium | P9.10 entity presenter extension |
| area fitting floating drift | Medium | deterministic precision + integer-mm boundary |
| large 6–10 room templates becoming ad hoc | Medium | grammar fixtures + deterministic generation |
| provenance omitted from persistence | High | P9.12 save/reopen gate |
| duplicated mirrored candidates | Medium | deterministic semantic dedup/diversity filter |
| hidden parameter coercion | High | typed errors + no-silent-coercion tests |

---

# P9.0 exit gate

```text
P9-G00 = PASS
```

Evidence disposition:

```text
A01 CLOSED
A02 CLOSED
A03 CLOSED
A04 CLOSED
A05 CLOSED
A06 CLOSED
A07 CLOSED
A08 ADAPTER → mandatory P9.10 work
A09 ADAPTER → mandatory P9.12 work
A10 CLOSED
A11 CLOSED
A12 CLOSED
```

There are no unresolved P9.0 `BLOCKER` findings.

Implementation may proceed in this order:

```text
P9.1 ApartmentWizardParameters
→ P9.2 ApartmentTopologyCatalog
→ P9.3 topology grammars
→ P9.4/P9.5 area + semantic validation
→ P9.6 geometry
→ P9.7 ranking
→ P9.8/P9.9 vector + provider
→ P9.10/P9.11 integration + materialization
→ P9.12 provenance
→ P9.13 qualification
```

Final P9 acceptance remains prohibited until A08/A09 adapters and all P9-G01..G13 gates are closed.
