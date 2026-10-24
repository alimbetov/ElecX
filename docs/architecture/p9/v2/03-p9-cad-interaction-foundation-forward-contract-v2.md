# P9 CAD Interaction Foundation — Forward Contract v2

Status: **AUTHORITATIVE FOR P9 FORWARD COMPATIBILITY WITH P10-P14**  
Branch: `feat/p9-apartment-topology-generator`  
Applies directly to: P9.6, P9.8, P9.9, P9.10, P9.11, P9.13  
Forward consumers: P10 building/complex generation, P11 EngineeringGraph navigation, P12 starter generation, P13 auto-placement, P14 routing/CAD editing

## 1. Purpose

P9 is the last architectural generation phase before ElecX moves into substantially heavier engineering placement and CAD interaction.

This contract prevents P9 from introducing preview, selection, coordinate, gesture or command abstractions that would later have to be replaced for P10-P14.

The governing principle is:

```text
canonical engineering state
        ↑
validated ProjectCommand / mutation boundary
        ↑
semantic editor operation
        ↑
interaction session / transient candidate
        ↑
input adapter + hit-test/snap + viewport
        ↑
mouse / keyboard / touch / stylus
```

No pointer/gesture/widget layer may become an alternative canonical mutation path.

---

# 2. Relationship to previous spatial-editor work

Historical spatial-editor branches already established useful ideas:

```text
integer-mm world geometry
WorldCamera screen<->world transform
cursor-anchored zoom
viewport culling
spatial index
screen-space acquisition radius
semantic LOD
command-oriented geometry edits
```

Those ideas are compatible with the current P3/P8 architecture, but the old prototype controller/state must not become a second authoritative editor model.

In particular, forward implementation MUST NOT preserve transitional patterns as permanent contracts:

```text
single selectedSpaceId / selectedOpeningId as the final selection model
wallIndex as durable host identity
widget/controller direct canonical mutation
simple grid-rounding as the complete snap engine
Expando/listenable viewport buses as cross-feature application command infrastructure
OS-specific layout branches
```

P9 adopts the architectural principles, not historical implementation coupling.

---

# 3. Coordinate-space model

ElecX MUST name coordinate spaces explicitly. Passing a generic `Offset`, `Point` or pair of doubles across layers without coordinate-space meaning is forbidden in new CAD-facing contracts.

## 3.1 Project/world coordinates

Canonical persisted planar geometry:

```dart
final class WorldPointMm {
  final int xMm;
  final int yMm;
}
```

Rules:

```text
signed integer millimetres
negative coordinates supported
no pixels
no device scale
no viewport dependence
```

Project/world coordinates are the basis for canonical Space boundaries, openings, component placement anchors and physical route geometry.

## 3.2 Candidate-local coordinates

P9-generated apartment geometry is created in a local frame before target placement:

```dart
final class CandidatePointMm {
  final int xMm;
  final int yMm;
}
```

Candidate-local geometry participates in P9 deterministic fingerprints.

It is not assumed to be permanently equal to project/world coordinates.

## 3.3 Target placement frame

A generated candidate is placed into the target Level through one explicit integer transform:

```dart
final class OrthogonalPlacementTransformMm {
  final int translateXmm;
  final int translateYmm;
  final int quarterTurnsClockwise; // 0..3
  final bool mirrorX;
}
```

P9 v1 default for an empty Level is a deterministic identity/level-origin placement unless an explicit target frame is supplied.

P10 may later provide non-identity placement transforms while reusing the same candidate geometry.

No transform may be inferred from screen position.

## 3.4 Surface/local coordinates

Wall/floor/ceiling/component-host editing may use explicit local reference frames:

```text
SurfacePointMm
HostLocalPointMm
RouteLocalPointMm
```

Conversion to project/world coordinates MUST use a typed reference frame/host identity.

## 3.5 Screen logical coordinates

Input/render coordinates are logical pixels:

```dart
final class ScreenPointLp {
  final double x;
  final double y;
}
```

They are transient presentation values.

Physical device pixels MUST NOT enter domain/application semantics.

## 3.6 Transform chain

Required conceptual chain:

```text
candidate-local mm
   --placement transform-->
project/world mm
   --camera projection-->
screen logical px
   --device renderer-->
physical pixels
```

Reverse hit-testing:

```text
pointer logical px
   --camera inverse-->
world mm
   --spatial index / exact geometry-->
semantic hit candidate
```

Only explicitly supported invertible steps may be used for editing.

---

# 4. Camera / viewport contract

P9 Preview currently needs only pan/zoom/fit, but the abstraction MUST be compatible with the future project CAD camera.

