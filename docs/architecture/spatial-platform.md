# ElecX Spatial Platform

## Purpose

The spatial platform is the shared geometric foundation for every engineering discipline. It must support precise field-oriented design, routing and documentation without forcing ElecX to become a full BIM authoring system.

## Canonical hierarchy

```text
Project
  -> Site
      -> OutdoorZone[]
      -> Building[]
          -> Level[]
              -> Zone[]
              -> Space[]
```

Representative `Space` types include room, corridor, hall, technical room, stair, shaft and outdoor area.

## Canonical coordinates

Persisted engineering geometry uses integer millimetres.

```text
xMm
yMm
zMm
```

Screen pixels are transient presentation coordinates only.

Each room/space may own a local reference frame:

```text
RoomReferenceFrame
  origin
  rotation
```

The default room origin is the geometric center. The UI may later allow center/corner/custom origins and rotated frames.

## Grid model

Visible precision layers:

```text
world/site context
-> floor grid
-> room-local grid
```

Room-local grids are independently configurable and rotate with the room reference frame.

Typical steps:

- 50 mm;
- 100 mm;
- 250 mm;
- 500 mm;
- custom.

Major/minor grid styling is presentation state; grid spacing is model/editor configuration.

## Room surfaces

Plan, floor, ceiling and walls are not separate drawings.

```text
Room
  -> RoomSurface[]
       -> SurfacePatch[]
            -> SurfaceEdge[]
```

Logical surface types:

- FLOOR;
- CEILING;
- WALL;
- CUSTOM.

A `RoomSurface` groups one or more exact planar patches.

A `SurfacePatch` owns:

- stable id;
- parent surface id;
- bounded polygon;
- plane/orientation;
- local 2D coordinate frame;
- world/local transform;
- boundary edges.

This supports piecewise-planar geometry while keeping editing deterministic.

## Piecewise-planar geometry

Target supported direction:

- horizontal planes;
- vertical planes;
- sloped planes;
- polygonal boundaries;
- explicit folds and steps;
- raised/lowered zones;
- beams and soffits;
- niches/recesses;
- columns and shafts;
- platforms/protrusions.

Examples:

```text
CeilingSurface
  -> main patch z=2700
  -> soffit side patch
  -> soffit underside z=2400

FloorSurface
  -> main patch z=0
  -> vertical step face
  -> raised patch z=150
```

NURBS, arbitrary curved surfaces and BIM-grade solid modelling are non-goals for the early product. Curves may later be approximated by validated planar segmentation where acceptable.

## Spatial features

Semantically useful construction geometry is explicit:

```text
SpatialFeature
  BEAM
  COLUMN
  SOFFIT
  NICHE
  SHAFT
  STEP
  PLATFORM
  RECESS
  PROTRUSION
  CUSTOM
```

A feature may own/generate one or more surface patches. This identity is important for dimensions, routing constraints, clash checks and documentation.

## Openings

Architectural openings are hosted by concrete wall geometry.

Initial types:

- door;
- window;
- passage;
- technical opening.

A wall-hosted opening owns at least:

- host wall/surface reference;
- offset from wall start;
- width;
- height;
- sill height where relevant;
- opening-specific metadata.

The same opening identity must render in plan and elevation.

## Edge topology and adjacency

Each editable patch exposes boundary edges.

```text
SurfaceEdge
  id
  patchId
  localStart/localEnd
  worldStart/worldEnd
  adjacentPatchId?
  adjacentSurfaceId?
```

Adjacency is explicit and symmetric where topology requires it.

The editor must not infer complex-room navigation from hardcoded left/right/top/bottom assumptions.

## Edge-driven navigation

The geometry itself is the primary surface navigator.

Conceptual behavior:

```text
far from edge       -> no preview
near edge           -> edge highlight
closer               -> adjacent surface preview
very close           -> strong preview / snap hint
click/tap/cross      -> adjacent surface becomes active
```

