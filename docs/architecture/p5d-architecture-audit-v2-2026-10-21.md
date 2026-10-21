# P5D — Hard Architecture Audit v2

Date: 2026-10-21  
Branch: `feat/p5d-opt-in-compass-design`

## Executive verdict

The primary P5D specification has been rewritten after the first audit and re-audited against the current repository contracts.

Result:

```text
product scope                 PASS
canonical/domain semantics    PASS
P3 mutation design            PASS AT SPEC LEVEL
persistence migration design  PASS AT SPEC LEVEL
P5C compatibility             PASS AT SPEC LEVEL
runtime identity affinity     PASS AT SPEC LEVEL
UI/pointer/a11y contract      PASS
sync boundary honesty         PASS
implementation readiness      READY FOR P5D-0 / P5D-A
production closure            NOT READY
```

There are no remaining architecture-specification HIGH blockers that require another redesign before implementation starts.

There are, however, implementation blockers. The existing code still has the old true-north-oriented `ProjectNorth`, root-store-only P3 diff/undo, canonical codec schema v1, always-visible legacy compass wiring, direct `workspace.updateProjectNorth()`, and a legacy sync transport that cannot preserve canonical P5D metadata. P5D must not be marked complete until those are changed and qualified.

---

## 1. Repository facts revalidated

### 1.1 Canonical aggregate has no engineering root metadata yet

Current `ProjectAggregateRoot` contains only:

```text
id
siteId
version
stores
index
```

There is no canonical Project North field today.

This confirms the specification is correct to introduce a dedicated root engineering metadata value rather than overloading Site/Building entities.

### 1.2 P3 still diffs only entity stores

Current P3:

```text
ProjectCommandCandidate -> ProjectEntityStores
ProjectEntityDiff       -> stores before/after
UndoRecord              -> beforeStores / afterStores
```

Therefore a root-metadata-only mutation cannot be implemented safely without the P5D-B mutation extension.

The revised specification resolves the earlier ambiguity by requiring:

```text
ProjectMutableState
  engineeringMetadata
  stores

ProjectChangeSet
  entityDiff
  engineeringMetadataDiff
```

and by forbidding fake EntityIds for root metadata.

Verdict: **resolved in specification; implementation pending**.

---

## 2. Naming collision resolved

The first audited draft used `ProjectRootMetadata`, while `ProjectSnapshot` already contains persistence-envelope metadata such as name/createdAt/updatedAt.

This was too easy to misread as the same metadata layer.

The revised contract uses:

```text
ProjectEngineeringMetadata
```

for canonical engineering-root values, while snapshot envelope metadata remains separate.

Verdict: **PASS**.

---

## 3. Canonical ProjectNorth constructor contract hardened

The first revised design still allowed a subtle implementation trap: one constructor could be reused both for explicit user input and corrupted persisted data.

That would allow malformed persisted values such as `360000` or `-1` to be silently modulo-normalized.

The specification now separates:

```dart
ProjectNorth.fromDegrees(...)
```

for explicit user/import input from:

```dart
ProjectNorth.fromNormalizedMilliDegrees(...)
```

for strict canonical/persisted values.

Required behavior:

```text
user/import 360°  -> normalize to 0°
persisted 360000  -> FormatException / reject
```

This is the correct corruption boundary.

Verdict: **PASS**.

---

## 4. True-north/daylight semantics are now mathematically explicit

The repository's legacy `ProjectNorth` is not just badly named; `DaylightAssistEngine` depends on its sign convention through `toTrueAzimuth()`.

The revised P5D specification now locks the compatibility equation:

```text
trueAzimuth = normalize(
  planAzimuth - trueNorthClockwiseFromProjectPositiveY
)
```

This prevents a future rename from accidentally flipping east/west behavior.

The implementation may choose another internal representation only if the adapter preserves this observable behavior and tests prove it.

Verdict: **PASS AT SPEC LEVEL**.

Implementation blocker:

```text
legacy ProjectNorth type still exists
DaylightAssistEngine still consumes it directly
```

---

## 5. Metadata diff is no longer under-specified

A boolean such as:

```text
projectNorthChanged = true
```

