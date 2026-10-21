# Project structure authoring v1

## Status

Implementation specification for `feat/project-structure-authoring`.

This document extends the accepted native project portability model. It defines how a user creates and edits the physical structure of an ElecX project before detailed electrical authoring begins.

## Product objective

A user must be able to start either from a blank project or from a useful demonstration template, then create the full building hierarchy directly from the left navigator without hidden commands.

The structure editor is shared by macOS, Windows, Linux, Android, iOS and iPadOS. Desktop and mobile may present the controls differently, but they MUST create the same domain objects and persistence state.

## Project hierarchy

The navigator represents the canonical physical hierarchy, not only the current canvas:

```text
Project
└── Site
    └── Building
        ├── Roof
        ├── Technical levels
        ├── Residential levels
        │   ├── Zones / apartments
        │   └── Rooms / spaces
        ├── Ground / plinth level
        └── Basements
            └── Rooms / spaces
```

Every visible node maps to a stable domain identity. Selection in the navigator and active editor context must stay synchronized.

## New project templates

The New Project flow must ask for both project name and initial structure.

Initial templates:

- Blank project — empty editable building structure.
- Demo apartment — existing ElecX residential demonstration model with apartments, common corridor and basement technical spaces.

Future templates may include detached house, apartment building and commercial building, but they are outside v1.

Template selection MUST NOT create a second project schema. A template only creates ordinary canonical domain entities.

For current macOS validation, Demo apartment should be the recommended/default test template so the previously available built-in drawing remains directly accessible.

## Navigator authoring controls

The left navigator is the primary Project Structure Editor.

The following explicit actions are required:

```text
+ Level
+ Room
```

The controls must use text labels on desktop. A bare `+` icon without a discoverable label is insufficient for primary authoring actions.

### Create level

`+ Level` opens a typed creation dialog.

Supported `BuildingLevelKind` values:

- Residential floor
- Ground / plinth floor
- Basement
- Technical floor
- Roof

Required fields:

- level kind;
- level number;
- display name;
- elevation, mm;
- floor-to-floor height, mm.

Defaults may be derived from adjacent levels, but the final values must be explicit and deterministic.

Validation:

- level number must be unique in the building;
- level number remains within the existing domain range;
- floor-to-floor height must be positive;
- generated ids must be stable and unique;
- cancel must not mutate project state.

After creation:

1. the level is inserted into `ComposedBuilding`;
2. `Building.levels` and the composed semantic level list remain consistent;
3. the level becomes active;
4. navigator expands/selects it;
5. the editor switches to Plan view;
6. project state becomes Modified and participates in autosave/recovery.

### Create basement

Basement is not a separate persistence model. It is a normal `ComposedBuildingLevel` with `kind = basement`, a negative level number and explicit elevation.

Suggested numbering:

```text
B1 => levelNumber = -1
B2 => levelNumber = -2
```

### Create roof

Roof is a normal level with `kind = roof`. It may initially contain no rooms. Future roof engineering objects such as equipment zones, trays, lightning protection and solar systems will attach to this level without introducing a special project format.

### Create room

`+ Room` is available only when a building level is active.

Invocation sequence:

```text
+ Room
  ↓
activate selected level
  ↓
show Plan
  ↓
activate room rectangle tool
  ↓
first corner
  ↓
second corner
  ↓
commit EngineeringSpace
```

After geometry commit, a room properties step must allow at least:

- name;
- `SpaceType`;
- optional zone assignment when zones exist.

Existing `SpaceType` values remain canonical:

- room;
- corridor;
- hall;
- technicalRoom;
- stair;
- shaft;
- outdoorArea where applicable outside building-room creation.

The created room must immediately appear under the active level in the navigator.

## Demo apartment restoration

The existing `EditorBuildingWorkspace.demo()` model is retained as a real project template instead of an implicit editor startup state.

The Demo apartment path must expose the current sample structure, including the existing residential rooms/apartments/common corridor and basement technical spaces.

Opening a demo project must use the same `EditorProjectDocument`, save, restore and future sync contracts as a blank project.

