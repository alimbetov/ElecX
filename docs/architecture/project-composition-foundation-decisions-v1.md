# Project Composition Foundation Decisions v1

## Status

Accepted design constraints for implementing `feat/project-structure-authoring` after architectural audit.

This document is subordinate to `docs/architecture/native-project-portability-and-sync.md` and complements:

- `docs/architecture/project-structure-authoring-v1.md`
- `docs/architecture/project-template-wizard-v1.md`
- `docs/architecture/project-composition-generation-v1.md`

If any requirement conflicts with the native portability architecture, the native portability architecture wins.

ElecX remains native-only: macOS, Windows, Linux, Android, iOS and iPadOS. Web/browser runtime is out of scope.

## Audit disposition

The specification direction is accepted, but implementation is conditionally ready. The branch must first establish the following foundation decisions before full Wizard, residential-complex generation, selective regeneration or engineering auto-generation is implemented.

## Decision 1 — One authoritative canonical project aggregate

### Problem

The current runtime carries a `ComposedBuilding` in `EditorBuildingWorkspace` while `ComposedProjectSite.site.buildings` contains another `Building` projection. Synchronization currently rebuilds and replaces the building copy manually.

This is not acceptable as the long-term ownership model for multiple buildings, generation, undo or synchronization.

### Decision

The target architecture has exactly one authoritative project aggregate.

Conceptually:

```text
EngineeringProjectAggregate
├── metadata
├── SiteAggregate
│   ├── outdoor zones
│   ├── service entries
│   └── building identities
├── BuildingAggregate by BuildingId
│   ├── levels
│   ├── vertical cores
│   └── typical-floor lineage
├── EngineeringGraph
└── GenerationState
```

Site/navigation projections may reference buildings by identity, but must not own an independently mutable second copy of the same building graph.

### Required invariant

For each persistent entity identity there is one authoritative canonical state inside the project aggregate.

UI/editor/navigator representations are projections only.

### Migration rule

Existing `ComposedBuilding` and `ComposedProjectSite` may remain transitional adapters while the aggregate is introduced, but new Wizard or multi-building logic must not deepen the duplicated-ownership model.

## Decision 2 — Stable typed external identities

### Problem

Current code often uses raw `String` identities and deterministic string concatenation such as level-prefixed cloned IDs. Demo data also contains fixed IDs.

This is insufficient as the permanent external identity strategy for multi-device sync, imports and regeneration.

### Decision

Application/domain contracts introduce typed identifiers:

```text
ProjectId
SiteId
BuildingId
LevelId
ZoneId
SpaceId
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

Persistent/external identities must be globally stable UUID-like values and must not depend on:

- list index;
- level number;
- platform;
- local database row id;
- UI tree path;
- regenerated display name.

`levelNumber`, apartment number and labels are attributes, not identities.

### ID allocation

IDs are allocated through an application/domain `EntityIdFactory` or equivalent injected identity service.

Preview-only draft IDs are scoped to the draft and must never leak into committed persistence.

Existing entity IDs survive rename, semantic reclassification, movement, rerouting and regeneration when the logical entity remains the same.

## Decision 3 — Structural commands use atomic mutation/change-set semantics

### Problem

Large structural operations cannot be implemented as ad-hoc widget mutations followed by several `notifyListeners()` calls.

### Decision

All canonical structural changes execute through explicit commands and one mutation boundary:

```text
request
→ validate request
→ build candidate state
→ validate candidate graph
→ compute change-set
→ commit atomically
→ publish one committed change notification
```

Failure before commit leaves the prior valid project state unchanged.

Conceptual contracts:

```dart
sealed class ProjectCommand {}

final class ProjectMutationResult {
  final ProjectAggregate project;
  final ProjectChangeSet changeSet;
  final UndoRecord undo;
}
```

Required command families include:

```text
Create/Rename/Remove Building
Create/Rename/Duplicate/Remove Level
Create/Rename/Remove Zone
Create/Update/Split/Merge/Remove Space
Create/Move/Resize/Remove Opening
Create/Extend/Remove VerticalCore
Create/Update/Remove ServiceEntry
GenerateTemplate
RegenerateDiscipline
```

Widgets never rebuild the project graph directly.

### Undo boundary

A semantically coherent action is one undo transaction:

- create one level → one Undo;
- generate one apartment → one Undo;
- create repeated floors 2..20 → one Undo;
- regenerate Lighting → one Undo.

## Decision 4 — Structural type and semantic room usage are separate

### Problem

`SpaceType` currently describes broad structural/editor categories and cannot drive meaningful engineering generation.

### Decision

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
SpaceType.room + SpaceUsage.bedroom
SpaceType.technicalRoom + SpaceUsage.electricalRoom
SpaceType.hall + SpaceUsage.parking
```

