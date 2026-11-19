# ElecX UX-D1 — CAD-first interaction contract

Status: **PARTIAL IMPLEMENTATION / NATIVE GUI NOT YET QUALIFIED**.

Design target: an apartment electrical CAD workspace where physical routes, electrical
connections and component placement are visually distinct operations that share
canonical identities. This document is a product/acceptance contract, not proof that
the entire interaction is implemented.

## Source-backed existing UI (R4 baseline)

- `unified_icon_toolbar.dart`: selection, manual cable, route trajectory editing and undo/redo.
- `cable_authoring_draft_bar.dart`: source port → physical path → target port guidance.
- `cable_trajectory_panel.dart`: route selection and navigation into the physical host plane.
- `apartment_wiring_preview.dart`: whole-apartment preview and application of eligible routes.
- `room_circuit_panel.dart`: load, cable specification and protection workflows.

## First delivered UX-D1 slice

1. A permanently discoverable **New manual cable** action inside trajectory editing.
   The action switches to the existing manual routing tool without manufacturing a
   route, skipping physical checks or changing saved data.
2. When no route exists, the panel explicitly says so.
3. When routes exist but none is selected, the panel explains selection, physical
   surface navigation and manual editing.
4. Once selected, the panel shows source device, target device, physical length,
   installation length and surface-segment count from the committed route.
5. For a selected route, existing per-segment chips still navigate into the
   real editable wall/ceiling/floor host.

## Follow-on execution, in this order

### UX-D2 — Component placement and edit
- Direct selection, movement, rotation and numeric coordinates.
- Snap semantics and explicit host identity across wall/floor/ceiling.
- Preserve electrical endpoint identity; on invalid physical placement mark
  dependent routing STALE/BLOCKED rather than silently break connections.
- Native mouse interactions and Save/Quit/Reopen are mandatory.

### UX-D3 — Electrical port-to-port connections
- Source and destination selected on the plan with visible port targets.
- Separate topology connection from physically routed cable geometry.
- Group and light-switch control topology must be semantically correct;
  no inferred L/N/PE or unsupported normative claims.

### UX-D4 — Manual route editing
- Click to place points, drag internal bends, add/remove waypoints, undo/redo.
- Cross-room transitions only through verified construction boundaries.
- No invisible synthetic penetration or disconnected host transition.
- Provide actionable error text on blocked transitions.

### UX-D5 — Paired plan and schematic views
- One canonical circuit model, two projections (physical plan vs electrical scheme).
- Selecting an object highlights the same identity in panels and both views.

### UX-D6 — Automatic route proposal
- Search physical, allowed edges with material/mounting/normative constraints.
- Offer shortest *admissible* route and alternative preferences.
- Preview/Diff/Apply transaction, with precise provenance and fail-closed blockers.
- Normative qualification requires an identified edition of applicable KZ rules,
  not the label `GOST compliant` by default.

### UX-D7 — Native desktop qualification
- Production `lib/main.dart`, real user-created project, mouse-only golden journey.
- Source → destination → manual route → edit bends → Undo/Redo → Save/Quit/Reopen.
- Verify visible cable, route identity, component identity and qualification state.
- CI must pass at exact SHA; domain-only passing tests cannot produce UX ACCEPTED.

## Release gates

- `DOMAIN GREEN`: focused tests pass.
- `INTEGRATION GREEN`: canonical state and persistence agree.
- `GUI GREEN`: all user actions are reachable in production main.dart.
- `UX ACCEPTED`: independent first-time user completes golden journey.
- `ENGINEERING QUALIFIED`: applicable normative, cable, protection and
  construction checks are independently proven.

Current release verdict remains **PARTIAL**. Do not merge to main on this
design specification or on widget tests alone.
