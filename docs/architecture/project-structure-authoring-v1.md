# Project structure authoring v1

## Status

Implementation specification for `feat/project-structure-authoring`.

This specification is subordinate to and must comply with:

`docs/architecture/native-project-portability-and-sync.md`

If this document and the native portability architecture ever disagree, the native portability architecture wins until an explicit architecture decision changes it.

## Platform scope

ElecX is a native application.

Supported UI/runtime targets:

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

Web/browser UI and browser persistence are explicitly out of scope for this feature and for the current product architecture.

No requirement, widget contract, persistence adapter, test gate or fallback in this feature may depend on browser APIs or on a Web implementation existing later.

Desktop-first delivery is allowed. Desktop-only domain semantics are not.

## Architectural contract

Project structure authoring must preserve the following non-negotiable invariants:

- one project identity across every supported native platform;
- one canonical project/domain model;
- stable project/entity identifiers independent from platform and local database row ids;
- one logical Drift/SQLite persistence schema and migration chain for native clients;
- local-first project mutation and autosave;
- UI code does not own filesystem, SQLite or backend concerns;
- structural edits remain compatible with future revision-aware backend sync;
- no silent last-write-wins behavior;
- no platform-specific project formats;
- desktop/mobile differences are interaction adaptations only;
- Web/browser runtime is not a target.

The required dependency direction remains:

```text
Native UI / Editor
        ↓
Application / Domain commands
        ↓
ProjectRepository / project persistence boundary
        ↓
Local native persistence
        ↓
Sync boundary
        ↓
Backend
```

A navigator button must never become a second persistence path.

## Product objective

A user must be able to create the complete physical structure of an engineering project without hidden commands:

- choose an initial project template;
- create a building;
- create a building level;
- create a basement;
- create a ground/plinth level;
- create a technical level;
- create a roof level;
- create and classify rooms/spaces;
- navigate the full hierarchy;
- always see the current Site / Building / Level / Zone / Room context;
- save, close and reopen the same structure;
- continue editing the same logical project on another supported native platform later.

The left navigator is therefore both a hierarchy viewer, a live current-location indicator and the primary entry point for project-structure authoring.

## Canonical hierarchy

The navigator projects the canonical physical model. It does not own a separate UI hierarchy.

```text
Project
└── Site
    ├── Building A
    │   ├── Roof
    │   ├── Technical levels
    │   ├── Residential levels
    │   │   ├── Zones / apartments
    │   │   └── Rooms / spaces
    │   ├── Ground / plinth
    │   └── Basements
    │       └── Rooms / spaces
    └── Building B
```

Each visible node must reference a stable domain identity.

At minimum:

```text
projectId
siteId
buildingId
levelId
zoneId
spaceId
```

The same identities must survive save/reopen, `.elecx` export/import when introduced, and future backend synchronization.

## UI projection rule

Navigator tree nodes are projections of canonical project state.

The UI MUST NOT:

- create synthetic platform-specific copies of levels or rooms;
- use macOS/Windows/Linux-only identifiers as project identities;
- persist navigator expansion state as engineering data;
- rebuild the entire building graph directly inside widget callbacks;
- serialize a special desktop project format;
- create a browser-specific representation.

Selection, expansion, focus, panel visibility and compass visibility are UI/session state unless explicitly promoted by a future architecture decision.

## New project flow

`New Project` must request:

1. project name;
2. initial project template.

Initial v1 templates:

```text
Blank project
Demo apartment
```

Future templates such as detached house, apartment building or commercial building are outside v1.

A template is a deterministic factory for canonical domain entities. It is not a schema, persistence mode or platform-specific project type.

### Blank project

Creates a valid local-first project identity and a minimal editable site/building context.

It must be possible to add all subsequent buildings, levels and rooms using the same authoring commands used by every other project.

### Demo apartment

The previously available demonstration drawing is restored as an explicit project template based on the existing `EditorBuildingWorkspace.demo()` data.

The template must expose the existing example structure including residential spaces, apartments/common corridor and basement technical spaces.

