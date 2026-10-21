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
- create a building level;
- create a basement;
- create a ground/plinth level;
- create a technical level;
- create a roof level;
- create and classify rooms/spaces;
- navigate the full hierarchy;
- save, close and reopen the same structure;
- continue editing the same logical project on another supported native platform later.

The left navigator is therefore both a hierarchy viewer and the primary entry point for project-structure authoring.

## Canonical hierarchy

The navigator projects the canonical physical model. It does not own a separate UI hierarchy.

```text
Project
└── Site
    └── Building
        ├── Roof
        ├── Technical levels
        ├── Residential levels
        │   ├── Zones / apartments
        │   └── Rooms / spaces
        ├── Ground / plinth
        └── Basements
            └── Rooms / spaces
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

It must be possible to add all subsequent levels and rooms using the same authoring commands used by every other project.

### Demo apartment

The previously available demonstration drawing is restored as an explicit project template based on the existing `EditorBuildingWorkspace.demo()` data.

The template must expose the existing example structure including residential spaces, apartments/common corridor and basement technical spaces.

After creation, a Demo apartment project becomes an ordinary project. Save, restore, migration and future sync must not distinguish it from a project authored from Blank.

For current macOS qualification this is the preferred visual test fixture because it immediately exposes the plan/editor behavior that existed earlier.

## Project Structure Editor

The left navigator must expose explicit primary actions.

Desktop baseline:

```text
NAVIGATOR

Site
└── Building
    ├── Roof
    ├── Floor 2
    │   ├── Room 201
    │   └── Room 202
    ├── Floor 1
    │   ├── Living room
    │   └── Bedroom
    └── B1
        └── Electrical room

[ + Level ]   [ + Room ]
```

Primary authoring actions require discoverable labels on desktop. A bare plus icon is not sufficient.

On mobile/tablet these commands may move into an adaptive sheet/menu, but they must call the same application/domain commands and create byte/semantically equivalent canonical state.

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
- requested level number is unique;
- level number is inside the domain-supported range;
- height is positive;
- elevation is valid for the request;
- generated `levelId` is stable and unique;
- no existing project identity is replaced;
- cancellation leaves canonical project state unchanged.

### Commit semantics

One successful level creation is one atomic logical mutation:

```text
validate request
    ↓
create canonical level
    ↓
update ComposedBuilding levels
    ↓
update Building.levels consistently
    ↓
update ProjectSite building projection
    ↓
activate new level
    ↓
mark project Modified
    ↓
normal autosave/recovery path
```

Widgets must not manually perform these individual graph mutations themselves.

## Basement

A basement is not a separate persistence model.

It is a canonical `ComposedBuildingLevel` with:

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
activate level
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
edit room properties
```

The existing room rectangle interaction should be reused rather than duplicated.

Room property minimum:

```text
name
SpaceType
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

After successful commit the room appears immediately in the navigator because the navigator is projected from canonical workspace state.

## Room mutation semantics

Room creation/rename/type change must operate through explicit application/domain operations, conceptually:

```dart
beginRoomCreation(...)
commitRoom(...)
renameRoom(...)
changeRoomType(...)
assignRoomToZone(...)
```

Requirements:

- validate before committed mutation;
- no partial room on cancel/failure;
- stable `spaceId` after rename/type change;
- one committed operation produces one project-change notification boundary;
- no widget-specific persistence write;
- normal project save/recovery captures the result.

## Level mutation API

Structural authoring should expose an explicit application/workspace API, conceptually:

```dart
createLevel(CreateLevelRequest request)
renameLevel(LevelId id, String name)
activateLevel(LevelId id)
removeLevel(LevelId id)
```

Removal may be deferred if dependency semantics are not ready, but creation and activation must not be implemented as arbitrary widget-side list manipulation.

Future dependency rules for risers, circuits, routes and equipment must be able to reject destructive operations fail-closed.

## Local-first behavior

Creating levels and rooms must not require network connectivity.

The command path is local:

```text
user action
  ↓
application/domain command
  ↓
canonical in-memory project state
  ↓
local save/autosave/recovery
  ↓
