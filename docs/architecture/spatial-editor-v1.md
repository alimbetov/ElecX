# Spatial Editor v1 — Current Implementation Scope

Status: implementation bridge for the current ElecX codebase.

Target spatial architecture is governed by `docs/architecture/spatial-platform.md`. This document describes what the current v1 implementation already provides and the immediate next increments.

## Product goal

The first ElecX editor follows an engineer's real spatial workflow rather than historical ELV delivery stages.

Current hierarchy:

```text
Project -> Site -> Building -> Level -> Space
```

A `Space` can represent a room, corridor, hall, technical room, stair, shaft or outdoor area. Future engineering systems reference these shared spaces instead of maintaining discipline-specific copies.

## Coordinate model

Persisted/domain geometry uses integer millimetres.

Every room has a `RoomReferenceFrame` with its own origin and future rotation support. The current v1 implementation uses the geometric center as the default origin and renders automatic horizontal/vertical centerlines.

Visible grid levels:

1. floor grid — coarse construction/navigation context;
2. room grid — independently configurable local precision grid.

Current room-grid choices include 50/100/250/500 mm.

## Current plan editor

Implemented foundation:

- selection;
- rectangular room creation by two snapped points;
- room/corridor demo geometry;
- project hierarchy panel;
- selected-space properties;
- room-local grid;
- automatic centerlines;
- metric status bar;
- basic zoom controls;
- integer-mm hit testing and coordinate conversion.

## Current surface editor

The implementation already exposes one selected room through derived physical surfaces:

```text
Plan
Floor
Ceiling
Wall 1..N
```

Current contracts include:

- stable surface references derived from room identity/edge index;
- wall-local coordinates where X is distance along the wall and Y is height above finished floor;
- previous/next wall navigation;
- edge-driven wall navigation:
  - wall top -> ceiling;
  - wall bottom -> floor;
  - wall sides -> adjacent walls;
- floor/ceiling boundary -> corresponding wall;
- doors/windows represented as wall-hosted openings;
- consistent opening rendering in plan and wall elevation;
- wall width/height and chained opening dimensions;
- local surface grid and room reference axes.

This is an incremental implementation of the target `RoomSurface -> SurfacePatch -> SurfaceEdge` model. Full persisted patch topology is not yet implemented.

## Current routing foundation

The current editor contains the first multi-surface route contracts:

- route draft bound to concrete surfaces;
- wall-to-wall transitions only at a shared edge;
- wall-to-floor and wall-to-ceiling transitions only at the corresponding common boundary;
- transition coordinates preserve the same physical point;
- topology transition points are not re-snapped away from their physical edge;
- active route rendering on the current surface;
- accumulated route length;
- number of involved surfaces;
- live CAD-like distances from the active route point to the current surface edges.

This is still an editor/domain foundation, not the final persisted `Route -> RouteNode[] -> RouteSegment[]` engineering model.

## Current application vertical slice

The repository currently connects:

```text
PIN quick unlock prototype
-> Project Hub
-> Spatial Editor
-> plan/room editing
-> wall/floor/ceiling surface work
-> route/surface interaction
```

PIN remains a local quick-unlock prototype and is not the complete account-security design.

## Immediate next increments

### 1. CAD viewport

- dedicated `ViewportController`;
- pan;
- zoom around cursor/focal point;
- fit floor/room/selection;
- stable world <-> screen transform;
- cursor coordinates and scale state.

### 2. Snap and geometry editing

- endpoint/midpoint/center/intersection/perpendicular/nearest snaps;
- snap preview and priority;
- arbitrary polygon rooms;
- editable vertices/segments;
- exact numeric geometry commands;
- persistent guides and smart guides;
- rotated room-local reference frames.

### 3. Full surface topology

- persisted/explicit `RoomSurface` and `SurfacePatch` model;
- `SurfaceEdge` adjacency;
- piecewise-planar geometry;
- beams/soffits/columns/shafts/steps/niches;
- deterministic world/local 3D transforms;
- topology validation and neighbor previews.

### 4. Persistence and revisions

- Drift project/spatial schema;
- spatial revisions;
- typical-floor copy;
- autosave/recovery;
- geometry change impact signaling.

### 5. Engineering attachment

Only after the spatial foundation is stable:

- typed equipment/endpoints;
- ports/connections;
- physical `Route`/`RouteNode`/`RouteSegment` persistence;
- electrical first vertical;
- catalog/solver/constraint integration.

## Migration from Electra

ElecX reuses proven geometry, routing and evidence ideas from `electra` without carrying forward ELV-stage ownership.

See `docs/migration/electra-to-elecx.md` for the authoritative migration policy.