## 4.1 Camera semantic state

Recommended forward contract:

```dart
final class WorldViewportCamera {
  final WorldPointMm centerMm;
  final double mmPerLogicalPixel;
}
```

Required operations:

```text
screenToWorld
worldToScreen
panLogicalPixels
zoomAtScreenAnchor
fitWorldBounds
visibleWorldBounds
```

The existing historical `WorldCamera` behavior is the target semantic model: world centre + mm-per-pixel scale, cursor-anchored zoom and exact integer-mm inverse projection.

## 4.2 P9 preview adapter

`PreviewViewportState` MUST be treated as a light presentation wrapper/adapter over the common camera semantics, not as a competing permanent camera model.

Preferred implementation direction:

```text
ApartmentTopologyVectorScene
        +
PreviewCamera / WorldViewportCamera-compatible adapter
        ↓
P9 renderer
```

P10-P14 should be able to reuse the same camera kernel without translating between incompatible zoom models.

## 4.3 Viewport invariants

Viewport operations MUST NOT change:

```text
ProjectAggregate
LocalProjectVersion
candidateFingerprint
geometryFingerprint
P8 reservation
selection entity identity
provenance
```

Pan/zoom is never Undo/Redo history.

---

# 5. Selection architecture

P9 has `ApartmentCandidateSelection`. That is Wizard answer selection and MUST remain separate from CAD object selection.

Future CAD selection needs a typed, multi-entity model.

## 5.1 Selection target

```dart
sealed class EditorSelectionTarget {
  const EditorSelectionTarget();
}

final class SpaceSelectionTarget extends EditorSelectionTarget {
  final SpaceId spaceId;
}

final class BoundarySelectionTarget extends EditorSelectionTarget {
  final SpaceId spaceId;
  final BoundaryEdgeId edgeId;
}

final class OpeningSelectionTarget extends EditorSelectionTarget {
  final OpeningId openingId;
}

final class ComponentSelectionTarget extends EditorSelectionTarget {
  final ComponentId componentId;
}

final class RouteSelectionTarget extends EditorSelectionTarget {
  final RouteId routeId;
}
```

The exact subtype set may grow, but new selection identity MUST use canonical typed IDs.

## 5.2 Selection set

Recommended model:

```dart
final class EditorSelectionState {
  final List<EditorSelectionTarget> orderedSelection;
  final EditorSelectionTarget? primary;
}
```

Rules:

- selected targets are unique;
- order is deterministic and explicit;
- `primary` is null iff selection is empty;
- inspector actions operate on primary or an explicitly supported homogeneous set;
- hover is not selection;
- keyboard focus is not selection;
- active navigation context is not selection.

## 5.3 Selection operations

Semantic operations:

```text
replaceSelection(target)
addSelection(target)
toggleSelection(target)
removeSelection(target)
clearSelection()
setPrimary(target)
```

Input mapping examples:

```text
mouse click               replace
Ctrl/Cmd + click          toggle
Shift + click             add when tool policy allows
finger tap                replace
explicit multi-select UI  add/toggle on touch
stylus tap                replace
Escape                    clear/cancel interaction according to operation state
```

Touch must not depend on hidden modifier keys for multi-selection.

## 5.4 Selection reconciliation

After canonical mutation:

```text
remove deleted targets
remap explicitly lineage-preserved targets
retain unchanged IDs
choose deterministic new primary if old primary disappeared
```

Boundary edge split/merge/removal uses P7 lineage; never rebind by numeric edge position.

---

# 6. Hover and focus separation

Three states are independent:

```text
selection     semantic editor selection
hover         transient pointer feedback
focus         accessibility/keyboard navigation
```

Changing hover/focus MUST NOT:

```text
change canonical state
change selection automatically
enter Undo history
change candidate fingerprints
```

A focused item may be activated to become selected through an explicit operation.

---

# 7. Hit-testing architecture

Future P13/P14 must not scan the full project on every pointer event.

Required pipeline:

```text
ScreenPointLp
  ↓ camera.screenToWorld
world point + screen acquisition radius converted to mm
  ↓
query relevant spatial indexes/layers
  ↓
semantic priority filter
  ↓
exact integer/rational geometry distance test
  ↓
ordered HitTestCandidate[]
  ↓
selection/tool policy chooses one
```

## 7.1 Layer-aware hit testing

Index/query by semantic layer where scale requires it:

```text
spaces/boundaries
openings
engineering components
route segments/vertices
annotations/dimensions
guides
site/buildings
```

Tool policy can disable irrelevant layers before exact testing.

## 7.2 Acquisition radius

Acquisition tolerance is defined in screen logical pixels and converted through camera scale.

