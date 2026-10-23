# P7 Final Closure Specification

Branch: `feat/project-structure-authoring-p7-closure`  
Base: `feat/project-structure-authoring`  
Status: **REVIEWED CLOSURE CONTRACT / ACTIVE**

Target terminal state:

```text
P7 = FROZEN + HARDENED + QUALIFIED
```

This document is the normative implementation and qualification contract for final P7 closure. It does not reopen already-qualified P7A horizontal boundary/identity semantics. It closes the remaining vertical physical topology, cross-level routing, dependency integrity, persistence, concurrency, destructive-operation safety and exact-SHA qualification.

P7 is also the structural compatibility boundary for P8-P17. The contracts frozen here MUST be strong enough that later wizard/generator/routing/provenance/persistence stages consume P7 rather than redesign it.

---

# 0. Normative language and precedence

The words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT** and **MAY** are normative.

If two statements conflict, apply this precedence:

1. already frozen/qualified P7A canonical ownership/session/history contracts;
2. production domain invariants and stable identity contracts already present in the branch;
3. this P7 closure specification;
4. tests, UI projections and legacy compatibility layers.

A test that encodes behaviour contradicting a higher-precedence contract MUST be corrected. Production architecture MUST NOT be weakened merely to keep such a test green.

P7 MUST reuse the existing canonical commit, persistence-owner and history protocol. It MUST NOT introduce a second transaction/history/session model for vertical authoring.

---

# 1. Closure objective

P7 is closed only when the production editor can create, mutate, persist, reopen, undo/redo and safely reject invalid multi-level physical routing while preserving stable canonical identity and without bypassing slab/core topology.

The target physical chain is:

```text
source Level
  -> source horizontal route
  -> SlabId
  -> slab penetration identity/evidence
  -> VerticalCoreId / canonical vertical transition
  -> hidden physical vertical route leg
  -> target Level
  -> target horizontal route
```

A durable direct `LevelId -> LevelId` transition without physical topology evidence is forbidden.

The closing principle is:

```text
one physical building object
  = one stable canonical identity
  = one owner
  = one persistence representation
  = one reopen identity
  = one dependency graph position
```

---

# 2. Downstream roadmap compatibility boundary

P7 MUST be frozen with explicit compatibility for the planned stages:

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

P7 does **not** implement these stages. It MUST, however, expose canonical contracts that allow them to be implemented without changing P7 identity, ownership or mutation semantics.

## 2.1 P8 compatibility — deterministic preview/diff

P7 mutations MUST be representable as deterministic candidate/change-set data before commit.

For the same:

```text
canonical input state
+ canonical session/version
+ normalized intent
```

the preview candidate MUST be structurally deterministic.

P8 MUST be able to compute:

```text
before
candidate
semantic diff
validation result
```

without mutating canonical state.

P7 therefore MUST NOT hide essential mutation semantics inside imperative UI callbacks.

## 2.2 P9/P10 compatibility — deterministic generators

Apartment/building/residential-complex generators will need to create many structural entities deterministically and atomically.

P7 MUST ensure that generated topology can use exactly the same canonical commands/validators as manual authoring.

Generators MUST NOT require privileged bypass APIs for:

- level creation;
- slab/core ownership;
- cross-level physical transitions;
- dependency validation;
- persistence identity.

## 2.3 P11 compatibility — generalized engineering graph

P7 physical topology MUST be mappable into a generalized engineering graph without reconstructing identity from geometry or UI order.

At minimum, P11 must be able to treat these as stable graph references:

```text
BuildingId
LevelId
SlabId
penetration identity/evidence
VerticalCoreId
RouteId
RouteAnchorId
```

P7 MUST preserve enough typed ownership/adjacency data to derive graph nodes/edges deterministically.

## 2.4 P12 compatibility — multi-discipline starter generation

POWER/LIGHTING/LAN/CCTV/ACS/FIRE starter generation MUST reuse one physical project structure.

P7 MUST NOT encode electrical-system-specific ownership inside generic building/slab/core identities.

Discipline-specific routes MAY reference P7 physical topology, but generic P7 topology MUST remain discipline-neutral.

## 2.5 P13 compatibility — auto-placement

Auto-placement requires deterministic host selection and collision/ownership reasoning.

P7 MUST provide stable host identity and canonical plan coordinates. Auto-placement MUST never need to use transient room/surface/list indexes as durable host identity.

## 2.6 P14 compatibility — auto-routing

Auto-routing will require route graph expansion across levels.

P7 MUST expose physical cross-level transitions as canonical topology with stable IDs and engineering cost/length evidence. P14 MUST NOT infer vertical routing merely from elevation difference.

