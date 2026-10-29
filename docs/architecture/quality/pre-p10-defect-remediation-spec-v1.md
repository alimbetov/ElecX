# PRE-P10 Defect Remediation & Closure Specification v1

**Branch:** `feat/pre-p10-defect-remediation`  
**Parent hardening branch:** `feat/pre-p10-cross-platform-hardening`  
**Baseline synchronization commit:** `8dfd5aae40c1f1ff8db3e12d1516594076793324`  
**Accepted main/P9 merge reference:** `68e4e71e2239216de2a4e4aab344a77235bfa07f`  
**Purpose:** production remediation and executable closure of PRE-P10/P9 defects before P10.  
**P10 status:** BLOCKED until final exact-SHA acceptance.

## 1. Decision

This document is the implementation/closure layer above the existing PRE-P10 discovery and acceptance package. It does not replace defect ledgers. The result of this branch shall be a production-ready P1-P9 baseline with proven persistence integrity, canonical ownership, P9 engineering integrity, native runtime qualification, five-platform semantic parity and exact-SHA evidence.

```text
P1-P9 semantics
+ canonical integrity
+ persistence/recovery integrity
+ production Wizard/P9 integration
+ committed native shells
+ native runtime qualification
+ responsive/a11y/i18n
+ five-platform semantic parity
+ destructive/adversarial journeys
+ exact-SHA evidence
=
PRE-P10 BASELINE ACCEPTED
```

## 2. Normative inputs

The following remain authoritative evidence/contracts:

- `pre-p10-cross-platform-hardening-plan-v1.md`;
- `pre-p10-pass1-findings-v3.md` (`PRE10-D001..D012`);
- `pre-p10-pass1-second-search-findings-v1.md` (`PRE10-D013..D020`);
- `pre-p10-pass1-traceability-v1.md`.

Confirmed late P9 findings `P9-DEF-018..P9-DEF-031` are included in remediation under their original IDs. They must not be duplicated as new PRE10 IDs. `P9-DEF-032-Q` remains a qualification item until reproduced.

## 3. Defect scope

### PRE-P10

| ID | Sev | Area |
|---|---:|---|
| PRE10-D001 | P1 | committed native shells |
| PRE10-D002 | P2 | immutable Flutter toolchain |
| PRE10-D003 | P1 | native runtime qualification |
| PRE10-D004 | P1 | complete five-platform CI |
| PRE10-D005 | P2 | startup physical keyboard input |
| PRE10-D006 | P2 | startup RU/EN localization |
| PRE10-D007 | P1 | startup responsive/text-scale |
| PRE10-D008 | P2 | Project Hub localization |
| PRE10-D009 | P1 | storage-init recovery |
| PRE10-D010 | P3 | stale architecture documentation |
| PRE10-D011 | P1 | Android/iOS semantic parity |
| PRE10-D012 | P2 | delayed unlock cancellation |
| PRE10-D013 | P1 | destructive recovery deletion |
| PRE10-D014 | P1 | legacy `.bak` fallback |
| PRE10-D015 | P1 | non-transactional Wizard project creation |
| PRE10-D016 | P1 | recovery deleted before replacement load |
| PRE10-D017 | P1 | canonical-inconsistent recovery snapshot |
| PRE10-D018 | P2 | raw internal exceptions in production UI |
| PRE10-D019 | P1 | wall-clock recovery ordering |
| PRE10-D020 | P1 | canonical-only mutation bypasses dirty state |

### P9 late-audit intake

Remediation must also close `P9-DEF-018..P9-DEF-031` with traceable executable evidence. No renumbering is allowed merely because the fix is performed in PRE-P10.

## 4. Deduplication rule

Before creating a new defect ID:

```text
candidate
 -> compare PRE10-D001..D020
 -> compare P9-DEF register
 -> compare historical final-review/RR findings
 -> distinct root cause and independent closure gate?
      NO  -> attach evidence to existing defect
      YES -> allocate next ID
```

Rephrased symptoms are not new defects.

## 5. Mandatory architecture invariants

### INV-01 Fail closed
Unknown schema/version, missing required production dependency, corrupted lineage or tampered payload must be rejected explicitly. Silent approximation or topology-only fallback is forbidden unless the mode is explicitly selected by contract.

### INV-02 Canonical authority
UI state, legacy projection, recovery state, bindings and engineering snapshots cannot independently define semantic truth.

### INV-03 Mutation success is atomic to the user
A UI operation is successful only after mandatory ownership/integrity acknowledgements complete. Ownership failure must not be swallowed.

### INV-04 Durable state cannot regress
An older snapshot may never replace a newer durable revision.

### INV-05 Fingerprints are derived values
Fingerprints must be recomputed from canonical normalized payloads, never trusted as caller-controlled domain input.

