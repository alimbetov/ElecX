# P7A-6 Adversarial Hardening and Qualification Plan

Branch: `feat/project-structure-authoring`

## Status

**P7A-6 = STARTED.**

P7A-5 is closed and frozen as `DONE + HARDENED + QUALIFIED` on production-code SHA:

```text
0da97676b11baeaa5dfe92c5357185df058f9a08
```

The purpose of P7A-6 is not to introduce another boundary identity model. It attacks the completed P7A contract under races, interruption, ambiguity, persistence/reopen, long histories, pathological geometry and production-scale load.

A P7A-5 invariant may be changed only when an adversarial test demonstrates a real correctness defect. New capabilities that require new semantic or topology concepts belong to P7B/P7C/P8 unless they are required to preserve an existing P7A invariant.

## Non-negotiable inherited invariants

P7A-6 must preserve:

- durable wall identity is `BoundaryEdgeId`, never `wallIndex`;
- durable hosted ownership is `(SpaceId, BoundaryEdgeId)`;
- one `BoundaryEdgeId` can never be re-parented to another `SpaceId`;
- identity-changing edits use explicit `BoundaryTopologyChangeSet` lineage;
- topology + hosts + wall profiles commit through one canonical P3 mutation boundary;
- stale `expectedVersion` fails before authoritative mutation;
- legacy/P2 state is a materialized projection of canonical state, not a second authority;
- persistence never invents stable identity from legacy ordinals;
- ambiguous host remap fails closed;
- canonical Undo/Redo preserves exact chronological document order;
- persistence ownership acknowledgement is required before a canonical mutation is admitted to unified production history;
- schema-v6 reopen rejects dangling or semantically inconsistent adopted hosted state;
- no platform-specific fork of boundary identity or mutation semantics.

## Hardening slices

### P7A-6.1 — stale-version and concurrent mutation races

Goal: prove that no stale editor/session can commit against a newer canonical project.

Required scenarios:

1. begin split at version `N`, commit unrelated P3 mutation to `N+1`, then attempt split commit;
2. begin merge at `N`, mutate hosted registry at `N+1`, then attempt merge;
3. two independent topology sessions start at the same version; only the first commit may succeed;
4. stale legacy wall ordinal after version transition must resolve through a fresh canonical projection or fail closed;
5. stale Undo/Redo replay owner or canonical-session affinity must invalidate unsafe history;
6. stale adoption session must not overwrite already-adopted canonical hosts;
7. owner acknowledgement failure must not expose an unsafe Undo entry.

Exit gate:

```text
No stale path mutates ProjectMutationSession.current.
No stale path leaves a second authoritative legacy state.
No failed stale path increments canonical version or undo depth.
```

### P7A-6.2 — hosted-object remap ambiguity matrix

Goal: exhaustively exercise split/merge/create/remove lineage against all supported hosted geometries.

Matrix dimensions:

- object kind: opening / component / cable endpoint / route anchor;
- geometry: point / interval;
- traversal: forward / reverse;
- location: before split / exactly on split / after split / crossing split;
- topology: axis-aligned / diagonal / long edge / minimal valid edge;
- profile: implicit / rectangle / shaped profile;
- route: one segment / multi-segment / locked / mandatory waypoint.

Required outcomes:

- point host selects exactly one result edge;
- exact ambiguity fails closed;
- interval crossing result edges fails closed unless a domain-specific lossless transform exists;
- reverse route traversal preserves anchor identity and ordering;
- wall-profile transformation remains geometrically lossless;
- unrelated spaces remain byte/semantic equivalent after the operation.

### P7A-6.3 — interruption and lifecycle hardening

Goal: prove correct behavior when an edit is interrupted at every lifecycle boundary.

Required interruption points:

```text
begin
preview
validation
canonical commit
persistence owner acknowledgement
legacy/P2 rematerialization
save
close
reopen
undo
redo
```

Scenarios must cover:

- Escape/cancel before commit;
- navigation to another room/building during preview;
- screen/controller disposal during preview;
- close/reopen after successful identity change;
- persistence-owner exception after in-memory commit;
- rematerialization failure after canonical commit;
- repeated Undo/Redo after reopen;
- app resume with a retired selected `BoundaryEdgeId`.

Exit gate: every interruption has one explicit authoritative state and no hidden partial topology/host mutation.

### P7A-6.4 — shared-boundary and cross-room adversarial semantics

Goal: prove isolation today and define a hard boundary for future shared-wall topology.

P7A currently owns per-space exterior loops. It must not silently infer shared-wall ownership between rooms.

Required tests:

- geometrically coincident edges in two spaces have independent stable identities;
- split/merge in Space A cannot mutate Space B topology, hosts or profiles;
- a foreign `BoundaryEdgeId` cannot be injected through lineage, hosted registry or persistence;
- room adjacency/opening semantics cannot accidentally authorize boundary re-parenting;
- shared/internal-wall editing that requires coordinated topology remains fail-closed until an explicit later-stage contract exists.

Any implementation that introduces a true shared physical wall entity is out of P7A-6 scope and must be designed explicitly in a later stage rather than inferred from coincident geometry.

