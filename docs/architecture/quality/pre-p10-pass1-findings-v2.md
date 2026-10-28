# PRE-P10 PASS-1 Findings & Defect Register — v2

> **Status:** authoritative PASS-1 defect ledger; supersedes `pre-p10-pass1-findings-v1.md`  
> **Normative parent:** `pre-p10-cross-platform-hardening-plan-v1.md`  
> **Branch:** `feat/pre-p10-cross-platform-hardening`  
> **Accepted P9 baseline:** `0588294a443fc3179249e5e0ffeb59fc876448ad`  
> **First executable discovery SHA:** `b6e5fa0ed4279912aa35eb675cfa80a0f5fa3b0f`  
> **First executable discovery run:** `40644029080`

This document is part of the PRE-P10 technical specification. Every confirmed defect discovered by repository inspection or executable qualification is recorded here. A defect is not closed by a code change alone; closure requires repeatable regression evidence and, where applicable, cross-platform evidence on an exact SHA.

## 1. PASS-1 current disposition

PASS-1 is **IN PROGRESS / RED BY DESIGN**. The branch is not ready to unblock P10.

Current evidence has confirmed packaging, CI orchestration, startup UX, localization, responsive, runtime qualification and parity gaps. Production canonical persistence is wired and its static save algorithm is crash-conscious, but recovery boundaries are still being qualified executablely.

## 2. Defect register

| ID | Sev. | Status | Platforms | Area | Summary |
|---|---:|---|---|---|---|
| PRE10-D001 | P1 | CONFIRMED | Linux, Windows, Android, iOS/iPadOS | Native packaging | Required production native shells are absent; P9 CI generated temporary shells. |
| PRE10-D002 | P2 | CONFIRMED | All CI | Reproducibility | Acceptance uses Flutter `stable` rather than an immutable SDK version. |
| PRE10-D003 | P1 | CONFIRMED | All target platforms | Native runtime | Only macOS `path_provider` integration smoke exists; no full production runtime journey. |
| PRE10-D004 | P1 | CONFIRMED | CI / all targets | Qualification orchestration | Hardening branch is outside inherited full P9.13 and macOS push triggers; current PRE-P10 workflow is discovery-only. |
| PRE10-D005 | P2 | CONFIRMED | Linux, Windows, macOS | Startup input | PIN screen lacks direct top-row/numpad/backspace physical-key handling. |
| PRE10-D006 | P2 | CONFIRMED | All | Startup i18n | PIN screen contains hard-coded Russian strings under an RU/EN app contract. |
| PRE10-D007 | P1 | CONFIRMED | Phone landscape, desktop/high text scale; potentially all | Startup responsive/a11y | PIN startup overflows by 60–570 px in mandatory viewport/text-scale cases. |
| PRE10-D008 | P2 | CONFIRMED | All | Project Hub i18n | Project Hub/recovery/create-project UI is predominantly hard-coded Russian and contains mixed-language diagnostics. |
| PRE10-D009 | P1 | CONFIRMED | All native platforms | Storage-init recovery | Top-level native storage initialization failure exposes raw exception text and has no in-app Retry/recovery path. |
| PRE10-D010 | P3 | CONFIRMED | Engineering/docs | Architecture documentation | `JsonProjectRepository` comment says it is not wired into production although production Project Hub now uses it. |
| PRE10-D011 | P1 | CONFIRMED | Android, iOS/iPadOS | Semantic parity | Existing P9 parity artifacts are emitted only on Linux/macOS/Windows; Android/iOS semantic parity is not proven. |

P0 count: **0 confirmed**.  
P1 count: **6 confirmed** (`D001`, `D003`, `D004`, `D007`, `D009`, `D011`).  
P2 count: **4 confirmed** (`D002`, `D005`, `D006`, `D008`).  
P3 count: **1 confirmed** (`D010`).

---

## 3. PRE10-D001 — missing committed production native shells

**Status:** CONFIRMED  
**Severity:** P1  
**Platforms:** Linux, Windows, Android, iOS/iPadOS  
**Detected from:** accepted P9 baseline and PASS-1 tree inventory

**Expected:** every production platform has committed, reviewable platform files and builds without acceptance-time project generation.

**Actual:** repository has committed `macos/`, but no committed `linux/`, `windows/`, `android/` or `ios/`. P9 acceptance invokes `flutter create --platforms=...` on runners.

**Impact:** platform identifiers, manifests, permissions, plugin registration, lifecycle and packaging errors can remain invisible in source review.

