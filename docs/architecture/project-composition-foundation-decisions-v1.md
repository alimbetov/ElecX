# Project Composition Foundation Decisions v1

## Status

Accepted implementation constraints for `feat/project-structure-authoring` after the pre-implementation technical audit.

This document is subordinate only to:

- `docs/architecture/native-project-portability-and-sync.md`

It is the authoritative reconciliation layer for the project-structure specifications and complements:

- `docs/architecture/project-structure-authoring-v1.md`
- `docs/architecture/project-template-wizard-v1.md`
- `docs/architecture/project-composition-generation-v1.md`
- `docs/architecture/project-navigator-current-location-v1.md`
- `docs/architecture/room-surface-navigator-v1.md`
- `docs/architecture/project-variant-qualification-v1.md`

If an older section in those documents conflicts with a decision below, this document wins until an explicit ADR changes the decision.

ElecX remains native-only: macOS, Windows, Linux, Android, iOS and iPadOS. Web/browser runtime is out of scope.

## Audit disposition

The product specification is mature enough to move from design into foundation implementation.

Implementation status:

```text
P0/P1 foundation implementation                GO
P2 repository boundary                          after P1
P3 command/change-set/undo                       after P1/P2
P4+ authoring UI                                 blocked until foundation gates pass
Wizard / ЖК / engineering generation            blocked until P1-P3 pass
```

The existing `EditorBuildingWorkspace`, `EditorProjectDocument`, `ComposedBuilding` and navigator code are transitional adapters. They must not become the permanent ownership model for the new subsystem.

## Decision 1 — One authoritative canonical project state

### Problem

The current runtime carries a `ComposedBuilding` in `EditorBuildingWorkspace` while `ComposedProjectSite.site.buildings` contains another `Building` projection. Synchronization rebuilds and replaces the building copy manually.

### Decision

The target architecture has exactly one authoritative canonical state for every persistent project entity.

Conceptually:

```text
ProjectAggregateRoot
├── metadata
├── SiteAggregate
│   ├── outdoor zones
│   ├── service entries
│   └── BuildingId references
├── BuildingStore / BuildingAggregate by BuildingId
│   ├── levels
│   ├── structural zones
│   ├── vertical cores
│   └── typical-floor lineage
├── EngineeringGraphStore
├── RouteStore
├── GenerationState
└── indexes
```

UI/editor/navigator state is projected from this source of truth.

### Important clarification

`one authoritative aggregate` does **not** require one giant deeply copied Dart object.

The aggregate is a consistency/ownership boundary. Internally it may use immutable entity stores, indexed maps and targeted copy-on-write updates so that editing a room does not clone a 100-floor building with thousands of components and routes.

### Migration rule

Existing `ComposedBuilding` and `ComposedProjectSite` may remain transitional adapters. New Wizard, multi-building, structural authoring or persistence logic must not deepen duplicated ownership.

## Decision 2 — Stable typed external identities

Application/domain contracts introduce typed identifiers:

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
ComponentId
PortId
CircuitId
RouteId
GenerationId
TemplateId
```

Persistent/external IDs are globally stable UUID-like values allocated through `EntityIdFactory` or an equivalent injected service.

They must never depend on:

- list index;
- level number;
- platform;
- database row id;
- UI tree path;
- room sequence counter;
- opening sequence counter;
- regenerated display name.

`levelNumber`, apartment number, label and display order are attributes, not identities.

Preview-only draft identities are scoped to the draft and never leak into committed persistence.

Existing IDs survive rename, renumber, reclassification, movement, rerouting and regeneration while the logical entity remains the same.

## Decision 3 — Level identity is `LevelId`, never `levelNumber`

### Problem

Current runtime uses `activeLevelNumber`, `Map<int, openings>`, `servedLevelNumbers` and navigator IDs such as `level:2`.

This is incompatible with multi-building projects, renumbering, typical floors and stable references.

### Decision

All persistent and application references use `LevelId`.

Target examples:

```text
activeLevelId: LevelId
openingsByLevel: Map<LevelId, ...>
VerticalCoreNode.levelId: LevelId
ServiceEntry.targetLevelId: LevelId
navigator level node → LevelId
```

Level metadata is separated conceptually into:

```text
LevelId          identity
LevelOrdinal     ordering
LevelCode        human-facing code such as B1 / 01 / RF
BuildingLevelKind semantic role
ElevationMm      physical vertical coordinate
```

An implementation may initially retain `levelNumber` as a compatibility field, but no new foreign key or navigation identity may use it.

## Decision 4 — Structural commands use atomic mutation/change-set semantics

All canonical structural changes execute through one mutation boundary:

```text
ProjectCommand
→ validate request
→ verify expected LocalProjectVersion
→ build candidate state
→ validate candidate graph
→ compute ProjectChangeSet
→ commit atomically
→ increment LocalProjectVersion
→ publish one committed change notification
→ append one UndoRecord
```

Failure before commit leaves the previous valid project unchanged.

Conceptual contracts:

```dart
sealed class ProjectCommand {}

