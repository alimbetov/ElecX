# PRE-P10 PASS-1 Findings & Defect Register — v3

> **Status:** authoritative PASS-1 defect ledger; supersedes v1/v2  
> **Normative parent:** `pre-p10-cross-platform-hardening-plan-v1.md`  
> **Branch:** `feat/pre-p10-cross-platform-hardening`  
> **Accepted P9 baseline:** `0588294a443fc3179249e5e0ffeb59fc876448ad`

PASS-1 remains **IN PROGRESS** and P10 remains blocked. A defect is not CLOSED until its fix is proven by the required exact-SHA regression/platform evidence.

## 1. Current defect register

| ID | Sev. | Status | Platforms | Area | Summary |
|---|---:|---|---|---|---|
| PRE10-D001 | P1 | CONFIRMED | Linux, Windows, Android, iOS/iPadOS | Native packaging | Required committed native shells are absent; P9 CI generated temporary shells. |
| PRE10-D002 | P2 | CONFIRMED | All CI | Reproducibility | Acceptance uses Flutter `stable` rather than an immutable SDK version. |
| PRE10-D003 | P1 | CONFIRMED | All target platforms | Native runtime | No full production-path native runtime qualification exists. |
| PRE10-D004 | P1 | CONFIRMED | CI / all targets | Qualification orchestration | PRE-P10 currently owns discovery probes, not yet the complete five-platform final gate. |
| PRE10-D005 | P2 | FIXED / AWAITING QUALIFICATION | Linux, Windows, macOS | Startup input | PIN direct physical digit/numpad/backspace handling was missing. |
| PRE10-D006 | P2 | FIXED / AWAITING QUALIFICATION | All | Startup i18n | PIN contained hard-coded Russian under an RU/EN app contract. |
| PRE10-D007 | P1 | FIXED / AWAITING QUALIFICATION | All form factors | Startup responsive/a11y | PIN overflowed by 60–570 px in mandatory viewport/text-scale cases. |
| PRE10-D008 | P2 | CONFIRMED | All | Project Hub i18n | Hub/recovery/create-project UI is predominantly hard-coded Russian/mixed language. |
| PRE10-D009 | P1 | FIXED / AWAITING QUALIFICATION | All native platforms | Storage-init recovery | Top-level store initialization had raw exception presentation and no in-session Retry. |
| PRE10-D010 | P3 | CONFIRMED | Engineering/docs | Architecture documentation | Canonical repository source comment is stale relative to production composition. |
| PRE10-D011 | P1 | CONFIRMED | Android, iOS/iPadOS | Semantic parity | Mobile semantic parity artifacts are not yet emitted/compared. |
| PRE10-D012 | P2 | FIXED / AWAITING QUALIFICATION | All | Startup negative journey | Backspace during the 120 ms pending-unlock window did not cancel already scheduled navigation. |

Current counts by severity: P0=0, P1=6, P2=5, P3=1. No P1/P2 is considered resolved until CLOSED evidence is attached.

## 2. Discovery evidence retained from v2

### PRE10-D005 / D006 / D007

First executable discovery:

```text
workflow: PRE-P10 PASS-1 Discovery
run:      40644029080
SHA:      b6e5fa0ed4279912aa35eb675cfa80a0f5fa3b0f
job:      PASS1-Q01-Q03 startup discovery
result:   FAILURE (discovery signal)
```

Responsive failures:

| Case | Discovery result |
|---|---:|
| 390×844, textScale 1.0 | PASS |
| 844×390, textScale 1.0 | FAIL — overflow 166 px |
| 844×390, textScale 2.0 | FAIL — overflow 570 px |
| 800×600, textScale 2.0 | FAIL — overflow 360 px |
| 768×1024, textScale 2.0 | PASS |
| 1440×900, textScale 2.0 | FAIL — overflow 60 px |

Q02 also proved direct physical keyboard input did not unlock, and Q03 proved English locale still displayed Russian startup copy.

### Q04/Q05 recovery baseline — PASS

Exact evidence:

```text
run: 40644464749
SHA: d97f246f68f4e8b375b6e4ae1868d4f4e716ff08
job: PASS1-Q04-Q05 persistence recovery discovery
result: SUCCESS
```

Proven behavior:

- Project Hub list failure exposes working Retry and recovers on the second attempt;
- corrupt canonical primary falls back to valid `.bak`;
- corrupt primary plus corrupt backup fails predictably;
- one corrupt project does not hide healthy projects from `list()`.

**Disposition:** no new canonical repository corruption defect was created. D009 is intentionally separate because it concerns the higher native store-initialization boundary.

## 3. PRE10-D005 fix candidate

**Root cause:** PIN state could only be mutated from on-screen `TextButton` callbacks.

**Fix implemented:** parent `Focus` now handles top-row digits, numpad digits and Backspace/Delete and feeds the same `_press`/`_backspace` state transitions as pointer/touch controls.

**Candidate fix commit:** `efab814ff25e4767c0eb5980a5b46ddb5ca5eed9` (startup hardening stack; later commits add qualification).

**Required closure evidence:** PRE10-Q02 PASS plus representative Linux/Windows/macOS native keyboard smoke before CLOSED.

## 4. PRE10-D006 fix candidate

**Root cause:** startup copy predated the typed RU/EN localization discipline.