**Root cause:** P9 used ephemeral shells to prove Flutter-layer portability before permanent packaging.

**Fix strategy:** after pinning Flutter, generate/review/minimize and commit all required shells; remove CI scaffolding from final PRE-P10 acceptance.

**Closure gate:** committed shells + native build + runtime smoke on all five platform families without `flutter create` during acceptance.

---

## 4. PRE10-D002 — Flutter SDK is not pinned

**Status:** CONFIRMED  
**Severity:** P2  
**Platforms:** all CI targets

**Expected:** same source SHA is always qualified with the same Flutter/Dart toolchain.

**Actual:** workflows use `subosito/flutter-action@v2` with `channel: stable`.

**Impact:** analyzer, rendering, plugin or build behavior can change for an unchanged source SHA after stable advances.

**Fix strategy:** introduce one repository-owned exact Flutter version and consume it in every hard acceptance job; record Flutter and Dart versions in the final audit.

**Closure gate:** no hard PRE-P10 acceptance job consumes unpinned `stable` alone.

---

## 5. PRE10-D003 — no full production-path native runtime qualification

**Status:** CONFIRMED  
**Severity:** P1  
**Platforms:** Linux, Windows, macOS, Android, iOS/iPadOS

**Evidence:** `integration_test/` contains only `path_provider_macos_smoke_test.dart`. That test proves one macOS plugin path; it does not exercise production startup, Project Hub, canonical persistence or P8/P9 runtime.

**Required runtime journey:** 

```text
native launch
→ ElecX root mounted
→ startup gate operable
→ Project Hub reachable
→ fixture/project opens
→ representative P8/P9 preview reachable
→ save/reopen succeeds
→ no uncaught native/plugin exception
```

**Impact:** plugin registration, native lifecycle, filesystem permission and platform navigation defects can escape build-only CI.

**Fix strategy:** shared runtime fixture + desktop runner smoke + Android emulator + iOS/iPadOS simulator smoke.

**Closure gate:** exact-SHA runtime evidence for every required platform family.

---

## 6. PRE10-D004 — PRE-P10 branch does not own a full automatic cross-platform gate

**Status:** CONFIRMED  
**Severity:** P1  
**Platforms:** CI / all targets

**Expected:** every commit on `feat/pre-p10-cross-platform-hardening` automatically executes the branch's complete mandatory quality matrix.

**Actual:** inherited `p9-final-acceptance.yml` push trigger is scoped to `main` and `feat/p9-apartment-topology-generator`; `desktop-macos.yml` is scoped to `main` and `fix/desktop-path-provider-packaging`. Generic `Flutter` runs for `feat/**` but only on Ubuntu. A new `pre-p10-pass1.yml` now owns discovery probes, but it is intentionally not yet the final five-platform matrix.

**Impact:** without a dedicated final workflow, a hardening SHA can be green on generic Linux CI while required platform qualification is absent.

**Fix strategy:** evolve the branch-owned PRE-P10 workflow into a complete matrix with repository quality, journeys, native build/runtime, five-platform parity and exact-SHA audit.

**Closure gate:** one push automatically creates all mandatory platform jobs and final audit depends on every hard gate.

---

## 7. PRE10-D005 — startup PIN lacks direct physical keyboard input

**Status:** CONFIRMED  
**Severity:** P2  
**Platforms:** Linux, Windows, macOS  
**Executable evidence:** `qualification_test/pre_p10_startup_qualification_test.dart`, `PRE10-Q02`, run `40644029080`, SHA `b6e5fa0ed4279912aa35eb675cfa80a0f5fa3b0f`

**Expected:** top-row digits and numpad digits enter PIN directly; Backspace/Delete removes the latest digit; four valid direct key entries advance to Project Hub.

**Actual:** Q02 sent `digit1`, `numpad2`, `digit3`, `backspace`, `digit3`, `digit4`; `PlatformProjectHubScreen` was not reached. Production PIN state changes only from on-screen button callbacks.

**Impact:** desktop startup is touch/pointer-first and materially weaker than native keyboard expectations.

**Fix strategy:** one keyboard/shortcut layer feeding the same PIN mutation methods used by buttons; preserve focus traversal and touch behavior.

**Closure gate:** Q02 plus Linux/Windows/macOS keyboard qualification passes.

---

## 8. PRE10-D006 — startup PIN bypasses RU/EN localization

**Status:** CONFIRMED  
**Severity:** P2  
**Platforms:** all  
**Executable evidence:** `PRE10-Q03`, run `40644029080`, SHA `b6e5fa0...`

