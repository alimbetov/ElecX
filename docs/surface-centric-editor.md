# Surface-Centric Editor — Implementation Bridge

Status: current implementation contract / non-authoritative for long-term spatial architecture.

Authoritative target model: `docs/architecture/spatial-platform.md`.

This file records the concrete surface interaction rules currently being implemented in ElecX while the code progresses from derived room surfaces toward the full `RoomSurface -> SurfacePatch -> SurfaceEdge` architecture.

## Core rule

ElecX treats floor plan, room walls, floor and ceiling as projections of one spatial model rather than unrelated drawings.

For a selected room the current editor exposes:

```text
Plan
Floor
Ceiling
Wall 1
Wall 2
...
```

Current derived identities:

```text
<spaceId>:wall:<edgeIndex>
<spaceId>:floor
<spaceId>:ceiling
```

These are an incremental implementation mechanism. The target architecture allows persisted concrete surfaces/patches while preserving stable physical identity.

## Surface coordinates

Current wall-local coordinates:

- X = distance along wall from its start vertex;
- Y = height above finished floor.

Floor/ceiling work uses room-plane local coordinates.

Canonical engineering units are millimetres; viewport pixels are never authoritative data.

## Architectural openings

Current opening types include doors and windows; the model is prepared for passages and technical openings.

A wall-hosted opening carries:

- host surface reference;
- offset from wall start;
- width;
- height;
- sill height.

The same opening identity renders consistently in plan and elevation.

## Edge-driven navigation

Current navigation contract:

```text
wall top    -> ceiling
wall bottom -> floor
wall start  -> previous adjacent wall
wall end    -> next adjacent wall
floor edge  -> corresponding wall
ceiling edge -> corresponding wall
```

The current rectangle/polygon-edge implementation resolves these transitions from room geometry. The target patch model will make adjacency explicit for complex piecewise-planar rooms.

## Cable-route continuity

Current code supports surface-bound route draft segments and validated transitions.

Examples:

```text
wall -> wall
wall -> floor
wall -> ceiling
```

A transition is accepted only when the source point lies on the physical common boundary. The transition preserves the corresponding physical point and continues the same route draft.

Important rule:

> A topology transition point must not be moved away from its shared physical edge by ordinary grid snap.

Current UI also exposes:

- active route rendering on the selected surface;
- accumulated route length;
- number of involved surfaces;
- dynamic distances from the active route point to all four edges of the current rectangular surface view.

Target routing authority is described in `docs/architecture/engineering-platform.md` and will eventually persist explicit `Route`, `RouteNode` and `RouteSegment` entities.

## CAD interaction direction

The current editor has basic zoom and technical dimensions. The next dedicated CAD-control work must provide:

- pan;
- zoom around cursor/focal point;
- fit-to-floor/room/selection;
- persistent metric scale;
- semantic snap candidates;
- cursor coordinates in the active frame;
- persistent guides and smart guides;
- arbitrary polygon geometry editing;
- associative dimensions;
- full undo/redo command semantics.

## Supersession rule

If this implementation bridge conflicts with:

- `docs/architecture/spatial-platform.md`, or
- `docs/product/technical-specification.md`,

the target architecture/specification wins.

This file should eventually shrink into an ADR/implementation note once full explicit surface-patch topology is implemented.
