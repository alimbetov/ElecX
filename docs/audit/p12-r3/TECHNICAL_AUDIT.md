# P12 R3.8–R3.11 technical audit

Date: 2026-11-10 (Asia/Almaty). Remote baseline `4811b57de49e9ad66e9bb5e3d0387d2ea0737a0c` verified by fetch; all six baseline workflows independently confirmed successful. Dedicated worktree `ElecX-p12-r3-audit`, branch `fix/p12-r3-multilevel-routing-qualification`. Existing worktrees/user changes preserved; no main mutation. macOS 15.6 arm64, Flutter 3.47.7, Dart 3.13.5. Doctor has non-macOS toolchain warnings; macOS device/build/runtime available.

## Confirmed defects and minimal fixes

| ID | Priority | Expected / reproduced actual | Root cause | Fix and regression |
|---|---|---|---|---|
| D1 | P1 | After deleting a connected component and its route, qualification must contain no result for that route; actual retained VALID. RED: expected empty, actual one qualification. | Workspace cached the Restore result; P2 deletion/Undo/Redo did not invalidate it. | 01fd6693 derives qualification from current committed routes/slabs/building on each read. Delete→Undo→Redo→Undo checks route ID/status and absence, without modifying route identity. |
| D2 | P1 | Remapping VerticalCore to another room invalidates passages hosted by the original room, even if both contain the same XY. Actual VALID instead of STALE. | Core authoring validated containment of mapped rooms, while qualification separately accepted any room on a level; the two ownership checks were not joined. | d86299b4 checks all four passage-side room IDs against spaceIdByLevel before accepting the leg. RED→GREEN overlapping-room regression. |
| D3 | P1 | Replacing the active level elevation with 100 mm must survive Save and Reopen. Actual capture restored old 0 mm. | replaceBuilding updated aggregate/site but left editor.level stale; capture synchronized old editor geometry over the replacement. | 13e32a7f updates the active editor level from the authoritative replacement while retaining navigation. Regression checks building and site snapshots, Restore and repeated Capture. |

No confirmed P0; three confirmed defects fixed. Added mutation/locality coverage in 3c830cef. All changes preserve schema v9, immutable SlabId/CoreId, existing physical graph/Canvas model and production safety gates. No force pushes, destructive clean/reset, schema/security weakening or invented UI seed.

## Architecture and audit scope

Existing surface transforms and transition graph enforce shared-corner/edge geometry; physical routes keep ordered host surfaces and explicit penetration aggregates. Tests exercise Wall↔Wall, Wall↔Ceiling, Wall↔Floor, reject unsupported Ceiling↔Floor, require the exact canonical slab for up/down interlevel crossings, and persist three-room/two-passage routes. Multi-level control has 1200 visible + 440 slab + 3000 core = 4640 mm, 4872 with 5% reserve; combined Wall→Ceiling→Slab→Core→Slab→Floor→Wall has 8440/8862 mm. Core span excludes slab thickness; reverse/unreferenced duplicate legs and unaligned passages reject. No second geometry or graph introduced.

Schema v9 stores canonical slabs explicitly. v7→v8 never guesses SlabId; v8→v9 leaves slab evidence empty. Current decode rejects slab map key/ID mismatch. File store validates JSON before writing temp, uses primary/backup rename and recovery; persistence suites exercise corrupt-file isolation and backup-only recovery. This is not a claim of crash/fault injection or multi-process save locking coverage.

## Qualification event coverage

| Mutation / evidence | Observed service result |
|---|---|
| Complete current evidence / restored v9 | VALID |
| Slab thickness / material | STALE |
| Moved room / slab footprint excludes crossing | STALE |
| Intermediate level elevation | STALE |
| Missing core | BLOCKED |
| Missing canonical slabs / migrated v8 | REQUIRES_REVIEW |
| Cross-building slab | STALE (explicit existing contract) |
| Restored correct evidence | VALID |
| Unrelated slab | VALID |
| Core mapped room differs from passage host | STALE after D2 |
| Delete route / Undo / Redo | absent / VALID / absent after D1 |

These are event-driven regression assertions, not proof of all possible simultaneous corruptions or every 4×4 status precedence combination. Qualification is explicitly a vertical-core-leg validator: wall-only/single-slab routes require their own validators and return REQUIRES_REVIEW here. Workspace room heights are derived from current construction/elevation evidence; no independent historical geometry fingerprint is persisted. Coherent geometry edits that remain physically consistent are not guaranteed to be reported as historical STALE. Complete mutation-history semantics need a separately reviewed evidence/version contract, not a speculative schema change in this fix PR.

## Remaining qualification blockers

Native basic startup, routing rejection and Save/Quit/Reopen pass. Full canonical three-level route authoring/status inspection was not reachable in the inspected production editor and remains BLOCKED; see DESKTOP_ACCEPTANCE.md. Do not treat passing domain fixtures as desktop acceptance. P12 source is honestly unavailable and Apply blocked. These scope gaps are not resolved by the three minimal fixes; no new model/UI feature was fabricated. Merge gate remains blocked if the task requires full native multi-level GREEN.

## 2026-11-13 debugging continuation

Merged current target `981dfe59` into the fix branch (`fb760150`), preserving its guided cable-authoring changes. Confirmed fourth P1 defect D4: committed active-room geometry edits before Save/navigation left workspace geometry stale, so a physically invalid core route remained VALID. RED expected STALE, actual VALID. Fix `38a97cf4` qualifies against a pure snapshot containing the current editor level; restored-document qualification uses the same path. Reads preserve workspace identity, route identity and saved state. Regression moves the active room away from the crossing, checks both qualification APIs, restores it and checks VALID. Four confirmed defects fixed in total; the native multi-level acceptance blocker remains.
