# PRE-P10 PASS-1 Findings & Defect Register — v1

> **Normative annex to:** `pre-p10-cross-platform-hardening-plan-v1.md`  
> **Branch:** `feat/pre-p10-cross-platform-hardening`  
> **PASS-1 detecting SHA:** `221cac0911b7d94bc78d323cb82a7ea836cd9acf`  
> **Baseline inherited from accepted P9:** `0588294a443fc3179249e5e0ffeb59fc876448ad`

This document is an integral part of the PRE-P10 technical specification. Every confirmed PASS-1 defect is recorded here before or together with its fix. The parent plan remains the acceptance contract; this annex is the live defect/evidence ledger for PASS-1.

## 1. PASS-1 scope

PASS-1 inventories the existing P1–P9 implementation before any P10 work. The review covers:

- repository/platform packaging;
- GitHub Actions and exact-SHA qualification coverage;
- application startup and root navigation;
- production persistence composition;
- Project Hub / editor composition;
- keyboard, pointer and touch input surfaces;
- localization, accessibility and responsive risks;
- positive journeys;
- negative/recovery journeys;
- native runtime qualification coverage;
- cross-platform semantic parity coverage.

No P10 product functionality belongs in this pass.

## 2. PASS-1 verified facts

### 2.1 Production canonical persistence is wired

`PlatformProjectHubScreen` opens the default editor store, recovery store and `openDefaultCanonicalProjectRepository()` before constructing `ProjectHubScreen`. `openDefaultCanonicalProjectRepository()` resolves the application documents directory and creates the canonical JSON repository using `AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec`.

**Disposition:** this is **not a defect**. Earlier comments in `JsonProjectRepository` that describe the adapter as not yet wired are stale documentation, but production composition itself is connected.

### 2.2 Canonical JSON save path is crash-conscious

The canonical JSON repository validates encode/decode stability before replacing the current project, writes a `.tmp`, moves the previous target to `.bak`, promotes the temporary file, restores the backup on failure, and can load from the backup if the primary is invalid.

**Disposition:** no PASS-1 persistence-corruption defect is registered from static inspection. NG-09 and NG-10 remain mandatory executable qualification scenarios.

### 2.3 Native integration-test inventory is incomplete

`integration_test/` currently contains only:

```text
path_provider_macos_smoke_test.dart
```

There is no equivalent committed runtime integration smoke for Linux, Windows, Android or iOS/iPadOS, and the macOS smoke only proves `path_provider`, not the full production startup → Project Hub → project open/save journey.

### 2.4 Current workflow coverage is not sufficient for this hardening branch

- Generic `Flutter` CI runs for `feat/**`, but only on Ubuntu.
- `P9.13 Final Acceptance` push trigger is limited to `main` and `feat/p9-apartment-topology-generator`.
- `macOS Desktop` push trigger is limited to `main` and `fix/desktop-path-provider-packaging`.
- Therefore a push to `feat/pre-p10-cross-platform-hardening` does not automatically execute the inherited full P9.13 cross-platform matrix or the dedicated macOS runtime workflow.

### 2.5 App startup surface is not fully cross-platform qualified

`ElecXApp` advertises the project localizations and starts at `PinUnlockScreen`. The PIN screen uses clickable/tappable `TextButton` keypad controls, but has no direct physical digit/numpad/backspace shortcut handling. It also hard-codes Russian startup strings outside the localization contract.

## 3. Authoritative defect register after PASS-1 inventory

| ID | Severity | Status | Platforms | Area | Summary |
|---|---|---|---|---|---|
| PRE10-D001 | P1 | CONFIRMED | Linux, Windows, Android, iOS/iPadOS | Native packaging | Required committed production platform shells are absent; P9 CI generated temporary shells. |
| PRE10-D002 | P2 | CONFIRMED | All CI platforms | Reproducibility | Hard qualification uses Flutter `stable` instead of one pinned SDK/toolchain. |
| PRE10-D003 | P1 | CONFIRMED | Linux, Windows, macOS, Android, iOS/iPadOS | Native runtime qualification | Only a macOS `path_provider` integration smoke exists; full production-path runtime smoke is absent on every required platform. |
| PRE10-D004 | P1 | CONFIRMED | CI / all target platforms | Qualification orchestration | The PRE-P10 branch does not automatically run the inherited full cross-platform acceptance or dedicated macOS workflow on push. |
| PRE10-D005 | P2 | CONFIRMED | Linux, Windows, macOS | Startup / keyboard UX | PIN startup screen has no direct physical digit, numpad or backspace handling; desktop keyboard interaction relies on focus traversal through on-screen buttons. |
| PRE10-D006 | P2 | CONFIRMED | All platforms | Startup / i18n | Application declares localized RU/EN support, but the startup PIN screen contains hard-coded Russian strings. |

The register must be extended with `PRE10-D007+` only for evidence-backed findings. Suspected issues are not promoted to defects until static evidence is conclusive or an executable qualification test reproduces them.

