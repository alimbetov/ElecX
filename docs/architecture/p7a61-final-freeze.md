# P7A-6.1 Final Freeze — Owner / Session-Switch Boundary

Branch: `feat/project-structure-authoring`

## Status

**P7A-6.1 = FROZEN + HARDENED + QUALIFIED.**

Final qualified production SHA:

```text
f6f19983c6dc7ee3f0dc1e945a4d2f3c1187fe44
```

This document is added after qualification and does not change the qualified production code.

## Why the previous deep-review SHA was not frozen

The earlier deep-review SHA `9b7ae625e3410c210f843a6b07968571c84bc0bd` closed stale-version, re-entrant owner and post-commit failure gaps, but the final adversarial owner/session-switch audit found one remaining correctness class:

```text
canonical commit in session A
        |
        v
persistence owner callback
        |
        +---- synchronously attaches session B
              with the same LocalProjectVersion
        |
        v
version-only post-commit guard
```

A version-only check could not distinguish session A from session B. The old `recordCanonicalCommit()` mismatch branch could then silently clear history and reattach the journal to session A, dropping the replay owner of session B. A subsequent best-effort rematerialization could also project stale session-A state after session B had become the active canonical owner.

## Final production hardening

### 1. Canonical history no longer silently rebinds on commit recording

`EditorDocumentHistory.recordCanonicalCommit(...)` now requires exact session affinity. If the attached canonical session changed, it fails instead of taking ownership of the supplied session.

The history API also exposes an explicit identity check used by production post-commit processing:

```text
hasCanonicalSessionAffinity(session)
```

### 2. Canonical Undo/Redo replay validates session identity after owner callbacks

Replay correctness is now:

```text
exact attached session
+ expected observed version
+ replay mutation
+ persistence owner
+ exact attached session still unchanged
+ exact produced version still current
+ rematerialize
+ exact attached session/version still current
```

A synchronous owner-driven session switch invalidates the obsolete replay chronology and cannot manufacture a Redo entry.

### 3. Boundary post-commit processing validates state, not only version

`CanonicalBoundaryTopologyMigrationRuntime` now checks:

```text
session identity + committed version
```

after each external post-commit boundary.

A session switch is represented as `CanonicalBoundaryPostCommitException` and is never collapsed into ordinary `false` rejection.

### 4. Old-session rematerialization is blocked

Best-effort rematerialization now runs only while the original session remains the attached canonical session. `_materialize(...)` itself also requires exact canonical session affinity.

Therefore:

```text
session B becomes active
        ↓
old session A MUST NOT repaint legacy/P2 state
```

## Regression evidence

New final-adversarial regression:

```text
test/p7a61_session_switch_boundary_test.dart
```

The test pack proves at minimum:

1. owner callback can attach a different canonical session at the same numeric version and the old transition is detected as divergent;
2. history is not rebound back to the old session;
3. old-session rematerialization is not allowed after the switch;
4. canonical Undo with owner-driven session replacement does not create a false Redo entry;
5. the newly attached session remains the journal owner after failure handling.

## Net diff for the final audit

Relative to the pre-final-audit branch baseline `41a811032cb623bf0b0243e113a9b1977fd065ca`, the final P7A-6.1 production/test delta is restricted to:

```text
lib/src/features/editor/editor_document_history.dart
lib/src/features/editor/canonical_boundary_topology_migration_runtime.dart
test/p7a61_session_switch_boundary_test.dart
```

No Wizard, P7B, P7C or P8 production code is part of this freeze.

## Final exit gate

```text
Stale version cannot overwrite canonical winner.                         PASS
Re-entrant no-op/preview cannot hide version advance.                    PASS
Hidden canonical gap blocks mixed P2/P3 replay.                         PASS
Persistence owner executes before post-commit projection.               PASS
Re-entrant owner mutation invalidates obsolete history.                  PASS
Owner failure after commit is never reported as ordinary rejection.      PASS
Projection failure after commit is never reported as ordinary rejection. PASS
Same-version canonical session replacement is detected.                 PASS
History cannot silently rebind to an obsolete session.                   PASS
Old-session rematerialization after session switch is blocked.           PASS
Session-switch during canonical replay cannot create false Redo/Undo.    PASS
```

## Qualification

Exact production SHA:

```text
f6f19983c6dc7ee3f0dc1e945a4d2f3c1187fe44
```

Flutter workflow — run `2776`, run ID `39846171183`:

```text
Dart format gate          PASS
flutter analyze           PASS
flutter full test         PASS
quality job               SUCCESS
verification job          SUCCESS
```

macOS Desktop workflow — run `661`, run ID `39846171286` on the same SHA:

```text
Flutter/macOS setup       PASS
flutter pub get           PASS
Analyze                   PASS
Full test                 PASS
Build macOS debug app     PASS
Runtime path_provider     PASS
job                       SUCCESS
```

## Freeze rule

`P7A-6.1` is now frozen. Later slices may add tests that exercise this boundary, but production changes to these race/session invariants require a demonstrated regression and must not be folded casually into unrelated P7A-6 work.

Next implementation slice:

```text
P7A-6.2 — hosted-object remap ambiguity matrix
```
