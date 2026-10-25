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
v2/05-p9-associative-parametric-editing-forward-contract-v2.md
                                                 generated geometry editability / push-pull / wall thickness / provenance
v2/p9.1-...v2.md                                stage specifications
...
v2/p9.13-...v2.md
../p9-defect-discovery-pool-2026-10-25.md       current implementation defect pool / remediation order
v2/98-p9-p10-p14-cad-readiness-audit-v2.md     forward CAD readiness audit
v2/99-p9-cross-stage-architecture-audit-v2.md  overall consistency audit / design disposition
```

`03`, `04` and `05` are normative forward contracts. If an affected stage document is silent or conflicts on coordinate/camera/selection/direct-manipulation/editability/propagation semantics, these forward contracts win.

`05` **does not create a new P9.14 roadmap stage**. It constrains P7/P9.11/P9.12/P13/P14/P15 so generated geometry remains editable and provenance-aware.

## Current runtime status

The design pack is substantially implemented through P9.6, but the runtime is **not merge-ready**.

```text
P9.0  specification / prerequisite audit               DONE
P9.1  ApartmentWizardParameters                        IMPLEMENTED
P9.2  ApartmentTopologyCatalog                         IMPLEMENTED / VERSIONED HARDENING
P9.3  topology families / grammars                     IMPLEMENTED / DIVERSITY HARDENING REQUIRED
P9.4  deterministic area fitting                       IMPLEMENTED / ARCHITECTURAL REGRESSION UNDER REMEDIATION
P9.5  adjacency + wet-core rules                       IMPLEMENTED
P9.6  geometry generation                              IMPLEMENTED / HARDENING / EXIT GATE RED
P9.7  candidate scoring/ranking                        NOT STARTED
P9.8  SVG/vector topology renderer                     NOT STARTED
P9.9  ApartmentWizardProvider                          NOT STARTED
P9.10 P8 Preview/Diff integration                      NOT STARTED
P9.11 canonical Spaces/StructuralZone materialization  NOT STARTED
P9.12 provenance                                       NOT STARTED
P9.13 qualification / Golden Journey                   PARTIAL COMPONENT QUALIFICATION

Cross-platform responsive/input contract              SPEC READY
CAD interaction forward contract                      SPEC READY
Associative/parametric editing forward contract       SPEC READY
```

Latest defect-discovery baseline before the docs-only forward-contract commits:

```text
format              PASS
flutter analyze     PASS
P8 NFR              PASS
flutter test        FAIL
1239 passed / 15 failed
```

Do not mark P9.6 accepted until the current defect pool is closed and the exact implementation HEAD is green.

## Current remediation priority

```text
WAVE A
restore pure P9.4 area-allocation boundary
unify production catalog qualification
add deterministic rejection matrix

WAVE B
complete graph-aware P9.6 geometry
preserve access/boundary/exposure constraints through handoff
implement/qualify corner + opposite-side exposure
qualify four-side appendage placement
prove 1..10 production corpus + access reachability

WAVE C
make corridorMode semantically real or remove it
implement materially distinct family grammars
request-expanded compatibility feasibility

WAVE D
maxVertices / overlap / outward-side / multi-segment-boundary / wet-core hardening
```

P9.7 must not become the primary development focus before Wave A/B are green.

## Authoritative dependency chain

```text
quality baseline
      +
shared contracts
      +
cross-platform responsive/input contract
      +
CAD interaction forward contract / stage amendments
      +
associative parametric editing forward contract
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

## Key domain decisions

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
LARGE     >= 1440

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
P9 freezes one deterministic target placement transform before Preview
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

## Key associative / parametric editing decisions

Generated apartments must remain ordinary editable canonical geometry after P9.11 Apply.

```text
room width/length edit
  -> resolves to boundary displacement
  -> constraint/propagation candidate
  -> validation
  -> Preview/Diff where material
  -> one ProjectCommand / one UndoRecord
```

Initial propagation policies:

```text
pushChain       downstream spaces translate while preserving dimensions
resizeNeighbor  driven room grows/shrinks against adjacent room while envelope stays fixed
pushUntilLock   propagation stops/rejects at explicit lock
```

Additional invariants:

```text
topology-preserving move preserves eligible BoundaryEdgeId
split/merge uses BoundaryEdgeLineage
shared room faces need recoverable coupling identity
wall thickness belongs to a wall/assembly concept, not duplicated room-edge fields
wall-thickness change declares firstFace/centerline/secondFace anchor
hosted openings/devices follow stable host boundaries
manual edit provenance distinguishes user-driven constraints from propagated consequences
P15 regeneration reconciles the driver constraint, not stale dependent coordinates
no platform gets a different propagation engine
```

The full associative solver is **not** implemented during current P9.6 defect remediation. P9.6/P9.11 must, however, avoid data-model choices that make this contract impossible later.

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
        + editable stable boundary/host/coupling compatibility
Gate I  P9.12 provenance/persistence + manual-edit override compatibility
Gate J  P9.13 qualification/Golden Journey/NFR/cross-platform/CAD-forward matrix
```

A gate does not close from code presence alone. Its stage tests and exit criteria must pass.

## P10-P15 forward architecture

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
stable boundary identity / lineage
shared-boundary coupling boundary
hosted-object identity
field-aware provenance
```

Expected reuse:

```text
P10 building/ЖК generation
    multiple P9 apartment candidates + explicit placement transforms

P11 EngineeringGraph
    stable canonical selection/navigation/inspection + host identities

P12 engineering generation
    same candidate/Preview/Diff/atomic command semantics

P13 auto-placement
    typed selection + hit-test/snap + placement candidate + ProjectCommand

P14 CAD routing / direct manipulation
    shared camera + indexed hit test + snap + interaction session
    + boundary displacement / propagation semantics

P15 selective regeneration
    generated baselines + user-driven overrides + propagated effects
```

No P10-P15 phase should introduce a second desktop/mobile domain model, second camera model, second room geometry model or second transaction path.

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

## Current disposition

```text
P9 specification quality                  STRONG
cross-platform architecture               DEFINED
P10-P15 CAD forward compatibility         DEFINED
associative parametric editability        DEFINED
current P9 runtime                        NOT ACCEPTED
current blocker source                    P9.4/P9.6 remediation
next action                               defect Wave A -> Wave B
```