## 2.7 P15 compatibility — provenance and selective regeneration

P7 entities and mutations MUST be compatible with future provenance metadata.

P7 MUST NOT rely on object recreation as the normal way to update generated structures. Stable identity must survive compatible regeneration.

P15 must later be able to answer:

```text
who/what created this entity?
which generation input produced it?
was it manually modified?
what can be regenerated safely?
what must be preserved?
```

P7 therefore MUST keep canonical mutation deltas explicit enough that provenance can be attached without redesigning the domain model.

## 2.8 P16 compatibility — Drift/SQLite persistence

P7 persistence contracts MUST be storage-engine neutral.

The current serializer/schema is a logical persistence contract, not an excuse to bind identity semantics to JSON/list order.

P16 MUST be able to map P7 entities into normalized relational tables using stable IDs and foreign keys without semantic loss.

P7 MUST therefore avoid:

- identity derived from serialization order;
- hidden cross-entity references known only to UI code;
- untyped polymorphic blobs for core topology where stable columns/relations are required;
- implicit cascade semantics that differ between in-memory and SQL persistence.

## 2.9 P17 compatibility — native qualification

P7 deterministic identity, validation, serialization and engineering calculations MUST be platform-independent.

No P7 invariant may depend on:

- filesystem iteration order;
- platform-specific map/set ordering assumptions;
- locale-dependent numeric/string formatting;
- desktop-only callbacks;
- native-only persistence behaviour.

---

# 3. Frozen scope and non-goals

The following P7A contracts are frozen and MUST NOT be redesigned without a reproduced regression plus a dedicated regression test:

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

This closing branch MUST NOT introduce:

- another boundary identity model;
- another project mutation/history model;
- UI-specific engineering mutation paths;
- temporary durable level-to-level routing shortcuts;
- durable identity derived from indexes, display order or ordinals;
- implicit destructive cascades;
- silent persistence repair of structurally invalid topology;
- rollback of an already committed canonical winner merely because projection/materialization failed afterward.

The following are explicitly outside P7 closure unless required to fix a demonstrated blocker:

- wizard UI or generator UX;
- generation algorithms;
- generalized system graph implementation;
- discipline starter generation;
- auto-placement algorithms;
- pathfinding/auto-routing algorithms;
- provenance engine;
- Drift/SQLite implementation;
- new native packaging work unrelated to qualification;
- redesign of horizontal boundary topology.

---

# 4. Existing canonical foundations

P7 closure builds on existing stable identity types.

At minimum, production already has stable identity classes for:

```text
ProjectId
BuildingId
LevelId
SlabId
VerticalCoreId
RouteId
RouteAnchorId
```

`SlabId` is a building-level physical identity and MUST NOT be treated as a floor/ceiling ordinal, array index, room surface index or display-level pair.

`ProjectVerticalCore` currently owns:

```text
VerticalCoreId id
BuildingId buildingId
VerticalCoreKind kind
Set<LevelId> levelIds
List<BoundaryPointMm> footprint
String? name
```

Therefore:

- `levelIds` is canonical membership, not persisted traversal order;
- vertical traversal order MUST be derived from canonical level topology;
- serialization MAY sort the set for deterministic bytes, but that sort MUST NOT become semantic identity;
- a core MUST span at least two levels;
- its footprint MUST remain a non-degenerate polygon in canonical building-plan coordinates.

---

# 5. Terminology and ownership model

## 5.1 Level

A `LevelId` identifies one canonical building level. Display number/name/elevation are mutable semantics and MUST NOT substitute for identity.

Canonical physical ordering MUST be derived from level topology/elevation semantics that are validated for the building. Equal/ambiguous elevations that make physical traversal indeterminate MUST fail closed for operations requiring an order.

## 5.2 Slab

A `SlabId` identifies one physical horizontal building boundary capable of hosting cross-level penetration evidence.

P7 closure MUST prove that slab ownership/adjacency is canonical and unambiguous before using a slab for cross-level routing.

If a slab representation does not yet carry all required ownership/adjacency data, P7 MUST extend the canonical slab model rather than reconstruct ownership from UI projection.

A slab MUST NOT be identified by `(lowerLevelIndex, upperLevelIndex)` or by floor/ceiling display ordinals.

## 5.3 Penetration

A slab penetration is durable physical evidence that a route crosses a concrete slab host.

If the existing implementation lacks a fully stable standalone penetration identity, P7 MUST introduce or formalize one before final qualification.

A penetration MUST resolve to exactly one canonical slab host and MUST NOT outlive that host.

A penetration host reference MUST survive Save/Reopen without coordinate-based re-identification.

## 5.4 VerticalCore

