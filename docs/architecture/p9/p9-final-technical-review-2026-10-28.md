# P9 Apartment Topology Generator — Final Technical Review

Date: 2026-10-28  
Branch: `feat/p9-apartment-topology-generator`

## Decision

```text
P9 = IMPLEMENTED, QUALIFICATION INCOMPLETE
```

P9.1-P9.12 are feature-complete and qualified. P9.13 acceptance-hardening is implemented, but P9 cannot be marked accepted until one exact final branch SHA passes the complete self-contained P9.13 workflow and is not behind `main`.

A green result from any older SHA does not qualify a newer code, test or documentation commit.

## Scope boundary

The authoritative P9 product feature is apartment topology generation:

```text
parameters
  -> deterministic candidate generation
  -> ranking / candidate selection
  -> vector preview
  -> P8 Preview/Diff reservation
  -> canonical materialization
  -> provenance
  -> persistence
  -> Apply / Undo / Redo
```

The D1-D8 apartment electrical engineering pipeline is an additive capability layered on the same frozen Wizard command. It must never invent authoritative electrical data merely to make P9 topology usable.

```text
topology-only
  no authoritative electrical pipeline is configured
  topology generation remains available
  no engineering proposal or electrical snapshot is created
  Preview explicitly states that electrical values were not assumed

engineering-enabled
  an authoritative ApartmentEngineeringPipeline is configured
  D8 output is frozen into the generated command
  Preview displays the exact frozen output
  Apply persists the same proposal without rerunning the pipeline
```

Silent fallback to fabricated electrical values is forbidden.

## Review findings and resolutions

### R1 — production Wizard composition could silently omit engineering

**CLOSED.** Production and topology-only provider construction are explicit. `ApartmentWizardProvider.production(...)` requires a pipeline; `ApartmentWizardProvider.geometryOnly()` is explicit topology-only mode. Runtime capability registration survives canonical mutations, Undo and Redo.

### R2 — full engineering orchestration started too late in the evidence chain

**CLOSED.** Production orchestration supports:

```text
D1 requirements
  -> authoritative supply evidence
  -> load calculation + evidence
  -> circuit synthesis + evidence
  -> exact synthesis lineage validation
  -> D2 -> D3 -> D4 -> D5 -> D6 -> D7 -> D8
```

Qualification fixture values are not production defaults.

### R3 — Preview hid the frozen D8 engineering output

**CLOSED.** `ApartmentEngineeringPreviewPanel` reads the exact `ApartmentEngineeringProposal` already frozen in `WizardSession.generatedCommand` and performs no engineering calculation. Engineering-enabled Preview exposes circuits, phase, cable/conductor sizing, overcurrent/RCD, fault/disconnection evidence, coordination, installation evidence, SLD, Why evidence and fingerprints. Topology-only Preview explicitly reports the no-electrical-assumptions state.

### R4 — applied engineering metadata was not first-class in canonical diff

**CLOSED.** `ProjectEngineeringMetadataDiff` tracks `appliedEngineeringProposalRegistryChanged`, so Apply/Undo/Redo engineering-snapshot changes are observable in the canonical change-set.

### R5 — persistence qualification stopped at codec level

**CLOSED.** Production-path qualification exercises:

```text
Wizard Apply
  -> ProjectMutationSession
  -> CanonicalProjectPersistenceOwner.acceptMutation
  -> JsonProjectRepository.save
  -> schema-v13 codec
  -> JsonProjectRepository.load
  -> exact engineering snapshot comparison
```

### R6 — stale/tampered Preview qualification was incomplete

**CLOSED.** Qualification proves stale base-version rejection, no stale engineering persistence, candidate-set lineage tamper rejection and no engineering rerun after a valid frozen Preview.

### R7 — repository hygiene contained generated analyzer/test output

**CLOSED.** Tracked generated analyzer/test logs are removed; `/analyze.log` and `/test.log` are ignored. CI output remains evidence, not source-controlled product state.

### R8 — production responsive policy diverged from authoritative P9 width classes