final class ProjectMutationRequest {
  final LocalProjectVersion expectedVersion;
  final ProjectCommand command;
}

final class ProjectMutationResult {
  final ProjectChangeSet changeSet;
  final LocalProjectVersion version;
  final UndoRecord undo;
}
```

Required command families include Building, Level, Zone, Space, Opening, VerticalCore, ServiceEntry, Wizard generation and selective regeneration.

Widgets never rebuild the project graph directly.

### Undo boundary

A semantic action is one undo transaction:

```text
create one level             → one Undo
create room                  → one Undo
generate apartment           → one Undo
create floors 2..20          → one Undo
regenerate Lighting          → one Undo
```

## Decision 5 — Local project version and remote revision are different concepts

`LocalProjectVersion` protects in-process/local concurrent mutation from stale candidates caused by autosave, Wizard preview, regeneration, Undo/Redo or another editor command.

`RemoteBaseRevision` belongs to future backend synchronization.

They must not be conflated.

```text
LocalProjectVersion
→ protects local aggregate commit

RemoteBaseRevision
→ protects backend revision push/conflict
```

A stale local candidate fails/recomputes; it does not silently overwrite a newer local state.

## Decision 6 — Structural type and semantic room usage are separate

Keep structural `SpaceType` and add canonical persisted `SpaceUsage`.

Target semantic set includes at least:

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

Examples:

```text
SpaceType.room          + SpaceUsage.bedroom
SpaceType.technicalRoom + SpaceUsage.electricalRoom
SpaceType.hall          + SpaceUsage.parking
```

Existing projects migrate to deterministic values, normally `unknown`, unless old semantics permit a safe non-guessing mapping.

## Decision 7 — Structural zones and overlay classifications are different

### Problem

Current `BuildingZone` enforces exclusive membership: a space can belong to at most one zone. That works for apartment/common/parking ownership but not for fire compartments, ACS/security zones or electrical distribution areas.

### Decision

Separate two concepts:

```text
StructuralZone
- apartment
- common
- technical
- parking
- storage
- utility
- commercial
- office
- service

OverlayClassification / EngineeringZone
- fire compartment
- ACS/security zone
- electrical distribution zone
- telecom/network zone
- other discipline classifications
```

Structural zone membership may remain exclusive where the domain requires it. Overlay classifications are many-to-many and must not be forced into `BuildingZoneKind`.

## Decision 8 — Typical floors are lineage, not shared mutable objects

Introduce explicit lineage:

```text
TypicalFloorDefinition
    ↓
FloorInstance
    ├── LevelId
    ├── definitionId
    ├── generationKey
    └── override state
