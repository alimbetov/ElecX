# P9 Apartment Topology Generator — Specification Index

Branch: `feat/p9-apartment-topology-generator`

## Current authority

The original v1 stage documents remain historical design records.

For implementation, the **v2 specification pack is authoritative** together with the project foundation/P8 decisions.

Read in this order:

```text
../p9-architecture-audit-v1-2026-10-24.md       prerequisite/code readiness
v2/00-p9-specification-quality-baseline-v2.md  quality/traceability rules
v2/01-p9-shared-contracts-v2.md                 common cross-stage value objects
v2/02-p9-cross-platform-responsive-input-contract-v2.md
                                                 desktop/tablet/mobile responsive + input architecture
v2/03-p9-cad-interaction-foundation-forward-contract-v2.md
                                                 coordinate/camera/selection/snap/command forward architecture
v2/04-p9-cad-stage-amendments-v2.md            normative amendments to affected P9 stages
v2/p9.1-...v2.md                                stage specifications
...
v2/p9.13-...v2.md
v2/98-p9-p10-p14-cad-readiness-audit-v2.md     forward CAD readiness audit
v2/99-p9-cross-stage-architecture-audit-v2.md  overall consistency audit / design disposition
```

`03` and `04` are normative for coordinate-space, placement-transform, camera, CAD-selection and interaction-dispatch semantics. If an affected stage document is silent or conflicts on those topics, `03/04` win.

## Stage status

```text
P9.0  specification / prerequisite audit          DONE
P9.1  ApartmentWizardParameters                   V2 READY FOR IMPLEMENTATION
P9.2  ApartmentTopologyCatalog                    V2 READY FOR IMPLEMENTATION
P9.3  topology families / grammars                V2 READY FOR IMPLEMENTATION
P9.4  deterministic area fitting                  V2 READY FOR IMPLEMENTATION
P9.5  adjacency + wet-core rules                  V2 READY FOR IMPLEMENTATION
P9.6  geometry generation                         V2 READY FOR IMPLEMENTATION + CAD AMENDMENT
P9.7  candidate scoring/ranking                   V2 READY FOR IMPLEMENTATION
P9.8  SVG/vector topology renderer                V2 READY FOR IMPLEMENTATION + CAD AMENDMENT
P9.9  ApartmentWizardProvider                     V2 READY FOR IMPLEMENTATION + CAD AMENDMENT
P9.10 P8 Preview/Diff integration                 V2 READY FOR IMPLEMENTATION + CAD AMENDMENT
P9.11 canonical Spaces/StructuralZone materialization V2 READY FOR IMPLEMENTATION + CAD AMENDMENT
P9.12 provenance                                  V2 READY FOR IMPLEMENTATION
P9.13 qualification / Golden Journey              V2 READY FOR IMPLEMENTATION + CAD AMENDMENT

Cross-platform responsive/input contract             V2 READY FOR IMPLEMENTATION
CAD interaction forward contract                     V2 READY FOR IMPLEMENTATION
P10-P14 CAD readiness audit                          PASS
runtime implementation                               NOT STARTED
```

## Authoritative dependency chain

```text
quality baseline
      +
shared contracts
      +
cross-platform responsive/input contract
      +
CAD interaction forward contract / stage amendments
               ↓
              P9.1
               ↓
              P9.2
               ↓
              P9.3
               ↓
              P9.4
               ↓
              P9.5
               ↓
              P9.6
             ↙    ↘
          P9.7    opening intents
             ↓      ↓
          P9.8      │
             ↘     ↙
              P9.9
               ↓
             P9.10
               ↓
             P9.11
               ↓
             P9.12
               ↓
             P9.13
```

P9.8 may be implemented in parallel once P9.6 candidate geometry is frozen. P9.12 schema work may begin earlier, but acceptance depends on materialized P9.11 entities.

## Key v2 domain decisions

```text
requested area = interior net area excluding balcony/loggia/terrace
balcony/loggia area = separate template-controlled appendage area
kitchenLiving != openPlan
openPlan = distinct kitchen + living with explicit open connection
exterior exposure preference != actual Building facade orientation
P9 v1 = one apartment into one empty Level
geometry = integer-mm rectilinear candidate, not SVG
entry + required internal access = real canonical openings with BoundaryEdgeId host
candidate browsing allocates no canonical IDs
Apply commits exact P8 frozen candidate/reservation
provenance is persisted and field-override aware
P9 does not claim statutory architectural compliance
```

## Key cross-platform decisions

```text
same request + semantic versions = same ordered candidate fingerprints
layout is capability/viewport-driven, not OS-name-driven
COMPACT  < 600
MEDIUM   600..1023
EXPANDED 1024..1439
LARGE    >= 1440

desktop = primary professional authoring
tablet  = full Wizard/review + practical authoring
phone   = full Wizard/review/Preview/Diff/Apply + lightweight editing

phone/tablet do not use weaker generator semantics
full semantic Diff remains available on COMPACT
mouse/keyboard/touch/stylus map to common semantic operations
hover/right-click/long-press are never sole access paths
orientation/window resize preserves Wizard state
preview zoom/pan is transient and non-canonical
```

