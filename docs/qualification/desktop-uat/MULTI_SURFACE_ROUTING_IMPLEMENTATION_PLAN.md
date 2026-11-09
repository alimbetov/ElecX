# Multi-Room / Multi-Surface Routing — implementation plan after macOS UAT

Status: **R0 partial implementation**. Based on native UAT dated 2026-11-09.
Do not reclassify any of ROUTE-01…05 as PASS until physically routed
instances are created through production UI and survive Save/Quit/Reopen.

## Audit baseline

- Five rooms, nine hosted equipment objects and one same-room Wall→Ceiling
  route were created through the app. Existing P2 route `route-1` persisted.
- Exact canonical C-01…C-04, qualified wall penetrations and the five
  requested cross-room cable paths were **not** authored.
- Prototypical P2 `circuit-1` is not an authoritative P11 `CircuitId`.
- The boundary construction/transition engine already validates physical
  adjacency, material and thickness. Relaxing its protections would corrupt
  electrical engineering claims.

## R0 — qualified-target discovery, without unsafe commit (implemented)

`PortDrivenCableAuthoring.blockedCrossRoomCableTargets` now identifies
electrically compatible devices in **different rooms** from the currently
bound source port. Discovery is pinned to the P2 mutation revision and
filters incompatible port types. This is read-only; it does not appear in
`compatiblePortDrivenCableTargetsOn`, cannot be snapped/committed, and is
not a substitute for a P11 circuit/physical route.

`CableAuthoringDraftBar` displays the other-room devices and the necessary
canonical adjacency / wall construction / approved passage prerequisites
instead of misleading users with an empty list. A blocked target is
rendered as text, never as an enabled completion action.

Tests verify compatible remote discovery, actual inability to snap/commit,
preservation of the draft, and revision invalidation. **No cross-room
route is claimed to exist.**

## R1 — canonical shared-wall preparation (next blocker)

1. Materialize each shared wall as a stable canonical `BoundaryEdgeId`
   for both incident `SpaceId`s. Actual topological adjacency must
   be proved, not inferred solely from touching rectangle coordinates.
2. Provide a production UI to review wall construction profile,
   material, thickness and any opening/penetration, with stable identities.
3. Use existing `BoundaryConstructionRegistry` and
   `BoundaryConstructionTransitionResolver`; never derive a default
   thickness, fake material or boundary ownership from screen pixels.
4. Test missing wall, mismatched two-sided construction, missing opening,
   stale building revision, and Undo/Redo. Save/Reopen must retain IDs.

Exit: a real wall between Corridor and Living has an explicitly approved
physical passage; deleting/changing the host invalidates affected paths.

## R2 — cross-room physical authoring

1. Keep the port-driven cable draft across a qualified host transition.
   Navigating to the next room must not silently discard or teleport points.
2. Continue through the exact `SurfaceTransitionCandidate` and existing
   `CablePenetrationAuthoring` and physical route committer. Require both
   endpoints, route continuity, wall material/thickness and a durable
   penetration identity before accepting the edit.
3. Reuse host-to-world coordinate transforms and explicit hidden-wall
   length. Do not create a second spatial or cable graph.
4. Keep one atomic mutation for route, penetrations, anchors and
   dependency invalidation. Rejections leave the existing route/draft intact.
5. Test Floor→Wall→Ceiling, ceiling-to-next-room, reverse routing and
   multi-room path over at least two different wall boundaries.

Exit: ROUTE-01 through ROUTE-04 are demonstrated through actual macOS GUI
and round-trip with exact endpoints, penetrations and physical lengths.

## R3 — canonical common-board circuits and branch topology

1. Create P11 canonical C-01…C-04 through the canonical project owner,
   with verified mapping to `DB-01` and compatible device ports.
2. Distinguish physical cables from electrical circuits; multiple loads
   may belong to the same circuit with junctions and separate spans.
3. Reuse `EngineeringGraph` for branches; no extra mutable wiring graph.
   Preserve P2 prototype IDs only as a qualified mapping, never as
   authoritative `CircuitId`.
4. Keep the original `ElectricalCableRoute` identity and segment order;
   specify and qualify segment ID evolution before changing schema v22.
5. Reject duplicate membership, dangling refs, incompatible branches and
   updates after source/graph revision drift.

Exit: ROUTE-05 physically and electrically connects four light loads,
one upstream DB-01, with correct branching and no duplicate loads.

## R4 — viewport, safety and final acceptance

- Render same physical path in Plan/Floor/Wall/Ceiling, including legitimate
  penetration markers and route selection, without widget-per-segment.
- Bind full reviewed `EngineeringProposalDiff` and explicit diagnostic
  reasons to production P12 read-only review. Never enable Apply from
  prototype electrical values or synthetic manufacturer evidence.
- Native user journey: create 5 rooms, DB-01 and 9 loads, 4 P11 circuits,
  ROUTE-01…05; Save, Quit (verified process exit), Reopen, compare every
  stable ID, host, surface transition, passage and electrical owner.
- Adversarial: delete load/board, move wall/endpoint, edit opening,
  incompatible connection, duplicate branch, Undo/Redo, stale proposal.
  Rejected changes must not mutate or corrupt canonical persistence.

Release decision: only a complete, exact-SHA green CI plus native
`macOS Desktop User Journey` can advance status from BLOCKED.
Production Apply is separately gated by full safety acceptance.

## Ownership / release

All work stays in `feat/p12a8-engineering-preview-diff`, PR #32 remains
Draft. The code changes in R0 are non-authorizing UX and discovery only.
No schema, normative safety limits, sqlite3 integrity settings, producer
trust anchors or project mutation semantics were relaxed.