```

Every instantiated level/space has independent stable IDs. No shared mutable room/zone aliases are permitted.

Edit scopes:

```text
current floor only
all linked floors
selected linked floors
```

Propagation uses semantic keys/change-set mapping, not pointer aliasing or level-number-derived IDs.

## Decision 9 — Provenance is field-aware and regeneration-safe

A single `userModified` boolean is insufficient.

Conceptual model:

```text
EntityProvenance
├── originType
├── generationId?
├── templateId?
├── templateVersion?
├── generatorVersion?
├── discipline?
├── generationKey?
├── overriddenProperties
└── lockedFromRegeneration
```

`originType` includes at least:

```text
manual
wizard
import
generatedEngineering
regenerated
```

Prefer typed `PropertyKey` values to arbitrary field-name strings where practical.

Regeneration computes candidate + diff first:

```text
ADD
UPDATE
PRESERVE
REMOVE
CONFLICT
```

Manual entities and overridden properties are preserved by default. Regenerating one discipline cannot modify another without an explicit declared dependency.

## Decision 10 — Engineering graph separates semantic and physical relations

Future POWER/LIGHTING/LAN/CCTV/ACS/FIRE topology cannot be represented only as cable routes or current power/control port kinds.

Target model:

```text
EngineeringGraph
├── Nodes / Components
├── Ports
├── LogicalEdges
│   ├── controls
│   ├── suppliedBy
│   ├── memberOf
│   └── communicatesWith
├── Circuits / Loops / Segments
├── MediaConnections
└── PhysicalRoutes
```

Representative media:

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

Examples:

```text
Switch --controls--> Luminaire
SocketGroup --memberOf--> Circuit --suppliedBy--> Board
LAN outlet --media--> PatchPanel --containedBy--> Rack
Fire detector --memberOf--> FireLoop --terminatesAt--> FirePanel
```

`ElectricalPortKind` may remain transitional but is not the final cross-discipline model.

## Decision 11 — Stable wall/boundary-edge identity is required

### Problem

Current `RoomSurfaceRef.wall(spaceId, wallIndex)`, wall profiles keyed by `int`, openings and routes can silently rebind to another physical wall if polygon vertex insertion/removal changes edge indices.

### Decision

Introduce a stable canonical `BoundaryEdgeId`/edge-lineage strategy before full wall authoring and Room Surface Navigator implementation.

Conceptually:

```text
RoomSurfaceRef.wall(
  SpaceId spaceId,
  BoundaryEdgeId edgeId,
)
```

A boundary edit must explicitly classify old/new edges as preserved, split, merged, created or removed.

Dependent objects are then remapped or conflicted explicitly:

```text
opening host
wall profile
component host
route endpoint/segment
active RoomSurfaceRef
```

If a selected wall is removed and cannot be unambiguously mapped, navigation falls back deterministically to Plan. It must never silently bind by the same numeric index.

## Decision 12 — Navigator location is a first-class application projection

Canonical navigation state distinguishes:

```text
ACTIVE CONTEXT
SiteId / BuildingId / LevelId

SELECTED ENTITY
ZoneId? / SpaceId? / other entity id
```

Presentation additionally tracks independently:

```text
keyboard focus
hover
expanded nodes
scroll offset
```

Navigator node identity wraps canonical IDs. It must not use `levelNumber`, labels, list indices or demo constants such as `building-a` as canonical location identity.

A ProjectNavigationState drives tree, breadcrumb and editor activation. Same-number levels in different buildings are unambiguous.

## Decision 13 — Multi-building persistence is a foundation requirement

The target persisted document stores full composed semantics for every building:

```text
ProjectDocument
├── metadata
├── site
├── buildings[] / building store
├── engineering graph
├── generation state
└── resume state
```

It must not store one full `building` plus shallow/duplicated copies of other buildings inside `site`.

`ProjectId` and `SiteId` are distinct typed identities. Project metadata can never infer `projectId` from `siteId`.

## Decision 14 — Repository and codec boundaries are independent of filesystem APIs

Target dependency direction:

```text
UI / Editor
    ↓
Application services/commands
    ↓
ProjectRepository
    ↓
Persistence implementation
    ├── legacy JSON adapter
    └── Drift/SQLite target
```

Separate responsibilities:

```text
domain/          ProjectAggregate + entities
application/     ProjectRepository + commands
serialization/   ProjectDocumentCodec
infrastructure/  JsonProjectRepository / DriftProjectRepository
```

Feature code must not depend on `dart:io`, `path_provider`, SQLite APIs or HTTP clients.

Drift normalizes major aggregates rather than making one giant JSON blob the editable database.

## Decision 15 — Reference underlays and canonical imported geometry are separate

PDF/image/CAD/BIM inputs have two different roles:

```text
ReferenceLayer / UnderlayAsset
- PDF
- raster image
- CAD/BIM reference view