---

## 4. PRE10-D001 — missing committed production native shells

**Status:** CONFIRMED  
**Severity:** P1  
**Detected SHA:** `221cac0911b7d94bc78d323cb82a7ea836cd9acf`  
**Platforms:** Linux, Windows, Android, iOS/iPadOS  
**Area:** packaging / native lifecycle

**Reproduction / evidence:** repository root contains committed `macos/`, but no committed `linux/`, `windows/`, `android/` or `ios/` platform projects. P9 acceptance calls `flutter create --platforms=...` in CI to compensate.

**Expected:** every production target has a committed, reviewable native shell and can build without generating native project state during acceptance.

**Actual:** four required platform families depend on acceptance-time scaffolding.

**Impact:** platform identifiers, manifests, permissions, plugin registration, lifecycle settings and packaging defects can remain invisible in source review.

**Root cause:** P9 qualification intentionally used ephemeral native shells to prove Flutter-layer portability before permanent platform packaging existed.

**Fix strategy:** generate the missing shells using the repository-pinned Flutter version, review/minimize platform diffs, normalize product identifiers and permissions, commit the shells, then remove acceptance-only scaffolding.

**Regression/closure:** native build plus runtime smoke on Linux, Windows, Android and iOS/iPadOS with no `flutter create` in the acceptance workflow.

---

## 5. PRE10-D002 — Flutter SDK is not pinned

**Status:** CONFIRMED  
**Severity:** P2  
**Detected SHA:** `221cac0911b7d94bc78d323cb82a7ea836cd9acf`  
**Platforms:** all CI platforms  
**Area:** reproducibility

**Expected:** exact-SHA acceptance runs with one repository-owned Flutter SDK version and therefore a stable Dart/toolchain baseline.

**Actual:** workflows use `subosito/flutter-action@v2` with `channel: stable`.

**Impact:** the same code SHA can later produce different analyzer, rendering, plugin, performance or build results after the stable channel advances.

**Root cause:** P8/P9 workflows optimized for current stable Flutter rather than immutable acceptance reproduction.

**Fix strategy:** add one authoritative SDK version source and consume it in every PRE-P10 build/test job; include exact Flutter/Dart versions in final audit evidence.

**Regression/closure:** all required workflows use the same explicit SDK version and the exact-SHA audit records it.

---

## 6. PRE10-D003 — no production-path native runtime qualification

**Status:** CONFIRMED  
**Severity:** P1  
**Detected SHA:** `221cac0911b7d94bc78d323cb82a7ea836cd9acf`  
**Platforms:** Linux, Windows, macOS, Android, iOS/iPadOS  
**Area:** native runtime / plugins / persistence

**Reproduction / evidence:** `integration_test/` contains only `path_provider_macos_smoke_test.dart`. That test proves one plugin resolves an application-support directory on macOS. There is no committed native runtime journey for Linux, Windows, Android or iOS/iPadOS and no existing native integration journey that launches the production app, reaches Project Hub, opens a canonical project and exercises save/reopen.

**Expected minimum journey:** 

```text
native launch
→ ElecX root mounted
→ startup gate operable
→ Project Hub reachable
→ canonical fixture opens
→ representative P8/P9 preview reachable
→ save/reopen succeeds
→ no uncaught native/plugin exception
```

**Actual:** P9 acceptance proves native compilation and Flutter-level semantics, not this production runtime chain.

**Impact:** platform plugin registration, filesystem permissions, startup lifecycle and navigation/runtime failures can escape build-only CI.

**Fix strategy:** implement platform runtime smoke harnesses and a shared semantic fixture; execute on desktop runners plus Android emulator and iOS simulator.

**Regression/closure:** exact final SHA has native runtime evidence for all five platform families.

---

## 7. PRE10-D004 — hardening branch is outside full acceptance push triggers

**Status:** CONFIRMED  
**Severity:** P1  
**Detected SHA:** `221cac0911b7d94bc78d323cb82a7ea836cd9acf`  
**Platforms:** CI / all target platforms  
**Area:** qualification orchestration

**Reproduction:** push a change only to `feat/pre-p10-cross-platform-hardening`.

**Expected:** every hardening commit automatically receives the branch's mandatory cross-platform quality matrix so platform regressions are detected at the introducing SHA.

**Actual:** `p9-final-acceptance.yml` push branches are only `main` and `feat/p9-apartment-topology-generator`. `desktop-macos.yml` push branches are only `main` and `fix/desktop-path-provider-packaging`. The generic Flutter workflow does run for `feat/**`, but only on Ubuntu and therefore cannot substitute for the missing matrix.

**Impact:** a PRE-P10 commit can be green in generic CI while Windows/macOS/mobile qualification never starts automatically.

**Root cause:** workflows were scoped to the feature branch that originally owned P9 acceptance and were not generalized after creating the cross-platform hardening phase.

