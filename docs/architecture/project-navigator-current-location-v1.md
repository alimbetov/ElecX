# Project Navigator Current Location v1

## Status

Required UX/interaction contract for `feat/project-structure-authoring`.

This specification complements:

- `docs/architecture/native-project-portability-and-sync.md`
- `docs/architecture/project-structure-authoring-v1.md`
- `docs/architecture/project-composition-foundation-decisions-v1.md`
- `docs/architecture/project-variant-qualification-v1.md`

ElecX remains strictly native-only: macOS, Windows, Linux, Android, iOS and iPadOS. Web/browser runtime is out of scope.

## Objective

The project navigator must always make the user's current structural location obvious.

The user must be able to answer immediately:

- which Site is active;
- which Building is active;
- which Level is active;
- which Zone/Apartment is active where applicable;
- which Room/Space is selected where applicable.

The tree is a projection of canonical project state. Current-location highlighting is UI/session state derived from canonical selection/activation; it is not a second project model.

## Desktop baseline

```text
PROJECT

Site
├── Building A
│   ├── B1
│   ├── Floor 1
│   ├── Floor 2      ← CURRENT
│   │   ├── Apartment 201
│   │   │   ├── Living room
│   │   │   └── Bedroom   ← SELECTED
│   │   └── Common corridor
│   └── Roof
└── Building B

[ + Building ]
[ + Level ] [ + Room ]
[ Wizard ]
```

The exact visual treatment may differ by native platform, but the semantic states are the same.

## Distinguish active context from selected entity

The navigator must distinguish at least two concepts:

```text
ACTIVE CONTEXT
The structural container currently opened by the editor.
Example: Building A / Floor 2.

SELECTED ENTITY
The entity currently selected inside that context.
Example: Bedroom 2.
```

Do not conflate them into one boolean `selected` state.

Conceptual presentation state:

```dart
final class ProjectNavigatorLocation {
  final SiteId siteId;
  final BuildingId? buildingId;
  final LevelId? levelId;
  final ZoneId? zoneId;
  final SpaceId? spaceId;
}
```

A concrete API may differ, but persistent identities must be used. `levelNumber`, tree indices and display labels are not location identities.

## Current path / breadcrumb

In addition to tree highlighting, desktop and tablet should expose the current structural path when useful:

```text
Site / Building A / Floor 2 / Apartment 201 / Bedroom
```

For a level-only context:

```text
Site / Building A / Floor 2
```

For outdoor/site context:

```text
Site / Courtyard
```

The breadcrumb is derived from the same canonical location as the tree. It must never maintain an independent navigation state.

## Automatic ancestor expansion

When the active location changes, all ancestors required to reveal the current node must be expanded automatically.

Example:

```text
select Bedroom
→ expand Site
→ expand Building A
→ expand Floor 2
→ expand Apartment 201
→ reveal Bedroom
```

Rules:

- current path must not remain hidden inside a collapsed ancestor;
- automatic reveal may expand required ancestors;
- unrelated branches should preserve the user's expansion state where practical;
- expansion state remains transient UI state and is not engineering project data.

## Scroll current location into view

When navigation changes because of an explicit action such as:

- selecting a level from canvas/navigation controls;
- opening a project and restoring its active context;
- moving to next/previous level;
- selecting a room from another editor surface;
- creating a new level/room and activating it;

then the navigator should ensure that the active/selected node is visible.

The implementation should use reveal/scroll-to-node behavior rather than resetting the entire tree scroll position.

Transient hover must never trigger automatic scrolling.

## Stable-identity projection

Every visible tree node must reference canonical identities:

```text
SiteId
BuildingId
LevelId
ZoneId
SpaceId
```

The navigator must not use identifiers such as:

```text
building:building-a
level:2
room:index-5
```

as canonical identity.

Synthetic view keys are allowed internally only when they wrap/reference stable canonical IDs and cannot be mistaken for persisted identities.

## Multi-building behavior

Current location must remain unambiguous when multiple buildings have equal level numbers.

Valid:

```text
Building A / Floor 2
Building B / Floor 2
```

Therefore a level cannot be located globally by `levelNumber` alone.

Navigator activation must resolve at minimum:

```text
BuildingId + LevelId
```

not only:

```text
levelNumber = 2
```

Switching Building must update both active Building and active Level atomically from the navigator/application navigation boundary.

## Authoring actions and context

Primary actions remain explicit and discoverable:

```text
[ + Building ]
[ + Level ] [ + Room ]
[ Wizard ]
```

Their target context is derived from the current location.

### + Building

Targets the active Site.

### + Level

Targets the active Building.

If no Building is active, the action is disabled or requests explicit Building selection. It must not guess a target when multiple Buildings exist.

### + Room

Targets the active Level.

It is enabled only when the active Level supports room authoring. It must not create a room on a hidden/previously active level.

### Wizard

The wizard receives explicit insertion/creation context where applicable. It must not infer target Building/Level from stale widget state.

## Creation behavior

After successful creation:

```text
Create Building
→ new Building becomes active
→ tree reveals Building

Create Level
→ new Level becomes active
→ tree reveals Level

Create Room
→ current Level stays active
→ new Room becomes selected
→ tree reveals Room
```

A failed/cancelled operation leaves current location unchanged.

## Delete behavior

If the selected/current entity is removed, the application layer must choose a deterministic valid fallback context.

Examples:

