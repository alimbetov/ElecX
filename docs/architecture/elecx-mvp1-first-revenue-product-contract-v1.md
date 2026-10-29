# ElecX MVP-1 First Revenue Product Contract v1

Status: **AUTHORITATIVE PRODUCT / MVP CONTRACT**

This document defines the shortest acceptable path from the current ElecX architecture to the first professionally usable, paid-value MVP.

It does not replace the authoritative P0..P17 architecture roadmap. It constrains delivery order inside that roadmap so product breadth does not outrun one complete professional end-to-end workflow.

Related authoritative documents:

- `docs/architecture/elecx-generate-refine-roadmap-principle-v1.md`
- `docs/architecture/project-composition-foundation-decisions-v1.md`
- `docs/architecture/elecx-p9-p17-execution-roadmap-v1.md`

## 1. Commercial objective

The first commercial objective is not maximum feature count.

The first commercial objective is to deliver one professional workflow that is complete enough that an engineer can use its output in real work and justify paying for it.

The MVP-1 product target is therefore:

```text
Apartment
  -> POWER engineering
  -> board
  -> circuits
  -> protection
  -> cables
  -> placement
  -> routing
  -> calculations
  -> decision evidence
  -> BOM / schedules
  -> drawings / PDF
  -> engineer edit
  -> impact analysis
  -> selective recalculation
  -> automatically updated deliverables
```

MVP-1 success is judged by professional usefulness and paid value, not only by internal architectural completion.

## 2. Product North Star

The MVP-1 North Star is:

```text
GENERATE A USEFUL PROFESSIONAL BASELINE
              ↓
EXPLAIN EVERY MATERIAL ENGINEERING DECISION
              ↓
ENGINEER ACCEPTS / REJECTS / REFINES
              ↓
DEPENDENCIES PROPAGATE
              ↓
ONLY IMPACTED ENGINEERING STATE IS RECALCULATED
              ↓
MANUAL DECISIONS ARE PRESERVED
              ↓
PROFESSIONAL DELIVERABLES UPDATE DETERMINISTICALLY
```

The engineer remains authoritative.

ElecX recommends, explains, previews and maintains consistency. It must not silently override deliberate professional decisions.

## 3. PI-01 — Golden Vertical Slice Gate

ElecX SHALL qualify one complete professional POWER workflow end-to-end before broad production expansion into additional engineering disciplines.

The mandatory first vertical slice is:

```text
Apartment
→ POWER
→ Board
→ Circuits
→ Protection
→ Cables
→ Placement
→ Routing
→ Calculations
→ Decision Evidence
→ BOM
→ Professional Deliverables
→ Engineer Edit
→ Impact Analysis
→ Selective Regeneration
→ Updated Deliverables
```

LIGHTING, LAN, CCTV, ACS and FIRE may prototype early, but they MUST NOT displace completion of the POWER Golden Journey as the primary product-delivery priority.

A broad set of half-complete discipline generators does not satisfy MVP-1.

## 4. PI-02 — Engineering Decision Evidence

Every generated engineering decision affecting safety, compliance, sizing, protection, equipment selection, placement or routing MUST be traceable.

At minimum, a material generated decision SHALL expose or persist:

```text
DecisionEvidence
├── decisionId
├── subjectId / generationKey
├── inputs
├── calculations
├── hard constraints
├── engineering constraints
├── normative rules / profile
├── catalog references
├── alternatives considered
├── rejected alternatives + reasons
├── selected alternative
├── selection reason
├── warnings
├── PASS / FAIL / INDETERMINATE result where applicable
├── catalog version
├── normative profile version
└── algorithm / generator version
```

A result such as:

```text
Cable = 3x2.5 mm²
```

is insufficient by itself.

The system must be able to explain why the result was selected, for example from load, design current, route length, protection device, installation conditions, voltage-drop limit, compatibility constraints and normative profile.