### P7A-6.5 — unified P2/P3 chronology stress

Goal: qualify the production document journal under long mixed command sequences.

Minimum deterministic sequence:

```text
P3 topology edit
P2 component edit
P3 host adoption/split
P2 cable route edit
P3 Project North/semantic edit
P2 group transform
P3 merge
undo x7
redo x7
```

Assertions:

- exact chronological order;
- one visible document history, not competing P2/P3 stacks;
- canonical version monotonicity;
- P2 mutation revision remains coherent through canonical projection;
- no duplicate legacy architecture entries from rematerialization;
- owner callback runs for every replayed canonical transition;
- a replay ownership failure invalidates the unsafe timeline fail-closed.

### P7A-6.6 — persistence/reopen qualification

Required cycles:

```text
adopt -> save -> reopen
split -> save -> reopen
merge -> save -> reopen
split -> undo -> save -> reopen
split -> undo -> redo -> save -> reopen
mixed P2/P3 history -> save -> reopen
```

Corruption tests must include:

- missing active edge identity ledger entry;
- historical owner mismatch;
- hosted reference to inactive edge;
- cross-space hosted reference;
- out-of-range point/interval offsets;
- orphan hosted opening;
- missing required opening host in adopted space;
- incompatible wall profile;
- malformed lineage-derived topology;
- future unsupported schema.

All corruption paths must fail closed with a persistence-domain diagnostic, normally `FormatException` at the codec boundary.

### P7A-6.7 — pathological geometry and scale

Correctness corpus:

- very large coordinate values within supported integer range;
- long thin rooms;
- high edge-count irregular simple polygons;
- concave polygons;
- many short but valid edges near the 300 mm guard;
- diagonal primitive lattice edges;
- repeated split/merge sequences;
- near-collinear but non-collinear merge candidates;
- self-intersection candidates;
- zero-area/degenerate candidates.

No algorithm may silently change identity semantics or use screen-space tolerance as canonical geometry truth.

### P7A-6.8 — performance and memory qualification

P7A-6 adds measurement, not semantic shortcuts.

Measure at minimum:

- fresh `BoundaryEdgeId <-> ordinal` projection rebuild;
- host-registry capture/validation;
- split/merge remap cost;
- route-anchor rehydration;
- legacy/P2 rematerialization;
- schema-v6 encode/decode;
- mixed document Undo/Redo;
- large irregular polygon validation.

Target test profiles:

```text
S:  10 spaces,   <= 8 edges/space,   <= 100 hosted refs
M: 100 spaces,  <= 20 edges/space,   <= 2,000 hosted refs
L: 500 spaces,  <= 40 edges/space,   <= 20,000 hosted refs
```

Initial P7A-6 gate is regression-oriented: detect pathological super-linear behavior, excessive allocation/rebuild churn and UI-blocking synchronous work. Hard numeric budgets should be recorded only after repeatable CI/local profiling data exists.

### P7A-6.9 — accessibility and production input parity

Identity-changing commands must retain one engineering mutation path for:

- toolbar mouse/touch;
- keyboard;
- future stylus/mobile adapters.

Qualification must ensure:

- disabled/fail-closed operations are represented consistently;
- keyboard does not bypass an unavailable toolbar operation;
- focus traversal is not stolen by CAD shortcuts;
- failure feedback does not claim an operation was rejected when canonical state actually committed;
- transient wall labels remain presentation-only.

### P7A-6.10 — final qualification and closure

P7A-6 is complete only when the exact production SHA passes:

```text
Dart format gate                 PASS
flutter analyze                  PASS
flutter full test                PASS
P7A-6 adversarial test matrix    PASS
macOS analyze                    PASS
macOS full test                  PASS
macOS debug build                PASS
runtime path_provider smoke      PASS
```

Additional closure evidence:

- no open P0/P1 correctness defect in P7A scope;
- all discovered P7A-6 defects have regression tests;
- closure document records exact production-code SHA and workflow run IDs;
- general P7A implementation status is updated to `DONE + HARDENED + QUALIFIED` or explicitly lists any remaining deferred non-P7A blocker;
- later-stage work is separated into P7B/P7C/P8 rather than hidden inside P7A-6.

## Execution order

```text
P7A-6.1 races
   -> P7A-6.2 remap ambiguity
   -> P7A-6.3 lifecycle interruption
   -> P7A-6.4 cross-room isolation
   -> P7A-6.5 mixed history stress
   -> P7A-6.6 persistence/reopen
   -> P7A-6.7 pathological geometry
   -> P7A-6.8 performance/memory
   -> P7A-6.9 input/accessibility parity
   -> P7A-6.10 final qualification
```

Correctness gates precede performance work. No performance optimization may weaken fail-closed identity, lineage, ownership or persistence validation.

## First implementation target

Start with **P7A-6.1 stale-version and concurrent mutation races**.

The first test pack should prove that split, merge and host adoption begun at version `N` cannot commit after an unrelated canonical transition to `N+1`, and that failures leave version, canonical state, hosted registries and undo depth unchanged except for the unrelated committed transition itself.
