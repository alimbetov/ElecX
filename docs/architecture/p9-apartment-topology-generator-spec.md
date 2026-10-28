# ElecX P9 — Apartment Topology Generator Technical Specification v1.0

Status: **Frozen architecture contract for P9.1**

## 1. Purpose

P9 is a **deterministic engineering decision pipeline**, not merely an object generator.

```text
Generate
  ↓
Validate
  ↓
Preview / Diff
  ↓
Acceptance
  ↓
Apply
```

Critical invariant:

```text
Generate != Apply
```

`generate`, `validate`, `project`, and `preview` MUST be pure relative to project state. Project mutation is permitted only at an explicit Apply boundary.

## 2. Normative terminology

- **MUST** — mandatory.
- **MUST NOT** — prohibited.
- **SHOULD** — deviation requires a documented architectural reason.
- **Candidate** — potential topology configuration.
- **Eligible** — candidate that passed all blocking validation.
- **Selected** — deterministic winner among eligible candidates.
- **Draft** — generated result not yet applied.
- **Canonical proposal** — engineering proposal handed to Preview/Diff.
- **Apply** — separate atomic project mutation.
- **Fail-closed** — uncertainty, missing safety evidence, or an exception does not default to success.

## 3. Scope

P9 MUST cover:

1. input normalization;
2. candidate discovery;
3. semantic validation;
4. geometry validation;
5. normative validation;
6. equipment compatibility;
7. scoring;
8. deterministic ranking;
9. deterministic selection;
10. `ApartmentTopologyDraft` creation;
11. candidate diagnostics;
12. normative evidence;
13. canonical engineering projection;
14. `ComponentPlacement` production;
15. provenance;
16. deterministic fingerprints;
17. `ImpactGraph` production;
18. P8 Preview/Diff handoff;
19. replayability;
20. qualification suites.

## 4. Non-scope and prohibited shortcuts

P9 MUST NOT directly:

- mutate project state during generation;
- perform hidden Apply;
- own UI navigation;
- perform manual geometry editing;
- own BIM/IFC export;
- perform procurement/pricing negotiation;
- own collaboration synchronization;
- fabricate equipment parameters;
- fabricate normative evidence;
- synthesize an arbitrary fallback topology.

Persistence may store P9 artifacts but MUST NOT determine engineering decisions.

## 5. No parallel domain model

Existing P9 and engineering types MUST be reused. A new type is allowed only if:

1. no semantic equivalent exists;
2. its responsibility is distinct;
3. dependency direction remains correct;
4. the architecture explicitly justifies it.

## 6. Core invariants

### 6.1 Pure generation

`generate()` MUST be side-effect-free relative to project state.

### 6.2 Determinism

The same normalized engineering input under the same generator, topology catalog, scoring profile, normative profile, and equipment catalog revisions MUST produce the same selected candidate and the same `contentFingerprint`.

### 6.3 Explainability

For each run it MUST be possible to identify:

- candidates considered;
- rejected candidates and reasons;
- validation rules used;
- candidate scores;
- why the winner won;
- normative evidence;
- dependency versions/revisions.

### 6.4 Replayability

A generation artifact MUST contain enough version/provenance information to reproduce the result or explain why exact replay is impossible after dependency changes.

### 6.5 Fail closed

```text
unknown != valid
indeterminate != pass
exception != fallback topology
```

## 7. End-to-end pipeline

```text
Apartment / Building Input
→ Input Normalization
→ Candidate Discovery
→ Candidate Evaluation
   → Semantic
   → Geometry
   → Normative
   → Equipment
→ rejected diagnostics / eligible candidates
→ scoring
→ deterministic ranking
→ deterministic selection
→ ApartmentTopologyDraft
→ Canonical Engineering Projection
→ CanonicalEngineeringGraph + ComponentPlacement[] + ImpactGraph
→ GenerationResult + Provenance
→ P8 Preview/Diff
→ Reject(no-op) OR Apply(atomic mutation)
```

## 8. Generation request and normalization

P9 MUST use a typed request rather than a map-based domain API. The request MUST identify project/apartment context, geometry, spaces, boundaries/openings, available construction facts, engineering constraints, requested systems, normative profile, catalog revision/profile, and generation options.

Normalization MUST:

- stabilize collection ordering;
- normalize identifiers;
- normalize physical units;
- validate required fields;
- remove insertion-order influence;
- calculate `inputFingerprint`.

Physical units MUST be explicit and canonical, for example mm, W, A, V. Implicit unit mixing is prohibited.

## 9. Fingerprints

`inputFingerprint` is a deterministic hash of engineering-significant normalized input and MUST ignore transient/UI state.

`contentFingerprint` is a deterministic hash of engineering output. Timestamps MUST NOT participate in it.

Same effective input under the same versions/rules MUST produce the same content fingerprint. An engineering-significant geometry change MUST alter the relevant fingerprint.

## 10. Candidate discovery and evaluation

The production topology catalog is authoritative. Discovery MUST be deterministic and MUST NOT synthesize an unknown fallback topology.

Candidate identity MUST contain at least `templateId`, `templateVersion`, and stable order or an equivalent stable-order contract.

Evaluation states are:

```text
DISCOVERED → EVALUATING → REJECTED | ELIGIBLE
ELIGIBLE   → SELECTED | NOT_SELECTED
```

A candidate MUST NOT be both REJECTED and SELECTED.

Evaluation diagnostics SHOULD contain candidate identity, semantic result, geometry result, normative result, equipment compatibility, score, eligibility, blocking reasons, warnings, and diagnostics.

## 11. Validation contracts

### 11.1 Semantic validation

A semantic blocker makes the candidate ineligible. Scoring MUST NOT override a semantic blocker. Blocking reasons MUST have stable machine-readable codes.

### 11.2 Geometry validation

Geometry validation MUST cover referenced spaces, boundaries/openings, host availability, adjacency, feasibility, dangling geometry references, and placement host validity. If a safety-relevant feasibility fact cannot be determined, the result is INDETERMINATE rather than valid.

### 11.3 Normative validation

Normative evaluation states are:

- `PASS`;
- `FAIL`;
- `NOT_APPLICABLE`;
- `INDETERMINATE`.

`FAIL` blocks eligibility. Safety-critical `INDETERMINATE` also blocks eligibility. `NOT_APPLICABLE` requires an explicit applicability decision.

Evidence SHOULD include `ruleId`, authority, source, revision, `effectiveFrom`, clause, `sourceUri` when known, input facts, applicability, result, and rationale. Unknown or unpinned normative revisions MUST NOT silently PASS.

### 11.4 Equipment compatibility

P9 MUST use the existing equipment/component catalog and engineering metadata. It MUST NOT fabricate dimensions, current, power, voltage, mounting constraints, manufacturer compatibility, clearance, price, or certification.

Unattended auto-configuration is allowed only when verified metadata is sufficient (`isAutoConfigurationReady` or semantic equivalent). Missing safety-critical metadata yields INDETERMINATE / NOT_AUTO_CONFIGURABLE and blocks automatic selection.

## 12. Scoring and deterministic ranking

Scoring occurs after the candidate has enough validation evidence to establish eligibility. The scoring profile MUST be versioned and deterministic. Scoring MUST NOT convert an invalid candidate into an eligible candidate.

```text
Validation → can it be used?
Ranking    → which valid alternative is better?
```

### 12.1 Frozen P9.1 comparator

Only eligible candidates participate in selection. The total order is frozen as:

```text
1. score DESC
2. stableOrder ASC
3. canonical template identity / templateId ASC
4. templateVersion ASC
```

Where the existing implementation has multiple stable-order components, they MUST be compared in their documented stable hierarchy before canonical identity.

Input list order, map iteration order, random values, and timestamps MUST NOT affect the winner.

## 13. Fail-closed selection

- an invalid candidate MUST never be selected;
- a higher-scoring invalid candidate MUST lose to any eligible candidate;
- zero eligible candidates MUST produce an explicit typed failure;
- `candidates.first` MUST NOT be used as fallback selection;
- exceptions MUST NOT trigger silent fallback;
- incomplete generation MUST NOT masquerade as success.

Failure taxonomy:

- `INVALID_INPUT`
- `NO_CANDIDATES`
- `NO_VALID_TOPOLOGY_CANDIDATE`
- `SEMANTIC_VALIDATION_FAILURE`
- `GEOMETRY_VALIDATION_FAILURE`
- `NORMATIVE_BLOCKED`
- `EQUIPMENT_COMPATIBILITY_BLOCKED`
- `CATALOG_VERSION_UNAVAILABLE`
- `GENERATOR_VERSION_UNSUPPORTED`
- `INTERNAL_GENERATION_ERROR`

## 14. Unified generation runtime

The application/domain boundary SHOULD expose the semantic equivalent of:

```dart
abstract interface class ApartmentTopologyGenerationEngine {
  ApartmentTopologyGenerationResult generate(
    ApartmentTopologyGenerationRequest request,
  );
}
```

Runtime responsibility:

```text
normalize
→ discover
→ evaluate
→ filter eligible
→ score
→ deterministic rank
→ select
→ build draft
→ return result
```

No-valid-candidate processing MUST retain diagnostics.

## 15. Draft and result

`ApartmentTopologyDraft` represents generated-but-unapplied topology. It MUST have stable lineage/provenance, immutable or effectively immutable content, deterministic fingerprinting, and be independently revalidatable without UI state.

A successful generation result conceptually contains generation identity, input/content fingerprints, selected candidate, selected draft, candidate evaluations/rejections, diagnostics, normative evidence, generator version, catalog revision, scoring-profile version, normative-profile version, and provenance.

A successful result contains exactly one selected candidate.

## 16. Canonical engineering projection

```text
ApartmentTopologyDraft
→ CanonicalEngineeringGraph + ComponentPlacement[]
```

Separation of responsibilities is mandatory:

```text
CanonicalEngineeringGraph = WHAT + CONNECTIVITY
ComponentPlacement        = WHERE
```

Geometry MUST NOT be embedded in the logical graph as a placement substitute. Typed stable IDs MUST be used for components, ports, connections, circuits, and routes. Dangling references, incompatible port directions/media, and invalid placement hosts are prohibited.

## 17. Impact graph

Required node kinds include component, engineering connection, circuit, route, boundary, slab, opening, and generation. Required dependency kinds include connectivity, hostedBy, routedBy, calculatedFrom, generatedFrom, and constrainedBy.

Traversal MUST support direct/transitive dependents, be cycle-safe, and reject self-dependency.

## 18. Provenance

Successful generation provenance MUST include generationId, generatorVersion, templateId/version, inputFingerprint, contentFingerprint, catalog revision, equipment catalog revision where applicable, scoring-profile version, normative-profile version, selected candidate, and generation timestamp.

Timestamp MUST NOT participate in `contentFingerprint`.

## 19. P8 Preview/Diff contract

Within ElecX, **P8 means ElecX Wizard Preview/Diff**, not EPLAN Electric P8.

```text
Current Project State + P9 Canonical Proposal → P8 Diff
```

Preview MUST NOT mutate the project. Reject is a no-op. Apply is an explicit, separate, atomic operation. Repeated diff of the same proposal against the same state MUST be deterministic.

## 20. Persistence and dependency direction

Do not add a Drift schema first. The direction is:

```text
Domain Contract → Persistence Mapping → Drift Schema
```

Architectural dependency direction:

```text
UI
→ Application / P9 Runtime
→ Domain
→ Catalog / Normative / Engineering Services
→ Persistence adapters
```

The domain MUST NOT depend on Flutter widgets. Core generation MUST remain testable without UI.

## 21. Versioning, compatibility, concurrency

Generator, topology template, catalog, scoring profile, normative profile, and relevant equipment catalog revision MUST be versioned/persisted. Algorithm changes that can change the winner require an appropriate version change.

Legacy runtime MUST remain available until the replacement is qualified. Adapters SHOULD be preferred to mass deletion.

Parallel generations MUST be logically isolated; mutable shared candidate order/state is prohibited.

## 22. Initial performance targets

- normal apartment: < 250 ms CPU generation target;
- complex apartment: < 1000 ms target;
- no long UI-thread blocking.

Correctness and determinism take precedence over micro-optimization.

## 23. Logging and audit

Logs SHOULD include generationId, inputFingerprint, generatorVersion, candidate count, eligible count, selected template/version, duration, and failure code. Logs are not the sole diagnostics store. Audit data MUST retain what was selected, why, and under which rule/catalog versions.

