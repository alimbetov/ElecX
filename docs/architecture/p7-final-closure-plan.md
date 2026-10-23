# P7 Final Closure Specification

Branch: `feat/project-structure-authoring-p7-closure`  
Base: `feat/project-structure-authoring`  
Status: **IMPLEMENTATION-READY CLOSURE CONTRACT / ACTIVE**

Target terminal state:

```text
P7 = FROZEN + HARDENED + QUALIFIED
```

This document is the normative implementation and qualification contract for final P7 closure. It preserves already-qualified P7A horizontal boundary/identity semantics and closes the remaining vertical physical topology, cross-level routing, deterministic planning/diff, dependency integrity, concurrency, persistence, destructive-operation safety and exact-SHA qualification.

P7 is also the structural compatibility boundary for P8-P17. Later stages MUST consume P7 identity, ownership, candidate/change-set and mutation contracts rather than redesign them.

---

# 0. Normative language and precedence

The words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT** and **MAY** are normative.

If two statements conflict, apply this precedence:

1. frozen/qualified P7A canonical ownership/session/history contracts;
2. production domain invariants and stable identity contracts already present in the branch;
3. this P7 closure specification;
4. tests, UI projections and legacy compatibility layers.

A test that contradicts a higher-precedence contract MUST be corrected. Production architecture MUST NOT be weakened merely to keep such a test green.

P7 MUST reuse the existing canonical commit, persistence-owner and history protocol. It MUST NOT introduce a second transaction/history/session model for vertical authoring.

---

# 1. Closure objective

P7 is closed only when the production editor can create, mutate, preview, diff, persist, reopen, undo/redo and safely reject invalid multi-level physical routing while preserving stable canonical identity and without bypassing slab/core topology.

The target physical chain is:

```text
source Level
  -> source horizontal route
  -> SlabId
  -> SlabPenetrationId
  -> VerticalCoreId / canonical vertical transition
  -> hidden physical vertical route leg
  -> target Level
  -> target horizontal route
```

A durable direct `LevelId -> LevelId` transition without physical topology evidence is forbidden.

The closure principle is:

```text
one physical object
  = one stable canonical identity
  = one canonical owner chain
  = one semantic dependency position
  = one persistence identity
  = one reopen identity
```

---

# 2. Existing production baseline and reviewed facts

The closing contract is based on the actual production model, not on hypothetical future types.

## 2.1 Existing stable identity foundation

Production already provides stable `EntityId` value objects including:

```text
ProjectId
BuildingId
LevelId
SlabId
VerticalCoreId
RouteId
RouteAnchorId
```

New identity MUST NOT be derived from display numbers, list positions, local row IDs, UI indexes or platform state.

`SecureRandomEntityIdFactory` currently allocates new UUID-v4 identities. This is valid for durable identity, but it means deterministic preview requires explicit identity reservation; candidate construction MUST NOT call the random allocator independently on every preview evaluation.

## 2.2 Existing canonical slab model

`ProjectSlab` already owns:

```text
SlabId id
BuildingId buildingId
SlabKind kind
LevelId? belowLevelId
LevelId? aboveLevelId
int bottomElevationMm
int thicknessMm
String materialId
List<BoundaryPointMm> footprint
```

and exposes stable `SlabFaceRef` values.

Therefore P7-C2 is a **qualification/hardening** stage, not a redesign of slab identity.

The slab contract already establishes:

- stable `SlabId`;
- building ownership;
- explicit below/above level affinity;
- explicit physical bottom/top elevation;
- positive physical thickness;
- non-degenerate footprint;
- foundation/inter-level/roof topology semantics.

P7 MUST preserve this model unless a reproduced defect proves an additive correction is necessary.

## 2.3 Existing VerticalCore model

`ProjectVerticalCore` currently owns:

```text
VerticalCoreId id
BuildingId buildingId
VerticalCoreKind kind
Set<LevelId> levelIds
List<BoundaryPointMm> footprint
String? name
```

Consequences:

- `levelIds` is membership, not traversal order;
- physical ordering MUST NOT depend on `Set` iteration;
- serialization order MAY be canonicalized for deterministic output but remains non-semantic;
- continuity is a project-level invariant because it depends on canonical building levels.

Current project validation proves building/level existence and building affinity, but does not yet prove physical continuity. P7-C3 MUST close that gap.

## 2.4 Existing penetration model and required typed migration

`BoundaryPenetration` currently has a durable `String id`, paired string anchor IDs, optional `SlabId`, and optional `VerticalCoreId`. New slab authoring already requires stable `SlabId` host evidence.

This is sufficient for current route continuity but is not strong enough as the final P11/P15/P16 boundary because slab penetrations remain untyped relative to other canonical physical identities.

P7 therefore MUST introduce:

```text
SlabPenetrationId extends EntityId
```

for canonical slab penetrations, plus the corresponding identity-factory allocation/reservation path.

Migration constraints:

