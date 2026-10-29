# Pre-P10 Cross-Platform Hardening & Defect Discovery Plan v1

**Branch:** `feat/pre-p10-cross-platform-hardening`  
**Baseline:** P9 accepted exact SHA `0588294a443fc3179249e5e0ffeb59fc876448ad`  
**Purpose:** mandatory quality gate before P10 development  
**Scope:** existing ElecX functionality P1-P9 only; no P10 feature work in this branch

## 1. Decision

P10 must not start from a baseline that is merely buildable on one platform. Before P10, ElecX shall undergo a dedicated cross-platform hardening cycle covering functional correctness, UI/runtime defects, persistence, navigation, accessibility, localization, input modalities, negative/recovery journeys and semantic parity.

The exit state of this branch is not "tests added". The exit state is:

```text
EXISTING P1-P9 FUNCTIONALITY
        +
POSITIVE JOURNEYS
        +
NEGATIVE / RECOVERY JOURNEYS
        +
RESPONSIVE / A11Y / I18N
        +
NATIVE BUILD + RUNTIME SMOKE
        +
CROSS-PLATFORM SEMANTIC PARITY
        +
SAVE / REOPEN / UNDO / REDO
        +
EXACT-SHA FINAL AUDIT
        =
PRE-P10 BASELINE ACCEPTED
```

P10 development is blocked until the exact final SHA of this branch is accepted.

---

## 2. Mandatory platforms

All five platform families are first-class qualification targets.

| Platform | Native build | Runtime smoke | UI qualification | Semantic parity |
|---|---:|---:|---:|---:|
| Linux desktop | REQUIRED | REQUIRED | REQUIRED | REQUIRED |
| Windows desktop | REQUIRED | REQUIRED | REQUIRED | REQUIRED |
| macOS desktop | REQUIRED | REQUIRED | REQUIRED | REQUIRED |
| Android phone/tablet | REQUIRED | REQUIRED | REQUIRED | REQUIRED |
| iOS/iPadOS | REQUIRED | REQUIRED | REQUIRED | REQUIRED |

A platform may not be marked PASS because another platform passed equivalent tests.

### 2.1 Native shell rule

The final accepted baseline shall build from committed production platform shells. CI-only `flutter create` scaffolding is acceptable only as a temporary discovery aid and is not sufficient for final PRE-P10 acceptance.

The final gate shall verify that required platform project files are present in the repository and that the build does not depend on generated acceptance-only shell state.

---

## 3. Quality principles

### QP-01 — no silent platform degradation

A feature that exists on desktop but silently disappears or behaves differently on mobile is a defect unless explicitly specified by product requirements.

### QP-02 — semantic behavior is platform independent

For the same canonical request, catalog/profile/version input and deterministic seed/state, all platforms shall produce the same semantic result and canonical fingerprint.

UI geometry, native window chrome and OS-specific presentation metadata are excluded from semantic fingerprints.

### QP-03 — UI qualification is behavioral

A widget merely existing in the tree is insufficient. Primary actions must be reachable, visible or intentionally scrollable, focusable when applicable, and operable through the supported input modality.

### QP-04 — negative paths are first-class

Unsupported, stale, malformed, conflicting and interrupted flows must be tested for preserved state, clear diagnostics and zero unintended canonical mutation.

### QP-05 — exact-SHA evidence

An older green run never qualifies a newer SHA. Final acceptance is bound to one immutable commit.

---

## 4. Functional inventory to qualify

The branch shall build a traceability inventory from P1 through P9. At minimum the following functional families must have positive and negative coverage.

### F01 — application startup and root navigation

- cold start;
- opening the project surface;
- navigation between project/site/building/level/space contexts;
- back navigation;
- cancellation without mutation;
- route restoration after rebuild/reopen where supported.

### F02 — project lifecycle

- create project;
- edit project structure;
- save;
- close;
- reopen;
- canonical fingerprint equality after reopen;
- multi-building data preservation where already supported;
- no loss of IDs, provenance, navigation identity or engineering references.

### F03 — P1-P7 structural authoring

Qualify existing supported operations for:

- typed stable IDs;
- Site / Building / Level / Zone / Space CRUD;
- `SpaceType` vs `SpaceUsage` semantics;
- openings and boundary-hosted objects;
- adjacency;
- boundary IDs/remap;
- vertical/typical-floor references;
- navigator active context;
- command atomicity;
- `LocalProjectVersion` handling;
- Undo/Redo;
- failed command = no partial mutation;
- canonical fingerprint stability.