future sync observes committed project revision/state
```

No editor gesture or structural command may synchronously wait for backend success.

The future Sync Engine may upload the resulting revision later, but it must not become a prerequisite for local authoring.

## Persistence boundary

`EditorProjectDocument.capture()` / `restore()` remain the current canonical serialization boundary during this stage.

This feature must preserve compatibility with the planned migration behind repository interfaces to:

```text
ProjectRepository
      ↓
Drift
      ↓
SQLite
```

Therefore structural authoring code must not depend on JSON-file-specific behavior even though the current native implementation may still use file-backed persistence underneath the abstraction.

New structure state that must round-trip:

- stable level identity;
- level number;
- level kind;
- level display name;
- elevation;
- floor-to-floor height;
- stable room/space identity;
- geometry;
- room type;
- zone membership;
- active project navigation state where intentionally persisted.

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

Transient shell/UI state:

```text
navigator expanded nodes
navigator panel visible
inspector visible
context bar visible
focus mode
compass visible
hover state
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

- duplicate level number;
- invalid level kind/number combination;
- invalid height/elevation request;
- invalid/degenerate room geometry;
- room creation without a valid active level;
- references to unknown level/zone/space identities;
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
- reject duplicate level number;
- create basement/ground/technical/roof;
- preserve stable IDs during non-identity edits;
- create room and classify type;
- reject invalid geometry;
- ensure failed mutation leaves state unchanged.

Persistence tests:

- capture/restore preserves hierarchy;
- save/reopen preserves hierarchy;
- projectId/levelId/spaceId remain unchanged;
- no transient compass/UI visibility is serialized as engineering meaning;
- structural data is platform-neutral.

UI/widget tests:

- template selector is discoverable;
- `+ Level` visible;
- `+ Room` visible;
- dialogs validate inputs;
- compass hidden initially;
- user can explicitly show/hide compass.

Native qualification tests are then executed per supported platform.

## macOS P1 Golden Journey

macOS is the reference implementation/qualification platform for this stage.

```text
A01 launch native macOS application
A02 create Blank project
A03 create Demo apartment and see built-in plan
A04 create residential level
A05 create ground/plinth level
A06 create basement
A07 create technical level
A08 create roof
A09 navigate between created levels
A10 create room using plan rectangle tool
A11 room appears immediately in hierarchy
A12 rename room without changing spaceId
A13 change room type
A14 compass is hidden by default
A15 explicitly show compass
A16 edit ProjectNorth while compass visible
A17 explicitly hide compass
A18 save project locally
A19 close ElecX completely
A20 relaunch ElecX
A21 reopen same projectId
A22 hierarchy and stable ids are preserved
A23 room geometry/type/zone membership are preserved
A24 ProjectNorth is preserved
A25 no MissingPluginException
A26 no Web/browser fallback is involved
A27 no platform-specific project corruption
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

```text
S1  architecture/specification alignment
S2  acceptance/domain tests for structural commands
S3  New Project template contract and selector
S4  explicit level mutation API
S5  + Level native desktop UX
S6  level dialog validation and activation
S7  explicit + Room action
S8  reuse room rectangle transaction
S9  room properties/type/zone commit
S10 compass opt-in shell state and UI
S11 capture/restore and save/reopen regression tests
S12 macOS Golden Journey qualification
S13 Windows qualification
S14 Linux qualification
S15 Android adaptation/qualification
S16 iPadOS/iOS adaptation/qualification
```

Production backend sync remains outside this branch. Compatibility with the already accepted sync/revision boundary is mandatory throughout.

## Definition of done

`feat/project-structure-authoring` is ready for merge only when:

- the feature complies with `native-project-portability-and-sync.md`;
- no Web/browser runtime path is introduced;
- Blank and Demo apartment flows work;
- level creation supports all v1 kinds;
- room creation is explicit and discoverable;
- structural mutations use explicit command/workspace boundaries;
- failed mutations are atomic/fail-closed;
- project structure save/reopen is deterministic;
- stable project/entity ids survive persistence;
- compass is opt-in and non-obstructive;
- macOS native Golden Journey passes;
- implementation does not block the same semantics from being used on Windows, Linux, Android, iOS and iPadOS.