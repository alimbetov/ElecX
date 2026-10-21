# P5D-G qualification and closure note

Branch: `feat/project-structure-authoring`

P5D-G is the final qualification stage for the opt-in canonical Project North compass. It does not introduce new product scope. Its job is to prove that P5D-0 through P5D-F satisfy the hardened contract and that P5C behavior remains intact.

## Closure state

- P5D-F implementation is complete and hardened.
- Baseline P5D-F HEAD `3fab65b49bee9fbc850d92bb564fdf6ac28940a3` passed Flutter and macOS Desktop CI.
- P5D-G qualification code was added at `7424e64e22ac88359556c28e31ae6f5f3b9b0d4e`.
- The P5D-G code candidate passed formatter and Flutter analyze; the independent Flutter verification job also passed its full test suite before this note was authored.
- Final P5D-G closure requires the branch HEAD after this note/status update to pass the complete Flutter and macOS Desktop workflows.

## Qualification evidence

| Matrix | Evidence | Result |
| --- | --- | --- |
| D01-D06 | `editor_shell_state_test.dart`, `p5d_g_closure_test.dart` | opt-in visibility, focus suppression/restoration, presentation-only state |
| D07-D11 | `project_compass_overlay_test.dart`, `project_compass_projection_test.dart` | unspecified state and cardinal projection |
| D12-D14 | `project_orientation_test.dart`, `project_north_edit_dialog_test.dart` | deterministic normalization, strict persisted range, invalid input rejection |
| D15-D23 | `project_orientation_mutation_test.dart` | no-op, metadata-only commit, exact version increment, undo/redo, exact diff, mixed diff |
| D24-D28 | `canonical_project_document_codec_test.dart`, `p5d_g_closure_test.dart` | v1->v2 migration, explicit v2 null, exact integer round-trip, malformed fail-closed, fingerprint |
| D29 | `p5d_g_closure_test.dart` | canonical repository save/load preserves Project North |
| D30-D31 | `legacy_project_orientation_boundary_test.dart` | zero and non-zero legacy values remain unconfirmed without provenance |
| D32-D33 | `daylight_assist_engine_test.dart` plus semantic type split | legacy true-north azimuth behavior remains separate from canonical Project Engineering North |
| D34 | `project_compass_projection_test.dart` and production projection guard | unsupported modes resolve unavailable/fail closed |
| D35-D39 | production toggle uses semantic checked `IconButton`; overlay/shell widget tests | keyboard/semantics/pointer/focus behavior retained |
| D40 | `canonical_editor_runtime_cutover_test.dart`, `unified_workspace_canonical_cutover_test.dart`, full regression suite | P5C navigation/cutover unchanged |
| D41 | `p5d_g_closure_test.dart` | same-number Levels in different Buildings remain distinct identities |
| D42 | production `UnifiedWorkspaceEditorScreen` canonical path contains no `workspace.updateProjectNorth()` call | no legacy mutation fallback |
| D43 | `unified_workspace_canonical_cutover_test.dart` | Open/workspace replacement re-resolves canonical runtime |
| D44 | `project_compass_production_wiring_test.dart` | screen/canonical/persistence identity mismatch disables canonical edit |
| D45 | `CanonicalAuthoringOwnershipReceipt` contract explicitly states ownership is not durable-save acknowledgement | durability claim remains correct |
| D46 | `ProjectSyncGateway` still transports `EditorProjectDocument`; P5D spec explicitly forbids claiming canonical Project North preservation through that path | no false sync claim |
| D47 | `project_orientation_mutation_test.dart` | metadata-only changes keep `affectedEntityIds` empty |
| D48 | native-only repository layout and `pubspec.yaml`; no web dependency introduced by P5D | no browser scope creep |

## Additional P5D-G qualification added

`test/p5d_g_closure_test.dart` was added to close gaps that were not explicit in the earlier suites:

1. schema-v2 explicit `projectNorthMilliDegrees: null` round-trips as unspecified;
2. canonical JSON repository persistence preserves a specified Project North exactly;
3. shell compass visibility changes cannot mutate canonical version, metadata, undo or redo state;
4. duplicate user-facing level numbers across different buildings cannot alias structural identity or Project North ownership.

## Merge blockers reviewed

The P5D-G audit found no evidence of the prohibited architecture paths:

- no default-visible compass;
- no visibility-driven project mutation;
- no conflation of engineering Project North with daylight true-north compatibility;
- no provenance-free legacy promotion;
- no `0°` sentinel for unspecified state;
- no modulo-normalization of persisted corrupt data;
- no widget-owned canonical persistence;
- no fake entity mutation for root metadata;
- no store-only undo record after metadata became mutable;
- no production raw mutation bypass around the application edit port/P3;
- no canonical `workspace.updateProjectNorth()` fallback;
- no edit without exact runtime/persistence-owner identity affinity;
- no durable-save claim from synchronous ownership receipt;
- no misleading compass in unsupported/blocked modes;
- no viewport rotation, GPS, device-heading, georeferencing, P5E/P6/P7/P16 or web scope introduced for P5D.

## Final closure gate

P5D-G may be marked `DONE + HARDENED` only when the final branch HEAD containing this closure record passes:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
macOS Analyze
macOS Test
macOS debug build
macOS path_provider runtime smoke
```

Until that final HEAD is green, this document is a qualification record rather than a merge-complete declaration.
