# P7A-6.1 Stale-Version / Concurrent Mutation Races — Closure

Branch: `feat/project-structure-authoring`

## Status

**P7A-6.1 = DONE + HARDENED + QUALIFIED.**

Qualified production-code SHA:

```text
88b39682fd0835569cf6e42f1e94974cb7ec2a4b
```

This document is added after qualification and does not change the qualified production code.

P7A-5 remains frozen and qualified on:

```text
0da97676b11baeaa5dfe92c5357185df058f9a08
```

## Qualified race contract

P7A-6.1 proves that stale editor/session state cannot overwrite a newer canonical project.

The production contract is:

```text
begin at version N
        |
        v
preview / candidate
        |
        +---- another canonical writer commits N -> N+1
        |
        v
expected-version / session-affinity gate
        |
        +---- stale => fail closed, winner remains authoritative
        |
        v
commit only when current version still matches
```

No stale failure is allowed to manufacture a second authoritative legacy/P2 state.

## Adversarial scenarios closed

The P7A-6.1 qualification matrix covers:

1. split begun at version `N`, followed by an unrelated canonical mutation to `N+1`; the stale split cannot commit;
2. merge begun at `N`, followed by a real hosted-registry adoption at `N+1`; the stale merge cannot overwrite the adopted registry;
3. two topology sessions begun at the same version; only the first commit wins;
4. a retired `BoundaryEdgeId` after split cannot be reused through the production stable-id split path;
5. transient wall ordinal resolution is rebuilt from the current canonical topology after identity change and never remains authoritative;
6. stale canonical Undo and Redo calls cannot consume history stacks or mutate a newer project version;
7. an out-of-band canonical version gap invalidates unsafe unified history;
8. version-gap history recovery rematerializes the current canonical winner into the legacy/P2 projection before the unsafe timeline is discarded;
9. replacing the attached canonical session invalidates history belonging to the previous project/session;
10. stale host adoption cannot overwrite an already-adopted canonical host registry;
11. re-entrant mutation during `ProjectCommand.buildCandidate()` is rejected by the second expected-version check in `ProjectMutationSession.commit()`;
12. the existing P7A-5 owner-acknowledgement failure regression remains active: an in-memory canonical commit whose persistence owner throws is not exposed as a safe Undo entry.

## Production defects found and fixed

### 1. Canonical history version-gap projection recovery

Before hardening, `EditorDocumentHistory.undo()/redo()` correctly rejected a canonical version gap and cleared the unified timeline, but it could leave the legacy editor materialized from an older canonical state.

That violated the invariant:

```text
canonical project = authority
legacy/P2 editor = reconstructable projection
```

The failure path now attempts canonical rematerialization for the still-attached canonical entry before clearing the unsafe timeline and refreshing baselines.

The recovery does **not** execute a second Undo/Redo operation. If rematerialization itself fails, the history is still invalidated fail-closed.

Production fix:

```text
lib/src/features/editor/editor_document_history.dart
```

### 2. Retired edge accepted too far into production split path

After a successful split, the source `BoundaryEdgeId` is retired. A direct production call using that old ID previously reached `previewSplitEdge()` and surfaced `BoundaryTopologyMigrationException(edgeNotFound)`.

The stable production gateway now rejects an inactive/retired edge before preview:

```text
current project index
   -> boundaryEdge(edgeId)
   -> null => false / no mutation
   -> active => begin canonical migration
```

This keeps the bool-returning production split contract fail-closed while preserving an important P7A-5 invariant: persistence-owner exceptions **after** an authoritative P3 commit are still propagated and are not disguised as a rejected edit.

Production fix:

```text
lib/src/features/editor/canonical_boundary_topology_migration_runtime.dart
```

## Regression pack

New P7A-6.1 tests:

```text
test/p7a6_stale_version_race_test.dart
test/p7a6_reentrant_mutation_race_test.dart
test/p7a6_host_registry_race_test.dart
test/p7a6_adoption_winner_race_test.dart
test/p7a6_production_session_race_test.dart
test/p7a6_history_gap_recovery_test.dart
test/p7a6_history_session_affinity_test.dart
```

Existing regression retained as part of this gate:

```text
test/p7a5_ownership_failure_hardening_test.dart
```

## Exit-gate result

```text
No stale path mutates ProjectMutationSession.current.               PASS
No stale path overwrites the canonical winner.                      PASS
No failed stale path increments canonical version.                  PASS
No failed stale path consumes/increments unsafe history depth.       PASS
Fresh wall projection replaces retired ordinal/edge assumptions.     PASS
Canonical session replacement invalidates foreign history.           PASS
Version-gap recovery reprojects current canonical state.              PASS
Owner-ack failure still invalidates unsafe canonical history.         PASS
```

## Qualification

Exact production SHA:

```text
88b39682fd0835569cf6e42f1e94974cb7ec2a4b
```

Flutter workflow — run `2718`, run ID `39832068617`:

```text
Dart format gate          PASS
flutter analyze           PASS
flutter full test         PASS
quality job               SUCCESS
verification job          SUCCESS
```

macOS Desktop workflow — run `632`, run ID `39832068202` on the same SHA:

```text
Flutter/macOS setup       PASS
flutter pub get           PASS
Analyze                   PASS
Test                      PASS
Build macOS debug app     PASS
Runtime path_provider     PASS
job                       SUCCESS
```

## Next slice

P7A-6.1 is frozen as qualified. The next implementation target is:

**P7A-6.2 — hosted-object remap ambiguity matrix.**

P7A-6.2 should attack split/merge/create/remove lineage across opening/component/cable-endpoint/route-anchor hosts, point/interval geometry, forward/reverse traversal, exact-split ambiguity, shaped profiles and unrelated-space isolation. It must not introduce a new boundary identity model.