### F04 — P8 Wizard + Preview/Diff

- wizard startup;
- parameter editing;
- deterministic candidate generation;
- candidate selection;
- preview;
- diff;
- cancel;
- apply;
- Undo;
- Redo;
- save/reopen;
- keyboard/touch/pointer operation;
- reduced-motion behavior;
- EN/RU localization;
- text scaling.

### F05 — P9 apartment generator

Both runtime modes are mandatory:

```text
topology-only
engineering-enabled
```

Qualify:

- supported apartment requests;
- deterministic candidate ordering;
- frozen engineering proposal;
- preview/apply identity;
- provenance;
- boundary-host migration;
- topology-preserving geometry edits;
- persistence/reopen;
- Undo/Redo;
- no fabricated electrical fallback;
- RU/EN engineering preview;
- exact fingerprints.

---

## 5. Positive journey catalogue

The implementation shall maintain stable journey IDs.

### PJ-01 — create → edit → save → reopen

Create a project, perform representative structural edits, save and reopen. Assert canonical fingerprint equality.

### PJ-02 — structural CRUD chain

Create Site → Building → Level → Space, edit attributes, navigate among entities and persist.

### PJ-03 — opening / boundary-host lifecycle

Create hosted opening/object, perform topology-preserving boundary geometry edit, verify host identity/offset invariants, save and reopen.

### PJ-04 — command Undo/Redo

Apply multiple structural commands, undo all, redo all, verify fingerprints at each expected checkpoint.

### PJ-05 — P8 preview cancel

Generate wizard candidates, inspect preview/diff, cancel and prove canonical state unchanged.

### PJ-06 — P8 preview apply

Generate, select, preview, apply, save/reopen and verify identical canonical result.

### PJ-07 — P9 topology-only

Generate an apartment without engineering pipeline, verify no fabricated electrical proposal, apply and persist.

### PJ-08 — P9 engineering-enabled

Generate with authoritative engineering pipeline, verify frozen D8 proposal, preview/apply identity and persistence.

### PJ-09 — P9 geometry override

Apply apartment result, perform topology-preserving geometry edit, verify boundary-host migration and project validity.

### PJ-10 — cross-platform reopen fixture

Load the same canonical fixture on every platform and verify semantic fingerprint equality.

### PJ-11 — responsive continuity

Start a journey in one viewport/orientation, resize/rotate during editing/preview, continue without losing draft, selection or canonical state.

### PJ-12 — localization continuity

Execute EN and RU variants and verify behavior/fingerprint equivalence except localized presentation strings.

### PJ-13 — keyboard-only desktop journey

Complete representative project + wizard flow without mouse.

### PJ-14 — pointer/mouse desktop journey

Complete the same flow with pointer controls.

### PJ-15 — touch mobile/tablet journey

Complete representative project + wizard flow with touch controls.

---

## 6. Negative and recovery journeys

Negative journeys are mandatory acceptance tests, not optional robustness tests.

### NG-01 — invalid numeric input

Invalid/empty/out-of-range input must show a deterministic blocker and must not mutate canonical state.

### NG-02 — unsupported apartment combination

Unsupported request must preserve entered parameters, explain the blocker and perform zero canonical mutation.

### NG-03 — stale project version

A command with stale `LocalProjectVersion` must fail atomically.

### NG-04 — apply after project changed

If canonical state changed after preview/reservation, stale apply must be rejected or recomputed according to the existing contract; silent application is forbidden.

### NG-05 — duplicate/double Apply

Rapid or repeated Apply must not create duplicate canonical entities or duplicate Undo records.

### NG-06 — cancel/back during draft

Back/cancel shall not leak partial generated entities or corrupt navigation state.

### NG-07 — failed validation during mutation

Candidate graph validation failure must leave the original aggregate unchanged.

### NG-08 — boundary-host conflict

Geometry change that makes a hosted object invalid must produce an explicit conflict/blocker; silent orphaning is forbidden.

### NG-09 — persistence write failure

Simulated repository save failure must not report success and must not corrupt the previously persisted project.

### NG-10 — malformed/corrupt persisted input

Corrupt or unsupported persisted data must fail predictably with actionable diagnostics; no crash loop.

### NG-11 — missing referenced entity

Broken navigation/engineering/boundary reference must be detected by validation rather than causing a late UI crash.

