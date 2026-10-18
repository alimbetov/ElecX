# ElecX Target Roadmap

This roadmap implements the target product architecture. It deliberately does not use ELV1–ELV8 as runtime boundaries.

## Delivery rule

Every wave must end with:

- exact functional scope;
- domain invariants;
- tests;
- analyzer/format gates;
- migration notes if persistence changes;
- user-visible acceptance scenario;
- no silent widening of responsibility into neighboring bounded contexts.

## Wave A — Product shell and project workflow

Outcome: the engineer can enter the app, create/open a project and reach the exact workspace quickly.

Scope:

- local quick unlock;
- account/bootstrap boundary;
- project hub;
- recent/continue project;
- Project/Site/Building/Level/Space hierarchy;
- project templates and units;
- local save/autosave foundation.

Status: foundation started.

## Wave B — CAD viewport foundation

Outcome: the canvas behaves like a professional engineering editor, not a static Flutter drawing area.

Scope:

- `ViewportController`;
- pan;
- zoom-around-cursor/focal point;
- fit floor/room/selection;
- stable world<->screen transform;
- cursor coordinates;
- zoom-dependent rendering density;
- keyboard/mouse gestures and touch equivalents.

Recommended branch:

`feat/spatial-viewport-cad-controls`

## Wave C — Geometry editing and snap engine

Outcome: arbitrary rooms and architectural geometry can be created and edited precisely.

Scope:

- polygon room/wall editing;
- editable vertices/segments;
- exact numeric geometry edits;
- grid/endpoint/midpoint/center/intersection/perpendicular/nearest/wall/guide snap;
- snap preview and deterministic candidate selection;
- room-local rotated reference frames;
- persistent guides and smart guides;
- associative dimensions;
- undo/redo command model.

## Wave D — Surface topology and 2.5D geometry

Outcome: rooms expose physically continuous editable floor/wall/ceiling/feature surfaces.

Scope:

- concrete `RoomSurface`/`SurfacePatch` model;
- edge adjacency;
- floor/ceiling/wall transitions;
- doors/windows/openings;
- beams/soffits/columns/shafts/steps/niches;
- piecewise-planar patch transforms;
- topology validation;
- edge-driven adjacent-surface preview;
- plan/elevation consistency.

Current branch already contains the first derived-surface implementation; this wave generalizes it into full patch topology.

## Wave E — Spatial persistence and revisions

Outcome: spatial work survives real project lifecycle changes safely.

Scope:

- Drift schema;
- Project/Site/Building/Level/Zone/Space persistence;
- surfaces/patches/edges/openings/features;
- spatial revision identity;
- spatial change impact events;
- import/export project snapshot;
- copy typical floor;
- deterministic migrations and fixtures.

## Wave F — Engineering entity and routing core

Outcome: engineering objects and physical runs can be placed and routed on shared geometry.

Scope:

- EngineeringEntity;
- Port/Connection;
- EngineeringLayer;
- Equipment/Endpoint placement;
- Route/RouteNode/RouteSegment;
- multi-surface cable routing;
- explicit surface/room/floor transitions;
- laying method;
- cable/conduit/tray physical channels;
- junction semantics;
- derived exact route length.

## Wave G — Electrical first vertical

Outcome: ElecX becomes useful for a real electrical project end-to-end.

Scope:

- loads;
- circuits;
- demand/design current;
- cable requirements/sizing;
- voltage drop;
- protection requirements;
- breaker/RCD/RCBO/SPD model;
- panel hierarchy;
- source topology;
- basic generator/UPS/ATS/battery/solar support;
- electrical BOM/schedules.

Reuse proven Electra algorithms where correct, but expose them through new solver contracts rather than ELV stage ownership.

## Wave H — Engineering knowledge and catalog

Outcome: calculations and selection use versioned engineering knowledge rather than UI constants.

Scope:

- canonical reference catalogs;
- manufacturer/product catalog;
- typed capabilities/parameters;
- compatibility;
- lifecycle/version/provenance;
- project overlays/preferred vendors;
- price books/vendor offers;
- project catalog pinning;
- local/user catalog extension.

