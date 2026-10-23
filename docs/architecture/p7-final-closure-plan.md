# P7 Final Closure Plan

Branch: `feat/project-structure-authoring-p7-closure`
Base: `feat/project-structure-authoring`

## Status

**P7 closure work = ACTIVE.**

Target terminal state:

```text
P7 = FROZEN + HARDENED + QUALIFIED
```

This document is the executable closure contract for the final P7 work. It does not reopen the already-qualified P7A horizontal boundary/identity model. The closing scope is the remaining vertical physical topology, atomic cross-level authoring, persistence, destructive-operation safety and exact-SHA qualification.

---

## 1. Closure objective

P7 is closed only when the production editor can create, persist, reopen, undo/redo and safely reject invalid multi-level physical routing without bypassing canonical slab/core topology.

Canonical cross-level routing must resolve to:

```text
source Level
  -> source horizontal route
  -> SlabId
  -> SlabPenetrationId
  -> VerticalCoreId / canonical vertical transition
  -> hidden vertical route leg
  -> target Level
  -> target horizontal route
```

A direct durable `LevelId -> LevelId` route transition without physical topology evidence is forbidden.

---

## 2. Frozen scope / non-goals

The following P7A contracts are considered frozen and MUST NOT be redesigned without a reproduced regression and a dedicated regression test:

- `BoundaryEdgeId` identity;
- boundary lineage;
- hosted-object ownership;
- wall-profile ownership;
- split/merge semantics;
- canonical session affinity;
- persistence-owner ordering;
- canonical history ownership;
- session-switch/re-entrant owner hardening.

This closing branch must not introduce:

- another boundary identity model;
- another project mutation/history model;
- UI-specific engineering mutation paths;
- temporary direct level-to-level routing shortcuts;
- index-derived durable physical identities.

---

## 3. Mandatory closure sequence

The implementation order is fixed:

```text
P7-C1  formatter / current CI
   -> P7-C2  VerticalCore dependency guards
   -> P7-C3  atomic cross-level continuation
   -> P7-C4  stale-version exact rollback
   -> P7-C5  schema-v9 Save/Reopen
   -> P7-C6  3-level E2E + reverse routing
   -> P7-C7  destructive-operation adversarial qualification
   -> P7-C8  slab-bypass audit
   -> P7-C9  exact-SHA Flutter + macOS qualification
   -> P7-C10 P7 FREEZE
```

A stage may be implemented in parallel locally, but it cannot be marked closed before all earlier stage exit gates are satisfied.

---

# P7-C1 — Formatter / current CI baseline

## Requirement

Restore a clean baseline before vertical production changes.

Mandatory gates:

```text
dart format --output=none --set-exit-if-changed .   PASS
flutter analyze                                      PASS
flutter test                                         PASS
```

CI changes that weaken or bypass these gates are forbidden.

## Exit evidence

Record:

- exact commit SHA;
- Flutter workflow run ID;
- failing/green job names;
- formatter/analyze/test results.

---

# P7-C2 — VerticalCore and structural dependency guards

## Requirement

Structural mutations must fail closed when vertical physical topology depends on the target object.

The dependency graph includes at minimum:

```text
BuildingId
  -> LevelId
      -> SlabId
          -> SlabPenetrationId
      -> VerticalCoreId membership
      -> cross-level route transition
      -> hidden vertical route leg
      -> engineering evidence
```

## RemoveLevel

`RemoveLevel` MUST reject when any active dependency exists unless an explicit typed cascade command is introduced.

The rejection must identify:

- target `LevelId`;
- blocking dependency kind;
- blocking identity;
- reason.

Implicit cascade deletion is forbidden.

## RemoveBuilding

Removal must reject when the building still owns levels, slabs, penetrations, vertical cores or cross-level route topology, unless a separately specified aggregate-cascade command is used.

## VerticalCore invariants

A core must prove:

- all referenced levels exist;
- all referenced levels belong to the same building;
- no duplicate level references exist;
- level ordering is deterministic;
- the modeled physical coverage is valid.

If a core represents a continuous riser, a physical gap such as `L1 -> L3` while `L2` lies between them is invalid unless explicit bypass semantics exist in the model.

## Required tests

At minimum:

```text
remove referenced level                     -> reject
remove referenced building                  -> reject
foreign-building core level                 -> reject
duplicate core level                        -> reject
non-contiguous continuous core              -> reject
valid contiguous core                       -> accept
```

## Exit gate

After every structural mutation:

```text
0 dangling LevelId
0 dangling SlabId
0 dangling SlabPenetrationId
0 dangling VerticalCoreId
0 dangling route transition references
```