Historical production UI used implicit layout boundaries around 760/1100 while the authoritative contract defines:

```text
COMPACT     < 600
MEDIUM      600..1023
EXPANDED    1024..1439
LARGE       >= 1440
```

**REMEDIATED / EXACT-SHA REQUALIFICATION REQUIRED.** Production now reuses the shared `responsiveWidthClassFor` classification through `ElecXPresentationPolicy`. Accessibility/text scaling may reduce pane density, but cannot redefine the authoritative width class or affect semantic generation state. Qualification explicitly asserts 599/600, 1023/1024 and 1439/1440 boundaries.

### R9 — unsupported-but-valid candidate generation lost blocking reasons

**REMEDIATED / EXACT-SHA REQUALIFICATION REQUIRED.** `ApartmentWizardExplorationController` retains immutable failures for the current semantic revision. Production UI surfaces typed blocker cards while preserving request input and leaving the canonical project unchanged.

### R10 — compact/touch candidate navigation depended on gesture discovery

**REMEDIATED / EXACT-SHA REQUALIFICATION REQUIRED.** `WizardCandidateCarousel` now exposes explicit Previous/Next controls in addition to swipe and keyboard navigation. GJ-04 validates >=48dp controls and equivalent selection/Apply semantics for keyboard, mouse, touch and stylus-as-pointer.

### R11 — Golden Journey acceptance was incomplete

**REMEDIATED / EXACT-SHA REQUALIFICATION REQUIRED.** P9.13 now includes:

```text
GJ-01 exact 3-room / 78.5 m² journey
      Preview/Diff -> Apply -> Undo/Redo -> Save/Reopen
      -> manual rename -> canonical boundary geometry edit
      -> stable BoundaryEdgeIds -> field-aware provenance overrides -> reopen

GJ-02 existing multi-level / multi-building isolation

GJ-03 responsive continuity across phone/tablet/desktop,
      RU/EN, text scale/theme, compact full Diff and exact reserved Apply

GJ-04 keyboard / mouse / touch / stylus-as-pointer semantic equality
```

### R12 — negative-journey coverage had acceptance gaps

**REMEDIATED / EXACT-SHA REQUALIFICATION REQUIRED.** Dedicated P9.13 coverage was added for NG-02 unsupported valid request, NG-06 renderer rejection immutability and NG-07 repository-save failure durability. Existing regression tests remain authoritative anchors for NG-01/03/04/05/08/09/10. Mapping is recorded in `p9.13-requirement-traceability-v1.md`.

### R13 — specialized final workflow could pass without repository-wide quality gates

**CLOSED BY DESIGN / EXACT-SHA RUN REQUIRED.** `.github/workflows/p9-final-acceptance.yml` now has a repository-quality prerequisite that runs formatting, `flutter analyze`, P8 accessibility/i18n regressions and the complete Flutter test suite. `H exact-SHA final audit` depends on this plus all P9.13 A-G/native jobs.

### R14 — acceptance evidence and traceability were not repository-controlled

**CLOSED STRUCTURALLY.** Added:

```text
docs/architecture/p9/p9.13-requirement-traceability-v1.md
docs/architecture/p9/p9-acceptance-audit-v1-2026-10-28.md
```

The acceptance audit remains a living record until the final exact-SHA workflow and ancestry check are complete.

## P9.13 hard acceptance matrix

| Area | Current implementation/evidence | Merge disposition |
|---|---|---|
| A Domain 250 supported / 100 invalid / 1500 fuzz / x10 determinism | implemented; historical gate green | RECHECK FINAL SHA |
| A-C p95/p99/RSS | implemented; historical gate green | RECHECK FINAL SHA |
| B topology-only / engineering-enabled / frozen proposal | implemented | RECHECK FINAL SHA |
| C Preview/Diff / Apply / Undo/Redo / Save/Reopen | implemented | RECHECK FINAL SHA |
| GJ-01..04 | implemented/hardened | RECHECK FINAL SHA |
| NG-01..10 | mapped/implemented | RECHECK FINAL SHA |
| responsive phone/tablet/desktop | policy remediated | RECHECK FINAL SHA |
| Linux/macOS/Windows semantic equality | implemented; historical gate green | RECHECK FINAL SHA |
| Linux/Windows/macOS native builds | implemented; historical gates green | RECHECK FINAL SHA |
| Android native build | implemented; historical compile green | RECHECK FINAL SHA |
| iOS/iPadOS native build | implemented; historical compile green | RECHECK FINAL SHA |
| repository format/analyze/full regression suite | self-contained prerequisite added | RECHECK FINAL SHA |
| H exact-SHA audit | implemented | BLOCKED UNTIL ALL DEPENDENCIES PASS |