## Key CAD-forward decisions

```text
candidate geometry has an explicit candidate-local integer-mm frame
canonical project geometry uses project/world integer-mm coordinates
candidate-local -> world uses explicit OrthogonalPlacementTransformMm
P9 v1 freezes one deterministic target placement transform before Preview
Preview and Apply use the exact same frozen placement transform

one shared camera semantic model:
  world centre + mmPerLogicalPixel
  screenToWorld / worldToScreen
  cursor/touch anchored zoom
  fit/visible bounds

ApartmentCandidateSelection != future EditorSelectionState
future CAD selection is typed and multi-entity with primary selection
hover/focus/snap marker/viewport are not canonical selection

hit testing is camera -> spatial index -> semantic filter -> exact geometry
snap acquisition is screen-space UX policy converted into world mm
future snap supports endpoint/midpoint/intersection/perpendicular/nearest/wall/guide/grid

pointer drag = transient preview during move
pointer up/confirm = one validated ProjectCommand = one UndoRecord
widgets/gestures never mutate canonical stores directly

BoundaryEdgeId/typed IDs remain durable host/selection identity
wallIndex/list position/screen segment index are forbidden durable identities
```

## Responsive qualification targets

```text
PHONE
390x844
844x390

TABLET
768x1024
1024x768
1366x1024

DESKTOP
800x600
1280x720
1440x900
1920x1080

text scale: 1.0 / 1.3 / 2.0
locale: RU / EN
```

P9.13 additionally qualifies keyboard-only, mouse+keyboard, touch-only, resize/orientation, representative stylus semantics and the P9 subset of the CAD-forward coordinate/camera contract.

## Implementation gates

```text
Gate A  shared domain + responsive/input + CAD-forward contracts + P9.1
Gate B  P9.2 catalog integrity/coverage
Gate C  P9.3-P9.5 semantic generator
Gate D  P9.6 candidate-local geometry + openings + placement-frame contract
Gate E  P9.7/P9.8 ranking + responsive vector renderer + common camera semantics
Gate F  P9.9 provider/session + responsive Wizard shell + operation dispatch boundary
Gate G  P9.10 apartment-aware responsive Preview/Diff + frozen transform/camera isolation
Gate H  P9.11 atomic canonical materialization + explicit candidate-local->world transform
Gate I  P9.12 provenance/persistence
Gate J  P9.13 qualification/Golden Journey/NFR/cross-platform/CAD-forward matrix
```

A gate does not close from code presence alone. Its stage tests and exit criteria must pass.

## P10-P14 forward architecture

P9 intentionally establishes reusable foundations before CAD interaction becomes heavier:

```text
ElecXPresentationCapabilities
ElecXResponsiveWidthClass
semantic Wizard/navigation state
semantic input-operation abstraction
shared world-camera semantics
candidate-local / world coordinate distinction
OrthogonalPlacementTransformMm
typed CAD selection boundary
hit-test / snap service boundaries
interaction-session / preview-then-command rule
keyboard shortcut mapping
focus/a11y policy
safe-area / window-resize handling
```

Expected reuse:

```text
P10 building/ЖК generation
    multiple P9 apartment candidates + explicit placement transforms

P11 EngineeringGraph
    stable canonical selection/navigation/inspection

P12 engineering generation
    same candidate/Preview/Diff/atomic command semantics

P13 auto-placement
    typed selection + hit-test/snap + placement candidate + ProjectCommand

P14 CAD routing
    shared camera + indexed hit test + snap + interaction session + one-command commit
```

No P10-P14 phase should introduce a second desktop/mobile domain model, second camera model or second transaction path.

## Historical spatial-editor compatibility note

Historical `feat/spatial-editor-foundation-p2` remains useful evidence for:

```text
WorldCamera semantics
SpatialSceneIndex
screen-space acquisition radius
LOD/adaptive grid
keyboard/viewport adapters
```

but it is not current authority. In particular its historical `700/1180` device breakpoints, controller-owned direct mutations, single-object selection and grid-only snap behavior must not become new production contracts.

If code is reused from that branch, it must be adapted to the v2 P9 responsive/CAD-forward contracts above.

## Final design disposition

See both:

```text
v2/98-p9-p10-p14-cad-readiness-audit-v2.md
v2/99-p9-cross-stage-architecture-audit-v2.md
```

```text
P9 specification consistency        = PASS
cross-platform architecture         = PASS
P10-P14 CAD forward readiness       = PASS
blocking design ambiguity           = 0
runtime implementation              = NOT STARTED
design disposition                  = READY FOR IMPLEMENTATION
```