is insufficient for diagnostics, incremental publication, tests and future metadata growth.

The revised design requires before/after values:

```text
beforeProjectNorth
afterProjectNorth
```

and explicitly states that `affectedEntityIds` remains entity-only.

This avoids inventing a fake entity identity for root invalidation.

Verdict: **PASS**.

---

## 6. Undo/Redo contract is now structurally correct

The revised specification requires:

```text
UndoRecord.beforeState
UndoRecord.afterState
```

where each state contains both:

```text
engineeringMetadata
stores
```

It also hardens an existing P3 weakness by stating that an impossible empty undo/redo transition is invariant corruption rather than a successful no-op.

Verdict: **PASS AT SPEC LEVEL**.

Implementation blocker: current `UndoRecord` still stores stores only.

---

## 7. Canonical schema migration is properly versioned

Current `CanonicalProjectDocumentCodec` is strict schema v1 and has no Project North.

The hardened P5D design correctly requires:

```text
v1 -> migrate -> v2
```

with:

```text
v1 missing orientation -> unspecified
v2 null                -> unspecified
v2 [0..359999]         -> exact orientation
invalid raw v2 value   -> reject
```

The migration is required as an explicit step instead of scattered version branches through entity decoding.

Verdict: **PASS**.

Implementation blocker: codec is still schema v1.

---

## 8. Legacy provenance handling remains fail-closed

Current transitional `ProjectSite` defaults orientation to `0°`, and legacy `EditorProjectDocument` persists `projectNorthDegrees` without confirmation provenance.

The revised specification now correctly states that **all** old numeric values, including non-zero values, remain unconfirmed unless explicit provenance exists.

This is stricter and safer than treating only legacy `0°` as suspicious.

Verdict: **PASS**.

---

## 9. P5C runtime affinity is now explicitly part of P5D

Project North is root-scoped, so stale runtime state is dangerous.

The revised P5D design now requires exact affinity among:

```text
screen/document project identity
canonical session ProjectId
persistence/ownership project identity
```

and requires re-resolution after open/recovery/project replacement.

This is important because P5C already rebuilds the canonical runtime when the legacy workspace is replaced. P5D must attach to that lifecycle instead of caching an independent orientation editor.

Verdict: **PASS AT SPEC LEVEL**.

---

## 10. Production edit boundary is now narrow enough

The widget must not know how to construct raw P3 mutation requests or manipulate stores.

The revised specification introduces an application-facing `ProjectNorthEditingPort` concept:

```text
widget
-> ProjectNorthEditingPort
-> P3 command/session
-> host ownership transfer
```

This is preferable to:

```text
widget
-> ProjectMutationSession directly
```

because it keeps persistence ownership, identity affinity and error semantics outside presentation code.

Verdict: **PASS**.

The exact interface may differ during implementation, but the dependency direction is now fixed.

---

## 11. Ownership receipt is no longer confused with durable save

Current P5C runtime explicitly documents that `CanonicalAuthoringOwnershipReceipt` is a synchronous ownership-transfer acknowledgment, not durable storage completion.

The second audit found that P5D originally risked wording the post-command flow as though repository save were atomically complete.

The revised specification now states:

```text
commit accepted by host != durable disk/backend save completed
```

If durable save later fails:

```text
canonical state remains committed/modified
legacy state is not used as rollback
failure must be surfaced
```

Verdict: **PASS**.

Inherited architecture risk remains: P3 publication itself is synchronous and assumes non-throwing publishers. P5D must not worsen or hide that pre-existing constraint.

---

## 12. Legacy sync transport cannot preserve canonical P5D state

Current `ProjectSyncGateway` carries `EditorProjectDocument` rather than canonical `ProjectSnapshot`/canonical codec documents.

Therefore a production claim such as:

```text
Project North syncs across devices
```

would currently be false.

The revised P5D specification now explicitly states:

- legacy sync may continue for legacy editor state;
- it must not be advertised as preserving canonical Project North;
- remote canonical sync is outside P5D only if the product does not promise it;
- if remote preservation is promised, sync transport must be upgraded before that claim is enabled.

Verdict: **PASS / scope correctly bounded**.

