# P7A-6.1 Stale-Version / Concurrent Mutation Races — Deep-Review Closure

Branch: `feat/project-structure-authoring`

## Status

**P7A-6.1 = REVIEWED + HARDENED + QUALIFIED.**

Qualified production-code SHA after the second, adversarial technical review:

```text
9b7ae625e3410c210f843a6b07968571c84bc0bd
```

The earlier production SHA `88b39682fd0835569cf6e42f1e94974cb7ec2a4b` passed its CI gates but is **superseded** as P7A-6.1 evidence. The deeper review found race and post-commit correctness gaps that were not exercised by the original matrix.

This document is a docs-only update after qualification and does not alter the qualified production code.

P7A-5 remains the inherited identity baseline; this review does not introduce a new boundary identity model.

## Review method

The second review did not accept the previous `DONE` status as evidence. It re-read the production mutation path and attacked the boundaries where control leaves pure canonical code:

```text
ProjectMutationSession
  -> ProjectCommand.buildCandidate
  -> canonical commit / undo / redo
  -> persistence ownership callback
  -> unified document history
  -> canonical -> legacy/P2 rematerialization
  -> toolbar user feedback
```

The review explicitly exercised:

- re-entrant writers during `buildCandidate()`;
- no-op candidates after a nested canonical writer;
- preview races, not only commit races;
- hidden P3 version gaps beneath P2/legacy history entries;
- persistence-owner ordering during Undo/Redo;
- owner callbacks that re-enter canonical mutation;
- owner failure after an already authoritative commit;
- rematerialization failure after an already authoritative commit;
- convenience/UI paths that previously collapsed post-commit failure into ordinary rejection;
- net diffs of production commits, in addition to CI status.

## Defects found by the deep review

### 1. Re-entrant no-op commit could hide a newer canonical writer

Before the fix, `ProjectMutationSession.commit()` performed its second expected-version check after:

```text
if (stateDiff.isEmpty) return null;
```

A command could therefore enter at version `N`, trigger a nested writer to `N+1` from `buildCandidate()`, then return a no-op candidate based on `N`; the outer call could return `null` instead of reporting that it was stale.

Fix: the post-build expected-version check now runs before the no-op return.

### 2. `preview()` had no post-build optimistic-concurrency check

`ProjectMutationSession.preview()` checked `expectedVersion` before `buildCandidate()` but not after it. A re-entrant writer could advance the canonical project while preview construction was in progress and the caller could receive a candidate for a version that was no longer current.

Fix: preview now performs the same post-build version gate as commit.

Production file:

```text
lib/src/application/project/project_mutation.dart
```

### 3. Hidden canonical version gap could be replayed through a P2/legacy entry

The original unified-history gate validated canonical affinity only when the entry being replayed was itself canonical.

Counterexample:

```text
P3 recorded at v1
out-of-band P3 -> v2
P2 edit recorded above it
Undo
```

Previously the top P2 entry could be undone even though the canonical journal was already stale.

Fix:

- `canUndo/canRedo` now require the attached canonical journal baseline to be current;
- every Undo/Redo checks the canonical version gap before looking at the top entry;
- a hidden P3 gap invalidates the mixed timeline fail-closed rather than replaying through it.

### 4. Canonical Undo/Redo called rematerialization before persistence ownership

A canonical Undo/Redo changes authoritative P3 state first. Previously the order was effectively:

```text
canonical replay
-> rematerialize legacy/P2
-> persistence owner
```

If rematerialization threw, persistence never saw an already committed canonical transition.

Fix:

```text
canonical replay
-> persistence owner
-> re-entrancy/version check
-> rematerialize legacy/P2
-> re-entrancy/version check
```

### 5. Re-entrant persistence owner could leave a false Undo/Redo timeline

The persistence callback is synchronous and may itself invoke canonical code. A nested canonical commit during Undo/Redo could advance the project after the outer replay, while the unified journal still prepared to publish a Redo/Undo entry for the obsolete transition.

Fix: after the owner callback and again after rematerialization, history verifies that the canonical project is still exactly the version produced by the replay. Divergence invalidates the timeline.

Production file:

```text
lib/src/features/editor/editor_document_history.dart
```

### 6. Owner failure after canonical commit could be reported as ordinary rejection

The stable-id runtime returns `bool` for normal pre-commit rejection. Convenience split/merge paths also caught `StateError`.

If the persistence owner threw `StateError` **after** the canonical P3 commit, the convenience path could therefore return `false`, even though topology had already changed.

That is a critical semantic error: `false` means no authoritative mutation; after commit that statement is false.

Fix: post-commit failures are represented by a dedicated:

```text
CanonicalBoundaryPostCommitException
```

with an explicit phase and original cause. It is deliberately not one of the pre-commit exceptions converted to `false`.

### 7. Rematerialization failure after canonical commit could also be reported as rejection

The prior `_commit()` rematerialized in `finally`. A projection failure after persistence ownership could escape as `StateError` and again be swallowed by the convenience wrapper.

Fix: committed processing is now explicit and phase-aware:

```text
canonical commit
-> persistence owner
-> committed-version check
-> unified history registration
-> committed-version check
-> legacy/P2 rematerialization
-> committed-version check
```

Any failure after canonical commit:

- preserves canonical state as authority;
- invalidates unsafe unified history;
- best-effort reprojects where safe;
- throws `CanonicalBoundaryPostCommitException` instead of pretending the operation was rejected.

### 8. UI toolbar still lied after the runtime was hardened

