# ElecX engineering engine architecture audit

## Goal

ElecX must behave as an engineering CAD/calculation engine, not as a drawing tool with ad-hoc validation. The engine must remain deterministic, testable, explainable and extensible across power, lighting, LAN, CCTV, ACS, fire alarm and automation.

## Target pipeline

```text
Spatial geometry
    ↓
Component placement
    ↓
Engineering topology
    ↓
Routing graph
    ↓
Hard constraints
    ↓
Route solver
    ↓
Drawing simulation
    ↓
Optimization candidates
    ↓
Explainable corrective actions
    ↓
User preview / accept / reject
```

## Layer responsibilities

### Geometry

Owns physical room/surface coordinates in integer millimetres, actual wall profiles and surface transitions. It must never know electrical calculation rules.

### Placement

Owns component identity, surface, position and rotation. Placement validity is derived from catalog mounting policy plus geometry.

### Topology

Owns engineering nodes, ports and directed connections. A physical undirected path and a valid directed supply/data path are different queries and must not be conflated.

### Routing

Owns candidate graph construction and shortest/preferred path solving. The solver must not silently violate hard constraints.

### Constraints

Owns keep-out/service/architectural zones and later discipline-specific separation rules. Hard constraints filter candidate graph edges before route ranking.

### Simulation

Audits an existing drawing without mutating it. Findings are deterministic and contain object identity, severity and explanation.

### Optimization

Produces alternative geometry/topology proposals. It must never apply a proposal automatically. Every proposal is previewable and reversible.

## Implemented hardening

- `EngineeringAnalysisProfile` moves thresholds and scoring out of the simulation algorithm.
- runtime `catalogResolver` allows simulation against SQLite/user/manufacturer catalogs instead of the built-in catalog singleton.
- `EngineeringTopology.hasDirectedPath()` distinguishes supply direction from mere physical connectivity.
- `SurfaceKeepOutZone` and `RoutingConstraintEngine` implement hard geometric routing constraints.
- route audit detects keep-out violations, excessive bends/transitions, missing endpoints and measurable route waste.
- component audit detects invalid surfaces, out-of-geometry placement, exact overlap and configurable generic clearance violations.
- simulation reports infeasible constrained auto-route separately from an inefficient route.

## Required invariants

1. Persistent engineering coordinates are always model-space millimetres, never pixels.
2. A component placement references exactly one physical surface.
3. A route endpoint references a real component port.
4. A topology edge may only be created when port direction and connection type are compatible.
5. Hard constraints are evaluated before soft route costs.
6. Simulation never mutates project state.
7. Optimization never applies itself; the user accepts/rejects a proposal.
8. Every finding identifies the affected object and can be mapped back to canvas selection.
9. Runtime catalogs and future normative profiles are dependencies, not globals hidden inside the solver.
10. Undo/redo wraps accepted mutations, not simulation previews.

## Current P0 gaps

### Canvas/session integration

`SurfaceCanvas` still contains legacy direct component-move calls in addition to the new `ComponentMoveSession`. Consolidate pointer/touch/stylus/keyboard movement through one transaction.

New V2 catalog placement must also use one pointer path:

```text
pointer → surface point → snap → validate → placement preview → confirm
```

### Architectural obstacle projection

Keep-out zones are currently explicit inputs. Build automatic projection from:

- door/window openings;
- beam/notch geometry;
- shafts and reserved zones;
- enclosure service clearances;
- future wet/fire/normative zones.

### Component physical envelopes

Current generic clearance uses center-to-center distance. Catalog V3 should provide installation envelope and service envelope separately:

```text
symbol bounds
installation bounds
service/maintenance clearance
routing keep-out clearance
```

### Multi-object routing optimization

Current optimization is per route. Future circuit-level optimization should jointly minimize trunk length and junction placement while preserving topology, separation and capacity constraints.

## P1 optimizer design

Use two classes of rules.

### Hard constraints

- invalid surface;
- outside wall/room geometry;
- forbidden/opening/service zone;
- incompatible connection/port;
- impossible surface transition;
- route capacity/separation violation;
- normative prohibition.

A hard violation removes the candidate or marks the drawing invalid.

### Soft objectives

- total cable length;
- number of bends;
- number of surface transitions;
- preferred installation plane;
- shared trunk reuse;
- installation complexity;
- estimated material cost;
- estimated labor cost;
- maintainability score.

A future optimizer should expose a cost vector rather than a single opaque score.

## P1 explainability contract

Every recommendation should answer:

- What is wrong?
- Where is it?
- Which rule detected it?
- What is the current measured value?
- What is the target/limit?
- What change is proposed?
- What measurable benefit does it give?

Example:

```text
Route R-12
WARNING: inefficient route
Current length: 12 450 mm
Candidate length: 9 880 mm
Saving: 2 570 mm (20.6%)
Bends: 7 → 4
Transitions: 2 → 1
Action: preview optimized route
```

## UI correction workflow

```text
Run simulation
  ↓
Finding list
  ↓
Select finding
  ↓
Canvas selects and focuses object
  ↓
Show current + suggested geometry
  ↓
Move / reroute / reconnect / change component
  ↓
Preview
  ↓
Accept
  ↓
Command history
  ↓
Re-simulate
```

Selected components remain directly movable on their host surface. Movement must use the shared move transaction and continuously re-evaluate snap, placement validity and local measurements.

## Acceptance bar for a strong engine

A release is not considered complete merely because components can be drawn. It must prove at least:

1. two different catalog components can be placed on appropriate surfaces;
2. components can be selected and moved transactionally;
3. nodes/ports can be connected through a valid directed topology to a board/source;
4. invalid port direction is rejected;
5. an intentionally inefficient route is detected and improved;
6. a keep-out crossing is detected and excluded from optimized routing;
7. invalid placement is reported without corrupting state;
8. simulation findings map to object ids suitable for UI selection;
9. analyzer and test suite pass on the exact commit.
