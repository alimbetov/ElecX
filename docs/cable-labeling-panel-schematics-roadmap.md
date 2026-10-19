# ElecX cable labeling, cabinet termination and schematic roadmap

## Principle

Cable labels, cabinet schedules, terminal plans and schematics are projections of the same engineering model. They must never be maintained as independent manual documents.

## Stable identity chain

```text
DistributionBoard
  -> ProtectiveDevice
  -> CircuitRef
  -> CableIdentity
  -> Route
  -> CableTerminationRef A/B
  -> Component Port / Terminal
```

A cable label is generated from this chain. Reassigning a circuit or termination must invalidate/regenerate dependent labels and deliverables.

## Required core entities

- `CircuitRef`: stable circuit identity, board and protective-device references.
- `CableIdentity`: stable cable id, route id, circuit id, cable specification and designation.
- `CableTerminationRef`: component, port and optional terminal identity for both cable ends.
- `CableLabelData`: printer-neutral label content.

Printer media size, margins, fonts, barcode type and cut settings belong to a later presentation/print adapter and must not enter the engineering domain.

## Label content

Recommended minimum fields:

- cable designation, e.g. `W-017`;
- board / circuit / protective-device designation, e.g. `DB-01 / LIGHT-01 / QF-07`;
- cable specification, e.g. `VVGng-LS 3x1.5`;
- local termination, e.g. `LIGHT-03:L`;
- optional opposite endpoint;
- QR/DataMatrix payload resolving to stable cable identity.

Both cable ends keep the same cable designation but can have different endpoint-specific secondary text.

## Cabinet workflow

```text
Board
  -> row / DIN position
  -> protective device
  -> terminal
  -> circuit
  -> cable
  -> destination
```

The enclosure layout engine should expose terminal and protective-device ids so a field electrician can trace a cable from a printed label directly to the correct breaker/terminal.

## Schematic projections

The same topology should support:

1. single-line diagram;
2. cabinet wiring/termination diagram;
3. terminal schedule;
4. cable schedule;
5. cable label batch;
6. installation/commissioning checklist.

No schematic renderer should invent connectivity; it renders `EngineeringTopology + CircuitRef + CableIdentity + Terminations`.

## Acceptance scenario

```text
DB-01 / QF-07
  -> LIGHT-01
  -> cable W-017
  -> route-0017
  -> LIGHT-03 power-in
```

Expected outputs:

- selected route inspector shows `W-017`, cable spec, circuit and endpoints;
- cabinet view shows `QF-07 -> W-017`;
- single-line diagram shows `DB-01/QF-07 -> LIGHT-03`;
- label A identifies cabinet end;
- label B identifies load end;
- QR/DataMatrix on either end resolves to `cable-0017`;
- changing `QF-07` to another protective device updates all generated projections after explicit model commit.

## Next implementation sequence

P0:
- stable identities and label composer;
- taxonomy and selection inspector;
- route/cable inspector evidence fields;
- selection/focus bridge for simulation findings.

P1:
- circuit registry and cable registry in project persistence;
- protective-device and terminal identities from enclosure model;
- printer-neutral label sheet model;
- single-line diagram projection model;
- cable schedule projection.

P2:
- printer adapters (PDF/A4 label sheets and dedicated thermal label printers);
- QR/DataMatrix rendering;
- cabinet wiring drawing;
- commissioning scan workflow and as-built verification.
