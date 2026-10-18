# ElecX Primary User Journeys

These journeys define the first product experience. Internal architecture exists to make these workflows fast, predictable and trustworthy.

## Journey 1 — Unlock and continue work

Goal: return to the active engineering context in seconds.

Flow:

```text
Launch
-> local PIN / biometric quick unlock
-> Projects
-> Continue last project
-> restore project + level + room/surface + viewport + active discipline/tool
```

Requirements:

- four-digit PIN is a local quick unlock, not the sole account-security mechanism;
- project hub shows recent projects and a clear `New Project` action;
- last workspace context is restorable;
- no mandatory cloud access for opening and editing an already local project;
- save/sync/validation state is visible without opening settings.

Success criterion: an engineer can reopen yesterday's exact working context with minimal navigation.

## Journey 2 — Create the physical project structure

Goal: describe the real object without forcing unrelated areas into one flat list.

Flow:

```text
New Project
-> project type / units / defaults
-> Site
-> outdoor zones
-> Building(s)
-> basement / plinth / floors / roof
-> floor zones
-> rooms / corridors / technical spaces / shafts
```

The hierarchy must support:

```text
Project
  -> Site
      -> Yard / Parking / Outdoor technical zone
      -> Building A
          -> Basement
          -> Plinth
          -> Floor 1
          -> Floor 2
          -> ...
          -> Roof
```

Requirements:

- floors may be copied to create typical levels;
- project/floor defaults may be inherited by rooms and overridden locally;
- room type is semantic data, not only a display name;
- exact geometry can be created manually or later imported from image/PDF/DXF sources;
- project setup must be a progressive wizard rather than one large form.

Success criterion: the spatial hierarchy resembles how the engineer thinks about the real building.

## Journey 3 — Build and edit the plan

Goal: create accurate usable geometry faster than in a general-purpose CAD workflow.

Primary editor structure for tablet/desktop:

```text
Project tree | Engineering canvas | Context properties
```

Core actions:

- draw room / wall / polygon;
- edit vertices and exact dimensions;
- place doors and windows;
- add columns, shafts, steps, beams, niches and other spatial features;
- pan / zoom / fit;
- measure;
- use room-local grid and reference axes;
- snap to meaningful geometry;
- copy rooms/floors/patterns;
- undo/redo every mutation.

Each room owns a local reference frame. The default origin is the geometric center, with automatic centerlines. The user can later select center/corner/custom origin and rotate the local frame.

Grid hierarchy:

```text
site / world context
-> floor grid
-> room-local grid
```

Snap priority is context-aware. Room-local geometry dominates while editing inside an active room.

Success criterion: common building geometry work feels closer to purpose-built CAD than to a drawing widget.

## Journey 4 — Work on wall, floor and ceiling surfaces

Goal: maintain physical continuity when the work leaves the floor plan.

The engineer can open a room and work on:

```text
Plan
Floor
Ceiling
Wall 1..N
piecewise-planar feature surfaces
```

These are not independent drawings. They are projections of one shared spatial model.

Typical wall interaction:

```text
            CEILING
               ^
               |
WALL D <- WALL A -> WALL B
               |
               v
             FLOOR
```

Requirements:

- doors/windows are visible consistently on plan and wall elevation;
- wall coordinates use distance along wall + height above finished floor;
- dimensions show wall length/height, opening dimensions and chained edge distances;
- active cursor or route point can show live distances to relevant edges;
- clicking/crossing a valid edge activates its adjacent surface;
- routing remains active when the surface changes;
- transitions preserve the same physical world point;
- topology, not visual orientation assumptions, determines the neighbor.

Future piecewise-planar interaction extends the same model through beam sides, soffit undersides, raised platforms and other features.

Success criterion: the engineer can follow the real installation path without mentally translating between disconnected plan/elevation drawings.

## Journey 5 — Engineer, validate and deliver the system

Goal: go from spatial intent to an explainable engineering result.

Flow:

```text
select BUILD / DESIGN / REVIEW
-> place loads/equipment/endpoints
-> connect ports / create systems
-> route cable/conduit/tray
-> run affected calculations
-> resolve constraints and normative findings
-> select or accept catalog equipment
-> compare candidate configurations where applicable
-> freeze/publish revision
-> generate BOM / schedules / drawings / reports
```

Initial electrical vocabulary:

- lighting;
- sockets and points;
- equipment loads;
- circuits;
- panels;
- cables and cable runs;
- protection devices;
- cable routing and laying method;
- UPS / generator / solar / battery / ATS where required.

Adjacent layers reuse the same geometry:

- LAN;
- CCTV;
- ACS;
- fire alarm;
- automation/BMS.

The UI must distinguish:

- facts the engineer entered;
- calculated facts;
- selected catalog products;
- normative findings;
- automatic recommendations;
- explicitly locked engineer decisions.

Success criterion: every important calculated or selected value can be traced back to geometry, inputs, solver/profile/catalog versions and the responsible project revision.

## Shared UX rules

Across all journeys:

- canvas stays dominant;
- one primary task owns the context panel;
- complexity is progressively disclosed;
- status never relies on color alone;
- touch targets are field-usable;
- keyboard/mouse productivity is supported where available;
- common repeated placement/routing actions do not require reopening palettes;
- validation points directly to the affected physical object;
- empty states suggest the next useful engineering action;
- printed/monochrome output remains understandable.