---

# P7-C3 — Atomic cross-level continuation

## Requirement

One user cross-level continuation must be one logical canonical transaction.

Forbidden partial state:

```text
penetration committed, vertical leg missing
vertical leg committed, target continuation missing
route identity updated, engineering evidence missing
slab handoff persisted after downstream failure
```

## Required transaction pipeline

```text
intent
 -> resolve source topology
 -> resolve target topology
 -> build full continuation candidate
 -> preflight all dependencies
 -> validate geometry
 -> validate expected version/session
 -> single canonical commit
 -> persistence ownership
 -> history registration
 -> projection/materialization
```

All failure-prone candidate construction must occur before canonical mutation where feasible.

## Single logical delta

The operation must produce one logical project change containing the required:

- slab/penetration delta;
- vertical topology delta;
- route topology delta;
- engineering evidence delta;
- history/owner metadata.

## Failure semantics

Before canonical commit:

```text
failure -> no canonical state change
```

After canonical commit but before persistence-owner acknowledgement:

- canonical winner remains authoritative;
- operation is not reported as an ordinary rejection;
- history fails closed if durability cannot be proven;
- rematerialization must only use the surviving canonical session.

## Required regression tests

Inject failure at least at:

```text
before penetration candidate
before vertical-leg candidate
before canonical commit
stale version at commit boundary
persistence-owner callback
post-commit projection/materialization
```

For every pre-commit failure, assert exact state equality for:

- route identity;
- route anchors;
- penetration registry;
- vertical core/leg state;
- project version;
- canonical history state.

---

# P7-C4 — Stale-version exact rollback

## Requirement

Optimistic concurrency must preserve the canonical winner and restore exact editor/draft identity.

Qualification scenario:

```text
Session A reads V10
Session B commits V11
Session A attempts vertical continuation from V10
=> Session A is rejected as stale
=> V11 remains canonical
```

The rejected operation must not recreate route state approximately.

Must remain unchanged/restored exactly:

- route ID;
- route-anchor IDs;
- segment locks;
- mandatory waypoints;
- engineering payload;
- source/target level intent;
- active draft state where applicable.

Forbidden recovery mechanisms:

- rebuilding old route identity from coordinates;
- allocating replacement anchor IDs;
- inferring old topology from indices.

## Required tests

```text
stale continuation cannot commit
winning project is unchanged
route IDs unchanged
anchor IDs unchanged
no orphan penetration
no orphan vertical leg
fresh-version retry succeeds deterministically
```

---

# P7-C5 — Schema-v9 Save/Reopen qualification

## Requirement

Schema v9 must durably preserve all canonical vertical physical identity and topology needed to reopen the exact same project state.

Persist at minimum:

- `SlabId` and ownership;
- source/target level affinity;
- `SlabPenetrationId` and geometry/host affinity;
- `VerticalCoreId`, building affinity and ordered level membership;
- canonical cross-level route transitions;
- hidden vertical route legs or equivalent canonical evidence;
- route engineering evidence;
- stable route-anchor identity.

## Save validation

Saving must fail closed for:

```text
unknown LevelId
unknown SlabId
unknown SlabPenetrationId
unknown VerticalCoreId
penetration without slab
vertical transition without physical host evidence
cross-building core references
retired/dangling route physical references
```

## Reopen invariant

For all canonical physical entities:

```text
identity before save == identity after reopen
```

Durable identity must never be reconstructed from array position, level ordinal, route segment ordinal or UI order.

## Corruption fixtures

Required schema-v9 corrupt reopen cases:

```text
missing slab
missing penetration
missing core
foreign level in core
duplicate core level
route transition without host
vertical leg with missing endpoint
```

All must fail closed; partial project load is forbidden.

---

# P7-C6 — Three-level E2E and reverse routing

## Requirement

Qualify a real three-level topology in both traversal directions.

Forward:

```text
L1 -> Slab12 -> Penetration12 -> Core -> L2
   -> Slab23 -> Penetration23 -> Core -> L3
```

Reverse:

```text
L3 -> Slab23 -> Penetration23 -> Core -> L2
   -> Slab12 -> Penetration12 -> Core -> L1
```

Direction belongs to route traversal, not to duplicated physical topology.

## E2E assertions

Prove:

- stable building/level/slab/penetration/core identities;
- correct route segment order;
- correct hidden vertical length;
- correct total engineering length;
- Save/Reopen identity preservation;
- Undo of the logical vertical operation;
- Redo of the same operation;
- deterministic result on repeat.

## Engineering invariant