**Fix strategy:** create a dedicated PRE-P10 workflow (preferred) or safely extend existing triggers. The dedicated workflow must own all PRE-P10 gates and exact-SHA final audit rather than depending on P9-named workflow semantics.

**Regression/closure:** a push to this branch automatically starts Linux/Windows/macOS/Android/iOS-iPadOS qualification and a failed platform job blocks the final audit.

---

## 8. PRE10-D005 — startup PIN lacks direct physical keyboard input

**Status:** CONFIRMED  
**Severity:** P2  
**Detected SHA:** `221cac0911b7d94bc78d323cb82a7ea836cd9acf`  
**Platforms:** Linux, Windows, macOS  
**Area:** F01 startup / PJ-13 keyboard journey / accessibility

**Expected:** desktop startup supports an efficient physical keyboard path: top-row digits and numpad digits enter the PIN, Backspace/Delete removes the last digit, and focus semantics remain usable without pointer input.

**Actual:** `PinUnlockScreen` only mutates PIN state from on-screen `TextButton.onPressed` callbacks. A keyboard-only user may traverse buttons with focus, but direct digit/numpad/backspace key handling is absent.

**Impact:** desktop input behavior is materially weaker than native expectations and makes the startup gate the weakest point of an otherwise keyboard-qualified engineering workflow.

**Root cause:** startup gate was implemented as a touch-first prototype keypad and never brought under the later desktop input policy.

**Fix strategy:** add a focused keyboard/shortcut layer with deterministic digit/numpad/backspace handling while retaining button semantics and touch interaction. Do not duplicate business state between keyboard and pointer paths.

**Regression tests:** startup keyboard qualification covering digit row, numpad, backspace, rapid input, focus traversal and navigation after four digits.

**Cross-platform verification:** Linux/Windows/macOS keyboard tests plus unchanged Android/iOS touch behavior.

---

## 9. PRE10-D006 — startup PIN bypasses the RU/EN localization contract

**Status:** CONFIRMED  
**Severity:** P2  
**Detected SHA:** `221cac0911b7d94bc78d323cb82a7ea836cd9acf`  
**Platforms:** all platforms  
**Area:** F01 startup / PJ-12 localization / accessibility

**Expected:** all user-visible startup strings follow the same RU/EN localization contract advertised by `ElecXApp.supportedLocales` and its localization delegates.

**Actual:** `PinUnlockScreen` hard-codes at least:

```text
Быстрый вход инженера
Prototype: PIN — локальная быстрая разблокировка, не замена учётной записи.
```

These strings remain Russian when the application locale is English.

**Impact:** the very first screen violates application-level localization continuity and invalidates a complete EN startup journey.

**Root cause:** the prototype PIN screen predates the shared wizard/project localization surface and was not migrated into the localization resource.

**Fix strategy:** move startup strings into the authoritative localization contract, add RU/EN values and test locale switching at app startup.

**Regression tests:** render/startup qualification under RU and EN, assert localized semantics and no hard-coded user-facing Russian remains in the startup surface.

---

## 10. Discovery hypotheses — not yet registered as defects

The following items require executable evidence before receiving a `PRE10-Dxxx` ID:

1. **PIN short-height/textScale overflow risk.** `PinUnlockScreen` uses a centered, fixed `Column` with large padding and no scroll container. Test at 390×844, 844×390, 800×600 and textScale 1.0/1.3/2.0.
2. **Startup focus visibility/order.** Verify deterministic focus order and visible focus indicators across Linux, Windows and macOS.
3. **Project Hub storage-init error localization/recovery.** The production storage initialization error text is hard-coded Russian; verify whether the screen exposes retry/recovery and whether this must become a separate defect.
4. **Persistence recovery completeness.** Static repository inspection looks crash-conscious, but NG-09/NG-10 must exercise write interruption, corrupt primary with valid backup, corrupt primary+backup, and Project Hub behavior.
5. **Full Android/iOS semantic parity.** P9 emitted parity on Linux/macOS/Windows only; PRE-P10 requires Android and iOS/iPadOS parity artifacts as well.

No hypothesis may be marked CLOSED or CONFIRMED without repeatable evidence.

## 11. PASS-1 next executable probes

Priority order:

```text
PASS1-Q01 startup responsive/text-scale matrix
PASS1-Q02 startup keyboard + focus semantics
PASS1-Q03 startup RU/EN localization
PASS1-Q04 Project Hub storage-init failure/retry
PASS1-Q05 canonical repository crash/recovery matrix
PASS1-Q06 production startup → hub → open → save/reopen widget/integration journey
PASS1-Q07 CI trigger self-test / PRE-P10 matrix
PASS1-Q08 native shell inventory/build without scaffolding
PASS1-Q09 Android/iOS semantic parity artifact emission
PASS1-Q10 P1-P9 journey traceability inventory
```

Each failed probe must create the next `PRE10-Dxxx` record before the fix is merged into this branch.
