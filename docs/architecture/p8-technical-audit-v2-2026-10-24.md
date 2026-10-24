# P8 Wizard + Preview/Diff Technical Audit v2 — 2026-10-24

## Status

Current implementation-state audit for `feat/p8-wizard-preview-diff`.

This document preserves `p8-technical-audit-v1.md` as historical evidence and updates its findings against the actual implementation present on the branch.

Audited implementation SHA:

```text
02078a2d07b0a3aac8e35902260488f6f6f8762b
```

Base branch at audit time:

```text
main = 56cb40ad2cc141262b064c61023a61baf257798f
branch ahead = 51 commits
branch behind = 0 commits
```

CI evidence on the audited SHA:

```text
verification = PASS
quality      = PASS
dart format  = PASS
flutter analyze = PASS
flutter test = PASS
```

The audit classifies each integration requirement as:

```text
CLOSED             implementation and sufficient direct evidence exist
PARTIALLY CLOSED   architecture/code exists, but production integration or qualification is incomplete
OPEN               required implementation/evidence is absent
```

---

# 1. Executive verdict

P8 is no longer specification-only. The branch now contains a valid application-layer Wizard foundation:

```text
WizardProvider contracts
WizardProviderRegistry
WizardSession
BasicBuildingWizardProvider
SharedProjectWizardMutationPort
reserved preview / frozen candidate commit
canonical LocalProjectVersion / Undo integration
unit tests for preview side effects, stale handling and Basic Building hierarchy
```

The most important architectural decision is correct: Wizard mutations reuse the existing canonical mutation timeline rather than introducing a second project model or a second transaction/Undo engine.

However, the feature named `wizard-preview-diff` is not yet a production-complete vertical slice.

The following user-visible/common-infrastructure capabilities remain absent or unqualified:

```text
Project Hub Wizard start gate
NewProject Basic Building seed normalization
Project Navigator Wizard entry
semantic user-facing diff projection
field-level before/after diff
rendering-neutral WizardPreviewScene
safe deterministic SVG/vector projection
responsive Wizard shell
provider-neutral candidate carousel
production owner/publication wiring
legacy structural materialization for new Levels
restart-safe canonical<->legacy Level identity bridge
save/reopen fingerprint qualification
full Apply -> one Undo -> Redo -> save -> reopen E2E
performance/accessibility/security/localization/observability qualification
```

Therefore:

```text
GO      for continuing P8 implementation on the existing architectural foundation
NO-GO   for declaring P8 ACCEPTED
NO-GO   for merging the branch as a completed wizard-preview-diff feature
```

Estimated completion by production capability, not by lines of code:

```text
60-65%
```

---

# 2. Architecture observed on the branch

Current implemented path:

```text
WizardSession
   |
   +-- WizardProviderRegistry
   |       |
   |       +-- BasicBuildingWizardProvider
   |
   +-- ProjectWizardMutationPort
           |
           +-- SharedProjectWizardMutationPort
                   |
                   +-- ReservedProjectMutationCoordinator
                           |
                           +-- ProjectMutationSession
                                   |
                                   +-- ProjectAggregateRoot
                                   +-- LocalProjectVersion
                                   +-- Undo/Redo history
```

Required production path still to be completed:

```text
Project Hub
   |
   +-- Create with Wizard                         [OPEN]
   |
   v
Responsive WizardShell                           [OPEN]
   |
   +-- provider / typed parameters               [IMPLEMENTED CORE]
   +-- candidate/variant selection               [PARTIAL]
   +-- WizardPreviewScene                        [OPEN]
   +-- SemanticDiffProjector                     [OPEN]
   +-- Apply / Cancel                            [CORE IMPLEMENTED]
   |
   v
SharedProjectWizardMutationPort                  [IMPLEMENTED]
   |
   v
ReservedProjectMutationCoordinator               [EXISTING CANONICAL BACKBONE]
   |
   v
ProjectMutationSession                           [EXISTING CANONICAL BACKBONE]
   |
   v
ProjectChangeSet / Undo / owner publication      [PARTIAL]
   |
   v
structural projection / persistence / reopen     [OPEN/PARTIAL]
```

