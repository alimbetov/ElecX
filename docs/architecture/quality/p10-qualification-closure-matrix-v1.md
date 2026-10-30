# P10 qualification closure matrix

Date: 2026-10-30
Branch: `feat/p10-building-residential-composition`
Contract: `../p10-building-residential-composition-spec-v1.md`
Workflow: `.github/workflows/p10-final-acceptance.yml`

Implementation and tests exist for P10.1–P10.13. Acceptance is conditional on all
required jobs completing successfully on one exact SHA. A local pass, a queued or
skipped platform, and an earlier green SHA do not constitute final acceptance.
The P10-H artifact records the actual source SHA/run after every prerequisite passes.
Existing Flutter `quality` and `verification` jobs remain mandatory on that SHA.

## Q01–Q20

| Requirement | Executable evidence | P10 CI gate |
| --- | --- | --- |
| Q01 normalized requests | `test/p10_building_generation_parameters_test.dart` | A |
| Q02 stable LevelId under renumber | `test/p10_building_level_stack_generator_test.dart`, `test/p106_vertical_core_hosts_test.dart` | A |
| Q03 repeated display numbers across buildings | `test/p10_building_level_stack_generator_test.dart`, `test/p109_site_composition_test.dart` | A, D |
| Q04 independent typical-floor instances | `test/p10_typical_floor*_test.dart` | A |
| Q05 real P9 geometry/topology/lineage | `test/p105_apartment_composition_test.dart`, `test/p105_composition_persistence_test.dart` | A |
| Q06 independent apartment edits | `test/p105_apartment_composition_test.dart`, `test/p105_composition_persistence_test.dart` | A |
| Q07 common corridor access | `test/p106_common_access_topology_test.dart` | A |
| Q08 typed core coverage/host lifecycle | `test/p106_vertical_core_hosts_test.dart`, `test/p106_common_core_lifecycle_test.dart` | A |
| Q09 cottage lifecycle | `test/p107_cottage_composition_test.dart`, `qualification_test/p10_p1013_golden_journeys_test.dart` GJ-COTTAGE-01 | B |
| Q10 tower lifecycle | `test/p108_tower_lifecycle_test.dart`, same qualification suite GJ-TOWER-01 | C |
| Q11 mixed three-building Site lifecycle | `test/p109_site_persistence_test.dart`, same qualification suite GJ-COMPLEX-01 | D |
| Q12 ten service purposes and exact hosts | `test/p1010_service_anchor*_test.dart` | E |
| Q13 Cancel leaves zero changes/previews | `test/p1011_commit_lifecycle_qualification_test.dart`, all families | F |
| Q14 concurrent mutation rejects stale Apply | same suite, all families | F |
| Q15 successful Preview then commit-time rejection | same suite, all families; shared commit guard before publication | F |
| Q16 one Undo and exact-ID Redo | same suite, all families; large GJs | B, C, D, F |
| Q17 nested parent/P9 evidence and overrides | `test/p1012*_test.dart`, current owner round trips and large GJs | B, C, D, E |
| Q18 generated entity deletion/tombstones/Undo/Redo | `test/p1012_composition_provenance_test.dart` | E |
| Q19 cross-platform semantics | `tool/p10_semantic_parity.dart`, `integration_test/p10_native_semantic_parity_test.dart`, `test_driver/p10_semantic_parity_driver.dart` | G |
| Q20 no transitional ownership or feature-local IO | `qualification_test/p10_p1013_architecture_qualification_test.dart`, production owner UI tests | A, F |

## Golden Journeys and scalability

One corpus in `qualification_test/support/p10_qualification_fixture.dart` feeds
native semantic artifacts and production lifecycle tests.

- GJ-COTTAGE-01: ground, upper residential level, roof, stair, electrical/telecom
  entries and all ten selected service purposes; 3 levels / 18 Spaces.
- GJ-TOWER-01: B2/B1, ground, 16 repeated residential floors with two real P9
  apartments each, technical level, roof, stair/elevator/service/electrical/telecom
  cores and service entries; 21 levels / 380 Spaces.