- legacy wall penetration IDs MAY remain compatible string values at the legacy boundary;
- persisted canonical slab penetration IDs MUST migrate losslessly into `SlabPenetrationId`;
- migration MUST NOT regenerate an existing durable penetration identity;
- canonical slab registries, route transitions and persistence MUST use the typed ID after migration;
- coordinate equality MUST NOT be used as penetration identity;
- anchor identity MUST remain stable and explicitly associated with the typed penetration identity.

If a unified typed `BoundaryPenetrationId` is chosen instead, it is acceptable only if slab-vs-wall host kind remains typed and all requirements stated for `SlabPenetrationId` remain provable. The implementation decision MUST be recorded in final freeze evidence.

---

# 3. Frozen P7A scope / non-goals

The following contracts are frozen and MUST NOT be redesigned without a reproduced regression plus a dedicated regression test:

- `BoundaryEdgeId` identity;
- boundary lineage;
- hosted-object ownership;
- wall-profile ownership;
- split/merge semantics;
- canonical session affinity;
- persistence-owner ordering;
- canonical history ownership;
- stale-version protection;
- same-version session replacement detection;
- session-switch/re-entrant owner hardening;
- old-session rematerialization protection.

P7 closure MUST NOT introduce:

- another project mutation/history/session model;
- UI-specific engineering mutation paths;
- durable direct level-to-level routing shortcuts;
- identity derived from indexes, coordinates, display order or serialized array order;
- implicit destructive cascades;
- silent repair of structurally invalid persisted topology;
- rollback of an already committed canonical winner merely because a later owner/projection step failed.

The following remain outside P7 except where required to prove compatibility:

- wizard UI;
- generator algorithms;
- generalized engineering graph implementation;
- discipline starter generation;
- auto-placement algorithms;
- pathfinding/auto-routing algorithms;
- provenance engine;
- Drift/SQLite implementation;
- unrelated native packaging work.

---

# 4. Downstream compatibility boundary: P8-P17

P7 MUST freeze contracts strong enough for:

```text
P8   Wizard contracts + deterministic preview/diff
P9   apartment generator 1..10
P10  cottage/building/residential-complex generation
P11  generalized engineering graph/connectivity
P12  POWER/LIGHTING/LAN/CCTV/ACS/FIRE starter generation
P13  auto-placement
P14  route topology / auto-routing
P15  provenance + selective regeneration
P16  Drift/SQLite production persistence
P17  native cross-platform qualification
```

## P8 — deterministic preview/diff

P7 MUST provide a pure planning path:

```text
canonical state
+ exact session/version
+ normalized intent
+ explicit identity reservation
    -> candidate
    -> semantic change set
    -> validation result
```

without canonical mutation.

## P9/P10 — generators

Manual authoring and generation MUST use equivalent canonical commands/planners/validators. No generator-only validation or identity bypass is allowed.

## P11 — generalized graph

The physical model MUST expose stable typed graph references for at least:

```text
BuildingId
LevelId
SlabId
SlabPenetrationId (or qualified unified typed penetration ID)
VerticalCoreId
RouteId
RouteAnchorId
```

Graph reconstruction MUST NOT depend on geometry matching or UI order.

## P12 — discipline starters

Building, level, slab, penetration and core topology MUST remain discipline-neutral. POWER/LIGHTING/LAN/CCTV/ACS/FIRE may reference the same hosts without redefining physical ownership.

## P13 — auto-placement

Physical hosts MUST be addressable by stable ID and canonical geometry, not transient room/surface indexes.

## P14 — auto-routing

Cross-level transitions MUST be usable as real graph edges with canonical physical/engineering cost. Auto-routing MUST NOT infer a legal vertical edge merely from elevation delta.

## P15 — provenance/selective regeneration

Stable identity MUST survive compatible regeneration. Semantic change sets MUST enumerate affected identities and dependency effects so provenance can later attach source/generation metadata without replacing the P7 mutation model.

## P16 — Drift/SQLite

P7 ownership MUST map cleanly to stable PK/FK relations. No semantic relation may depend on JSON/list/map ordering or hidden UI-only references.

## P17 — native qualification

Validation, candidate planning, canonical ordering, serialization semantics and engineering calculations MUST be independent of locale, filesystem ordering and map/set insertion order.

---

# 5. Canonical physical ordering contract

`levelNumber` and `displayOrder` are presentation/authoring semantics, not physical adjacency authority.

For operations that require vertical order, P7 MUST resolve building levels from canonical physical topology using explicit level/slab data.

The preferred proof order is:

```text
Building ownership
  -> canonical level elevation
  -> canonical inter-level slab adjacency
  -> validated unique physical sequence
```

Rules:

1. A level belongs to exactly one building.
2. An inter-level `ProjectSlab` explicitly relates `belowLevelId` and `aboveLevelId`.
3. `bottomElevationMm/topElevationMm` and level elevation MUST be physically compatible according to the existing slab/level validation contract.
4. `levelNumber`, `displayOrder`, name and insertion order MUST NOT be used to manufacture adjacency.
5. If two levels are physically ambiguous for an operation requiring strict order and slab adjacency does not disambiguate them, the operation MUST fail closed with a typed `ambiguousLevelOrder`/equivalent issue.
6. Basement, ground, residential, technical and roof level kinds participate in the same physical ordering rules; kind does not substitute for geometry/topology.