Recognized/promoted canonical geometry
- Building
- Level
- Space
- Opening
- boundary edges
```

Loading an underlay does not automatically create canonical walls/spaces.

Promotion/import into canonical geometry is explicit, validated and provenance-aware.

This keeps the canonical model usable without forcing every reference asset into engineering semantics.

## Decision 16 — Project projections are indexed and incremental

Introduce `ProjectIndex` as the aggregate grows:

```text
BuildingId → BuildingAggregate
LevelId    → Level
SpaceId    → Space
EdgeId     → BoundaryEdge
ComponentId→ Component
RouteId    → Route
```

Navigator and editor projections consume `ProjectChangeSet` invalidation.

Do not rebuild/reproject the whole project for hover, wall selection or a single room edit.

Wizard preview operates on an independent candidate/draft graph, not a deep copy of the live project for every slider tick.

## Decision 17 — Canonical semantic fingerprint is a qualification primitive

Introduce a normalized `CanonicalProjectFingerprint`/equivalent test representation.

It includes semantics that must survive round trips:

```text
stable entity identities where required
hierarchy
geometry
SpaceType / SpaceUsage
openings/edge hosts
engineering graph
circuits/routes
provenance
```

It excludes irrelevant/transient differences:

```text
hover/focus
navigator scroll
panel visibility
serialization key order
local database row ids
non-semantic timestamps where not under test
```

Use it to prove:

```text
preview cancel        → fingerprint unchanged
failed command        → fingerprint unchanged
save/reopen           → semantic fingerprint equal
migration             → expected semantic fingerprint
cross-platform open   → equivalent project semantics
```

Byte-for-byte equality is not a platform invariant.

## Decision 18 — Vertical topology references stable IDs and physical nodes

Vertical cores reference `LevelId`, not level numbers.

Target shape:

```text
VerticalCore
└── nodes by LevelId
    ├── hostSpaceId?
    ├── footprint
    ├── route transition anchors
    └── supported media
```

Validation proves every referenced level/space belongs to the same building.

This provides physical cross-floor transition anchors for later auto-routing.

## Migration sequence

Avoid a Big Bang migration.

Recommended sequence:

```text
M0 current schema v4
M1 typed ID wrappers + EntityIdFactory in application/domain contracts
M2 schema v5: SpaceUsage + ID-backed navigation resume state
M3 schema v6: canonical multi-building ownership + LevelId references
M4 stable BoundaryEdgeId / wall-host migration
M5 schema v7: generation manifests + field-aware provenance/overrides
M6 generalized engineering connectivity adapters
M7 introduce Drift ProjectRepository
M8 import legacy JSON projects into Drift
M9 connect revision-aware sync behind ProjectRepository
```

Every migration gate proves:

```text
old supported project
→ migrate
→ validate
→ save
→ close
→ reopen
→ expected semantic fingerprint
```

No migration silently invents engineering meaning that cannot be safely derived.

## Implementation decomposition — authoritative roadmap

This `P*` roadmap is the umbrella implementation order. Any `S*`, `G*` or other sequence in subordinate documents is a work-package breakdown inside the matching `P*` phase, not an alternative roadmap.

```text
P0   architecture reconciliation + contract tests

P1A  typed IDs + EntityIdFactory
P1B  canonical ProjectAggregateRoot / entity stores
P1C  ProjectIndex + LocalProjectVersion

P2A  ProjectRepository interface
P2B  ProjectDocumentCodec
P2C  legacy JSON repository adapter
P2D  multi-building document shape + migration path

P3A  ProjectCommand
P3B  ProjectMutationSession
P3C  ProjectChangeSet
P3D  candidate graph validator
P3E  Undo/Redo

