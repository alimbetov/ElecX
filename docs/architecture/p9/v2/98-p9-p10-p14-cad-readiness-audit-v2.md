# P9 → P10-P14 CAD Readiness Audit v2

Date: 2026-10-24  
Branch: `feat/p9-apartment-topology-generator`  
P8 baseline: `main@c397302f183d023e4bdd670ac0c8b46c6fad994a`

## Disposition

```text
P9 domain/generation contracts                   PASS
P9 cross-platform responsive/input architecture PASS
P9 forward CAD interaction contract              PASS
P9 placement-frame boundary                      PASS
P10 composition compatibility                    PASS
P13 auto-placement compatibility                 PASS
P14 routing/CAD interaction compatibility        PASS
Blocking forward-design ambiguity                0
P9 runtime implementation                        NOT STARTED
Forward design disposition                       READY FOR IMPLEMENTATION
```

This audit proves **design compatibility**, not runtime correctness.

---

# 1. Audit scope

The audit reviewed P9 as the foundation immediately before heavier CAD/engineering interaction:

```text
P9 apartment generation
      ↓
P10 building / floor / residential complex composition
      ↓
P11 EngineeringGraph
      ↓
P12 starter engineering generation
      ↓
P13 auto-placement
      ↓
P14 route topology / auto-routing / CAD editing
```

Focus areas:

```text
coordinate systems
candidate-local vs world placement
camera/viewport ownership
selection model
multi-selection readiness
hit testing
snap architecture
gesture arbitration
command dispatch
direct-manipulation transaction semantics
stable host identities
responsive/mobile/tablet compatibility
render/performance boundaries
```

---

# 2. Evidence reviewed

Current authoritative P9 pack:

```text
00 quality baseline
01 shared contracts
02 cross-platform responsive/input contract
03 CAD interaction forward contract
04 CAD stage amendments
P9.1..P9.13 stage specs
99 cross-stage audit
```

Also reviewed historical spatial-editor work as **non-authoritative implementation evidence**:

```text
feat/spatial-editor-foundation-p2@572d2e91...

WorldCamera
SpatialSceneIndex
adaptive grid
screen/world transform
cursor-anchored zoom
viewport culling
screen-space hit acquisition
keyboard/viewport adapters
EditorController prototype
```

Useful concepts are carried forward; transitional implementation patterns are not adopted as authority.

---

# 3. Findings

## CAD-R01 — P9 candidate coordinates could be mistaken for final world coordinates

**Severity:** HIGH  
**Status:** CLOSED

### Risk

P9.6 previously described integer-mm geometry but did not strongly distinguish candidate-local coordinates from final Level/project placement.

That would become problematic in P10 when multiple apartments must be translated/rotated/mirrored on one floor.

### Resolution

`03` and `04` define:

```text
candidate-local integer-mm geometry
+
OrthogonalPlacementTransformMm
→ canonical project/world integer-mm geometry
```

P9 v1 uses one documented deterministic transform; P10 can provide multiple explicit transforms without changing P9 candidate polygons.

---

## CAD-R02 — PreviewViewportState could become a second camera architecture

**Severity:** HIGH  
**Status:** CLOSED

### Risk

The historical spatial-editor prototype already established a robust semantic camera model:

```text
world centre
mmPerPixel
screenToWorld
worldToScreen
cursor-anchored zoom
fit bounds
visible bounds
```

A separate P9 `scale + translation` camera with incompatible conventions would force later conversion/rewrite.

### Resolution

P9 preview viewport is now explicitly an adapter over a shared world-camera semantic model.

P10-P14 must reuse one camera kernel rather than introducing provider/device-specific camera types.

---

## CAD-R03 — Historical selection was single-object and controller-specific

**Severity:** HIGH  
**Status:** CLOSED

### Risk

Historical `EditorController` used concepts such as:

```text
selectedSpaceId
selectedOpeningId
activeSurface
```

This is insufficient for equipment placement, route editing, batch properties and CAD multi-selection.

### Resolution

Forward contract defines typed:

```text
EditorSelectionTarget
EditorSelectionState
orderedSelection
primary
```

and explicit replace/add/toggle/remove/clear operations.

Wizard `ApartmentCandidateSelection` remains a separate concept.

---

## CAD-R04 — Hover/focus/selection could become conflated

**Severity:** MEDIUM  
**Status:** CLOSED

Forward contract separates:

```text
selection
hover
keyboard/accessibility focus
active navigation context
```

Only explicit semantic operation changes selection.

---

## CAD-R05 — Grid rounding is not sufficient as the future snap architecture

**Severity:** HIGH  
**Status:** CLOSED

### Risk

Historical prototype contains useful grid snap but future P13/P14 requires:

```text
endpoint
midpoint
centre
intersection
perpendicular
nearest point
wall/boundary
route vertex
component anchor
guide
grid
```

### Resolution

Forward contract reserves typed `SnapQuery` / `SnapResult`, deterministic priority/tie-break and screen-space acquisition radius converted to world mm.

P9 itself does not implement the complete snap engine.

---

## CAD-R06 — Pointer hit testing could regress to full-project scans

**Severity:** HIGH  
**Status:** CLOSED

Historical spatial-engine architecture already proved the correct direction:

```text
pointer px
→ camera inverse
→ acquisition world bounds
→ spatial-index query
→ semantic priority
→ exact geometry test
```

P9 forward contract makes layer-aware indexed hit testing a P13/P14 invariant.

---

## CAD-R07 — Widget/controller direct mutation would conflict with P3/P8

**Severity:** CRITICAL  
**Status:** CLOSED

### Risk

Prototype controller methods directly mutated local editor state. That is acceptable historical prototype behavior but cannot be the final canonical architecture after P3/P8.

### Resolution

All geometry-changing operations converge on:

```text
ProjectCommand / ReservedProjectCommand
→ ProjectMutationSession
→ validation
→ ProjectChangeSet
→ atomic commit
→ LocalProjectVersion
→ UndoRecord
```

Presentation/controller may mutate only transient interaction state.

---

## CAD-R08 — Viewport command bus could become global command bus

**Severity:** MEDIUM  
**Status:** CLOSED

Historical `EditorViewportCommand`/notifier is treated only as a presentation adapter pattern.

It MUST NOT replace application-level semantic `ProjectCommandDispatcher`.

Viewport operations remain non-canonical and never enter Undo history.

---

## CAD-R09 — Direct manipulation transaction boundary was under-defined

**Severity:** CRITICAL  
**Status:** CLOSED

Forward rule:

```text
pointer down
→ transient interaction session
→ snapped/validated preview candidate during moves
→ pointer up/confirm
→ one ProjectCommand
→ one commit
→ one UndoRecord
```

Pointer moves do not increment LocalProjectVersion.

Cancel/Escape/pointer-cancel restores unchanged canonical fingerprint.

---

## CAD-R10 — Gesture arbitration could conflict with carousel/pan/drag

**Severity:** HIGH  
**Status:** CLOSED

Priority is now explicit:

```text
active handle
active drawing/routing/placement tool
direct manipulation
selection/hit test
viewport gesture
parent carousel/page gesture
```

Pointer ownership is determined at gesture start/context; a child CAD canvas cannot unexpectedly hand a captured drag to a parent carousel.

---

## CAD-R11 — Breakpoint policy conflict with historical spatial editor

**Severity:** MEDIUM  
**Status:** CLOSED

Historical branch used:

```text
mobile <700
tablet 700..1179
desktop >=1180
```

P9 v2 uses the new forward responsive classes:

```text
COMPACT  <600
MEDIUM   600..1023
EXPANDED 1024..1439
LARGE    >=1440
```

The historical values are **not authoritative** because that branch is a prototype and is not current P9 foundation.

If historical editor code is reused/ported, it must consume the new central responsive policy rather than retaining local breakpoint constants.

No two breakpoint systems may coexist in production application code.

---

## CAD-R12 — Candidate selection could leak into post-Apply editor selection

**Severity:** MEDIUM  
**Status:** CLOSED

Selecting Candidate 2/5 in the Wizard does not automatically create an `EditorSelectionState` over the resulting Spaces.

After Apply, navigation/editor may explicitly select:

```text
new apartment StructuralZone
or
primary generated Space
```

using canonical IDs and a documented post-command navigation policy.

---

## CAD-R13 — Transform semantics and fingerprints were ambiguous

**Severity:** HIGH  
**Status:** CLOSED

Rules:

```text
candidateFingerprint -> candidate-local generated answer
canonical project fingerprint -> transformed committed world geometry
P10 composition fingerprint -> candidate identity + placement transform + composition semantics
```

No screen/render matrix participates.

---

## CAD-R14 — Floating affine transforms could contaminate orthogonal geometry

**Severity:** HIGH  
**Status:** CLOSED

P9/P10 v1 transform policy:

```text
integer-mm translation
quarter-turn rotation
explicit mirror
```

No floating persisted matrix.

Arbitrary rotation requires a future explicit canonical-angle ADR.

---

## CAD-R15 — Stable host identities for P13/P14

**Severity:** CRITICAL  
**Status:** CLOSED

P7/P9 use `BoundaryEdgeId` for wall-hosted openings and future devices/routes.

P13/P14 may not regress to:

```text
wallIndex
list position
paint order
screen segment index
```

for durable host identity.

---

## CAD-R16 — Auto-placement and auto-routing could invent separate preview/commit flows

**Severity:** HIGH  
**Status:** CLOSED

P13/P14 generated actions should reuse the proven architecture:

```text
request
→ candidate(s)
→ validate
→ preview/diff when material
→ exact atomic command
→ provenance/Undo
```

This does not require every tiny manual edit to open a Wizard; it requires generated/batch automation to obey the same canonical mutation boundary.

---

## CAD-R17 — Multi-selection accessibility on touch was unspecified

**Severity:** MEDIUM  
**Status:** CLOSED

Mouse modifier keys are not the only path.

Touch/tablet must have an explicit discoverable multi-select mode/control when P13/P14 implements multi-selection.

Stylus remains optional.

---

## CAD-R18 — Interaction performance could depend on total project size

**Severity:** HIGH  
**Status:** CLOSED

Forward NFR reserves:

```text
60 fps normal interaction target
hit test p95 <=2ms on visible/indexed set
snap preferred p95 <=2ms, p99 <=5ms
no O(total project objects) pointer scan
```

Culling/index/LOD are mandatory for large project scale.

---

## CAD-R19 — Route geometry could become screen polyline state

**Severity:** CRITICAL  
**Status:** CLOSED

P14 route topology remains canonical world/surface engineering geometry with stable hosts/anchors.

Display simplification/LOD is projection only.

---

## CAD-R20 — Responsive/mobile implementation could fork command semantics

**Severity:** CRITICAL  
**Status:** CLOSED

One semantic operation/command architecture applies to:

```text
Windows
macOS
Linux
iPadOS
Android
iOS
```

Input modality changes operation mapping, not domain command meaning.

---

# 4. Authority map after audit

```text
Canonical project state
  project foundation/P3/P7/P8 decisions

P9 generation semantics
  P9.1..P9.13 + 01 shared contracts

Responsive/input presentation
  02 cross-platform contract

Forward CAD interaction compatibility
  03 CAD interaction foundation contract
  04 CAD stage amendments

Forward CAD readiness disposition
  this audit (98)

Overall P9 consistency
  99 cross-stage audit
```

---

# 5. P9 implementation requirements added by audit

Gate A must include typed foundations for:

```text
candidate-local geometry frame
typed placement transform
preview camera adapter/common camera semantics
clear Wizard candidate selection naming boundary
```

P9 does **not** need to implement full EditorSelectionState/SnapEngine in Gate A unless code reuse naturally requires them.

However no Gate A-D public contract may prevent their later addition without breaking P9 persisted/canonical semantics.

---

# 6. P10 handoff readiness

P10 can safely consume P9 candidates as:

```text
Apartment candidate A
 + placement transform A
Apartment candidate B
 + placement transform B
...
```

without modifying P9 geometry through renderer coordinates.

P10 can add:

```text
floor envelope fitting
apartment packing
common corridors
vertical cores
real facade orientation
```

on top of explicit candidate-local/world-frame separation.

Disposition: PASS.

---

# 7. P13 handoff readiness

P13 can build auto-placement on:

```text
canonical Spaces / SpaceUsage
BoundaryEdgeId
OpeningId
EngineeringGraph
EquipmentCatalog
placement candidates
shared hit-test/snap/camera/command boundaries
```

No P9-specific mobile/desktop domain fork exists.

Disposition: PASS.

---

# 8. P14 handoff readiness

P14 can extend:

```text
WorldViewportCamera semantics
layer-aware spatial index
EditorSelectionState
SnapQuery/SnapResult
interaction session
direct-manipulation preview
ProjectCommand commit
```

for route topology/route editing without replacing P9 architecture.

Disposition: PASS.

---

# 9. Remaining deliberate future work

Not P9 blockers:

```text
full production SnapEngine implementation             P13/P14
production multi-selection controller                 P13/P14
box/crossing/lasso selection UX                       P13/P14
route vertex stable identity details                  P14
constraint solver for arbitrary polygons              later CAD
arbitrary-angle canonical transforms                  later ADR
persistent editor camera/selection resume policy      later product decision
GPU renderer                                           profile-driven future
```

These are explicitly deferred because P9 now defines compatible boundaries rather than because they were overlooked.

---

# 10. Final decision

```text
P9 → P10 composition readiness       PASS
P9 → P13 auto-placement readiness    PASS
P9 → P14 CAD/routing readiness       PASS
blocking forward-design ambiguity    0
```

P9 remains **READY FOR IMPLEMENTATION**, subject to implementation honoring `03` and `04` and P9.13 qualification proving the P9 subset of these contracts.
