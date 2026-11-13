# Multi-surface routing architecture contract (before implementation)

Status: proposed acceptance contract; not an implemented schema or second graph. Baseline 9f15d985. Existing persistence/safety ownership must be preserved.

## Reuse existing owners

`EngineeringGraph` owns canonical electrical connectivity and P11 circuit membership. Prototype `CircuitCableRegistry`/P2 bundles must not silently become canonical circuits. `ElectricalCableRoute` owns source/target port references and ordered physical surface segments, penetrations and vertical core legs. `SurfaceTransitionResolver`, `SurfaceTransitionGraph`, `SurfaceTransitionNavigator`, `BoundaryConstructionTransitionResolver` and `PhysicalCableRouteCommitter` already provide geometry/validation/atomic commit concepts. Extend these rather than introduce another cable graph or coordinate system. Continue Canvas/Impeller rendering, not per-segment widgets.

## Required increments and invariants

1. Canonical circuit authoring UI: create C-01…04, choose one upstream board across project scope, assign multiple loads and display canonical membership separately from prototype groups. Reject incompatible circuits/duplicate membership through existing validation, with actionable diagnostics.
2. Construction authoring: produce canonical boundary hosts/edge IDs, actual adjacency and openings/penetrations with thickness, geometry and permissions. A touching rectangle or crossed line is never proof of legal passage. Source and destination spaces must resolve to one shared qualified transition. Preserve identity through wall edits; block/invalidate affected routes atomically.
3. Physical route authoring: explicit port-bound start/end; show allowed next surfaces/passages, preserve draft with meaningful warning on unsupported navigation. Same-room-only guard may be relaxed only after cross-space commit validates canonical topology, physical continuity and host mappings together.
4. Segment identity: review compatibility/version policy for stable segment identifiers and predecessor/successor association; existing segments lack IDs and may lack anchor IDs. Do not casually bump/change P11/v22 serialization. Define deterministic migration/round-trip policy and owner approval before implementation. Circuit ownership must resolve via canonical cable/route references, not duplicated mutable CircuitId fields.
5. Branching: junction nodes/ports and canonical connectivity must represent branch points; physical cable spans reference those same electrical owners. Define whether shared trunk is a distinct cable or shared installation path; avoid duplicating current/load across branches. Binary routes can remain spans but cannot substitute for full junction topology.
6. Geometry: mm locally, existing host-to-world transforms as sole mapping. Commit must prove endpoint anchoring, adjacent segment common world point within documented tolerance, legal boundary host/penetration and length including hidden transitions exactly once. Renderer projects the same route on Plan/Floor/Wall/Ceiling and supports route/board/circuit selection.
7. Dependency lifecycle: delete load/board, move host, edit wall/opening, reroute and undo/redo must transact references, physical objects, sizing evidence and canonical revision together. Unsupported operation blocks with explanation. Test failure rollback and orphan checks.
8. P12 source: connect authoritative proposal/evidence snapshot to production source. Validate project/version/fingerprints on read and transactional Apply recheck; stale/foreign snapshots remain blocked. Full selected/unresolved review must not infer acceptance from prototype parameters.

## Exit tests

Native UI authoring for all five requested routes; same board and exact membership; real qualified passages; four-light junction topology; stable identities and common-world continuity before/after Quit/reopen; route lengths and all surface projections; delete/move/wall edit/duplicate/incompatible/undo adversarial cases; authoritative P12 stale diagnostics. Keep unit/widget/native integration evidence distinct. Approval of this contract precedes large missing-model implementation; this UAT makes no architecture-completion claim.