The toolbar previously did:

```text
try action
catch anything
show "operation rejected"
```

So even the new post-commit exception was rendered as “Разделение стены отклонено”.

Fix: toolbar feedback now distinguishes:

```text
pre-commit rejection
    -> operation-specific rejection text

committed + persistence/projection failure
    -> explicit text that the model was already changed,
       persistence/synchronization failed,
       and unsafe history was cleared
```

Production files:

```text
lib/src/features/editor/canonical_boundary_topology_migration_runtime.dart
lib/src/features/editor/unified_icon_toolbar.dart
```

## Adversarial regression pack

Existing P7A-6.1 coverage remains active:

```text
test/p7a6_stale_version_race_test.dart
test/p7a6_reentrant_mutation_race_test.dart
test/p7a6_host_registry_race_test.dart
test/p7a6_adoption_winner_race_test.dart
test/p7a6_production_session_race_test.dart
test/p7a6_history_gap_recovery_test.dart
test/p7a6_history_session_affinity_test.dart
```

The second review added:

```text
test/p7a61_reentrant_noop_preview_test.dart
test/p7a61_deep_history_race_test.dart
test/p7a61_postcommit_projection_failure_test.dart
```

The P7A-5 owner-failure regression was strengthened to require the new explicit post-commit contract:

```text
test/p7a5_ownership_failure_hardening_test.dart
```

New adversarial assertions include:

- re-entrant no-op commit throws stale instead of returning `null`;
- re-entrant preview cannot return a candidate after version advance;
- P2 Undo cannot cross a hidden canonical version gap;
- persistence owner is called even when replay rematerialization fails;
- nested owner mutation cannot manufacture a false Redo entry;
- convenience split cannot translate committed owner failure into `false`;
- convenience split cannot translate committed rematerialization failure into `false`;
- committed failures clear unsafe unified history while leaving the canonical winner authoritative.

## Net production diff review

Compared with the superseded production SHA `88b39682fd0835569cf6e42f1e94974cb7ec2a4b`, the qualified code changes are constrained to:

```text
lib/src/application/project/project_mutation.dart
lib/src/features/editor/editor_document_history.dart
lib/src/features/editor/canonical_boundary_topology_migration_runtime.dart
lib/src/features/editor/unified_icon_toolbar.dart
```

A full-file toolbar edit temporarily introduced unrelated changes during the review. The commit diff inspection caught that mistake before qualification; the toolbar was restored from its exact prior blob and only the intended post-commit feedback change was retained. This is part of the review evidence, not hidden cleanup.

## P7A-6.1 exit gates

```text
Stale buildCandidate path cannot commit/return a false no-op.             PASS
Stale preview cannot escape after canonical version advance.              PASS
Only the canonical winner mutates ProjectMutationSession.current.         PASS
Hidden P3 gaps block P2/legacy Undo/Redo replay.                           PASS
Stale canonical replay does not consume unsafe history.                   PASS
Persistence owner sees already-committed canonical Undo/Redo first.       PASS
Re-entrant owner mutation invalidates obsolete replay chronology.         PASS
Committed owner failure is never represented as ordinary false rejection. PASS
Committed projection failure is never represented as false rejection.     PASS
Toolbar does not tell the user "rejected" after a known committed failure. PASS
Unsafe post-commit divergence clears unified Undo/Redo history.            PASS
```

## Qualification

Exact qualified production SHA:

```text
9b7ae625e3410c210f843a6b07968571c84bc0bd
```

Flutter workflow — run `2758`, run ID `39839583748`:

```text
Dart format gate          PASS
flutter analyze           PASS
flutter full test         PASS
quality job               SUCCESS
verification job          SUCCESS
```

macOS Desktop workflow — run `652`, run ID `39839583765` on the same SHA:

```text
Flutter/macOS setup       PASS
flutter pub get           PASS
Analyze                   PASS
Full test                 PASS
Build macOS debug app     PASS
Runtime path_provider     PASS
job                       SUCCESS
```

## Scope boundary after deep review

This closure is deliberately narrower than the earlier wording.

P7A-6.1 proves stale-version/concurrent-mutation correctness for the covered synchronous production paths. It does **not** claim to close all lifecycle or UI/input concerns.

Explicitly deferred:

- navigation/disposal/session replacement during a committed transition beyond the tested race boundaries -> `P7A-6.3` lifecycle/interruption hardening;
- automatic repair/rematerialization policy when a hidden canonical transition is discovered beneath newer P2 edits -> `P7A-6.3`;
- keyboard/stylus/mobile parity and user-visible failure reporting for every input adapter -> `P7A-6.9`;
- the toolbar currently advertises Alt+A/Alt+S/Alt+M labels, while this review found no separate independent keyboard mutation path to qualify; input parity is therefore not claimed here;
- split-button readiness for geometrically unsplittable integer-lattice diagonals remains an input/UX readiness concern rather than a canonical race-correctness defect -> `P7A-6.9`.

These are not silently counted as PASS under P7A-6.1.

## Result

The original P7A-6.1 closure was too optimistic. The second technical review materially strengthened the mutation core, unified history, persistence-owner boundary, post-commit semantics and user feedback, and added regressions for every defect fixed in this review.

The qualified race-hardening baseline is now `9b7ae625e3410c210f843a6b07968571c84bc0bd`. Further work should proceed to P7A-6.2 only without weakening this baseline; lifecycle/interruption findings remain scheduled for P7A-6.3 and input-parity findings for P7A-6.9.