**Expected:** English locale renders English startup copy; Russian locale renders Russian copy.

**Actual:** Q03 under `Locale('en')` still finds `Быстрый вход инженера`. Prototype explanatory copy is also hard-coded Russian.

**Impact:** the first application screen breaks end-to-end localization continuity.

**Fix strategy:** migrate startup copy into authoritative app/project localization resources and add RU/EN qualification.

**Closure gate:** EN contains no hard-coded Russian user-facing startup text; RU and EN both pass responsive/a11y probes.

---

## 9. PRE10-D007 — startup PIN is not responsive at mandatory short-height/text-scale cases

**Status:** CONFIRMED  
**Severity:** P1  
**Platforms/form factors:** phone landscape and desktop/high text scale; risk applies to all targets using this Flutter surface  
**Executable evidence:** `PRE10-Q01`, run `40644029080`, SHA `b6e5fa0...`

**Expected:** no RenderFlex overflow; keypad/backspace and startup actions remain reachable under mandatory viewport/text-scale matrix.

**Actual results:** 

| Case | Result |
|---|---:|
| 390×844, scale 1.0 | PASS |
| 844×390, scale 1.0 | **FAIL — overflow 166 px** |
| 844×390, scale 2.0 | **FAIL — overflow 570 px** |
| 800×600, scale 2.0 | **FAIL — overflow 360 px** |
| 768×1024, scale 2.0 | PASS |
| 1440×900, scale 2.0 | **FAIL — overflow 60 px** |

**Root cause:** `Center → ConstrainedBox(maxWidth:360) → Padding(32) → fixed Column` has no vertical scrolling/adaptive compaction and text scaling multiplies vertical demand.

**Impact:** startup can be unusable before any project functionality is reachable; violates mandatory accessibility and cross-platform form-factor gate.

**Fix strategy:** make startup layout height-aware and scroll-safe while preserving >=48 logical-pixel touch targets, semantics, keypad order and keyboard operation. Avoid clipping as a workaround.

**Closure gate:** Q01 passes all required sizes at textScale 1.0/1.3/2.0 with no overflow/unreachable controls.

---

## 10. PRE10-D008 — Project Hub bypasses the application localization contract

**Status:** CONFIRMED  
**Severity:** P2  
**Platforms:** all  
**Area:** Project Hub / recovery / create-project / diagnostics

**Expected:** user-facing Project Hub copy follows supported RU/EN localization.

**Actual static evidence:** `ProjectHubScreen` hard-codes Russian strings for create-project dialog, actions, Hub headings, empty states, recovery UI and retry UI, while one canonical-open diagnostic is English. Examples include `Проекты`, `Новый проект`, `Продолжить`, `Мои проекты`, `Аварийное восстановление`, `Повторить`, mixed with `Canonical project state could not be opened safely`.

**Impact:** full EN project lifecycle is impossible to qualify and diagnostic language is inconsistent.

**Fix strategy:** migrate Project Hub/recovery/create-project/diagnostic copy into shared localization resources; use typed localization access rather than inline literals.

**Closure gate:** RU/EN Hub journey from startup through create/open/recovery contains no unintended cross-language copy.

---

## 11. PRE10-D009 — top-level storage initialization failure has no in-app recovery

**Status:** CONFIRMED  
**Severity:** P1  
**Platforms:** all native platforms  
**Area:** `PlatformProjectHubScreen` / NG-12 / startup recovery

**Expected:** transient initialization failure provides a deterministic Retry/reopen path and localized actionable diagnostics; raw internal exceptions are not the primary user contract.

**Actual:** when `_openStores()` fails, `PlatformProjectHubScreen` renders a static error body containing `Не удалось инициализировать локальное хранилище ElecX.` plus raw `${snapshot.error}`. There is no Retry button or mechanism to recreate `_storesFuture`; access to Project Hub remains blocked until external restart/rebuild. By contrast, lower-level `ProjectHubScreen` already has a working retry pattern for project-list failure.

**Impact:** a transient path_provider/filesystem/plugin initialization error can make the entire project surface unrecoverable in-session.

**Fix strategy:** make store initialization retryable, preserve one error/retry presentation contract, localize it, log detailed technical error separately, and add injectable/open-store seam for deterministic qualification.

**Closure gate:** simulated first initialization failure → Retry → successful Project Hub on the same app session; verify no crash loop.

---

## 12. PRE10-D010 — stale canonical repository architecture comment

**Status:** CONFIRMED  
**Severity:** P3  
**Area:** architecture/documentation

**Expected:** source-level architecture comments describe current composition accurately.

