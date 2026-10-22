# P7A-2 Technical Review — 2026-10-22

Branch: `feat/project-structure-authoring`

## Scope

This review covers the P7A-2 canonical aggregate ownership slice only:

- `ProjectEntityStores.boundaries` ownership;
- aggregate validation;
- `ProjectIndex` boundary indexes;
- mutation diff semantics;
- undo/redo state capture;
- destructive structural commands;
- compatibility with P4/P6 commands;
- native-platform neutrality.

P7A-3 persistence/migration, P7A-4 production editor cutover and P7A-5 hosted-object migration are outside this review except where P7A-2 contracts must make them safe.

## Disposition

**P7A-2H1 and P7A-2H2 are closed.**

The review found one concrete destructive-operation defect and one historical identity invariant. Both are now enforced in the canonical mutation path. The final Flutter quality/verification run on HEAD `9119cdd2f57c1de510fc37d70baf3bc618cc0743` passes formatting, analyze and tests. macOS Desktop qualification for the same HEAD remains an independent current-run gate and does not alter the H1/H2 result.

## Findings

### HIGH — RemoveSpace could orphan owned boundary topology — FIXED

Before hardening, legacy stores-only command compatibility intentionally preserved `current.stores.boundaries`. That was correct for ordinary P3/P4 mutations but incorrect for `RemoveSpaceCommand`.

The corrected removal contract is:

```text
RemoveSpaceCommand
  -> remove SpaceId
  -> remove structural back-references
  -> remove boundaries[SpaceId]
  -> remove owned BoundaryEdgeId values in the same canonical mutation
  -> validate candidate
  -> one commit / one undo record
```

Openings, adjacency, overlays and future hosted engineering objects remain dependency blockers. Owned boundary topology itself cascades with its space.

Regression qualification verifies that removal clears the space, topology and stable edge identities and that Undo restores all of them atomically.

### HIGH — BoundaryEdgeId must never change owning SpaceId — FIXED (H1)

A single aggregate snapshot already rejects duplicate `BoundaryEdgeId` ownership across two spaces. P7A-2 now additionally enforces historical ownership inside `ProjectMutationSession`.

The invariant is stronger than adjacent-version comparison:

```text
BoundaryEdgeId E first observed at Space A
        |
        +-- geometry/order edit at Space A    ALLOWED
        +-- remove E                           ALLOWED
        +-- undo/redo at Space A              ALLOWED
        +-- later reuse E at Space A           ALLOWED by identity ownership
        `-- later reuse E at Space B           REJECTED
```

`ProjectMutationSession` records the first canonical owner of every observed `BoundaryEdgeId` and never reassigns that owner. Preview, commit, Undo and Redo restoration validate candidate stores against the historical owner map before authoritative state replacement.

A cross-space reassignment throws `BoundaryEdgeOwnershipException` before `_current`, `LocalProjectVersion` or Undo history can be mutated.

Split/merge/reconstruction that produces a different logical edge must therefore allocate new identities and describe the relationship through `BoundaryTopologyChangeSet` lineage.

#### Persistence hand-off to P7A-3

The P7A-2 owner history is intentionally mutation-session state. P7A-3 must make retired-edge ownership durable across save/reopen so a process restart cannot weaken the same invariant.

P7A-3 therefore has an explicit requirement:

```text
save
 -> persist active boundary topology
 -> persist/reconstruct retired BoundaryEdgeId ownership tombstones
reopen
 -> seed ProjectMutationSession ownership history
 -> forbid reuse of retired ID under another SpaceId
```

The persistence representation may evolve, but the semantic invariant may not.

### MEDIUM — compatibility preservation must remain explicit for newer canonical stores — VERIFIED

Stores-only P3/P4 commands preserve P6 semantic stores and P7A boundaries through `ProjectCommandCandidate.resolveState()`.

P6 semantic commands rebuild `ProjectEntityStores` through `fromState`; they explicitly carry `boundaries` forward.

This avoids a regression where changing `SpaceUsage`, adjacency or overlay data silently erases topology.

### MEDIUM — boundary diff semantics are suitable for downstream invalidation — VERIFIED

Current canonical diff behavior is appropriate:

- boundary added to an existing Space -> owner `SpaceId` updated + edge IDs added;
- boundary removed from an existing Space -> owner `SpaceId` updated + edge IDs removed;
- edge geometry changes -> stable `BoundaryEdgeId` updated;
- edge order/topology changes -> owner `SpaceId` updated;
- simultaneous Space + boundary creation/removal keeps added/updated/removed sets disjoint.

### MEDIUM — failed candidate and Undo/Redo atomicity — VERIFIED

Boundary topology is inside `ProjectMutableState.stores`, therefore candidate validation occurs before `_current` replacement and Undo/Redo captures topology with the same canonical state boundary.

An invalid topology or historical ownership candidate leaves:

- current aggregate unchanged;
- local version unchanged;
- undo depth unchanged.

### LOW — formatter qualification debt — CLOSED (H2)

Final Flutter quality run on HEAD `9119cdd2f57c1de510fc37d70baf3bc618cc0743` passes:

```text
dart format --output=none --set-exit-if-changed lib test  PASS
flutter analyze                                             PASS
flutter test                                                PASS
```

No formatter diff artifact is produced because the formatting check is clean.

## Platform architecture review

No P7A-2 canonical code introduces platform-specific semantics.

The same aggregate ownership contract applies on:

```text
macOS
Windows
Linux
Android
iOS
iPadOS
```

Input modality, filesystem access, lifecycle and adaptive presentation remain outside the boundary model.

No platform stub or separate mobile/desktop topology model is required or allowed.

## P7A-2 hardening result

```text
P7A-2H1 BoundaryEdgeId historical SpaceId ownership  DONE
P7A-2H2 Dart format gate on final HEAD               PASS
Flutter analyze                                      PASS
Flutter test                                         PASS
macOS Desktop final-head qualification               RUNNING
```

Windows/Linux/Android/iOS/iPadOS runners remain non-blocking for P7A-2 architecture closure under the native-platform portability contract.

## Recommendation

Proceed next to P7A-3 persistence / deterministic legacy migration after the current macOS final-head qualification completes. P7A-3 must persist or deterministically reconstruct retired-edge ownership tombstones so H1 survives save/reopen and application restart.