The missing presentation/integration layers MUST NOT be solved by bypassing this backbone.

---

# 3. Delta against technical audit v1

## C1 — production Wizard mutation port was missing

Status: **CLOSED at application-core level**.

Implemented:

```text
ProjectWizardMutationPort
SharedProjectWizardMutationPort
```

The shared port is explicitly constructed over an existing `ProjectMutationSession` and owns a `ReservedProjectMutationCoordinator` bound to that exact session.

Positive invariant:

```text
Wizard does not own a second ProjectAggregateRoot timeline.
Wizard does not own a second Undo stack.
Wizard does not expose raw mutation-session internals to presentation code.
```

Remaining production evidence is covered under owner/publication integration below.

---

## C2 — canonical ownership publication was missing

Status: **PARTIALLY CLOSED**.

The canonical mutation port is now correct, but the branch still does not contain the complete production host sequence:

```text
Wizard confirm
-> one ProjectMutationResult
-> document-history record
-> onCanonicalMutationCommitted(...)
-> CanonicalProjectPersistenceOwner acceptance
-> structural projection/materialization
-> normal save/autosave
```

No Wizard-specific persistence repository should be introduced.

Mandatory exit evidence:

```text
P8-Q084 owner acknowledgement exactly once
P8-Q095 one Apply creates one canonical history item
P8-Q096 Undo/Redo remains on the same production timeline
```

---

## C3 — structural materialization gap

Status: **OPEN**.

The editor remains transitional: canonical Building/Level state and the legacy editor workspace must stay reopenable and identity-consistent.

Basic Building can create canonical Levels, but P8 does not yet prove that every generated Level can be materialized/opened in the production editor and round-trip its exact canonical `LevelId` through save/reopen.

Required boundary remains outside `WizardProvider`:

```text
committed canonical structure
-> deterministic legacy structural projection
-> empty runtime shell for new Levels
-> persisted canonical<->legacy identity binding
-> reopen exact same canonical IDs
```

This is a feature-acceptance blocker.

---

# 4. New critical finding — startup provider is intentionally disabled for New Project

Status: **OPEN / CRITICAL**.

The product requirement is that Wizard becomes a baseline project-start flow.

Current `BasicBuildingWizardProvider` declares only:

```text
WizardTargetScope.site
```

and explicitly rejects `NewProjectWizardTarget` until seed normalization exists.

The test suite codifies this current limitation:

```text
base provider is not exposed for new-project until seed normalization
```

This is a correct fail-closed implementation, but it proves that the minimum P8 startup vertical slice is not implemented yet.

Required correction:

```text
NewProjectWizardTarget
-> reuse/normalize compatibility seed Building identity
-> reuse or stably transform reference Level identity
-> add additional reserved Levels
-> preserve canonical/legacy binding
-> preview semantic changes
-> Apply exact frozen candidate
```

Do NOT simply enable `newProject` in `supportedScopes` before seed normalization is implemented.

---

# 5. New high finding — feature branch scope contamination

Status: **OPEN / HIGH**.

Compared with `main`, the branch is 51 commits ahead and includes files unrelated to the P8 Wizard feature, including changes in areas such as:

```text
docs/cable-routing-authoring-requirements.md
lib/src/domain/route_anchor_identity_reconciliation.dart
lib/src/engine/authoring_measurement_engine.dart
lib/src/features/editor/cable_endpoint_transform_session.dart
lib/src/features/editor/cable_route_edit_session.dart
lib/src/features/editor/canonical_slab_* / vertical-core routing files
test/authoring_measurement_engine_test.dart
test/route_anchor_identity_reconciliation_test.dart
tool/p8_component_move_patch.py
```

Risks:

```text
P8 review scope becomes non-deterministic
merge conflict probability increases
regressions can be incorrectly attributed to Wizard work
P8 acceptance evidence becomes mixed with unrelated engineering changes
rollback/cherry-pick becomes harder
reviewers cannot reason about one bounded feature delta
```