P4A  Create/Rename/Remove Building
P4B  Create/Rename/Duplicate/Remove Level
P4C  Create/Rename/Remove StructuralZone
P4D  Create/Update/Split/Merge/Remove Space
P4E  structural dependency checks/fallback navigation

P5A  ProjectNavigationState
P5B  indexed Project Navigator projection + breadcrumb
P5C  +Building / +Level / +Room authoring UX
P5D  opt-in compass
P5E  Room Surface Navigator shell/projection

P6   SpaceUsage + openings + adjacency + overlay classifications
P7   BoundaryEdgeId + wall-host migration + vertical topology + typical floors
P8   typed Wizard contracts + deterministic preview/diff
P9   apartment generator 1..10
P10  cottage/building/residential-complex generation
P11  generalized engineering graph/connectivity
P12  POWER/LIGHTING/LAN/CCTV/ACS/FIRE starter generation
P13  auto-placement
P14  route topology / auto-routing foundation
P15  provenance + selective regeneration
P16  Drift/SQLite production persistence
P17  native cross-platform qualification
```

### Hard ordering rules

- P4 UI does not bypass P3 mutation semantics.
- P5 navigation IDs do not use level numbers or demo constants.
- full Room Surface Navigator wall interaction waits for stable wall identity in P7; P5 may land the shell/projection contract against transitional adapters only.
- P8+ never directly mutates `EditorBuildingWorkspace`.
- engineering generation waits for `SpaceUsage` and generalized engineering graph contracts.

## Architecture readiness gates

Implementation may advance beyond foundation only when these gates are true:

```text
AG-01 one authoritative canonical state per persistent entity
AG-02 typed stable IDs independent from level number/list index/platform
AG-03 LevelId is used for persistent/application level references
AG-04 ProjectId and SiteId are distinct identities
AG-05 LocalProjectVersion guards stale local mutation
AG-06 structural commands are atomic/fail-closed
AG-07 one semantic action yields one ProjectChangeSet and Undo record
AG-08 ProjectRepository/ProjectDocumentCodec isolate filesystem persistence
AG-09 multi-building document shape preserves every building aggregate
AG-10 SpaceUsage is canonical and persisted
AG-11 structural zones are not abused for overlay classifications
AG-12 typical-floor instances have independent stable identities
AG-13 stable wall/boundary-edge identity is defined before durable wall references expand
AG-14 navigator/editor/breadcrumb share one ID-backed navigation state
AG-15 Wizard preview cannot mutate live project state
AG-16 provenance is field-aware and regeneration-safe
AG-17 engineering graph distinguishes logical topology from physical routing
AG-18 vertical topology uses LevelId and physical transition nodes
AG-19 large projections have indexed/incremental update paths
AG-20 canonical semantic fingerprint covers round-trip/preview failure invariants
AG-21 supported native platforms preserve the same engineering semantics
AG-22 no Web/browser runtime, persistence or business semantics are introduced
```

## Specification merge vs feature implementation DoD

The umbrella specification PR may merge when:

```text
- architecture documents are internally reconciled by this foundation contract;
- mandatory decisions/gates are explicit;
- implementation roadmap is unambiguous;
- qualification strategy is defined;
- no production feature completion is claimed.
```

Full feature completion is separate and requires the applicable P0-P17 gates and qualification suites.

## Non-negotiable conclusion

`feat/project-structure-authoring` is the umbrella architecture for ElecX Project Composition & Generation, but implementation must establish foundation ownership, identity, mutation and persistence boundaries before product UI or generators are allowed to deepen the current workspace model.

The intended long-term direction is:

```text
Canonical Project Aggregate / Entity Stores
        ↓
Typed structural/engineering commands
        ↓
LocalProjectVersion + candidate validation
        ↓
Atomic ProjectChangeSet + Undo
        ↓
Indexed Editor/Navigator projections
        ↓
ProjectRepository + ProjectDocumentCodec
        ↓
Drift/SQLite
        ↓
Revision-aware Sync Engine
```

Not:

```text
Widget/Wizard
→ mutate EditorBuildingWorkspace directly
→ rebuild duplicate graphs
→ identify levels by number
→ identify walls by unstable index
→ serialize platform-specific state
```
