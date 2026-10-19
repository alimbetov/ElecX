# Cable sizing, thermal/grouping and channel-aware routing architecture

## Purpose

ElecX must not choose cable size from route geometry alone and must not choose a route from geometry alone. A valid engineering proposal is the result of four independent concerns:

1. electrical adequacy of the cable;
2. thermal/grouping derating along every installation section;
3. physical channel capacity and segregation;
4. feasible route optimization across hosts, installation methods and channels.

The core engine deliberately contains no hard-coded national/IEC tabulated ampacity or derating values. Those values belong to a normative profile/resolver (ELV7). The core consumes explicit evidence and produces deterministic calculations and reasons.

## Layering

```text
Load / circuit requirements
        |
        v
Cable electrical candidate
        |
        +--> base ampacity evidence  <--- normative profile
        |
        +--> thermal/grouping factors <--- normative profile + occupancy
        |
        v
CableSizingEngine
        |
        +--> current adequacy
        +--> voltage drop
        +--> optional short-circuit evidence hook
        |
        v
Feasible CableSpec candidates
        |
        v
Installation capacity / segregation
        |
        v
Channel-aware route solver
        |
        v
Ranked, explainable engineering alternatives
```

## Non-negotiable invariants

- conductor cross-section (mm2) is never used as physical channel occupancy area;
- cable outer diameter/envelope is never used as conductor electrical cross-section;
- normative coefficients are inputs/evidence, not constants hidden in algorithms;
- a hard violation (overfill, forbidden segregation, unavailable channel, invalid host) removes an edge/state from routing;
- soft preferences (length, labor, material, bends, transitions, maintainability) only rank feasible alternatives;
- a route may contain multiple installation methods and channels;
- thermal/grouping conditions are evaluated per installation section; the worst permitted-current section governs the circuit;
- selection of a larger cable must be re-evaluated against channel capacity because electrical improvement can create a physical overfill;
- optimization is read-only until the user accepts a proposal.

## Electrical sizing model

### CircuitElectricalRequirement

Inputs include:

- phase system (DC, single-phase AC, three-phase AC);
- design/load current;
- nominal voltage;
- power factor where applicable;
- maximum permitted voltage-drop ratio;
- route length;
- number of loaded conductors where required by normative evidence.

### CableElectricalEvidence

Resolved from cable + installation/normative profile:

- base ampacity A;
- conductor resistance ohm/km at the calculation reference or corrected temperature;
- optional reactance ohm/km;
- evidence/source key for traceability.

The engine does not invent missing values. Missing evidence produces an indeterminate result rather than PASS.

### Voltage drop

The engine supports explicit equations for:

- DC / single phase: `2 * I * L * (R*cosPhi + X*sinPhi)`;
- balanced three phase: `sqrt(3) * I * L * (R*cosPhi + X*sinPhi)`.

L is one-way route length in km. For DC the reactance term is normally zero but remains explicit in evidence.

## Thermal and grouping model

Thermal derating is represented as named multiplicative factors:

```text
adjustedAmpacity = baseAmpacity
                 * ambientFactor
                 * groupingFactor
                 * insulationFactor
                 * soilFactor
                 * installationFactor
                 * customFactors...
```

Factors are immutable evidence objects with IDs and reasons. The engine records the product and every constituent factor for explainability.

A route may traverse:

- concealed wall;
- tray;
- riser;
- underground duct;
- facade;
- etc.

Therefore each route section can have a different factor set. The minimum adjusted ampacity across all sections is the governing ampacity.

## Channel occupancy feedback loop

Cable selection and route selection form a constrained loop:

```text
candidate cable size
       |
       v
thermal adequacy
       |
       v
physical outer diameter
       |
       v
channel fill / segregation
       |
       +---- fail ----> next cable/channel/path candidate
       |
       v
feasible combined candidate
```

The optimizer must never size the cable first and assume the current channel remains feasible.

## Channel-aware routing state

Legacy `RouteEngine` remains the geometric indoor solver. The next solver uses an expanded state:

```text
ChannelRouteState
- routeNodeId
- hostId
- installationPathSpecId
- pathSectionId
- channelId
```

A transition is feasible only if:

- geometric edge exists;
- host transition is legal;
- installation method supports the edge/host;
- channel exists;
- cable segregation class is allowed;
- adding occupancy does not exceed capacity/reserve policy;
- additional normative hard constraints approve it.

## Cost model

Use an explicit cost vector before scalar ranking:

```text
lengthMm
materialCost
laborCost
transitionCount
bendCount
channelUtilizationPenalty
maintainabilityPenalty
normativeRiskPenalty
```

The scalar score is policy-driven. The result retains the vector so UI can explain why one alternative won.

## Acceptance scenarios

1. 3x2.5 mm2 cable passes current but fails voltage drop -> rejected.
2. Larger cable passes electrical checks but overfills existing conduit -> rejected for that channel, alternative channel/path considered.
3. Two power circuits grouped in one tray reduce governing ampacity through externally supplied grouping factor.
4. Ethernet candidate is rejected from a power-only channel before route scoring.
5. Same endpoint pair has facade and underground alternatives; both feasible -> ranking reports cost/length tradeoff.
6. A route with one thermally severe section is governed by that section even if all others have higher ampacity.
7. Missing ampacity/resistance evidence -> INDETERMINATE, never implicit PASS.
8. Accepted optimization is applied only through a command/history mutation after preview.

## P0 implementation scope

- pure `CableSizingEngine`;
- named thermal-factor model and section-level governing ampacity;
- pure channel-aware graph/state solver accepting injected hard-feasibility and cost callbacks;
- tests proving electrical, thermal and routing separation.

## Deferred to ELV7 / later qualification

- actual KZ/IEC ampacity tables and correction coefficients;
- short-circuit withstand tables/equations tied to normative profiles;
- protective-device coordination;
- harmonics/neutral sizing rules;
- parallel cable rules;
- EMC/separation distances by exact normative profile;
- manufacturer-specific cable impedance and thermal data.
