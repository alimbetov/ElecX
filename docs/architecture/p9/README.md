# P9 Apartment Topology Generator — Specification Index

Branch: `feat/p9-apartment-topology-generator`

## Current authority

The original v1 stage documents remain historical design records.

For implementation, the **v2 specification pack is authoritative** together with the project foundation/P8 decisions and the final technical review:

```text
../p9-architecture-audit-v1-2026-10-24.md       prerequisite/code readiness
v2/00-p9-specification-quality-baseline-v2.md  quality/traceability rules
v2/01-p9-shared-contracts-v2.md                 common cross-stage value objects
v2/02-p9-cross-platform-responsive-input-contract-v2.md
                                                 responsive/input architecture
v2/03-p9-cad-interaction-foundation-forward-contract-v2.md
                                                 coordinate/camera/selection/snap/command contract
v2/04-p9-cad-stage-amendments-v2.md             normative stage amendments
v2/05-p9-associative-parametric-editing-forward-contract-v2.md
                                                 editability/provenance forward contract
v2/p9.1-...v2.md ... v2/p9.13-...v2.md          stage specifications
p9-final-technical-review-2026-10-28.md         final implementation/merge gates
v2/98-p9-p10-p14-cad-readiness-audit-v2.md     forward CAD readiness audit
v2/99-p9-cross-stage-architecture-audit-v2.md  cross-stage architecture audit
```

`03`, `04` and `05` are normative forward contracts. If an affected stage document is silent or conflicts on coordinate/camera/selection/direct-manipulation/editability/propagation semantics, these forward contracts win.

The historical defect-discovery pool records the earlier remediation phase. It is not the current runtime status authority; closed findings and final merge gates are recorded in `p9-final-technical-review-2026-10-28.md`.

## Current runtime status

P9 is a **feature-complete merge candidate**. Final acceptance is SHA-bound: the exact final branch HEAD must pass the complete repository CI workflow and must not be behind `main`.

```text
P9.0  specification / prerequisite audit               DONE
P9.1  ApartmentWizardParameters                        IMPLEMENTED / QUALIFIED
P9.2  ApartmentTopologyCatalog                         IMPLEMENTED / QUALIFIED
P9.3  topology families / grammars                     IMPLEMENTED / QUALIFIED
P9.4  deterministic area fitting                       IMPLEMENTED / QUALIFIED
P9.5  adjacency + wet-core rules                       IMPLEMENTED / QUALIFIED
P9.6  geometry generation + engineering extension      IMPLEMENTED / QUALIFIED
P9.7  candidate scoring/ranking                        IMPLEMENTED / QUALIFIED
P9.8  vector topology renderer                         IMPLEMENTED / QUALIFIED
P9.9  ApartmentWizardProvider                          IMPLEMENTED / QUALIFIED
P9.10 P8 Preview/Diff integration                      IMPLEMENTED / QUALIFIED
P9.11 canonical Spaces/StructuralZone materialization  IMPLEMENTED / QUALIFIED
P9.12 provenance / persistence                         IMPLEMENTED / QUALIFIED
P9.13 qualification / Golden Journey                   IMPLEMENTED / FINAL CI GATE

Cross-platform responsive/input contract               DEFINED / QUALIFIED BY CI NFR
CAD interaction forward contract                       DEFINED
Associative/parametric editing forward contract        DEFINED FOR FORWARD STAGES
```

The earlier `1239 passed / 15 failed` baseline is historical and superseded by the current remediation/qualification work. It must not be used as the acceptance status of the branch.

## Runtime mode policy

P9 topology generation and the additive D1-D8 electrical engineering capability are intentionally separated.

### Topology-only mode

When no authoritative `ApartmentEngineeringPipeline` is configured:

```text
ApartmentWizardProvider.geometryOnly()
  -> deterministic topology candidates
  -> Preview/Diff
  -> canonical materialization
  -> provenance/persistence
  -> Apply/Undo/Redo
```

No electrical values are assumed and no engineering proposal is persisted. Preview explicitly communicates that engineering output requires authoritative electrical inputs.

### Engineering-enabled mode

When an authoritative pipeline is configured:

```text
D1 requirements
  -> authoritative supply evidence
  -> load calculation
  -> circuit synthesis
  -> D2 -> D3 -> D4 -> D5 -> D6 -> D7 -> D8
  -> immutable ApartmentEngineeringProposal
  -> frozen Wizard command
  -> Preview/Diff
  -> Apply exact frozen proposal
```

The pipeline runs during generation. Preview reads the frozen proposal; Apply does not rerun the engineering pipeline.

Production fixture values are never promoted to authoritative defaults merely to make the pipeline pass.

## Authoritative dependency chain

```text
quality baseline
      +
shared contracts
      +
responsive/input contract
      +
CAD-forward / associative forward contracts
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

## Core domain decisions

```text
requested area = interior net area excluding balcony/loggia/terrace
balcony/loggia area = separate template-controlled appendage area
kitchenLiving != openPlan
openPlan = distinct kitchen + living with explicit open connection
exterior exposure preference != actual Building facade orientation
P9 v1 = one apartment into one empty Level
geometry = integer-mm rectilinear candidate, not SVG
entry + required internal access = canonical openings with BoundaryEdgeId host
candidate browsing allocates no canonical IDs
Apply commits the exact P8 frozen candidate/reservation
provenance is persisted and field-override aware
P9 does not claim statutory architectural compliance
```

## Cross-platform decisions

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

## CAD-forward decisions

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

pointer drag = transient preview during move
pointer up/confirm = one validated ProjectCommand = one UndoRecord
widgets/gestures never mutate canonical stores directly

BoundaryEdgeId/typed IDs remain durable host/selection identity
wallIndex/list position/screen segment index are forbidden durable identities
```

## Associative / parametric editing decisions

Generated apartments remain ordinary editable canonical geometry after Apply. The forward contract preserves stable boundary/host/provenance semantics so later direct manipulation and selective regeneration do not require a second room model.

```text
room width/length edit
  -> boundary displacement
  -> constraint/propagation candidate
  -> validation
  -> Preview/Diff where material
  -> one ProjectCommand / one UndoRecord
```

The complete future associative solver is not part of P9 acceptance.

## Merge gates

The final technical review defines C1-C8. Current implementation disposition:

```text
C1 explicit production/topology runtime composition                 CLOSED
C2 one frozen Generate -> Preview/Diff -> Apply command             CLOSED
C3 frozen D8 circuits/cable/protection/RCD/SLD/Why Preview          CLOSED
C4 production persistence-owner reload of engineering snapshot      CLOSED
C5 exact Apply -> Undo -> Redo engineering snapshot                 CLOSED
C6 stale/tamper fail-closed qualification                           CLOSED
C7 exact final HEAD complete CI                                     REQUIRED AT MERGE
C8 docs/repository hygiene + behind main == 0                       REQUIRED AT MERGE
```

A green workflow from an older SHA never qualifies a newer commit. Any new branch commit reopens C7 until that exact SHA is green.

## P10-P15 forward architecture

P9 establishes reusable foundations for later CAD/engineering stages:

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

No P10-P15 phase should introduce a second desktop/mobile domain model, second camera model, second room geometry model or second transaction path.

## Current disposition

```text
P9 specification quality                  STRONG
cross-platform architecture               DEFINED
P10-P15 CAD forward compatibility         DEFINED
associative parametric editability        FORWARD CONTRACT DEFINED
P9 runtime                                FEATURE-COMPLETE MERGE CANDIDATE
remaining acceptance work                 exact-final-HEAD C7/C8 only
```