P7 does not require arbitrary disconnected/bypass core semantics. A continuous `VerticalCore` MUST serve every canonical intermediate routable level between its lowest and highest served levels.

Example after canonical ordering:

```text
B1 < Ground < L1 < Technical < L2 < Roof

{Ground, L1, Technical}      VALID
{Ground, Technical}          INVALID
{L1, Technical, L2}          VALID
{B1, L1}                     INVALID when Ground lies between
```

---

# 6. Identity reservation contract — blocker resolution for deterministic preview

Random durable identity allocation and deterministic preview are compatible only when identity allocation is explicit.

P7 MUST implement an explicit conceptual contract equivalent to:

```text
MutationIdentityReservation
or
IdentityAllocationPlan
```

Exact Dart naming is implementation-defined, but the semantics are mandatory.

## 6.1 Reservation lifecycle

One preview/apply lifecycle MUST use one immutable reservation containing every new durable identity required by the candidate, for example:

```text
new SlabPenetrationId
new penetration-anchor IDs / typed anchor identities if created
new RouteAnchorId values
other new physical IDs required by the operation
```

The deterministic formula is:

```text
canonical state
+ exact session identity
+ observed canonical version
+ normalized intent
+ identity reservation
    => exact candidate
    => exact semantic change set
```

With the same five inputs, candidate and change set MUST be equal by canonical semantic equality, including all reserved IDs.

## 6.2 Preview rules

Preview MUST:

- not mutate canonical project state;
- not register history;
- not persist entities;
- not consume a new random identity on each recomputation;
- reuse the same reservation while the preview remains valid;
- expose the reservation/plan internally to the commit path without making UI indexes authoritative.

Repeated rendering/revalidation of one preview MUST NOT produce different IDs.

## 6.3 Commit rules

Commit MUST verify before mutation that:

- exact session still matches;
- observed canonical version still matches;
- reservation belongs to the same preview/intent context;
- reserved IDs do not collide with active identities;
- reservation has not already been consumed by another committed operation.

Commit MUST apply the same IDs shown by the accepted preview. It MUST NOT silently allocate replacements.

## 6.4 Stale preview

If canonical state/session/version changes after preview:

```text
old preview -> STALE / REJECT
```

The system MUST NOT silently replan and apply under the user's old confirmation.

A fresh retry MAY create a fresh reservation, but the new candidate/diff is a new preview contract.

## 6.5 Deterministic equivalence

Two independently created reservations may contain different UUID values. Therefore P7 distinguishes:

- **exact candidate determinism**: same state + session/version + intent + same reservation -> identical candidate/change set;
- **semantic planning determinism**: same state + intent with different fresh reservations -> same hosts, topology, operation kinds, engineering delta and dependency effects after normalizing newly allocated IDs.

This distinction is mandatory for P8 testing and prevents false claims of byte-identical random-ID previews.

---

# 7. Semantic candidate/change-set contract

Candidate/change-set is a domain contract, not a JSON diff.

## 7.1 Candidate

A candidate MUST be immutable/pure with respect to canonical state and contain enough information to validate the full operation before commit:

- source/target `LevelId`;
- selected `SlabId` and side/adjacency evidence;
- `SlabPenetrationId` or qualified typed penetration identity;
- optional/required `VerticalCoreId` as appropriate;
- source/target route/anchor references;
- hidden vertical route leg evidence;
- engineering length delta;
- dependency effects;
- expected session/version;
- identity reservation reference/value set.

## 7.2 Semantic change set

The change set MUST describe domain effects such as:

```text
CreatePenetration
AttachPenetrationToSlab
BindPenetrationToVerticalCore
Add/ReplaceCrossLevelRouteTransition
AddHiddenVerticalRouteLeg
UpdateEngineeringEvidence
RemovePhysicalDependency
```

Exact class names are implementation-defined.

The change set MUST NOT use raw JSON property differences as its source of truth.

Each operation MUST expose:

- operation kind;
- affected stable identity/identities;
- owner/host identity when applicable;
- before/after semantic payload where required for diff/history;
- dependency additions/removals;
- engineering delta where applicable.

## 7.3 Canonical operation ordering

Change-set operation ordering MUST be deterministic and independent of map/set iteration.

Use a documented ordering equivalent to:

```text
1. identity/host creation
2. owner/dependency attachment
3. route topology mutation
4. engineering evidence mutation
5. removals in reverse dependency-safe order
```

Within the same operation category, order by stable typed identity value or another explicitly documented total order.

This order is for deterministic diff/serialization; it MUST NOT replace dependency validation.

## 7.4 Generator parity

Manual UI authoring, P8 wizard application and future P9/P10 generators MUST be able to invoke the same planner/validator/commit semantics. Generator mode MUST NOT bypass dependency, continuity, session/version or persistence invariants.