Required action before merge:

```text
classify every non-P8 changed file as:
A. true P8 dependency
B. already intended shared prerequisite
C. unrelated change that must be split/rebased/cherry-picked out
```

This is not a reason to redesign P8. It is branch hygiene and release-risk control.

---

# 6. Frozen preview / reservation lifecycle

Status: **PARTIALLY CLOSED, architecture strong**.

`ReservedProjectMutationCoordinator` already provides the correct safety shape:

```text
preview reserves identities once
preview captures observed LocalProjectVersion
preview is tied to coordinator/session identity
foreign preview is rejected
consumed reservation is rejected
stale observed version is rejected
commit uses _FrozenPreviewCommand
command generation/random allocation does not run again during Apply
reservation is marked consumed only after successful non-null commit
```

This substantially closes the architectural risk of preview/commit drift.

Still required as explicit regression evidence:

```text
duplicate Apply -> second commit rejected / no second mutation
foreign preview -> fail closed
failed commit -> reservation not incorrectly consumed
stale preview -> no canonical mutation
parameter change -> old preview invalidated
same parameters in a new Wizard session -> new business intent allowed
frozen candidate IDs/content == committed candidate IDs/content
```

Do not add global parameter-level deduplication. A new Wizard session with the same semantic parameters is a new user intent.

---

# 7. WizardSession state machine

Status: **PARTIALLY CLOSED / ~75%**.

Implemented states include:

```text
idle
selectingFamily
editingParameters
generating
selectingVariant
previewReady
previewBlocked
committing
completed
cancelled
failed
```

Positive behavior:

```text
parameter update invalidates current preview
preview generation checks target base version
stale preview blocks confirmation
explicit rebaseToCurrent() discards old reservation
Cancel clears transient preview state
confirm uses the frozen reserved preview
```

Important interpretation:

`rebaseToCurrent()` is acceptable only because it is explicit and invalidates the previous preview. It MUST never become an automatic hidden rebase on Apply.

Missing qualification:

```text
rapid Back/Generate/Apply sequences
resize/orientation persistence around previewReady
provider switch lifecycle
failure recovery from generator exception
failure recovery from commit exception
no event accepted after completed/cancelled except explicitly defined restart path
```

---

# 8. Basic Building provider

Status: **PARTIALLY CLOSED / ~75%**.

Implemented:

```text
typed BasicBuildingWizardParameters
name normalization
above-ground range validation
basement range validation
floor-to-floor height validation
deterministic semantic intent key
reserved Building/Level identities
canonical Site -> Building -> Level hierarchy generation
semantic create/update operations
preview side-effect-free test
single commit / single Undo test
```

Current level semantics are concrete in code:

```text
basements: -N .. -1
optional explicit ground: 0
positive levels: 1 .. N
```

When explicit ground is absent, positive Level 1 becomes the reference elevation at 0 mm.

Issue: this is not the same API shape proposed in the earlier audit (`WizardLevelNumberingConvention`). The current boolean `createGroundLevel` is testable and unambiguous enough for the present implementation, but the product/spec documents must no longer imply a different enum contract unless that migration is still intended.

Decision required before P8 freeze:

```text
Option A — retain createGroundLevel as the v1 canonical contract and update spec text.
Option B — migrate to WizardLevelNumberingConvention before public/provider API freezes.
```

Recommendation: **Option B** if multiple regional/building numbering conventions are expected in P9/P10; otherwise freeze Option A for P8 and explicitly defer richer numbering policies.

---

# 9. Semantic diff

Status: **OPEN / HIGH**.

The canonical reservation layer already exposes `ProjectSemanticChangeSet` with typed semantic operations and deterministic ordering.

That is a good source model, but it is not yet the user-facing diff required by P8.

Missing common P8 projection:

```text
WizardDiffModel
WizardDiffEntry
WizardFieldChange
WizardDiffProjector
```

Required user-facing semantics:

```text
Add / Update / Remove
entity type + stable identity/context
human label/path
field-level before / after values where meaningful
severity/blocker/warning linkage where applicable
deterministic hierarchy + semantic ordering
summary counts
filter by change kind/entity category/severity
local search for large result sets
selection link to preview scene
```

Do not expose raw JSON diff or `semanticKey` strings as the product UI.

Whole-candidate Apply/Cancel remains the P8 rule. Individual diff rows are not checkboxes for partial acceptance.

---

# 10. Vector preview / SVG

Status: **OPEN / HIGH**.

No production `WizardPreviewScene` implementation is present in the current Wizard application layer.

Required architecture:

```text
semantic candidate
-> typed WizardPreviewScene
-> Flutter/native renderer
-> optional deterministic SVG projection
```

SVG MUST NOT become canonical geometry or be parsed back into project state.

For Basic Building, a useful minimum preview is a schematic elevation stack showing:

```text
Building name
Level code/name
level number
elevation
basement/ground/above-ground distinction
```

Security constraints for SVG projection remain:

```text
no scripts
no event handlers
no foreignObject
no external URLs/resources
no active content
```

---

# 11. Production UI integration

Status: **OPEN / CRITICAL**.

`ProjectHubScreen` still follows the current direct startup path:

```text
create initial EditorProjectDocument
-> save
-> open editor
```

There is no production start gate equivalent to:

```text
New Project
  -> Create with Wizard
  -> Start blank
```

The canonical navigator and structure-authoring controls also do not expose the required contextual Wizard action.

Therefore the implemented `WizardSession` is not reachable through the intended production UX.

Required minimum vertical slice:

```text
Project Hub
-> New Project
-> Create with Wizard
-> Building
-> parameters
-> Generate
-> preview
-> Changes
-> Apply
-> one canonical mutation
-> one Undo
-> open resulting structure
-> save
-> close
-> reopen
-> same semantic fingerprint and IDs
```

---

# 12. Responsive shell and candidate carousel

Status: **OPEN / HIGH**.

Required breakpoints remain:

```text
compact  < 600
medium   600..899
expanded 900..1399
wide     >= 1400
```

The shell must preserve one `WizardSession` across:

```text
orientation change
split screen
window resize
wide <-> compact transitions
```

A layout change MUST NOT:

```text
regenerate candidate
allocate new IDs
reset selected provider
reset parameters
reset selected candidate
invalidate preview unless the canonical base changed
```

Provider-neutral candidate carousel remains P8 common infrastructure because P9 will consume it. P9 must not be forced to invent a second candidate lifecycle.

---

# 13. Persistence / publication / reopen

Status: **PARTIALLY CLOSED / HIGH**.

The shared mutation timeline is correct, but P8 completion requires proof across the production persistence boundary.

Mandatory E2E invariant:

```text
fingerprint A
-> Wizard Apply
-> fingerprint B
-> Undo
-> fingerprint A
-> Redo
-> fingerprint B
-> save
-> close
-> reopen
-> fingerprint B
```

For every newly generated Level:

```text
LevelId before save == LevelId after reopen
```

No level name, number or elevation may be used as identity fallback.

Failure mode qualification must include canonical-ahead-of-legacy recovery where canonical save/publication succeeds but structural legacy projection/save is interrupted.

---

# 14. CI and automated-test status

Status: **CI CLOSED, qualification PARTIAL**.

Exact audited SHA is fully green for the repository workflow.

Current P8-specific tests directly prove at least:

```text
provider registry target filtering
preview side-effect freedom
single confirm advances canonical version once
single confirm adds one Undo item
Undo removes generated hierarchy
parameter blockers prevent generation
stale frozen preview fails closed
explicit rebase creates a fresh reservation
Basic Building normalization/validation
Basic Building deterministic intent
Building/Level hierarchy generation
Level numbering/elevation behavior
NewProject provider is intentionally unavailable until seed normalization
```

Missing P8-specific adversarial tests include:

```text
duplicate Apply
foreign preview
failed commit reservation recovery
parameter-change invalidation after preview
same-parameters new-session semantics
exact candidate fingerprint equality on commit
owner publication exactly once
Undo + Redo E2E
save/reopen identity/fingerprint
projection recovery
responsive state preservation
semantic-diff ordering/filtering at scale
preview-scene determinism
SVG safety
```

---

# 15. NFR qualification status

Status: **OPEN / PARTIAL**.

The following production thresholds remain mandatory until deliberately changed by the specification authority:

| Area | Target | Current evidence |
|---|---:|---|
| semantic diff, <=10k changed entities | p95 <= 2.0 s | OPEN |
| semantic diff, <=10k changed entities | p99 <= 3.5 s | OPEN |
| Basic Building <=230 Levels generation | p95 <= 300 ms | OPEN |
| Basic Building preview-ready | p95 <= 500 ms | OPEN |
| local Wizard interactions | p95 <= 100 ms | OPEN |
| commit excluding separately characterized storage sync | p95 <= 3.0 s | OPEN |
| additional memory for 10k diff entries | <=150 MB | OPEN |
| 1000 preview/cancel cycles | 0 canonical mutations | OPEN |
| 1000 duplicate Apply simulations | 0 duplicate commits | OPEN |
| stale detection | 100% | PARTIAL unit evidence |

Reference hardware and benchmark harness must be fixed before performance numbers are accepted.

Accessibility/security/localization qualification still required:

```text
keyboard-only flow
touch targets >= 48x48
no color-only state
screen-reader semantics
text scaling
reduced motion
RU/EN-safe user-facing messages / no domain semantics dependent on locale
SVG active-content rejection
metadata-only telemetry where project content is sensitive
```

---

# 16. Work-package status

| WP | Area | Status | Estimate |
|---|---|---|---:|
| WP00 | specification/readiness | DONE | 100% |
| WP01 | typed Wizard contracts | GREEN | 90% |
| WP02 | provider registry/capabilities | PARTIAL | 60% |
| WP03 | responsive primitives | OPEN | 5% |
| WP04 | Basic Building provider | GREEN/PARTIAL | 75% |
| WP05 | shared reserved mutation bridge | GREEN | 90% |
| WP06 | candidate/session coordinator | GREEN/PARTIAL | 75% |
| WP07 | semantic user diff | OPEN | 15% |
| WP08 | vector preview/SVG | OPEN | 5% |
| WP09 | Wizard state machine | PARTIAL | 70% |
| WP10 | responsive Wizard shell | OPEN | 5% |
| WP11 | candidate carousel | OPEN | 5% |
| WP12 | Project Hub integration | OPEN | 5% |
| WP13 | Navigator integration | OPEN | 5% |
| WP14 | persistence/publication/materialization | PARTIAL | 45% |
| WP15 | recovery/accessibility/performance | PARTIAL | 25% |
| WP16 | qualification/closure/P9 handoff | PARTIAL | 40% |

These percentages are engineering-readiness estimates, not schedule estimates.

---

# 17. Risk register

## Closed / materially mitigated

```text
R1 second Wizard mutation engine                    CLOSED
R2 second Wizard Undo timeline                      CLOSED
R3 preview writes canonical state                   CLOSED by architecture/tests
R4 regeneration/random allocation during Apply      CLOSED by frozen preview command
R5 stale Apply silently overwrites newer version    CLOSED by architecture; more E2E desired
R6 repository format/analyze/test gate              CLOSED
```

## Partially closed

```text
R7 exact preview candidate == committed candidate   strong architecture, fingerprint test missing
R8 duplicate Apply                                  consumed reservation exists, explicit test missing
R9 failed commit reservation semantics              correct ordering appears present, explicit test missing
R10 one Apply == one production history/Undo item   unit proof exists, production E2E missing
R11 save/reopen exact identity                      persistence bridge missing
R12 canonical owner acknowledgement                 production wiring/evidence incomplete
```

## Open / blocking acceptance