### INV-06 Schema evolution is explicit
Unknown semantic fields/versions must be migrated explicitly, preserved only through an explicit opaque-extension contract, or rejected. Silent field loss is forbidden.

### INV-07 Recovery is coherent
Recovery must restore a consistent canonical/materialized project state, not only one representation.

### INV-08 Logical ordering is monotonic
Wall clock is display metadata, not semantic ordering authority.

### INV-09 Lifecycle state is bounded
Discarded previews, consumed reservations and completed sessions must not retain full aggregates indefinitely.

### INV-10 Platform semantics are equal
Equivalent deterministic inputs produce equal semantic artifacts on Linux, Windows, macOS, Android and iOS/iPadOS.

### INV-11 Safe production errors
Raw exception text, filesystem details and stack traces are not user-facing contracts.

## 6. WP-01 — Toolchain and committed native shells

**Defects:** `PRE10-D001`, `D002`, `D010`.

1. Establish one repository-owned exact Flutter SDK version source.
2. All hard workflows must consume that exact version and emit `flutter --version`/`dart --version` evidence.
3. Floating `channel: stable` is not sufficient for acceptance.
4. Pinning precedes production native-shell generation.
5. Commit reviewed production shells for Linux, Windows, macOS, Android and iOS.
6. Final CI must not execute `flutter create` to compensate for missing production shells.
7. Correct stale repository architecture comments/docs while closing D010.

## 7. WP-02 — Native runtime and five-family parity

**Defects:** `PRE10-D003`, `D004`, `D011`.

Every platform family must independently prove:

```text
build -> launch -> project create/open -> representative edit
-> P8/P9 production journey -> persistence -> close/reopen
-> semantic artifact emission
```

Build-only evidence is insufficient.

Semantic artifact must contain platform-neutral fields such as canonical fingerprint, logical revision, P8/P9 fingerprints, provenance fingerprint and reopen fingerprint. Absolute paths, timestamps, device IDs and native window geometry are excluded.

Final semantic condition:

```text
Linux == Windows == macOS == Android == iOS
```

for all semantic fields.

## 8. WP-03 — Startup, Hub, input, i18n and safe failures

**Defects:** `PRE10-D005`, `D006`, `D007`, `D008`, `D009`, `D012`, `D013`, `D018`.

Existing fix candidates D005/D006/D007/D009/D012 must first be qualified by their existing probes. They become CLOSED only when repeatable exact-SHA evidence is green.

Project Hub/recovery/create-project copy must use typed RU/EN localization. Hard-coded production UI strings are not accepted where the app contract is localized.

Recovery delete must require explicit confirmation or an equivalent undoable staged-delete contract. Cancellation must produce zero storage mutations and be tested for pointer, keyboard, touch and accessibility activation.

Introduce a typed/safe error boundary. Internal `Object`/exception details are retained for diagnostics, while UI receives stable diagnostic codes and localized safe summaries. Regression must inject a sentinel internal string and assert that it is never rendered.

## 9. WP-04 — Persistence, recovery and durability foundation

**Defects:** `PRE10-D014`, `D015`, `D016`, `D017`, `D019`, `D020`; related `P9-DEF-022`; qualification `P9-DEF-032-Q`.

This package must be solved through one durability model, not unrelated callback patches.

### Logical revision

Define a monotonic project lineage/revision contract. Authoritative mutations, including legacy edits, canonical edits, Wizard Apply, Undo and Redo, advance logical revision according to one documented transaction semantics.

Suggested state model:

```text
currentRevision
canonicalDurableRevision
legacyDurableRevision
recoveryRevision
```

The shell reports `Saved` only when required authoritative state is durable. Canonical-only mutation must transition to Modified, schedule recovery and activate exit protection.

### D014 backup fallback

`JsonFileEditorProjectStore.load()` and `list()` must apply the same policy:

```text
try primary
 -> read/decode/schema failure
 -> try .bak
 -> valid backup => recover
 -> both invalid => deterministic failure
```

One corrupt project must not hide healthy projects.

### D015 transactional Wizard creation

No committed blank project may survive Wizard Cancel/failure. Prefer in-memory/staged creation followed by one coherent canonical+legacy commit after successful Apply. Cancel/failure leaves project list and both stores unchanged.

### D016 replacement load safety

Never delete recovery before a replacement saved document has loaded, decoded and validated successfully. `null`, exception or validation failure must preserve recovery and autosave lifecycle.

### D017 coherent recovery envelope

Recovery must contain or deterministically reconstruct the matching canonical state. Recommended envelope:

```text
ProjectRecoveryEnvelope
  recoverySchemaVersion
  projectId
  lineageId
  logicalRevision
  capturedAt
  legacyDocument + fingerprint
  canonicalSnapshot + fingerprint
```

