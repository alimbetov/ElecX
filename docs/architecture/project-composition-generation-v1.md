# Project Composition & Generation v1

## Status

Architecture/specification extension for `feat/project-structure-authoring`.

This document deepens the structural authoring and wizard contracts before implementation. It is subordinate to:

- `docs/architecture/native-project-portability-and-sync.md`
- `docs/architecture/project-structure-authoring-v1.md`
- `docs/architecture/project-template-wizard-v1.md`

If requirements conflict, `native-project-portability-and-sync.md` has priority until an explicit architecture decision changes it.

## Platform scope

ElecX remains native-only.

Supported runtime/UI targets:

```text
Desktop
├── macOS
├── Windows
└── Linux

Mobile
├── Android
├── iOS
└── iPadOS
```

Web/browser runtime, browser persistence, Web-specific project schemas and Web-specific business semantics are out of scope.

## Product intent

`feat/project-structure-authoring` is not only a floor/room CRUD feature. It is the foundation for a native Project Composition & Generation subsystem capable of creating and editing:

- sites;
- one or many buildings;
- apartment blocks and residential complexes;
- levels and repeated/typical floors;
- semantic zones and rooms;
- openings and adjacency;
- vertical cores;
- outdoor infrastructure;
- engineering service entries;
- generated engineering starter systems;
- deterministic templates with preview, provenance and selective regeneration.

All generated and manually authored output becomes ordinary canonical ElecX project data.

## Canonical composition hierarchy

The target physical hierarchy is:

```text
Project
└── Site
    ├── Outdoor zones / site infrastructure
    ├── Building A
    │   ├── Roof
    │   ├── Technical levels
    │   ├── Residential levels
    │   │   ├── Zones / apartments
    │   │   └── Spaces / rooms
    │   ├── Ground / plinth
    │   └── Basements
    ├── Building B
    ├── Parking / service building
    └── Shared engineering infrastructure
```

The navigator is a projection of this canonical graph, never a separate persistence model.

## Multi-building first-class support

The structure model and wizard MUST support more than one building on a site.

Use cases include:

```text
Residential complex
├── Tower A
├── Tower B
├── Parking block
└── Utility block

Detached house site
├── House
├── Garage
└── Utility building
```

Requirements:

- every building has a stable external identity;
- active-building selection is explicit;
- level numbers are unique within a building, not globally across the site;
- building creation/removal/rename uses application/domain commands;
- future shared site networks may connect multiple buildings without changing project identity;
- persistence and sync remain platform-neutral.

## Structural lifecycle commands

Authoring must support more than creation.

Target command families:

```text
Building
- create
- rename
- duplicate
- remove (when dependency-safe)

Level
- create
- rename
- duplicate
- reorder/display-order
- clone from typical floor
- detach from typical-floor template
- remove (when dependency-safe)

Zone
- create
- rename
- assign/unassign spaces
- duplicate where valid
- remove

Room / Space
- create
- rename
- change semantic use
- change geometry
- split
- merge
- duplicate
- move between compatible zones
- remove
```

Every structural mutation is fail-closed and atomic:

```text
request
→ validate complete request
→ construct candidate graph
→ validate candidate graph
→ commit once
→ notify once
```

A failed command leaves the previous valid canonical graph unchanged.

## Typical floors and template instances

Repeated storeys must be a first-class authoring concept.

A building may define one or more typical-floor templates and instantiate them across selected levels.

Conceptual model:

```text
TypicalFloorTemplate T1
├── geometry pattern
├── zone pattern
├── semantic room pattern
└── optional engineering starter pattern

Instances
├── Floor 2
├── Floor 3
├── Floor 4
└── Floor 5
```

An instance is still an independent canonical level with stable per-level/per-space identities.

No shared mutable object aliasing is allowed.

Editing policy must support:

```text
Apply change to:
○ current floor only
○ all linked floors
○ selected linked floors
```

A user must be able to detach one level from a typical-floor relationship without regenerating unrelated identities.

## Semantic space model

`SpaceType` alone is not sufficient for future engineering automation.

The project must distinguish geometric/structural type from semantic room use.

Conceptual separation:

```text
SpaceType
- room
- corridor
- hall
- technicalRoom
- stair
- shaft

SpaceUsage / RoomUsage
- livingRoom
- bedroom
- kitchen
- kitchenLiving
- bathroom
- toilet
- corridor
- entranceHall
- wardrobe
- storage
- laundry
- office
- balcony
- terrace
- garage
- electricalRoom
- serverRoom
- utilityRoom
- plantRoom
- stairLobby
- elevatorLobby
- commercial
- other
```

Engineering automation may depend on `SpaceUsage`, while geometry/navigation can continue using the more general structural `SpaceType`.

Examples:

```text
Kitchen
→ dedicated appliance circuits
→ worktop sockets
→ optional hood / dishwasher / oven loads

Bathroom
→ wet-zone constraints
→ dedicated loads where needed

Bedroom
→ bedside outlets
→ lighting controls near entry/bed

Corridor
→ pass-through switching candidates

ElectricalRoom
→ distribution equipment candidates
```

Room usage must be canonical persisted data with stable semantics across all native platforms.

## Zones beyond apartments

The zone taxonomy must be extensible beyond the current minimal set.

Required design allowance:

```text
apartment
common
technical
parking
storage
utility
commercial
office
lobby
stairwell
elevatorHall
service
residentialShared
outdoorService
```

A zone groups canonical spaces; it does not replace their geometry.

## Non-rectangular geometry

Rectangle authoring remains the fastest baseline, but the architecture must not lock the product to rectangular rooms.

Planned authoring support:

```text
rectangle room
polygon room
L-shaped room
angled walls
split room
merge rooms
shared-boundary editing
segmented/curved boundaries later
```

Generated and imported geometry uses the same deterministic integer-mm coordinate system.

No generator may depend on platform-specific floating point behavior to produce canonical geometry.

## Openings and room connectivity

Doors/windows/openings are first-class architectural topology, not only decoration.

The model must preserve at least:

```text
openingId
host wall/surface
opening type
offset
width
height
sill height
connected spaces where applicable
external/internal classification where derivable
```

Room adjacency/connectivity must be derivable or explicitly represented so later engines can reason about:

- cable routing;
- switch placement;
- corridor traversal;
- fire/evacuation semantics;
- wall/facade constraints;
- access between spaces.

## Wall and facade semantics

The composition layer must allow future classification of:

```text
external wall
internal partition
party wall
shaft boundary
facade orientation
balcony/loggia boundary
```

These semantics matter for daylight, outdoor transitions, routing and equipment placement.

Project North remains canonical project data; compass visibility remains transient shell state.

## Vertical topology

Vertical cores are first-class multi-level topology.

Required kinds include existing/future support for:

```text
stair
elevator
electrical riser
low-current riser
service shaft
cable riser
fire-system riser
```

A vertical core:

- has a stable identity;
- declares served levels;
- may map to level-local spaces/surfaces;
- can later host route transitions;
- must survive save/reopen and sync;
- cannot be silently destroyed if dependent routes/equipment exist.

## Outdoor and site infrastructure

The authoring/wizard architecture must support canonical outdoor entities and zones for scenarios such as:

```text
yard
parking
driveway
gate
external lighting
generator area
transformer/substation area
solar equipment
EV chargers
outdoor CCTV
intercom/gate control
service-entry paths
```

This remains one project model and one site graph.

## Engineering service entries

Templates must be able to define entry/origin points for engineering systems without hard-coding vendor equipment.

Examples:

```text
Electrical service entry
Internet/fiber entry
Generator connection
Solar inverter / PV connection
Fire-system backbone entry
Intercom entry
CCTV backbone entry
External lighting feeder
```

These entries provide deterministic anchors for later topology generation and routing.

## Distribution strategy placeholders

The composition/wizard subsystem must be compatible with generated distribution nodes such as:

```text
Main Distribution Board
Floor Distribution Board
Apartment DB
Low-current cabinet
Network rack
Fire alarm panel
```

The wizard may initially generate abstract engineering roles rather than catalog/vendor products.

Catalog resolution occurs through equipment-selection layers later.

## Architectural dimensions and reference data

The structure model should explicitly allow authoring/generation of:

```text
wall thickness
room/clear height
floor-to-floor height
finished-floor elevation
slab thickness where relevant
door/window dimensions
reference axes
construction lines
alignment guides
room-local grids
center lines
```

Engineering calculations should not have to infer critical dimensions from screen pixels.

## Import compatibility boundary

Even when import implementation is deferred, the canonical structure model must remain compatible with future ingestion of:

```text
PDF underlay
image underlay
DXF/DWG-derived geometry
IFC/BIM-derived geometry
```

Imported data must be normalized into the same canonical model rather than create a permanently separate editor mode/schema.

## Wizard architecture: two generation layers

Wizard generation is split conceptually into:

```text
A. Architectural generation
   site/buildings/levels/zones/rooms/openings/cores

B. Engineering starter generation
   lighting/power/low-current/distribution/topology/routes
```

The user may run architecture only or architecture + selected engineering profiles.

## Engineering profiles

Initial engineering profile concept:

```text
Basic
Standard
Premium
Custom
```

Profiles are parameter sets, not separate project types.

A custom profile can select disciplines independently.

Target discipline families:

```text
Power
Lighting
LAN
Wi-Fi
TV
Intercom
CCTV
ACS
Fire alarm
External/site systems where applicable
```

Not every family must ship in the first implementation, but contracts must allow them without changing project schema.

## Engineering generation pipeline

Generation must produce logical engineering topology, not only symbols on a plan.

Example power chain:

```text
Socket group
  ↓
Circuit
  ↓
Protection device role
  ↓
Distribution board
```

Example lighting chain:

```text
Switch
  ↓ controls
Luminaire group
  ↓ supplied by
Lighting circuit
  ↓
Distribution board
```

Example LAN chain:

```text
Data outlet
  ↓ cable
Patch panel / network cabinet
```

The canonical engineering graph remains editable after generation.

## Engineering placement rules

Auto-placement should use semantic room data, openings, walls and dimensions.

Examples:

- switches near valid room entrances;
- outlets distributed along usable walls;
- kitchen dedicated outlets tied to appliance assumptions;
- luminaire candidates based on room geometry/use;
- low-current outlets based on room usage;
- equipment avoids doors/windows/invalid host areas;
- generated placements use the same canonical surface/coordinate system as manual authoring.

Generation must surface warnings rather than silently invent unsafe geometry.

## Auto-routing

Auto-routing is a later stage of the same generation pipeline.

The architecture must allow:

```text
generated devices
   ↓
generated connectivity
   ↓
route candidates
   ↓
constraint/normative validation
   ↓
committed canonical routes
```

Routing must use existing route/surface models and must not invent template-only route formats.

## Provenance

Generated entities require provenance metadata sufficient for diagnostics and safe regeneration.

Conceptual fields:

```text
creationOrigin = manual | wizard | import
templateId
templateVersion
generatorVersion
generationId
discipline
createdAt
userModified
```

Provenance does not replace stable entity identity.

Manual edits preserve the same entity ID and mark the entity as user-modified where regeneration semantics require it.

## Selective regeneration

Regeneration must never blindly replace the whole project.

Target actions:

```text
Regenerate architecture subset
Regenerate lighting
Regenerate power
Regenerate low-current
Regenerate selected floor/building
```

Before commit, the system computes a diff.

At minimum classify:

```text
ADD
UPDATE
PRESERVE
REMOVE candidate
CONFLICT
```

User-modified entities are preserved or explicitly conflicted by default; they must not be silently overwritten.

## Preview and diff

Wizard preview must include structural and engineering summary.

Example:

```text
12 levels
48 apartments
216 spaces
4 vertical cores
48 apartment DB roles
312 luminaires
680 power outlets
96 data outlets
```

Regeneration preview should show:

```text
Will add:      + 24
Will update:   ~ 7
Will preserve: = 31 manual edits
Conflicts:     ! 2
```

Preview itself is transient and must not mutate canonical project state.

## Undo/redo transaction semantics

Large structural/generation actions must behave as coherent transactions.

Examples:

```text
Generate 3-room apartment
→ one Undo

Create typical floors 2..20
→ one Undo

Regenerate Lighting
→ one Undo
```

Undo must restore the previous canonical graph and stable identities where appropriate.

The operation boundary must be compatible with future persisted command/change-set history.

## Template and generator versioning

Template metadata must support reproducibility:

```text
templateId
templateVersion
generatorVersion
schemaVersion
```

A project generated under an older template remains valid even if the template catalog changes.

Opening an existing project must never require regenerating from the current template definition.

## Normative profile input

Wizard requests should be able to carry a normative/engineering profile reference without embedding normative rules in the structure layer.

Conceptual options:

```text
KZ
IEC
EU
Custom
```

The selected profile influences generation/validation but does not create another project schema.

Normative engines may reject or warn on generated proposals before commit.

## Equipment catalog compatibility

Engineering generation should initially create abstract roles/capabilities when exact vendor equipment is not selected.

Conceptual flow:

```text
abstract engineering role
        ↓
requirements/capabilities
        ↓
Equipment Catalog resolver
        ↓
manufacturer/product selection
```

Wizard contracts must not hard-code one vendor catalog.

## Cost/quality presets

Future generation may expose optimization modes:

```text
Economy
Balanced
Premium
```

They may influence equipment density, redundancy, automation level and catalog selection, but they remain parameterizations of the same canonical model.

Cost optimization must never bypass normative or safety validation.

## Local-first rule

All structural and wizard generation works offline.

Required direction:

```text
Native UI
  ↓
Application/domain commands
  ↓
Canonical project model
  ↓
ProjectRepository
  ↓
Local native persistence
  ↓
Future revision-aware Sync Engine
```

No structural edit, generator preview or engineering placement operation may require a synchronous backend round-trip.

## Stable identity rule

Externally visible project/entity identities are stable and platform-independent.

Generation or regeneration MUST NOT change unrelated IDs.

Rename, room-use change, equipment reassignment or route adjustment must preserve identity unless the user explicitly creates a new entity.

## Cross-platform invariant

The same committed project must open and remain editable on:

```text
macOS
Windows
Linux
Android
iOS
iPadOS
```

Platform-specific UI adaptation is allowed; project meaning is not.

No Web/browser fallback participates in acceptance.

## Failure policy

Fail closed on:

- invalid hierarchy;
- duplicate level/building identities;
- invalid typical-floor references;
- invalid room polygon;
- broken zone membership;
- broken opening host;
- invalid vertical-core level references;
- invalid engineering entry host;
- invalid generated connectivity;
- unresolved required generation conflict;
- unsafe destructive mutation with protected dependencies;
- platform-specific serialization divergence.

No partial graph mutation is permitted after validation failure.

## Acceptance expansion

In addition to existing structure/wizard acceptance, qualification must prove:

```text
C01 multiple buildings can exist on one site
C02 duplicate/rename structural commands preserve stable identity rules
C03 typical-floor instances are independent canonical entities
C04 current-floor vs linked-floor edit scope is explicit
C05 semantic room usage survives save/reopen
C06 non-rectangular room geometry is representable without schema fork
C07 doors/openings support room connectivity reasoning
C08 vertical cores span selected levels with stable identity
C09 outdoor/service-entry entities round-trip through persistence
C10 architectural dimensions/reference data remain deterministic
C11 wizard architecture-only generation works offline
C12 engineering generation creates logical connectivity, not only symbols
C13 generated entities carry provenance
C14 manual edits are protected from blind regeneration
C15 regeneration preview reports add/update/preserve/conflict
C16 regeneration can be undone as one logical action
C17 template/generator versions survive persistence
C18 project remains valid when original template catalog entry is unavailable
C19 normative profile selection does not fork project schema
C20 equipment catalog resolution is optional and vendor-neutral
C21 save/reopen preserves generated architecture + engineering semantics
C22 same project opens on every supported native platform
C23 no Web/browser code path is required
```

## Recommended implementation phases

```text
P0 architecture/contracts/tests
P1 stable semantic room model
P2 multi-building + structural lifecycle commands
P3 typical-floor model and instance semantics
P4 openings/connectivity + vertical cores hardening
P5 outdoor/service-entry composition
P6 architectural Wizard generation
P7 provenance + preview/diff transaction model
P8 engineering profile contracts
P9 lighting/power starter generation
P10 low-current starter generation
P11 selective regeneration + manual-edit protection
P12 undo/redo integration for large generated operations
P13 persistence/migration qualification
P14 macOS Golden Journey
P15 Windows/Linux qualification
P16 Android/iPadOS/iOS qualification
```

## Non-negotiable conclusion

Project Structure Authoring evolves into a Project Composition & Generation subsystem, but it remains strictly inside the accepted ElecX architecture:

- one canonical project model;
- one stable identity system;
- one native persistence/migration chain;
- local-first execution;
- revision-aware future sync;
- no silent overwrite;
- no platform-specific domain semantics;
- no Web/browser runtime.
