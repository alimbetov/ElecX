# P9 Apartment Topology Generator — Implementation Specification v1

## Status

Authoritative implementation specification for branch:

`feat/p9-apartment-topology-generator`

Baseline:

- P8 Wizard + Preview/Diff is merged into `main`;
- branch base: `c397302f183d023e4bdd670ac0c8b46c6fad994a`;
- P9 is the next phase in the authoritative `P0..P17` roadmap.

This specification refines P9 from:

- `docs/architecture/project-composition-foundation-decisions-v1.md`;
- `docs/architecture/project-composition-generation-v1.md`;
- `docs/architecture/p8-wizard-preview-diff-implementation-v1.md`;
- `docs/architecture/p8-development-roadmap-v1.md`;
- `docs/architecture/apartment-topology-catalog-v1.md`.

Detailed stage specifications live under `docs/architecture/p9/` and are normative refinements of this umbrella specification.

If requirements conflict, the order of authority is:

1. native portability/foundation decisions;
2. this P9 specification and its stage specifications for apartment-generation behavior;
3. older apartment-topology addenda.

P9 extends the accepted P8 Wizard platform. It MUST NOT introduce a second transaction engine, second project graph, second preview lifecycle or provider-specific commit path.

---

# 1. Product objective

P9 turns the P8 Wizard framework into a production apartment-layout generator.

The user provides a bounded typed request, ElecX returns a small ranked set of recognizable apartment candidates, the user selects one, inspects the P8 Preview/Diff, and commits the exact frozen candidate as normal canonical project state.

North-star flow:

```text
Project Hub / Project Navigator
        ↓
Apartment Wizard
        ↓
ApartmentWizardParameters
        ↓
normalize + validate
        ↓
ApartmentTopologyCatalog
        ↓
compatible topology grammars
        ↓
bounded deterministic expansion
        ↓
area fitting
        ↓
adjacency / wet-core / geometry validation
        ↓
score + deterministic rank
        ↓
3..6 candidates
        ↓
dynamic vector/SVG previews
        ↓
user selection
        ↓
ApartmentWizardProvider
        ↓
P8 reserved Preview + semantic Diff
        ↓
Apply exact frozen candidate
        ↓
1 ProjectChangeSet + 1 UndoRecord
        ↓
canonical StructuralZone + Spaces + topology + provenance
```

The committed result is ordinary editable ElecX state. Generated apartments are not a separate document type.

---

# 2. Stage decomposition

```text
P9.0  specification / readiness audit
P9.1  ApartmentWizardParameters
P9.2  ApartmentTopologyCatalog
P9.3  topology families / grammars
P9.4  deterministic area fitting
P9.5  adjacency + wet-core rules
P9.6  geometry generation
P9.7  candidate scoring/ranking
P9.8  SVG/vector topology renderer
P9.9  ApartmentWizardProvider
P9.10 P8 Preview/Diff integration
P9.11 canonical Spaces/StructuralZone materialization
P9.12 provenance
P9.13 qualification / Golden Journey
```

Each stage has a dedicated normative mini-spec under `docs/architecture/p9/` with contracts, invariants, algorithms, failure model, tests and exit gate.

---

# 3. Non-negotiable architecture

```text
one canonical ProjectAggregateRoot
stable typed identities
P8 ReservedProjectMutationCoordinator lifecycle
side-effect-free candidate/card generation
exact frozen preview commit
one Apply = one ProjectChangeSet = one UndoRecord
no widget-side canonical mutation
no SVG-to-canonical parsing
no runtime randomness
no backend/AI dependency
no silent coercion of unsupported requests
```

P9 semantic catalog and generator are pure domain/application capabilities. Flutter presentation consumes them; it does not own them.

---

# 4. P9.0 audit disposition

See `docs/architecture/p9-architecture-audit-v1-2026-10-24.md`.

```text
P8 Wizard readiness             PASS
P6 semantic-space readiness     PASS
P7 boundary-topology readiness  PASS
P9 specification readiness      PASS
P9 runtime implementation       NOT STARTED
P9.0 disposition                GO TO P9.1
```

Mandatory adaptations discovered by audit:

```text
P9.10 extend semantic Diff for Zone/Space apartment semantics
P9.12 persist generation provenance template/family/seed identity
```

---

# 5. Stage-spec index

```text
docs/architecture/p9/p9.1-apartment-wizard-parameters-v1.md
docs/architecture/p9/p9.2-apartment-topology-catalog-v1.md
docs/architecture/p9/p9.3-topology-families-grammars-v1.md
docs/architecture/p9/p9.4-deterministic-area-fitting-v1.md
docs/architecture/p9/p9.5-adjacency-wet-core-rules-v1.md
docs/architecture/p9/p9.6-geometry-generation-v1.md
docs/architecture/p9/p9.7-candidate-scoring-ranking-v1.md
docs/architecture/p9/p9.8-svg-vector-renderer-v1.md
docs/architecture/p9/p9.9-apartment-wizard-provider-v1.md
docs/architecture/p9/p9.10-p8-preview-diff-integration-v1.md
docs/architecture/p9/p9.11-canonical-materialization-v1.md
docs/architecture/p9/p9.12-provenance-v1.md
docs/architecture/p9/p9.13-qualification-golden-journey-v1.md
```

---

# 6. Definition of P9 accepted

P9 is accepted only when all P9.1–P9.13 exit gates are closed and the Golden Journey proves:

```text
create/select target Level
→ open Apartment Wizard
→ enter typed parameters
→ generate deterministic candidate set
→ inspect dynamic vector cards
→ select candidate
→ P8 Preview/Diff
→ Apply exact frozen candidate
→ one canonical mutation / one Undo
→ Undo restores BEFORE fingerprint
→ Redo restores AFTER fingerprint
→ Save / Close / Reopen preserves AFTER fingerprint
→ provenance survives round-trip
→ generated spaces remain normally editable
```

Unsupported combinations fail before project mutation and preserve user input.

Final disposition string:

```text
P9 APARTMENT TOPOLOGY GENERATOR = ACCEPTED FOR MERGE
```
