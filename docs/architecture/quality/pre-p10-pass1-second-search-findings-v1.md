# PRE-P10 PASS-1 — second-search new-defect ledger v1

**Date:** 2026-10-28  
**Branch:** `feat/pre-p10-cross-platform-hardening`  
**Detecting SHA:** `157106667df3af6116d970ca999ca881941a4b0d`  
**Scope:** second independent repository/architecture/platform audit after the initial PASS-1 inventory.

## Counting rule

`PRE10-D001` through `PRE10-D012` are the established baseline from `pre-p10-pass1-findings-v3.md` and are **explicitly excluded from this document and from the new-defect count**. A finding is recorded below only when it is a distinct failure mode, with a separate root cause and closure gate.

**Second-search result: 8 new defects — 7 P1, 1 P2.**

| ID | Severity | Status | New failure class |
|---|---|---|---|
| PRE10-D013 | P1 | CONFIRMED | crash-recovery snapshot can be irreversibly discarded in one action |
| PRE10-D014 | P1 | CONFIRMED | legacy project store does not fall back to a valid `.bak` when primary exists but is corrupt |
| PRE10-D015 | P1 | CONFIRMED | Wizard project creation is not transactional; cancel/failure leaves persistent ghost project state |
| PRE10-D016 | P1 | CONFIRMED | opening saved version destroys recovery before replacement load succeeds |
| PRE10-D017 | P1 | CONFIRMED | recovery autosave is not canonical-consistent and can become unrestorable |
| PRE10-D018 | P2 | CONFIRMED | raw internal exceptions are rendered directly in production UI |
| PRE10-D019 | P1 | CONFIRMED | recovery ordering/freshness relies on wall clock instead of monotonic revision/lineage |
| PRE10-D020 | P1 | CONFIRMED | canonical-only commits can bypass dirty-state/autosave/exit protection |

---

## PRE10-D013 — destructive recovery discard has no confirmation or undo

### Evidence

`lib/src/features/projects/project_hub_screen.dart` invokes recovery-store `discard(projectId)` directly from the recovery card delete action. The UI has no confirmation, staged deletion, undo token, or recovery recycle boundary.

`test/project_hub_recovery_test.dart` currently codifies immediate deletion rather than a protected destructive journey.

### Risk

A single accidental activation can destroy the only unsaved crash-recovery state.

### Closure gate

- recovery deletion requires explicit confirmation or an undoable staged delete;
- cancellation leaves the snapshot byte-for-byte available;
- keyboard/touch/accessibility activation is covered;
- regression proves no destructive side effect before confirmation.

---

## PRE10-D014 — corrupt legacy primary masks a valid backup

### Evidence

`JsonFileEditorProjectStore.load()` in `lib/src/features/editor/editor_project_document.dart` selects the primary file whenever it exists and only selects `.bak` when primary is absent. A primary decode/schema failure therefore terminates the load instead of retrying the valid backup.

`list()` has the same asymmetry: a corrupt primary can suppress the project even if a valid backup exists.

This is distinct from the canonical repository, whose corrupt-primary/valid-backup recovery is already qualified.

### Risk

A recoverable project can appear corrupt or missing despite a valid on-disk backup.

### Closure gate

- `load()` falls back on primary read/decode/schema failure;
- `list()` uses the same fallback semantics;
- corrupt-primary + valid-backup is executable-qualified;
- double-corruption fails deterministically without hiding healthy projects.

---

## PRE10-D015 — Wizard project creation persists before commit

### Evidence

`ProjectHubScreen._createProject()` persists `initialDocument` before entering the Wizard. `_configureNewProjectWithWizard()` then calls `CanonicalEditorProductionHandle.loadOrBootstrap(...)`, which also creates/saves the canonical sidecar when absent.

`ProjectWizardScreen._cancel()` returns `null`; the caller reloads the Hub but does not roll back either persistence boundary.

Failure sequence:

```text
Create through Wizard
→ save blank legacy project
→ bootstrap/save blank canonical sidecar
→ open Wizard
→ Cancel or Wizard failure
→ legacy + canonical records remain
```

### Risk

Cancelled/failed creation leaves ghost projects and violates the intended preview/apply transactional model.

### Closure gate

- no durable project state before successful Wizard Apply; or a staged transaction is fully rolled back;
- cancel/failure leave legacy and canonical stores unchanged;
- successful creation persists one coherent project pair;
- executable tests cover cancel, thrown failure, and success.

---

## PRE10-D016 — saved-version open deletes recovery before load succeeds

### Evidence

In `UnifiedWorkspaceEditorScreen`, the saved-version open flow calls `_discardRecoveryBestEffort()` before attempting `projectStore.load(projectId)`.

`_discardRecoveryBestEffort()` cancels the autosave timer, advances the recovery generation, deletes the snapshot, and resets autosave bookkeeping. If the following load returns `null` or throws, the current unsaved in-memory workspace remains open, but its recovery protection has already been removed and is not restarted on that failure path.

### Risk

A failed open operation can turn a previously crash-recoverable unsaved session into an unprotected session.

### Closure gate

- recovery is discarded only after a validated replacement document is ready;
- failed/null load preserves the snapshot and autosave lifecycle;
- regression covers both `null` and thrown load failures.

---

## PRE10-D017 — recovery snapshot is not an atomic canonical/legacy recovery unit

### Evidence

`UnifiedWorkspaceEditorScreen._writeRecoverySnapshot()` captures only `EditorProjectDocument` and its recovery metadata. It does not persist the corresponding canonical aggregate snapshot or canonical delta/lineage.

Canonical mutations are synchronously accepted by `CanonicalProjectPersistenceOwner`, but repository durability remains an explicit later `save()` operation. `CanonicalEditorProductionHandle.loadOrBootstrap()` validates the persisted canonical sidecar against the supplied legacy/recovery document and fails closed on divergence.

Therefore this crash window is possible:

```text
persisted canonical = Vn
canonical in-memory mutation = Vn+1
legacy projection/recovery snapshot = Vn+1
crash before explicit Save
persisted canonical remains Vn
restore recovery document Vn+1
→ sidecar validation sees Vn != recovered materialization
→ valid recovery cannot be opened coherently
```

Existing P8 crash-window qualification covers the opposite direction (canonical newer than legacy) and does not close this case.

### Risk

A valid autosave can exist but be rejected after crash because its canonical counterpart was not captured atomically.

### Closure gate

- recovery stores an atomic canonical + materialized pair, or sufficient canonical delta/version lineage to reconstruct it;
- restore binds the exact matching canonical state;
- crash-window regression covers canonical mutation → autosave → crash before manual Save;
- recovered canonical fingerprint equals the pre-crash in-memory fingerprint.

---

## PRE10-D018 — production UI leaks raw internal exceptions

### Evidence

`WizardSession` catches arbitrary `Object` instances and stores them as `failure`. `ProjectWizardScreen` renders `_session.failure.toString()` directly.

Project Hub also interpolates caught exception objects directly into user-visible SnackBars/cards, including project creation, Wizard Apply, canonical open/projection, and load failure paths.

This is a distinct error-boundary defect, not the existing Hub localization defect.

### Risk

Internal `StateError`/`ArgumentError` messages, identifiers, versions, filesystem details, and implementation diagnostics can leak into production UI and are not stable/localizable user contracts.

### Closure gate

- internal failures map to stable diagnostic/error codes;
- user-facing summaries are localized and safe;
- raw exception/stack details are retained only in diagnostics/logging;
- regression injects a sentinel internal string and proves it is not rendered to the user.

---

## PRE10-D019 — recovery freshness is wall-clock ordered despite monotonic revision

### Evidence

