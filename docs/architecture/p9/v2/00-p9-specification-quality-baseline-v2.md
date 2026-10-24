# P9 Specification Quality Baseline v2

Status: **AUTHORITATIVE FOR P9 DESIGN**  
Branch: `feat/p9-apartment-topology-generator`  
Applies to: `P9.1..P9.13`

## 1. Purpose

This document defines the quality bar that every P9 stage specification MUST satisfy before runtime implementation is accepted.

P9 is not a set of independent features. It is one deterministic apartment-generation pipeline built on the accepted P8 Wizard transaction model.

```text
typed request
  -> catalog compatibility
  -> grammar expansion
  -> area fitting
  -> semantic validation
  -> geometry generation
  -> geometry validation
  -> scoring / diversity
  -> vector projection
  -> P8 reserved preview/diff
  -> canonical materialization
  -> persisted provenance
  -> qualification
```

If a stage cannot prove its output contract to the next stage, that stage is not complete.

## 2. Authority order

If documents conflict, use this order:

1. `project-composition-foundation-decisions-v1.md`;
2. accepted P8 transaction/preview contracts;
3. this quality baseline;
4. P9 stage v2 specifications;
5. P9 umbrella v1 specification;
6. older apartment topology addenda.

No P9 document may weaken canonical ownership, typed identity, stale-version protection, one-commit/one-Undo semantics or native-only portability.

## 3. Normative language

`MUST`, `MUST NOT`, `SHOULD`, `MAY` are normative.

Every stage v2 spec MUST contain:

- scope and explicit non-goals;
- inputs and outputs;
- typed contracts;
- functional requirements with stable IDs;
- invariants with stable IDs;
- error taxonomy with stable codes;
- determinism rules;
- test/qualification matrix;
- measurable exit gate;
- downstream dependencies.

## 4. Requirement ID convention

Use:

```text
P9.<stage>-FR-###   functional requirement
P9.<stage>-INV-###  invariant
P9.<stage>-ERR-###  error/failure contract
P9.<stage>-NFR-###  non-functional requirement
P9.<stage>-AT-###   acceptance test
```

Examples:

```text
P9.4-FR-003
P9.6-INV-005
P9.10-ERR-002
P9.13-NFR-004
```

Runtime tests SHOULD reference these IDs in names/comments so requirements remain traceable.

## 5. Common deterministic contract

For the same:

```text
normalized request
catalogVersion
templateId + templateVersion
variantSeedId
generatorVersion
scoringProfileVersion
explicit target context
```

P9 MUST produce semantically equivalent candidate results on every supported native platform.

Determinism excludes:

- random-number generation without an explicit persisted seed;
- clock/time dependent generation;
- locale-dependent parsing/sorting;
- map/set iteration order as semantic order;
- floating-point equality as a business invariant;
- platform-specific layout metrics as generation input.

All externally compared ordering MUST use explicit stable sort keys.

## 6. Unit policy

Canonical generation uses integer engineering units.

```text
length       millimetres (int)
area         square decimetres or square millimetres internally (int)
angle        integer degrees for v1 orthogonal geometry
score        basis points 0..10000 (int)
versions     positive integers / stable version strings
```

UI may display metres and square metres but MUST NOT use localized display strings as generator input.

Conversions occur at the UI/application boundary and are explicitly rounded by one documented policy.

## 7. Identity model

P9 uses three identity layers:

### 7.1 Semantic draft identity

Stable inside deterministic candidate generation:

```text
spaceKey = bedroom:1
spaceKey = kitchenLiving:1
adjacencyKey = sorted(spaceKeyA, spaceKeyB, kind)
edgeSemanticKey = spaceKey + boundaryRole + segmentOrdinal
```

These keys participate in candidate fingerprints.

### 7.2 Preview reservation identity

P8 `MutationIdentityReservation` allocates canonical IDs once for the selected candidate preview/apply lifecycle.

No permanent `SpaceId`, `ZoneId`, `BoundaryEdgeId`, etc. is allocated while merely browsing topology cards.

### 7.3 Persistent identity

Apply commits the exact frozen reserved candidate. Apply MUST NOT regenerate IDs or geometry.

## 8. Candidate fingerprint

Every valid candidate MUST have a canonical fingerprint derived from semantic data, not rendered SVG.