```text
remove selected Room
→ remain on its Level
→ select no Room or deterministic neighbor

remove active Level
→ activate deterministic neighboring Level in same Building

remove active Building
→ activate deterministic remaining Building or Site context
```

The navigator must not retain dangling IDs after structural mutation.

Fallback policy must be tested and must not depend on tree index accidents.

## Restore/reopen behavior

Project reopen may restore intentional working context if that context is part of the accepted resume-state contract.

Required validation:

```text
persisted active BuildingId exists
persisted active LevelId exists in that Building
persisted selected ZoneId/SpaceId exists in that Level
```

If resume-state references are invalid after migration/recovery, the system chooses a deterministic valid fallback and reports diagnostics where appropriate. It must not silently reinterpret one entity as another based on matching level numbers or labels.

## Canvas/editor synchronization

Navigator and editor must reflect one navigation/selection source of truth.

Examples:

```text
Navigator selects Floor 2
→ Editor activates Floor 2
→ breadcrumb updates
→ tree marks Floor 2 current

Canvas selects Bedroom
→ navigator marks Bedroom selected
→ ancestors reveal automatically

Next Level command
→ canonical active Level changes
→ editor + navigator + breadcrumb update from same state
```

Do not implement separate mutually synchronized booleans in multiple widgets.

## Visual-state requirements

Desktop tree must visually differentiate:

- active Building;
- active Level;
- selected Zone/Room;
- hover;
- focus/keyboard focus;
- modified/error/conflict badges if later introduced.

Selected/current state must not rely only on color. Use a combination such as:

- marker/icon;
- selected row treatment;
- text weight;
- accessible semantics label.

Example semantics:

```text
Floor 2, current level
Bedroom, selected room
Building A, active building
```

## Keyboard navigation

Desktop must support predictable keyboard interaction:

```text
Up/Down        move tree focus
Left           collapse / move to parent
Right          expand / move to first child
Enter/Space    activate focused node
Home/End       optional first/last visible node
```

Keyboard focus and selected project entity are related but not identical. Moving focus alone must not unexpectedly change engineering selection until activation semantics require it.

## Mobile/tablet adaptation

Mobile/tablet may present the tree as an adaptive sheet or full-screen structure navigator.

It must still show:

- current Building;
- current Level;
- selected Room/Zone;
- current breadcrumb/path where space permits;
- equivalent `+ Building`, `+ Level`, `+ Room`, `Wizard` actions.

The canonical navigation semantics are identical to desktop.

## Performance rule

Current-location updates must not rebuild/reproject the whole project tree unnecessarily.

Target behavior:

```text
ProjectChangeSet / NavigationChange
→ invalidate affected tree nodes/path
→ update current/selected markers
```

Hover changes must remain local presentation updates.

For large projects (100+ levels, 1000+ spaces, multiple buildings), revealing the current node must use indexed ID lookup rather than repeated O(N²) recursive scans.

## Persistence/state ownership

Canonical/project state:

```text
BuildingId / LevelId / ZoneId / SpaceId entities
project structure
```

Resume/session state where explicitly supported:

```text
active BuildingId
active LevelId
selected ZoneId/SpaceId
```

Transient UI state:

```text
expanded tree nodes
hovered node
keyboard-focus node
scroll offset
visual current marker
```

The transient state must not alter engineering semantics or sync revisions.

## Qualification scenarios

Add the following mandatory navigator qualification cases:

```text
N01 new project shows current Site/Building/Level
N02 selecting another Level moves current marker
N03 selecting a Room marks Room selected while Level remains current
N04 selecting a deeply nested Room auto-expands all ancestors
N05 explicit navigation scrolls current node into view
N06 hover does not change current/selected state
N07 Building A/Floor 2 and Building B/Floor 2 remain unambiguous
N08 + Building uses active Site context
N09 + Level uses active Building context
N10 + Room uses active Level context
N11 created Level becomes current and visible
N12 created Room becomes selected and visible
N13 cancel/failure preserves previous current location
N14 deleting selected Room leaves a valid Level context
N15 deleting active Level chooses deterministic valid fallback
N16 save/reopen restores valid current context when resume state is enabled
N17 invalid restored identity fails closed to deterministic fallback, never label/number guessing
N18 canvas selection updates navigator current path
N19 next/previous level updates navigator and breadcrumb from one source of truth
N20 keyboard focus is accessible and does not silently mutate project selection
N21 current/selected state is understandable without color alone
N22 large navigator current-node reveal uses indexed lookup path
N23 no Web/browser-specific navigation state or behavior exists
```

## Merge blockers

The corresponding implementation stage is blocked if:

- current location can be hidden inside a collapsed branch after explicit navigation;
- same-number levels in different buildings are ambiguous;
- `levelNumber` or list index is used as canonical navigator identity;
- `+ Level` or `+ Room` can target stale/hidden context;
- navigator and editor can disagree about active Building/Level;
- delete leaves dangling current/selected IDs;
- restored context silently binds to another entity by name/number;
- current/selected state is inaccessible to keyboard/screen-reader users;
- tree projection requires full-project rebuild for ordinary selection/hover;
- a Web-specific navigation model is introduced.

## Non-negotiable conclusion

The navigator is not only a hierarchy browser. It is the user's live structural-location indicator and authoring entry point.

At all times, the user must be able to see where they are in:

```text
Project → Site → Building → Level → Zone → Room
```

while `+ Building`, `+ Level`, `+ Room` and `Wizard` operate on that explicit current context through canonical application/domain commands.