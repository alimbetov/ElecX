# ElecX Generate → Refine → Propagate Product Roadmap Principle v1

Status: **AUTHORITATIVE PRODUCT / ROADMAP PRINCIPLE**

This document does not replace the authoritative `P0..P17` implementation order in `project-composition-foundation-decisions-v1.md`. It defines the product outcome that each phase must serve.

## 1. Core product invariant

```text
GENERATE FIRST
      ↓
ENGINEER REFINES
      ↓
DEPENDENCIES PROPAGATE
      ↓
MANUAL DECISIONS ARE PRESERVED
      ↓
ONLY IMPACTED ENGINEERING STATE IS RECALCULATED
```

ElecX is not primarily a faster drawing tool and is not intended to replace the engineer.

The product goal is to generate a technically coherent engineering baseline from a familiar or sufficiently similar topology, then make the remaining professional refinement fast, traceable and safe.

A successful workflow should normally move the engineer rapidly to a useful baseline rather than forcing a blank-sheet start.

## 2. Primary user journey

```text
1. engineer selects a familiar/similar topology
2. engineer enters a small set of trusted baseline parameters
3. ElecX generates architectural/project composition
4. ElecX generates engineering starter state
5. ElecX performs applicable calculations/configuration
6. ElecX proposes placement and routing where supported
7. engineer corrects real dimensions/topology
8. engineer adds/removes/replaces components
9. impact analysis marks only affected engineering state dirty
10. ElecX selectively recalculates/reconciles affected dependencies
11. manual decisions remain authoritative unless explicitly released
12. project remains validation-ready and explainable
```

The generated baseline is an editable starting point, not an immutable wizard artifact.

## 3. Human authority

Automation proposes and maintains consistency. The engineer remains authoritative.

Manual actions may include:

```text
adjust room dimensions
move/resize walls
change wall thickness
add/remove openings
add/remove devices
replace generated equipment
lock a component/route/space from regeneration
change circuit grouping
adjust placement
reroute
accept/reject generated alternatives
```

ElecX MUST distinguish generated state, user-driven overrides and solver-propagated consequences.

## 4. Selective impact principle

A local edit MUST NOT imply unconditional whole-project regeneration.

Required conceptual flow:

```text
canonical change
    ↓
ProjectChangeSet
    ↓
ImpactGraph / dependency analysis
    ↓
affected semantic/engineering nodes
    ↓
selective recalculation / reconciliation
    ↓
validation + diff
```

Examples:

```text
room area changed
  -> lighting/outlet recommendations may become dirty

wall moved
  -> hosted devices follow stable host identity
  -> affected routes/lengths may become dirty

route length changed
  -> cable quantity / voltage-drop checks may become dirty

manual breaker replacement
  -> preserve manual equipment choice
  -> revalidate compatibility instead of silently replacing it
```

Unrelated disciplines/state remain untouched unless an explicit dependency exists.

## 5. P0..P17 alignment

The authoritative roadmap remains:

```text
P0-P8  canonical foundation, structural authoring, stable boundaries,
       Wizard candidate/Preview/Diff semantics

P9     apartment baseline generation 1..10
       -> engineer chooses a familiar/similar apartment topology
       -> result is editable canonical geometry

P10    cottage/building/residential-complex generation
       -> compose larger familiar structures from qualified generators

P11    generalized EngineeringGraph/connectivity
       -> machine-readable dependency backbone for impact analysis

P12    POWER/LIGHTING/LAN/CCTV/ACS/FIRE starter generation
       -> produce the engineering baseline immediately after composition

P13    auto-placement
       -> propose physical component placement using canonical semantics

P14    route topology / auto-routing foundation
       -> derive physical routes from engineering topology and hosts

P15    provenance + selective regeneration
       -> preserve engineer decisions
       -> recompute only affected generated state
       -> resolve conflicts explicitly

P16    production persistence
       -> durable editable project + provenance + dependency state

P17    native cross-platform qualification
       -> same engineering semantics on supported native platforms
```

## 6. P9-specific consequence

P9 is not complete merely because it can draw a plausible apartment.

P9 must produce a baseline that later phases can refine without semantic loss:

```text
stable SpaceId / BoundaryEdgeId materialization
real openings and adjacency
integer-mm editable geometry
semantic SpaceUsage
explicit topology/exposure/access contracts
field-aware provenance handoff
no SVG/display authority
```

P9.4 area fitting remains geometry-agnostic.
P9.6 owns bounded geometry feasibility.
P9.11 materializes ordinary editable canonical state.
P9.12 records generated baselines/overrides for P15.

## 7. Associative geometry consequence

After generation, a room dimension edit is a boundary edit, not replacement of the whole generated apartment.

```text
Move boundary
  -> propagate through coupled geometry according to explicit policy
  -> move stable hosted openings/components with their host
  -> produce candidate/diff
  -> one atomic command
```

The normative details are defined by:

`docs/architecture/p9/v2/05-p9-associative-parametric-editing-forward-contract-v2.md`

## 8. Provenance consequence

State must distinguish at least these concepts even if the final enum/schema differs:

```text
generated baseline
user override
manual entity
user-suppressed generated entity
solver-propagated consequence
locked state
stale/dirty dependent state
requires-review/conflict
```

A generated recommendation removed by the engineer must not silently return during regeneration.
A manually added/replaced component must not be silently removed/replaced.

## 9. Product decision rule

When architectural alternatives compete, prefer the design that best supports:

```text
Generate first.
Engineer refines.
Dependencies propagate.
Manual decisions are preserved.
Only impacted engineering state is recalculated.
```

A design that produces a faster first generation but makes later manual refinement destructive or opaque is rejected.

## 10. Current implementation priority

For the current P9 branch the next work remains:

```text
Wave A
  restore P9.4 pure deterministic area allocator
  establish one production catalog entry point for qualification
  provide deterministic per-draft rejection diagnostics

Wave B
  make P9.6 graph-aware and preserve all semantic geometry constraints
  close 1..10 corpus/access/exposure/appendage blockers

Wave C
  make topology-family/corridor-mode diversity semantically real

Wave D
  harden geometric invariants required by P9.11 and later CAD editing
```

P9.7 ranking is not the main production focus until Wave A/B are green.

## 11. Acceptance statement

ElecX roadmap success is not measured only by how much it can auto-generate.

It is measured by whether an engineer can:

```text
select a close topology
obtain a useful engineering baseline
correct the real project quickly
keep deliberate manual decisions
see propagated consequences
recalculate only impacted state
continue working without rebuilding the project from scratch
```