### NG-12 — platform capability unavailable

Missing OS capability/plugin support must produce an explicit supported error/degraded state rather than a crash or silent no-op.

### NG-13 — interrupted/restarted operation

App rebuild/restart during a non-committed wizard flow must not persist partial canonical mutations.

### NG-14 — extreme text scale / short height

Critical actions must remain reachable at supported text scales and short landscape heights; no RenderFlex overflow may be accepted.

### NG-15 — orientation/resize during Preview

Changing orientation/window size during preview must not regenerate or silently change the selected candidate/reservation.

---

## 7. Responsive and UI matrix

Minimum viewport contract:

```text
PHONE
390 x 844
844 x 390

BREAKPOINTS
599 / 600
1023 / 1024
1439 / 1440

TABLET
768 x 1024
1024 x 768
1366 x 1024

DESKTOP
1280 x 720
1440 x 900
1920 x 1080

SHORT HEIGHT
800 x 600
844 x 390
```

At every relevant viewport:

- no `RenderFlex overflow`;
- no clipped required controls;
- no unreachable primary action;
- no hidden blocker/warning without an accessible route to it;
- scroll containers remain operable;
- modal/dialog content remains reachable;
- semantic operation result does not depend on viewport;
- current draft/selection survives resize and orientation change.

### 7.1 Accessibility matrix

Mandatory:

- text scale 1.0;
- text scale 1.3;
- text scale 2.0;
- EN;
- RU;
- light theme;
- dark theme;
- reduced motion;
- semantic labels for non-text controls;
- keyboard focus visibility;
- touch targets >= 48 logical px where applicable.

---

## 8. Cross-platform parity

The parity suite shall emit a canonical semantic artifact from each platform.

Required invariant:

```text
fingerprint(Linux)
 == fingerprint(Windows)
 == fingerprint(macOS)
 == fingerprint(Android)
 == fingerprint(iOS/iPadOS)
```

The artifact must bind at least:

- fixture/request ID;
- project schema version;
- algorithm/generator version;
- catalog/profile version where applicable;
- candidate ordering;
- selected candidate semantic key;
- canonical project fingerprint;
- persisted/reopened fingerprint;
- provenance fingerprint where applicable.

Byte equality may be used only for canonicalized artifacts with normalized line endings/ordering. Semantic equality remains authoritative.

---

## 9. Native runtime qualification

A build-only gate is not sufficient for final acceptance.

Each platform must prove at least:

```text
native launch
→ Flutter root mounted
→ project surface reachable
→ representative project fixture opens
→ representative P8/P9 preview reachable
→ save/reopen path executes where platform storage supports it
→ no uncaught platform/plugin exception
```

Desktop runtime smoke: Linux, Windows, macOS.  
Mobile/tablet runtime smoke: Android emulator/device and iOS/iPadOS simulator/device.

---

## 10. Defect management contract

Every defect found during this branch MUST be recorded in this document before or together with its fix. A defect is not considered closed merely because CI becomes green.

### 10.1 Mandatory defect fields

Each defect entry shall contain:

```text
ID
Title
Status
Severity
Detected on platform(s)
Affected functional area / P-stage
Exact detecting SHA
Reproduction / journey ID
Expected behavior
Actual behavior
Impact
Root cause
Fix strategy
Fix commit SHA
Regression test(s)
Cross-platform verification
Residual risk
Closure evidence / workflow run
```

### 10.2 Severity

- **P0** — data corruption, deterministic/canonical divergence, security/safety-critical failure, unusable primary flow, cross-platform semantic mismatch. Blocks all work.
- **P1** — major functional/UI/platform failure with no acceptable workaround. Blocks PRE-P10 acceptance.
- **P2** — important robustness/usability/reproducibility defect. Must be fixed or explicitly dispositioned before PRE-P10 acceptance.
- **P3** — cosmetic/non-blocking issue. May be deferred only with explicit rationale and owner.

### 10.3 Status vocabulary

```text
OPEN
CONFIRMED
FIX IN PROGRESS
FIXED / AWAITING QUALIFICATION
CLOSED
DEFERRED WITH ACCEPTED RISK
```

`CLOSED` requires an executable regression test or other repeatable evidence wherever technically possible.

---

## 11. Defect register

This table is authoritative and shall be updated continuously as defects are discovered.