Recommended defaults:

```text
precise pointer / stylus   8..10 logical px
touch                      16..20 logical px
```

Exact values are configurable UX policy, not persisted engineering data.

This ensures stable interaction difficulty across zoom levels.

---

# 8. Snap engine forward contract

P9 generation geometry is deterministic and does not need interactive snapping, but P9 must avoid introducing a contradictory grid-only snap abstraction before P13/P14.

## 8.1 Snap request

```dart
final class SnapQuery {
  final WorldPointMm rawWorldPoint;
  final double acquisitionRadiusLogicalPx;
  final SnapContext context;
  final Set<SnapKind> enabledKinds;
  final EditorSelectionState selection;
}
```

## 8.2 Snap kinds

At minimum future kernel supports:

```text
grid
endpoint
midpoint
centre
intersection
perpendicular
nearestPoint
boundary/wall
routeVertex
componentAnchor
guide
```

## 8.3 Snap result

```dart
final class SnapResult {
  final WorldPointMm snappedPoint;
  final SnapKind kind;
  final int priority;
  final EditorSelectionTarget? owner;
  final String? anchorKey;
  final int distanceScreenMilliPx;
}
```

Exact representation may differ, but the result must include enough information to render a snap marker and to reproduce the semantic anchor used by a command.

## 8.4 Resolution order

Snap resolution MUST be deterministic for equal inputs.

Recommended ordering:

```text
explicit active-tool constraint
coincident/endpoint
intersection
midpoint/centre
perpendicular
boundary nearest point
route/component anchor
guide
grid fallback
```

Tie-break uses explicit priority + stable typed identity/anchor key, never collection iteration order.

## 8.5 Snap vs constraints

Snapping chooses an interaction candidate. Constraints validate/solve the final command candidate.

Snap does not become a persisted hidden constraint unless the user explicitly creates one.

---

# 9. Input operation / command dispatch architecture

P9 already maps mouse/keyboard/touch/stylus to semantic operations. This must grow into a two-lane dispatcher.

## 9.1 Transient editor operations

Do not mutate canonical state:

```text
pan
zoom
fit
hover
replace/add/toggle selection
begin drag interaction
update drag preview
cancel drag
open inspector/context UI
```

## 9.2 Canonical operations

Canonical mutation path:

```text
semantic editor intent
  ↓
ProjectCommand / ReservedProjectCommand
  ↓
ProjectMutationSession
  ↓
CandidateGraphValidator
  ↓
ProjectChangeSet
  ↓
atomic commit + LocalProjectVersion + UndoRecord
```

No new CAD feature may create an `EditorController` method that edits authoritative entity stores directly.

## 9.3 Command dispatcher

Recommended application facade:

```dart
abstract interface class ProjectCommandDispatcher {
  ProjectMutationResult dispatch(ProjectMutationRequest request);
}
```

Presentation should not know repository implementation details.

---

# 10. Direct-manipulation transaction model

P13/P14 drag interactions MUST use preview-then-commit semantics.

```text
pointer down
  ↓
hit target + capture interaction context
  ↓
pointer move
  ↓
screenToWorld
  ↓
snap/constraints
  ↓
transient interaction candidate
  ↓
render preview only
  ↓
pointer up / confirm
  ↓
build one validated ProjectCommand
  ↓
one atomic commit / one UndoRecord
```

Rules:

- pointer move does not increment LocalProjectVersion;
- no UndoRecord per move event;
- Escape/pointer cancel discards transient candidate;
- stale canonical version at commit fails/rebases explicitly;
- command builds from stable IDs captured/revalidated at completion;
- preview candidate never becomes canonical merely because it was painted.

---

# 11. Interaction-session contract

Recommended state:

```dart
sealed class EditorInteractionSession {}

Idle
PointerAcquired
Dragging
BoxSelecting
RouteDrafting
PlacementPreview
CommandConfirming
```

Only one primary geometry-mutating interaction session owns a pointer stream at a time.

Secondary pointers may be assigned to viewport gestures only when the active tool policy permits it.

Session disposal/cancel must release pointer capture and transient overlays.

---

# 12. Gesture arbitration

Gesture conflicts must be resolved before P13/P14 implementation.

Priority when a pointer begins inside a CAD canvas:

```text
1 explicit active handle / control point
2 active drawing/routing/placement tool
3 selected-object direct manipulation
4 selection/hit testing
5 viewport pan/zoom gesture
6 parent carousel/page gesture
```

P9 candidate carousel remains outside the CAD editing kernel. If a future editable preview canvas is embedded in a carousel, pointer ownership is determined from pointer-down location and interaction mode; ownership cannot switch mid-gesture due only to movement direction.