```text
total canonical route length =
  visible horizontal length
+ hidden vertical physical length
+ other canonical physical segments
```

Vertical length must not be derived only from UI projection.

## Additional acceptance cases

Where domain support already exists, include:

- basement -> ground;
- ground -> upper floor;
- upper floor -> technical floor;
- technical floor -> roof;
- multiple penetrations on one slab;
- multiple cores in one building.

---

# P7-C7 — Destructive-operation adversarial qualification

## Requirement

For each physical entity:

```text
Level
Slab
SlabPenetration
VerticalCore
Building
```

qualify:

```text
delete when unused
delete when referenced
delete after Save/Reopen
delete after Undo
delete after Redo
delete from stale version
```

Default policy for referenced physical entities:

```text
REJECT
```

Cascade is allowed only via an explicit typed command whose semantics list the full dependent delta.

No partial cascade may leave a child/reference alive after its owner has been removed.

If retired physical identities are tombstoned by the canonical model, identity reuse must be forbidden where it could create reopen or history ambiguity.

---

# P7-C8 — Repository-wide slab-bypass audit

## Requirement

Audit production and test support code for all cross-level routing paths.

Search for patterns equivalent to:

```text
LevelId -> LevelId
floor index -> floor index
manual target-level assignment
manual vertical distance calculation
route segment level switch
cross-level mutation without slab/penetration/core resolution
```

Production runtime must have exactly one canonical class of path:

```text
CrossLevelIntent
 -> slab resolution
 -> penetration resolution
 -> vertical-topology resolution
 -> canonical route mutation
```

Test fixtures may construct physical topology directly only if they still pass canonical validators and are unreachable from production runtime.

## Exit gate

```text
0 production slab-bypass paths
```

The audit must produce a short evidence document or a dedicated section in the final freeze record listing searched surfaces and resolved exceptions.

---

# P7-C9 — Exact-SHA Flutter + macOS qualification

## Requirement

Qualification is valid only for one immutable production SHA after P7-C1..P7-C8 are complete.

Record:

```text
FINAL_P7_PRODUCTION_SHA=<sha>
```

Mandatory Flutter gates:

```text
Dart format          PASS
flutter analyze      PASS
flutter full test    PASS
quality              SUCCESS
verification         SUCCESS
```

Mandatory macOS gates:

```text
Flutter/macOS setup  PASS
flutter pub get      PASS
Analyze              PASS
Full test            PASS
Build macOS debug    PASS
path_provider smoke  PASS
workflow             SUCCESS
```

The qualification suite must contain evidence for:

- VerticalCore guards;
- cross-level atomicity;
- stale-version handling;
- schema-v9 Save/Reopen;
- three-level forward routing;
- reverse routing;
- destructive-operation matrix;
- Undo/Redo;
- corrupt persistence fixtures;
- slab-bypass regression coverage.

A retry-until-green run, skipped mandatory test, temporary exclusion or known flaky mandatory suite does not qualify the SHA.

---

# P7-C10 — Final freeze

Create:

```text
docs/architecture/p7-final-freeze.md
```

The final freeze document must record:

- branch;
- exact qualified production SHA;
- Flutter workflow ID;
- macOS workflow ID;
- canonical vertical architecture;
- physical identity set;
- persistence schema version;
- atomicity/failure contract;
- dependency/removal contract;
- Undo/Redo contract;
- Save/Reopen contract;
- slab-bypass audit result;
- intentional limitations;
- future extension rules.

Terminal status:

```text
P7 = FROZEN + HARDENED + QUALIFIED
```

After freeze, a core P7 contract may change only with:

1. a reproduced defect/regression;
2. a regression test;
3. an impact analysis;
4. an explicit compatibility decision;
5. a new exact-SHA qualification.

---

## 4. Final P7 invariants

The following invariants are mandatory after closure.

### INV-P7-01 — Stable slab identity
Every canonical slab has a unique stable `SlabId` and one ownership chain.

### INV-P7-02 — Penetration ownership
Every `SlabPenetrationId` references an existing canonical slab.

### INV-P7-03 — Building affinity
A slab/penetration/core cannot silently cross building ownership boundaries.

### INV-P7-04 — Core validity
Every `VerticalCoreId` belongs to exactly one building and references only valid levels of that building.

### INV-P7-05 — Physical continuity
A continuous vertical core cannot contain an unexplained physical gap.

### INV-P7-06 — No route without physical transition evidence
A durable cross-level route must reference canonical physical transition evidence.

### INV-P7-07 — Hidden length is engineering length
Vertical hidden distance contributes to canonical route length and downstream engineering calculations.

