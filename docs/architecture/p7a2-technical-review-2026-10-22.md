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

**P7A-2 architecture is sound after hardening, but qualification is not yet closed.**

The review found one concrete correctness defect that is now fixed and one transition invariant that must be enforced before public topology mutation is introduced.

## Findings

### HIGH — RemoveSpace could orphan owned boundary topology — FIXED

Before hardening, legacy stores-only command compatibility intentionally preserved `current.stores.boundaries`. That was correct for ordinary P3/P4 mutations but incorrect for `RemoveSpaceCommand`.

The old sequence was effectively:

```text
remove SpaceId from spaces
        |
compatibility resolver preserves boundaries
        |
BoundaryTopology still references removed SpaceId
        |
aggregate validation rejects candidate
```

This meant a valid room with canonical P7A topology could no longer be removed even after all independent P6 semantic dependencies were cleared.

Boundary topology is owned state of the space itself. It is not an independent semantic dependency.

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

Regression qualification now verifies that removal clears the space, topology and stable edge identities and that Undo restores all of them atomically.

### HIGH — BoundaryEdgeId must not change owning SpaceId across a mutation — CONTRACT REQUIRED

A single aggregate snapshot already rejects duplicate `BoundaryEdgeId` ownership across two spaces. That is necessary but not sufficient for historical identity stability.

A candidate could theoretically contain:

```text
before: BoundaryEdgeId E -> Space A
after:  BoundaryEdgeId E -> Space B
```

where each individual snapshot is internally valid.

This is forbidden. A stable boundary identity represents one logical boundary lineage and must never be re-parented to another `SpaceId`.

Required transition invariant:

```text
if BoundaryEdgeId E exists before and after a mutation:
    before.ownerSpaceId MUST equal after.ownerSpaceId
```

If geometry changes ownership because of split/merge/reconstruction, the operation must allocate new edge identities and describe the relationship through `BoundaryTopologyChangeSet` lineage.

This invariant must be enforced before any production/public topology mutation command is exposed. It is an application/domain transition rule, not a UI rule and not a platform rule.

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

This is sufficient for later cache/projection invalidation and production editor refresh without using `wallIndex`.

### MEDIUM — failed candidate and Undo/Redo atomicity — VERIFIED

Boundary topology is inside `ProjectMutableState.stores`, therefore candidate validation occurs before `_current` replacement and Undo/Redo captures topology with the same canonical state boundary.

An invalid topology candidate leaves:

- current aggregate unchanged;
- local version unchanged;
- undo depth unchanged.

### LOW — formatter qualification debt — OPEN

The first P7A-2 Flutter workflow showed:

```text
flutter analyze PASS
flutter test    PASS
macOS Desktop  PASS
formatter gate FAIL
```

The formatter identified P7A files only. This is not a runtime correctness failure, but P7A-2 must not be called qualified until `dart format --output=none --set-exit-if-changed lib test` is green on the final HEAD.

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

## Required closure conditions for P7A-2

P7A-2 may be marked `DONE + HARDENED` when all of the following are true:

1. owned boundary removal regression remains green;
2. stable `BoundaryEdgeId` cross-space re-parenting is rejected at mutation-transition validation before public topology edit commands land;
3. formatter gate is green;
4. `flutter analyze` is green;
5. `flutter test` is green;
6. current macOS Desktop qualification is green;
7. no platform-specific engineering state is introduced.

Windows/Linux/Android/iOS/iPadOS runners remain non-blocking for P7A-2 architecture closure under the native-platform portability contract.

## Recommendation

Do not proceed directly to production editor cutover yet.

The safe order remains:

```text
P7A-2 review hardening
  -> close formatter + transition invariant
  -> P7A-3 persistence / deterministic legacy migration
  -> P7A-4 production editor cutover
  -> P7A-5 hosted-object migration
  -> P7A-6 qualification
```
