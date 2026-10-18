# Migration from Electra to ElecX

## Purpose

ElecX is a product/architecture reset, not a rejection of the engineering work already completed in `alimbetov/electra`.

The migration rule is:

> Reuse validated concepts, algorithms, evidence patterns and tests. Do not preserve historical ELV stage ownership when it conflicts with the target product architecture.

## What ElecX inherits conceptually

The former Electra repository established several durable principles that remain valid:

- local-first Flutter engineering application;
- exact metric geometry;
- 2D/2.5D room/surface model;
- edge-driven surface navigation;
- explicit cable/routing topology;
- typed ports/connections;
- discipline-specific engineering semantics over shared geometry;
- versioned catalogs/profiles;
- revision/evidence/hash/fingerprint patterns;
- deterministic qualification tests;
- layout, normative, selection and deliverable requirements.

These are target-product capabilities in ElecX, not reasons to reproduce the old package/stage structure.

## What is not migrated as architecture

Do not recreate the runtime as:

```text
ELV4 -> ELV5 -> ELV6 -> ELV7 -> ELV8
```

Do not make stage-specific aggregates the only source of truth when the fact is fundamentally shared.

Avoid growth patterns such as one new discipline-specific persistence hierarchy for every new calculation family when the real invariant belongs to shared engineering model, solver evidence or projection infrastructure.

Historical exact-SHA gates, authority chains and audit records remain useful provenance in the old repository but are not copied wholesale into the new target documentation.

## Mapping of major historical tracks

| Electra heritage | ElecX destination |
|---|---|
| FL geometry/editor work | Spatial Platform / CAD editor |
| surface navigation ADRs | `docs/architecture/spatial-platform.md` + editor implementation |
| cable routing / CableRun | Engineering routing core |
| ELV1 ports/connections/topology | EngineeringEntity / Port / Connection core |
| ELV2 profiles/placement/revision impact | Knowledge + constraints + revision impact |
| ELV3 cable allocation/routing/carriers | Routing/channel subsystem and typed resource constraints |
| ELV4 power topology | Power/energy topology and electrical solvers |
| ELV5 CCTV/LAN/ACS/FIRE calculations | Discipline solver packages |
| ELV6 rack/cabinet/enclosure layout | Layout/enclosure subsystem |
| ELV7 normative profiles | Compliance/constraint engine |
| ELV8 manufacturer selection | Catalog + configurator |
| ELV8 BOM/reports/deliverables | Deliverables subsystem |

## Spatial model migration

The old direction already recognized:

```text
Room
  -> RoomSurface[]
      -> SurfacePatch[]
          -> SurfaceEdge[]
  -> SpatialFeature[]
```

ElecX keeps this target and introduces it progressively.

Current code begins with derived room surfaces from polygon edges. The migration path is:

```text
simple room polygon
-> concrete wall/floor/ceiling identities
-> explicit surface edges and adjacency
-> persisted RoomSurface
-> persisted SurfacePatch
-> piecewise-planar features
```

This avoids blocking the first editor on the full future geometry model while preserving a compatible destination.

## Editor migration

Retain:

- canvas-first workflow;
- local room frames;
- exact millimetres;
- edge-driven navigation;
- continuous routing across surfaces;
- contextual engineering panels;
- dry technical visual style;
- field/touch ergonomics.

Improve in ElecX:

- make `Project -> Site -> Building -> Level -> Zone/Space` explicit;
- make project creation/user journeys primary product documentation;
- introduce a dedicated viewport subsystem;
- make local room grids/centerlines a first-class UX feature;
- add CAD-grade snap/associative dimensions before discipline expansion;
- keep BUILD / DESIGN / REVIEW as the simple top-level mental model.

## Routing migration

Retain the principle that calculated cable length is derived from physical route geometry.

Target:

```text
Circuit/Network
  -> Run
      -> Route
          -> RouteNode[]
          -> RouteSegment[]
```

Surface transitions preserve exact world points. Conduit/tray/pathway sharing is modeled as physical infrastructure, not as a boolean flag on a cable.

## Engineering calculation migration

Do not port calculation services as isolated stage pipelines if they can become solvers.

Migration shape:

```text
old calculation process
-> identify typed inputs/outputs
-> identify shared vs discipline-specific facts
-> define solver ID/version
-> declare consumes/produces facts
-> preserve/port golden tests
-> wrap evidence/fingerprint
-> register in dependency graph
```

Only after result equivalence is proven should old code be retired.

## Catalog/reference-data migration

The former reference-data design correctly separated:

1. common engineering data;
2. discipline reference data;
3. manufacturer catalog data;
4. project overrides.

ElecX keeps this separation and adds price/vendor availability as a distinct commercial layer.

Do not merge all catalog properties into a generic untyped table.

## Normative migration

Historical normative matrices and ELV7 design are source material, not automatically authoritative law/standards data.

Before importing a rule into ElecX:

- verify the source;
- record provenance;
- define jurisdiction/profile;
- define effective/validity dates where relevant;
- express rule inputs and applicability explicitly;
- add qualification tests;
- avoid claims of complete national coverage unless the evidence supports them.

## Revision/evidence migration

Strong Electra primitives should be preserved:

- canonical representation;
- fingerprints/hashes;
- solver/calculation version identity;
- revision-scoped results;
- immutable frozen/published evidence where appropriate;
- replay/rebuild checks;
- exact acceptance tests.

ElecX should simplify ownership while keeping reproducibility.

## Testing migration

Preferred strategy:

```text
old golden scenario
-> extract domain fixture
-> execute old accepted behavior where possible
-> execute new ElecX solver/domain behavior
-> compare engineering result and evidence
-> retain as migration qualification test
```

Important historical electrical/ELV fixtures should become long-lived regression cases instead of being copied as implementation-stage narratives.

## Documentation migration policy

Documents copied into ElecX must be rewritten into one of these categories:

- product target;
- architecture contract;
- ADR;
- implementation specification;
- qualification/acceptance;
- migration/provenance.

Do not copy historical remediation documents into the authoritative product tree merely to preserve volume.

## Source documents used to establish the ElecX target

Primary source material from the former repository includes:

- `docs/product/technical-specification.md`;
- `docs/architecture/README.md`;
- `docs/product/engineering-workspace-ui.md`;
- `docs/product/development-roadmap.md`;
- `docs/product/elv-reference-data-catalogs.md`;
- ELV4 power-topology design/implementation evidence;
- ELV5 discipline-calculation design;
- ELV6 enclosure/layout design;
- ELV7 normative-validation design;
- ELV8 selection/deliverables design;
- geometry/routing/editor ADRs and qualification tests.

The old repository remains the provenance archive while ElecX documentation becomes the authoritative description of the new target product.
