# P5D — Opt-in Compass v1

## Status

Architecture and implementation specification for `feat/p5d-opt-in-compass-design`.

P5D follows P5C and must preserve the P5C canonical-navigation and controlled-hybrid invariants. It intentionally does not pull P5E, P6, P7 or P16 scope forward.

ElecX remains native-only:

- macOS
- Windows
- Linux
- Android
- iOS
- iPadOS

Web/browser runtime is out of scope.

## Objective

Add a discoverable but non-intrusive compass that communicates canonical project orientation without becoming a second navigation model, a viewport transform owner, or a persistence shortcut.

The compass is hidden by default and appears only after explicit user action.

The overlay must answer one question only:

```text
Where is canonical Project North relative to the current plan view?
```

It must not imply geospatial accuracy, device-heading accuracy, magnetic north, true north, survey north, or map georeferencing unless those capabilities are introduced by a later explicit architecture decision.

## Scope boundary

P5D includes:

- hidden-by-default compass overlay;
- explicit native UI toggle;
- canonical `ProjectNorth` value semantics;
- optional editing of Project North through an application/domain command;
- projection of Project North into the current plan viewport;
- focus-mode suppression;
- desktop/mobile adaptive controls;
- accessibility semantics;
- qualification and regression tests.

P5D does not include:

- viewport rotation as a new editing feature;
- device compass / magnetometer integration;
- GPS or map georeferencing;
- true-north / magnetic-declination calculations;
- solar studies;
- per-building local coordinate systems;
- P5E Room Surface Navigator;
- P6 semantic-space expansion;
- P7 BoundaryEdge / wall-topology work;
- P16 Drift/SQLite production persistence.

## Existing architecture constraints

The current project-structure specification already establishes:

```text
compass visible = transient editor-shell/session UI state
project north   = canonical engineering project state
```

Therefore showing or hiding the compass must never mutate canonical project data or mark the engineering document modified.

The compass consumes canonical state. It does not own it.

## Coordinate contract

### Canonical plan coordinate space

P5D defines Project North only in the canonical plan XY plane.

The existing geometry model uses millimetre coordinates with semantic `left/right/bottom/top`, therefore P5D treats the project plane as:

```text
+X -> project right
+Y -> project up
```

This is a domain convention, not a Flutter screen-coordinate convention.

### ProjectNorth representation

Use a dedicated immutable value object rather than a raw `double` spread across widgets.

Conceptual API:

```dart
final class ProjectNorth {
  const ProjectNorth._(this.milliDegreesClockwiseFromPositiveY);

  final int milliDegreesClockwiseFromPositiveY;

  static ProjectNorth fromDegrees(double degrees);
  double get degrees;
}
```

Canonical storage range:

```text
0 <= milliDegreesClockwiseFromPositiveY < 360000
```

Semantics:

```text
0°   -> North points along project +Y
90°  -> North points along project +X
180° -> North points along project -Y
270° -> North points along project -X
```

Angles are normalized before commit.

Do not persist NaN, Infinity, negative unnormalized values, or multiple equivalent encodings such as both `0` and `360`.

### Why integer milli-degrees

The canonical model should avoid floating-point equality and round-trip drift for a simple engineering orientation value.

One milli-degree precision is more than sufficient for this stage and yields deterministic equality, serialization and change detection.

### Unspecified Project North

Existing projects must not silently acquire a fabricated engineering orientation.

Therefore migration semantics are:

```text
legacy project without ProjectNorth
-> projectNorth = null / unspecified
```

Do not silently persist `0°` as if the engineer had confirmed it.

When the compass is visible and Project North is unspecified, show an explicit setup state such as:

```text
North not set
[ Set Project North ]
```

Do not draw a confident `N` arrow at 0°.

## Ownership

Project North is project-level canonical orientation metadata.

Conceptually:

```dart
ProjectAggregateRoot {
  ...
  ProjectNorth? projectNorth;
}
```

It is not owned by:

- `EditorController`;
- `EditorBuildingWorkspace`;
- a Level;
- a Room;
- `ProjectNavigationState`;
- the compass widget.

Future building-local transforms may reference the project/site frame, but P5D does not introduce per-building rotation.

## Mutation semantics

Editing Project North is an engineering mutation and must use the same P3 mutation discipline as structural authoring.

Conceptual commands:

```dart
SetProjectNorthCommand(ProjectNorth north)
ClearProjectNorthCommand()
```

Required semantics:

```text
user confirms new orientation
-> validate request
-> build candidate ProjectAggregateRoot
-> candidate graph validation
-> compute ProjectChangeSet
-> atomic commit
-> LocalProjectVersion + 1
-> one notification
-> one Undo boundary
```

Cancel must not change project state.

Setting the same normalized value is a no-op:

```text
same ProjectNorth
-> no version increment
-> no history record
-> no publication event
```

Showing/hiding the compass is not a mutation and must never enter this command path.

## UI/session state

Compass visibility belongs to editor-shell/session presentation state.

Conceptual state:

```dart
final class CompassOverlayState {
  final bool requestedVisible;
  final bool suppressedByFocusMode;

  bool get effectiveVisible =>
      requestedVisible && !suppressedByFocusMode;
}
```

Rules:

- initial `requestedVisible = false`;
- toggle changes presentation state only;
- no `ProjectChangeSet`;
- no LocalProjectVersion change;
- no canonical persistence publication;
- no legacy document dirty flag;
- focus mode may suppress the overlay without changing the user's requested visibility;
- leaving focus mode restores the overlay if the user had requested it.

P5D does not require persistence of compass visibility across app restarts. If such preference persistence is later added, it belongs to user/editor preferences, not engineering project data.

## Viewport projection

The compass is a projection of canonical Project North into the current plan viewport.

The rendering layer may need a transient viewport rotation input if one already exists, but P5D must not introduce viewport rotation as a new editing capability.

Conceptually:

```text
canonical ProjectNorth
+ existing viewport orientation
-> screen arrow orientation
```

If the current viewport has no rotation capability, the compass projection is direct.

The projection adapter must own Flutter/screen-axis conversion. Domain `ProjectNorth` must never encode Flutter Y-down coordinates.

## Visibility by editor mode

Baseline:

- Plan view: supported.
- Room world / surface view: hidden unless a later explicit requirement defines useful semantics there.
- Site/outdoor view: may be supported only when it uses the same canonical project coordinate frame.

Fail closed when the current editor mode does not have a valid plan-orientation projection.

Do not show a misleading compass merely because an overlay slot is available.

## Native controls

### Desktop

Provide a discoverable control in a View/app-bar surface:

```text
[ Compass ]
```

or equivalent checked menu item.

Requirements:

- visible text or tooltip;
- keyboard reachable;
- checked/on state exposed semantically;
- no hidden gesture-only activation.

### Mobile / tablet

Expose the same semantic toggle in an adaptive View sheet/menu:

```text
[ ] Compass
```

The domain behavior must be identical to desktop.

## Overlay placement

Default placement: viewport top-right safe overlay area, not raw screen top-right.

The layout must account for:

- app bar;
- navigator/drawer edge;
- floating authoring controls;
- context controls;
- platform safe areas;
- mobile notches/insets;
- blocked-materialization banner from P5C.

The overlay must not cover primary authoring controls.

Recommended implementation shape:

```text
Editor viewport Stack
├── canvas
├── controlled status/banner overlays
└── compass overlay safe-area anchor
```

The compass should consume pointer events only inside its own interactive hit target. The rest of the overlay layer must not block canvas gestures.

## Interaction

Minimum interaction:

```text
Toggle Compass
-> show/hide overlay

Tap/click visible compass
-> open Project North details/edit action
```

Editing should be explicit and confirmable.

Suggested first-stage editor:

```text
Project North
Angle: [ 32.500° ]

[ Cancel ] [ Apply ]
```

Optional quick presets may be added later, but P5D should not create multiple competing orientation inputs.

The visible compass itself should not be freely draggable unless a separate UX decision justifies persistent/temporary placement behavior.

## Accessibility

The compass must not rely on arrow color alone.

Required semantics:

```text
Compass, Project North 32.5 degrees clockwise from project up
```

For unspecified orientation:

```text
Compass, Project North not set
```

Requirements:

- keyboard focus on desktop;
- Enter/Space activation where appropriate;
- screen-reader label/state;
- visible `N` marker when orientation is defined;
- minimum practical touch target around the interactive control;
- focus ring/treatment not dependent on color alone;
- sufficient contrast in light and dark themes.

## Error handling

Invalid engineering input is rejected before mutation.

Examples:

```text
empty / unparsable angle -> validation error
NaN / Infinity          -> validation error
same normalized value   -> no-op
```

Unexpected runtime projection failure must not mutate Project North and must not rotate the canvas.

The compass may be hidden and a diagnostic surfaced rather than rendering a misleading arrow.

## P5C compatibility invariants

P5D must not weaken P5C.

Specifically:

- no new navigation source of truth;
- no `levelNumber` identity use;
- no direct structural mutation in widgets;
- no bypass of `CanonicalEditorRuntimeCutoverCoordinator` for structural navigation;
- no new legacy persistence ownership claim;
- no synthetic Room geometry;
- no compass action may change Building/Level/Room navigation.

The compass is orthogonal to `ProjectNavigationState`.

## Persistence boundary

Project North is canonical engineering data and must participate in canonical codec/repository round-trip when P5D implementation adds the field.

