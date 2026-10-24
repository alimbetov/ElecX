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
v2/p9.1-...v2.md                                stage specifications
...
v2/p9.13-...v2.md
v2/99-p9-cross-stage-architecture-audit-v2.md  consistency audit / final design disposition
```

## Stage status

```text
P9.0  specification / prerequisite audit          DONE
P9.1  ApartmentWizardParameters                   V2 READY FOR IMPLEMENTATION
P9.2  ApartmentTopologyCatalog                    V2 READY FOR IMPLEMENTATION
P9.3  topology families / grammars                V2 READY FOR IMPLEMENTATION
P9.4  deterministic area fitting                  V2 READY FOR IMPLEMENTATION
P9.5  adjacency + wet-core rules                  V2 READY FOR IMPLEMENTATION
P9.6  geometry generation                         V2 READY FOR IMPLEMENTATION
P9.7  candidate scoring/ranking                   V2 READY FOR IMPLEMENTATION
P9.8  SVG/vector topology renderer                V2 READY FOR IMPLEMENTATION
P9.9  ApartmentWizardProvider                     V2 READY FOR IMPLEMENTATION
P9.10 P8 Preview/Diff integration                 V2 READY FOR IMPLEMENTATION
P9.11 canonical Spaces/StructuralZone materialization V2 READY FOR IMPLEMENTATION
P9.12 provenance                                  V2 READY FOR IMPLEMENTATION
P9.13 qualification / Golden Journey              V2 READY FOR IMPLEMENTATION

Cross-platform responsive/input contract             V2 READY FOR IMPLEMENTATION
runtime implementation                               NOT STARTED
```

## Authoritative dependency chain

```text
quality baseline
      +
shared contracts
      +
cross-platform responsive/input contract
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

P9.13 additionally qualifies keyboard-only, mouse+keyboard, touch-only, resize/orientation and representative stylus semantics.

## Implementation gates

```text
Gate A  shared domain + responsive/input contracts + P9.1
Gate B  P9.2 catalog integrity/coverage
Gate C  P9.3-P9.5 semantic generator
Gate D  P9.6 geometry + openings
Gate E  P9.7/P9.8 ranking + responsive vector renderer
Gate F  P9.9 provider/session + responsive Wizard shell
Gate G  P9.10 apartment-aware responsive Preview/Diff
Gate H  P9.11 atomic canonical materialization
Gate I  P9.12 provenance/persistence
Gate J  P9.13 qualification/Golden Journey/NFR/cross-platform input matrix
```

A gate does not close from code presence alone. Its stage tests and exit criteria must pass.

## P10-P14 forward architecture

P9 intentionally establishes reusable foundations before CAD interaction becomes heavier:

```text
ElecXPresentationCapabilities
ElecXResponsiveWidthClass
semantic Wizard/navigation state
input-operation abstraction
PreviewViewportState
keyboard shortcut mapping
focus/a11y policy
safe-area / window-resize handling
```

Expected reuse:

```text
P10 building/ЖК generation and multi-candidate compare
P11 EngineeringGraph navigation/inspection
P12 engineering generation Wizard/Preview/Diff
P13 auto-placement pointer/touch/stylus operations
P14 CAD routing viewport and edit commands
```

No P10-P14 phase should introduce a second desktop/mobile domain model or transaction path.

## Final design disposition

See `v2/99-p9-cross-stage-architecture-audit-v2.md`.

```text
P9 specification consistency        = PASS
cross-platform architecture         = PASS
blocking design ambiguity           = 0
runtime implementation              = NOT STARTED
design disposition                  = READY FOR IMPLEMENTATION
```