A `VerticalCoreId` identifies a stable multi-level vertical routing volume owned by one `BuildingId`.

Its `levelIds` are the levels physically covered by the core. For P7 closure, discontinuous core coverage is **not supported**.

Given canonical level order:

```text
L1 < L2 < L3 < L4
```

these are valid/invalid:

```text
{L1, L2}          VALID
{L1, L2, L3}      VALID
{L2, L3, L4}      VALID
{L1, L3}          INVALID
{L1, L2, L4}      INVALID
```

A future explicit bypass/discontinuous-core model MAY relax this, but P7 MUST fail closed until such a typed contract exists.

## 5.5 Vertical route leg

A vertical route leg is canonical engineering route evidence between adjacent physical level transitions. It MUST contribute to engineering length even when hidden from the active 2D projection.

## 5.6 Projection

Editor/legacy/UI materialization is a projection of canonical state. Projection MUST NOT become the source of truth for physical identity, ownership, route length or host selection.

## 5.7 Candidate

A candidate is a pure, non-committed representation of the proposed canonical result. Candidate construction MUST be side-effect free with respect to canonical project state.

## 5.8 Change set

A change set is a semantic delta between canonical before-state and candidate/after-state. It SHOULD be usable by future P8 preview/diff and P15 provenance logic.

---

# 6. Canonical dependency graph

The minimum ownership/dependency graph is:

```text
Project
└── Building
    ├── Level
    ├── Slab
    │   └── Penetration
    └── VerticalCore
        └── covered LevelIds

Canonical Route
└── CrossLevelTransition
    ├── source LevelId
    ├── target LevelId
    ├── SlabId
    ├── Penetration identity/evidence
    ├── VerticalCoreId
    ├── route anchors
    └── physical vertical leg / engineering evidence
```

Every durable reference MUST satisfy all of the following:

```text
target exists
owner exists
target belongs to expected owner
target is active/not retired
target is geometrically/topologically compatible
target is visible to the same canonical session/version
```

The dependency graph MUST be queryable without relying on UI projection so that P15/P16 can later implement selective regeneration and database referential integrity.

---

# 7. Requirement taxonomy

All implementation work MUST be traceable to one or more requirement IDs.

```text
REQ-P7-BASE-*   baseline/CI
REQ-P7-ID-*     stable identity
REQ-P7-DEP-*    dependency/ownership guards
REQ-P7-SLAB-*   slab topology
REQ-P7-CORE-*   VerticalCore topology
REQ-P7-ATOM-*   atomic cross-level continuation
REQ-P7-CONC-*   concurrency/session/version
REQ-P7-HIST-*   Undo/Redo/history
REQ-P7-PERS-*   persistence/Save-Reopen
REQ-P7-GEO-*    geometry/engineering evidence
REQ-P7-DIFF-*   deterministic candidate/change-set
REQ-P7-E2E-*    end-to-end routing
REQ-P7-DEST-*   destructive mutation safety
REQ-P7-AUD-*    slab-bypass/repository audit
REQ-P7-FUT-*    P8-P17 compatibility
REQ-P7-QUAL-*   exact-SHA qualification
REQ-P7-FREEZE-* final freeze
```

Every new regression test SHOULD contain the relevant requirement ID in its name, description or adjacent comment.

---

# 8. Global invariants

## INV-P7-01 Stable identity

Canonical physical identities MUST NOT be derived from list position, display number, floor ordinal, route segment index or UI state.

## INV-P7-02 Slab ownership

Every cross-level slab reference MUST resolve to one active canonical `SlabId` in the expected building topology.

## INV-P7-03 Penetration ownership

Every penetration MUST belong to exactly one existing slab host and MUST be compatible with the route/core transition.

## INV-P7-04 Core ownership

Every `VerticalCoreId` MUST belong to exactly one `BuildingId`.

## INV-P7-05 Core level ownership

Every `LevelId` referenced by a core MUST exist and belong to the same building as the core.

## INV-P7-06 Core continuity

Core membership MUST cover every canonical intermediate level between its lowest and highest covered levels. Gaps fail closed.

## INV-P7-07 Deterministic level order

Physical traversal order MUST be derived from canonical level topology, not `Set` iteration order. Ambiguous physical order MUST fail closed.

## INV-P7-08 Physical evidence

A durable cross-level route MUST NOT exist without resolvable physical transition evidence.

## INV-P7-09 Atomic continuation

One user cross-level continuation is one logical canonical transaction/change set. Pre-commit failure MUST leave canonical state unchanged.

## INV-P7-10 Canonical winner after commit

After a canonical commit succeeds, later owner/projection/materialization failure MUST NOT be reported as ordinary rejection and MUST NOT revert the canonical winner implicitly.

