# ElecX Engineering Workspace UI

## Purpose

ElecX should feel like one coherent engineering instrument from spatial setup through design, review and field execution. The interface must be precise enough for engineering work but simpler than a general-purpose desktop CAD suite.

## Governing UX principles

1. Canvas first.
2. One active task, one primary context panel.
3. Progressive disclosure instead of permanent clutter.
4. Stable project/spatial context is always visible.
5. Technical graphics, not decorative rendering.
6. Color supplements meaning; it never carries meaning alone.
7. Field ergonomics: large hit targets, predictable gestures, minimal modal workflows.
8. Same domain state, adaptive composition across desktop/tablet/phone.
9. Drill down into detail instead of showing every subsystem at once.
10. Every critical number is traceable to its object, calculation and evidence.

## Product mode switcher

The simplest top-level mental model is:

```text
BUILD | DESIGN | REVIEW
```

### BUILD

Tools focus on:

- site/building/level/space structure;
- walls/rooms;
- doors/windows/openings;
- features;
- dimensions;
- grids/guides/reference frames;
- floor/room duplication.

### DESIGN

Tools focus on:

- equipment/endpoints;
- engineering systems/layers;
- connections;
- routes;
- panels/racks/cabinets;
- engineering properties;
- auto-layout/configuration actions.

### REVIEW

Tools focus on:

- issues/findings;
- calculations;
- compliance;
- configuration alternatives;
- BOM/cost;
- reports/drawings;
- freeze/publish/export.

## Tablet/desktop shell

Preferred composition:

```text
+--------------------------------------------------------------------------------+
| Project / Building / Level / Space | BUILD/DESIGN/REVIEW | Status | Undo/Redo |
+-------------------+--------------------------------------+---------------------+
| Project / Tool    |                                      | Context / Inspector |
| rail              |          ENGINEERING CANVAS          |                     |
|                   |                                      |                     |
+-------------------+--------------------------------------+---------------------+
| Coordinates | Snap | Grid | Scale | Active surface | Tool-specific actions   |
+--------------------------------------------------------------------------------+
```

The right context panel is collapsible. The canvas should always receive the largest area.

## Phone composition

- no permanent right panel;
- context becomes bottom sheet;
- tools move into reachable bottom/edge controls;
- project hierarchy is compact and drill-down based;
- canvas remains dominant;
- advanced properties use staged/paged sections.

## Context hierarchy

The top bar should answer immediately:

- which project?
- which building/level/space?
- which product mode/workspace?
- which discipline/layer?
- saved/sync/validation state?

Low-frequency administration does not belong in the working toolbar.

## Spatial editor tool vocabulary

BUILD tools:

```text
Select
Room / Wall
Opening
Feature
Guide
Measure / Dimension
```

DESIGN tools:

```text
Select
Equipment
Endpoint / Point
Connect
Route
Junction
Panel / Rack
Measure
```

REVIEW tools:

```text
Issue / Finding
Trace
Compare
Validate
Publish
Export
```

Tool names/icons must remain stable across surfaces/workspaces.

## CAD interaction

Desktop/pointer productivity:

```text
wheel       zoom around cursor
middle/space+drag temporary pan
Esc         cancel operation
Enter       finish operation
Delete      delete selection
Ctrl/Cmd+Z  undo
Ctrl/Cmd+Shift+Z redo
F           fit/focus selection
```

Touch equivalents must exist; keyboard shortcuts are accelerators, not the only access path.

## Room/surface editing

The engineer can work on plan, floor, ceiling or a wall/feature surface without leaving the room context.

Surface navigation is geometry-driven.

Near a valid edge the UI can:

- highlight the edge;
- preview the neighboring surface;
- show the target surface name/icon;
- allow click/tap/cross to activate it;
- preserve an active route/placement operation when topology permits.

Doors/windows/openings keep the same identity in plan and elevation.

## Precision UI

The editor should always make precision discoverable:

- cursor coordinates;
- current local/world frame;
- snap candidate hint;
- active grid step;
- zoom/scale;
- live distances to walls/edges;
- explicit dimensions;
- numeric entry for constrained edits.

Dynamic measurement lines should appear only when useful for the active action.

## Selection hierarchy

Visual priority:

```text
active tool target
selected object
related/dependent objects
context geometry
inactive background
```

Dense routes, surfaces and equipment cannot all compete at equal emphasis.

## Properties

Properties are grouped consistently:

```text
Basic
Geometry
Engineering
Advanced
Evidence (when relevant)
```

Example equipment:

```text
Basic
  type/name
  system/circuit

Geometry
  space/surface
  local position
  height/orientation

Engineering
  load/capabilities/ports
  selected catalog product

Advanced
  IDs / overrides / custom metadata

Evidence
  calculation/profile/catalog references
```

## Repeated actions

Common field actions must not require reopening a palette repeatedly.

Examples:

- place multiple sockets/lights/detectors;
- repeat spacing pattern;
- route multiple branches;
- assign several endpoints to a circuit;
- continue working on adjacent surfaces.

Recent/favorites/project presets may reduce catalog search cost.

## Floor Routing view

The floor-wide routing canvas prioritizes topology over room-detail decoration.

Show:

- floor outline/rooms as context;
- panels/racks;
- tray/conduit/pathway backbones;
- risers/transitions;
- junctions;
- outgoing branches;
- selected route traces.

Useful trace actions:

```text
Trace upstream
Trace downstream
Show path to source
Show carried runs
Open room
Open junction
```

## Panel / rack workspace

Physical layout supports:

- module/U grids;
- drag/drop assignment;
- auto-numbering;
- free/occupied capacity;
- terminals/ports;
- reserve;
- inline findings;
- auto-layout candidate + manual override;
- direct BOM/validation.

## Validation UX

Bad:

```text
17 errors
```

Preferred:

```text
Circuit C-14 — overloaded
-> highlight route + connected loads
-> show violated rule/input
-> offer direct corrective actions or candidate alternatives
```

Findings link to the actual physical/engineering object.

## Configuration UX

Auto-configuration must remain transparent.

The UI distinguishes:

- suggested;
- accepted;
- manual;
- locked;
- invalid;
- deprecated/unavailable.

Alternative configurations should emphasize meaningful engineering tradeoffs, not only opaque scores.

Example:

```text
Economy        lower CAPEX, lower reserve
Balanced       target reserve/reliability
High reliability redundant/greater reserve
```

Each alternative drills down to changed equipment, calculations, findings and cost.

## Reports and review

Reports are navigable before they are exportable.

```text
Project overview
-> Level/Space/System
-> Circuit/Route/Equipment
-> Evidence
```

Any aggregate should support drill-down.

## Field modes later

Installation and Commissioning modes reuse the same physical objects but change the available actions.

Installation emphasizes planned/as-built, work packages, deviations, labels and issues.

Commissioning emphasizes test sequence, measured values, pass/fail and unresolved issues.

## Acceptance UX targets

An experienced engineer should be able to:

- understand current project/level/space/mode within two seconds;
- restore the previous working viewport quickly;
- edit exact geometry without guessing pixel distances;
- move from plan to the relevant wall/floor/ceiling without losing context;
- continue a cable route across surfaces;
- place repeated components without repeated palette navigation;
- trace a route/system to its source;
- see why a validation failed at the affected object;
- inspect why a catalog item/configuration was selected;
- produce an understandable monochrome print/export.

The product should feel simple because irrelevant complexity is hidden, not because engineering capability is removed.
