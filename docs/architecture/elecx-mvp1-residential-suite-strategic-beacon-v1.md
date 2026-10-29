# ElecX MVP-1 Residential Engineering Suite Strategic Beacon v1

Status: **AUTHORITATIVE STRATEGIC PRODUCT BEACON**

This document defines the intended product breadth for the first-revenue ElecX MVP while preserving the staged implementation and qualification discipline of the existing P0..P17 roadmap and `elecx-mvp1-first-revenue-product-contract-v1.md`.

It is a product-direction constraint, not permission to implement six disconnected or half-complete discipline engines.

## 1. Strategic product target

The first-revenue product target is a complete residential engineering workflow for an apartment:

```text
Apartment
   ↓
POWER + LIGHTING + LAN + CCTV + ACS + FIRE
   ↓
Explainable Engineering
   ↓
Placement
   ↓
Routing
   ↓
Cross-Discipline Dependencies
   ↓
Engineer Refinement
   ↓
Impact Analysis
   ↓
Selective Regeneration
   ↓
Professional Deliverables
   ↓
FIRST PAID VALUE
```

The commercial product should therefore be positioned as an integrated residential engineering suite rather than a POWER-only calculator or generator.

## 2. Golden Vertical Slice interpretation

The Golden Vertical Slice remains one end-to-end workflow, not six unrelated products.

The mandatory discipline set for the residential suite target is:

```text
POWER
LIGHTING
LAN
CCTV
ACS
FIRE
```

All six disciplines must use the same canonical project, generalized `EngineeringGraph`, Equipment Catalog, constraint/evidence model, placement/routing foundations, impact semantics, provenance model and deliverables pipeline.

The implementation must avoid discipline-specific architectural forks where generalized contracts are sufficient.

## 3. Reference-discipline rule

POWER remains the **reference discipline** used to establish and deeply qualify the reusable engineering pipeline.

POWER must prove the full lifecycle first:

```text
requirements
→ engineering graph
→ equipment selection
→ placement
→ routing
→ calculations
→ decision evidence
→ engineer edit
→ impact analysis
→ selective regeneration
→ deliverables
→ persistence
```

The other disciplines are added sequentially onto the same architecture rather than developed as independent parallel engines.

Recommended discipline qualification order:

```text
POWER
  ↓
LIGHTING
  ↓
LAN
  ↓
CCTV
  ↓
ACS
  ↓
FIRE
  ↓
CROSS-DISCIPLINE QUALIFICATION
```

POWER being the reference discipline does not mean the final residential MVP is POWER-only.

## 4. Depth constraint

The first-revenue breadth is broad, but the depth of each discipline is intentionally bounded to the residential apartment use case.

The rule is:

> broad residential coverage, constrained professional depth, one shared engineering platform.

The MVP must not expand a discipline into adjacent enterprise or industrial products before the residential Golden Journey is accepted.

Examples of deferred depth include:

```text
LIGHTING -> advanced DIALux-class photometric simulation
LAN      -> enterprise network planning / data-center design
CCTV     -> cloud VMS / AI video analytics / face recognition
ACS      -> enterprise identity / visitor-management platforms
FIRE     -> every building class and every jurisdiction
POWER    -> industrial distribution, complex protection studies, campus grids
```

These may be future products, but they are not First Revenue blockers.

## 5. Discipline minimum outcome

### POWER

Must remain the deepest reference slice and cover at least:

```text
loads
board
circuits
protection
cables
placement
routing
calculations
decision evidence
manual override
impact/selective regeneration
SLD / schedules / BOM / PDF
```

### LIGHTING

Residential minimum:

```text
SpaceUsage-driven lighting requirements
luminaire groups
switch/control intent
circuits
supported equipment selection
placement
routing
calculation / constraint evidence
lighting plan
luminaire/control schedules
BOM
```

Advanced photometric simulation is not required unless explicitly promoted into MVP scope.

### LAN

Residential minimum:

```text
service / internet entry
router/gateway
switch where required
LAN outlets
Wi-Fi access-point candidates where supported
structured cabling
port/capability compatibility
placement
routing
LAN plan
port/cable schedules
BOM
```

### CCTV

Residential minimum:

```text
camera requirements
camera candidates
placement
coverage/FOV evidence at supported fidelity
network/PoE dependency
NVR/switch relation where applicable
routing
camera/network schedules
BOM
```

### ACS

Residential minimum:

```text
door/access point
reader
lock
exit button where applicable
door contact
controller
power/network/bus dependencies
placement
routing
device/connection schedules
BOM
```

### FIRE

Residential minimum:

```text
SpaceUsage / risk-context inputs
detector/device requirements
manual call points / notification devices where applicable
loop/zone topology
panel/controller dependencies
placement
routing
versioned normative evidence
warnings / INDETERMINATE handling
device/loop schedules
BOM
```

For FIRE and other safety-relevant decisions, insufficient evidence MUST remain `INDETERMINATE`; ElecX must not fabricate compliance.

## 6. Shared engineering architecture rule

The target architecture is one shared system:

```text
                    EngineeringGraph
                           │
          ┌────────────────┼────────────────┐
          │                │                │
       POWER           LIGHTING            LAN
          │                │                │
          ├──────── CCTV ──┼──── ACS ───── FIRE
          │                │                │
          └────────────────┼────────────────┘
                           ↓
                    Equipment Catalog
                           ↓
                    Constraint Engine
                           ↓
                     Placement Engine
                           ↓
                      Routing Engine
                           ↓
                       Impact Engine
                           ↓
                   Deliverables Engine
```

Logical engineering topology and physical routing remain separate.

A discipline generator produces candidate engineering state; it does not own an isolated duplicate project model.

## 7. Cross-discipline dependency objective

The residential suite must be capable of representing and eventually qualifying dependencies that cross discipline boundaries.

Examples:

```text
CCTV camera
  -> LAN / PoE
  -> PoE switch
  -> POWER load dependency

ACS controller
  -> POWER
  -> LAN / field bus
  -> access devices

FIRE panel
  -> FIRE loops / zones
  -> POWER supply dependency
```

A change in one discipline must dirty/recalculate only explicitly affected dependent state.

Unrelated state must remain unchanged.

## 8. Shared engineer-authority rule

Every discipline follows the same product invariant:

```text
ELECX RECOMMENDS
      ↓
ELECX EXPLAINS
      ↓
ENGINEER ACCEPTS / REJECTS / REFINES
      ↓
DEPENDENCIES PROPAGATE
      ↓
MANUAL DECISIONS SURVIVE
      ↓
ONLY IMPACTED STATE IS RECALCULATED
```

Manual overrides, suppressions and locks are first-class across all disciplines.

No generator may silently destroy deliberate engineer work.

## 9. Shared Engineering Decision Evidence rule

Every material generated decision affecting safety, compliance, sizing, equipment selection, placement or routing must remain traceable to:

```text
inputs
calculations
constraints
normative rules / profile
catalog references
alternatives considered
rejected alternatives + reasons
selected result
selection reason
warnings
PASS / FAIL / INDETERMINATE where applicable
catalog version
normative profile version
algorithm / generator version
```

The explainability requirement applies to all six disciplines, not only POWER.

## 10. Residential Professional Deliverables target

The First Revenue suite should be able to produce a coherent package from canonical engineering state.

### General

```text
combined engineering plan where appropriate
equipment specification
unified BOM
warnings / unresolved / indeterminate issues
PDF package
```

### POWER

```text
electrical plan
single-line diagram
panel schedule
circuit schedule
cable schedule / cable journal
calculation evidence/report
```

### LIGHTING

```text
lighting plan
luminaire schedule
switch/control schedule
circuit information
```

### LAN

```text
LAN plan
port schedule
structured-cabling schedule
```

### CCTV

```text
CCTV layout
camera schedule
network/PoE schedule
```

### ACS

```text
ACS layout
door/device schedule
connection schedule
```

### FIRE

```text
fire-system layout
device schedule
loop/zone schedule
normative warnings/evidence
```

Deliverables remain projections of canonical engineering state and must not become separately maintained sources of truth.

## 11. Delivery order inside the first-revenue roadmap

The strategic target is all six disciplines, but development remains sequential and gate-driven:

```text
PRE-P10 ACCEPTED
       ↓
Residential Structural Host
       ↓
EngineeringGraph
+ Equipment Catalog
+ Normative Evidence
       ↓
POWER reference slice
       ↓
LIGHTING residential slice
       ↓
LAN residential slice
       ↓
CCTV residential slice
       ↓
ACS residential slice
       ↓
FIRE residential slice
       ↓
Cross-Discipline Qualification
       ↓
Unified Placement / Routing qualification
       ↓
Impact + Selective Regeneration qualification
       ↓
Professional Deliverables qualification
       ↓
Production Persistence
       ↓
Native Golden Journey qualification
       ↓
FIRST PAID VALUE
```

A later discipline must reuse already-qualified shared infrastructure rather than weaken previously accepted invariants.

## 12. Scope-control beacon

When implementation choices compete, prefer the work that shortens the path to this outcome:

```text
Apartment
→ six residential engineering disciplines
→ explainable decisions
→ shared placement/routing
→ engineer-controlled refinement
→ selective recalculation
→ professional documentation
→ durable project
→ paid user value
```

Do not broaden beyond residential depth merely because a generalized architecture makes broader features technically possible.

The strategic breadth boundary for First Revenue is the six disciplines above.

## 13. Product acceptance beacon

The long-term intent of MVP-1 is not to demonstrate six icons or six shallow generators.

The target is one integrated residential engineering product in which:

```text
ElecX generates across the required residential disciplines.
ElecX explains material engineering decisions.
The engineer remains authoritative.
Cross-discipline dependencies are machine-readable.
Manual work survives regeneration.
Only impacted state is recalculated.
Professional deliverables follow canonical state.
The project survives Save / Close / Reopen.
The result is useful enough to sell.
```

This beacon defines the desired First Revenue product shape. The existing MVP contract continues to define the staged engineering discipline and acceptance mechanics used to reach it.