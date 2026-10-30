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
values fail closed. Port capability sets and capability/component port lists
are immutable snapshots, so external edits cannot invalidate a validated graph.
P9 canonical projection uses the typed constructor with its existing allocated
port identities; the exact string values and fingerprint representation remain.

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
`quality`/`verification` on the implementation SHA. A local analyzer/probe pass
does not replace CI acceptance.

## Remaining P11 packages

| Package | Planned result |
| --- | --- |
| P11.2 | Extensible media and capability model |
| P11.3 | Circuit/loop/group abstractions |
| P11.4 | Generalized graph invariants and compatibility validation |
| P11.5 | Cross-discipline extension contract |
| P11.6 | Multiple source/supply topology |
| P11.7 | Typed dependency relations for P15 impact traversal |
| P11.8 | Graph diff/fingerprint/persistence and shared-owner lifecycle |
| P11.9 | Equipment Catalog adapters |
| P11.10 | Qualification corpus and full hard-gate closure |

The P10 v19 project document schema is unchanged in P11.1. Graph persistence and
production mutation integration remain explicit P11.8 work. This foundation
does not constitute acceptance of all P11 or generate P12 engineering content.
