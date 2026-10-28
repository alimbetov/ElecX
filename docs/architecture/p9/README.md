# P9 Apartment Topology Generator — Specification Index

Branch: `feat/p9-apartment-topology-generator`

## Current authority

The original v1 stage documents remain historical design records. The authoritative implementation/acceptance set is:

```text
../p9-architecture-audit-v1-2026-10-24.md       prerequisite/code readiness
v2/00-p9-specification-quality-baseline-v2.md  quality/traceability rules
v2/01-p9-shared-contracts-v2.md                 cross-stage value objects
v2/02-p9-cross-platform-responsive-input-contract-v2.md
                                                 responsive/input architecture
v2/03-p9-cad-interaction-foundation-forward-contract-v2.md
                                                 coordinate/camera/selection/snap/command contract
v2/04-p9-cad-stage-amendments-v2.md             normative stage amendments
v2/05-p9-associative-parametric-editing-forward-contract-v2.md
                                                 editability/provenance forward contract
v2/p9.1-...v2.md ... v2/p9.13-...v2.md          stage specifications
p9-final-technical-review-2026-10-28.md         implementation review + merge blockers
p9.13-requirement-traceability-v1.md            hard-requirement -> test -> gate mapping
p9-acceptance-audit-v1-2026-10-28.md            live exact-SHA acceptance record
v2/98-p9-p10-p14-cad-readiness-audit-v2.md     forward CAD readiness audit
v2/99-p9-cross-stage-architecture-audit-v2.md  cross-stage architecture audit
```

`03`, `04` and `05` are normative forward contracts. If an affected stage document is silent or conflicts on coordinate/camera/selection/direct-manipulation/editability/propagation semantics, these forward contracts win.

The historical defect-discovery pool is not a current runtime-status authority.

## Current formal status

```text
P9 = IMPLEMENTED, QUALIFICATION INCOMPLETE
```

P9.1-P9.12 are feature-complete and qualified through the repository regression suite and targeted P9 qualification. P9.13 acceptance-hardening is implemented, but the branch may not be marked accepted until one exact final SHA passes every P9.13 hard gate, including `H exact-SHA final audit`, and is not behind `main`.

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
P9.13 final qualification / Golden Journeys             IMPLEMENTED / EXACT-SHA CI PENDING

Cross-platform responsive/input contract               IMPLEMENTED / FINAL CI PENDING
CAD interaction forward contract                       DEFINED
Associative/parametric editing forward contract        DEFINED FOR FORWARD STAGES
```

A green workflow from an older SHA never qualifies a newer code, test or documentation commit.

## P9.13 hardening now present

The final acceptance layer includes:

```text
A  Domain qualification
   250 supported requests
   100 invalid requests
   1500 property/fuzz cases
   10 deterministic repetitions per supported request

B  Engineering qualification
   topology-only
   engineering-enabled
   frozen proposal
   provenance

C  Transactional qualification
   Preview/Diff
   Apply
   Undo/Redo
   Save/Reopen

D  Desktop
   Linux / Windows / macOS native compilation

E  Mobile
   Android native compilation
   iOS native compilation

F  Tablet
   Android tablet / iPadOS responsive semantics

G  Cross-platform semantic parity
   Linux == macOS == Windows semantic artifacts

H  Exact-SHA final audit
   repository format/analyze/full test prerequisite
   complete A-G/native dependency closure
```

Golden Journeys now cover:

```text
GJ-01 Generate -> Preview -> Apply -> Undo/Redo -> Save/Reopen
      -> manual rename -> canonical geometry edit -> provenance override persistence
GJ-02 existing multi-level/multi-building isolation
GJ-03 phone/tablet/desktop + locale/theme/text-scale continuity
      -> compact full Diff -> exact preserved Apply
