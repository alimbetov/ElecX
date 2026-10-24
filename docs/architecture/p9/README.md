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

runtime implementation                              NOT STARTED
```

## Authoritative dependency chain

```text
quality baseline + shared contracts
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

## Key v2 decisions

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

## Implementation gates

```text
Gate A  shared contracts + P9.1
Gate B  P9.2 catalog integrity/coverage
Gate C  P9.3-P9.5 semantic generator
Gate D  P9.6 geometry + openings
Gate E  P9.7/P9.8 ranking/render
Gate F  P9.9 provider/session
Gate G  P9.10 apartment-aware Diff
Gate H  P9.11 atomic canonical materialization
Gate I  P9.12 provenance/persistence
Gate J  P9.13 qualification/Golden Journey/NFR
```

A gate does not close from code presence alone. Its stage tests and exit criteria must pass.

## Final design disposition

See `v2/99-p9-cross-stage-architecture-audit-v2.md`.

```text
P9 specification consistency = PASS
blocking design ambiguity    = 0
runtime implementation       = NOT STARTED
design disposition           = READY FOR IMPLEMENTATION
```