## 12.1 Mouse

Recommended:

```text
primary drag       active tool/direct manipulation
middle drag        pan
wheel              scroll where applicable
Ctrl/Cmd+wheel     zoom where convention allows
Space+primary drag optional CAD pan
```

## 12.2 Touch

Recommended:

```text
one-finger tap       select
one-finger drag      tool/drag OR pan according to explicit mode
pinch/two-finger     viewport zoom/pan
explicit multi-select affordance for additive selection
```

## 12.3 Stylus

Stylus is treated as precise pointer by default.

Pressure/tilt/barrel button are optional future modifiers and MUST NOT be required for core operations.

---

# 13. Box/lasso selection forward contract

P13/P14 likely require multi-selection beyond repeated taps.

At minimum the architecture reserves:

```text
BoxSelectionQuery(world polygon/bounds, crossingPolicy, layerMask)
```

Two CAD conventions may be supported later:

```text
window selection   fully contained objects
crossing selection intersecting objects
```

The policy must be explicit in UI and tests; drag direction must not silently encode semantics unless deliberately documented.

Lasso is optional future extension.

---

# 14. Placement frame and P9/P10 boundary

P9 candidate generation must remain reusable by P10 floor/building composition.

Therefore P9.6 geometry is candidate-local and P9.11 materialization applies an explicit target placement transform.

## 14.1 P9 v1

For an empty Level:

```text
candidate-local origin
 -> deterministic Level placement frame
 -> canonical world coordinates
```

Recommended default is identity transform at the target Level/project origin or another single documented deterministic anchor.

## 14.2 P10 reuse

P10 may generate multiple apartment candidates and place each using an explicit transform:

```text
Apartment candidate A + transform A
Apartment candidate B + transform B
Apartment candidate C + transform C
```

P10 must not edit P9 source polygons by screen-space translation.

## 14.3 Transform fingerprint semantics

P9 candidate fingerprint identifies candidate-local geometry.

A composed P10/final materialization fingerprint additionally includes target placement transform.

P9 v1 provenance stores the applied placement transform when non-identity or when required for exact reconstruction.

---

# 15. Canonical transform policy

For current orthogonal architecture:

```text
translation        integer mm
rotation           integer quarter-turns in P9/P10 v1 path
mirror             explicit boolean/axis operation
```

Do not persist arbitrary floating affine matrices for orthogonal building geometry merely because Flutter rendering uses matrices.

If later CAD supports arbitrary rotation, introduce a typed canonical angle/unit policy via ADR before extending persisted transforms.

---

# 16. Route editing forward contract

P14 physical route geometry will consume the same interaction kernel.

Required future concepts:

```text
RouteId
RouteVertexId or stable route-point identity
host surface/segment identity
source/target anchor
route draft interaction session
snap query/results
validated route command
```

Display simplification/LOD never replaces canonical route vertices.

P9/P13 must not introduce component placement APIs that assume routes are screen-space polylines.

---

# 17. Auto-placement forward contract

P13 generated device placement consumes:

```text
SpaceUsage
canonical room geometry
BoundaryEdgeId
OpeningId
wall/facade role
wet zones
engineering topology
catalog equipment dimensions/ports
```

Placement candidate should follow the same safety pattern as P8/P9:

```text
placement request
 -> candidates
 -> validate
 -> preview
 -> semantic diff
 -> atomic command
```

Manual adjustment then uses the common interaction kernel and normal commands.

---

# 18. Interaction performance budgets

Forward targets for CAD surfaces:

```text
60 fps frame budget                    <= 16.6 ms normal target
pointer hit-test visible/indexed set   p95 <= 2 ms
snap query visible/indexed set         p95 <= 2 ms preferred, p99 <= 5 ms
screenToWorld/worldToScreen            effectively O(1)
no O(total project objects) pointer scan
no domain mutation during paint
no project-wide reprojection on hover
```

120 Hz displays MAY benefit from lower budgets, but 60 fps is the minimum interaction target for supported hardware under reference qualification scenes.

Performance qualification datasets should eventually include thousands of rooms/components and site-scale projects with culling/LOD active.

---

# 19. Repaint / projection boundaries

Recommended render layering:

```text
static/background/grid
architectural geometry
openings
engineering components
routes
annotations
selection/hover
snap/interaction overlay
```

Transient cursor/snap/drag changes SHOULD invalidate only interaction layers where architecture permits.

ProjectChangeSet invalidates affected scene records/index entries rather than forcing a full project rebuild.

---

# 20. Accessibility and modality

CAD interaction must remain operable without relying on one modality.

