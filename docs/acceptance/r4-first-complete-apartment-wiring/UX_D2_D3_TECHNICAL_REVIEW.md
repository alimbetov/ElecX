# ElecX R4 UX-D2/D3 — Technical Review & Defect Remediation

Date: 2026-11-20. Target branch: `feat/r4-first-complete-apartment-wiring`.
Audit baseline: `f63235a05f9313efa205d55180e3acf890691321`
(Flutter Actions on that baseline: success). This document records source-inspected
behaviour and implemented fixes; it is **not** a native Desktop acceptance receipt.

## Inspected production path

`EditableSpatialCanvas` → `EditorP2Session.select` →
`EngineeringInspectorPanel` → `ComponentConnectionActions` →
`PortDrivenCableAuthoring` → `ManualCableDraftPersistence` →
`EditorP2Session` routes/history.

Existing `ComponentTransformSession` implements surface-bound preview/commit
for component movement. Existing `SurfaceCanvas` supports pointer movement,
port acquisition and route editing on the active physical host.

## Confirmed UX defects and remediations

| Priority | Finding | Remediation | Verification |
| --- | --- | --- | --- |
| P1 | Inspector listened only to P2 component selection; port-driven draft mutation notifies the editor controller, so progress/ready UI could remain stale | Listen to both controller and P2. Show source binding, compatible same-surface target ports, current completion/blocked status | Widget regression for source→target→finish |
| P1 | After starting a draft, inspector still offered another start port; clicking it necessarily failed | Replace start actions with contextual completion while an active port binding exists | Widget regression for state transition |
| P1 | The inspector's navigation action was still enabled during the draft | Disable host-navigation button during draft so the inspector cannot inadvertently change its host | Widget regression for disabled navigation and safe cancel |
| P1 | No inspector-level finish/cancel workflow; completion existed only in a separate draft bar | Wire `snapPortDrivenCableCompletionTarget`, `finishManualCableDraft` and `cancelManualCableDraft` (no parallel persistence model) | Widget regression ensures pre-commit P2 routes stay empty, then one route appears and Undo/Redo works |
| P1 | Starting at a load port is electrically reverse-directed; labelling the starting point “Источник” is incorrect | Label “Начало трассы”, preserving actual directed cable endpoints | Existing reverse-authoring tests plus widget regressions |
| P0 safety | A compatible device in another room is not proof of a valid crossing | Do not expose foreign-room target for direct completion; show passage requirement and keep Finish disabled | Negative widget regression |
| P0 safety | A candidate selected before a load edit must not be accepted with stale P2 revision | Retain existing revision validation and explicit disabled Finish state | Negative widget regression |

## Known unclosed scope

1. **P0 UX-D2**: Direct manipulation of equipment on the apartment-wide plan is
   not yet implemented; existing component drag operates on the wall/ceiling/floor
   host plane. Opening the host from the inspector is a bridge, not completion.
2. **P0 UX-D3**: Direct port-to-port gesture entirely on the general plan, with
   safe cross-room continuation, is not yet implemented. Same-host inspector
   completion is reachable; physically verified passage still requires the
   existing authoring workflow.
3. **P0 electrical**: Full lighting control topology (switches, L/N/PE),
   normative cable sizing and protection remain unqualified.
4. **P0 acceptance**: A full production `lib/main.dart` desktop
   source→target→draw→edit→Save→Quit→Reopen must be witnessed, including
   real screenshots and object identity. Widget tests do not substitute for it.
5. **CI**: The feature branch's Flutter workflow is not the same as the full
   six-workflow release acceptance; require exact-SHA evidence before merge.

## Required native acceptance checklist

- On a four-room apartment, click a socket symbol on the overview plan.
- Inspector shows stable room/host coordinates and selectable ports.
- Click “Открыть поверхность для перемещения” and drag the socket.
- Verify connected cable identity persists or physical route is explicitly
  rejected; silent detachment is forbidden.
- Start at a board output port; choose target input port from live inspector.
- Verify **no committed route before Finish**, and one route after Finish.
- Undo and Redo the route commit.
- Verify cross-room targets remain blocked without construction evidence.
- Save, fully quit, relaunch, reopen, verify circuit/route identities.
- Confirm with actual native GUI screenshots and raw logs.

## Merge gate

`PARTIAL` until all P0 user journeys and native desktop acceptance pass.
Do not merge R4 to main merely because Flutter tests are green.
