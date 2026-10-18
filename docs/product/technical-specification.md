# ElecX Technical Specification

Status: target product specification.

This document is the concise top-level technical contract. Detailed authority is split across product and architecture documents referenced below.

## 1. Product

ElecX is a professional local-first engineering design application focused first on electrical installation and expanded through typed engineering modules over one shared spatial model.

The product combines:

- project/site/building/space modelling;
- CAD-grade 2D/2.5D editing;
- physical routing;
- electrical and ELV calculations;
- equipment/reference catalogs;
- constraints and normative validation;
- automatic configuration/optimization;
- professional deliverables;
- future installation/commissioning and collaboration.

## 2. Platform

Primary client: Flutter application targeting tablet/desktop/mobile form factors.

Architecture:

- local-first/offline-capable;
- SQLite/Drift operational local store;
- pure Dart/domain packages for calculations and model logic;
- optional backend for identity, sync, sharing, collaboration, catalog distribution and heavy compute;
- modular monolith before service decomposition.

## 3. Language and identifiers

Code, database/schema/API identifiers, domain codes and technical documentation are English-first.

User-facing text is localization-ready. Stable codes remain language-neutral.

## 4. User entry flow

```text
Launch
-> local PIN/biometric quick unlock
-> Project Hub
-> Continue / New Project
-> restore or create spatial workspace
```

PIN is a local unlock convenience after bootstrap/account trust has been established; it is not the complete security model.

## 5. Project hierarchy

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

Levels support basement, plinth, normal floors, roof and other explicit level semantics.

Spaces support rooms, corridors, halls, technical rooms, stairs, shafts and outdoor areas.

## 6. Editor modes

Primary mental model:

```text
BUILD
DESIGN
REVIEW
```

BUILD edits architecture/spatial facts.

DESIGN edits engineering objects, connections and physical routes.

REVIEW exposes calculations, validation, configuration alternatives and deliverables.

Future specialized workspaces include Room, Floor Routing, Panels, Reports, Installation and Commissioning.

## 7. Geometry and coordinate model

Canonical persisted geometry uses integer millimetres and, where required, x/y/z world coordinates.

Each room/patch exposes deterministic local coordinates.

The spatial target is polygonal piecewise-planar geometry rather than free-form BIM.

Detailed contract: `docs/architecture/spatial-platform.md`.

## 8. CAD interaction baseline

Required capabilities include:

- pan;
- zoom around pointer/focal point;
- fit floor/room/selection;
- floor and room-local grids;
- room reference axes and centerlines;
- guides/smart guides;
- semantic snapping;
- exact numeric edits;
- associative dimensions;
- dynamic distances;
- doors/windows/openings;
- arbitrary polygon rooms;
- undo/redo;
- copy/repeat/typical floor workflows.

## 9. Surface editing

Plan, floor, ceiling, walls and feature patches are views of one spatial model.

Surface navigation uses explicit adjacency. Crossing/clicking a valid edge activates the adjacent surface.

Routing remains continuous across a valid surface transition and preserves the exact physical world point.

## 10. Shared engineering model

Shared typed concepts include entity, port, connection, assignment, requirement, capability, route and evidence.

Discipline-specific engineering properties remain strongly typed in discipline modules.

A physical device may participate in several networks through typed ports without duplication.

## 11. Physical routing

Physical routing is represented explicitly:

```text
Run
-> Route
   -> RouteNode[]
   -> RouteSegment[]
```

Route segments may reference concrete surface patches, laying methods and physical channels.

Length is derived from route geometry plus explicit reserve/termination allowances; synthetic manually maintained total length is not authoritative.

## 12. Electrical module

Initial production vertical includes:

- loads;
- circuits;
- design current;
- cable requirements/sizing;
- voltage-drop calculations;
- protection requirements/selection support;
- panel hierarchy and layout;
- source topology;
- cable routes;
- BOM/schedules/reports.

External power systems include grid, generator, UPS, battery, solar/inverter and ATS concepts.

## 13. ELV modules

Typed future/parallel modules include CCTV, LAN/Wi-Fi, ACS, fire alarm, intrusion, intercom, PA/voice alarm and BMS/automation.

They reuse spatial/routing/equipment infrastructure but own their calculation semantics.

## 14. Catalog and reference data

The system distinguishes:

- canonical engineering reference data;
- discipline reference data;
- manufacturer products;
- price/vendor data;
- project-local overlays/approved equivalents;
- calculated project state.

Reference data supports stable codes, version, lifecycle, provenance and project pinning.

## 15. Solver runtime

Engineering calculations implement versioned solver contracts with declared consumed/produced facts.

The runtime maintains a dependency graph and selectively recalculates affected facts after edits.

Every critical calculation is traceable to its inputs and solver version.

## 16. Constraints and normative rules

Calculation and acceptance are separate concerns.

Normative/jurisdiction profiles are explicit and versioned. Projects pin the profile used at design time.

Findings identify affected entity, rule/profile, evidence and severity.

## 17. Configuration and optimization

The platform supports:

```text
requirements
-> abstract engineering needs
-> catalog candidates
-> solver graph
-> constraints/compliance
-> feasible configurations
-> multi-objective evaluation
-> ranked alternatives
```

Engineer locks and explicit overrides cannot be silently replaced.

## 18. Revisions and evidence

Critical project outputs must be reproducible using:

- project/spatial revision;
- catalog edition;
- normative profile version;
- solver versions;
- input snapshot/fingerprint;
- configuration/evaluation evidence.

## 19. Deliverables

Target outputs include:

- technical plans/elevations;
- topology/single-line diagrams;
- cable/circuit/panel/rack schedules;
- BOM/BOQ;
- cost estimate;
- labels/QR;
- calculation report;
- compliance report;
- PDF;
- spreadsheet export;
- later CAD interchange.

## 20. Local persistence

Structured state is normalized in Drift/SQLite. Heavy binary artifacts remain outside relational tables with metadata references.

`project_id` is the logical local partition key.

## 21. Cloud boundary

Core engineering remains usable offline.

Cloud may provide:

- authentication/subscription;
- sync/backup;
- QR/read-only or authenticated sharing;
- collaboration/audit;
- catalog/price synchronization;
- heavy optimization/AI.

## 22. Source of detailed authority

- Vision: `docs/product/product-vision.md`
- User workflows: `docs/product/user-journeys.md`
- Capability map: `docs/product/target-capabilities.md`
- Architecture: `docs/architecture/README.md`
- Spatial model/editor: `docs/architecture/spatial-platform.md`
- Engineering platform: `docs/architecture/engineering-platform.md`
- Roadmap: `docs/product/roadmap.md`
- Migration/provenance: `docs/migration/electra-to-elecx.md`