`INDETERMINATE` is a first-class result when evidence is insufficient. ElecX MUST NOT fabricate compliance or PASS results.

## 5. PI-03 — Engineer Authority and Manual Work Preservation

Automation proposes and maintains consistency. The engineer remains authoritative.

The system MUST distinguish at least these semantic concepts, even if the exact implementation schema differs:

```text
GENERATED_BASELINE
GENERATED_MODIFIED
MANUAL
MANUAL_OVERRIDE
USER_SUPPRESSED_GENERATED
LOCKED
PROPAGATED
STALE / DIRTY
REQUIRES_REVIEW / CONFLICT
```

Required behavior includes:

- a manually replaced breaker is preserved during regeneration;
- a user-suppressed generated outlet is not silently recreated;
- a locked route is preserved unless the system reports an explicit conflict;
- unrelated engineering state is not regenerated without an explicit dependency;
- generated state remains ordinary editable canonical project state.

## 6. PI-04 — Professional Deliverables Contract

Canonical engineering state alone is not a complete professional product result.

MVP-1 SHALL deterministically generate professional deliverables from canonical project and engineering state.

Minimum POWER deliverables:

```text
1. electrical floor drawing
2. single-line diagram
3. panel schedule
4. circuit schedule
5. cable schedule / cable journal
6. equipment specification
7. BOM
8. calculation report
9. warnings / unresolved / indeterminate issues report
10. PDF package
```

Deliverables are projections of canonical state, not independent manually maintained copies.

Required dependency behavior:

```text
canonical engineering change
        ↓
affected engineering state
        ↓
affected deliverable projections become dirty
        ↓
rebuild only impacted projections
```

Examples:

```text
breaker changed
  -> panel schedule
  -> single-line diagram
  -> BOM
  -> protection calculation evidence

route length changed
  -> cable schedule
  -> cable quantity
  -> voltage-drop calculation
  -> BOM
  -> calculation report
```

## 7. MVP-1 delivery map inside P0..P17

The architecture roadmap remains authoritative, but MVP-1 follows this constrained delivery path:

```text
CURRENT
  ↓
PRE-P10 hardening / remediation
  ↓
PRE-P10 ACCEPTED
  ↓
MVP-A  Structural Host              [P10 subset]
  ↓
MVP-B  Engineering Foundation       [P11 + Catalog + Normative Evidence]
  ↓
MVP-C  POWER Generation             [P12A]
  ↓
MVP-D  POWER Placement              [P13 POWER slice]
  ↓
MVP-E  POWER Routing                [P14 POWER slice]
  ↓
MVP-F  Impact / Selective Regen     [P15 POWER slice]
  ↓
MVP-G  Professional Deliverables
  ↓
MVP-H  Production Persistence       [P16 slice]
  ↓
MVP-I  Native Golden Journey qualification
  ↓
MVP-1 ACCEPTED
```

P17-wide native qualification remains a later full-roadmap phase, but MVP-1 acceptance requires the Golden Journey to be qualified on the initial supported production platform set chosen for release.

## 8. MVP-A — Structural Host scope

MVP-1 does not require the full P10 breadth.

Required:

```text
Project
└── Site
    └── Building
        └── Level
            └── Apartment StructuralZone
                └── Spaces
```

Required semantic/physical foundations include:

- stable typed identities;
- canonical Spaces / SpaceUsage;
- Boundaries / BoundaryEdgeId;
- openings and adjacency;
- editable integer-mm geometry;
- Preview/Diff;
- atomic apply;
- Undo/Redo;
- provenance;
- save/reopen semantic stability.

Optional architecture/service anchors required by POWER may be introduced where needed, such as service entry or distribution-board location candidates.

Deferred from MVP-1:

- full cottage generation;
- tower generation;
- residential-complex generation;
- parking/service-building composition;
- advanced multi-building site generation.

## 9. MVP-B — Engineering Foundation scope

The implementation MUST use generalized `EngineeringGraph` semantics rather than a disposable POWER-only graph.