```text
R13 NewProject Basic Building unavailable           CRITICAL
R14 Project Hub Wizard entry absent                 CRITICAL
R15 full UI -> Apply -> persist -> reopen E2E absent CRITICAL
R16 semantic human diff absent                      HIGH
R17 vector preview scene absent                     HIGH
R18 responsive shell absent                         HIGH
R19 candidate carousel absent                       HIGH
R20 Navigator Wizard entry absent                   HIGH
R21 structural Level materialization/reopen gap     HIGH/CRITICAL
R22 branch contains unrelated feature changes       HIGH merge/review risk
R23 performance/accessibility/security qualification HIGH before production acceptance
```

---

# 18. Architecture decisions to freeze

Do not redesign the following while closing the remaining work:

1. `ProjectMutationSession + ReservedProjectMutationCoordinator` is the only commit backbone.
2. Wizard preview is not canonical state.
3. Prepared preview owns one frozen candidate and one reservation lifecycle.
4. Apply commits the exact frozen candidate; it never invokes provider generation again.
5. Stale preview fails closed. Refresh/rebase is explicit and requires a new preview.
6. One successful Apply produces one canonical mutation/change set and one Undo item.
7. Provider contracts remain typed and target-aware.
8. Whole-candidate Apply/Cancel is the P8 acceptance model; no per-diff-row partial commit.
9. `WizardPreviewScene` is a rendering-neutral projection; SVG is output only.
10. NewProject seed normalization/materialization belongs in production integration, not in ad-hoc widget mutation code.

---

# 19. Recommended implementation sequence from current HEAD

## P8-1 — adversarial core qualification

Add tests for:

```text
duplicate Apply
foreign preview
failed commit reservation
parameter invalidation
same-parameter new session
frozen candidate fingerprint equality
```

Do this before expanding UI so the transaction contract becomes regression-proof.

## P8-2 — NewProject seed normalization contract

Implement the compatibility-seed reuse strategy and enable Basic Building for `NewProjectWizardTarget` only after the generated hierarchy remains reopenable.

## P8-3 — semantic diff projection

Implement a human-facing diff model over `ProjectSemanticChangeSet` + canonical before/candidate snapshots.

## P8-4 — WizardPreviewScene

Implement deterministic Basic Building schematic scene and safe SVG-compatible projection.

## P8-5 — responsive WizardShell

Implement responsive layout without moving canonical/session ownership into widgets.

## P8-6 — Project Hub startup integration

Expose:

```text
Create with Wizard
Start blank
```

with precise Cancel semantics.

## P8-7 — Navigator integration

Expose only providers supported for the active runtime target.

## P8-8 — owner publication + structural materialization

Wire canonical owner acknowledgement exactly once and project newly created Levels into the transitional editor runtime.

## P8-9 — persistence/Undo/Redo/reopen E2E

Prove the A -> B -> A -> B fingerprint sequence and exact ID round-trip.

## P8-10 — provider-neutral carousel

Finish common carousel before P9 apartment variants depend on it.

## P8-11 — NFR and failure qualification

Run 10k diff, memory, 1000-cycle, accessibility, SVG safety and recovery suites.

## P8-12 — branch scope cleanup

Split or justify unrelated files before final PR/merge review.

---

# 20. P8 acceptance gate

P8 may be marked `ACCEPTED` only when the following path is executable in production composition without test-only seams:

```text
Project Hub
-> New Project
-> Create with Wizard
-> Basic Building
-> typed parameters
-> Generate
-> deterministic meaningful preview
-> semantic Changes list
-> Back / Cancel / Apply
-> Apply exact frozen preview
-> exactly one canonical change/history item
-> exactly one Undo
-> Redo restores exact candidate
-> generated Level is openable
-> save
-> close
-> reopen
-> exact canonical identities and semantic fingerprint restored
```

and:

```text
CI is green
critical/high audit findings are closed or explicitly accepted with documented owner
performance/accessibility/security gates are evidenced
branch delta is reviewable and free of unexplained unrelated work
```

Until then the correct state is:

```text
P8 CORE FOUNDATION IMPLEMENTED
P8 PRODUCTION VERTICAL SLICE INCOMPLETE
```
