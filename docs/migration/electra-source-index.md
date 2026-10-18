# Electra Source Specification Index

## Purpose

This index prevents useful engineering work from being lost during the Electra -> ElecX reset.

The listed Electra documents are **source material**, not ElecX authority. Their requirements must be migrated into the ElecX target bounded context, verified against current architecture and covered by new acceptance/qualification tests before old implementation can be retired.

Source repository: `alimbetov/electra`.

## Core product / UX / spatial sources

| Electra source | ElecX destination |
|---|---|
| `docs/product/technical-specification.md` | product vision, target TS, spatial platform |
| `docs/architecture/README.md` | target architecture |
| `docs/product/engineering-workspace-ui.md` | engineering workspace UX |
| `docs/product/ui-ergonomics.md` | workspace/touch/CAD ergonomics |
| `docs/product/development-roadmap.md` | migration provenance only; replaced by ElecX roadmap |
| geometry/editor ADRs including edge-driven surface navigation | spatial platform + CAD implementation ADRs |

## Shared engineering / routing heritage

| Electra source family | ElecX destination |
|---|---|
| ELV1 connectivity/ports/topology contracts | EngineeringEntity / Port / Connection core |
| `elv2-profile-constraints-technical-specification.md` | constraints, engineering profiles, project pinning |
| `elv2-p2-placement-compatibility-contract.md` | placement/compatibility constraints |
| `elv2-p4-atomic-placement-contract.md` | command/invariant design for placement |
| `elv2-p5-revision-impact-contract.md` | revision/dependency invalidation |
| `elv2-p6-explicit-adoption-contract.md` | explicit adoption/engineer decision semantics |
| `elv3-p0-cable-resource-model.md` | route/cable resource model |
| `elv3-p0-electrical-cablerun-migration.md` | electrical route migration fixtures |
| `elv3-p0-physical-channel-model.md` | tray/conduit/pathway physical-channel model |
| `elv3-p0-physical-routing-design-inputs.md` | routing requirements and evidence |
| ELV3 code/implementation contracts | routing/resource qualification fixtures, not package ownership |

## Power topology / electrical

Primary source branch/document family:

- `feat/flutter-elv4-power-topology-design`;
- `docs/product/elv4-authoritative-spec-index.md`;
- `docs/product/elv4-power-topology-design-specification.md`;
- `docs/product/elv4-coordinated-p0-p9-contract.md`;
- `docs/product/elv4-p0-p9-delivery-plan.md`;
- `docs/product/elv4-implementation/**`.

ElecX destination:

```text
power/energy topology
+ electrical solvers
+ source/storage/converter model
+ constraints
+ qualification fixtures
```

Migration policy: preserve validated calculation/topology behavior, replay/evidence patterns and golden scenarios; do not recreate ELV4 as a runtime container.

## CCTV / LAN / ACS / Fire calculations

Primary source branch/document family:

- `feat/flutter-elv5-power-topology-design`;
- `docs/product/elv5-authoritative-spec-index.md`;
- `docs/product/elv5-discipline-calculations-design-specification.md`;
- `docs/product/elv5-p0-p9-delivery-plan.md`;
- `docs/product/elv5-implementation/**`;
- `docs/product/elv-canonical-discipline-model.md`;
- `docs/product/elv-engineering-systems-specification.md`;
- `docs/product/elv-domain-scenario-validation.md`.

ElecX destination:

```text
solvers/cctv
solvers/lan
solvers/acs
solvers/fire
+ shared EngineeringEntity/Port/Route
+ shared catalog/reference data
```

Migration policy: keep discipline mathematics and qualification scenarios typed; move shared geometry/connectivity/persistence concerns into platform contexts.

## Enclosure / rack / cabinet layout

Primary source branch/document family:

- `feat/flutter-elv6-enclosure-layout-design`;
- `docs/product/elv6-authoritative-spec-index.md`;
- `docs/product/elv6-enclosure-layout-design-specification.md`;
- `docs/product/elv6-p0-p9-delivery-plan.md`.

ElecX destination:

```text
engineering_layout
+ catalog capabilities
+ physical constraints
+ configurator feedback loop
```

Migration policy: layout is a consumer of selected equipment and constraints. It can invalidate a candidate and request reselection; it is not a terminal stage.

## Normative / compliance

Primary source branch/document family:

- `feat/flutter-elv7-normative-validation-design`;
- `docs/product/elv7-authoritative-spec-index.md`;
- `docs/product/elv7-normative-validation-design-specification.md`;
- `docs/product/elv7-p0-p9-delivery-plan.md`;
- `docs/product/elv-normative-standards-matrix.md`.

ElecX destination:

```text
engineering_constraints
engineering_compliance
normative profiles / rule packs
```

Migration policy:

- historical matrices are candidate source material, not automatically verified standards data;
- each migrated rule requires provenance, jurisdiction/profile, version/effective dates, explicit inputs/applicability and tests;
- do not claim complete KZ/IEC/EU coverage until independently verified.

## Catalog / reference data

Primary source:

- `docs/product/elv-reference-data-catalogs.md`;
- reference/catalog sections across ELV5–ELV8 design branches.

ElecX destination:

```text
engineering_catalog
├── canonical reference classes
├── discipline reference data
├── manufacturer products
├── compatibility/capabilities
├── price books/vendor offers
└── project overlays
```

Migration policy: retain stable codes/version/provenance/lifecycle concepts; avoid generic EAV as the stable core model.

## Selection / deliverables

Primary source branch/document family:

- `feat/flutter-elv8-deliverables-design`;
- `docs/product/elv8-authoritative-spec-index.md`;
- `docs/product/elv8-deliverables-design-specification.md`;
- `docs/product/elv8-p0-p9-delivery-plan.md`;
- `docs/product/elv8-marking-printing-panel-deliverables-amendment.md`.

ElecX destination is intentionally split:

```text
manufacturer selection
    -> engineering_catalog + engineering_configurator

BOM / schedules / reports / marking / printing
    -> engineering_deliverables
```

This split is important: product selection participates in the engineering feedback loop and must happen before the final deliverable stage when required.

## Reference-data and scenario sources

Also preserve as migration inputs:

- `docs/product/elv-domain-scenario-validation.md`;
- `docs/product/elv-engineering-systems-specification.md`;
- `docs/product/elv-canonical-discipline-model.md`;
- `docs/product/elv-reference-data-catalogs.md`;
- old product acceptance criteria and qualification workflows where they encode actual engineering invariants.

## Migration state vocabulary

Every significant legacy source should eventually be marked with one of:

```text
NOT_REVIEWED
REVIEWED_REUSABLE
REWRITTEN_IN_ELECX
MIGRATION_TEST_CREATED
IMPLEMENTED_EQUIVALENT
SUPERSEDED
REJECTED_WITH_REASON
```

## Completion rule

A legacy area is considered migrated only when:

1. its useful requirements have a named ElecX owner/bounded context;
2. obsolete stage-specific assumptions are removed;
3. code-level contracts are rewritten for the target architecture;
4. accepted engineering behavior has regression/qualification tests;
5. persistence/revision implications are defined;
6. target documentation is authoritative without requiring the reader to understand ELV stage chronology.