## INV-P7-11 Stale protection

A stale version/session MUST never overwrite the canonical winner.

## INV-P7-12 Exact session affinity

Vertical authoring/history MUST inherit the frozen P7A exact-session-affinity rules.

## INV-P7-13 Engineering length

Hidden vertical physical distance MUST be part of canonical engineering route length and MUST NOT be inferred solely from the active UI projection.

## INV-P7-14 Save/Reopen identity

Save/Reopen MUST preserve entity IDs and structural relationships without identity regeneration.

## INV-P7-15 Undo/Redo integrity

Undo/Redo MUST restore/reapply the whole logical cross-level operation without partial artifacts.

## INV-P7-16 Destructive integrity

Structural/destructive operations MUST NOT leave dangling physical references.

## INV-P7-17 No slab bypass

Production runtime MUST have zero durable level-switch paths that bypass canonical physical transition resolution.

## INV-P7-18 Fail-closed persistence

Corrupt/inconsistent persisted vertical topology MUST fail closed rather than being silently repaired into a different physical model.

## INV-P7-19 Cross-building prohibition

A single slab/core/cross-level transition MUST NOT bridge unrelated buildings.

## INV-P7-20 Deterministic projection

Given the same canonical state, projection/rematerialization MUST not invent new physical identity or alter engineering evidence.

## INV-P7-21 Pure previewability

A complete candidate for a vertical mutation MUST be constructible without mutating canonical state.

## INV-P7-22 Semantic diffability

The logical mutation MUST be expressible as a stable semantic change set suitable for preview/diff and later provenance attachment.

## INV-P7-23 Generator parity

Programmatic generation and manual authoring MUST pass through equivalent canonical invariants; no generator-only bypass may be required.

## INV-P7-24 Storage neutrality

Canonical identity and ownership semantics MUST remain valid when mapped from in-memory/serialized representation to Drift/SQLite relational persistence.

## INV-P7-25 Discipline neutrality

Generic building/slab/core topology MUST not depend on POWER/LIGHTING/LAN/CCTV/ACS/FIRE-specific semantics.

## INV-P7-26 Platform determinism

Validation, candidate construction, topology ordering and engineering evidence MUST not depend on platform-specific iteration or locale behaviour.

---

# 9. Mutation protocol

All vertical mutations MUST use one canonical protocol compatible with frozen P7A ownership/history semantics.

Required phase order:

```text
1. Capture canonical session + observed version
2. Normalize intent
3. Resolve source topology from canonical state
4. Resolve target topology from canonical state
5. Build complete candidate graph
6. Build semantic change set
7. Preflight dependency ownership
8. Preflight geometry/topology
9. Preflight destructive/conflict guards
10. Revalidate exact session + observed version
11. Perform one canonical commit
12. Invoke persistence owner / authoritative external owner boundary
13. Register/confirm history according to canonical owner protocol
14. Rematerialize projections from canonical winner
15. Return typed outcome
```

The implementation MAY internally use several pure builders/validators, but MUST expose only one logical commit boundary for one continuation intent.

Candidate/change-set construction MUST be reusable by future P8 preview and P15 provenance without invoking the commit step.

---

# 10. Deterministic candidate and diff contract

For equivalent canonical input and normalized intent:

```text
candidate(A) == candidate(B)
semanticDiff(A) == semanticDiff(B)
```

where equality is semantic, not object-instance identity.

Determinism MUST cover:

- selected slab/core host;
- created/updated physical references;
- route transition order;
- engineering-length delta;
- dependency delta;
- validation result;
- affected canonical IDs.

If new IDs are needed during preview, the architecture MUST use one of these explicit strategies:

1. reserve deterministic/provisional IDs that become committed IDs; or
2. represent creation slots symbolically and allocate stable IDs only at commit while preserving semantic diff equivalence.

P7 MUST NOT let P8 preview allocate durable entities as a side effect.

---

# 11. Failure taxonomy

P7 MUST explicitly distinguish failures by commit phase.

## 11.1 Pre-commit rejection

Examples:

- missing slab/core/level;
- incompatible building;
- geometric incompatibility;
- discontinuous core;
- ambiguous level order;
- stale version detected before commit;
- invalid candidate;
- blocked destructive dependency.

Contract:

```text
canonical state before == canonical state after
canonical version unchanged
history unchanged
no orphan physical artifacts
```

Expected invalid user/domain input SHOULD return typed rejection/result semantics rather than generic exceptions.

## 11.2 Canonical commit conflict

If session/version changes during commit acquisition/validation, the operation MUST fail closed as a stale/conflict outcome. It MUST NOT rebase silently onto the newer winner.

