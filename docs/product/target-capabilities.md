# ElecX Target Capability Map

This document defines the target product capability landscape. It is intentionally independent from release-stage names.

## 1. Project and identity

Target capabilities:

- account bootstrap and optional cloud identity;
- four-digit local quick unlock and biometrics;
- local project library;
- project templates;
- recent/continue workspace;
- project variants and scenarios;
- project revision history;
- local autosave;
- optional sync/backup/share.

## 2. Spatial project model

Canonical hierarchy:

```text
Project
  -> Site
      -> OutdoorZone[]
      -> Building[]
          -> Level[]
              -> Zone[]
              -> Space[]
```

Spatial capability includes:

- basement, plinth, normal floors, roof and outdoor areas;
- rooms, corridors, halls, stairs, shafts and technical spaces;
- exact dimensions and semantic room types;
- floor/room height inheritance;
- typical-floor copy and reusable room patterns;
- imported plan references;
- shared geometry across all engineering disciplines.

## 3. CAD-grade spatial editor

Required target behavior:

- exact integer-millimetre world coordinates;
- world/floor/room local coordinate frames;
- rotated room reference frame;
- floor grid and independently configurable room grid;
- centerlines, guides and smart alignment hints;
- pan, zoom-around-cursor, fit floor/room/selection;
- screen/world conversion independent of stored geometry;
- draw/edit rectangle and arbitrary polygon rooms;
- vertex, segment and dimension editing;
- snap candidates: grid, endpoint, midpoint, center, intersection, perpendicular, nearest, wall, guide, equipment;
- selection/hit-test priority rules;
- associative dimensions;
- measurement and dynamic cursor dimensions;
- undo/redo command history;
- copy/paste/pattern/repeat tools.

## 4. Surface-centric 2.5D model

A room is represented through concrete editable surfaces, not only a floor polygon.

```text
Room
  -> RoomSurface[]
      -> SurfacePatch[]
          -> SurfaceEdge[]
```

Target geometry supports:

- floor;
- ceiling;
- wall surfaces;
- horizontal, vertical and sloped planar patches;
- steps and raised areas;
- beams and soffits;
- niches and recesses;
- columns and shafts;
- platforms/protrusions;
- custom piecewise-planar features.

A full BIM/NURBS/free-form mesh authoring engine is not required.

## 5. Architectural openings and features

Target objects:

- door;
- window;
- passage;
- technical opening;
- column;
- shaft;
- beam;
- soffit;
- niche;
- step;
- platform;
- recess;
- protrusion.

The same opening/feature identity must render consistently in plan, elevation and relevant surface views.

## 6. Surface navigation

Target interaction is edge-driven:

```text
wall top    -> ceiling
wall bottom -> floor
wall side   -> adjacent wall
floor edge  -> corresponding wall
ceiling edge -> corresponding wall
feature edge -> explicitly adjacent patch
```

Near an edge the UI may progressively preview the adjacent surface. Routing and placement operations can continue through a valid transition.

## 7. Engineering objects and typed ports

Shared engineering concepts:

```text
EngineeringEntity
Port
Connection
Assignment
EquipmentItem
Endpoint
EngineeringLayer
```

Equipment may expose multiple typed ports so one real device can participate in several systems.

Example:

```text
Camera
  -> ETHERNET_POE

AirConditioner
  -> POWER
  -> CONTROL
  -> DRAIN
  -> REFRIGERANT_IN
  -> REFRIGERANT_OUT
```

Do not duplicate the physical device per discipline.

## 8. Physical routing

Routing is explicit topology:

```text
Run
  -> Route
      -> RouteNode[]
      -> RouteSegment[]
```

Target node semantics include:

- endpoint;
- bend;
- junction;
- surface transition;
- entry / exit;
- riser / vertical drop;
- room transition;
- floor transition.

Target routes support:

- cable;
- conduit;
- tray;
- duct/pathway references;
- shared physical channels;
- laying method per segment;
- exact derived geometric length;
- reserve and termination allowances;
- route continuity across wall/floor/ceiling/feature surfaces.

## 9. Electrical design

Initial commercial capability:

- loads and consumption groups;
- demand/design current;
- circuits;
- cable sizing;
- voltage drop;
- short-circuit related checks where data is available;
- breaker/RCD/RCBO/SPD selection requirements;
- selectivity/co-ordination extension points;
- panel hierarchy;
- phase assignment and reserve;
- cable routes;
- generator/UPS/battery/solar/ATS source topology;
- panel and cabinet layout;
- BOM and schedules.

## 10. Low-voltage engineering layers

Target typed layers:

- CCTV;
- LAN / structured cabling / Wi-Fi;
- access control;
- fire alarm;
- intrusion alarm;
- intercom;
- PA/voice alarm;
- BMS/automation/IoT.

Shared geometry/connectivity/routing infrastructure remains generic. Calculation semantics remain discipline-specific.

## 11. Equipment and reference catalog

Catalog capability is a platform subsystem, not a late deliverable stage.

Required layers:

```text
Canonical engineering classes
ELV/electrical reference data
Manufacturer catalog products
Price books / vendor offers
Project overrides / approved equivalents
```

Reference/catalog data supports:

- stable technical codes;
- versioning;
- validity/effective dates;
- lifecycle/deprecation;
- provenance;
- unit normalization;
- compatibility relations;
- capabilities and technical parameters;
- project pinning;
- preferred/forbidden vendors;
- user/project-local extensions.

## 12. Solver runtime

Calculations implement a common contract and declare dependencies.

Conceptually:

```text
EngineeringSolver
  consumes FactKind[]
  produces FactKind[]
  solve(context)
```

The runtime provides:

- solver registry;
- dependency graph;
- affected-closure calculation;
- deterministic execution;
- input/output fingerprints;
- versioned evidence;
- selective recalculation rather than full-project recomputation.

## 13. Constraints and normative validation

Solver and constraint responsibilities are distinct.

```text
Solver      -> what is the engineering result?
Constraint  -> is this state allowed/acceptable?
```

Constraint sources include:

- physical compatibility;
- capacity;
- environmental limits;
- manufacturer compatibility;
- project rules;
- jurisdiction/normative rule packs.

Projects explicitly pin normative profile versions. Existing projects must not silently change because a global rule pack was updated.

## 14. Configuration and optimization

Target configuration flow:

```text
Requirements
-> abstract engineering requirements
-> catalog candidates
-> solver graph
-> constraints/compliance
-> feasible configurations
-> objectives
-> ranked / Pareto candidates
```

Candidate objectives may include:

- CAPEX;
- OPEX/energy;
- reliability;
- spare capacity;
- maintainability;
- availability;
- rack/panel space;
- local product availability;
- SKU standardization.

Engineer-locked decisions remain locked unless explicitly released.

## 15. Layout and enclosure design

Target capabilities:

- electrical panels;
- DIN rows/modules;
- terminals;
- busbars;
- ducts;
- cabinet zones;
- racks;
- patch panels;
- switches/NVR/controllers;
- mm/module/U capacity;
- cable-entry and routing zones;
- thermal/load/clearance constraints where modeled;
- automatic layout candidate generation with manual override.

## 16. Review, evidence and revisions

Every critical result should be reproducible from:

- project revision;
- spatial revision;
- catalog edition;
- normative profile;
- solver version;
- input snapshot/fingerprint;
- result/evidence.

Target revision states may include working/draft/frozen/published concepts, but exact lifecycle should remain explicit and tested.

## 17. Deliverables

Target outputs:

- floor plans;
- wall/ceiling/floor engineering views;
- single-line/topology diagrams;
- cable schedules;
- panel schedules;
- rack/cabinet schedules;
- BOM/BOQ;
- cost estimate;
- labels and QR;
- calculation reports;
- compliance report;
- professional PDF;
- spreadsheet export;
- DXF/DWG interchange later where practical.

## 18. Field execution

Future field workflows:

- work packages;
- planned vs installed/as-built;
- deviations;
- photos/notes;
- pull/termination records;
- test/checklist records;
- measured values;
- commissioning status;
- issue tracking tied to physical objects.

## 19. Collaboration and cloud

Cloud is optional for core engineering but supports:

- sync and backup;
- QR/share links;
- read-only customer view;
- authenticated collaborator access;
- layer permissions;
- comments/audit;
- catalog/price distribution;
- compute-heavy optimization/AI when beneficial.

The local application remains useful without a live backend.