---

# 8. Canonical dependency graph

Minimum dependency graph:

```text
Project
└── Building
    ├── Level
    ├── Slab
    │   ├── below/above LevelId
    │   └── SlabPenetration
    └── VerticalCore
        └── covered LevelIds

Canonical Route
└── CrossLevelTransition
    ├── source LevelId
    ├── target LevelId
    ├── SlabId
    ├── SlabPenetrationId
    ├── VerticalCoreId when core-routed
    ├── RouteAnchorId(s)
    └── physical/engineering vertical evidence
```

Every durable reference MUST satisfy:

```text
target exists
owner exists
target belongs to expected owner/building
target is active/not retired
target is topologically and geometrically compatible
target belongs to the same canonical session/version snapshot used by planning
```

The dependency graph MUST be queryable without UI projection so P15/P16 can later implement selective regeneration and SQL referential integrity.

---

# 9. Global invariants

## Identity and ownership

**INV-P7-01** — Canonical physical identity is never derived from list position, coordinates, display number, floor ordinal, route segment index or UI state.

**INV-P7-02** — Every canonical slab reference resolves to one active `SlabId` in the expected building.

**INV-P7-03** — Every canonical slab penetration has stable typed identity and belongs to exactly one slab host.

**INV-P7-04** — Every `VerticalCoreId` belongs to exactly one `BuildingId`.

**INV-P7-05** — Every core `LevelId` exists and belongs to the same building.

**INV-P7-06** — Core membership is continuous in canonical physical level order; gaps fail closed.

**INV-P7-07** — Physical level order never depends on `Set`, map, insertion, display or serialized order.

**INV-P7-08** — A durable cross-level route cannot exist without resolvable physical transition evidence.

## Mutation and concurrency

**INV-P7-09** — One user cross-level continuation is one logical canonical transaction/change set.

**INV-P7-10** — Pre-commit rejection leaves canonical state/version/history unchanged.

**INV-P7-11** — After canonical commit succeeds, later owner/projection failure cannot implicitly revert the canonical winner.

**INV-P7-12** — A stale version/session never overwrites the canonical winner.

**INV-P7-13** — Vertical authoring inherits exact-session-affinity and session-switch protections from P7A.

## Engineering/persistence

**INV-P7-14** — Hidden vertical physical distance contributes to canonical engineering route length.

**INV-P7-15** — Save/Reopen preserves physical identities and ownership without regeneration.

**INV-P7-16** — Undo/Redo restores/reapplies the complete logical vertical operation.

**INV-P7-17** — Structural/destructive operations cannot leave dangling physical references.

**INV-P7-18** — Production runtime contains zero durable slab-bypass level-switch paths.

**INV-P7-19** — Corrupt current-schema vertical topology fails closed rather than silently changing physical meaning.

**INV-P7-20** — A single slab/core/cross-level transition cannot bridge unrelated buildings.

## Preview/diff/future compatibility

**INV-P7-21** — Candidate construction is side-effect free.

**INV-P7-22** — Exact preview determinism includes an explicit identity reservation.

**INV-P7-23** — Commit uses the IDs accepted by preview; no hidden replacement allocation.

**INV-P7-24** — Semantic diff is typed domain delta, not JSON diff.

**INV-P7-25** — Change-set ordering is deterministic and independent of map/set order.

**INV-P7-26** — Manual authoring and generators use equivalent canonical invariants.

**INV-P7-27** — Generic physical topology remains discipline-neutral.

**INV-P7-28** — P7 ownership remains representable by stable relational PK/FK mappings.

**INV-P7-29** — Platform/locale/filesystem/map/set ordering cannot change semantic results.

**INV-P7-30** — Stable identity can accept future provenance metadata without changing the physical identity contract.

---

# 10. Failure taxonomy

P7 MUST distinguish failure phase and committed state.

## 10.1 Pre-commit rejection

Examples:

- missing/foreign slab/core/level;
- missing or invalid typed penetration identity;
- discontinuous core;
- ambiguous level order;
- incompatible slab adjacency;
- invalid geometry;
- reservation collision/invalid reservation;
- stale preview/version/session;
- blocked destructive dependency.

Contract:

```text
canonical state before == canonical state after
canonical version unchanged
history unchanged
reservation not reported as committed
no orphan physical artifact
```

## 10.2 Commit conflict

A session/version change detected at commit boundary MUST reject without silent rebase. The user/system must obtain a fresh candidate.

## 10.3 Post-commit persistence-owner failure

If canonical commit succeeded but persistence-owner acknowledgement fails:

- canonical winner remains authoritative;
- result MUST identify that commit occurred;
- outcome MUST NOT be reported as ordinary validation rejection;
- history/session handling follows frozen P7A owner-failure semantics;
- stale projection cannot overwrite the winner.

## 10.4 Post-commit projection/materialization failure

If canonical commit/owner boundary succeeded but projection fails:

- canonical winner remains authoritative;
- retry/rematerialization reads from canonical winner;
- no rollback to stale UI state;
- failure remains distinguishable from pre-commit rejection.

## 10.5 Typed issue categories

Minimum semantic categories:

```text
missingBuilding
missingLevel
missingSlab
missingPenetration
missingVerticalCore
foreignBuildingReference
invalidSlabAdjacency
discontinuousVerticalCore
ambiguousLevelOrder
invalidPhysicalTransition
invalidIdentityReservation
identityCollision
dependencyBlocked
staleVersion
sessionMismatch
committedOwnerFailure
committedProjectionFailure
corruptPersistence
```

Exact Dart names MAY differ, but semantic distinguishability is mandatory.

---

# 11. Closure sequence

```text
P7-C1  baseline / current CI
   -> P7-C2  canonical slab contract qualification
   -> P7-C3  typed slab-penetration identity closure
   -> P7-C4  VerticalCore dependency + continuity guards
   -> P7-C5  identity reservation + deterministic candidate/change-set
   -> P7-C6  atomic cross-level continuation
   -> P7-C7  stale/session concurrency qualification
   -> P7-C8  Save/Reopen persistence qualification
   -> P7-C9  3-level E2E + reverse routing
   -> P7-C10 destructive-operation adversarial matrix
   -> P7-C11 slab-bypass repository audit
   -> P7-C12 P8-P17 compatibility audit
   -> P7-C13 exact-SHA Flutter + macOS qualification
   -> P7-C14 final freeze
```

A stage may be developed in parallel locally but cannot be marked closed before its prerequisite proofs are satisfied.

---

# P7-C1 — Baseline / current CI

Mandatory gates:

```text
dart format --output=none --set-exit-if-changed .   PASS
flutter analyze                                      PASS
flutter test                                         PASS
```

CI weakening/bypass is forbidden. Record exact SHA and workflow evidence.

---

# P7-C2 — Canonical slab contract qualification

Qualify the existing `ProjectSlab` model rather than introducing a parallel slab abstraction.

Required proofs:

- `SlabId` stable and unique;
- store key equals entity ID;
- `buildingId` exists;
- below/above level references exist when non-null;
- referenced levels belong to the slab building;
- foundation/inter-level/roof side rules hold;
- inter-level slab below/above ordering is physically valid;
- duplicate physical level-side pair is rejected according to the current topology contract;
- bottom/top elevation and thickness are preserved through Save/Reopen;
- footprint/material/host evidence survives Save/Reopen;
- slab dependency reverse lookup exists without UI projection.

Required rejection tests:

```text
missing slab host
foreign-building slab level
same level on both sides
invalid foundation/inter-level/roof sides
invalid physical level order
duplicate claimed physical level pair
route transition incompatible with slab adjacency
```

Exit gate:

```text
one canonical slab model
zero UI-derived slab identity paths
```

---

# P7-C3 — Typed slab-penetration identity closure

Introduce/formalize typed canonical penetration identity before final vertical qualification.

Required contract:

```text
SlabPenetrationId extends EntityId
```

or a reviewed unified typed `BoundaryPenetrationId` satisfying the same guarantees.

Required implementation effects:

- entity factory/reservation support;
- canonical registry/store key uses typed ID;
- paired anchors reference the same typed penetration identity;
- route transition references typed penetration identity;
- persistence stores/reopens it exactly;
- existing string IDs migrate losslessly;
- no coordinate-based identity regeneration;
- no durable identity reuse that would make history/reopen/provenance ambiguous.

Required tests:

```text
legacy persisted ID -> typed ID with identical value
new slab penetration gets typed stable ID
Save/Reopen preserves typed ID
Undo/Redo preserves original identity semantics
same coordinates do not imply same penetration identity
slab deletion blocked by referenced penetration
penetration cannot outlive missing slab
```

Exit gate:

```text
all new canonical slab penetrations use stable typed identity
```

---

# P7-C4 — VerticalCore dependency and continuity guards

Required proofs:

- building exists;
- all member levels exist;
- all member levels belong to same building;
- membership contains at least two distinct levels;
- physical order is uniquely resolvable from canonical topology;
- `Set` iteration/insertion order has no semantic effect;
- continuous core includes every canonical intermediate routable level;
- footprint remains valid;
- store key/id mismatch fails closed.

`RemoveLevel` MUST reject while referenced by core/slab/penetration/route unless an explicit typed cascade command exists.

`RemoveBuilding` MUST reject while it still owns/references physical topology unless an explicit aggregate cascade is used.

Required tests:

```text
same core levels inserted in different Set order -> same result
levelNumber/displayOrder changes -> no manufactured physical adjacency
foreign-building core level -> reject
missing core level -> reject
ambiguous/equal physical order without disambiguating topology -> reject
L1,L3 with intermediate L2 -> reject
L1,L2,L3 -> accept
remove referenced level -> reject
remove referenced building -> reject
```

---

# P7-C5 — Identity reservation + deterministic candidate/change-set