| ID | Severity | Status | Platforms | Area | Summary |
|---|---|---|---|---|---|
| PRE10-D001 | P1 | CONFIRMED | Linux, Windows, Android, iOS/iPadOS | Native platform packaging | Repository baseline contains committed macOS shell, while other required platform shells are absent and P9 acceptance generates missing shells temporarily in CI. Final PRE-P10 acceptance requires committed production shells. |
| PRE10-D002 | P2 | CONFIRMED | All CI platforms | Reproducibility | Qualification workflows use `channel: stable` rather than an exact Flutter SDK version. The same exact project SHA can therefore be qualified by different Flutter/Dart toolchains over time. |
| PRE10-D003 | P1 | OPEN | All required platforms | Native runtime qualification | P9 proves native compilation and Flutter/widget semantics, but PRE-P10 requires true native runtime smoke per platform. Build success alone is insufficient. |

### PRE10-D001 — missing committed native shells

**Status:** CONFIRMED  
**Severity:** P1  
**Detected baseline:** `0588294a443fc3179249e5e0ffeb59fc876448ad`  
**Platforms:** Linux, Windows, Android, iOS/iPadOS

**Evidence:** repository root on the baseline contains `macos/` but no committed `linux/`, `windows/`, `android/` or `ios/` directories. P9 acceptance explicitly uses acceptance-only native shell scaffolding.

**Expected:** all target production platforms have committed, reviewable native shells and can build without generating platform projects during qualification.

**Actual:** final P9 acceptance could compile missing platforms only after CI generated temporary shells.

**Impact:** platform-specific configuration, permissions, plugins, package identity, signing-ready metadata and native lifecycle defects may remain invisible until later stages.

**Fix strategy:** generate/review/commit supported native shells, normalize identifiers/configuration, keep platform-specific files minimal, then build and runtime-smoke them directly.

**Closure:** OPEN until all required native shell gates pass without scaffolding.

### PRE10-D002 — Flutter SDK is not pinned

**Status:** CONFIRMED  
**Severity:** P2  
**Detected baseline:** `0588294a443fc3179249e5e0ffeb59fc876448ad`

**Expected:** exact-SHA acceptance is reproducible with an exact Flutter version (and therefore a known Dart toolchain).

**Actual:** workflow uses `subosito/flutter-action@v2` with `channel: stable`.

**Impact:** a later stable release can change analyzer behavior, rendering, tests, plugins or performance for the same project SHA.

**Fix strategy:** establish one repository-owned Flutter version source and use it in all hard acceptance jobs; record `flutter --version` in audit evidence.

**Closure:** OPEN until all PRE-P10 workflows consume the pinned version.

### PRE10-D003 — build-only evidence is insufficient as native runtime evidence

**Status:** OPEN  
**Severity:** P1  
**Platforms:** Linux, Windows, macOS, Android, iOS/iPadOS

**Expected:** each platform launches the real application shell and completes a minimal production-path smoke journey.

**Current evidence:** P9 final acceptance proves builds plus common Flutter semantic tests; this PRE-P10 branch intentionally raises the bar to native runtime qualification.

**Fix strategy:** add platform runtime smoke harnesses and capture exact-SHA evidence.

---

## 12. Defect discovery passes

The audit shall be executed in deliberate passes so that platform defects are not hidden by broad end-to-end failures.

### PASS-1 — repository and architecture integrity

- format/analyze;
- dependency health;
- generated/temp artifacts;
- native shell inventory;
- platform plugin inventory;
- persistence adapters;
- command/version invariants;
- deterministic fingerprints.

### PASS-2 — domain/application regression

- full unit/component suite;
- P1-P9 command invariants;
- save/reopen;
- Undo/Redo;
- stale-version handling;
- invalid graph handling;
- cross-platform fixture fingerprints.

### PASS-3 — UI functional audit

- all primary screens/actions;
- navigation/back/cancel;
- forms and validation;
- dialogs/sheets/snackbars;
- lazy materialization/scroll reachability;
- loading/error/empty states;
- duplicate action protection.

### PASS-4 — responsive/a11y/i18n

Run the required viewport × locale × text-scale × theme × reduced-motion matrix.

### PASS-5 — native desktop

Linux → Windows → macOS:

- committed shell build;
- launch;
- keyboard;
- pointer;
- resize;
- filesystem/persistence path;
- representative P8/P9 journey;
- close/reopen.

### PASS-6 — Android phone/tablet

- committed shell build;
- emulator/device launch;
- portrait/landscape;
- phone/tablet layouts;
- touch;
- system back;
- lifecycle/rebuild;
- persistence;
- representative P8/P9 journey.

