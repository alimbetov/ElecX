# R4 UX-D2/D3 — Apartment plan mouse interaction acceptance

Date: 2026-11-20
Branch: `feat/r4-first-complete-apartment-wiring`
Scope: direct plan component movement and explicit plan port pairing.
Release verdict: **PARTIAL — native Desktop acceptance NOT RUN**.

## Implemented engineering path

### UX-D2 — Move a device directly on the plan
- `SpatialCanvas` renders selectable component symbols with mouse drag
  callbacks, visual selection and feedback for invalid placement.
- `PlanComponentMoveProjection` performs geometry-verified reverse projection
  of a plan point into the device's original physical host.
- Wall: only longitudinal coordinate changes; mounting height never changes
  from a flat plan drag. A stale canonical BoundaryEdgeId, departure from the
  wall, or out-of-profile position rejects the move.
- Ceiling/floor: both room-local plan coordinates can change, but only inside
  the same room.
- `ComponentTransformSession` / `EditorP2Session` own the actual transaction:
  the connected cable is reconciled or the move is cancelled. Route identity
  must not be recreated silently; one Undo/Redo operation covers both.
- Locked electrical and cable route layers remain protected. No silent
  move to a different wall or room.

### UX-D3 — Select two ports with the mouse on the apartment plan
- The selected equipment inspector exposes **Соединить на плане** for
  individually named, connectable source ports.
- The user clicks an eligible destination equipment symbol. With a unique
  compatible port it is selected; multiple candidate ports open a selection
  dialog. Source and destination equipment are highlighted.
- `PlanPortPairSession` holds only transient identity, port and baseline
  revision data. It **does not** persist a fake electrical or cable link.
- The dashed on-plan line is a proposed straight candidate, **not** a verified
  route, a normative certificate or a committed object.
- **Проверить и проложить** invokes the existing port-driven physical
  authoring and `finishManualCableDraft` with exact port identities. Only a
  successful physical commit enters project history.
- Same-host straight candidate only. Different room, wall, floor or ceiling
  means **BLOCKED** until the verified construction route is authored in the
  physical editor. No synthetic passage or inferred cable channel.
- Undo/Redo must preserve topology, endpoint IDs and cable identity.
- A P2 mutation, change in device coordinates, lock/tool/view change or
  existing route draft invalidates the candidate before Apply.

## Source-backed test matrix

| Test | Assertion |
| --- | --- |
| `plan_component_move_projection_test.dart` | Wall/ceiling inverse projection, stale canonical edge, out-of-host rejection |
| `plan_component_drag_widget_test.dart` | Real plan drag, connected route identity, Undo/Redo, invalid host and locked layer |
| `plan_port_pair_session_test.dart` | Same-host port pair, no precommit mutation, exact directed ends, invalidation |
| `plan_port_pair_widget_test.dart` | Inspector source button → actual plan target click → preview → Apply; remote block |
| `r4_apartment_production_workflow_test.dart` | Actual apartment project selection, inspector and route visibility |

Passing tests are not a substitute for macOS Desktop GUI UAT.

## Required real Desktop GUI acceptance (not yet verified)

1. Launch the ordinary app: `flutter run -d macos -t lib/main.dart`.
2. Open the actual R4 apartment saved through production Hub.
3. In **Выбор** mode, select a socket on the overall apartment plan.
4. Drag it 300 mm along its wall: position changes in inspector and plan.
5. Check the connected route stays attached, retains the same RouteId and
   does not switch wall or mounting height.
6. Undo/Redo; verify exact coordinates, route identity and visible cable.
7. Attempt moving through a doorway or away from the host: reject and restore.
8. Select a board on the overall plan, press **Соединить на плане · power-out**.
9. Click a same-host socket. The dashed proposed route appears, but neither
   project history nor committed cable changes until explicit Apply.
10. Press **Проверить и проложить**. Confirm one route with actual endpoint
    port IDs. Undo/Redo.
11. Attempt connecting a socket in a different room without a valid passage:
    action must stay blocked, not generate a straight fake route.
12. Save → native Quit → relaunch → reopen. Verify stable ComponentId,
    RouteId, circuit bindings and on-plan visualization.
13. Capture native screenshots, event logs, exact SHA and all required
    GitHub Actions outcomes.

## Limitations / next gates

- There is **no qualified general-plan cross-room automatic routing** yet.
- Port pairing is a same-host straight candidate, not a full multi-waypoint
  cable path editor.
- L/N/PE, switch-controlled lighting and KZ normative qualification are
  still separate P0 gates.
- Native macOS mouse-driven E2E must pass on the same final SHA before
  the feature can be called `UX ACCEPTED` or merged to main.
