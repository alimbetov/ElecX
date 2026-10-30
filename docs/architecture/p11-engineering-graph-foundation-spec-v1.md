# P11 — Generalized EngineeringGraph foundation

Date: 2026-10-30
Branch: `feat/p11-engineering-graph-foundation`
Base: accepted P10 main `06bb2dc8938871082c50a4dee0a25724788af6ff`
Program contract: [P9–P17 roadmap](elecx-p9-p17-execution-roadmap-v1.md), §7.

## Ownership and identity contract

P11 extends the existing `CanonicalEngineeringGraph`. Its immutable components,
connections and derived indexes express logical connectivity. Canonical project
mutation, ID allocation, history and persistence retain their existing owners.
This foundation introduces no additional project store or persistence boundary.

| Logical role | Existing identity / reference |
| --- | --- |
| Node/component | `ComponentId` |
| Component-local port | `PortId` |
| Complete endpoint | `EngineeringPortRef(ComponentId, PortId)` |
| Logical edge | `EngineeringConnectionId` |
| Logical circuit | `CircuitId` |
| Logical loop | `LoopId` |
| Semantic group | `EngineeringGroupId` |
| Logical supply source | `EngineeringSupplySourceId` |
| Optional architectural supply provenance | Existing `ServiceEntryId` |
| Optional physical route reference | Existing `RouteId` |

Existing nonblank opaque values are retained verbatim. Display text, coordinates,
list indexes and concatenated pseudo-identities are not durable identity formats.

## P11.1 delivered scope

- Existing graph component/connection identities remain authoritative.
- Scoped typed endpoint references and immutable port specs.
- Component/edge lookup, adjacency indexes and directed traversal.
- Duplicate/dangling/self-port/direction/media violations fail closed.
- Logical identity is independent from placement and physical routing.

Qualification: exact SHA
`7d6e39c1da0a45c63d5533fc53317b744191fd09`, Flutter run `40997724850`,
`quality` and `verification` green including full tests.

## P11.2 delivered scope

- Extensible `EngineeringMedia` and `EngineeringPortCapability` value objects.
- Explicit immutable port media/capability sets.
- Optional explicit connection media with endpoint compatibility validation.
- Null media preserves P9/P10 migration compatibility until P11.8.
- Logical medium remains independent from optional `RouteId`.

Qualification: exact SHA
`11c74296ce4f013a6887b84ab1a1bad27df70275`, Flutter run `41000369674`,
full repository gates green.

## P11.3 delivered scope

- `EngineeringCircuit`, `EngineeringLoop` and `EngineeringGroup` abstractions.
- `CanonicalEngineeringTopology` as an immutable validated/indexed view over the
  authoritative graph, not a second project store.
- Circuit ownership, loop closure/continuity and group referential integrity.
- Legacy per-edge circuit evidence remains compatible and conflicts fail closed.

Qualification: exact SHA
`87591b24068826a03aa1276930ca928822ff7f75`, Flutter run `41001655240`,
full repository gates green.

## P11.4 delivered scope

P11.4 adds explicit versioned compatibility/invariant validation without turning
product preferences into hidden engineering rules.

- Exact directed `EngineeringConnectionCompatibilityRule` contracts.
- Versioned immutable `EngineeringCompatibilityProfile` with duplicate and
  ambiguous legacy-media rules rejected.
- Optional strict gates for explicit media, compatibility rule coverage and
  resolved circuit membership.
- Custom `EngineeringMedia` values require no enum fork.
- Foreign/stale topology views are rejected by graph identity.
- `EngineeringGraphValidationReport.requireValid()` provides fail-closed use.
- Base endpoint/direction/media checks remain owned by the canonical graph.

Qualification: `test/p11_graph_invariant_validation_test.dart`, P11.1–P11.3
regressions and full repository gates are green on exact SHA
`d897df2433cda33da9645f484dd8971ea3030276` (Flutter run `41002831586`).

## P11.5 delivered scope

P11.5 makes discipline and system classification extensible while preserving the
legacy enum families required by existing P9/P10 and catalog APIs.

- `EngineeringDisciplineKey` and `EngineeringSystemKey` are opaque stable value
  objects with explicit built-in `core.*` keys.
- `EngineeringGraphComponent` carries both its legacy discipline/system family
  and extensible discipline/system keys. Existing callers receive deterministic
  built-in keys automatically.
- `EngineeringGraphConnection`, `EngineeringCircuit` and `EngineeringLoop` carry
  an extensible `systemKey`; custom systems sharing one legacy enum family cannot
  be mixed accidentally.
- `EngineeringExtensionContract` declares versioned custom disciplines/systems,
  supported media and supported port capabilities. It owns metadata only.
- `EngineeringExtensionRegistry` validates custom keys against the same canonical
  graph; it does not own nodes, edges, topology or persistence.
- Built-in keys cannot be redeclared. Cross-contract discipline/system key
  collisions fail closed.
- Unknown custom keys, legacy-family mismatch, system/discipline mismatch and
  undeclared custom media/capabilities are explicit validation failures.
- P11.4 compatibility rules also include extensible system keys, so two custom
  systems sharing a legacy fallback family remain distinguishable.
- Legacy graph adapters preserve their prior API and default to built-in keys.
- No project document schema change is introduced; persistence remains P11.8.

Qualification: `test/p11_cross_discipline_extension_test.dart`, P11.1–P11.4
regressions and full repository gates are green on exact SHA
`279edbb29ce7ffd11053f45e0263bea1e1a28c45` (Flutter run `41004212214`).

## P11.6 implementation scope

P11.6 adds multiple-source topology without introducing a second graph owner or
premature electrical calculations.

- `EngineeringSupplySourceId` is a stable opaque identity for a logical source.
- `EngineeringSupplyRoleKey` is extensible; built-in primary/alternate/emergency/
  storage roles are semantic metadata, not automatic transfer policy.
- `EngineeringSupplySource` binds a source to an existing canonical
  `EngineeringPortRef`, legacy/extensible system classification and optional
  explicit medium.
- Optional `ServiceEntryId` links a source to the existing P10 architectural
  service-anchor identity without taking ownership of that anchor.
- `EngineeringCircuitSupply` supports one or more candidate sources per circuit.
- `CanonicalEngineeringSupplyTopology` is an immutable validated/indexed view over
  `CanonicalEngineeringTopology`, never a new project store.
- Duplicate/dangling sources, circuits and service-entry links fail closed.
- A source endpoint must be output/bidirectional, have a compatible outgoing edge
  and match the source system/media evidence.
- Every assigned source must match the target circuit system and be able to reach
  every circuit edge through directed connections of the same extensible system.
- One source may serve multiple circuits and one circuit may have multiple sources.
- Source selection, transfer switching, load flow, protection, cable sizing and
  equipment sizing remain outside P11.6 and are not inferred by this topology.
- No project document schema change is introduced; persistence remains P11.8.

Qualification target: `test/p11_multiple_supply_topology_test.dart`, all prior P11
suites and full repository `quality`/`verification` on the exact P11.6 SHA. P11.6
is not accepted until all of those checks are green.

## Remaining P11 packages

| Package | Planned result |
| --- | --- |
| P11.7 | Typed dependency relations for P15 impact traversal |
| P11.8 | Graph diff/fingerprint/persistence and shared-owner lifecycle |
| P11.9 | Equipment Catalog adapters |
| P11.10 | Qualification corpus and full hard-gate closure |

The P10 v19 project document schema remains unchanged in P11.1–P11.6. Graph
persistence and production mutation integration remain explicit P11.8 work. This
foundation does not constitute acceptance of all P11 and does not generate P12
engineering content.