This is not a reason to pull the whole backend-sync redesign into P5D.

---

## 13. Viewport rotation remains correctly excluded

`WorldCamera` still has no rotation state.

The cardinal projection remains:

```text
0°   -> up
90°  -> right
180° -> down
270° -> left
```

No architectural justification exists for introducing camera rotation merely to support the compass.

Verdict: **PASS**.

---

## 14. Existing legacy compass is still an implementation blocker

The repository currently renders `ProjectCompassOverlay` automatically in plan context and feeds it `workspace.site.site.projectNorth`.

The edit path still calls:

```text
workspace.updateProjectNorth(...)
```

This remains incompatible with canonical P5D production mode.

The revised spec correctly requires:

```text
canonical engineering metadata
-> projection state
-> widget
```

and:

```text
widget
-> application edit port
-> P3
```

Verdict: **spec resolved / code unresolved**.

---

## 15. Shell-state ownership remains correct

`EditorShellState` is still the proper place for requested compass visibility.

The special P5D focus-mode rule is intentionally different from existing panel toggles:

```text
while focus mode active
-> requested compass visibility may change
-> effective visibility remains false
-> exit focus mode reflects requested state
```

This is coherent and testable.

Verdict: **PASS**.

---

## 16. Remaining risks classified

### HIGH — none at specification level

No unresolved HIGH design contradiction remains in the rewritten P5D specification.

### HIGH — implementation blockers

```text
H1 old ProjectNorth semantics not yet split/migrated
H2 ProjectAggregateRoot has no engineering metadata yet
H3 P3 candidate/diff/undo remain store-only
H4 canonical codec remains schema v1
H5 production screen still has always-visible legacy compass path
H6 canonical production edit port does not exist
H7 direct workspace.updateProjectNorth() still exists
```

These are expected implementation work, not reasons for another TЗ redesign.

### MEDIUM — implementation/qualification risks

```text
M1 exact Dart rounding edge cases must be locked by tests
M2 publisher failure semantics remain inherited P3 debt
M3 screen/runtime/persistence identity affinity must be enforced, not documented only
M4 unsupported/blocked canvas mode must suppress compass consistently
M5 legacy sync UI must not imply canonical ProjectNorth sync
M6 accessibility focus/checked-state behavior needs widget qualification
M7 overlay hit testing must prove pointer passthrough outside target
```

### LOW / deferred

```text
L1 user preference persistence for compass visibility
L2 viewport rotation feature
L3 device magnetometer
L4 GPS / georeferencing
L5 magnetic declination
L6 per-building coordinate transforms
L7 remote canonical sync transport
```

---

## 17. Hardened implementation order after audit v2

The final order is:

```text
P5D-0
  split semantic types
  lock daylight compatibility
  lock provenance/affinity/ownership contracts

P5D-A
  ProjectNorth strict + input constructors
  ProjectEngineeringMetadata
  aggregate integration

P5D-B
  ProjectMutableState
  engineering metadata diff
  P3 commit/undo/redo extension
  Set/Clear commands

P5D-C
  canonical codec v2
  v1->v2 migrator
  semantic fingerprint
  repository round-trip

P5D-D
  shell requested/effective visibility

P5D-E
  projection states
  compass widget migration

P5D-F
  application edit port
  production runtime identity affinity
  UnifiedWorkspaceEditorScreen cutover

P5D-G
  complete qualification matrix
  P5C regressions
  Flutter + macOS CI
```

No P5D-F screen wiring should land before P5D-A/B/C have proven canonical mutation and persistence contracts.

---

## 18. Final audit verdict

The rewritten P5D TЗ is now architecturally coherent enough to implement.

```text
P5D TЗ HARD AUDIT V2 = PASS

Specification redesign required before coding: NO
Implementation work required:             YES
Ready to start P5D-0/P5D-A:               YES
Ready to mark P5D complete:                NO
Ready to merge production P5D runtime:     NO
```

The next legitimate action is implementation of P5D-0/P5D-A, followed immediately by P5D-B mutation-engine extension before any canonical production compass editing is wired into `UnifiedWorkspaceEditorScreen`.