## 24. Forbidden behavior checklist

P9 MUST NOT:

- use `candidates.first` as a fallback;
- allow invalid candidates to win by score;
- treat INDETERMINATE as PASS;
- use random selection;
- let insertion/list order choose the winner;
- let Map iteration order choose the winner;
- let `DateTime.now()` alter engineering output;
- mutate project state during generate/preview/reject;
- mix placement geometry into logical graph ownership;
- create dangling components/ports/routes;
- fabricate equipment data;
- fabricate normative evidence;
- hide exceptions behind fallback topology;
- duplicate existing domain models;
- let persistence schema drive engineering semantics;
- change comparator semantics silently.

## 25. P9.1 frozen contract

```text
Request
→ Discovery
→ Evaluation
→ INVALID(rejected) / VALID
→ scoring
→ ranking
→ deterministic selection
→ winner ? build draft/result : explicit failure
```

Frozen invariants:

- INVALID never wins;
- candidate input order cannot change winner;
- equal score cannot choose a winner nondeterministically;
- no valid candidate cannot fallback;
- generation cannot mutate project state.

### 25.1 Mandatory P9.1 qualification tests

- **Q01** same input → same winner;
- **Q02** shuffled candidates → same winner;
- **Q03** invalid candidate → rejected;
- **Q04** invalid candidate with higher score → never selected;
- **Q05** equal score → deterministic stable tie-break;
- **Q06** no valid candidates → explicit `NO_VALID_TOPOLOGY_CANDIDATE` failure.

P9.1 is not complete before all six are automated and green.

## 26. Broader qualification matrix

Qualification MUST additionally cover normative FAIL, safety-critical INDETERMINATE, draft/fingerprint stability, canonical graph identity/reference integrity, placement host integrity, provenance changes under engineering-significant input changes, generate→preview→reject no-op behavior, and repeated-preview semantic equivalence.

## 27. CI gates

Every P9 increment is expected to pass:

```text
dart format
→ flutter analyze
→ targeted P9 tests
→ flutter test
→ P8 regressions
→ engineering-core qualification
→ GitHub Actions
```

Formatting, analysis, P9 qualification, P8 regression, or engineering-core qualification failures block merge.

## 28. Delivery packages

- **P9.1** Unified Generation Runtime — deterministic selection, fail-closed behavior, Q01–Q06.
- **P9.2** Candidate Diagnostics — blockers, warnings, score explanation, rejection/selection rationale.
- **P9.3** Canonical Engineering Projection — Draft → graph + placements.
- **P9.4** Normative Evidence — normative eligibility and provenance.
- **P9.5** Equipment Auto-Configuration — compatibility, metadata gate, deterministic equipment selection.
- **P9.6** Impact + Provenance — ImpactGraph, fingerprints, replay.
- **P9.7** P8 Preview/Diff Integration — canonical proposal, deterministic diff, reject no-op, atomic Apply.
- **P9.8** Persistence — domain → DTO → Drift → migration and round-trip qualification.
- **P9.9** Full Qualification / Hardening — determinism, fault injection, compatibility, replay, persistence, performance, backward compatibility.

## 29. Overall Definition of Done

The complete path MUST exist and be qualified:

```text
Apartment
→ Request
→ Normalize
→ Discover
→ Semantic
→ Geometry
→ Normative
→ Equipment
→ Score
→ Rank
→ Select
→ Draft
→ CanonicalGraph + Placements
→ Impact + Provenance
→ P8 Diff
→ Apply
```

The result MUST be deterministic, fail-closed, explainable, replayable, versioned, free of implicit fallback, free of dangling engineering references, and free of fabricated engineering/normative facts.

## 30. Contract freeze

Architecture-significant changes to selection comparator, eligibility semantics, INDETERMINATE interpretation, fingerprint algorithm, generation-result semantics, canonical graph ownership, Generate/Apply boundary, normative blocking, or equipment auto-configuration eligibility require:

1. specification update;
2. version update where applicable;
3. qualification update;
4. compatibility assessment.

## 31. Architecture statement

> P9 is a deterministic engineering decision pipeline.
>
> P9 must never choose a variant whose admissibility the system could not prove.
>
> Same engineering input under same versions of rules/catalogs must give reproducible engineering output.