Implement the reservation and pure planning contracts from sections 6-7.

Required tests:

```text
preview does not mutate canonical project
preview does not register history/persistence
re-evaluating same preview does not consume new IDs
same state + session/version + intent + same reservation -> exact same candidate
same inputs + same reservation -> exact same semantic change set
fresh reservations -> same normalized semantic topology/engineering result
preview -> commit uses exactly reserved IDs
reserved-ID collision -> reject before mutation
stale preview -> reject without hidden replan
fresh retry -> new preview/reservation allowed
change-set ordering independent of map/set insertion order
semantic change set is not derived from JSON diff
all affected IDs/dependencies enumerated
```

Exit gate:

```text
P8-compatible pure preview contract exists in production code
```

---

# P7-C6 — Atomic cross-level continuation

One user continuation MUST be one logical canonical transaction.

Required pipeline:

```text
intent
 -> normalize
 -> capture exact session/version
 -> obtain/reuse identity reservation
 -> resolve source topology
 -> resolve target topology
 -> build candidate
 -> build semantic change set
 -> validate ownership/dependencies/geometry
 -> revalidate exact session/version + reservation
 -> single canonical commit
 -> persistence-owner boundary
 -> history registration
 -> projection/materialization
```

Forbidden partial states:

```text
penetration committed, vertical leg missing
vertical leg committed, target continuation missing
route updated, engineering evidence missing
slab handoff survives a pre-commit downstream failure
preview IDs differ from committed IDs
```

Inject failures at least:

```text
before penetration candidate
before vertical-leg candidate
before canonical commit
at session/version revalidation
at persistence-owner callback
at post-commit projection/materialization
```

For pre-commit failures assert state/version/history unchanged. For post-commit failures assert canonical-winner semantics, not rollback.

---

# P7-C7 — Stale/session concurrency qualification

Qualification scenario:

```text
A previews V10 with reservation R1
B commits V11
A confirms old preview
=> A rejected stale
=> R1 not silently rebound to V11
=> V11 remains canonical
=> fresh preview on V11 required
```

Must preserve exact route ID, anchor IDs, locks, mandatory waypoints, engineering payload and canonical winner.

Required tests:

```text
stale preview cannot commit
same-version session replacement detected
old-session rematerialization blocked
winning project unchanged
no orphan penetration/vertical leg
fresh-version retry succeeds with explicit fresh preview
post-commit owner failure remains distinguishable
post-commit projection failure remains distinguishable
```

---

# P7-C8 — Save/Reopen persistence qualification

Qualify the actual current schema version at the final P7 SHA. Do not hard-code a speculative schema number here.

Persist/reopen exactly:

- `SlabId` and full slab ownership/physical attributes;
- typed slab penetration ID and anchor ownership;
- `VerticalCoreId`, building affinity and membership;
- canonical cross-level route transition;
- hidden vertical physical leg/evidence;
- route engineering evidence;
- stable `RouteAnchorId` values;
- any persisted reservation-derived committed IDs as ordinary canonical IDs, not as ephemeral reservation state.

Ephemeral uncommitted preview/reservation state SHOULD NOT become part of project persistence unless a future explicit draft-persistence contract requires it.

Save/reopen MUST fail closed for:

```text
unknown LevelId
unknown SlabId
unknown typed penetration ID/host
unknown VerticalCoreId
penetration without slab
cross-building reference
non-contiguous core
ambiguous physical order
route transition without physical host evidence
hidden leg with missing endpoint
```

Required corruption fixtures cover each case.

Final freeze MUST record the exact qualified schema version and migration path for legacy penetration IDs.

---

# P7-C9 — Three-level E2E + reverse routing

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

Direction belongs to route traversal, not duplicated physical objects.

Prove:

- stable building/level/slab/penetration/core identities;
- correct physical transition order;
- correct hidden vertical length;
- correct total engineering length;
- Save/Reopen identity preservation;
- coherent Undo/Redo;
- deterministic preview/diff;
- reverse traversal reuses physical host identity rather than creating duplicate slab/core identity.

Engineering invariant:

```text
total canonical route length =
  visible horizontal length
+ penetration path contribution
+ hidden vertical physical length
+ other canonical physical segments
```

At minimum qualify representative basement/ground/residential/technical/roof combinations supported by the model.

---

# P7-C10 — Destructive-operation adversarial matrix

For:

```text
Level
Slab
SlabPenetration
VerticalCore
Building
```

qualify:

```text
delete unused
delete referenced
delete after Save/Reopen
delete after Undo
delete after Redo
delete from stale version/session
```

Default referenced-object policy:

```text
REJECT
```

Cascade is allowed only via an explicit typed command whose semantic change set enumerates the complete dependency-safe removal delta.

Dependency rejection MUST expose target ID/type, blocker kind, blocker ID(s) and reason.

No partial cascade may leave a child/reference after owner removal.

---

# P7-C11 — Repository-wide slab-bypass audit

Audit `lib/`, relevant tests and integration surfaces for patterns equivalent to:

```text
LevelId -> LevelId direct transition
floor index -> floor index
manual target-level assignment
vertical length from elevation only
route segment level switch without physical host resolution
coordinate-matched penetration identity
cross-level mutation without slab/penetration/core evidence
```

Production runtime must reduce to one canonical class of path:

```text
CrossLevelIntent
 -> canonical topology resolution
 -> identity reservation
 -> typed penetration/slab/core candidate
 -> semantic change set
 -> canonical commit
```

Exit gate:

```text
0 production slab-bypass paths
0 coordinate/index-derived durable vertical identities
```

Final freeze records searched surfaces and justified test-only exceptions.

---

# P7-C12 — P8-P17 compatibility audit

## P8

PASS only if preview can be built without commit, repeated preview is ID-stable within one reservation, semantic diff is typed/deterministic, and stale preview cannot silently replan on confirm.

## P9/P10

PASS only if generated structures can use the same canonical planner/validator/commit protocol without privileged identity or validation bypass.

## P11

PASS only if all physical nodes/edges have stable typed references and graph reconstruction needs no coordinate/index identity inference.

## P12

PASS only if physical structure is discipline-neutral and multiple disciplines may reference the same hosts.

## P13

PASS only if stable physical hosts/footprints are addressable without UI ownership.

## P14

PASS only if cross-level physical transitions can become deterministic graph edges with canonical length/cost evidence.

## P15

PASS only if stable identities survive compatible updates and semantic change sets enumerate affected identities/dependencies suitable for provenance/selective regeneration.

## P16

PASS only if ownership maps to stable PK/FK relations, deletion policy is explicit, and no relation depends on serialized order or hidden UI state.

## P17

PASS only if candidate selection, operation ordering, validation and serialization semantics are unchanged under varied map/set insertion orders and platform/locale environments.

Any FAIL that would force later breaking of P7 identity/ownership/mutation contracts is a P7 closure blocker.

---

# P7-C13 — Exact-SHA Flutter + macOS qualification

Qualification is valid only for one immutable production SHA after C1-C12.

Record:

```text
FINAL_P7_PRODUCTION_SHA=<sha>
```

Flutter gates:

```text
Dart format          PASS
flutter analyze      PASS
flutter full test    PASS
quality              SUCCESS
verification         SUCCESS
```

macOS gates:

```text
Flutter/macOS setup  PASS
flutter pub get      PASS
Analyze              PASS
Full test            PASS
Build macOS debug    PASS
path_provider smoke  PASS
workflow             SUCCESS
```

Mandatory qualification evidence includes C2-C12 tests/audits. Retry-until-green, skipped mandatory suites, temporary exclusions or known mandatory flakes do not qualify the SHA.

---

# P7-C14 — Final freeze

Create:

```text
docs/architecture/p7-final-freeze.md
```

Record:

- branch and qualified SHA;
- Flutter/macOS workflow IDs;
- exact qualified persistence schema version;
- canonical slab contract;
- final typed penetration identity choice and legacy migration rule;
- VerticalCore ordering/continuity contract;
- identity reservation lifecycle;
- deterministic candidate/change-set contract;
- atomicity/failure contract;
- dependency/removal contract;
- Undo/Redo contract;
- Save/Reopen contract;
- slab-bypass audit;
- P8-P17 compatibility audit;
- intentional limitations and future extension rules.

Terminal status:

```text
P7 = FROZEN + HARDENED + QUALIFIED
```

After freeze, a core P7 contract may change only with reproduced regression, regression test, impact analysis including P8-P17 compatibility, explicit compatibility decision and new exact-SHA qualification.

---

# 12. Mandatory test matrix

```text
Identity
  SlabId stable through mutate/save/reopen
  typed penetration ID legacy migration
  typed penetration ID save/reopen
  same coordinates != same penetration identity
  VerticalCoreId stable
  RouteAnchorId stable

Physical ordering
  Set insertion-order independence
  map insertion-order independence
  displayOrder independence
  levelNumber independence
  valid slab-derived adjacency
  ambiguous physical order reject
  continuous core accept
  physical gap reject

Identity reservation / preview
  preview side-effect free
  repeated preview does not consume new IDs
  same reservation -> exact same candidate
  same reservation -> exact same change set
  different reservations -> normalized semantic equivalence
  preview IDs == committed IDs
  collision reject
  stale preview reject/no hidden replan

Change set
  typed semantic operations
  deterministic dependency-safe ordering
  all affected IDs enumerated
  engineering delta present
  no JSON-diff source of truth

Atomic continuation
  L1 -> L2
  L2 -> L1
  preflight failure
  commit-boundary stale conflict
  owner failure after commit
  projection failure after commit
  no partial pre-commit artifact

Three-level
  L1 -> L2 -> L3
  L3 -> L2 -> L1
  reverse reuses physical hosts
  hidden/penetration length accounting
  Save/Reopen
  Undo/Redo

Persistence corruption
  missing slab
  missing typed penetration
  penetration wrong host
  missing core
  foreign core level
  discontinuous core
  ambiguous physical order
  route transition missing host
  hidden leg missing endpoint

Destructive operations
  Level
  Slab
  SlabPenetration
  VerticalCore
  Building
  unused/referenced/reopened/undo/redo/stale variants

Future compatibility
  P8 preview/diff
  P9/P10 generator parity
  P11 graph typed identity
  P12 discipline neutrality
  P13 stable host addressability
  P14 physical graph-edge readiness
  P15 provenance/change-set readiness
  P16 relational mapping readiness
  P17 insertion-order/platform determinism
```

