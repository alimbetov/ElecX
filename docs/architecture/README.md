# ElecX Target Architecture

## Architectural thesis

ElecX is a modular, local-first engineering platform centered on a shared spatial model and a verified engineering configuration.

Historical ELV stages are delivery provenance, not runtime architecture.

The target architecture is organized by responsibility:

```text
ElecX
├── Engineering Foundation
├── Spatial Platform
├── Engineering Knowledge
├── Solver Runtime
├── Configuration & Optimization
├── Discipline Modules
├── Physical Design & Deliverables
├── Project / Revision Platform
└── Cloud / Collaboration
```

## Core principles

1. Shared spatial source of truth for every discipline.
2. Integer-millimetre canonical geometry; pixels are presentation only.
3. 2D/2.5D field workflow instead of heavyweight BIM in the first product generations.
4. Local-first calculations and editing; network independence for core engineering.
5. SQLite/Drift is the local operational store; normalized entities, not one giant JSON document.
6. Engineering calculations are pure/testable and isolated from Flutter UI.
7. Typed domain models and typed capability contracts; no generic EAV engineering core.
8. Physical routes are graphs with explicit nodes/segments/transitions.
9. Catalog, norms, calculations and revisions are versioned and reproducible.
10. Solver dependency graph enables selective recalculation.
11. Configuration/optimization proposes feasible alternatives but preserves engineer locks and overrides.
12. Start as a modular monolith. Split services only when an external boundary creates measurable value.

## High-level runtime

```text
Flutter Application
    |
    +-- Auth / Project Hub
    +-- Spatial CAD Editor
    +-- Engineering Workspaces
    +-- Review / Reports
    +-- Local Persistence / Outbox
    |
    +--> Pure Dart / domain packages
          +-- engineering_core
          +-- engineering_model
          +-- spatial_core
          +-- engineering_catalog
          +-- engineering_solver
          +-- engineering_constraints
          +-- engineering_configurator
          +-- engineering_optimizer
          +-- engineering_compliance
          +-- engineering_revision
          +-- engineering_deliverables
          +-- discipline solvers

Optional network
    |
    v
Backend
    +-- auth/subscription
    +-- sync/backup
    +-- project sharing / QR
    +-- collaboration / audit
    +-- catalog/price distribution
    +-- object storage
    +-- optional heavy optimization/AI
```

## Bounded contexts

### Engineering Foundation

Owns stable cross-domain primitives:

- IDs;
- quantities/units;
- intervals;
- canonicalization;
- hashing/fingerprints;
- evidence primitives;
- generic revision metadata.

It must not know what CCTV, a breaker or a fire loop is.

### Spatial Platform

Owns:

- Project/Site/Building/Level/Zone/Space geometry;
- local coordinate frames;
- walls/openings/features;
- room surfaces/patches/edges/adjacency;
- world/local transforms;
- geometric validation;
- viewport-independent geometry operations;
- spatial revisions.

All engineering layers reference this geometry.

### Engineering Knowledge

Owns versioned knowledge:

- canonical reference classes;
- equipment/product catalog;
- capabilities and parameters;
- compatibility;
- calculation profiles;
- normative profiles/rule packs;
- price books/vendor offers;
- project overlay preferences.

### Solver Runtime

Owns:

- solver contract;
- solver registry;
- dependency graph;
- affected-closure computation;
- deterministic execution;
- caches/fingerprints;
- result/evidence envelope.

### Constraints and Compliance

Owns evaluation of whether a candidate state is acceptable:

- physical constraints;
- capacity constraints;
- compatibility;
- project rules;
- normative/jurisdiction rules;
- findings and explainable evidence.

### Configuration & Optimization

Owns:

- requirement normalization;
- abstract component requirements;
- candidate generation;
- catalog resolution;
- constraint propagation;
- configuration evaluation;
- objective scoring;
- Pareto/ranked alternatives;
- engineer locks/overrides.

### Discipline Modules

Contain typed engineering semantics and solvers.

Initial modules:

```text
power
lighting
lan
cctv
acs
fire
layout
energy
```

Future modules can use the same spatial/routing foundation without changing its identity.

### Physical Design & Deliverables

Owns engineering presentation/output models:

- rack/panel/cabinet layout;
- routing views;
- schedules;
- BOM/BOQ;
- calculations/compliance reports;
- drawings and export models.

### Project / Revision Platform

Owns lifecycle:

- projects;
- variants/scenarios;
- draft/frozen/published revisions;
- catalog/norm/profile pinning;
- snapshots;
- replay/evidence;
- invalidation/staleness relationships.

### Cloud / Collaboration

Owns only network-value boundaries. It must not become a prerequisite for offline engineering.

## Source of truth vs projections

Canonical state and read models are separate.

```text
SOURCE OF TRUTH
Project / SpatialModel / EngineeringEntity / Port / Connection / Route /
Requirement / Assignment / Revision / Evidence

        -> projections

PowerProjection
LanProjection
CctvProjection
LayoutProjection
BomProjection
CostProjection
ComplianceProjection
```

A projection may be rebuilt. Canonical source data may not be silently reconstructed from a report or screen-specific table.

## Persistence strategy

Drift/SQLite stores normalized local data. Heavy binary artifacts stay in the filesystem/object storage with metadata references.

`project_id` is the logical partition key for project-scoped access.

JSON is allowed for bounded extensible payloads where schema/version is explicit. It is not a replacement for stable typed relationships.

## Migration rule from Electra

Reuse proven concepts and algorithms, not old stage ownership.

Examples:

```text
ELV4 power work      -> power solvers / topology capabilities
ELV5 discipline work -> CCTV/LAN/ACS/FIRE typed solvers
ELV6 layout work     -> layout/enclosure subsystem
ELV7 normative work  -> constraints/compliance subsystem
ELV8 selection/docs  -> catalog/configurator/deliverables
```

The architecture remains stable while release roadmaps change.
