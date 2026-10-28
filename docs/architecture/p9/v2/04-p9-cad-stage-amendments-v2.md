# P9 CAD Readiness — Stage Amendments v2

Status: **NORMATIVE AMENDMENT TO P9.6/P9.8/P9.9/P9.10/P9.11/P9.13**  
Depends on: `03-p9-cad-interaction-foundation-forward-contract-v2.md`

## 1. Purpose

This document binds the forward CAD interaction contract directly into the affected P9 stages without duplicating their full specifications.

If an affected stage v2 document is silent or conflicts on coordinate-space, placement-transform, camera, selection or interaction-dispatch semantics, this amendment wins.

---

# 2. P9.6 Geometry Generation amendments

## P9.6-CAD-FR-001 — Candidate-local frame

All P9.6 generated geometry is expressed in a typed **candidate-local integer-mm frame**.

The geometry generator MUST NOT assume that its local origin is the final project/world origin.

Conceptual contract:

```dart
final class CandidateGeometryFrame {
  final String frameCode; // stable semantic code, v1 = apartmentLocal
}
```

The frame itself is semantic metadata; screen/viewport information is forbidden.

## P9.6-CAD-FR-002 — Explicit target transform boundary

P9.6 does not perform final target placement.

The handoff to materialization is:

```text
ApartmentGeometryCandidate(candidate-local mm)
+
OrthogonalPlacementTransformMm
```

P9 v1 may use identity transform, but the transform must still be explicit in application/materialization contracts.

## P9.6-CAD-INV-001

`geometryFingerprint` identifies candidate-local semantic geometry and MUST NOT change merely because a later P10/P11 consumer places the same candidate at another world translation.

Rotation/mirroring already intrinsic to a P9 variant seed remains part of candidate geometry identity; target-level placement transform is a separate composition fact.

## P9.6-CAD-AT-001

The same candidate generated for two different target placement origins has identical candidate-local `geometryFingerprint`.

## P9.6-CAD-AT-002

No screen logical pixel, device pixel or camera value appears in the P9.6 geometry serialization.

---

# 3. P9.8 Renderer amendments

## P9.8-CAD-FR-001 — Common camera semantics

P9 preview viewport MUST use camera semantics compatible with the shared ElecX world-camera contract:

```text
world/candidate centre
mmPerLogicalPixel or equivalent scale
screenToWorld/worldToScreen
pan
zoomAtAnchor
fitBounds
```

`PreviewViewportState` is a presentation adapter, not a second independent camera architecture.

## P9.8-CAD-FR-002 — Coordinate adapter

Renderer explicitly chooses one source frame:

```text
candidate-local preview frame
or
reserved/materialized world frame
```

The choice must be typed and testable. No rendering layer may silently mix both frames.

## P9.8-CAD-INV-001

Zoom, pan, fit and responsive relayout cannot change candidate-local geometry, target placement transform or P8 reserved IDs.

## P9.8-CAD-AT-001

Zoom-at-anchor preserves the same projected engineering point within documented integer-mm inverse-rounding tolerance.

## P9.8-CAD-AT-002

Viewport resize changes screen projection only; vector semantic scene and candidate fingerprint remain unchanged.

---

# 4. P9.9 ApartmentWizardProvider amendments

## P9.9-CAD-FR-001 — Candidate selection != CAD selection

`ApartmentCandidateSelection` identifies one generated Wizard answer.

It MUST NOT be reused as the future `EditorSelectionState` for canonical Spaces/Openings/Components/Routes.

Naming and packages should make this distinction obvious.

## P9.9-CAD-FR-002 — Operation dispatch boundary

Wizard input adapters dispatch semantic Wizard operations.

They may not directly mutate `ProjectAggregateRoot`.

Canonical effects remain:

```text
P8/P9 semantic action
 -> ReservedProjectCommand / ProjectCommand
 -> ProjectMutationSession
 -> atomic commit
```

## P9.9-CAD-INV-001

Responsive shell, input modality and candidate-card focus/hover are presentation/session state and cannot become canonical editor selection automatically after Apply.

After Apply, any editor selection of the newly created apartment is an explicit navigation/editor action using canonical IDs.

---

# 5. P9.10 Preview/Diff amendments

## P9.10-CAD-FR-001 — Preview frame explicitness

Preview scene metadata MUST declare whether coordinates are candidate-local or frozen reserved/materialized-world projection.

The recommended P8 integration path is:

```text
frozen reserved candidate
 + frozen placement transform
 -> preview world projection
```

so the geometry shown before Apply is exactly the geometry that materialization will commit.

## P9.10-CAD-FR-002 — Viewport non-semantic

Camera state, selected Diff row, preview hover and zoom are excluded from:

```text
ProjectSemanticChangeSet
candidateFingerprint
LocalProjectVersion
UndoRecord
provenance
```

## P9.10-CAD-INV-001

Changing only preview camera state cannot make a fresh P8 reservation stale.

## P9.10-CAD-AT-001

Pan/zoom/fit repeated between Preview and Apply produces identical committed canonical fingerprint.

---

# 6. P9.11 Materialization amendments

## P9.11-CAD-FR-001 — Frozen placement transform

Before reserved Preview preparation, determine/freeze:

```dart
final class OrthogonalPlacementTransformMm {
  final int translateXmm;
  final int translateYmm;
  final int quarterTurnsClockwise;
  final bool mirrorX;
}
```

For P9 v1 empty-Level flow the production default is one documented deterministic transform, normally identity at the Level/world reference origin.

The exact transform used by Preview MUST be the exact transform used by Apply.

## P9.11-CAD-FR-002 — Transform before canonical topology

Materialization pipeline:

```text
candidate-local polygon/segments/opening intents
  ↓ apply frozen placement transform
world integer-mm geometry
  ↓
reserve/map BoundaryEdgeId + OpeningId hosts
  ↓
CandidateGraphValidator
  ↓
commit
```

Do not convert via screen coordinates or renderer matrices.

## P9.11-CAD-FR-003 — Exact integer orthogonal transform

For P9/P10 v1 orthogonal geometry:

```text
translation = integer mm
rotation    = quarter-turn integer 0..3
mirror      = explicit boolean
```

Transform implementation must avoid floating-point drift.

## P9.11-CAD-FR-004 — Provenance/composition evidence

Applied placement transform is retained in generation/composition evidence when necessary for exact reconstruction, especially once P10 composes multiple apartment instances.

P9 v1 identity transform may be omitted from compact persistence only if schema semantics make identity unambiguous and round-trip tests prove exact reconstruction.

## P9.11-CAD-INV-001

`candidateFingerprint` remains the identity of candidate-local answer; canonical project fingerprint includes the resulting transformed world geometry.

## P9.11-CAD-INV-002

Boundary/opening host identity is derived after transform from semantic segment mapping and reserved typed IDs, never from visual edge ordering.

## P9.11-CAD-AT-001

Identity transform materializes coordinates exactly equal to candidate-local coordinates.

## P9.11-CAD-AT-002

Quarter-turn + translation fixture produces exact expected integer world coordinates with no drift.

## P9.11-CAD-AT-003

Preview and Apply use byte-identical frozen placement-transform parameters.

## P9.11-CAD-AT-004

Undo/Redo preserves generated world geometry and typed IDs independent of current viewport.

---

# 7. P9.13 Qualification amendments

The following become merge-blocking P9 qualification items.

## P9.13-CAD-AT-001 — Coordinate-space purity

Static/contract tests prove:

```text
candidate geometry uses candidate-local integer mm
canonical geometry uses world integer mm
viewport uses logical px/transient scale
no pixel value enters project/candidate fingerprints
```

## P9.13-CAD-AT-002 — Placement exactness

Test identity, translation and representative quarter-turn/mirror transform utilities independently from UI.

The P9 production Golden Journey uses its documented v1 target transform and verifies Preview == Apply transformed geometry.

## P9.13-CAD-AT-003 — Camera round trip

For representative bounds/negative coordinates/zoom levels:

```text
world -> screen -> world
```

returns the expected integer point within the documented inverse projection rounding tolerance.

## P9.13-CAD-AT-004 — Cursor/touch anchored zoom

Zoom around an anchor keeps the same underlying engineering point beneath the anchor within tolerance.

## P9.13-CAD-AT-005 — Viewport independence

Run the same candidate through:

```text
390x844
768x1024
1440x900
```

with different pan/zoom states and prove identical candidate/vector semantic fingerprints.

## P9.13-CAD-AT-006 — Selection-type separation

Contract tests prove Wizard candidate selection cannot be passed where canonical CAD `EditorSelectionTarget` is required and vice versa.

## P9.13-CAD-AT-007 — No viewport mutation

Thousands of viewport operations produce:

```text
same LocalProjectVersion
same Undo count
same canonical fingerprint
same P8 reservation identity
```

## P9.13-CAD-AT-008 — Resize/orientation with prepared Preview

Resize/orientation preserves the same frozen placement transform and P8 candidate; Apply result remains identical.

## P9.13-CAD-NFR-001 — Interaction kernel baseline

P9 preview camera operations must not cause P9 generator rerun and should maintain interactive frame pacing on representative bounded apartment scenes.

The full P13/P14 spatial-index snap/hit-test budgets are reserved by the forward contract and are not required to be implemented by P9.

---

# 8. Forward P13/P14 requirements reserved by P9

P9 need not implement these features, but current code must not make them impossible without architectural replacement:

```text
typed multi-selection with primary entity
hover/focus separated from selection
layer-aware indexed hit testing
screen-radius snap acquisition
endpoint/midpoint/intersection/perpendicular/nearest/wall/guide snap
pointer-captured interaction sessions
transient drag candidate
one completed drag = one ProjectCommand = one Undo
box/crossing selection
component placement candidates
route vertex/segment editing
stable BoundaryEdgeId/host-based snapping
```

---

# 9. Exit condition

P9 design remains `READY FOR IMPLEMENTATION` only if implementation plans and tests honor this amendment.

A runtime implementation that introduces any of the following is a P9 design regression and merge blocker:

```text
screen pixels persisted as geometry
a second incompatible camera model
candidate selection reused as CAD entity selection
direct widget/controller mutation of canonical project state
wallIndex/list-index durable host identity
viewport resize triggering regeneration
Apply using a placement transform different from Preview
```