## 11.3 Post-commit owner failure

If canonical commit succeeded but persistence-owner acknowledgement fails:

- canonical winner remains authoritative;
- the outcome MUST identify that commit already happened;
- it MUST NOT be reported as ordinary validation rejection;
- history/session state MUST follow the existing P7A owner-failure contract;
- obsolete projections MUST NOT overwrite the winner.

## 11.4 Post-commit projection/materialization failure

If canonical commit and owner boundary succeeded but projection/materialization fails:

- canonical winner remains authoritative;
- no rollback to stale projection is allowed;
- retry/rematerialization MUST read from the canonical winner;
- the outcome MUST be distinguishable from a pre-commit rejection.

---

# 12. Typed result/error contract

Expected domain rejections SHOULD be represented with typed codes/results capable of carrying relevant identity.

Minimum semantic categories:

```text
missingBuilding
missingLevel
missingSlab
missingPenetration
missingVerticalCore
foreignBuildingReference
discontinuousVerticalCore
ambiguousLevelOrder
invalidPhysicalTransition
dependencyBlocked
staleVersion
sessionMismatch
committedOwnerFailure
committedProjectionFailure
corruptPersistence
```

A destructive dependency rejection MUST expose enough data for UX/tests to identify:

```text
target entity id
target entity type
blocking dependency type
blocking dependency id(s)
reason code
```

Exact class/type names MAY differ, but semantic distinguishability is mandatory.

---

# 13. P7 closure sequence

Implementation/qualification order:

```text
P7-C1  baseline / current CI
   -> P7-C2  canonical slab contract qualification
   -> P7-C3  VerticalCore dependency + continuity guards
   -> P7-C4  deterministic candidate/change-set path
   -> P7-C5  atomic cross-level continuation
   -> P7-C6  stale/session concurrency qualification
   -> P7-C7  Save/Reopen persistence qualification
   -> P7-C8  3-level E2E + reverse routing
   -> P7-C9  destructive-operation adversarial matrix
   -> P7-C10 slab-bypass repository audit
   -> P7-C11 P8-P17 compatibility audit
   -> P7-C12 exact-SHA Flutter + macOS qualification
   -> P7-C13 final freeze
```

A stage may be developed in parallel, but it MUST NOT be marked closed before all preceding dependencies required by its proof are closed.

---

# P7-C1 — Baseline / current CI

Mandatory gates:

```text
dart format --output=none --set-exit-if-changed .   PASS
flutter analyze                                      PASS
flutter test                                         PASS
```

CI changes that weaken or bypass these gates are forbidden.

Record exact SHA and workflow evidence.

---

# P7-C2 — Canonical slab contract qualification

P7 MUST establish/verify one canonical slab model sufficient for physical routing.

The qualified slab contract MUST define:

- stable `SlabId`;
- building ownership;
- adjacent/served level semantics where applicable;
- physical host geometry/evidence required for penetration validation;
- active/retired lifecycle semantics;
- persistence representation;
- dependency lookup;
- deterministic ordering/serialization rules that are non-semantic.

Required rejection cases:

```text
missing slab host
foreign building slab
ambiguous level ownership
retired slab reference
penetration hosted by wrong slab
route transition incompatible with slab adjacency
```

If the current production model cannot represent these invariants, P7-C2 MUST extend it before routing qualification continues.

---

# P7-C3 — VerticalCore dependency and continuity guards

Structural mutations MUST fail closed when vertical physical topology depends on the target object.

`RemoveLevel` MUST reject when any active dependency exists unless an explicit typed cascade command exists.

`RemoveBuilding` MUST reject while it still owns levels/slabs/penetrations/cores/routes unless a separately specified aggregate cascade is used.

A core must prove:

- all referenced levels exist;
- all referenced levels belong to the same building;
- core membership contains at least two distinct levels;
- canonical physical order is unambiguous;
- coverage is contiguous in canonical level order;
- footprint remains valid;
- duplicate identity/store-key mismatch is impossible/diagnosed.

Required tests:

```text
remove referenced level                     -> reject
remove referenced building                  -> reject
foreign-building core level                 -> reject
ambiguous level ordering                    -> reject
non-contiguous continuous core              -> reject
valid contiguous core                       -> accept
```

After every structural mutation:

```text
0 dangling LevelId
0 dangling SlabId
0 dangling penetration reference
0 dangling VerticalCoreId
0 dangling route transition references
```

---

# P7-C4 — Deterministic candidate/change-set path

Before canonical mutation, production code MUST be able to construct a full continuation candidate and semantic change set.

Candidate preflight MUST include:

- source/target level resolution;
- slab resolution;
- penetration host/evidence;
- core resolution;
- route transition delta;
- hidden vertical leg/evidence;
- engineering length delta;
- dependency delta;
- exact expected session/version.

Required tests:

```text
preview/candidate does not mutate project
same input -> same semantic candidate
same input -> same validation result
candidate rejected before commit leaves state bit-for-bit/semantically unchanged
candidate exposes all affected canonical identities
```

This stage is the explicit compatibility bridge to P8 and P15.

---

# P7-C5 — Atomic cross-level continuation

One user cross-level continuation MUST be one logical canonical transaction.

Forbidden partial state:

```text
penetration committed, vertical leg missing
vertical leg committed, target continuation missing
route identity updated, engineering evidence missing
slab handoff persisted after downstream pre-commit failure
```

Required pipeline:

```text
intent
 -> normalize
 -> resolve source topology
 -> resolve target topology
 -> build full candidate
 -> build semantic change set
 -> preflight all dependencies
 -> validate geometry
 -> validate expected session/version
 -> single canonical commit
 -> persistence ownership
 -> history registration
 -> projection/materialization
```

Inject failures at least at:

```text
before penetration candidate
before vertical-leg candidate
before canonical commit
stale version at commit boundary
persistence-owner callback
post-commit projection/materialization
```

For every pre-commit failure, assert unchanged:

- route identity;
- route anchors;
- penetration registry;
- vertical core/leg state;
- project version;
- canonical history state.

For post-commit failures, assert canonical winner semantics instead of rollback.

---

# P7-C6 — Stale/session concurrency qualification

Scenario:

```text
Session A reads V10
Session B commits V11
Session A attempts vertical continuation from V10
=> A rejected as stale
=> V11 remains canonical
```

Must preserve exact identity/state:

- route ID;
- route-anchor IDs;
- segment locks;
- mandatory waypoints;
- engineering payload;
- source/target level intent;
- current canonical session identity.

Forbidden recovery:

- reconstructing identity from coordinates;
- allocating replacement anchor IDs;
- inferring old topology from indices;
- silently rebasing stale intent.

Required tests:

```text
stale continuation cannot commit
same-version session replacement is detected
winning project unchanged
no orphan penetration
no orphan vertical leg
fresh retry succeeds deterministically
old-session rematerialization blocked
```

---

# P7-C7 — Save/Reopen persistence qualification

The current persistence schema/version used by P7 MUST durably preserve all canonical vertical physical identity and topology needed to reopen the same project state.

Do **not** hard-code a future schema number in this specification. The final freeze MUST record the exact qualified schema version.

Persist at minimum:

- `SlabId` and ownership;
- source/target level affinity;
- penetration identity/evidence and host affinity;
- `VerticalCoreId`, building affinity and level membership;
- canonical cross-level route transitions;
- hidden vertical route legs or equivalent canonical evidence;
- engineering evidence;
- stable route-anchor identity.

Save MUST fail closed for:

```text
unknown LevelId
unknown SlabId
unknown penetration host/reference
unknown VerticalCoreId
penetration without slab
vertical transition without physical host evidence
cross-building core references
retired/dangling route physical references
ambiguous core traversal order
```

Reopen invariant:

```text
identity before save == identity after reopen
ownership before save == ownership after reopen
engineering evidence before save == after reopen
```

Corruption fixtures MUST include:

```text
missing slab
missing penetration/reference
missing core
foreign level in core
non-contiguous core membership
route transition without host
vertical leg with missing endpoint
cross-building reference
```

All fail closed; partial canonical load is forbidden.

P16 readiness requirement: the logical model MUST be representable with normalized stable-key relations without semantic dependence on JSON/list order.

---

# P7-C8 — Three-level E2E and reverse routing

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

Direction belongs to route traversal, not duplicated physical topology.

Prove:

- stable building/level/slab/penetration/core identities;
- correct route transition order;
- correct hidden vertical length;
- correct total engineering length;
- Save/Reopen identity preservation;
- Undo of logical vertical operation;
- Redo of same operation;
- deterministic candidate/result on repeat.

Engineering invariant:

```text
total canonical route length =
  visible horizontal length
+ hidden vertical physical length
+ other canonical physical segments
```

Additional acceptance cases where the project already models them:

- basement -> ground;
- ground -> upper floor;
- upper floor -> technical floor;
- technical floor -> roof;
- multiple penetrations on one slab;
- multiple cores in one building.

---

# P7-C9 — Destructive-operation adversarial matrix

For each physical entity:

```text
Level
Slab
Penetration
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

Default referenced-entity policy:

```text
REJECT
```

Cascade is allowed only via an explicit typed command whose semantic change set lists the full dependent delta.

No partial cascade may leave a child/reference alive after its owner is removed.

If retired physical identities are tombstoned, identity reuse MUST be forbidden where it can create reopen/history/provenance ambiguity.

P15 readiness requirement: destructive change sets MUST expose enough dependency information for future selective regeneration to distinguish `delete`, `replace`, `preserve` and `blocked`.

---

# P7-C10 — Repository-wide slab-bypass audit

Audit production and test support code for patterns equivalent to:

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

Exit gate:

```text
0 production slab-bypass paths
```

The final freeze record MUST list searched surfaces and justified exceptions.

---

# P7-C11 — P8-P17 compatibility audit

Before freeze, explicitly prove the following.

## P8 — Wizard preview/diff

```text
PASS if mutation candidate can be built without commit
PASS if semantic change set can be rendered before commit
PASS if preview does not allocate hidden durable state
```

## P9/P10 — Generators

```text
PASS if generated structures can use canonical application/domain APIs
PASS if no generator-only identity or validation bypass is required
PASS if batch structural creation can be expressed as deterministic candidate/change sets
```

## P11 — Generalized graph

```text
PASS if physical topology exposes stable IDs + ownership + adjacency
PASS if graph reconstruction does not depend on UI coordinates/index identity
```

## P12 — Discipline starters

```text
PASS if P7 building/slab/core model is discipline-neutral
PASS if multiple engineering disciplines can reference same physical hosts
```

## P13 — Auto-placement

```text
PASS if stable physical hosts are addressable by ID
PASS if canonical coordinates/footprints are available without UI ownership
```

## P14 — Auto-routing

```text
PASS if cross-level transitions form deterministic physical graph edges
PASS if vertical engineering cost/length is canonical
```

## P15 — Provenance/selective regeneration

```text
PASS if stable identities survive compatible updates
PASS if semantic change sets enumerate affected identities/dependencies
PASS if no normal mutation requires destroy-and-recreate identity
```

## P16 — Drift/SQLite

```text
PASS if ownership can map to stable PK/FK relationships
PASS if no semantic relation depends on serialized array order
PASS if delete policy is explicit enough for SQL referential integrity
```

## P17 — Native qualification

```text
PASS if candidate/validation/serialization results are platform deterministic
PASS if no P7 contract depends on locale/filesystem/set iteration order
```

Any FAIL here is a P7 closure blocker if fixing it later would require breaking a frozen P7 identity/ownership/mutation contract.

---

# P7-C12 — Exact-SHA Flutter + macOS qualification

Qualification is valid only for one immutable production SHA after P7-C1..P7-C11 are complete.

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

Qualification evidence MUST include:

- canonical slab contract;
- VerticalCore guards;
- deterministic candidate/change-set;
- cross-level atomicity;
- stale/session handling;
- Save/Reopen;
- three-level forward routing;
- reverse routing;
- destructive-operation matrix;
- Undo/Redo;
- corrupt persistence fixtures;
- slab-bypass audit;
- P8-P17 compatibility audit.

A retry-until-green run, skipped mandatory test, temporary exclusion or known flaky mandatory suite does not qualify the SHA.

---

# P7-C13 — Final freeze

Create:

```text
docs/architecture/p7-final-freeze.md
```

The final freeze document MUST record:

- branch;
- exact qualified production SHA;
- Flutter workflow ID;
- macOS workflow ID;
- canonical vertical architecture;
- physical identity set;
- exact qualified persistence schema version;
- atomicity/failure contract;
- deterministic candidate/change-set contract;
- dependency/removal contract;
- Undo/Redo contract;
- Save/Reopen contract;
- slab-bypass audit result;
- P8-P17 compatibility audit result;
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
4. an explicit compatibility decision covering P8-P17;
5. a new exact-SHA qualification.

---

# 14. Minimum mandatory test matrix

```text
Stable identity
  SlabId survives mutation/save/reopen
  VerticalCoreId survives mutation/save/reopen
  RouteAnchorId survives continuation/save/reopen

VerticalCore
  valid contiguous levels
  missing level
  foreign-building level
  ambiguous level order
  continuous-core physical gap

Slab/penetration
  valid host
  missing host
  foreign host
  retired host
  incompatible adjacency

Candidate/diff
  preview is side-effect free
  deterministic candidate
  deterministic semantic diff
  all affected IDs enumerated

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
  valid current-schema reopen
  malformed slab reference
  malformed penetration reference
  malformed core membership
  non-contiguous core membership
  malformed route physical reference
  cross-building corruption

Destructive operations
  Level
  Slab
  Penetration
  VerticalCore
  Building
  referenced/unreferenced/stale/reopened variants