## Compass behavior

The project compass is context information, not a permanent canvas obstruction.

Current behavior renders `ProjectCompassOverlay` automatically for plan contexts. This is changed in v1.

Required behavior:

- compass is hidden by default;
- user explicitly requests it through a visible editor action such as `Compass` / `Project orientation`;
- the action toggles compass visibility;
- when visible, clicking the compass may still open orientation editing;
- hiding/showing the compass does not change `ProjectNorth`;
- compass visibility is editor-shell UI state, not engineering project semantics;
- focus mode may suppress the compass even when its normal visibility preference is enabled;
- the overlay must not cover primary authoring controls or navigator content.

Suggested desktop action:

```text
App bar / View controls
[Compass]
```

Suggested mobile/tablet action:

```text
View menu
☐ Compass
```

## State ownership

Engineering data belongs to the canonical project/workspace model.

UI presentation state belongs to `EditorShellState` or an equivalent shell-level controller.

Examples:

```text
Project data
- building levels
- rooms
- level kind
- elevation
- project north

Shell state
- navigator visible
- inspector visible
- context bar visible
- focus mode
- compass visible
```

Compass visibility must therefore not force a project save merely because the user toggled it.

## Persistence requirements

Newly created levels and rooms must survive the full project lifecycle:

```text
create
→ edit
→ save
→ close application
→ reopen
→ restore identical hierarchy
```

`EditorProjectDocument.capture()` and `restore()` remain the canonical persistence boundary.

No platform-specific structure schema is allowed.

## UX requirements

Desktop navigator:

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

Creation actions must remain visible without requiring right-click or undocumented keyboard shortcuts.

Context menus may provide duplicate advanced actions later, but must not be the only path.

## Command boundaries

UI widgets must not directly rebuild the entire building graph ad hoc.

Introduce explicit application/domain commands or workspace methods for structural mutations, conceptually:

```dart
createLevel(CreateLevelRequest request)
removeLevel(LevelId id)
renameLevel(LevelId id, String name)
activateLevel(LevelId id)

beginRoomCreation()
commitRoom(...)
renameRoom(...)
changeRoomType(...)
```

Every command must validate before mutation and notify the workspace exactly once after a successful committed state transition.

## Failure behavior

Structure mutations are fail-closed.

Examples that must be rejected without partial mutation:

- duplicate level number;
- invalid elevation/height input;
- invalid room polygon;
- room creation without an active building level;
- references to unknown zone/level ids;
- attempting to remove a level while future protected dependencies prevent it.

User-facing validation errors must be explicit and actionable.

## macOS P1 acceptance

macOS is not considered complete until all scenarios below pass on a real desktop runtime:

```text
A01 launch application
A02 create Blank project
A03 create Demo apartment project and see the built-in plan
A04 create residential floor
A05 create basement
A06 create technical floor
A07 create roof
A08 switch between all created levels
A09 create room using canvas rectangle tool
A10 created room appears in navigator
A11 rename/select room and preserve type
A12 compass is hidden by default
A13 user can show compass explicitly
A14 user can hide compass again
A15 edit ProjectNorth while compass is visible
A16 save project
A17 close ElecX completely
A18 reopen project
A19 hierarchy, active level, rooms and ProjectNorth restore correctly
A20 no MissingPluginException or platform-specific structure corruption
```

## Cross-platform invariant

The same acceptance semantics are later repeated on Windows, Linux, Android and iPadOS/iOS.

The implementation is rejected if one platform creates hierarchy data another supported platform cannot open or edit.

## Implementation order

```text
S1 specification and acceptance tests
S2 explicit project template selection
S3 level mutation API
S4 navigator + Level action/dialog
S5 explicit Room action wired to existing room tool
S6 room post-create properties/type assignment
S7 opt-in compass visibility
S8 persistence/reopen regression tests
S9 macOS Golden Journey qualification
S10 port same acceptance to Windows/Linux/mobile
```

Backend sync remains outside this branch except for preserving stable identities and canonical persistence compatibility.