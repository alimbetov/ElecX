# ElecX

ElecX is a professional local-first engineering design and configuration application for electricians and adjacent building-system engineers.

The product starts from the engineer's real workflow rather than from internal delivery stages:

```text
Project
-> Site
-> Building
-> Level
-> Zone / Space
-> Spatial CAD editor
-> Engineering design
-> Validation / configuration
-> Drawings / BOM / reports
```

## Product direction

ElecX combines a purpose-built CAD-like 2D/2.5D editor with typed engineering calculations, equipment/reference catalogs, normative validation, automatic configuration and professional deliverables.

The target is not a collection of calculators and not a miniature generic CAD clone. The central artifact is a verified engineering configuration placed in one shared spatial model.

Primary product modes:

```text
BUILD | DESIGN | REVIEW
```

- **BUILD** — site/building/level/room geometry, walls, openings, surfaces, dimensions and guides.
- **DESIGN** — engineering equipment, ports/connections, circuits/networks and physical routes.
- **REVIEW** — calculations, compliance findings, configuration alternatives, BOM, drawings and publication.

Electrical is the first commercial vertical. LAN, CCTV, access control, fire alarm, automation and other engineering layers reuse the same geometry and routing foundation.

## Spatial editor

The spatial editor is the current implementation focus.

ElecX treats plan, floor, ceiling and wall elevations as views of one physical model. A cable route can continue across adjacent surfaces while preserving the same physical transition point.

Current foundation includes:

- local four-digit quick-unlock prototype;
- project hub;
- `Project -> Site -> Building -> Level -> Space` hierarchy;
- integer-millimetre geometry;
- room/floor grids and room-local reference frame;
- automatic room centerlines;
- derived wall/floor/ceiling surfaces;
- doors/windows in plan and wall elevation;
- edge-driven navigation between adjacent surfaces;
- multi-surface route transitions and accumulated route length;
- CAD-like dimensions and live distances around an active route point;
- basic zoom and technical three-panel workspace.

The next editor priorities are a reusable viewport controller, zoom-around-cursor/pan/fit, semantic snap engine, arbitrary polygon editing, persistent guides and full piecewise-planar surface topology.

## Target architecture

```text
ElecX
├── Engineering Foundation
├── Spatial Platform
├── Engineering Knowledge / Catalog
├── Solver Runtime
├── Constraints / Compliance
├── Configuration & Optimization
├── Discipline Modules
├── Physical Design & Deliverables
├── Project / Revision Platform
└── Cloud / Collaboration
```

Historical `ELV1..ELV8` work from the former `electra` repository is retained as design provenance and migration input. It does **not** define ElecX runtime boundaries.

## Documentation

Start here:

1. [Documentation authority](docs/README.md)
2. [Product vision](docs/product/product-vision.md)
3. [Five primary user journeys](docs/product/user-journeys.md)
4. [Target capability map](docs/product/target-capabilities.md)
5. [Technical specification](docs/product/technical-specification.md)
6. [Target architecture](docs/architecture/README.md)
7. [Spatial platform](docs/architecture/spatial-platform.md)
8. [Engineering platform](docs/architecture/engineering-platform.md)
9. [Engineering workspace UX](docs/product/engineering-workspace-ui.md)
10. [Target roadmap](docs/product/roadmap.md)
11. [Acceptance criteria](docs/product/acceptance-criteria.md)
12. [Electra -> ElecX migration map](docs/migration/electra-to-elecx.md)

## Engineering principles

- local-first and offline-capable;
- shared spatial source of truth;
- exact metric geometry independent of screen pixels;
- 2D/2.5D field workflow instead of heavyweight BIM for ordinary work;
- explicit physical routing topology;
- typed engineering semantics instead of generic key/value models;
- calculations isolated from Flutter UI;
- versioned catalog/norm/solver context;
- selective dependency-driven recalculation;
- reproducible revisions and evidence;
- modular monolith first;
- cloud only where it creates user value.

## Development

`main` remains the integration branch. Feature work is developed in focused branches with analyzer/tests and explicit acceptance criteria.
