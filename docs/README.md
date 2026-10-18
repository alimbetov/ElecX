# ElecX Documentation Authority

ElecX documentation is organized around the target product, not around historical ELV delivery stages.

## Authority order

When documents conflict, use this order:

1. `docs/product/product-vision.md` — what ElecX is and what user problem it solves.
2. `docs/product/user-journeys.md` — the primary engineer workflows the product must make excellent.
3. `docs/product/target-capabilities.md` — target functional capability map.
4. `docs/architecture/README.md` — target system architecture and bounded contexts.
5. `docs/architecture/spatial-platform.md` — spatial/CAD model and surface navigation contract.
6. `docs/architecture/engineering-platform.md` — engineering model, solvers, catalog, constraints and configuration.
7. `docs/product/roadmap.md` — implementation sequence and release waves.
8. Feature-level implementation specifications and ADRs.
9. `docs/migration/electra-to-elecx.md` — provenance and migration mapping from the former `electra` repository.

Historical Electra ELV1–ELV8 documents are design inputs and provenance only. They do not define ElecX runtime boundaries.

## Product rule

ElecX is an engineer-first, local-first, spatial engineering application. The central artifact is a verified engineering configuration placed in a shared spatial model.

```text
Engineer intent
    -> Project / Site / Building / Level / Space
    -> Spatial model
    -> Engineering objects and routes
    -> Calculations / constraints / catalog candidates
    -> Verified configuration
    -> Drawings / BOM / reports / field workflow
```

## Documentation language

Source code, domain terms, schemas, APIs and technical documentation are English-first. User-facing text is localization-ready. Russian, Kazakh and other UI languages are presentation concerns and must not leak into stable technical identifiers.

## Design principles

- user workflow before internal stage numbering;
- one shared spatial source of truth;
- exact metric geometry in integer millimetres;
- 2D/2.5D interaction instead of heavyweight BIM for field work;
- continuous navigation across floor, ceiling, walls and piecewise-planar features;
- explicit physical routing, not synthetic cable-length fields;
- typed engineering semantics instead of generic key/value models;
- calculations isolated from UI and network availability;
- catalog, normative profiles and solver versions are versioned and traceable;
- revisions, evidence and reproducibility are first-class;
- modular monolith first; cloud services only where they create user value.

## Current implementation focus

The current codebase implements the first spatial-editor vertical slice: quick local PIN unlock, project hub, project/site/building/level/space hierarchy, room-local grids and reference frames, surface-centric wall/floor/ceiling navigation, openings, dimensions and multi-surface route foundations.

The next engineering priority is not ELV stage expansion. It is to complete the CAD-grade spatial foundation, then attach engineering layers to it.