**Fix implemented:** new `AppShellLocalizations` owns startup-shell RU/EN copy; PIN renders `Engineer quick access` / `Быстрый вход инженера` and localized prototype explanation from the locale.

**Required closure evidence:** Q03 PASS and later app-wide RU/EN journey. D008 remains open because Project Hub has not yet been migrated.

## 5. PRE10-D007 fix candidate

**Root cause:** fixed centered `Column` with large padding had no scroll-safe vertical strategy.

**Fix implemented:** startup body is now `SafeArea → Focus → LayoutBuilder → SingleChildScrollView → min-height constraint → centered max-width content`, preserving 72×60 keypad controls while allowing short-height/high-text-scale scrolling instead of RenderFlex overflow.

**Required closure evidence:** Q01 must pass the full mandatory matrix without overflow; later touch reachability must be proven on Android/iOS.

## 6. PRE10-D009 fix candidate

**Root cause:** `_storesFuture` was `late final` and the error branch was static text with raw `${snapshot.error}`.

**Fix implemented:**

- store opener dependencies are injectable through typed opener callbacks;
- `_storesFuture` is restartable;
- user-facing error no longer prints the raw internal exception;
- localized Retry action recreates the store initialization future in the same app session;
- error presentation is scroll-safe.

**Qualification:** `PRE10-Q06` now simulates first-attempt native storage failure, verifies no technical error leak, taps Retry and requires `ProjectHubScreen` to appear in the same session.

**Required closure evidence:** Q06 PASS; later representative native runtime smoke on all required platform families.

## 7. PRE10-D012 — delayed unlock race

**Status:** FIXED / AWAITING QUALIFICATION  
**Severity:** P2  
**Platforms:** all  
**Area:** startup / negative journey

**Finding:** the original PIN implementation scheduled navigation 120 ms after the fourth digit. If the user pressed Backspace during that delay, `_pin` changed but the previously scheduled `Future.delayed` still navigated to Project Hub.

**Expected:** deleting a digit before the unlock delay expires cancels pending navigation and leaves the user on the PIN screen.

**Root cause:** delayed navigation had no cancellation token/timer ownership and did not revalidate a cancellable transition.

**Fix implemented:** PIN state owns a `Timer`; Backspace and dispose cancel it, and the timer callback also revalidates `mounted` plus `pin.length == 4` before navigation.

**Regression test:** `PRE10-Q02b backspace cancels pending delayed unlock`.

**Required closure evidence:** Q02b PASS on the exact qualification SHA.

## 8. Confirmed defects still awaiting implementation

### D001 — committed native shells

Repository still has only committed macOS shell. Linux/Windows/Android/iOS production shells must be generated with the accepted pinned toolchain, reviewed and committed. Final PRE-P10 acceptance may not rely on `flutter create` during CI.

### D002 — immutable Flutter toolchain

Hard workflows still use `channel: stable`. Pinning must precede shell generation.

### D003 — production native runtime

`integration_test/` still has only the macOS path-provider smoke. Need native production journeys, not build-only evidence.

### D004 — complete branch-owned final matrix

`pre-p10-pass1.yml` now owns Q01–Q06 discovery. It is not yet the final Linux/Windows/macOS/Android/iOS acceptance matrix; D004 remains CONFIRMED.

### D008 — Project Hub app-wide localization

Project Hub/recovery/create-project strings remain predominantly hard-coded Russian with mixed English diagnostics.

### D010 — stale repository comment

Documentation-only correction remains pending.

### D011 — mobile semantic parity

Linux/macOS/Windows parity from P9 is strong, but Android/iOS runtime artifacts must be emitted and compared before PRE-P10 acceptance.

## 9. Current executable probes

```text
Q01  startup responsive/text-scale              rerunning after D007 fix
Q02  startup direct keyboard                    rerunning after D005 fix
Q02b delayed unlock cancellation                new regression for D012
Q03  startup RU/EN localization                 rerunning after D006 fix
Q04  Project Hub list failure + Retry           PASS
Q05  canonical primary/backup corruption        PASS
Q06  platform store init failure → Retry        new regression for D009
Q07  complete PRE-P10 CI ownership              RED → D004
Q08  committed native shells/build              RED → D001
Q09  five-family semantic parity                RED → D011
Q10  P1–P9 traceability inventory               documented in pre-p10-pass1-traceability-v1.md
```

## 10. P1–P9 inventory conclusion

The domain/application core is substantially stronger than the platform shell:

```text
P1–P7 core semantics        STRONG
P8 core + Flutter UI        STRONG
P9 core + Flutter UI        STRONG
canonical recovery core     STRONG

startup/root UI             FIX CANDIDATES UNDER QUALIFICATION
Project Hub app-wide i18n   RED
native committed packaging  RED
native production runtime   RED
mobile semantic parity      RED
full PRE-P10 final CI       RED
```

The authoritative detailed mapping is `pre-p10-pass1-traceability-v1.md`.

## 11. Exit rule remains unchanged

P10 is blocked until one exact final SHA satisfies the parent PRE-P10 acceptance contract. In particular, all P0/P1 defects must be CLOSED, P2 defects must be CLOSED or have explicit accepted disposition allowed by the parent contract, required native runtime and five-family parity must be green, and the final audit must bind all evidence to that exact SHA.