After creation, a Demo apartment project becomes an ordinary project. Save, restore, migration and future sync must not distinguish it from a project authored from Blank.

For current macOS qualification this is the preferred visual test fixture because it immediately exposes the plan/editor behavior that existed earlier.

## Project Structure Editor

The left navigator must expose explicit primary actions and must always display the user's current structural location.

Desktop baseline:

```text
PROJECT

Site
├── Building A
│   ├── B1
│   ├── Floor 1
│   ├── Floor 2      ← CURRENT
│   │   └── Bedroom  ← SELECTED
│   └── Roof
└── Building B

[ + Building ]
[ + Level ] [ + Room ]
[ Wizard ]
```

Primary authoring actions require discoverable labels on desktop. A bare plus icon is not sufficient.

On mobile/tablet these commands may move into an adaptive sheet/menu, but they must call the same application/domain commands and create semantically equivalent canonical state.

Detailed current-location behavior is defined in:

`docs/architecture/project-navigator-current-location-v1.md`

## Current location and selection

The navigator must distinguish:

```text
ACTIVE CONTEXT
Site / Building / Level currently opened by the editor.

SELECTED ENTITY
Zone/Room/other entity currently selected inside that context.
```

A selected Room does not replace the fact that its parent Level remains the active Level.

The current path is based on stable identities, not level numbers, list indices or labels.

Conceptually:

```text
SiteId
BuildingId?
LevelId?
ZoneId?
SpaceId?
```

When current location changes, the navigator must:

- update the current/selected marker;
- expand all required ancestors;
- reveal/scroll the current node into view for explicit navigation actions;
- preserve unrelated expansion state where practical;
- update breadcrumb/path from the same state source;
- never scroll/reselect merely because of hover.

Current location must remain unambiguous for equal display numbers in different Buildings.

For example:

```text
Building A / Floor 2
Building B / Floor 2
```

therefore `levelNumber = 2` is insufficient as canonical navigation identity.

## Current path / breadcrumb

Desktop and tablet should expose a structural breadcrumb where useful:

```text
Site / Building A / Floor 2 / Apartment 201 / Bedroom
```

or:

```text
Site / Building A / Floor 2
```

The breadcrumb is a projection of the same current-location state as the tree and must never maintain an independent navigation model.

## Authoring action targeting

Primary actions operate on explicit current context:

```text
+ Building → active Site
+ Level    → active Building
+ Room     → active Level
Wizard     → explicit project/site/building/level insertion context where applicable
```

If the required parent context is not available or ambiguous, the action is disabled or requests explicit selection. It must not use stale widget state or silently guess a target.

After successful creation:

```text
Create Building → new Building becomes active and visible
Create Level    → new Level becomes current and visible
Create Room     → Level remains active; new Room becomes selected and visible
```

Cancel/failure preserves the previous current location.

## Level creation

`+ Level` opens a typed creation flow.

Supported `BuildingLevelKind`:

```text
residential
ground
basement
technical
roof
```

Required request data:

```text
kind
levelNumber
displayName
elevationMm
floorToFloorHeightMm
```

Defaults may be inferred from adjacent levels for user convenience, but the committed values must be deterministic and explicit.

### Validation

Before mutation:

- building exists;
- requested level number is unique within the target Building;
- level number is inside the domain-supported range;
- height is positive;
- elevation is valid for the request;
- generated `levelId` is stable and unique;
- no existing project identity is replaced;
- cancellation leaves canonical project state unchanged.

### Commit semantics

One successful level creation is one atomic logical mutation:

```text
CreateLevelCommand
    ↓
validate request
    ↓
construct candidate canonical project state
    ↓
validate candidate graph
    ↓
compute ProjectChangeSet
    ↓
commit once
    ↓
activate created LevelId
    ↓
project editor/navigator projections update
    ↓
normal local autosave/recovery path
```

There must not be a second independently mutable Building copy in the navigator/site model. Transitional adapters may exist, but authoritative mutation happens once through the canonical command boundary.

Widgets must not manually perform individual graph mutations themselves.

## Basement

A basement is not a separate persistence model.

It is a canonical building level with:

```text
kind = basement
levelNumber < 0
explicit elevationMm
```