Restore validates identity, lineage, revision, fingerprints and cross-representation consistency before exposing the project.

### D019 monotonic ordering

Freshness is determined by lineage + logical revision. `capturedAt` is display metadata or a non-destructive tiebreaker only. Required test: revision 11 with an earlier clock timestamp wins over revision 10.

### D020 canonical dirty state

Every accepted canonical commit/undo/redo must advance shell dirty state exactly once and participate in coherent recovery/durability.

## 10. P9-DEF-032-Q — Out-of-order Save qualification

Run a controlled race:

```text
snapshot vN
Save A(vN) starts and blocks
mutation -> vN+1
Save B(vN+1) completes
Save A(vN) completes last
close/reopen
```

Required result: reopened revision is `vN+1`.

If `vN` can become durable, promote to confirmed `P9-DEF-032` and implement both owner-level save serialization/coalescing and repository-level stale-write rejection/CAS semantics. Atomic file replacement alone does not solve stale ordering.

## 11. WP-05 — P9 engineering integrity

**Defects:** `P9-DEF-019`, `020`, `024`, `025`, `026`, `030`, `031`.

- D8 output fingerprint must be recomputed on construction/bind/decode/reopen; tampered payload with preserved hash is rejected.
- Engineering proposal must have explicit validity/staleness lifecycle (`valid`, topology/semantics/normative/supply stale reasons or equivalent).
- Cross-registry invariants must validate proposal level/candidate/intent fingerprints against generation manifest on mutation, save, decode, reopen, undo and redo.
- Generation manifest target lineage must resolve project/site/building/level/apartment-zone/generated entities and reject foreign/dangling IDs.
- Generated baseline fingerprint must be validated; active generation keys and removed tombstone keys must be disjoint; `invalidBaseline` must become executable validation.
- Unknown future semantic/provenance contract must follow explicit migration/preservation/fail-closed rules; silent discard is forbidden.
- Nested proposal/output semantic versions require explicit supported-version dispatch; non-empty strings are not version validation.

## 12. WP-06 — P9 runtime ownership and production materialization

**Defects:** `P9-DEF-021`, `022`, `027`, `028`, `029`.

- Runtime engineering pipeline registry must support replace/unbind; resolving `null` must clear prior session binding.
- Canonical ownership acknowledgement must be part of success semantics and errors must propagate.
- Separate structural-authoring, wizard-mutation and engineering-wizard capabilities. Reported enabled state must match actual entrypoint behavior.
- P9 Apply must end with generated Zone/Space reachable in the production editor. Binding/materialization reconciliation is part of the Apply lifecycle, not a manual afterthought.
- Engineering-required production mode with missing pipeline must block/fail closed. Geometry-only is allowed only through explicit topology-only policy.

## 13. WP-07 — P9 candidate and lifecycle hardening

**Defects:** `P9-DEF-018`, `P9-DEF-023`.

Final recommendation is selected only after rendering, canonical projection and normative/engineering eligibility. If rank #1 becomes ineligible and #2 is eligible, #2 becomes the recommendation deterministically.

Preview/reservation lifecycle must be bounded. Completed/discarded items may retain lightweight IDs/tokens but not indefinitely retain full candidate aggregates. Run at least 1000 Generate -> Preview -> Cancel/Apply cycles and prove no linear retained-state growth.

## 14. Mandatory destructive/adversarial campaign

Run:

```text
Generate -> Preview -> Apply -> Save -> Close -> Reopen
-> Edit -> Delete -> Undo -> Redo -> Re-Save -> Close -> Reopen
```

After each transition validate canonical graph, logical revision, proposal validity, generation lineage, provenance/tombstones, dirty state, recovery state, binding reachability and canonical fingerprint.

Additional variants:

- malformed persistence;
- cross-version persistence;
- unknown nested engineering version;
- tampered fingerprint;
- stale preview/reservation;
- project A/project B session isolation;
- clock rollback;
- corrupt primary + valid backup;
- failed replacement load;
- failed Wizard creation;
- ownership acknowledgement failure;
- concurrent/out-of-order Save.

## 15. Stable closure qualification IDs