Minimum fingerprint payload:

```text
normalized request
catalog/template versions
familyId
variantSeedId
ordered semantic spaces + target areas
ordered adjacency rules/results
normalized integer geometry
candidate scoring profile version
```

Excluded:

```text
localized labels
widget state
SVG markup
hover/focus
screen size
transient timings
canonical IDs not yet reserved
```

Canonical serialization MUST define field order, collection order and numeric representation.

## 9. Failure policy

P9 fails closed.

No stage may silently:

- clamp an unsupported request into a different semantic request;
- drop a required room;
- change requested kitchen mode;
- ignore a required adjacency;
- generate overlapping geometry;
- allocate permanent IDs to preview cards;
- bypass P8 stale-version checks;
- replace an occupied Level in P9 v1;
- parse SVG back into canonical geometry.

Failures are typed and user-facing messages are mapped separately from stable technical codes.

## 10. Common error envelope

Application-level errors SHOULD expose:

```dart
final class P9Failure {
  final String code;              // stable machine code
  final P9FailureStage stage;
  final P9FailureSeverity severity;
  final Map<String, Object?> facts;
  final List<P9Suggestion> suggestions;
}
```

Localized strings are presentation concerns and MUST NOT be persisted as error identity.

## 11. Stage boundary rule

Each stage produces an immutable value object consumed by the next stage.

No downstream stage may reach backwards into UI/controller state.

Example:

```text
NormalizedApartmentRequest
        ↓
CompatibleTopologyTemplate[]
        ↓
TopologyDraft[]
        ↓
AreaFittedTopologyDraft[]
        ↓
SemanticallyValidatedTopology[]
        ↓
ApartmentGeometryCandidate[]
        ↓
RankedApartmentCandidate[]
```

## 12. Performance methodology

Performance gates are measured separately from functional tests.

Rules:

- warm-up before sampling;
- fixed catalog fixture and request corpus;
- record p50/p95/p99;
- no network/backend dependency;
- tests fail on hard p95/p99 thresholds defined in P9.13;
- memory gate measures incremental RSS for the complete candidate cycle;
- debug-mode results are diagnostic; CI release/profile-like harness is authoritative where available.

## 13. Test pyramid

Each stage requires:

```text
unit tests
  deterministic pure algorithms

contract tests
  stage input/output and invariants

property tests
  repeated/generated parameter matrices

integration tests
  adjacent P9 stages

P8 integration tests
  frozen preview/diff/apply

persistence tests
  save/reopen semantic fingerprint

Golden Journey
  end-to-end user intent
```

## 14. Cross-platform requirement

Generation semantics MUST NOT depend on Flutter rendering or OS APIs.

At minimum the same fixture corpus on macOS and Linux/CI MUST yield the same normalized candidate fingerprints. Windows qualification remains part of the native acceptance matrix when runner coverage is available.

## 15. Versioning policy

Independent versions are required for:

```text
catalogVersion
templateVersion
generatorVersion
scoringProfileVersion
provenanceSchemaVersion
```

Changing one semantic layer MUST NOT silently reuse an old version identifier.

Any change that can change candidate fingerprint for unchanged user intent requires a version bump in the owning layer.

## 16. Security / robustness constraints

P9 is local/native and has no backend requirement.

SVG output MUST be inert:

- no scripts;
- no event handlers;
- no external references;
- no `foreignObject`;
- escaped labels;
- bounded element count;
- never parsed into canonical state.

Catalog data is trusted application data in v1 but MUST still be validated at startup/tests so malformed templates fail before user mutation.

## 17. Merge readiness definition

P9 cannot be marked accepted until all are true:

```text
P9.1..P9.13 stage requirements implemented
all stage exit gates PASS
all requirement IDs trace to tests
candidate fingerprint deterministic on supported CI platforms
P8 preview/apply exactness preserved
one Apply = one ProjectChangeSet = one UndoRecord
save/reopen preserves canonical fingerprint + provenance
hard p95/p99/RSS gates PASS
RU/EN + accessibility gates PASS
full Flutter analyze/test PASS
macOS native workflow PASS
```

Any accepted residual MUST be explicitly documented with owner, risk, containment and target phase. Silent residuals are forbidden.
