# Project Composition & Generation v1

## Status

Umbrella product/domain specification for `feat/project-structure-authoring`.

This document is subordinate to:

- `docs/architecture/native-project-portability-and-sync.md`
- `docs/architecture/project-composition-foundation-decisions-v1.md`

The foundation decisions are authoritative for ownership, identity, mutation, persistence and implementation ordering.

## Platform scope

ElecX remains native-only:

```text
macOS
Windows
Linux
Android
iOS
iPadOS
```

Web/browser runtime, persistence and business semantics are out of scope.

## Product intent

Project Structure Authoring evolves into the native **Project Composition & Generation** subsystem for:

- one or many buildings on a site;
- levels, basements, ground/plinth, technical levels and roof;
- structural zones and semantic rooms;
- openings, adjacency, walls/facades and stable room surfaces;
- typical floors and vertical cores;
- outdoor/service infrastructure;
- architectural Wizard generation;
- engineering starter generation;
- preview/diff, provenance and selective regeneration;
- local-first persistence and future revision-aware sync.

Manual, generated and imported/promoted project entities share one canonical model.

## Canonical composition hierarchy

```text
ProjectAggregate
└── Site
    ├── Outdoor infrastructure
    ├── Building A
    │   ├── Roof
    │   ├── Technical levels
    │   ├── Residential levels
    │   │   ├── Structural zones / apartments
    │   │   └── Spaces / rooms
    │   ├── Ground / plinth
    │   └── Basements
    ├── Building B
    ├── Parking/service buildings
    └── Shared engineering infrastructure
```

The tree/navigator is a projection, not another project graph.

## Multi-building support

Every building has a stable `BuildingId` and full independent composed semantics.

Level numbers/codes may repeat between buildings; `LevelId` remains unique and authoritative.

Shared site systems may reference multiple BuildingIds without replacing project identity.

## Structural lifecycle

Application/domain commands cover at least:

```text
Building
- create / rename / duplicate / remove

Level
- create / rename / duplicate / reorder-display / remove
- instantiate/detach typical floor

StructuralZone
- create / rename / assign/unassign spaces / remove

Space
- create / rename / reclassify / change geometry
- split / merge / duplicate / move / remove

Opening
- create / move / resize / remove

VerticalCore
- create / extend / update / remove

ServiceEntry / OutdoorZone
- create / update / remove
```

Every command uses the atomic mutation path from the foundation decisions.

## Space semantics

`SpaceType` describes structural/editor shape semantics.

`SpaceUsage` describes purpose and drives engineering automation.

Example:

```text
SpaceType.room + SpaceUsage.bedroom
SpaceType.room + SpaceUsage.kitchen
SpaceType.technicalRoom + SpaceUsage.electricalRoom
```

No engineering generator may infer kitchen/bathroom/bedroom semantics from localized display names.

## Structural zones vs engineering overlays

Structural ownership/grouping remains separate from cross-cutting classifications.

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
```

Overlay classification examples:

```text
fire compartment
access-control/security zone
electrical distribution zone
telecom/network zone
```

One room may belong to one exclusive structural zone and multiple overlay classifications.

## Level semantics

Do not overload one integer with identity, ordering, display and physical elevation.

Target semantics:

```text
LevelId            stable identity
LevelOrdinal       ordering
LevelCode          B1 / 01 / RF / custom display code
BuildingLevelKind  basement / ground / residential / technical / roof
ElevationMm        physical coordinate
```

`levelNumber` may remain a transitional compatibility property only.

## Typical floors

Typical floors use explicit lineage:

```text
TypicalFloorDefinition
       ↓
FloorInstance
├── LevelId
├── definitionId
├── generationKey
└── overrides
```

Instances own independent IDs and data.

Supported edit scopes:

```text
current floor
all linked floors
selected linked floors
```

No shared mutable aliasing is allowed.

## Room geometry and stable boundary topology

Rectangle authoring remains a fast tool, but canonical geometry supports polygon/L-shaped/angled rooms.

Durable wall-hosted entities require stable `BoundaryEdgeId`/edge lineage.

A polygon edit explicitly maps edge changes:

```text
preserved
split
merged
created
removed
```

Dependent openings, wall profiles, components, routes and active surface references are remapped or conflicted explicitly.

A raw `wallIndex` is transitional only and cannot be a permanent external identity.

## Openings and adjacency

Openings are first-class topology:

```text
OpeningId
host BoundaryEdgeId
kind
offset/dimensions
sill/height
connected spaces where applicable
```

Room connectivity must support later reasoning for switch placement, routing, access and fire/evacuation analysis.

## Wall/facade semantics

Allow classification of:

```text
external wall
internal partition
party wall
shaft boundary
facade orientation
balcony/loggia boundary
```

Project North is canonical project data. Compass visibility is shell state.

## Vertical topology

Vertical cores use stable `VerticalCoreId` and nodes keyed by `LevelId`.

```text
VerticalCore
└── nodes by LevelId
    ├── hostSpaceId?
    ├── footprint
    ├── route transition anchors
    └── supported media
```

Kinds include stair, elevator, electrical riser, low-current riser, cable/service shaft and fire-system riser.

This model is the physical basis for cross-floor routing.

## Outdoor/site infrastructure

Canonical site composition must allow:

```text
yard
parking
driveway
gate
external lighting
generator area
transformer/substation area
PV/solar equipment
EV charging
outdoor CCTV/intercom
service-entry paths
```

## Engineering service entries

Service entries provide source/topology anchors for:

```text
electrical service
internet/fiber
generator
PV/inverter
fire backbone
intercom
CCTV backbone
external lighting feeder
```

They reference stable Site/Building/Level/Space identities.

## Reference underlays and import

Reference assets and canonical geometry are different layers.

```text
ReferenceLayer / UnderlayAsset
├── PDF
├── raster image
└── CAD/BIM reference

