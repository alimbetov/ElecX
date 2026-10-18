# ElecX Product Vision

## Product thesis

ElecX is a professional local-first engineering design application for electricians and adjacent building-system engineers. It combines a field-friendly CAD editor with typed engineering calculations, equipment knowledge, rule validation, automatic configuration and professional deliverables.

ElecX is not a collection of calculators and not a miniature desktop CAD clone.

The product should let an engineer move from a real building to a verified, reproducible engineering configuration with minimal context switching.

## Primary user

Initial target user:

- practicing electrician / electrical engineer;
- works on apartments, houses, offices, commercial buildings and technical spaces;
- often works on a tablet or laptop near the object;
- needs accurate geometry, placement, routing, calculations and documentation;
- values speed, offline operation and engineering traceability more than photorealistic 3D.

Future users include low-voltage engineers, installers, commissioning staff, project reviewers, customers and suppliers.

## Core promise

The engineer should be able to:

```text
open project
-> model the real site/building/level/room
-> work on plan, walls, floor and ceiling
-> place equipment
-> route cables and infrastructure continuously across surfaces
-> calculate and validate engineering decisions
-> compare feasible configurations
-> generate drawings, schedules, BOM and evidence
-> return later and reproduce why the system made a decision
```

## Product hierarchy

The spatial hierarchy is explicit and shared by every discipline:

```text
Project
  -> Site
      -> OutdoorZone[]
      -> Building[]
          -> Level[]
              -> Zone[]
              -> Space[]
```

Representative spaces:

- room;
- corridor;
- hall;
- technical room;
- stair;
- shaft;
- basement area;
- plinth / ground-floor technical zone;
- roof area;
- outdoor area.

Yard, parking and other exterior regions belong to the site model rather than being forced into the same semantic level as rooms.

## UX model

The application begins with a simple four-digit local quick unlock after account/bootstrap authentication. The engineer then enters a project hub and can continue the last workspace immediately.

Primary product modes:

```text
BUILD
DESIGN
REVIEW
```

`BUILD` creates and edits the spatial model.

`DESIGN` places and routes engineering systems.

`REVIEW` validates, compares, documents and publishes the result.

As capability grows, these map into specialized workspaces such as Room, Floor Routing, Panels, Reports, Installation and Commissioning without changing the underlying project model.

## Spatial editor vision

The editor is a precise 2D/2.5D engineering workspace inspired by the useful interaction principles of CAD, but optimized for building-system engineering.

Required experience:

- plan, wall, floor and ceiling are views of one physical model;
- per-room local coordinate frames and configurable grids;
- automatic centerlines and persistent guides;
- pan, zoom-around-cursor, fit room/floor/selection;
- endpoint, midpoint, center, intersection, perpendicular, nearest, wall and guide snap;
- doors, windows, openings, columns, shafts, beams, niches, steps and soffits;
- associative dimensions and live cursor distances;
- copy typical floor / repeated room patterns;
- exact metric coordinates stored independently of screen pixels;
- continuous routing while moving between adjacent physical surfaces.

The engineer should feel the precision of CAD without needing to manage generic CAD layers, arbitrary UCS state or free-camera 3D for ordinary field work.

## Killer feature: configuration that understands consequences

The long-term differentiator is not drawing. It is consequence-aware engineering configuration.

Example:

```text
replace 12 W camera with 25 W PTZ
    -> PoE demand changes
    -> switch candidate may become invalid
    -> rack layout may change
    -> UPS demand changes
    -> breaker / cable checks may change
    -> BOM and cost change
    -> configuration is re-ranked
```

The engineer remains in control, but ElecX maintains dependency awareness and can propose feasible alternatives instead of silently leaving the project inconsistent.

## Engineering domains

Electrical is the first commercial vertical. The architecture must also support independent engineering layers over the same geometry:

- electrical power and lighting;
- LAN / structured cabling;
- CCTV;
- access control;
- fire alarm;
- intrusion / intercom / PA;
- BMS / automation;
- solar, battery, generator, UPS and ATS systems;
- EV charging;
- future plumbing, heating and HVAC coordination.

Shared geometry and topology are generic. Discipline-specific engineering meaning remains strongly typed.

## Configuration output

ElecX should not force one opaque “best” answer. Where multiple valid designs exist it should expose a small Pareto-style set such as:

```text
Economy
Balanced
High reliability
```

Each candidate is explainable through:

- selected equipment;
- topology;
- routes;
- calculations;
- compliance findings;
- reserve margins;
- cost;
- evidence and source versions.

## Local-first and privacy

Engineering work must remain available offline. Local SQLite/Drift data is the operational source of truth for the device. The network is optional for core calculations.

Cloud capability is for:

- authentication and subscription;
- project sync / backup;
- controlled sharing and QR access;
- collaboration;
- catalog and price synchronization;
- heavy optimization or AI assistance where useful.

Technical project sharing and personal-account information are separate concerns.

## Non-goals for the first product generations

ElecX is not initially:

- a full BIM authoring package;
- a photorealistic interior-design tool;
- a free-form mesh/NURBS editor;
- a cloud-dependent SaaS calculator;
- a microservice-heavy distributed platform;
- an application where each engineering discipline owns a duplicate floor plan.

## Definition of success

An experienced engineer should be able to understand where they are, place or route objects accurately, see the consequence of changes, inspect why a calculation passed or failed and produce a professional deliverable without exporting the project into several unrelated applications.