- GJ-COMPLEX-01: the same tower plus two differently stacked/placed cottages,
  repeated display floor numbers, shared anchors and independent IDs;
  3 buildings / 27 levels / 408 Spaces.

Each journey uses the existing mutation port and production persistence owner:
Generate → frozen Preview → Apply → one Undo/Redo → Save → Reopen → manual edit →
Undo/Redo → Save → Reopen. Full canonical bytes, apart from monotonic version,
are checked at restoration boundaries. P10-E additionally injects an asynchronous
repository Save rejection: the previous durable state remains intact, the accepted
in-memory composition remains owned, and retry persists complete v19 state.

This exercises the specification's hundreds-of-Spaces scalability requirement.
It does not establish a renderer FPS/GPU budget. A separately measured CAD frame
performance gate requires a controlled reference environment.

The local-edit audit found that a single room rename recreated all 598 parent
provenance members/baseline maps in a two-floor tower. Reconciliation now uses
the actual canonical diff plus placement, shared/service anchor, P7 host and
typical-definition metadata changes. It never trusts advisory command IDs.
Only affected members are reconciled; unchanged records/manifests, immutable
baselines, child bindings and derived ownership lookup/fingerprint are retained.
The same audit probe now replaces 1 member and 0 baseline maps. The projected
aggregate is constructed once per tracking operation, outside manifest loops.
`test/p1012_provenance_locality_test.dart` covers all three families, independent
compositions, metadata-only changes, repeated overrides, tombstones, frozen
candidate Apply, forged evidence rejection and exact Undo/Redo. Full aggregate
integrity validation remains mandatory; this is not a constant-time mutation or
frame-time claim.

## Native scope and CI

A–F run domain/application, production Wizard, persistence and lifecycle tests.
G emits the same semantic fixture data on Linux/macOS/Windows and on actual
Android phone/tablet emulators and iOS/iPadOS simulators. Desktop jobs also compile
the native application. Mobile jobs run the integration target through Flutter
Drive and capture its `reportData` through the host driver. An aggregate job
requires all seven artifacts and compares their decoded canonical semantics;
it never substitutes host-only tests for mobile results.

As in the existing P9 native qualification, missing platform shells are generated
in the isolated CI checkout for compilation/integration probes. These probes do
not assert app-store signing, distribution packaging or device GPU performance.
No Web production path is added.

H runs only after repository regression, A–F and all G targets/equality succeed.
Its artifact records `GITHUB_SHA` and `GITHUB_RUN_ID`. No failed/cancelled/missing
prerequisite may be treated as an accepted platform or accepted P10 stage.

Apple probes use `tool/p10_apple_simulator.py`: simulator choice is independent
of inventory ordering (newest installed available iOS runtime, then model/UDID),
with the exact selection retained in `selected.json`. Boot and Flutter Drive
have separate bounded timeouts; timeout terminates the probe's process group.
Verbose Drive/boot logs are retained on success and failure. Failure additionally
collects simulator inventory, Xcode version, Runner/debugserver/SpringBoard logs
and a screenshot, within bounded diagnostic steps. A probe failure remains a
failed gate; diagnostics or retries never substitute for a semantic artifact.
Python qualification tests verify selection and failed/timed-out subprocesses.

## Hard gates and release boundary

| Hard gate | Evidence |
| --- | --- |
| G1 canonical typed ownership | A, B, C, D, E |
| G2 typical-floor independence | A, C |
| G3 independent P9 edits | A, C, D |
| G4 multi-building identity | A, D, F |
| G5 core/service physical hosts | A, B, C, D, E |
| G6 frozen Preview and atomic single Undo | F; large B/C/D journeys |
| G7 persistence and complete lineage | B, C, D, E |
| G8 determinism across native platforms | G artifact equality |
| G9 fail-closed integrity | A, E, F |
| G10 P11/P12 physical readiness without engineering generation | A, B, C, D, E; unchanged architectural-only composition commands |

P10 is accepted for merge only after H plus repository `quality`/`verification`
are green on the same SHA and no known P10 blocker remains. Merge to `main` and a
new green post-merge exact-SHA run are separate requirements before formal P11
handoff. Each acceptance artifact identifies the source it actually qualifies.