`EditorProjectRecoverySnapshot` stores both `capturedAt` and integer `revision`, but `JsonFileEditorProjectRecoveryStore.load()` and `list()` choose among target/backup/temp candidates by `capturedAt` only.

Project Hub and editor recovery-offer logic also compare recovery freshness to saved state using timestamps. `_offerRecoveryIfNewer()` can discard a snapshot solely because its wall-clock timestamp is not later than the saved document timestamp.

Clock-skew example:

```text
backup: revision 10, capturedAt 10:05
clock corrected backwards
target: revision 11, capturedAt 09:58
→ timestamp ordering chooses revision 10
```

### Risk

NTP correction, VM resume, manual clock change, or platform clock anomaly can hide or delete a logically newer recovery state.

### Closure gate

- recovery ordering uses a monotonic revision/lineage contract;
- wall clock is display metadata or a defined tiebreaker only;
- no snapshot is destructively discarded solely from wall-clock comparison;
- clock-skew regression proves higher logical revision wins even with earlier `capturedAt`.

---

## PRE10-D020 — canonical-only commit can remain visually saved and unprotected

### Evidence

`CanonicalProjectPersistenceOwner.acceptMutation()` explicitly provides synchronous ownership only; disk durability occurs later through `save()`.

`UnifiedWorkspaceEditorScreen` marks the document dirty by incrementing `_projectRevision` in `_onProjectChanged()`. However canonical authoring and space-semantics commit callbacks record canonical history, acknowledge the canonical owner, call projection/refresh, but do not call the screen dirty-state transition.

During canonical-to-editor cutover, `_onProjectChanged()` deliberately returns early while `coordinator.isSynchronizing`, so projection notifications do not repair the missing revision increment.

The existing `canonical_projection_dirty_state_test.dart` proves only that the underlying command-history projection advances its own mutation revision without manufacturing Undo; it does not prove `UnifiedWorkspaceEditorScreen._projectRevision`, recovery autosave, save label, or exit guard.

Failure class:

```text
Saved screen
→ canonical-only command commits Vn→Vn+1
→ persistence owner accepts Vn+1 in memory
→ screen projectRevision does not advance
→ UI may still report Saved
→ recovery autosave is not scheduled
→ exit guard sees no unsaved change
→ process/navigation exit before explicit Save
→ persisted canonical remains Vn
```

### Risk

A canonical P3/P6/P8/P9 edit can be accepted in memory but lose durability/recovery protection because the shell does not know that the project became dirty.

### Closure gate

- every owned canonical commit/undo/redo advances one shell-level dirty revision exactly once;
- save status becomes `Modified` until both canonical and legacy durability complete;
- autosave/recovery covers canonical-only state coherently with D017;
- back/close guard treats canonical-only commits as unsaved;
- executable test proves canonical-only commit → Modified → recovery scheduled → Save → Saved.

---

## Checked but not counted as new defects

The second search also re-checked the following and intentionally did **not** add new IDs:

- D001–D012: baseline defects, excluded by rule;
- canonical repository corrupt-primary fallback: already qualified; D014 is specifically the still-different legacy store behavior;
- editor `PopScope` unsaved-change confirmation: existing ordinary-edit path is present and not counted;
- project-id path traversal: persisted filenames are encoded; no new traversal defect recorded;
- canonical-first dual-write ordering: intentional fail-closed design; no new defect recorded without a separate failing scenario;
- P8 crash-window recovery: strong for canonical-newer/legacy-older, but it does not cover D017's inverse recovery window;
- repeated localization/platform gaps already represented by D001–D012 were not reclassified under new IDs.

## Second-search disposition

```text
PASS-1 SECOND SEARCH = COMPLETE FOR THIS INVENTORY CUT
NEW DEFECTS          = 8
P1                   = 7
P2                   = 1
DUPLICATES COUNTED   = 0
P10                   = BLOCKED
```

No item in this document is `CLOSED`. These findings are discovery evidence only; implementation and exact-SHA qualification belong to the subsequent hardening pass.