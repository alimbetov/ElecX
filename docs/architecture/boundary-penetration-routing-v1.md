# Boundary penetration routing v1

## Status

Normative architecture contract for `feat/project-structure-authoring`.

## Core invariant

A cable route MUST NOT teleport through a physical building construction.

Whenever a logical route crosses a wall or slab, the crossing is represented by one `BoundaryPenetration` with two paired anchors:

- `entryAnchor` on the source surface;
- `exitAnchor` on the opposite surface;
- one shared `penetrationId`;
- one shared `routeId`.

The `exitAnchor` is the canonical continuation start shown on the reverse surface. Continuing from it extends the same logical route; it does not create a second cable.

## Physical geometry

Every committed penetration has:

- `hostKind`: `wall` or `slab`;
- `hostThicknessMm > 0`;
- `pathLengthMm >= hostThicknessMm`;
- optional `materialId`.

For a normal perpendicular penetration, `pathLengthMm == hostThicknessMm`. The model deliberately keeps the two values separate so an angled penetration can later contribute its real path length without changing identity or persistence semantics.

The hidden route length inside a wall/slab MUST be included in total cable route length through `BoundaryPenetration.routeLengthContributionMm`.

## Wall crossing

A cross-room transition may be discovered geometrically, but it MUST remain only a candidate until physical construction thickness is resolved. Committing it creates the penetration and both anchors atomically.

A missing wall thickness is fail-closed: the transition may be displayed as requiring a penetration, but `createPenetration` cannot succeed until a positive thickness is supplied.

## Cross-level crossing

Floor and ceiling surfaces on different levels are not directly adjacent. A transition between them MUST cross a slab and therefore MUST use `SurfaceTransitionGraph.levelPenetration` and a `BoundaryPenetrationHostKind.slab` penetration.

Upward continuation is:

`lower level ceiling -> slab penetration -> upper level floor`

Downward continuation is:

`upper level floor -> slab penetration -> lower level ceiling`

The same plan coordinate is projected into each room-local surface coordinate system.

## Reverse-surface continuation marker

Presentation layers should render `BoundaryPenetration.exitAnchor` as a continuation marker on the opposite surface. The marker must retain:

- route identity;
- penetration identity;
- exact surface-local position.

Selecting that marker starts or resumes drawing from the anchor using the existing `routeId`.

The domain contract intentionally does not prescribe iconography. Desktop, tablet and mobile presentations may render different controls while preserving the same anchor semantics.

## Atomicity and history

A penetration is an aggregate. Entry anchor and exit anchor cannot exist independently. Creation and removal in document history MUST be one atomic mutation:

`route segment + penetration + entry anchor + exit anchor + continuation transition`

Undo must never leave an orphaned anchor or a route segment that points through a missing penetration. A penetration with dependent continuation segments must be removed together with the dependent route fragment or rejected by the document command layer.

## Stable host identity

Wall penetrations should bind to canonical `BoundaryEdgeId` wall references once the calling context has the ordered boundary topology. Legacy `wallIndex` is only a transitional projection and must not become durable penetration identity.

Slab identity is intentionally left as the next canonical topology extension. The v1 penetration aggregate is host-type-neutral so adding a stable slab id does not change paired-anchor semantics.

## Qualification requirements

The implementation is qualified by tests that prove:

1. ordinary wall/floor adjacency does not create a penetration;
2. shared-wall cross-room continuation requires a penetration;
3. wall thickness contributes to route length;
4. both anchors keep one `routeId`;
5. the reverse anchor is a continuation start;
6. ceiling-to-upper-floor continuation requires a slab penetration;
7. slab thickness is preserved by the created penetration;
8. missing physical thickness fails closed at commit time.
