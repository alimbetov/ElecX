# PRE-P10 PASS-1 P1–P9 Traceability Inventory — v1

> **Branch:** `feat/pre-p10-cross-platform-hardening`  
> **Purpose:** PASS1-Q10 inventory of existing P1–P9 executable coverage before adding new qualification.  
> **Rule:** existing domain/widget tests are reused; PRE-P10 adds tests only where an acceptance layer is missing.

## 1. Coverage model

Each functional family is assessed in three independent layers:

```text
L1  domain/application correctness
L2  Flutter UI / production composition
L3  native runtime / platform integration
```

A strong L1 result does not imply L3 qualification. PRE-P10 acceptance requires all applicable layers.

Status vocabulary:

- **STRONG** — substantial positive + negative executable coverage exists;
- **PARTIAL** — useful tests exist, but a required journey/composition/platform boundary is missing;
- **GAP** — no adequate executable proof for the required acceptance layer;
- **N/A** — layer does not materially apply.

## 2. P1–P9 matrix

| Stage / family | L1 domain/application | L2 Flutter UI/composition | L3 native runtime | PASS-1 disposition |
|---|---|---|---|---|
| P1 foundation / lifecycle | STRONG | STRONG | GAP | Reuse core tests; add native production journey |
| P2 editor interaction foundation | STRONG | STRONG | GAP | Reuse interaction tests; qualify keyboard/pointer/touch on native targets |
| P3 command/mutation/change-set/undo | STRONG | PARTIAL | GAP | Core atomicity/stale/undo-redo strong; prove production UI path + native runtime |
| P4 structural CRUD | STRONG | PARTIAL | GAP | CRUD/destructive guards strong; add end-to-end project-structure journey |
| P5 navigation | STRONG | PARTIAL | GAP | Navigation state/projections strong; native back/focus/window lifecycle missing |
| P6 semantics/openings/adjacency | STRONG | STRONG | GAP | Existing production wiring tests reusable; native reachability still missing |
| P7 boundary/vertical/topology | STRONG | STRONG | GAP | Extensive adversarial/race/persistence tests; qualify representative native journey only |
| P8 Wizard Preview/Diff | STRONG | STRONG | PARTIAL | P8 acceptance is mature; native runtime launch/application path still missing |
| P9 Apartment generator | STRONG | STRONG | PARTIAL | P9.13 accepted; mobile semantic parity + persistent native runtime remain PRE-P10 gaps |
| Canonical persistence/recovery | STRONG | STRONG | PARTIAL | Q04/Q05 prove recovery core; native filesystem/plugin journey still required |
| Startup / root navigation | N/A | GAP | GAP | D005/D006/D007/D009; highest-priority UI/runtime repair |
| RU/EN application continuity | N/A | PARTIAL | GAP | P8/P9 localized; startup/Hub violate app-wide contract (D006/D008) |
| Cross-platform semantic parity | STRONG on desktop fixture | N/A | PARTIAL | Linux/macOS/Windows proven; Android/iOS missing (D011) |

## 3. Reused authoritative test families

### P1 — lifecycle / integrity

Representative executable coverage:

- `test/p1_lifecycle_acceptance_test.dart`
- `test/p1_integrity_hardening_test.dart`
- `test/editor_integrity_hardening_test.dart`
- `test/editor_project_persistence_test.dart`
- `test/project_recovery_and_save_diagnostics_test.dart`

Existing evidence includes saved/modified lifecycle, autosave recovery, preview-cancel cleanliness, guarded opening/boundary edits and interruption behavior.

### P2 — editor interaction foundation

Representative coverage:

- `test/p2_engine_test.dart`
- `test/editor_p2_session_test.dart`
- `test/interaction_hardening_regression_test.dart`
- `test/editor_interaction_policy_test.dart`
- `test/f17_scene_accessibility_test.dart`
- `test/f18_touch_target_acceptance_test.dart`
- `test/surface_canvas_interaction_test.dart`

PRE-P10 does not duplicate these algorithms; it verifies that supported native input devices can reach the same operations.

### P3 — mutation / preview / commit / undo / redo

Representative coverage:

- `test/project_mutation_test.dart`
- `test/project_mutation_reservation_test.dart`
- `test/project_commit_publisher_test.dart`
- `test/wizard_mutation_hardening_test.dart`

