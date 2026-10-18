# ElecX Spatial Engine — scalable architecture

## Goal

The spatial engine must remain interactive while the project grows from one room to a multi-building site containing thousands of architectural and electrical objects. The editor must not repaint or search the whole project on every pointer event.

Target navigation scale:

`component -> wall/room -> level -> building -> site`.

Persisted engineering geometry remains integer millimetres. Rendering works from a camera projection and never changes model precision.

## Core pipeline

```text
Domain model (mm)
        |
        v
Scene projection / immutable render records
        |
        v
Spatial index
        |
Viewport visible bounds
        |
        v
Visible set
        |
LOD policy
        |
        v
Render list
        |
        v
Flutter CustomPainter / future GPU renderer
```

The rendering adapter is replaceable. Geometry, indexing, LOD and selection semantics must not depend on Flutter widgets.

## Coordinate contract

### World coordinates

- signed integer millimetres;
- stable project coordinate system;
- no pixels stored in the domain;
- negative coordinates supported;
- buildings may be far from the project origin without changing object geometry.

### Camera

`WorldCamera` owns:

- world centre;
- `mmPerPixel` scale;
- screen -> world conversion;
- pan;
- cursor-anchored zoom;
- fit bounds;
- visible world bounds with overscan.

Using `mmPerPixel` makes zoom independent from arbitrary canvas dimensions and naturally supports very large maps.

## Visibility culling

Every renderable/indexable object exposes a conservative `MmBounds`.

The spatial index is queried using the viewport world rectangle before painting or hit-testing. Objects outside the visible rectangle do not participate in the frame.

Initial implementation uses a uniform spatial hash because building plans contain many similarly sized local objects and incremental updates are cheap. The public index contract must allow replacement by R-tree/BVH if production profiling proves necessary.

Recommended initial cell sizes:

- detailed room/editor index: 2–5 m;
- floor index: 5–20 m;
- site/building index: 25–100 m.

Cell size is configuration, not persisted domain state.

## Multiple indices

Do not put every entity type into one giant bucket. Maintain indexes by semantic layer when scale warrants it:

- spaces / room boundaries;
- architectural openings;
- electrical components;
- cable route segments;
- annotations / dimensions;
- guides;
- buildings / site footprints.

This allows layer visibility and hit-testing to skip irrelevant data structures entirely.

## Level of detail

Rendering detail changes with `mmPerPixel`.

### Site LOD

Show:

- building/site footprints;
- primary labels;
- major infrastructure paths.

Hide:

- room walls;
- openings;
- electrical symbols;
- dimensions;
- grids.

### Building LOD

Show:

- building footprints;
- active level envelope;
- coarse room/zone grouping where useful.

### Level LOD

Show:

- room boundaries;
- room labels;
- major cable routes;
- distribution boards.

Hide fine dimensions and minor grids.

### Room LOD

Show:

- doors/windows;
- electrical symbols;
- cable routes;
- principal dimensions.

### Detail LOD

Show:

- snap markers;
- minor grid;
- handles;
- offsets;
- fine dimensions;
- route vertices;
- wall profile vertices.

LOD is presentation only. Objects are never removed from the engineering model.

## Render scene records

Future render records should be immutable and cheap to compare. Each record carries:

- stable object id;
- layer id;
- bounds;
- geometry revision;
- semantic kind;
- minimal render payload.

Heavy conversion from domain objects to paths must be cached by `(objectId, geometryRevision, lod)`.

## Dirty regions and revisions

Do not rebuild the complete scene after every edit.

Each command must identify changed object ids. Scene projection updates only those records and their spatial-index entries.

Recommended revision model:

```text
projectRevision
  levelRevision
    objectRevision
```

A viewport-only operation such as pan/zoom does not change any engineering revision.

## Layered painting

Recommended paint order:

1. background;
2. adaptive grid;
3. architectural geometry;
4. openings;
5. cable routes;
6. electrical symbols;
7. dimensions/annotations;
8. selection/hover;
9. snap/interaction overlay.

Static and dynamic layers should be split across repaint boundaries. Cursor movement must not force rebuilding expensive static geometry.

## Grid performance

Never materialise the full grid as model objects.

Grid lines are generated only for visible bounds. Step selection is LOD-aware so screen spacing remains useful. Minor grid is omitted when its projected spacing is too small.

## Hit testing

Hit-test pipeline:

```text
pointer px
 -> camera screenToWorld
 -> acquisition bounds in world mm
 -> spatial index query
 -> semantic priority filter
 -> exact geometry distance test
 -> selected candidate
```

The acquisition radius is defined in screen pixels and converted to world millimetres per camera scale. This preserves interaction quality at every zoom level.

## Cable routing scale

Cable route data is stored as topology-aware surface segments. For rendering/indexing each segment gets a conservative world/surface bound.

At distant LOD:

- individual route vertices are hidden;
- collinear visual segments may be simplified for display only;
- circuit trunks may be aggregated.

Engineering length always uses canonical route geometry, never simplified render geometry.

## Very large project / map readiness

For site-scale projects the engine must support chunked loading:

```text
Project manifest
   -> site/building metadata
   -> requested level chunks
   -> requested room/electrical chunks
```

The viewport determines which chunks are required. Persistence/sync can therefore load only nearby geometry instead of deserialising the entire project.

Chunk identity should be spatial/semantic, not pixel-based.

## Concurrency and background work

Operations suitable for Dart isolates when profiling justifies them:

- rebuilding large spatial indexes;
- route search;
- geometry validation across many objects;
- large scene projection rebuilds;
- electrical calculations.

Pointer handling, camera state and final painting stay on the UI isolate.

Do not move small operations to isolates prematurely; message-copy overhead must be measured.

## Performance budgets

Desktop target:

- pan/zoom interaction: target 60 fps minimum, 120 fps where display permits;
- normal frame CPU budget at 60 Hz: < 16.6 ms;
- pointer hover/snap query: preferred < 2 ms;
- visible-set query: preferred < 2 ms for normal scenes;
- no O(total project objects) scan during pan/zoom;
- no domain mutation during rendering;
- no geometry allocation proportional to total project size per frame.

Reference qualification datasets should eventually include:

- 1 floor / 100 rooms / 2k components;
- 10 floors / 1k rooms / 20k components;
- multi-building site / 10k rooms / 100k engineering objects.

These are qualification datasets, not promises that every object is painted simultaneously. Culling and LOD are mandatory.

## Acceptance gates

The scalable engine foundation is acceptable when:

1. camera round-trip and cursor-anchored zoom tests pass;
2. spatial index returns only intersecting visible records;
3. index supports negative world coordinates;
4. upsert/remove do not leave stale entries;
5. LOD deterministically changes by world scale;
6. pan/zoom requires no project-wide geometry mutation;
7. visible queries scale with visible cells rather than total object count;
8. rendering remains a consumer of domain state, never its owner.
