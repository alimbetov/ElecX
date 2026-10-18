# ElecX Product Acceptance Criteria

These criteria define target product behavior. Feature-level specs may add stricter criteria but must not weaken these.

## A. Project workflow

A project workflow is acceptable when:

1. An existing local project opens without network access.
2. The project hierarchy supports Site -> Building -> Level -> Zone/Space.
3. Basement, plinth, normal floors, roof and outdoor areas can be represented without semantic hacks.
4. The application can restore the last project/level/space/viewport context.
5. Project/floor defaults and room overrides are explicit.

## B. Spatial precision

Spatial editing is acceptable when:

1. Canonical geometry is stored in integer millimetres.
2. Screen pixels are never authoritative engineering coordinates.
3. Pan/zoom cannot change stored geometry.
4. Numeric dimensions can be inspected at any zoom.
5. Room-local reference frames are deterministic.
6. Room grid settings are independent of floor grid settings.
7. Polygon editing rejects degenerate geometry.
8. Undo/redo restores exact prior geometry state.

## C. CAD interaction

The editor is acceptable when:

1. Zoom-around-cursor preserves the physical point under the focal location.
2. Fit floor/room/selection is deterministic.
3. Snap exposes candidate type and target before commit.
4. Endpoint/midpoint/center/intersection/wall/guide snaps are distinguishable.
5. Topology transition points are not moved away from shared edges by generic snap.
6. Dynamic dimensions remain readable but do not become authoritative geometry.
7. Repeated placement/routing can continue without reopening the tool palette.

## D. Surface model

Surface editing is acceptable when:

1. Plan, floor, ceiling and wall elevations resolve to one shared room geometry.
2. Every wall has a stable identity derived from authoritative room topology or persisted surface identity.
3. Doors/windows keep the same object identity across plan/elevation rendering.
4. Wall local X measures distance along the wall; local Y measures height from finished floor.
5. Surface adjacency is explicit and validated.
6. Moving to an adjacent surface does not require recreating selected engineering objects.
7. Piecewise-planar features can be introduced without changing the fundamental navigation model.

## E. Routing

Physical routing is acceptable when:

1. A route consists of explicit nodes and segments.
2. Route length is derived from exact geometry.
3. A cable route can cross wall/floor/ceiling surfaces without losing continuity.
4. Each surface transition preserves one physical world point.
5. Invalid non-adjacent surface transitions are rejected.
6. Laying method may vary by segment.
7. Junctions are not represented as ordinary bends when branching semantics exist.
8. Shared conduit/tray/pathway infrastructure can be represented independently from individual cables.

## F. Engineering model

The shared engineering model is acceptable when:

1. One physical equipment item can participate in multiple systems through typed ports.
2. Discipline-specific semantics remain typed.
3. Generic EAV/key-value storage is not used as the stable core model.
4. Project changes can identify affected downstream facts.
5. Manual/locked engineering decisions are explicit.

## G. Catalog/reference data

Catalog behavior is acceptable when:

1. Canonical engineering class and manufacturer SKU are separate identities.
2. Catalog/reference entities have stable codes and versions.
3. Deprecated data remains readable for existing projects.
4. Projects can pin catalog/profile versions.
5. Project overrides do not mutate global catalog data.
6. Manufacturer compatibility can be evaluated explicitly.
7. Critical selections can state which catalog/version produced them.

## H. Solver runtime

A solver runtime is acceptable when:

1. Each solver has stable ID/version.
2. Inputs and outputs are typed.
3. Consumed/produced fact dependencies are declared.
4. An input change triggers only the affected dependency closure where possible.
5. Execution order is deterministic.
6. Cycles/errors are detected explicitly.
7. Critical results have fingerprints/evidence.
8. Golden engineering scenarios are reproducible.

## I. Constraints/compliance

Validation is acceptable when:

1. Calculation results and acceptance rules are separate.
2. A normative finding identifies the exact rule/profile/version.
3. The affected project object is directly navigable.
4. Projects do not silently adopt newer rule versions.
5. Rule provenance is recorded.
6. National/standard completeness is not claimed without verified coverage evidence.

## J. Configuration/optimization

Automatic configuration is acceptable when:

1. Requirements are normalized before product selection.
2. Invalid candidates can explain why they failed.
3. Locked user selections are never silently replaced.
4. Configuration changes trigger dependent calculation/layout/cost updates.
5. The user can compare multiple feasible alternatives.
6. Cost is not the only objective supported by the model.
7. The selected configuration remains fully traceable to inputs/catalog/norm/solver versions.

## K. Electrical first vertical

The first production electrical vertical is acceptable when a user can:

1. Create a real project and room geometry.
2. Place electrical loads/endpoints.
3. Create circuits and panel relationships.
4. Route cables physically.
5. Derive route/cable length.
6. Calculate core electrical sizing/checks supported by available inputs.
7. Select/validate protection and cable candidates.
8. Produce a panel/circuit/cable schedule and BOM.
9. Reopen the project offline and reproduce the result.

## L. Deliverables

Deliverables are acceptable when:

1. Generated documents are projections of authoritative project state.
2. Aggregate values drill down to project evidence in-app.
3. Printed output remains understandable in monochrome.
4. BOM items trace back to actual project objects/selections.
5. Critical reports include catalog/norm/solver version context.
6. Published/frozen outputs can be reproduced later.

## M. Quality gate

A feature is not complete only because the UI appears to work.

Required completion evidence includes, as applicable:

- formatting gate;
- static analysis;
- unit/domain tests;
- persistence/migration tests;
- UI/widget tests for critical interaction;
- golden scenario or qualification tests;
- invalid-path tests;
- deterministic replay/rebuild tests for revisioned results;
- documentation aligned with actual runtime behavior.
