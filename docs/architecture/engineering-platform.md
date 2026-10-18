# ElecX Engineering Platform

## Purpose

The engineering platform turns spatial project facts into traceable engineering decisions. It is designed so calculations, catalogs, normative rules and optimization can evolve without coupling the runtime to historical delivery stages.

## Central model

The center of ElecX is an engineering configuration over shared physical space.

```text
Requirements
   + Spatial model
   + Engineering facts
   + Catalog/version context
   + Normative profile
           |
           v
      Solver Graph
           |
           v
      Constraints
           |
           v
 Feasible Configuration
           |
           v
 Evaluation / Optimization
           |
           v
  Evidence + Deliverables
```

## Shared engineering model

Core concepts should remain discipline-neutral where the semantics are truly shared:

```text
EngineeringEntity
EngineeringPort
EngineeringConnection
EngineeringAssignment
EngineeringRequirement
EngineeringCapability
EngineeringConstraint
EngineeringEvaluation
EngineeringEvidence
EngineeringLayer
```

A physical entity should not be duplicated because several disciplines use it.

Example:

```text
NetworkSwitch
  ports: ETH-01..ETH-48, SFP-01..SFP-04
  capabilities: ETHERNET_SWITCHING, POE_PSE, VLAN, LACP
  assignments: Camera-101 -> ETH-01
```

CCTV and LAN operate on the same switch identity.

## Typed capabilities, not EAV

Stable engineering semantics must use typed contracts/classes.

Conceptually:

```text
PoePseCapability
  powerBudget
  portCount
  standards

CircuitBreakerCapability
  ratedCurrent
  breakingCapacity
  poles
  tripCurve

RackCapability
  rackUnits
  depth
  maxLoad
```

Extensible JSON payloads are acceptable only at explicit versioned boundaries. A generic `property_name/property_value` model must not become the engineering core.

## Requirements before equipment

Equipment selection starts from an abstract requirement, not from a manufacturer SKU.

```text
User requirement
-> engineering requirement
-> abstract component requirement
-> catalog candidates
-> calculation/validation
-> selected configuration
```

Example:

```text
48 cameras
20% spare ports
20% PoE reserve
2 x 10G uplinks

=> requiredPorts >= 58
=> requiredPoeBudget >= calculated demand * reserve
=> uplinkCount >= 2
=> uplinkSpeed >= 10G
```

Only then are catalog candidates resolved.

## Engineering catalog

The catalog is an early platform subsystem.

Target hierarchy:

```text
Manufacturer
ProductFamily
ProductModel
ProductEdition
CatalogVersion

EquipmentType
CapabilityDefinition
ParameterDefinition
CompatibilityDefinition

EquipmentCapability
EquipmentParameter
EquipmentCompatibility
Accessory / Dependency

PriceBook
VendorOffer
Availability
LifecycleStatus
```

Catalog data layers:

1. common canonical engineering reference data;
2. discipline reference data;
3. manufacturer products;
4. price/availability data;
5. project-local overlays and approved equivalents.

Every relevant reference entity should support stable code, version, lifecycle, provenance and effective dates.

## Discipline reference data

Examples:

### Electrical

- voltage/current classes;
- conductor/cable classes;
- protection device classes;
- breaker curves;
- RCD types;
- SPD classes;
- enclosure/module characteristics;
- source/storage/conversion equipment.

### CCTV

- camera stream/resolution/codec profiles;
- lens/FOV data;
- storage/retention profiles;
- PoE classes;
- NVR channel profiles.

### LAN

- copper/fiber categories/classes;
- shielding;
- connector/interface types;
- link/channel limits;
- PoE and switch-port capabilities;
- loss-budget profiles.

### ACS

- reader/credential/interface types;
- lock behavior/current profiles;
- controller I/O profiles;
- autonomy profiles.

### Fire

- loop/device types;
- capacity profiles;
- standby/alarm current profiles;
- cable fire-performance classes;
- autonomy/supervision profiles.

Algorithms are code; coefficients, limits and policy values that vary by profile/version belong in reference data.

## Solver contract

Solvers calculate engineering facts. They do not own the whole application flow.

Conceptually:

```text
EngineeringSolver<I,O>
  id
  version
  consumes FactKind[]
  produces FactKind[]
  applicability(context)
  solve(input, context)
```

Representative solver families:

```text
POWER.LOAD_DEMAND
POWER.DESIGN_CURRENT
POWER.CABLE_SIZING
POWER.VOLTAGE_DROP
POWER.SHORT_CIRCUIT
POWER.PROTECTION

LAN.PORT_CAPACITY
LAN.BANDWIDTH
LAN.POE_BUDGET
LAN.UPLINK_CAPACITY

CCTV.BITRATE
CCTV.STORAGE
CCTV.BANDWIDTH

ACS.CONTROLLER_CAPACITY
ACS.PSU_CAPACITY

FIRE.LOOP_CAPACITY
FIRE.PSU_AUTONOMY

LAYOUT.RACK
LAYOUT.PANEL

ENERGY.GENERATOR
ENERGY.SOLAR
ENERGY.BATTERY
ENERGY.ATS
```