`project_mutation_test.dart` explicitly covers:

- one command = one version + one undo boundary;
- authoritative diff rather than command hints;
- preview without state/history mutation;
- semantic no-op;
- stale command fail-closed;
- invalid candidate fail-closed;
- monotonic Undo/Redo;
- redo clearing after a new command;
- stale Undo/Redo not consuming history.

Therefore P3 core semantics are **STRONG**. The missing acceptance layer is production/native reachability, not command correctness.

### P4 — structural CRUD

Representative coverage:

- `test/project_building_commands_test.dart`
- `test/project_level_commands_test.dart`
- `test/project_space_commands_test.dart`
- `test/project_structural_zone_commands_test.dart`
- `test/project_destructive_commands_test.dart`
- `test/project_structure_authoring_test.dart`
- `test/project_structure_authoring_controls_test.dart`
- `test/p4_boundary_dependency_destructive_guard_test.dart`
- `test/p4_vertical_core_destructive_guard_test.dart`
- `test/p4_structural_semantics_persistence_test.dart`

PASS-1 gap: one user-level create/edit/delete/save/reopen journey through production composition and representative native runtimes.

### P5 — navigation

Representative coverage:

- `test/project_navigation_state_test.dart`
- `test/project_navigator_projection_test.dart`
- `test/canonical_project_navigator_test.dart`
- `test/p5_level_semantics_test.dart`
- `test/project_structure_navigation_adoption_test.dart`
- `test/site_navigation_model_test.dart`

PASS-1 gap: native Back/Escape/focus/window-orientation lifecycle continuity.

### P6 — semantics / openings / adjacency

Representative coverage:

- `test/p6_semantic_mutation_test.dart`
- `test/p6_semantic_persistence_test.dart`
- `test/p6_adjacency_pair_framing_regression_test.dart`
- `test/p6_adjacency_symmetry_regression_test.dart`
- `test/p6_hosted_opening_dependency_regression_test.dart`
- `test/p6_overlay_remove_failclosed_regression_test.dart`
- `test/p6f_space_semantics_production_wiring_test.dart`
- `test/p6e_opening_projection_regression_test.dart`

Existing coverage is sufficient for core reuse. Native runtime qualification should exercise representative semantics/edit/opening operations rather than clone the whole test suite per OS.

### P7 — stable boundaries / hosts / vertical topology

Representative coverage is extensive, including:

- `test/p7a45_canonical_topology_editing_test.dart`
- `test/p7a45_production_topology_editing_test.dart`
- `test/p7a5_atomic_topology_host_migration_test.dart`
- `test/p7a5_boundary_host_migration_test.dart`
- `test/p7a5_persistence_opening_ownership_test.dart`
- `test/p7a5_production_topology_migration_runtime_test.dart`
- `test/p7a61_deep_history_race_test.dart`
- `test/p7a61_postcommit_projection_failure_test.dart`
- `test/p7a63_lifecycle_interruption_test.dart`
- `test/p7a65_unified_chronology_stress_test.dart`
- `test/p7a66_route_anchor_persistence_test.dart`
- `test/p7a67_pathological_geometry_test.dart`
- vertical-core command, continuity, route and persistence suites.

Disposition: **do not repeat the adversarial matrix on every native OS**. Run full deterministic Flutter suite once in repository-quality, then run a compact representative native journey that proves platform composition does not block P7 behavior.

### P8 — Wizard + Preview/Diff

Representative coverage:

- `test/p8_project_hub_wizard_flow_test.dart`
- `test/p8_wizard_golden_journey_test.dart`
- `test/p8_wizard_behavior_matrix_test.dart`
- `test/p8_wizard_crash_window_recovery_test.dart`
- `test/p8_wizard_noop_qualification_test.dart`
- `test/p8_wizard_reliability_stress_test.dart`
- `test/p8_wizard_responsive_carousel_qualification_test.dart`
- `test/p8_wizard_nfr_a11y_i18n_qualification_test.dart`
- `test/p8_wizard_r23_extended_qualification_test.dart`

Disposition: L1/L2 **STRONG**. PRE-P10 adds production startup/native runtime reachability, not a second P8 acceptance program.

### P9 — apartment generator

Authoritative existing traceability:

- `docs/architecture/p9/p9.13-requirement-traceability-v1.md`
- `qualification_test/p9_p913_domain_qualification_test.dart`
- `qualification_test/p9_p913_golden_journey_test.dart`
- `qualification_test/p9_p913_additional_journeys_test.dart`
- `qualification_test/p9_p913_negative_journeys_test.dart`
- `qualification_test/p9_p913_responsive_matrix_test.dart`
- `qualification_test/p9_p913_performance_qualification_test.dart`

P9.13 exact-SHA acceptance already proved domain, deterministic, engineering, transactional, responsive, native build and desktop semantic parity.

PRE-P10 remaining P9-specific gaps:

- D003 production native runtime journey;
- D011 Android/iOS semantic parity;
- D001 real committed platform shells instead of generated acceptance shells.

## 4. Persistence / recovery traceability

Existing reusable tests:

- `test/canonical_json_project_repository_test.dart`
- `test/canonical_project_document_codec_test.dart`
- `test/editor_project_persistence_test.dart`
- `test/project_hub_persistence_test.dart`
- `test/project_hub_recovery_test.dart`
- `test/project_recovery_and_save_diagnostics_test.dart`
- multiple P6/P7/P9 persistence suites.

PRE-P10 Q04/Q05 adds missing boundary evidence:

- Project Hub list failure → visible Retry → recovery on second attempt;
- corrupt canonical primary → valid `.bak` fallback;
- corrupt primary + corrupt backup → predictable failure;
- corrupt project does not hide healthy projects from `list()`.

Result on discovery SHA `d97f246f68f4e8b375b6e4ae1868d4f4e716ff08`, run `40644464749`: **PASS**.

Disposition: no new canonical repository defect from Q04/Q05. D009 remains separate because it concerns the higher `PlatformProjectHubScreen` store-initialization boundary.

## 5. Acceptance gaps discovered by Q10

### G10-01 — no single production P1–P7 user journey

Core tests are strong but fragmented by layer. PRE-P10 needs a compact product journey proving that the production composition can execute representative structural operations end-to-end:

```text
startup
→ Project Hub
→ create/open project
→ Site/Building/Level/Space operation
→ navigation
→ canonical mutation
→ Undo
→ Redo
→ Save
→ Reopen
→ fingerprint/state verification
```

This is an **acceptance coverage gap**, currently tracked under D003/D004 rather than a separate product defect until an executable journey reveals incorrect behavior.

### G10-02 — native platform tests must be representative, not exhaustive duplication

The full deterministic Flutter suite remains the authoritative semantic regression suite. Native platform qualification should prove:

- production app starts;
- platform plugins/filesystem work;
- supported input can drive critical controls;
- production navigation reaches representative P1–P9 functions;
- save/reopen works;
- semantic fingerprint matches the shared fixture.

This avoids five copies of thousands of domain assertions while still finding platform defects.

### G10-03 — startup/Hub are currently the weakest cross-platform layer

Unlike P6–P9 feature surfaces, startup and Project Hub were not brought under the same localization/responsive/input qualification discipline. This is already materialized as D005–D009.

## 6. PASS-1 Q10 conclusion

```text
P1–P7 core semantics        STRONG
P8 core + Flutter UI        STRONG
P9 core + Flutter UI        STRONG
canonical recovery core     STRONG (Q04/Q05 PASS)

startup/root UI             RED
Project Hub app-wide i18n   RED
native committed packaging  RED
native production runtime   RED
mobile semantic parity      RED
full PRE-P10 CI ownership   RED
```

The next work should therefore prioritize platform/application-shell hardening before inventing more domain tests.

## 7. Required next qualification journeys

```text
PRE10-J01  production startup → Hub → create/open → structural edit → Undo/Redo → Save/Reopen
PRE10-J02  startup RU/EN + responsive + keyboard/touch continuity
PRE10-J03  platform store-init failure → Retry → Hub in same session
PRE10-J04  representative P8 Preview/Diff through production native runtime
PRE10-J05  representative P9 Generate/Preview/Apply through production native runtime
PRE10-J06  shared semantic fixture persisted/reopened on Linux/Windows/macOS/Android/iOS
```

These journeys are additive acceptance glue around already-tested P1–P9 semantics. Any functional failure found by them must receive the next `PRE10-Dxxx` ID before or together with its fix.