### INV-P7-08 — Atomic cross-level authoring
A failed continuation cannot leave a partial slab/penetration/core/route transition.

### INV-P7-09 — Stale mutation cannot win
A stale editor/session mutation cannot overwrite a newer canonical project version.

### INV-P7-10 — Durable identity survives reopen
Save/Reopen cannot regenerate physical IDs from ordering or coordinates.

### INV-P7-11 — Vertical Undo/Redo is logical, not partial
Undo/Redo restores or reapplies the whole logical vertical transition and its engineering evidence.

### INV-P7-12 — Destructive mutations are dependency-safe
Removal cannot leave dangling physical references.

### INV-P7-13 — Persistence corruption fails closed
Invalid current-schema vertical topology cannot be partially loaded or silently repaired.

### INV-P7-14 — No production bypass
No production cross-level route path may bypass slab/penetration/vertical-topology resolution.

### INV-P7-15 — One canonical owner timeline
Vertical authoring uses the same canonical mutation/session/history ownership model as the rest of P7; no second ownership timeline is introduced.

---

## 5. Minimum mandatory test matrix

```text
VerticalCore
  valid contiguous levels
  missing level
  foreign-building level
  duplicate level
  continuous-core physical gap

Cross-level atomicity
  normal L1 -> L2
  reverse L2 -> L1
  preflight failure
  stale-version rejection
  persistence-owner failure
  projection/materialization failure

Three-level routing
  L1 -> L2 -> L3
  L3 -> L2 -> L1
  Save/Reopen
  Undo
  Redo
  hidden-length accounting

Persistence
  valid schema-v9 reopen
  malformed slab reference
  malformed penetration reference
  malformed core membership
  malformed route physical reference

Destructive operations
  Level
  Slab
  SlabPenetration
  VerticalCore
  Building
  referenced/unreferenced/stale/reopened variants
```

Tests are evidence for invariants, not substitutes for production guards. A behavior that is enforced only in tests is not considered implemented.

---

## 6. Definition of Done

P7 is not closed until every item below is true:

```text
[ ] formatter gate green
[ ] flutter analyze green
[ ] flutter full test green

[ ] VerticalCore dependency guards implemented
[ ] continuous-core physical gap handling explicit and tested
[ ] destructive Level/Building mutations fail closed on dependencies

[ ] cross-level continuation is atomic
[ ] no partial slab handoff is possible
[ ] no orphan penetration is possible
[ ] no orphan vertical route leg is possible

[ ] stale-version exact restoration qualified
[ ] fresh-version retry deterministic

[ ] schema-v9 vertical Save/Reopen qualified
[ ] corrupt schema-v9 vertical topology fails closed

[ ] three-level forward E2E green
[ ] three-level reverse E2E green
[ ] hidden vertical engineering length verified

[ ] destructive-operation adversarial matrix green
[ ] repository slab-bypass audit complete
[ ] zero production bypass paths

[ ] exact-SHA Flutter qualification green
[ ] exact-SHA macOS qualification green

[ ] p7-final-freeze.md committed
[ ] exact qualified SHA recorded
[ ] P7 declared FROZEN + HARDENED + QUALIFIED
```

---

## 7. Recommended commit structure

Keep closure changes reviewable and avoid mixing unrelated stages:

```text
fix(p7): restore clean formatter and CI baseline
fix(p7): enforce vertical topology dependency guards
fix(p7): make cross-level continuation atomic
fix(p7): preserve exact state on stale vertical continuation
fix(p7): harden schema-v9 vertical topology persistence
test(p7): qualify three-level forward and reverse routing
test(p7): harden destructive vertical topology mutations
refactor(p7): remove remaining slab-bypass production paths
test(p7): complete exact-sha vertical qualification
docs(p7): freeze project structure vertical authoring contract
```

Each substantive production commit must include or update regression/qualification tests in the same stage.

---

## 8. Final architecture boundary

The terminal architecture is:

```text
P7A — horizontal boundary / hosted identity
  FROZEN

P7B — building physical topology
  Level
  Slab
  SlabPenetration
  VerticalCore
  dependency ownership

P7C — cross-level physical routing
  atomic continuation
  hidden vertical physical length
  persistence
  Undo/Redo
  stale-version safety

P7 FINAL QUALIFICATION
  exact SHA
  Flutter green
  macOS green
  adversarial E2E green
  slab-bypass audit clean

=> P7 FROZEN + HARDENED + QUALIFIED
```

The branch `feat/project-structure-authoring-p7-closure` is considered complete only when this closure contract and the resulting `p7-final-freeze.md` agree with the exact qualified production SHA.