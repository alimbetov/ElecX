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
| Optional physical route reference | Existing `RouteId` |

Existing nonblank opaque values are retained verbatim. A catalog key such as
`link` may occur on multiple components. Its owner is always part of endpoint
equality; concatenation, delimiters, display text, coordinates and list indexes
are not identity formats. New allocation uses the existing `EntityIdFactory`.

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

## P11.2 implementation scope

P11.2 separates the extensible medium/capability contract from the existing
closed `EngineeringConnectionType` enum without breaking P9/P10 callers.

- `EngineeringMedia` is an opaque, case-sensitive value object with initial
  built-ins for AC/DC power, lighting control, dry contact, Ethernet, PoE,
  optical fibre, coax, RS-485, fire loop and security/access bus.
- Custom media identifiers are valid when nonblank; adding a medium does not
  require changing an enum.
- `EngineeringPortCapability` provides extensible semantic capability tags.
  Quantitative parameters remain typed catalog/engineering data rather than
  being encoded into capability strings.
- `EngineeringPortSpec` owns immutable explicit media/capability sets in
  addition to its legacy allowed-connection set.
- `EngineeringGraphConnection` and the transitional legacy edge can carry an
  optional explicit medium.
- When a connection declares a medium, both endpoint ports must explicitly
  support it; absence or mismatch fails closed. The graph never infers or
  silently substitutes a medium.
- A null connection medium preserves the existing P9/P10 graph contract until
  the persistence/migration lifecycle is intentionally extended in P11.8.
- Logical medium remains independent from optional `RouteId`; P11.2 does not
  introduce physical routing ownership.

Qualification target: `test/p11_media_capability_foundation_test.dart`, P11.1
regressions, existing graph/P9/P10 suites and full repository
`quality`/`verification` on the P11.2 exact SHA. Implementation is not accepted
until those checks are green.

## Remaining P11 packages

| Package | Planned result |
| --- | --- |
| P11.3 | Circuit/loop/group abstractions |
| P11.4 | Generalized graph invariants and compatibility validation |
| P11.5 | Cross-discipline extension contract |
| P11.6 | Multiple source/supply topology |
| P11.7 | Typed dependency relations for P15 impact traversal |
| P11.8 | Graph diff/fingerprint/persistence and shared-owner lifecycle |
| P11.9 | Equipment Catalog adapters |
| P11.10 | Qualification corpus and full hard-gate closure |

The P10 v19 project document schema remains unchanged in P11.1/P11.2. Graph
persistence and production mutation integration remain explicit P11.8 work. This
foundation does not constitute acceptance of all P11 and does not generate P12
engineering content.