Engineering generation may depend on `SpaceUsage`. UI geometry tools may continue to operate on `SpaceType`.

### Migration

Existing persisted spaces receive deterministic backward-compatible usage defaults, usually `unknown`, except where existing semantics can be safely mapped without guessing.

## Decision 5 — Typical floors are lineage, not shared mutable objects

### Problem

Current repeated-floor support clones data, which avoids shared mutable pointers, but does not express definition/instance lineage or scoped updates.

### Decision

Introduce explicit typical-floor lineage:

```text
TypicalFloorDefinition
    ↓
FloorInstance
    ├── LevelId
    ├── definitionId
    └── override state
```

Every instantiated level and space is still an independent canonical entity with its own stable IDs.

No shared mutable room/zone objects are permitted between floors.

Required edit scopes:

```text
current floor only
all linked floors
selected linked floors
```

A floor may detach from its typical-floor definition without replacing unrelated identities.

### Propagation rule

Changes are propagated by semantic generation keys/change-set mapping, not by pointer aliasing or bulk ID regeneration.

## Decision 6 — Provenance is field-aware and regeneration-safe

### Problem

A single `userModified` boolean is insufficient. A user may override position while generator-owned metadata or routing recommendations remain safely regenerable.

### Decision

Generated/imported entities use field-aware provenance.

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
├── overriddenFields
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

`generationKey` is a stable semantic key used to match logical generated entities across preview/regeneration without changing committed entity IDs.

Example:

```text
building:A/level:typical/apartment:02/room:kitchen/discipline:lighting/role:main-light
```

### Regeneration policy

Regeneration computes a candidate and diff first.

At minimum classify:

```text
ADD
UPDATE
PRESERVE
REMOVE
CONFLICT
```

Manual entities and user-overridden fields are preserved by default. Conflicts are explicit. No silent destructive overwrite is allowed.

Regenerating one discipline must not mutate unrelated disciplines except through an explicit declared dependency.

## Decision 7 — Engineering connectivity is media-neutral

### Problem

Current route comments already describe AC/DC/Ethernet/PoE/fibre/fire/security, but current port compatibility is mainly `powerIn/out` and `controlIn/out`.

That model cannot be the final foundation for POWER, LIGHTING, LAN, CCTV, ACS and FIRE generation.

### Decision

Move toward a media-neutral engineering port model.

Conceptually:

```text
EngineeringPortDefinition
├── PortId
├── role
├── direction
├── supportedMedia
├── signalClass?
└── electricalClass?
```

Representative media include:

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
project-specific wired media
```

`ElectricalPortKind` may remain as a transitional legacy adapter but new multi-discipline architecture must not encode all future connectivity in the current enum.

### Graph requirement

Engineering generation creates logical topology, not only symbols:

```text
Switch → controls → Luminaire
SocketGroup → Circuit → ProtectionRole → Board
LAN outlet → Cable → PatchPanel → Rack
Fire detector → Loop → FirePanel
```

## Decision 8 — Repository/persistence boundary is independent of JSON and platform filesystem APIs

### Problem

The current `EditorProjectDocument` file combines versioned document serialization/restoration with file-system-oriented imports such as `dart:io` and `path_provider`.

### Decision

Target dependency direction:

```text
UI / Editor
    ↓
Application commands/services
    ↓
ProjectRepository
    ↓
Persistence implementation
    ├── transitional JSON/native adapter
    └── Drift/SQLite target
```

Separate responsibilities conceptually into:

```text
domain/
  ProjectAggregate

application/
  ProjectRepository

serialization/
  ProjectDocumentCodec

infrastructure/
  JsonProjectRepository
  DriftProjectRepository