GJ-04 keyboard / mouse / touch / stylus-as-pointer semantic equality
```

Negative journeys NG-01..10 are explicitly mapped in `p9.13-requirement-traceability-v1.md`.

## Runtime mode policy

P9 topology generation and the additive D1-D8 electrical engineering capability remain intentionally separated.

### Topology-only

When no authoritative `ApartmentEngineeringPipeline` is configured:

```text
ApartmentWizardProvider.geometryOnly()
  -> deterministic topology candidates
  -> Preview/Diff
  -> canonical materialization
  -> provenance/persistence
  -> Apply/Undo/Redo
```

No electrical values are assumed and no engineering proposal is persisted.

### Engineering-enabled

With an authoritative pipeline:

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

Preview reads the frozen proposal; Apply does not rerun engineering. Qualification fixture values are never promoted to authoritative production defaults.

## Core domain decisions

```text
requested area = interior net area excluding balcony/loggia/terrace
balcony/loggia area = separate template-controlled appendage area
kitchenLiving != openPlan
openPlan = distinct kitchen + living with explicit open connection
exterior exposure preference != actual Building facade orientation
P9 = one apartment into one empty Level
geometry = integer-mm rectilinear candidate, not SVG
entry + internal access = canonical openings with BoundaryEdgeId host
candidate browsing allocates no canonical IDs
Apply commits the exact P8 frozen candidate/reservation
provenance is persisted and field-override aware
P9 does not claim statutory architectural compliance
```

## Cross-platform decisions

One shared width-class authority is used by production and qualification:

```text
COMPACT     < 600
MEDIUM      600..1023
EXPANDED    1024..1439
LARGE       >= 1440
```

`ElecXPresentationPolicy` may reduce pane density for accessibility/text scaling, but it does not redefine these width classes and cannot alter domain semantics.

```text
same request + semantic versions = same ordered candidate fingerprints
layout is viewport/capability-driven, not OS-name-driven
desktop = primary professional authoring
tablet  = full Wizard/review + practical authoring
phone   = full Wizard/review/Preview/Diff/Apply + lightweight editing
full semantic Diff remains reachable on COMPACT
explicit Previous/Next + swipe + keyboard navigation share one selection semantic
mouse/keyboard/touch/stylus map to common semantic operations
orientation/window resize preserves Wizard reservation/state
preview zoom/pan is transient and non-canonical
```

## CAD / associative forward decisions

Generated apartments remain ordinary editable canonical geometry after Apply. P9 qualification now proves that a real canonical boundary edit preserves durable boundary identity and marks field-aware geometry provenance overrides.

The complete future associative solver, generalized engineering graph, placement, routing and selective regeneration remain P11-P15 scope.

## Merge gates

```text
C1 explicit production/topology runtime composition                 CLOSED
C2 one frozen Generate -> Preview/Diff -> Apply command             CLOSED
C3 frozen D8 circuits/cable/protection/RCD/SLD/Why Preview          CLOSED
C4 production persistence-owner reload of engineering snapshot      CLOSED
C5 exact Apply -> Undo -> Redo engineering snapshot                 CLOSED
C6 stale/tamper fail-closed qualification                           CLOSED
C7 exact final HEAD complete repository + P9.13 CI                  OPEN UNTIL GREEN
C8 docs/repository hygiene + behind main == 0                       RECHECK AT FINAL SHA
```

The specialized `.github/workflows/p9-final-acceptance.yml` is self-contained: `H exact-SHA final audit` cannot pass unless repository formatting, analysis, P8 a11y/i18n regressions, the complete Flutter suite, P9 A-G gates and native compilation gates all pass.

## Current disposition

```text
P9 specification quality                  STRONG
P9.1-P9.12 runtime                        IMPLEMENTED / QUALIFIED
P9.13 acceptance infrastructure           IMPLEMENTED
cross-platform semantic parity            IMPLEMENTED / FINAL SHA RECHECK REQUIRED
responsive/input contract                 IMPLEMENTED / FINAL SHA RECHECK REQUIRED
repository traceability/audit             PRESENT
P9 overall                                IMPLEMENTED, QUALIFICATION INCOMPLETE
```

No additional P9 product scope should be added unless final acceptance exposes a real defect. The next valid state is `P9 = ACCEPTED FOR MERGE`, and it is allowed only after an exact-final-SHA green run.