## Dependency graph

Each solver declares consumed and produced facts. The runtime builds a dependency graph.

Example:

```text
CAMERA_COUNT
  -> NETWORK_PORT_DEMAND
  -> SWITCH_SELECTION
  -> RACK_U
  -> UPS_LOAD
  -> POWER / BOM / COST
```

If camera count changes, ElecX recalculates the affected closure instead of recomputing every unrelated system.

Required runtime behavior:

- deterministic order;
- cycle detection;
- explicit invalidation;
- input/output fingerprints;
- cache only when correctness is provable;
- trace of why a solver ran;
- solver-version evidence.

## Solver vs constraint

These responsibilities are separate.

```text
Solver:      what is the result?
Constraint:  is the state acceptable?
```

Example:

```text
solver -> voltageDrop = 3.4%
constraint -> voltageDrop <= applicableLimit
```

Constraint families include:

- geometry/placement;
- physical compatibility;
- port/capacity;
- thermal/load;
- manufacturer compatibility;
- project policy;
- normative/jurisdiction rules.

## Compliance engine

Normative rules run throughout candidate evaluation, not only at the final export step.

```text
candidate
-> engineering calculations
-> engineering constraints
-> normative constraints
-> survive/reject/findings
```

A project explicitly pins its profile/version. A rule update does not silently mutate prior project interpretation.

A finding must be traceable to:

- rule/profile version;
- project revision;
- affected entity;
- input facts;
- evidence;
- severity/status.

## Configuration engine

The configuration engine is the core automation capability.

```text
Requirements
-> Requirement Normalizer
-> Candidate Generator
-> Constraint Propagation
-> Catalog Candidate Resolver
-> Solver Graph
-> Compliance
-> Feasibility
-> Cost / Reliability / Reserve
-> Optimizer
-> Top N alternatives
```

The engine does not replace the engineer. It narrows the search space, explains invalid candidates and proposes feasible alternatives.

## Engineer locks and overrides

Any auto-configuration system must respect explicit user decisions.

Representative states:

- suggested;
- accepted;
- manually selected;
- locked;
- approved equivalent;
- rejected/forbidden.

A locked selection cannot be silently replaced by optimization. Instead ElecX reports downstream consequences or infeasibility.

## Optimization

Optimization is multi-objective, not only `min(price)`.

Possible objectives:

- CAPEX;
- OPEX/energy;
- reliability;
- spare capacity;
- maintainability;
- equipment availability;
- rack/panel space;
- local vendor availability;
- number of SKUs / standardization;
- installation complexity.

The preferred UX is a small set of explainable alternatives such as Economy, Balanced and High Reliability rather than one opaque numeric score.

## External power and energy topology

External energy sources are first-class engineering entities.

Representative source/storage/conversion types:

```text
GRID
GENERATOR
SOLAR
BATTERY
UPS
FUEL_CELL
OTHER
```

The topology may include:

```text
GRID ------ ATS ------ BUS
              ^
GENERATOR ----|

SOLAR -> INVERTER ----|
BATTERY -> PCS --------|-> BUS
```

Protection, source priority, reserve/autonomy and operating modes are handled by typed engineering rules/solvers rather than special UI-only cases.

## Enclosure and rack layout

Physical configuration must become a solver/constraint consumer of selected equipment.

Target model supports:

- panel/cabinet/rack hierarchy;
- DIN rails/rows;
- module widths;
- terminals;
- busbars;
- ducts;
- wiring zones;
- rack U capacity;
- depth/load limits;
- cable-entry zones;
- spare/reserve capacity;
- patching/port relationships;
- manual and automatic layout candidates.

Layout changes can feed back into selection if a candidate physically does not fit.

## Revisions and evidence

A reproducible engineering result pins:

```text
ProjectRevision
SpatialRevision
CatalogEdition
NormativeProfileVersion
SolverVersions
InputSnapshot / Fingerprints
Configuration
Evaluation
Evidence
```

Revision/evidence primitives should preserve the successful work already developed in Electra: canonical JSON, hashes, immutable snapshots where appropriate, replay and qualification tests.

## Deliverables

Deliverables are projections from authoritative project state.

Target outputs:

- BOM/BOQ;
- cable schedule;
- circuit/panel schedule;
- rack/enclosure schedule;
- drawings/topologies;
- calculation report;
- compliance report;
- cost estimate;
- labels/QR;
- PDF/spreadsheet exports;
- future DXF/DWG interchange.

A report must not become a second source of engineering truth.