Required principles:

- keyboard can reach/select major objects and operations where practical;
- context actions have discoverable toolbar/inspector alternatives;
- touch target sizes respect platform guidance;
- hover is enhancement only;
- stylus is optional;
- selection state is announced semantically;
- canvas accessibility uses meaningful objects, not every line segment as an independent node.

Precision geometry entry may always expose numeric inspector fields even when drag is supported.

---

# 21. State persistence policy

Persistent canonical state:

```text
engineering entities
geometry
hosts
routes
provenance
```

Potential resumable editor state (separate product decision):

```text
active BuildingId/LevelId
selected canonical entity IDs
camera centre/scale
active tool
layer visibility
```

Transient/non-persistent:

```text
hover
pointer capture
snap marker
unfinished drag candidate unless explicit draft persistence is designed
screen pixel position
IME state
```

No transient interaction state may enter generation provenance.

---

# 22. Error/cancel semantics

Interaction failure codes are typed and independent from user strings.

Examples:

```text
editor.hit.target-stale
editor.selection.target-missing
editor.snap.no-candidate
editor.interaction.stale-version
editor.interaction.constraint-failed
editor.interaction.host-invalid
editor.interaction.command-rejected
```

A failed/cancelled direct manipulation leaves canonical fingerprint unchanged.

---

# 23. Forward invariants

### P9-CAD-INV-001

There is one canonical project mutation path: ProjectCommand/ProjectMutationSession. Gestures/widgets do not bypass it.

### P9-CAD-INV-002

World/candidate geometry is integer-mm engineering data; screen coordinates are transient presentation data.

### P9-CAD-INV-003

P9 Wizard candidate selection and CAD entity selection are different typed concepts.

### P9-CAD-INV-004

CAD selection supports future multi-selection without changing persistent entity identity.

### P9-CAD-INV-005

Hover, focus, snap marker and viewport state are not canonical selection/state.

### P9-CAD-INV-006

Hit testing and snapping query visible/indexed semantic layers rather than scanning total project objects.

### P9-CAD-INV-007

Snap acquisition radius is screen-space UX policy converted through camera scale; snapped result is expressed in engineering coordinates.

### P9-CAD-INV-008

A drag interaction previews transient geometry and commits at most one semantic mutation/Undo record at completion.

### P9-CAD-INV-009

Resize/orientation/input-modality changes cannot change world geometry or selection identity.

### P9-CAD-INV-010

P9 candidate-local geometry is placed into canonical world coordinates through an explicit typed transform.

### P9-CAD-INV-011

No durable wall/edge/component/route host uses array/list index as identity.

### P9-CAD-INV-012

No future P13/P14 implementation introduces a second camera or mobile-specific command model incompatible with P9/P3 foundations.

---

# 24. P9 changes required by this contract

Before P9 runtime implementation begins, stage specifications MUST explicitly align as follows:

```text
P9.6   candidate-local coordinate frame + placement transform boundary
P9.8   preview viewport compatible with common camera semantics
P9.9   input operations remain presentation/application operations, not canonical writes
P9.10  preview camera/selection remain transient and do not alter frozen candidate
P9.11  apply explicit placement transform before canonical boundary materialization
P9.13  qualify camera round-trip, resize continuity, interaction-state separation and transform exactness
```

P9 does not need to implement the full snap/multi-select/direct-manipulation kernel yet. It MUST, however, avoid contracts that make those capabilities require replacement of P9 foundations.

---

# 25. Qualification matrix reserved for P13/P14

Future CAD qualification should include at least:

```text
camera screen<->world round-trip
cursor-anchored zoom
fit selection
negative world coordinates
selection replace/add/toggle/clear
selection reconciliation after entity deletion
BoundaryEdgeId lineage selection remap
screen-radius hit acquisition across zoom levels
snap deterministic tie-break
pointer drag cancel -> fingerprint unchanged
one drag -> one Undo
stale drag commit fails closed
mouse/keyboard/touch/stylus equivalent semantic operations
60 fps / hit-test / snap budgets on indexed scenes
```

P9.13 only needs the subset required to prove that P9 does not violate this architecture.

---

# 26. Final forward disposition

The desired P9 handoff to P10-P14 is:

```text
P9 generation
  produces canonical-ready semantic geometry/openings
        ↓
explicit placement/reference frame
        ↓
P3/P8 atomic mutation architecture
        ↓
shared camera + typed selection + operation dispatch boundaries
        ↓
P13 auto-placement
        ↓
P14 professional route/CAD interaction
```

If implementation follows this contract, P10-P14 extend the interaction kernel instead of replacing P9 UI/geometry foundations.
