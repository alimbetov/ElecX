# ElecX R4 UX-D2/D3 — Independent Technical Reaudit, 20 November 2026

Baseline audited: `7776ed6a28f791e3a719e04b3acb2c6583834b0b`
Branch: `feat/r4-first-complete-apartment-wiring`.
Scope: apartment-plan device drag, electrical endpoint selection, straight
physical cable candidate, UI state recovery, transactional Undo/Redo.

Verdict: **PARTIAL — latest exact-SHA CI and native GUI E2E required**.

## Evidence and corrections

| Priority | Finding | Code correction | Regression evidence |
| --- | --- | --- | --- |
| P1 | Baseline Flutter Quality failed for an otherwise valid test suite because of one nonconformant file | Apply the exact `dart format` diff for `plan_component_move_projection_test.dart` | Exact-SHA Quality rerun |
| P0 | Same-host + compatible ports made a proposed straight segment appear actionable even when it crossed a door/window or was diagonal | `PlanPortPairSession.straightRouteBlockReason` validates the exact 2-point route against `NormativeRouteEngine` and the live host context. `ready` is false on failure; Apply remains disabled | `plan_port_pair_session_test.dart`: obstacle and diagonal negatives |
| P0 | P2 mutation revision alone did not invalidate a draft after structural level or opening changes | Snapshot the level identity and immutable opening references at Start, compare before preview and Apply | `plan_port_pair_session_test.dart`: structural opening/level changes without P2 mutation |
| P1 | Users received an opaque failure after trying an impossible straight proposal | Show physical rejection reason in inspector and on-plan preview. Never label geometry check as KZ/GOST certification | `plan_port_pair_widget_test.dart`: explicit blocking and disabled Apply |
| P1 | Failure during physical Apply could leave the board selected and/or switch context away from the user's selected load | Restore plan, Select tool, previous equipment selection; cancel only transient cable draft on failure | Source-inspected recovery path; native GUI acceptance still required |
| P1 | Positive port-pair test accidentally crossed a real door on demo wall 0 | Place the positive test devices on unobstructed wall 1; retain a separate explicit door-crossing negative | Positive route commit + Undo/Redo and blocking test |
| P1 | Baseline QA failed exact Dart formatting in the new test files | Apply formatter output | Exact-SHA Quality rerun |

## Critical invariants

1. A selected pair of ports is *not* a saved cable. No route is committed
   before explicit Apply.
2. Both endpoints and route anchors are specific, versioned physical identities.
   Source and destination components retain their original IDs.
3. The candidate is a **straight same-host segment only**. It must fail
   closed against door/window obstacles, diagonal geometry, invalid hosts,
   changed structural data and locked/hidden layers.
4. A structurally revised apartment invalidates a prior proposal even if P2
   `history.mutationRevision` has not advanced.
5. Committed cable routes must survive Undo/Redo with stable RouteId. No
   synthetic penetration or teleporting inter-room cable may be produced.
6. Moving a device must preserve its mounting height and physical host, update
   connected routes atomically or reject the move without corruption.

## Remaining P0 gates (NOT COMPLETE)

- User picks individual source and target **port glyphs on the plan**:
  source currently starts from the inspector and target may be chosen by
  clicking equipment. This is a transitional gesture, not a complete port UX.
- Native macOS `lib/main.dart` mouse-driven acceptance must demonstrate
  live drag, port pick, blockage feedback, Apply, Undo/Redo,
  Save → Quit → Reopen, with screenshots and persisted IDs.
- Multi-room and multi-surface manual transitions and passage creation remain
  difficult in the actual production interface.
- Lighting control circuits, separate L/N/PE topology, installation methods,
  cable cross-sections and normative compliance require separate qualification.
- Connected device footprints/installation clearances against an opening are
  not yet dimensionally modeled by this two-point UI check. A point-local
  obstacle test is not a certified installation clearance.
- Neither a green Flutter suite nor valid geometry proves GOST/PUE-KZ
  compliance. Exact applicable standards and editions are required.

## Release discipline

Require complete Flutter Quality + Verification success on the same current
HEAD, plus **native GUI E2E**. Keep `main` untouched. No merge on test success
alone. Document any still-blocked transition with a visible reason.