## Qualification anchors

```text
qualification_test/p9_p913_domain_qualification_test.dart
qualification_test/p9_p913_performance_qualification_test.dart
qualification_test/p9_p913_golden_journey_test.dart
qualification_test/p9_p913_additional_journeys_test.dart
qualification_test/p9_p913_responsive_matrix_test.dart
qualification_test/p9_p913_negative_journeys_test.dart

test/p9_apartment_wizard_provider_test.dart
test/p9_apartment_topology_catalog_test.dart
test/p9_apartment_vector_renderer_test.dart
test/p9_apartment_p8_preview_diff_integration_test.dart
test/p9_apartment_wizard_ui_acceptance_test.dart
test/p9_generation_provenance_test.dart

test/p9_p96_apartment_wizard_engineering_pipeline_test.dart
test/p9_p96_applied_engineering_persistence_test.dart
test/p9_p96_production_persistence_owner_test.dart
test/p9_p96_apartment_engineering_preview_panel_test.dart

tool/p9_semantic_parity.dart
.github/workflows/p9-final-acceptance.yml
```

## Invariants retained

```text
same request + semantic versions -> deterministic ordered candidate set
candidate browsing allocates no canonical IDs
Preview and Apply use the same reserved candidate/command
Apply is atomic through ProjectMutationSession
Undo/Redo operate on canonical state snapshots
provenance survives persistence
manual name/geometry changes become field-aware overrides
engineering fingerprints participate in reserved intent
no production electrical value is invented when authoritative input is absent
responsive/input transitions do not alter semantic reservation or project state
```

## Non-blocking forward dependencies

The Project Hub does not yet synthesize authoritative supply/load/PSCC data, so default runtime may legitimately remain topology-only. Production engineering-enabled mode requires authoritative supply/load/protection/catalog/policy inputs; that is a P11/P12 composition dependency, not a reason to reject P9 topology generation.

Permanent production-native shells for all platforms remain P17 scope. P9.13 may generate missing shells ephemerally in CI only to prove source-level native target compilation.

The P9.13 workflow currently selects Flutter via `channel: stable`; exact SDK pinning remains a reproducibility hardening item unless an authoritative repository SDK version is established. No arbitrary version should be invented merely to close the audit.

## Merge acceptance rule

`P9 = ACCEPTED FOR MERGE` is allowed only when all of the following are true on one exact final branch HEAD:

```text
Dart formatting                                      PASS
flutter analyze                                      PASS
P8 accessibility/i18n regressions                   PASS
complete flutter test                               PASS
A Domain qualification                              PASS
A-C performance + RSS                               PASS
B-C engineering + transactional                     PASS
GJ-01..04                                           PASS
NG-01..10                                           PASS
D-F responsive phone/tablet/desktop                 PASS
G Linux/macOS/Windows semantic equality             PASS
Linux/Windows/macOS native target compilation       PASS
Android native compile + responsive contract        PASS
iOS/iPadOS native compile + responsive contract     PASS
H exact-SHA final audit                             PASS
branch behind main                                  0
repository hygiene                                  PASS
```

Any newer commit reopens exact-SHA acceptance.

## Current disposition

```text
P9.1-P9.12 implementation          CLOSED
P9.13 acceptance hardening         IMPLEMENTED
P9.13 exact-final-SHA qualification OPEN
P9 overall                         IMPLEMENTED, QUALIFICATION INCOMPLETE
```