The first qualified graph slice is POWER:

```text
Source
  ↓
Board
  ↓
Circuit
  ↓
Protection
  ↓
Cable
  ↓
Load / Device
```

The graph must preserve separation between logical engineering topology and physical routing.

Initial relations may include typed concepts such as:

```text
suppliedBy
protectedBy
connectedTo
memberOf
feeds
hostedBy
routedBy
```

The Equipment Catalog MVP must support the minimum typed identities and technical data required for deterministic POWER selection and compatibility checks.

Initial product families may include:

```text
boards
MCB
RCD / RCBO
cables
outlets / sockets
basic residential electrical devices
```

Live prices, marketplace integration and broad manufacturer ingestion are not MVP-1 blockers.

## 10. Normative / Constraint Evidence scope

MVP-1 requires at least one explicit versioned residential engineering profile.

The rule/evidence model must support:

```text
RuleId
profile / jurisdiction
source + revision
applicability
input evidence
PASS / FAIL / INDETERMINATE
explanation
```

The initial profile may be a KZ-oriented residential profile aligned with the selected standards basis, provided every implemented rule has explicit source/version/evidence semantics.

Unknown or insufficient information MUST remain explicit.

## 11. MVP-C — POWER Generation scope

Inputs include:

```text
Apartment
Spaces
SpaceUsage
geometry
supply parameters
engineering profile
Equipment Catalog snapshot/version
normative/constraint profile
manual/locked state
```

MVP-1 POWER generation must be able to produce or propose at least:

```text
electrical loads
load groups
board
circuits
protection intent / device selection
cable requirement / cable selection
```

Minimum calculations/validation include, where applicable and sufficiently evidenced:

```text
connected load
design load
design current
demand/diversity
protection rating
cable ampacity
cable cross-section
voltage drop
basic compatibility
```

Every material result participates in Decision Evidence.

## 12. MVP-D — POWER Placement scope

MVP-1 placement must support enough physical component placement to complete the residential POWER Golden Journey.

Initial classes may include:

```text
distribution board
socket / outlet
electrical connection point
required service device
```

Placement must be host-aware, constraint-aware, deterministic for the same inputs/versions and explainable.

Screen coordinates are never canonical engineering authority.

## 13. MVP-E — POWER Routing scope

The first routing slice covers apartment POWER routes from distribution board/circuit anchors to relevant devices through supported physical hosts/channels.

A route candidate must be able to carry at least:

```text
stable identity
source / target anchors
physical geometry
length
host transitions
penetrations where supported
constraint evidence
ranking / reason
manual waypoints / lock state where supported
```

Routing must not replace logical EngineeringGraph relationships.

## 14. MVP-F — mandatory impact / regeneration scenarios

MVP-1 SHALL NOT be accepted unless at least these professional-edit scenarios pass:

### SC-01 — Move distribution board

```text
move DB
→ affected routes change
→ cable lengths change
→ voltage drop recalculates
→ cable validity re-evaluates where required
→ BOM and affected schedules update
```

### SC-02 — Manual breaker replacement

```text
replace generated breaker manually
→ manual selection is preserved
→ compatibility/protection is revalidated
→ regeneration cannot silently restore the old generated breaker
```

### SC-03 — Suppress generated outlet

```text
delete/suppress generated outlet
→ suppression is recorded
→ regeneration does not silently recreate it
```

### SC-04 — Move wall / host geometry

```text
move wall
→ hosted device follows stable host where valid
→ affected route is recalculated
→ unrelated circuits remain untouched
```

### SC-05 — Lock route

```text
lock route
→ later regeneration preserves route
→ if the route becomes invalid, ElecX reports an explicit conflict/review state
```

## 15. MVP-H — Production persistence scope

MVP-1 requires durable production persistence, not only an in-memory/demo workflow.

Target architecture remains:

```text
Application / Domain
        ↓
ProjectRepository
        ↓
DriftProjectRepository
        ↓
SQLite
```

Persisted semantics must include what is required to restore the professional project, including:

```text
project hierarchy
geometry/topology
EngineeringGraph
equipment selections
routes
calculation/normative evidence
provenance
manual overrides
suppressions
locks
dirty/review state
state required to regenerate deliverable projections
```

Mandatory lifecycle qualification:

```text
Generate
→ Edit
→ Selective Regenerate
→ Save
→ Close
→ Reopen
→ same semantic engineering project
```

No accepted manual decision may disappear across persistence boundaries.

## 16. MVP-1 Definition of Done

MVP-1 is accepted only when an engineer can complete the following Golden Journey:

```text
1. create/open project
2. create or select apartment topology
3. enter trusted baseline parameters
4. obtain editable apartment baseline
5. generate POWER baseline
6. obtain board
7. obtain circuits/groups
8. obtain protection selections
9. obtain cable selections
10. inspect explanations/evidence for material engineering decisions
11. obtain supported automatic placement
12. obtain supported routes
13. inspect calculations, warnings and indeterminate results
14. manually edit the engineering project
15. preview impact
16. selectively recalculate only affected dependencies
17. preserve manual overrides, suppressions and locks
18. generate professional deliverables
19. save project
20. close application
21. reopen project
22. recover the same semantic engineering state and accepted manual decisions
23. regenerate equivalent professional deliverables
```

Required deliverable set at acceptance:

```text
electrical drawing
single-line diagram
panel schedule
circuit schedule
cable schedule / journal
equipment specification
BOM
calculation report
warnings / unresolved issues
PDF package
```

## 17. First Revenue Gate

Technical MVP acceptance and commercial validation are separate but connected gates.

### MVP-1 Technical Gate

All mandatory Golden Journey behavior above is qualified on exact accepted SHA(s).

### First Paid Value Gate

At least one real target user can complete or materially use the Golden Journey output for a real residential POWER project without requiring ElecX developers to manually reconstruct the engineering result outside the product.

### First Revenue milestone

The product reaches the first-revenue milestone when a real customer pays for access, a project, a subscription or another legitimate commercial use of the accepted MVP-1 workflow.

Revenue is not the same as accounting profit. Profitability is a later business metric, but first revenue is the earliest objective proof that the product has paid value.

## 18. Explicit MVP-1 non-goals

The following must not block first paid value unless a later product decision explicitly promotes one into MVP scope:

```text
full cottage generator
residential tower generator
residential complex / full multi-building generator
full LIGHTING automation
LAN automation
CCTV automation
ACS automation
FIRE automation
PV / generator / UPS / battery / ATS optimization
advanced industrial cable trays
complex vertical/campus/site routing
cloud collaboration
remote multi-user synchronization
full manufacturer marketplace
live supplier pricing
DWG / IFC / BIM interoperability
broad international normative-profile coverage
```

The architecture may remain ready for these capabilities, but MVP-1 execution must not be delayed by them.

## 19. Scope-control decision rule

When a proposed feature competes with completion of the Golden Vertical Slice, prefer the work that reduces the distance to:

```text
Apartment
→ valid POWER engineering
→ explainable decisions
→ editable result
→ selective recalculation
→ professional deliverables
→ paid user value
```

unless the proposed work fixes a P0/security/data-corruption/irreversible-loss issue or is a mandatory upstream dependency.

This rule is specifically intended to prevent feature diffusion.

## 20. Product acceptance statement

ElecX MVP-1 is not a collection of partially implemented CAD, calculation and automation features.

It is one complete professional residential POWER workflow in which:

```text
ElecX generates.
ElecX explains.
The engineer decides.
Manual work survives.
Dependencies propagate.
Only affected state is recalculated.
Professional documentation follows canonical engineering state.
The project survives Save / Close / Reopen.
The result is useful enough to sell.
```

That is the product boundary for the first paid-value milestone.