**Actual:** `JsonProjectRepository` states that it is not wired into the production editor yet, while `PlatformProjectHubScreen` opens `openDefaultCanonicalProjectRepository()` and supplies it to `ProjectHubScreen`.

**Impact:** maintainers can make incorrect migration/cutover decisions from stale source documentation.

**Fix strategy:** update comment to describe current ownership/cutover state and remaining legacy projection seam accurately.

**Closure gate:** comment matches production composition and associated architecture document.

---

## 13. PRE10-D011 — Android/iOS semantic parity is not proven

**Status:** CONFIRMED  
**Severity:** P1  
**Platforms:** Android, iOS/iPadOS  
**Area:** cross-platform semantic parity

**Expected PRE-P10 invariant:** 

```text
fingerprint(Linux)
 == fingerprint(Windows)
 == fingerprint(macOS)
 == fingerprint(Android)
 == fingerprint(iOS/iPadOS)
```

**Actual:** P9 `semantic-parity` matrix emits artifacts only on `ubuntu-latest`, `macos-latest`, and `windows-latest`; byte equality compares only those three. Android and Apple mobile jobs build and execute common responsive tests but do not emit/compare platform semantic artifacts.

**Impact:** Flutter-layer algorithms are likely portable but PRE-P10 has no exact evidence that persisted/reopened semantic outputs on mobile are identical to desktop.

**Fix strategy:** emit the same canonicalized parity fixture from Android emulator and iOS/iPadOS simulator runtime, including persisted/reopened fingerprint, then compare normalized semantic artifacts across all five families.

**Closure gate:** exact-SHA five-family equality job PASS.

---

## 14. Verified non-defects / already-strong areas

### 14.1 Production canonical repository composition

Production `PlatformProjectHubScreen` already opens the canonical repository and passes it into `ProjectHubScreen`. Do not create a false defect claiming the canonical repository is disconnected.

### 14.2 Canonical JSON save algorithm

Static inspection shows pre-write codec round-trip validation, temporary write with flush, backup rotation, restore-on-failure and load fallback. No data-corruption defect is declared from static inspection.

### 14.3 Existing recovery/autosave behavior

Existing tests already cover:

- orphan recovery surfaced by Project Hub;
- recovery restore into editor;
- discard orphan recovery;
- autosave writes recovery without reporting project Saved;
- explicit Save clears recovery;
- in-flight autosave cannot resurrect recovery after Save;
- invalid cable save diagnostics.

PASS-1 therefore focuses new recovery probes on missing boundaries instead of duplicating these scenarios.

## 15. Executable discovery status

### Run 40644029080 — startup probes

```text
SHA: b6e5fa0ed4279912aa35eb675cfa80a0f5fa3b0f
Job: PASS1-Q01-Q03 startup discovery
Result: FAILURE (expected discovery signal)
Passed probes: 2
Failed probes: 6
```

Confirmed by this run:

- D005 direct keyboard failure;
- D006 English-locale failure;
- D007 responsive/text-scale overflow.

Diagnostic artifact:

```text
pre-p10-pass1-startup-b6e5fa0ed4279912aa35eb675cfa80a0f5fa3b0f
```

## 16. PASS-1 active probes

```text
Q01  startup responsive/text-scale           RED → D007
Q02  startup direct keyboard                 RED → D005
Q03  startup RU/EN localization              RED → D006
Q04  Project Hub list failure + Retry        RUNNING/next evidence
Q05  canonical primary/backup corruption     RUNNING/next evidence
Q06  production startup→hub→open→save/reopen TODO
Q07  full PRE-P10 CI ownership               RED → D004
Q08  committed native shells/build           RED → D001
Q09  five-family semantic parity             RED → D011
Q10  P1–P9 journey traceability              IN PROGRESS
```

## 17. Next priority order

1. Let Q04/Q05 complete and record exact evidence.
2. Add deterministic qualification seam for `PlatformProjectHubScreen` storage initialization and reproduce D009.
3. Fix startup cluster D005/D006/D007 together because they share one first-screen surface; keep separate defect IDs/evidence.
4. Pin Flutter before generating committed native shells so platform projects are generated by the accepted toolchain.
5. Commit/review native shells, then replace build-only evidence with true runtime smoke.
6. Extend semantic parity to Android/iOS runtime.
7. Complete P1–P9 requirement/journey → test → platform → CI traceability.

P10 remains blocked until PRE-P10 exact-SHA acceptance is green and all P0/P1/P2 dispositions satisfy the parent specification.