Catalog is required before serious auto-configuration.

## Wave I — Solver graph and constraints

Outcome: project changes invalidate and recalculate only affected engineering facts.

Scope:

- common solver interface;
- solver registry;
- consumes/produces fact declarations;
- dependency graph;
- affected closure;
- deterministic execution;
- fingerprints/caching;
- evidence envelopes;
- physical/capacity/compatibility constraints.

## Wave J — Normative/compliance engine

Outcome: projects are checked against explicit versioned rule profiles.

Scope:

- jurisdiction profiles;
- normative rule packs;
- project profile pinning;
- findings with evidence;
- rule applicability;
- severity/status;
- explainable links to affected geometry/equipment/calculation;
- KZ baseline first, followed by IEC/EU profiles where supported.

Normative references must be verified and provenance-tracked; documentation must not imply completeness without evidence.

## Wave K — CCTV/LAN/ACS/FIRE solvers

Outcome: low-voltage disciplines reuse the same spatial/routing/equipment core.

Scope examples:

### CCTV
- bitrate;
- storage;
- bandwidth;
- PoE power;
- recorder/channel requirements.

### LAN
- ports;
- link/channel limits;
- bandwidth/uplink;
- PoE;
- copper/fiber constraints.

### ACS
- controller capacity;
- lock/PSU demand;
- I/O;
- autonomy.

### Fire
- loop capacity;
- PSU/battery demand;
- standby/alarm modes;
- supervision/rule constraints.

Historical ELV5 is design input for this wave.

## Wave L — Rack/panel/cabinet layout

Outcome: selected equipment is physically arranged and validated.

Scope:

- racks/cabinets;
- DIN rows/modules;
- terminals/busbars/ducts;
- rack U and depth/load capacity;
- patching;
- cable-entry zones;
- reserve capacity;
- layout constraints;
- automatic layout candidate generation;
- manual override.

Historical ELV6 is design input for this wave.

## Wave M — Configuration engine

Outcome: ElecX can propose feasible engineering configurations from requirements.

Scope:

- requirement normalization;
- abstract component requirements;
- catalog candidate generator;
- constraint propagation;
- candidate evaluation;
- engineer locks;
- infeasibility explanations;
- scenario variants.

## Wave N — Optimization

Outcome: the engineer can compare a small set of high-quality alternatives.

Scope:

- CAPEX;
- reserve;
- reliability;
- availability;
- energy/OPEX;
- space;
- maintainability;
- SKU standardization;
- local vendor availability;
- Pareto/ranked alternatives.

## Wave O — Deliverables

Outcome: the project can be issued professionally from authoritative state.

Scope:

- plans/elevations;
- topology/single-line diagrams;
- cable/circuit/panel/rack schedules;
- BOM/BOQ;
- estimates;
- labels/QR;
- calculation/compliance reports;
- PDF;
- spreadsheet export;
- future DXF/DWG interchange.

Historical ELV8 deliverable work is design input here; manufacturer selection itself belongs earlier in Catalog/Configuration.

## Wave P — Installation and commissioning

Outcome: ElecX follows the project from design into the field.

Scope:

- work packages;
- installed/as-built status;
- route deviations;
- photos/notes;
- cable pull/termination evidence;
- tests/checklists;
- measured values;
- issues;
- commissioning status.

## Wave Q — Cloud and collaboration

Outcome: users can share and collaborate without making cloud availability a core engineering dependency.

Scope:

- sync/backup;
- QR project sharing;
- customer read-only view;
- authenticated collaborator access;
- discipline/layer permissions;
- comments/audit;
- catalog/price synchronization;
- optional heavy optimization/AI execution.

## Current immediate sequence

For the current repository state, the recommended next order is:

```text
1. CAD viewport
2. snap + polygon geometry
3. full surface topology/openings/features
4. spatial persistence/revisions
5. engineering entities + routing
6. electrical vertical
7. catalog + solver graph
8. constraints/compliance/configuration
```

Do not jump directly into discipline-specific calculation storage before these foundations are stable.