Concurrency/session
  stale version
  same-version session replacement
  old-session rematerialization
  post-commit owner failure
  post-commit projection failure

Future compatibility
  P8 preview without commit
  generator API parity
  graph reconstructability
  discipline neutrality
  stable host addressability
  auto-routing physical edge readiness
  provenance/change-set readiness
  SQL PK/FK mapping readiness
  platform deterministic behavior
```

Tests are evidence for invariants. Passing tests alone do not close P7 if production code still has an architectural bypass.

---

# 15. Review findings incorporated into this specification

The technical review identified and corrected the following specification defects/ambiguities.

## FIND-P7-01 — Post-commit rollback wording was unsafe

A specification that requires rollback after a successful canonical commit contradicts frozen P7A owner/session semantics.

Resolution:

```text
pre-commit failure  -> unchanged canonical state
post-commit failure -> canonical winner remains authoritative
```

## FIND-P7-02 — `VerticalCore.levelIds` is a Set, not an ordered identity list

Persisted/semantic traversal order MUST NOT be inferred from set iteration.

Resolution: physical order is derived from canonical level topology; deterministic serialization ordering remains non-semantic.

## FIND-P7-03 — Core continuity needed a hard closure decision

The previous wording allowed ambiguity around `L1 + L3` coverage.

Resolution: P7 supports continuous core coverage only. Discontinuous/bypass semantics require a future explicit typed model.

## FIND-P7-04 — Slab identity existed but slab contract qualification was underspecified

`SlabId` already exists as stable identity. P7 does not need to invent the ID type; it must close canonical slab ownership/adjacency/penetration/persistence semantics around it.

## FIND-P7-05 — Hard-coded persistence schema version was brittle

A closure specification must qualify the current actual schema version, not prescribe an arbitrary future number.

Resolution: final freeze records the exact qualified schema version.

## FIND-P7-06 — Preview/diff was missing

Without pure candidate/change-set semantics, P8 wizard preview would force duplicated mutation logic.

Resolution: deterministic candidate + semantic change set are now P7 closure requirements.

## FIND-P7-07 — Provenance/regeneration compatibility was missing

Destroy/recreate identity patterns would undermine P15.

Resolution: stable identity across compatible updates and explicit affected-ID/dependency deltas are required.

## FIND-P7-08 — Generalized graph and auto-routing compatibility were implicit

P11/P14 need stable physical graph edges, not inferred level jumps.

Resolution: slab/core/penetration/route physical evidence must be graph-reconstructable by ID.

## FIND-P7-09 — P16 relational persistence compatibility was implicit

List-order or UI-only ownership would make Drift/SQLite migration destructive.

Resolution: storage-neutral PK/FK-ready ownership is required.

## FIND-P7-10 — Platform determinism was not explicit

P17 cannot qualify architecture that depends on Set/Map iteration, locale or desktop-only behaviour.

Resolution: platform determinism is now a final invariant and compatibility gate.

---

# 16. Final closure checklist

```text
[ ] current HEAD baseline green
[ ] canonical slab ownership/adjacency qualified
[ ] penetration identity/evidence qualified
[ ] VerticalCore continuity enforced
[ ] ambiguous level order fails closed
[ ] structural dependency guards closed
[ ] pure deterministic candidate path exists
[ ] semantic change set exists
[ ] cross-level continuation atomic pre-commit
[ ] post-commit failure semantics match P7A freeze
[ ] stale/session race tests pass
[ ] Save/Reopen preserves exact physical identities
[ ] corrupt vertical persistence fails closed
[ ] L1 -> L2 -> L3 E2E passes
[ ] L3 -> L2 -> L1 E2E passes
[ ] hidden vertical length is canonical engineering evidence
[ ] Undo/Redo restores whole logical transition
[ ] destructive-operation matrix passes
[ ] repository-wide slab-bypass audit = 0 production bypasses
[ ] P8 preview/diff compatibility PASS
[ ] P9/P10 generator compatibility PASS
[ ] P11 graph compatibility PASS
[ ] P12 discipline-neutral topology PASS
[ ] P13 host/placement compatibility PASS
[ ] P14 routing topology compatibility PASS
[ ] P15 provenance/selective-regeneration compatibility PASS
[ ] P16 Drift/SQLite mapping compatibility PASS
[ ] P17 platform determinism compatibility PASS
[ ] exact-SHA Flutter workflow green
[ ] exact-SHA macOS workflow green
[ ] p7-final-freeze.md published
```

Only after every mandatory item is closed may the branch declare:

```text
P7 = FROZEN + HARDENED + QUALIFIED
```