Suggested display numbering:

```text
B1 → -1
B2 → -2
```

`levelNumber` is a display/order attribute, not the persistent Level identity.

Its identity and serialization are identical in semantics on macOS, Windows, Linux, Android, iOS and iPadOS.

## Ground / plinth

Ground/plinth uses the canonical ground-level kind and an explicit level number/elevation. UI terminology may be localized, but persistence semantics must remain stable.

## Technical level

A technical level is an ordinary canonical level with `kind = technical`. It may host technical rooms, shafts, risers and later equipment without a special storage format.

## Roof

Roof is a canonical level with `kind = roof`.

It may initially contain zero rooms. Future roof engineering entities such as solar equipment, lightning protection, trays and rooftop equipment must attach to this same project hierarchy rather than create a separate document type.

## Room creation

`+ Room` is available only with an active building level that supports room authoring.

Required flow:

```text
+ Room
  ↓
resolve explicit active BuildingId + LevelId
  ↓
show Plan
  ↓
activate room rectangle authoring
  ↓
select first point
  ↓
preview geometry
  ↓
select second point
  ↓
validate polygon
  ↓
commit EngineeringSpace
  ↓
select/reveal created SpaceId
  ↓
edit room properties
```

The existing room rectangle interaction should be reused rather than duplicated.

Room property minimum:

```text
name
SpaceType
SpaceUsage when introduced
optional zone assignment
```

Canonical building-space types remain:

```text
room
corridor
hall
technicalRoom
stair
shaft
```

`outdoorArea` remains for outdoor/site contexts and must not be offered as an ordinary building-room type.

After successful commit the room appears immediately in the navigator because the navigator is projected from canonical project state.

## Room mutation semantics

Room creation/rename/type change must operate through explicit application/domain operations, conceptually:

```dart
beginRoomCreation(...)
commitRoom(...)
renameRoom(...)
changeRoomType(...)
changeRoomUsage(...)
assignRoomToZone(...)
```

Requirements:

- validate before committed mutation;
- no partial room on cancel/failure;
- stable `spaceId` after rename/type/usage change;
- one committed operation produces one project-change notification boundary;
- no widget-specific persistence write;
- normal project save/recovery captures the result.

## Level mutation API

Structural authoring should expose an explicit application/domain API, conceptually:

```dart
createLevel(CreateLevelRequest request)
renameLevel(LevelId id, String name)
activateLevel(BuildingId buildingId, LevelId levelId)
removeLevel(LevelId id)
```

Removal may be deferred if dependency semantics are not ready, but creation and activation must not be implemented as arbitrary widget-side list manipulation.

Future dependency rules for risers, circuits, routes and equipment must be able to reject destructive operations fail-closed.

## Local-first behavior

Creating buildings, levels and rooms must not require network connectivity.

The command path is local:

```text
user action
  ↓
application/domain command
  ↓
canonical project state
  ↓
local save/autosave/recovery
  ↓
future sync observes committed project revision/state
```

No editor gesture or structural command may synchronously wait for backend success.

The future Sync Engine may upload the resulting revision later, but it must not become a prerequisite for local authoring.

## Persistence boundary

`EditorProjectDocument.capture()` / `restore()` remain the transitional serialization boundary during this stage.

This feature must preserve compatibility with the planned migration behind repository interfaces to:

```text
ProjectRepository
      ↓
Drift
      ↓
SQLite
```

Therefore structural authoring code must not depend on JSON-file-specific behavior even though the current native implementation may still use file-backed persistence underneath the abstraction.

New structure state that must round-trip includes:

- stable building identity;
- stable level identity;
- level number/order metadata;
- level kind;
- level display name;
- elevation;
- floor-to-floor height;
- stable room/space identity;
- geometry;
- room type/usage;
- zone membership;
- intentional resume context using stable BuildingId/LevelId/ZoneId/SpaceId where supported.

The target multi-building persisted project representation must be able to preserve full composed semantics for every Building, not only one active `ComposedBuilding` plus shallow copies in `ProjectSite`.

## Revision/sync compatibility