### PASS-7 — iOS/iPadOS

- committed shell build;
- simulator/device launch;
- portrait/landscape;
- iPhone/iPad layouts;
- touch;
- lifecycle;
- persistence;
- representative P8/P9 journey.

### PASS-8 — negative/recovery campaign

Run NG-01..NG-15, inject repository/validation failures where appropriate, and verify zero silent corruption.

### PASS-9 — cross-platform parity

Produce and compare canonical artifacts from every platform family.

### PASS-10 — exact-SHA final audit

One unchanged SHA must pass every hard gate.

---

## 13. Required test/evidence structure

Recommended structure:

```text
qualification_test/pre_p10/
  pre_p10_domain_regression_test.dart
  pre_p10_positive_journeys_test.dart
  pre_p10_negative_journeys_test.dart
  pre_p10_responsive_matrix_test.dart
  pre_p10_semantic_parity_test.dart
  pre_p10_persistence_reopen_test.dart
  pre_p10_input_modality_test.dart

integration_test/pre_p10/
  pre_p10_app_smoke_test.dart
  pre_p10_project_lifecycle_test.dart
  pre_p10_p8_p9_smoke_test.dart

tool/pre_p10/
  emit_semantic_parity.dart
  compare_semantic_parity.dart
  verify_native_shells.dart
  build_acceptance_audit.dart

docs/architecture/quality/
  pre-p10-cross-platform-hardening-plan-v1.md
  pre-p10-requirement-traceability-v1.md
  pre-p10-final-acceptance-audit-v1-YYYY-MM-DD.md
```

The exact paths may change, but traceability is mandatory.

---

## 14. CI acceptance architecture

The final workflow shall contain at least these independent jobs:

```text
A repository-quality
B domain/application regression
C positive journeys
D negative/recovery journeys
E responsive/a11y/i18n
F desktop Linux native runtime
G desktop Windows native runtime
H desktop macOS native runtime
I Android phone/tablet native runtime
J iOS/iPadOS native runtime
K semantic parity emission
L semantic parity equality
M persistence/reopen parity
N exact-SHA final audit
```

`N exact-SHA final audit` must depend on all preceding hard gates.

No `continue-on-error` may mask a hard acceptance failure.

---

## 15. Traceability rule

Every hard requirement and every confirmed defect shall map to evidence:

```text
Requirement / Defect ID
→ test file
→ test name or runtime smoke step
→ CI job
→ final exact-SHA audit
```

A defect fix without regression evidence remains `FIXED / AWAITING QUALIFICATION`, not `CLOSED`.

---

## 16. Exit criteria / P10 start gate

P10 may start only when all of the following are true on one exact SHA:

- all P1-P9 existing functionality in traceability is green;
- all mandatory positive journeys pass;
- all mandatory NG/recovery journeys pass;
- Linux native build + runtime smoke pass;
- Windows native build + runtime smoke pass;
- macOS native build + runtime smoke pass;
- Android phone/tablet native build + runtime smoke pass;
- iOS/iPadOS native build + runtime smoke pass;
- responsive matrix passes;
- EN/RU and text scaling pass;
- accessibility and reduced motion pass;
- keyboard/pointer/touch modality gates pass;
- save/reopen fingerprint invariants pass;
- Undo/Redo invariants pass;
- semantic parity matches across all five platform families;
- no P0/P1 defects remain OPEN;
- no P2 defect remains without explicit disposition;
- native production shells are committed;
- exact Flutter SDK is pinned for acceptance;
- defect register is current;
- requirement/defect traceability is complete;
- final exact-SHA audit is committed or reproducibly generated and archived;
- branch is not behind its intended merge base.

Only then:

```text
PRE-P10 CROSS-PLATFORM BASELINE = ACCEPTED
P10 DEVELOPMENT = UNBLOCKED
```

Until then:

```text
P10 DEVELOPMENT = BLOCKED BY PRE-P10 HARDENING
```

---

## 17. Operating rule for this branch

All hardening work, all discovered defects, all fixes, all qualification tests, all evidence and final audit remain in:

```text
feat/pre-p10-cross-platform-hardening
```

Do not create per-defect feature branches for this hardening cycle unless repository policy later explicitly requires it.

Every newly discovered defect must be added to Section 11 before closure. If a defect materially changes acceptance scope, update the relevant requirement/journey section in this same document.