Typical wall relationship:

```text
            CEILING
               ^
               |
WALL D <- WALL A -> WALL B
               |
               v
             FLOOR
```

For floor/ceiling, the corresponding polygon edge resolves to the concrete adjacent wall.

For features, the same topology may expose transitions such as:

```text
ceiling -> beam side -> beam underside -> opposite side -> ceiling
```

The UI may show a folded/angled preview. Fold angle/opacity are transient presentation state and are never engineering data.

## Surface-local coordinates

For a wall elevation:

```text
X = distance along wall from the start vertex
Y = height above finished floor
```

For floor/ceiling and arbitrary patches, editing uses the patch local 2D frame with deterministic mapping to world 3D coordinates.

## CAD viewport contract

The viewport is a dedicated presentation/application subsystem.

Required capabilities:

- pan;
- wheel/gesture zoom;
- zoom around cursor/focal point;
- fit floor;
- fit room;
- fit selection;
- stable world-to-screen and screen-to-world conversion;
- cursor coordinates in active frame;
- density/label adaptation by zoom.

Viewport state must not mutate world geometry.

## Snap engine

Snap is candidate-based, not only grid rounding.

Target candidates:

- grid;
- endpoint;
- midpoint;
- center;
- intersection;
- perpendicular;
- nearest;
- wall;
- guide;
- equipment/port where meaningful.

Snap selection considers screen-space tolerance, candidate type priority, active tool and local room/surface context.

Topology transition points are special: a shared physical edge transition must not be moved off the edge by generic grid snapping.

## Guides and centerlines

Each room automatically exposes local center axes. Users may create persistent guides and derived fractional guides such as halves, thirds or quarters.

Smart guides may show:

- same X/Y;
- equal spacing;
- room center;
- wall center;
- object center;
- alignment to nearby geometry.

Persistent guide definitions belong to project/editor geometry state; ephemeral smart hints do not.

## Dimensions

Dimensions are model-derived annotations, never an independent geometry source.

Target features:

- overall dimensions;
- chained dimensions;
- opening offsets;
- wall/floor/ceiling distances;
- live cursor or active-route-point distances;
- associative dimension editing.

Associative edit example:

```text
click 1200 mm
-> type 1500
-> constrained geometry command moves the object
-> dependent dimensions update
```

The dimension text itself is not authoritative geometry.

## Routing continuity across surfaces

Routing remains active when the engineer crosses a valid adjacent edge.

```text
RouteSegment(surfacePatchId = wallA)
  -> RouteNode(type = SURFACE_TRANSITION)
  -> RouteSegment(surfacePatchId = floor)
```

A transition must preserve the same physical world point and exact accumulated route geometry.

The same applies to adjacent walls, ceiling, feature patches and later room/floor transitions.

## Spatial revisions

Shared geometry is revisioned independently from discipline calculations.

If walls, openings, surfaces, patches or features change, the spatial revision changes. Engineering layers that depend on the prior revision become stale/affected and must be selectively recalculated or reviewed.

## Spatial validation

The spatial core must detect at least:

- degenerate polygons;
- invalid transforms;
- invalid wall/opening bounds;
- broken or asymmetric adjacency;
- gaps/overlaps where a shared edge is required;
- invalid feature-to-patch ownership;
- route transitions not lying on a valid shared boundary;
- impossible room/surface topology.

## Current implementation mapping

Current ElecX code already establishes the first subset:

- integer-mm `MmPoint`/polygon geometry;
- `Project -> Site -> Building -> Level -> Space` foundation;
- room-local reference frame and grids;
- derived wall/floor/ceiling surface identities;
- doors/windows in plan/elevation;
- surface-edge navigation;
- wall/floor/ceiling route transitions;
- accumulated route length;
- CAD-like dimensions around active route points.

The next implementation step is a reusable viewport + snap engine, then arbitrary polygon editing and full patch topology.