The production Sync Engine is outside this branch, but every mutation must be compatible with the accepted revision model.

The feature must not introduce operations that require replacing project identity or regenerating unrelated stable IDs.

Future revision semantics are conceptually:

```text
local base revision N
        ↓
structural edits
        ↓
local committed project state
        ↓
future push(baseRevision = N)
        ↓
accepted N+1 OR explicit conflict
```

No authoring UX may assume silent remote overwrite is acceptable.

## Portable project compatibility

The future `.elecx` package must carry the same canonical hierarchy. This feature must not create data that only the local JSON/SQLite implementation can understand outside the canonical project model.

## Compass UX

The compass represents project orientation information, but the overlay itself is optional UI.

Current always-visible behavior is rejected because it can visually collide with engineering content.

Required behavior:

- compass hidden by default;
- visible only after explicit user request;
- explicit toggle is discoverable;
- visible compass may open Project North editing;
- hiding/showing does not mutate `ProjectNorth`;
- visibility belongs to editor-shell/session UI state;
- compass toggle alone does not dirty the engineering project;
- Focus mode may suppress the overlay;
- overlay must not cover primary authoring controls;
- behavior must adapt to native desktop/mobile UI without changing engineering semantics.

Suggested native desktop control:

```text
View / App bar
[ Compass ]
```

Suggested native mobile/tablet control:

```text
View sheet/menu
[ ] Compass
```

There is intentionally no Web-specific compass behavior.

## State ownership

Canonical project state:

```text
project/site/building identity
levels
level kinds
room identities and geometry
zones
project north
engineering entities
```

Intentional resume/session context where supported:

```text
active BuildingId
active LevelId
selected ZoneId
selected SpaceId
```

Transient shell/UI state:

```text
navigator expanded nodes
navigator panel visible
inspector visible
context bar visible
focus mode
compass visible
hover state
keyboard-focus node
navigator scroll offset
pointer/stylus preview
```

Platform-specific input state must not leak into persisted engineering semantics.

## Native interaction parity

All supported native platforms must invoke the same semantic commands.

Allowed UI/input adaptation:

```text
macOS / Windows / Linux
mouse
keyboard
trackpad
contextual desktop panels

Android / iOS / iPadOS
touch
stylus / Apple Pencil where available
adaptive sheets/panels
platform lifecycle integration
```

The same room/level request must produce the same canonical domain result regardless of input modality.

## Web exclusion gate

This branch MUST NOT add:

- browser project store implementations;
- `dart:html` / browser-only storage dependencies;
- Web persistence fallbacks;
- Web-specific project schemas;
- Web CI acceptance requirements;
- conditional business logic that changes project semantics for browsers.

A future decision to support Web requires a separate architecture decision and is not implied by Flutter's ability to target browsers.

## Failure behavior

Structural mutations are fail-closed.

Reject without partial canonical mutation:

- duplicate level number within a Building;
- invalid level kind/number combination;
- invalid height/elevation request;
- invalid/degenerate room geometry;
- room creation without a valid active BuildingId + LevelId;
- references to unknown building/level/zone/space identities;
- duplicate generated external identity;
- destructive operations that violate future protected dependencies.

User errors must be actionable. Internal consistency errors must not silently auto-correct project meaning.

## Transaction boundary

For each structural command:

```text
request
  ↓
validate complete request
  ↓
construct candidate state
  ↓
validate candidate graph
  ↓
compute ProjectChangeSet
  ↓
commit state atomically
  ↓
notify once
```

Failure before commit leaves the previous valid project state intact.

This model is required so the same operations can later be mapped cleanly into Drift transactions and revision/change-set semantics.

## Test strategy

Testing is layered.

Domain/application tests:

- create valid typed level;
- reject duplicate level number within one Building;
- allow same level display number in different Buildings;
- create basement/ground/technical/roof;
- preserve stable IDs during non-identity edits;
- create room and classify type/usage;
- reject invalid geometry;
- ensure failed mutation leaves state and current location unchanged.

Persistence tests:

- capture/restore preserves hierarchy;
- multi-building save/reopen preserves every Building's full composed semantics;
- projectId/buildingId/levelId/spaceId remain unchanged;
- intended resume context uses stable IDs;
- no transient compass/hover/scroll visibility is serialized as engineering meaning;
- structural data is platform-neutral.

UI/widget tests:

- template selector is discoverable;
- `+ Building` visible;
- `+ Level` visible;
- `+ Room` visible;
- `Wizard` visible;
- current Building/Level is visibly indicated;
- selected Room/Zone is distinguishable from active Level;
- selecting deep nodes auto-expands required ancestors;
- explicit navigation reveals current node in scroll view;
- same-number levels in different Buildings are unambiguous;
- action targeting follows current context;
- dialogs validate inputs;
- compass hidden initially;
- user can explicitly show/hide compass.

Native qualification tests are then executed per supported platform.

## macOS P1 Golden Journey

macOS is the reference implementation/qualification platform for this stage.

```text
A01 launch native macOS application
A02 create Blank project
A03 current Site/Building/Level is visible in PROJECT tree
A04 create Demo apartment and see built-in plan
A05 create Building B
A06 create residential level
A07 create ground/plinth level
A08 create basement
A09 create technical level
A10 create roof
A11 navigate between created levels and verify current marker follows
A12 switch between Building A/Floor 2 and Building B/Floor 2 without ambiguity
A13 create room using plan rectangle tool
A14 created room appears immediately, is selected and ancestors are revealed
A15 rename room without changing spaceId
A16 change room type/usage
A17 compass is hidden by default
A18 explicitly show compass
A19 edit ProjectNorth while compass visible
A20 explicitly hide compass
A21 save project locally
A22 close ElecX completely
A23 relaunch ElecX
A24 reopen same projectId
A25 hierarchy and stable ids are preserved
A26 valid current Building/Level/Room resume context is restored when supported
A27 room geometry/type/usage/zone membership are preserved
A28 ProjectNorth is preserved
A29 no MissingPluginException
A30 no Web/browser fallback is involved
A31 no platform-specific project corruption
```

## Cross-platform qualification

After macOS passes, repeat equivalent engineering semantics on:

```text
Windows
Linux
Android
iPadOS / iOS
```

A platform may use different controls, but acceptance fails if it creates project data another supported native platform cannot open and edit.

## Implementation sequence

The authoritative umbrella roadmap is `P0..P17` from `project-composition-foundation-decisions-v1.md`.

The former `S*` sequence is treated only as subordinate work inside the relevant P stages:

```text
P4/P5  project structure authoring and navigator UX
P5     current-location tree/breadcrumb and explicit +Building/+Level/+Room/Wizard actions
P6     semantic spaces/openings/adjacency
P8+    Wizard generation according to the umbrella roadmap
```

Production backend sync remains outside this branch. Compatibility with the already accepted sync/revision boundary is mandatory throughout.

## Specification definition of done

The architecture/specification umbrella is ready to leave draft only when:

- it complies with `native-project-portability-and-sync.md`;
- one authoritative canonical ownership model is defined;
- multi-building persistence semantics are defined;
- stable ID and command/change-set rules are internally consistent;
- current-location navigator semantics are explicit and ID-based;
- typed Wizard, provenance and qualification contracts are internally consistent;
- no Web/browser runtime path is introduced;
- one authoritative `P0..P17` roadmap is used.

## Feature implementation definition of done

The implemented Project Structure Authoring feature is complete only when:

- Blank and Demo apartment flows work;
- `+ Building`, `+ Level`, `+ Room`, `Wizard` are discoverable;
- current Site/Building/Level/Zone/Room context is always understandable;
- current path auto-expands/reveals after explicit navigation;
- level creation supports all v1 kinds;
- room creation is explicit and discoverable;
- structural mutations use explicit command/change-set boundaries;
- failed mutations are atomic/fail-closed;
- project structure save/reopen is deterministic;
- stable project/entity ids survive persistence;
- compass is opt-in and non-obstructive;
- macOS native Golden Journey passes;
- implementation does not block the same semantics from being used on Windows, Linux, Android, iOS and iPadOS.