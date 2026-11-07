# P12A.8 Engineering Preview/Diff/Apply — implementation contract (Draft)

Status: **implementation in progress; Apply NOT qualified**.
Baseline: P12A.7 PR #30 (pending exact-SHA CI). This branch is stacked on `feat/p12a7-evidence-gated-cable-protection-selection`; it must be retargeted to `main` only after the qualified P12A.7 merge.

## Verified production integration points

- `lib/src/application/project/project_mutation_reservation.dart` owns `ReservedProjectCommand`, `MutationIdentityReservation`, `ReservedProjectMutationPreview`, `ProjectSemanticChangeSet`, `ProjectSemanticOperation`, and `ReservedProjectMutationCoordinator.preview()/commitPreview()`.
- `lib/src/application/project/wizard/project_wizard_mutation_port.dart` owns `SharedProjectWizardMutationPort` bound to the **existing** `ProjectMutationSession`. It rejects discarded, consumed, and foreign previews; it does not create another canonical timeline.
- `lib/src/application/project/wizard/wizard_diff.dart` projects typed semantic operations into read-only, human-facing `WizardDiffModel`. Engineering fields need an explicit typed projector extension; stringified JSON blobs are not an acceptable substitute.
- P12A.7 `PowerEvidenceSelectionPreview` captures an evidence/decision fingerprint and a cable/protection closure, but `readyToApply` is deliberately `false` and board electrical ratings are unverified.

## Mandatory invariant

P12A.5–P12A.7 propose **engineering intent**, not canonical project state. The P12A.8 adapter must produce exactly one existing `ReservedProjectCommand`; only `ReservedProjectMutationCoordinator.preview(command)` may allocate the new canonical IDs and produce the frozen candidate. Only `commitPreview(preview)` may apply that candidate. No second ProjectMutationSession, custom repository, recalculation during Apply, or independently generated IDs.

## Integration implementation slices

### A8.1: Engineering intent and reviewed evidence snapshot — read-only

Define an immutable engineering intent with:
- Source project ID + `LocalProjectVersion` and canonical input fingerprint;
- P12A.5 circuit generation keys and selected load/board identity;
- P12A.7 evidence selection fingerprint, normative source ID/revision/content SHA-256/approval ID;
- all referenced route, fault, cable, ampacity, impedance, protection, manufacturer/catalog source revisions and digests;
- a **trusted verification record** for each external source (issuer, published version, jurisdiction, applicability scope, authenticated content hash, reviewer, review timestamp and approval/revocation state);
- device/board electrical ratings and their manufacturer documents;
- explicit eligibility flags for short-circuit breaking capacity, busbar capacity, I²t/thermal withstand, disconnection time, selectivity/coordination and RCD as required by the project rules.

Snapshots must use stable semantic normalization. Do not infer applicable norms or fill absent ratings with defaults. A `PowerEvidenceSourcePin` is an identity check, **not** an authenticity proof.

### A8.2: Read-only candidate via canonical reservation

Implement `EngineeringReservedProjectCommand implements ReservedProjectCommand` using existing reserved `circuit`, `component`, `port`, `engineeringConnection` and other **actually required** identity kinds. Use stable generation-key → reservation-slot mappings. All `buildCandidate()`, `validateReservation()` and `semanticOperations()` implementations must use `ProjectAggregateRoot` and `MutationIdentityReservation` directly.

First create a **fully mapped read-only engineering preview**; if canonical entity model cannot represent cable/protection/board selections without lossy metadata, extend the existing canonical aggregate and persistence codec before allowing Apply. Never store the canonical selection only in UI state.

### A8.3: Typed Engineering Diff

Extend the existing typed semantic operation taxonomy and `WizardDiffProjector` (or reuse the same shared projector) to describe:
- add/update/remove circuit;
- board assignment and ratings;
- circuit→cable and circuit→protection selection;
- route/port/binding changes;
- provenance and evidence version changes.

Diff entries must link before/after *canonical* entities, precise ID types, source IDs, fields, and review diagnostics. Stable ordering and scope are required.

### A8.4: Apply qualification and stale protection

Prior to `commitPreview()`, enforce:
- frozen preview was prepared by the active coordinator; not consumed or discarded;
- current `LocalProjectVersion` equals the preview-observed version;
- exact catalog/manufacturer/normative content hashes and accepted approval records still match;
- no revoked sources, no unresolved ratings or electrical safety checks;
- stable generation keys and reserved ID ownership;
- project input, topology and route revisions still match.

The checks must be protected from time-of-check/time-of-use races, via a single transactional/optimistically guarded commit boundary, including the evidence registry version (or a snapshot-pinned immutable registry). A preflight check outside the transaction alone is insufficient. Duplicate Apply must fail closed without creating a second history record. Do not silently re-plan and retry stale previews.

### A8.5: Persistent lifecycle qualification

Use the existing `ProjectMutationSession` Undo/Redo and canonical repository Save/Reopen. Demonstrate that exact circuit, board, cable, protection, ports, relationships, provenance hashes and allocated IDs survive Apply → Undo → Redo → Save → Close → Reopen.

## Executable acceptance matrix (to implement)

| Test | Expected |
|---|---|
| Repeated preview over identical inputs | Same semantic diff; no canonical mutation |
| Permuted load order | Same generation keys and semantic fingerprint |
| Version changed after preview | Stale rejection; zero new history entries |
| Catalog/normative digest changed | Apply rejected; no mutation |
| Missing or revoked external review | Apply rejected |
| Missing busbar/fault rating | Apply rejected |
| Missing required selectivity/RCD/I²t check | Apply rejected |
| Invalid route/port binding | Apply rejected |
| Malicious/foreign/consumed/discarded preview | Apply rejected |
| Duplicate Apply | No duplicated entities, IDs, or history |
| Exception midway through mutation | Atomic rollback |
| Apply/Undo/Redo | Exact canonical fingerprints and IDs |
| Save/Close/Reopen | Same canonical identity, graph, technical choices, and evidence |
| Round-trip codec with unknown schema revision | Fail closed or supported explicit migration |

## Gates / release policy

- P12A.7 exact-SHA formatting, analyze, unit/qualification tests and inherited CI green.
- Independent normative-source authenticity and jurisdictional applicability review is required; **synthetic test values do not satisfy this gate**.
- Confirm board and manufacturer ratings and protective coordination. Unsupported cases must remain preview-only.
- A8.2–A8.5 code must pass exact-SHA CI + golden and negative journeys before anyone enables `readyToApply`.
- PR remains **Draft** until all acceptance gates pass. Do not merge partial Apply behavior.

## Implementation order

1. Qualify P12A.7 CI.
2. Map P12A.7 decision types against existing canonical aggregate/persistence schemas.
3. Add immutable version-pinned engineering intent and tests.
4. Add single reserved command and typed diff projection; keep Apply disabled.
5. Add trusted evidence registry and all mandatory electrical qualification checks.
6. Wire guarded commit to existing coordinator/session; test stale/duplicate/atomicity.
7. Run full Undo/Redo and Save/Reopen golden journey plus inherited CI on exact SHA.
