# Room engineering persistence and discipline-aware topology

## Purpose

ElecX persists the engineering model independently from editor widgets. A room owns not only geometry, but also environment, stable surfaces, placed components, ports, graph connections, routes and calculation snapshots.

## Coordinate ownership

Geography and CAD geometry are deliberately separated.

- Site geographic reference: latitude/longitude/altitude/climate profile.
- Room boundary and surfaces: integer millimetres in project/room coordinates.
- Component placement: `room_id + surface_id + local_x_mm + local_y_mm`.
- Route points: `surface_id + local_x_mm + local_y_mm`.

A socket, camera or detector is never persisted as GPS coordinates. Geography selects climate/normative context; the engineering geometry remains deterministic millimetre geometry.

## Room environment

Every room may have a `RoomEnvironment`:

- usage type;
- temperature regime;
- design minimum/maximum/nominal temperature;
- humidity;
- wet/dusty/corrosive flags;
- extensible environment tags.

Room environment is an input to normative checks and cable/link calculations. A route may later override room ambient values if it crosses a more restrictive zone.

## Component capability model

The component type determines:

1. engineering discipline;
2. system class;
3. calculation kind;
4. available ports;
5. allowed connection types on each port.

Examples:

| Component | System class | Ports / connections | Calculation |
| --- | --- | --- | --- |
| socket | powerAc | AC 1P/3P | power cable sizing |
| luminaire | lighting | AC + optional control | power cable sizing |
| IP camera PoE | cctv | PoE / Ethernet | PoE power budget + data link |
| LAN outlet | structuredCabling | Ethernet copper | copper link length/category |
| fiber termination | fiberOptic | fiber | optical budget |
| ACS controller | accessControl | DC, RS-485, dry contact | DC voltage drop + bus topology |
| fire detector | fireAlarm | fire loop | loop topology/resistance/voltage |

A graph edge is valid only when both endpoint ports allow the requested `EngineeringConnectionType` and their directions are compatible.

## Engineering graph

```text
EngineeringNode
  ├ componentTypeId
  ├ discipline
  ├ systemClass
  ├ RoomSurfaceRef
  ├ local X/Y
  └ ports
       ↓
EngineeringEdge
  ├ fromPort
  ├ toPort
  ├ connectionType
  ├ systemClass
  ├ routeId
  └ circuitId
```

The graph is the source for auto-routing, circuit aggregation and system-specific validation.

## Calculation dispatch

The same generic graph must not use one universal cable algorithm.

```text
systemClass
   ↓
EngineeringSystemPolicy
   ├ powerAc / lighting      → powerCableSizing
   ├ powerDc                 → dcVoltageDrop
   ├ structuredCabling       → copperLinkLength
   ├ poeNetwork / CCTV       → poePowerBudget
   ├ fiberOptic              → fiberOpticalBudget
   ├ fireAlarm               → fireLoopElectrical
   ├ accessControl           → dcVoltageDrop + bus checks
   └ automationBus           → busTopology
```

A future component may participate in more than one graph. Example: an IP camera has an Ethernet/PoE graph edge and may also have an auxiliary DC power edge.

## Power cable sizing

Cable section is not selected from device count alone. The pipeline is:

```text
placed equipment
  ↓ connected load
  ↓ demand/simultaneity
  ↓ design current
  ↓ route length
  ↓ room/route ambient temperature
  ↓ installation method + grouping
  ↓ conductor/insulation
  ↓ corrected ampacity
  ↓ voltage drop
  ↓ protective-device coordination
  ↓ selected cable section
```

Persisted snapshots record inputs and results together with the normative profile used. Recalculation is required when loads, route geometry, room environment, cable catalog or normative profile changes.

## Low-voltage/data examples

### LAN

Validation uses cable category, permanent-link/channel length and topology. It must not run the power-cable section algorithm.

### PoE/CCTV

The data route and the power budget are related but distinct checks. Inputs may include switch/PSE budget, endpoint power class, cable length and voltage at device.

### Access control

A controller may expose DC power, RS-485 and dry-contact ports. The graph may therefore contain several connection types for one physical component.

### Fire alarm

Validation depends on fire-loop/radial topology, node count, loop resistance, voltage at the last device and isolator rules from the active normative profile.

### Fiber

Validation uses optical power budget, attenuation, connector/splice losses and reserve margin, not conductor section.

## SQL ownership

The initial schema is split into:

- `docs/sql/001_engineering_core.sql` — projects, sites, rooms, environment, geometry, surfaces, components, ports, circuits and routes;
- `docs/sql/002_engineering_system_profiles.sql` — system class/calculation dispatch and discipline-specific calculation snapshots.

JSON columns are allowed only for extensible metadata or result payloads. Core geometry, component coordinates, topology and routes remain normalized and queryable.

## Persistence roadmap

1. Stabilize domain contracts and SQL schema.
2. Add local SQLite/Drift tables and repositories.
3. Implement atomic project/level/context transactions.
4. Add graph rebuild from persisted nodes/edges.
5. Add discipline-specific calculation engines.
6. Add revision/snapshot migration and sync contracts later.