explicit recognition/promotion
        ↓
Canonical geometry
```

Loading a PDF/image never silently creates walls or spaces.

DXF/DWG/IFC ingestion may provide reference data and/or explicit promoted canonical entities with import provenance.

## Wizard architecture

Wizard generation has two layers:

```text
A. Architectural generation
   site/buildings/levels/zones/spaces/openings/cores

B. Engineering starter generation
   devices/logical topology/circuits/loops/distribution/routes
```

The Wizard uses typed parameter contracts and returns `GeneratedProjectCandidate`, not a directly mutated workspace.

Preview does not mutate the live project.

## Engineering profiles

Product presets:

```text
Basic
Standard
Premium
Custom
```

These are generation parameterizations, not safety/compliance classes.

Target disciplines:

```text
POWER
LIGHTING
LAN
CCTV
ACS
FIRE
```

Additional Wi-Fi/TV/intercom/site systems may be layered on the same graph.

## Engineering graph

Generation creates semantic topology separately from physical routing.

```text
EngineeringGraph
├── Nodes / Components
├── Ports
├── LogicalEdges
├── Circuits / Loops
├── MediaConnections
└── PhysicalRoutes
```

Examples:

```text
Switch --controls--> Luminaire
SocketGroup --memberOf--> Circuit --suppliedBy--> Board
LAN outlet --media--> PatchPanel --> Rack
Fire detector --memberOf--> FireLoop --> FirePanel
```

Do not encode every discipline as a cable route or force future media into the current power/control enum.

## Auto-placement

Placement consumes canonical semantics:

```text
SpaceUsage
room geometry
stable boundary edges
openings
wall/facade classification
wet zones
service entries
vertical cores
```

Generated devices must have valid hosts and logical relationships.

Placement warnings are explicit; unsafe or undefined assumptions are not silently invented.

## Auto-routing foundation

Routing follows:

```text
logical engineering topology
→ source/target anchors
→ host-surface graph
→ vertical/site transitions
→ route candidates
→ constraints/normative validation
→ committed PhysicalRoutes
```

Cross-floor routing uses VerticalCore transition nodes.

## Provenance and selective regeneration

Use field-aware provenance:

```text
originType
generationId
templateId/templateVersion
generatorVersion
discipline
generationKey
overriddenProperties
lockedFromRegeneration
```

Do not use a single `userModified` boolean as the final model.

Selective regeneration computes a diff first:

```text
ADD
UPDATE
PRESERVE
REMOVE
CONFLICT
```

Manual entities and overridden properties are protected by default.

## Preview/diff and atomic commit

Wizard and regeneration flows:

```text
request
→ independent candidate
→ validate
→ diff
→ preview
→ confirm
→ verify LocalProjectVersion
→ atomic ProjectChangeSet
→ one UndoRecord
```

Cancel/failure preserves the canonical semantic fingerprint.

## Local-first / persistence

Structural editing and generation are offline-first.

```text
Native UI
→ Application/domain commands
→ ProjectAggregate
→ ProjectRepository
→ local persistence
→ future Sync Engine
```

Feature code does not depend on JSON files, `dart:io`, `path_provider`, SQLite APIs or backend APIs.

The persisted target supports full multi-building project composition.

## Canonical semantic fingerprint

Qualification compares semantic state through a normalized fingerprint rather than byte-for-byte serialization.

It includes stable identities, hierarchy, geometry, usage, hosts, engineering topology, routes and provenance while excluding transient shell state and local row IDs.

## Failure policy

Fail closed on:

- invalid hierarchy;
- duplicate persistent identity;
- stale LocalProjectVersion;
- invalid LevelId/BuildingId reference;
- invalid structural zone membership;
- ambiguous/removed boundary-edge host;
- invalid opening/vertical-core/service-entry host;
- invalid engineering topology;
- unresolved regeneration conflict;
- unsafe destructive dependency;
- platform-specific semantic divergence.

## Qualification expansion

Required examples:

```text
C01 multiple full Building aggregates on one Site
C02 same display floor number in different Buildings remains unambiguous
C03 renumber Level preserves LevelId/dependencies
C04 typical-floor instances have independent stable IDs
C05 SpaceUsage round-trips
C06 polygon/L-shaped rooms support stable wall-host topology
C07 removing/splitting wall never silently rebinds opening/route/surface
C08 vertical cores use LevelId transition nodes
C09 architectural Wizard preview is side-effect free
C10 engineering starter creates logical graph, not icons only
C11 manual overrides survive selective regeneration
C12 one generation/regeneration commit = one Undo
C13 multi-building save/reopen preserves semantic fingerprint
C14 same project semantics open on all supported native platforms
C15 no Web/browser path exists
```

## Implementation order

The authoritative implementation roadmap is the `P0..P17` sequence in `project-composition-foundation-decisions-v1.md`.

This document defines product/domain scope, not an alternative schedule.

## Non-negotiable conclusion

Project Composition & Generation is built on one canonical ownership model, stable typed identity, atomic commands, indexed projections and repository-separated persistence.

The feature must not deepen current transitional patterns such as single-building workspace ownership, level-number foreign keys, wall-index durable identity or widget-side graph mutation.