P5D does not require Drift/SQLite.

The implementation order is:

```text
ProjectNorth value semantics
-> aggregate field
-> command/change-set semantics
-> canonical document codec / current repository boundary
-> UI projection
```

Do not write Project North directly into `EditorProjectDocument` from the widget layer as an independent persistence path.

If the transitional repository/codec cannot yet round-trip the field safely, Project North editing must remain disabled until an explicit canonical persistence owner exists, analogous to the P5C production-authoring gate.

## Suggested implementation slices

### P5D-A — orientation value contract

- add `ProjectNorth` value object;
- normalization/validation;
- equality/hash;
- optional aggregate field;
- codec round-trip contract tests.

### P5D-B — mutation commands

- `SetProjectNorthCommand`;
- optional `ClearProjectNorthCommand`;
- no-op behavior;
- undo/redo qualification;
- LocalProjectVersion guard.

### P5D-C — shell presentation state

- hidden by default;
- requested vs effective visibility;
- focus-mode suppression;
- no dirty-state side effects.

### P5D-D — compass projection/widget

- screen projection adapter;
- plan-only fail-closed behavior;
- safe overlay placement;
- light/dark theme;
- accessibility semantics.

### P5D-E — production wiring

- desktop View/app-bar toggle;
- mobile/tablet adaptive toggle;
- Project North edit flow;
- persistence-owner gate when editing is not safely durable;
- `UnifiedWorkspaceEditorScreen` integration without P5C regression.

### P5D-F — qualification

- widget tests;
- domain tests;
- codec/repository round-trip tests;
- Flutter analyze/test;
- macOS Desktop gate;
- later P17 native cross-platform qualification remains separate.

## Qualification matrix

Mandatory scenarios:

```text
D01 new session starts with compass hidden
D02 showing compass does not increment LocalProjectVersion
D03 showing compass does not mark legacy document Modified
D04 hiding compass does not mutate ProjectNorth
D05 focus mode suppresses visible compass
D06 leaving focus mode restores previously requested compass visibility
D07 unspecified ProjectNorth shows explicit not-set state, never fake 0°
D08 setting 0° points North along project +Y
D09 setting 90° points North along project +X
D10 angle normalization is deterministic
D11 NaN/Infinity/unparsable values are rejected
D12 setting same normalized value is a no-op
D13 SetProjectNorth produces one ProjectChangeSet / one undo boundary
D14 undo restores previous ProjectNorth exactly
D15 redo restores edited ProjectNorth exactly
D16 ProjectNorth round-trips through canonical codec/repository boundary
D17 compass is absent in unsupported editor projection mode
D18 compass toggle is keyboard accessible
D19 screen-reader semantics expose current orientation / not-set state
D20 compass overlay does not intercept unrelated canvas pointer gestures
D21 overlay does not cover primary structural authoring controls
D22 P5C navigator/cutover behavior remains unchanged
D23 same-number Levels in different Buildings have no effect on compass identity
D24 no Web/browser implementation or dependency is introduced
```

## Merge blockers

P5D is not complete if any of the following is true:

- compass is visible by default;
- visibility dirties the engineering project;
- UI stores Project North only in widget/controller state;
- legacy projects silently acquire a persisted `0°` orientation;
- compass uses Flutter screen coordinates as canonical orientation semantics;
- compass changes structural navigation;
- the overlay blocks canvas gestures outside its hit target;
- focus mode permanently loses the user's requested visibility state;
- Project North edit bypasses P3 mutation semantics;
- Project North cannot round-trip through the accepted canonical persistence boundary;
- unsupported editor modes show a misleading orientation;
- accessibility exposes only an unlabeled icon/arrow;
- P5D introduces device sensors, geospatial semantics, viewport rotation, P5E, P6, P7 or P16 work.

## Closure definition

P5D may be marked `CLOSED` when:

```text
- ProjectNorth semantics are explicit and deterministic
- compass is opt-in and hidden by default
- visibility remains presentation-only state
- Project North editing uses canonical mutation semantics
- canonical persistence boundary round-trips ProjectNorth safely
- production screen wiring is qualified
- pointer/keyboard/accessibility behavior is qualified
- P5C regressions remain green
- final Flutter and macOS Desktop gates pass
```

Expected closure statement:

```text
P5D CLOSED

Included:
- canonical ProjectNorth value
- opt-in compass overlay
- desktop/mobile toggle
- focus-mode suppression
- Project North edit command
- canonical round-trip
- accessibility/pointer qualification

Deferred:
- viewport rotation feature
- device compass / magnetometer
- georeferencing / true north
- per-building transforms
- P5E Room Surface Navigator
- P6/P7 model expansion
- P16 Drift/SQLite
```
