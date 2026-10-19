# Surface-centric editor contract

ElecX treats the floor plan, room walls, floor and ceiling as views of one spatial model rather than unrelated drawings.

## Navigation

For a selected room the editor exposes:

```text
Plan
  -> Floor
  -> Ceiling
  -> Wall 1
  -> Wall 2
  -> ...
```

A wall is derived from the corresponding room-boundary edge. Its stable identity is:

```text
<spaceId>:wall:<edgeIndex>
```

Floor and ceiling identities are:

```text
<spaceId>:floor
<spaceId>:ceiling
```

This identity must remain the same when the user switches between plan and elevation views.

## Surface coordinates

Wall local coordinates:

- X = distance along the wall from its start vertex;
- Y = height above finished floor.

Floor/ceiling coordinates use the selected room plane.

Persisted engineering coordinates use integer millimetres. Pixel coordinates are view-only.

## Architectural openings

Doors, windows, passages and technical openings are hosted by a wall surface. An opening is defined by:

- wall reference;
- offset from wall start;
- width;
- sill height;
- height.

The same opening must render consistently in both plan and wall elevation.

## Cable routing

Cable routing will use `SurfaceRouteDraft` segments bound to physical surfaces. A route may transition only through an explicit common edge or architectural opening:

```text
wall -> wall
wall -> floor
wall -> ceiling
wall -> passage -> adjacent room wall
```

A transition must preserve the physical world point, route continuity and accumulated length. Surface changes are therefore topology operations, not visual navigation shortcuts.

## CAD interaction baseline

The editor must provide:

- mouse-wheel / gesture zoom;
- pan and fit-to-view;
- persistent metric scale;
- floor and room grids;
- local room reference axes;
- snap to grid, endpoint, midpoint, center, intersection, wall and guide;
- associative dimensions;
- extension lines and dimension chains;
- visible architectural openings in plan and elevation;
- cursor coordinates in the active surface frame;
- undo/redo for every geometry operation.

Dimensions are model-derived annotations. They must never become an independent source of geometry.

## Next implementation increments

1. Pan + zoom around cursor and fit-to-selection.
2. Endpoint/midpoint/intersection snap engine.
3. Persistent guide lines and smart alignment hints.
4. Editable wall vertices and arbitrary room polygons.
5. Door/window creation and editing from either plan or wall elevation.
6. Multi-surface cable route with explicit transitions and measured total length.
7. Associative dimension editing (typing a dimension mutates geometry through a constrained command).
