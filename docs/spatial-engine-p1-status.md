# Spatial engine P1 implementation status

This document records the implemented viewport/performance increment for `feat/spatial-editor-foundation`.

## P1.1 WorldCamera integration — implemented

- plan coordinates use `WorldCamera` instead of a fixed 12000×8000 canvas;
- wall/floor/ceiling surfaces use the same camera contract in surface-local millimetres;
- world/surface model remains integer millimetres; pixels are viewport-only.

## P1.2 Real pan — implemented

- middle-mouse drag pans plan and surface views;
- pan changes camera center, never model geometry.

## P1.3 Cursor zoom — implemented

- wheel zoom is anchored to the cursor world point;
- toolbar zoom uses viewport centre as the anchor;
- camera scale is expressed as `mmPerPixel`.

## P1.4 Fit operations — implemented

Plan:
- fit level;
- fit selected room (current selection semantics also define fit selection).

Surface:
- fit active wall/floor/ceiling.

## P1.5 SpatialSceneIndex — implemented

- plan rooms are projected into `SpatialHashIndex`;
- index uses integer-mm bounds;
- index refresh fingerprint includes room id/bounds/vertex count, so room resize does not leave stale cells.

Future indexes should be separated by domain layer: openings, electrical components, cable routes, guides and dimensions.

## P1.6 Visible-object culling — implemented for plan rooms

- camera computes visible world bounds with overscan;
- renderer receives only rooms intersecting queried spatial cells;
- benchmark dataset validates that a local viewport over 10,000 rooms resolves a bounded local candidate set.

## P1.7 Semantic LOD — implemented

`RenderLod` levels:
- site;
- building;
- level;
- room;
- detail.

Openings, labels, fine dimensions and grid detail are conditionally rendered by semantic scale.

## P1.8 Adaptive grid — implemented

- grid spacing is selected from camera `mmPerPixel`;
- minor grid is hidden when line density would be excessive;
- major grid remains available at broader scales;
- the grid is generated from visible bounds, not persisted as model objects.

## P1.9 Split repaint layers — implemented for plan viewport

Plan uses independent repaint boundaries for:
1. background/adaptive grid;
2. architecture;
3. interaction overlay.

Surface rendering is isolated in its own repaint boundary and uses the same camera/LOD/grid policy. Additional route/selection split can be introduced when electrical authoring becomes dominant.

## P1.10 Performance benchmark scene — implemented

`PerformanceScene.grid()` creates deterministic large scenes without external fixtures.

Current qualification includes:
- 10,000 rooms in the scene;
- spatial index containing all 10,000;
- a local viewport returning fewer than 100 visible candidates;
- adaptive grid scaling checks.

## Remaining hardening

- measure frame timings in a desktop profile build (not a unit-test wall-clock assertion);
- add separate spatial indexes for electrical components and cable route segments;
- add hover/snap query instrumentation;
- cache immutable render primitives per scene revision where profiling proves useful;
- add chunk streaming once project persistence is introduced.