```

Feature code must not depend on `dart:io`, `path_provider`, SQLite APIs or HTTP clients.

### Drift readiness

The target Drift schema should normalize major project aggregates rather than store the whole editable project only as one giant JSON blob.

Conceptual tables:

```text
projects
sites
buildings
levels
zones
spaces
space_usage
openings
vertical_cores
vertical_core_levels
service_entries
outdoor_zones
engineering_components
engineering_ports
engineering_connections
circuits
circuit_members
routes
route_segments
typical_floor_definitions
typical_floor_instances
generation_manifests
entity_provenance
entity_overrides
project_revisions
```

JSON may remain useful for legacy migration, export/import, debug fixtures and initial snapshot synchronization.

## Decision 9 — Project projections are indexed and incremental

### Problem

Future projects may contain 100+ floors, 1000+ rooms and many thousands of components/routes. Rebuilding the whole navigator/project graph for every small edit or hover will not scale.

### Decision

Introduce indexed lookup/projection support as the aggregate grows:

```text
ProjectIndex
├── BuildingId → BuildingAggregate
├── LevelId → Level
├── SpaceId → Space
├── ComponentId → Component
└── RouteId → Route
```

Navigator and other large projections consume `ProjectChangeSet` invalidation and should not recompute the full tree for transient hover state.

Wizard preview is generated into an independent draft/candidate graph rather than deep-copying the live project for every parameter change.

## Decision 10 — Vertical topology references stable level identity

### Problem

Current vertical cores primarily address levels by integer `levelNumber`. Level numbers are display/ordering attributes and can change independently from identity.

### Decision

Long-term vertical topology references `LevelId`.

A vertical core has stable identity and level-local nodes:

```text
VerticalCore
└── nodes by LevelId
    ├── hostSpaceId?
    ├── footprint
    └── supported route media
```

Validation must prove that every referenced level/space exists in the same building aggregate.

Level number remains useful for UI ordering but is not a foreign key.

## Migration sequence

Avoid a single Big Bang migration.

Recommended sequence:

```text
M0 current schema v4
M1 typed identity wrappers in application/domain contracts
M2 schema v5: SpaceUsage
M3 schema v6: canonical multi-building ownership/indices
M4 schema v7: generation manifests + provenance/overrides
M5 generalized engineering connectivity adapters
M6 introduce Drift ProjectRepository
M7 import existing JSON projects into Drift
M8 connect revision-aware sync behind ProjectRepository
```

Every migration gate must prove:

```text
old supported project
→ migrate
→ validate
→ save
→ close
→ reopen
→ semantic equality
```

No migration may silently infer engineering meaning that cannot be safely derived from old data.

## Implementation decomposition

The umbrella specification is intentionally larger than one implementation PR.

Recommended implementation branches/stages:

```text
P0  foundation ADRs and contract tests
P1  canonical ProjectAggregate + typed IDs
P2  ProjectRepository boundary cleanup
P3  structural command/change-set/undo engine
P4  Building/Level/Zone/Room authoring
P5  navigator authoring UX + opt-in compass
P6  semantic spaces + openings + adjacency
P7  typical floors + vertical cores
P8  Wizard contracts + deterministic preview/diff
P9  apartment generator 1..10
P10 cottage/building/residential-complex generation
P11 generalized engineering connectivity
P12 POWER/LIGHTING/LAN/CCTV/ACS/FIRE starter generation
P13 auto-placement
P14 route topology / auto-routing foundation
P15 provenance + selective regeneration
P16 Drift/SQLite production persistence
P17 native cross-platform qualification
```

P8+ must not be implemented by directly mutating the current `EditorBuildingWorkspace` graph ad hoc.

## Architecture readiness gates

Implementation may advance beyond foundation only when the following are true:

```text
AG-01 exactly one authoritative canonical state per persistent entity
AG-02 external IDs are stable and independent from level number/list index/platform
AG-03 structural commands are atomic/fail-closed
AG-04 Wizard preview cannot mutate live project state
AG-05 generated/manual/imported provenance is explicit
AG-06 selective regeneration preserves manual overrides by default
AG-07 engineering ports can evolve beyond power/control-only semantics
AG-08 feature code depends on ProjectRepository, not filesystem/SQLite/backend
AG-09 typical-floor instances have independent stable identities
AG-10 vertical topology can reference stable level identities
AG-11 large-tree projections have an incremental/indexed path
AG-12 all persisted semantics are identical on supported native platforms
AG-13 no Web/browser runtime or business semantics are introduced
```

## Non-negotiable conclusion

`feat/project-structure-authoring` is accepted as an umbrella architecture for Project Composition & Generation only if implementation proceeds through these foundation decisions first.

The intended long-term direction is:

```text
Canonical Project Aggregate
        ↓
Typed structural/engineering commands
        ↓
Atomic ProjectChangeSet
        ↓
Editor/Navigator projections
        ↓
ProjectRepository
        ↓
Drift/SQLite
        ↓
Revision-aware Sync Engine
```

Not:

```text
Widget/Wizard
→ directly mutate EditorBuildingWorkspace
→ rebuild duplicate graphs
→ serialize platform-specific state
```
