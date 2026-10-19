# Route transition and flow visualization

## Goal

Cable/media routes must feel continuous across room surfaces and room boundaries. A route endpoint that reaches a physical boundary exposes all valid continuation targets representing the same physical point.

## Route media

The routing layer is not limited to mains power. It supports AC, DC, Ethernet/LAN, PoE, fibre, coax, field buses, control, fire/security loops and project/vendor-specific wired media.

`RouteMediumProfile` describes engineering/visual semantics. `ElectricalCableRoute.cableType` keeps the exact material/specification. New cable products therefore do not require new routing algorithms or enum values.

## Canonical transition point

A transition is one physical point with two surface-local coordinates:

```text
wall A @ (x,y)
       ↕ same physical point
ceiling @ (u,v)
```

or:

```text
room A / wall 2 @ (x,y)
       ↕ penetration/shared wall
room B / wall 0 @ (u,y)
```

`SurfaceTransitionCandidate` carries both anchors and a stable transition id.

## Supported transitions

- wall ↔ adjacent wall in the same room;
- wall ↔ floor;
- wall ↔ ceiling;
- wall ↔ coincident/shared wall in another room.

Cross-room continuation is conservatively marked `requiresPenetration=true` until an explicit sleeve/opening/path proves that the crossing is available.

## Authoring UX

While `CableRoute` is active and the route endpoint approaches/touches a valid boundary:

1. draw a primary transition marker on the current surface;
2. expose target-surface chips/markers (wall, ceiling, floor, adjacent room);
3. hover/tap a target to preview its corresponding marker;
4. activate target -> switch surface and create the next segment starting at the exact mapped point;
5. keep the route session active so the user continues drawing immediately.

A transition marker is larger than an ordinary route vertex and has a persistent semantic id.

## Selected route UX

Click/tap a route to select the whole engineering path, not only the visible segment. All visible segments use a selection halo; transition nodes use a stronger marker. If the user switches to another surface, the corresponding selected segment and transition anchor remain highlighted.

## Flow visualization

Flow animation is a visualization aid, not a literal electron simulation.

- AC power: oscillating/pulsating halo without one-way moving charges;
- DC power: source → target directional pulses;
- Ethernet/LAN/PoE: bidirectional packet pulses;
- fibre: moving light pulses, bidirectional when applicable;
- RS-485/control/fire/security loops: logical/control pulses;
- unknown/custom media: neutral pulsing highlight without asserting direction.

Animation must be optional and must not affect geometry, topology, routing cost, persistence or engineering validation.

## Performance

Animate only selected/inspected routes. Do not continuously animate every route in a large project. Use screen-space constant pulse size and stroke widths; route coordinates remain model-space millimetres.

## Interaction invariants

- transition points on both surfaces map to the same physical building point;
- selecting a route never changes engineering topology;
- visualization never changes simulation results;
- crossing into another room must preserve the route identity and media profile;
- route continuation must not silently create a wall penetration;
- hard routing constraints remain authoritative even if a transition is geometrically possible.
