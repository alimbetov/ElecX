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
| Optional physical route reference | Existing `RouteId` |

Existing nonblank opaque values are retained verbatim. A catalog key such as
`link` may occur on multiple components. Its owner is always part of endpoint
equality; concatenation, delimiters, display text, coordinates and list indexes
are not identity formats. New allocation uses the existing application/domain
identity boundary.

`EngineeringPortSpec.identified` accepts `PortId`. The string constructor and
`id` getter preserve the existing catalog/serialization interface. Blank port
values fail closed. Port collections, allowed connection sets, explicit media
sets and capability sets are immutable snapshots, so external edits cannot
invalidate a validated graph. P9 canonical projection uses the typed constructor
with its existing allocated port identities; existing string values and legacy
fingerprint representation remain unchanged.

## P11.1 delivered scope

- Existing graph component/connection identities remain authoritative.
- Scoped, value-based endpoint references and typed port specs.
- Component, endpoint and edge lookup plus incoming/outgoing adjacency indexes.
- Directed traversal uses indexed adjacency and a queue; branches, cycles and
  isolated nodes retain the existing reachability semantics.
- Duplicate IDs, unknown component/port endpoints, self-port loops and existing
  media/direction incompatibilities continue to fail closed.
- Logical edges are valid without physical routes. Placement/rerouting retain
  logical identity. All indexes are derived from the graph's immutable inputs.

Qualification: `test/p11_graph_identity_foundation_test.dart`, existing canonical
graph/identity suites, P9 projection/fingerprint regressions and full repository
`quality`/`verification` are green on exact implementation SHA
`7d6e39c1da0a45c63d5533fc53317b744191fd09` (Flutter run `40997724850`).

## P11.2 delivered scope

P11.2 separates the extensible medium/capability contract from the existing
closed `EngineeringConnectionType` enum without breaking P9/P10 callers.

- `EngineeringMedia` is an opaque, case-sensitive value object with initial
  built-ins for AC/DC power, lighting control, dry contact, Ethernet, PoE,
  optical fibre, coax, RS-485, fire loop and security/access bus.
- Custom media identifiers are valid when nonblank; adding a medium does not
  require changing an enum.
- `EngineeringPortCapability` provides extensible semantic capability tags.
- `EngineeringPortSpec` owns immutable explicit media/capability sets.
- Connections can carry an optional explicit medium.
- Explicit media must be supported by both endpoints; mismatch fails closed.
- Null media preserves the legacy P9/P10 contract until P11.8.
- Logical medium remains independent from optional `RouteId`.

Qualification: `test/p11_media_capability_foundation_test.dart`, P11.1
regressions and full repository gates are green on exact SHA
`11c74296ce4f013a6887b84ab1a1bad27df70275` (Flutter run `41000369674`).

## P11.3 delivered scope

P11.3 adds canonical logical circuit, loop and group abstractions without
replacing the graph, cable registry or electrical synthesis models.

- `EngineeringCircuit` uses `CircuitId` and immutable edge membership.
- `EngineeringLoop` uses `LoopId` and ordered closed traversal membership.
- `EngineeringGroup` uses `EngineeringGroupId` and extensible `semanticTypeId`.
- `CanonicalEngineeringTopology` is an immutable validated/indexed view over the
  authoritative graph, not a second project store.
- One connection cannot belong to two circuits in one topology.
- Circuit system class and optional explicit medium must match member edges.
- Existing per-edge `circuitId` evidence is respected and conflicts fail closed.
- Bound loops must be continuous, closed and fully contained by their circuit.
- Group references are referentially validated and dangling members fail closed.
- P11.3 owns no load calculation, protection, routing or persistence.

Qualification: `test/p11_circuit_loop_group_foundation_test.dart`, P11.1/P11.2
regressions and full repository gates are green on exact SHA
`87591b24068826a03aa1276930ca928822ff7f75` (Flutter run `41001655240`).

## P11.4 implementation scope

P11.4 adds explicit, versioned compatibility and invariant validation without
turning product preferences into hidden engineering rules.

- `EngineeringConnectionCompatibilityRule` describes one exact directed contract
  across source system class, target system class, edge system class, legacy
  connection type and optional extensible medium.
- `EngineeringCompatibilityProfile` is explicit and versioned. Rule ids and
  compatibility signatures must be unique; ambiguous duplicate contracts fail
  closed.
- Custom media are validated through `EngineeringMedia` and require no enum fork.
- `EngineeringGraphValidationOptions` controls migration strictness. Legacy
  projects remain readable by default, while production flows may require an
  explicit compatibility rule, explicit media and resolved circuit membership.
- `EngineeringGraphInvariantValidator` returns an immutable validation report and
  can fail closed through `requireValid()`.
- Strict circuit resolution requires canonical P11.3 topology evidence for any
  persisted per-edge `circuitId`.
- A topology supplied to validation must reference the exact authoritative graph
  instance; a foreign/stale topology view is rejected.
- Base endpoint existence, direction and port-media compatibility remain enforced
  by `CanonicalEngineeringGraph`; P11.4 does not duplicate graph ownership.
- P11.4 does not infer normative compliance, calculate engineering values, select
  equipment or introduce persistence changes.

Qualification target: `test/p11_graph_invariant_validation_test.dart`, P11.1–P11.3
regressions and full repository `quality`/`verification` on the exact P11.4 SHA.
P11.4 is not accepted until those checks are green.

## Remaining P11 packages

| Package | Planned result |
| --- | --- |
| P11.5 | Cross-discipline extension contract |
| P11.6 | Multiple source/supply topology |
| P11.7 | Typed dependency relations for P15 impact traversal |
| P11.8 | Graph diff/fingerprint/persistence and shared-owner lifecycle |
| P11.9 | Equipment Catalog adapters |
| P11.10 | Qualification corpus and full hard-gate closure |

The P10 v19 project document schema remains unchanged in P11.1–P11.4. Graph
persistence and production mutation integration remain explicit P11.8 work. This
foundation does not constitute acceptance of all P11 and does not generate P12
engineering content.