Tests are evidence for invariants; passing tests alone do not close P7 if production code still exposes an architectural bypass.

---

# 13. Definition of Done

P7 is not closed until all are true:

```text
[ ] C1 clean baseline green
[ ] existing ProjectSlab contract fully qualified
[ ] typed canonical slab penetration identity implemented/migrated
[ ] canonical physical level ordering defined without display/index dependence
[ ] VerticalCore continuity enforced fail-closed
[ ] destructive dependency guards implemented
[ ] explicit identity reservation lifecycle implemented
[ ] preview is pure and deterministic within reservation
[ ] semantic typed change-set implemented
[ ] change-set ordering deterministic
[ ] cross-level continuation atomic at one canonical commit boundary
[ ] stale preview/version/session cannot silently rebase
[ ] post-commit failures preserve canonical winner semantics
[ ] current-schema Save/Reopen preserves all vertical identities/evidence
[ ] corruption fixtures fail closed
[ ] three-level forward E2E green
[ ] three-level reverse E2E green
[ ] hidden vertical/penetration engineering length qualified
[ ] Undo/Redo qualified as one logical operation
[ ] destructive adversarial matrix green
[ ] zero production slab-bypass paths
[ ] P8-P17 compatibility audit PASS
[ ] exact-SHA Flutter qualification green
[ ] exact-SHA macOS qualification green
[ ] p7-final-freeze.md committed
[ ] P7 declared FROZEN + HARDENED + QUALIFIED
```

---

# 14. Review findings / resolved specification blockers

## BLOCK-P7-01 — untyped slab penetration identity

**Problem:** canonical slab penetration currently uses a durable string ID while downstream P11/P15/P16 require a stronger stable typed boundary.

**Resolution:** typed canonical penetration identity is mandatory in C3 with lossless legacy migration and no coordinate-derived regeneration.

## BLOCK-P7-02 — random UUID allocation vs deterministic P8 preview

**Problem:** repeated preview cannot be exact-deterministic if every evaluation obtains new UUIDs from `SecureRandomEntityIdFactory`.

**Resolution:** explicit immutable identity reservation/allocation plan is part of preview/apply lifecycle. Exact determinism includes the reservation input; fresh reservations are compared by normalized semantic equivalence.

## BLOCK-P7-03 — `VerticalCore.levelIds` is an unordered Set

**Problem:** set iteration cannot define physical traversal.

**Resolution:** membership remains a set; physical order derives from canonical level/slab topology. Set/map order is explicitly non-semantic and covered by regression tests.

## BLOCK-P7-04 — physical adjacency could be confused with level number/display order

**Problem:** basement/ground/technical/roof and custom numbering make `levelNumber + 1` or display ordering invalid physical logic.

**Resolution:** physical adjacency is proved from building ownership, canonical elevation and slab below/above topology. Ambiguity fails closed.

## BLOCK-P7-05 — semantic diff was underspecified

**Problem:** a generic before/after or JSON diff is insufficient for P8 preview and P15 provenance.

**Resolution:** typed semantic operations, affected identities, dependency effects, engineering deltas and deterministic operation ordering are mandatory.

## BLOCK-P7-06 — post-commit rollback ambiguity

**Problem:** rolling back canonical state after successful commit would contradict frozen P7A owner/session semantics.

**Resolution:** pre-commit failure leaves state unchanged; post-commit owner/projection failure keeps the canonical winner authoritative and is reported as committed failure.

## BLOCK-P7-07 — slab contract was described as potentially absent

**Problem:** actual production already contains a strong `ProjectSlab` model.

**Resolution:** C2 is now qualification/hardening of the existing model, not speculative redesign.

## BLOCK-P7-08 — speculative schema version

**Problem:** hard-coded future schema numbers make the closure contract brittle.

**Resolution:** qualify the actual schema at final SHA; final freeze records the exact version and migration evidence.

---

# 15. Implementation approval gate

This specification is considered **APPROVED FOR IMPLEMENTATION** when no unresolved item remains in section 14.

At this revision all identified specification/architecture blockers are resolved by explicit normative contracts. Remaining work is implementation and qualification under C1-C14, not another design phase.

Implementation MUST start from the current branch baseline and progress with focused reviewable commits. Any implementation discovery that contradicts this document MUST be classified as either:

1. production defect to fix while preserving the contract; or
2. demonstrated contract defect requiring an explicit specification amendment plus impact analysis before code is weakened.
