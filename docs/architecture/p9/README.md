# P9 Apartment Topology Generator — Stage Specifications

Branch: `feat/p9-apartment-topology-generator`

Umbrella specification: `../p9-apartment-topology-generator-spec-v1.md`  
Readiness audit: `../p9-architecture-audit-v1-2026-10-24.md`

## Ordered stages

```text
P9.0  specification/audit                         DONE (design)
P9.1  ApartmentWizardParameters                   stage spec ready
P9.2  ApartmentTopologyCatalog                    stage spec ready
P9.3  topology families / grammars                stage spec ready
P9.4  deterministic area fitting                  stage spec ready
P9.5  adjacency + wet-core rules                  stage spec ready
P9.6  geometry generation                         stage spec ready
P9.7  candidate scoring/ranking                   stage spec ready
P9.8  SVG/vector topology renderer                stage spec ready
P9.9  ApartmentWizardProvider                     stage spec ready
P9.10 P8 Preview/Diff integration                 stage spec ready
P9.11 canonical Spaces/StructuralZone materialization stage spec ready
P9.12 provenance                                  stage spec ready
P9.13 qualification / Golden Journey              stage spec ready
```

`stage spec ready` means the implementation contract is defined; it does NOT mean runtime code is implemented.

## Dependency chain

```text
P9.1
  ↓
P9.2 → P9.3
       ↓
      P9.4 → P9.5 → P9.6 → P9.7 → P9.8
                                ↓
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

P9.8 renderer may be developed in parallel once the candidate geometry contract from P9.6 is frozen. P9.12 schema work may begin early, but acceptance depends on P9.11 materialization.

## Architectural rule

P9 plugs into P8. It does not create a second project model, transaction engine, preview lifecycle, persistence owner or SVG-based geometry authority.