```text
PRE10-CQ01 pinned Flutter toolchain
PRE10-CQ02 committed native shells
PRE10-CQ03 five-platform native runtime smoke
PRE10-CQ04 five-platform semantic parity
PRE10-CQ05 Project Hub RU/EN
PRE10-CQ06 recovery deletion confirmation
PRE10-CQ07 raw-error leakage rejection
PRE10-CQ08 legacy corrupt-primary -> valid backup
PRE10-CQ09 Wizard Cancel -> zero durable project
PRE10-CQ10 Wizard failure -> zero durable project
PRE10-CQ11 failed saved-version load preserves recovery
PRE10-CQ12 canonical mutation -> recovery -> crash -> coherent restore
PRE10-CQ13 clock skew -> logical revision wins
PRE10-CQ14 canonical-only commit -> Modified/autosave/exit guard
PRE10-CQ15 out-of-order Save qualification
PRE10-CQ16 blocked top1 -> eligible top2 recommended
PRE10-CQ17 D8 payload tamper rejected
PRE10-CQ18 proposal staleness after canonical edit
PRE10-CQ19 pipeline bind -> unbind
PRE10-CQ20 owner ACK failure does not produce success
PRE10-CQ21 1000 preview/reservation cycles bounded
PRE10-CQ22 cross-registry lineage mismatch rejected
PRE10-CQ23 invalid manifest target lineage rejected
PRE10-CQ24 baseline/tombstone corruption rejected
PRE10-CQ25 wizard capability consistency
PRE10-CQ26 P9 Apply -> generated room opens in production editor
PRE10-CQ27 required engineering pipeline missing -> blocked
PRE10-CQ28 unknown provenance semantic contract rejected/preserved explicitly
PRE10-CQ29 unknown proposalVersion rejected
PRE10-CQ30 unknown outputProjectionVersion rejected
PRE10-CQ31 destructive full lifecycle roundtrip
```

Every CQ must map to defect ID, test file/test name, CI job, platform coverage and exact qualification SHA.

## 16. Production P9 Golden Journey

Required real-composition journey:

```text
CanonicalEditorProductionHandle
 -> UnifiedWorkspaceEditorScreen
 -> Apartment Wizard
 -> Preview
 -> Apply
 -> owner ACK
 -> binding/materialization reconciliation
 -> select generated room
 -> open generated room
 -> edit
 -> Save
 -> close/reopen
 -> open same room
```

Assert no silent geometry-only fallback, no stale proposal, no broken binding, no lost provenance, no fingerprint mismatch, no owner/session divergence and no missing generated IDs.

## 17. CI architecture

Final hard workflow must contain independent jobs for repository quality, domain/application regression, defect-closure tests, persistence/recovery adversarial tests, P8/P9 integration, responsive/a11y/i18n, Linux/Windows/macOS runtime, Android runtime, iOS runtime, semantic artifact emission/comparison, destructive campaign and exact-SHA final audit.

No hard gate may be masked by `continue-on-error`. Final acceptance may not rely on generated native shells or floating Flutter stable.

## 18. Implementation order

```text
Phase 0 baseline sync + characterization
Phase 1 exact Flutter pinning
Phase 2 committed native shells
Phase 3 persistence/recovery/dirty-state foundation
Phase 4 P9 engineering integrity/schema/provenance
Phase 5 P9 runtime ownership/materialization
Phase 6 startup/Hub/error-boundary cleanup
Phase 7 native runtime harnesses
Phase 8 five-platform semantic parity
Phase 9 destructive/adversarial campaign
Phase 10 exact-SHA final audit
```

Hard dependency: D002 precedes D001. The unified durability model precedes scattered D017/D019/D020 fixes.

## 19. Closure matrix

Maintain `pre-p10-defect-closure-matrix-v1.md` with fields: defect ID, severity, root cause, fix commit, regression test, CI job, platforms, qualification SHA, evidence run and final status.

Allowed statuses:

```text
CONFIRMED
IMPLEMENTING
FIXED / AWAITING QUALIFICATION
CLOSED
ACCEPTED DISPOSITION
```

A code change without executable evidence is never CLOSED.

## 20. Final Definition of Done

P10 may be unblocked only when one unchanged exact SHA satisfies all of the following:

- branch synchronized with intended main;
- exact Flutter SDK pinned;
- Linux/Windows/macOS/Android/iOS production shells committed;
- all five native runtime families PASS;
- RU/EN, responsive, text-scale, accessibility, reduced-motion and input-modality gates PASS;
- persistence/recovery and destructive lifecycle campaigns PASS;
- P8/P9 real production journeys PASS;
- semantic artifacts are equal across all five platform families;
- Save/Reopen and Undo/Redo invariants PASS;
- unknown schema/version behavior is explicit and fail-closed where required;
- provenance/engineering integrity PASS;
- all P0/P1 defects CLOSED;
- correctness/data-integrity P2 defects CLOSED, other P2s explicitly dispositioned only where parent contract permits;
- PRE10/P9 closure matrix current;
- `P9-DEF-032-Q` either becomes a fixed confirmed defect or a documented qualified non-finding;
- final exact-SHA audit is archived and all hard jobs are unmasked.

Final state:

```text
PRE-P10 HARDENING         = ACCEPTED
P1-P9 PRODUCTION BASELINE = ACCEPTED
P10 DEVELOPMENT           = UNBLOCKED
```
