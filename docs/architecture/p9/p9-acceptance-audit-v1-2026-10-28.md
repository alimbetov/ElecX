# P9.13 Acceptance Audit v1 — 2026-10-28

Branch: `feat/p9-apartment-topology-generator`  
Audit baseline commit at creation: `688e2303aefd9fb3d317d233ee99b01e3b101ca9`  
Base `main`: `c397302f183d023e4bdd670ac0c8b46c6fad994a`  
Current disposition: **P9 = IMPLEMENTED, QUALIFICATION INCOMPLETE**

> This is a living repository acceptance record. Because committing this file changes branch HEAD, the final merge decision must always be rebound to the later exact SHA that passes the complete P9.13 workflow.

## 1. Acceptance objective

P9.13 must prove one production vertical slice, not merely unit-test completeness:

```text
parameters
 -> deterministic generation
 -> ranking / selection
 -> vector preview
 -> P8 Preview/Diff reservation
 -> canonical materialization
 -> provenance / persistence
 -> Apply / Undo / Redo
 -> cross-platform semantic parity
 -> responsive/input continuity
 -> exact-SHA final audit
```

No final acceptance is granted from an older SHA.

## 2. Semantic version / corpus evidence

Known P9 generator version:

```text
generatorVersion = p9.generator.v3
```

Qualification corpus currently encoded in `qualification_test/p9_p913_domain_qualification_test.dart`:

```text
supported corpus version: p9.13-supported-v1
supported requests:       250
invalid corpus version:   p9.13-invalid-v1
invalid requests:         100
property/fuzz seed:       91313
property/fuzz cases:      1500
determinism repetitions:  10 per supported request
```

The final exact-SHA run is authoritative for pass/fail; these constants describe the acceptance load, not a waiver of CI evidence.

## 3. Historical acceptance evidence before hardening

On historical HEAD `955a71b321c6ef96fd046666f54f086f0c67c1af`:

```text
Flutter workflow run 40630968845       SUCCESS
P9.13 workflow run 40630968949         FAILURE
```

The ordinary Flutter workflow was fully green: formatting, static analysis, P8 NFR/a11y/i18n and full `flutter test` passed.

Within historical P9.13 run `40630968949` the following already passed:

```text
A Domain qualification                         PASS
A-C P9.13 performance + memory NFRs            PASS
B-C Engineering + transactional qualification PASS
G Semantic parity Linux                        PASS
G Semantic parity macOS                        PASS
G Semantic parity Windows                      PASS
G Cross-platform semantic equality             PASS
D Desktop native Linux                         PASS
D Desktop native Windows                       PASS
D Desktop native macOS                         PASS
Android debug APK compilation                  PASS
Apple iOS/iPadOS debug compilation             PASS
```

The run was blocked by the common responsive qualification surface on desktop/Android/iOS. `H exact-SHA final audit` was therefore skipped.

## 4. Technical-review remediation applied after that run

### R8 — responsive contract drift

Historical production layout used implicit `760/1100` switching while the authoritative P9 contract specifies:

```text
COMPACT     < 600
MEDIUM      600..1023
EXPANDED    1024..1439
LARGE       >= 1440
```

Remediation:

- production UI now delegates authoritative width classification to the existing shared `responsiveWidthClassFor` contract;
- `ElecXPresentationPolicy` owns only accessibility-aware pane density and cannot redefine semantic width classes;
- targeted qualification asserts 599/600, 1023/1024 and 1439/1440 boundaries;
- GJ-03 now traverses phone/tablet/desktop, RU/EN, text scale and theme states, opens compact full Diff and applies the exact preserved reservation after returning to desktop.

### R9 — unsupported generation reasons were lost

`ApartmentWizardExplorationController` now retains immutable generation failures for the authoritative semantic revision. The production Wizard presents typed blockers while preserving the user's request and leaving canonical state unchanged.

### R10 — touch candidate navigation depended on gesture discovery

`WizardCandidateCarousel` now exposes explicit Previous/Next controls in addition to swipe and keyboard navigation. The controls have Material tooltips and at least 48dp targets in GJ-04 qualification.

### R11 — incomplete Golden Journey coverage

Hardening added:

```text
GJ-01 canonical boundary geometry edit through ProjectBoundaryTopologyEditingService,
      stable BoundaryEdgeIds, field-aware geometry override and reopen persistence
GJ-02 existing multi-level / multi-building isolation and reopen
GJ-03 responsive continuity through exact preserved reservation + compact Diff + Apply
GJ-04 keyboard / mouse / touch / stylus-as-pointer semantic equality
```

### R12 — remaining negative acceptance gaps

Added dedicated P9.13 coverage for:

```text
NG-02 unsupported-but-valid request: reasons visible, input preserved, no mutation
NG-06 renderer rejection: candidate and canonical project unchanged
NG-07 repository save failure: prior durable project remains valid, no partial durable provenance
```

Existing regressions are explicitly reused for NG-01/03/04/05/08/09/10 and mapped in `p9.13-requirement-traceability-v1.md`.

### R13 — final workflow was not self-contained

`.github/workflows/p9-final-acceptance.yml` now contains an explicit repository-quality prerequisite covering:

```text
Dart format
flutter analyze
P8 a11y/i18n regression gates
complete flutter test
evidence document presence
```

`H exact-SHA final audit` depends on repository quality plus every P9.13 A-G/native gate, so a green specialized matrix can no longer qualify a SHA whose general Flutter regression suite is red.

### R14 — repository hygiene / evidence

- tracked generated `test.log` removed;
- root `test.log` and `analyze.log` ignored;
- requirement traceability is repository-controlled;
- this repository acceptance audit is repository-controlled.

## 5. Current acceptance matrix

The following table describes what must be green on the same final SHA. Historical PASS values are useful evidence but do not replace the fresh run after remediation.

| Dimension | Current code/evidence state | Exact final SHA required |
|---|---|---:|
| A Domain corpus / fuzz / determinism | implemented | YES |
| A-C hard p95/p99/RSS | implemented | YES |
| B engineering topology-only / enabled / frozen proposal | implemented | YES |
| C Preview/Diff / Apply / Undo / Redo / persistence | implemented | YES |
| GJ-01 | hardened including geometry override | YES |
| GJ-02 | implemented | YES |
| GJ-03 | hardened | YES |
| GJ-04 | implemented | YES |
| NG-01..10 | mapped / remaining gaps implemented | YES |
| Desktop Linux | native compile gate implemented | YES |
| Desktop Windows | native compile gate implemented | YES |
| Desktop macOS | native compile gate implemented | YES |
| Android phone/tablet | compile + responsive gate implemented | YES |
| iOS/iPadOS | compile + responsive gate implemented | YES |
| Linux/macOS/Windows semantic equality | implemented | YES |
| repository format/analyze/full tests | now part of P9.13 workflow | YES |
| exact-SHA H audit artifact | implemented | YES |

## 6. Responsive / input acceptance contract

Qualified viewport matrix:

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
800 x 600
1280 x 720
1440 x 900
1920 x 1080
```

Presentation dimensions exercised include:

```text
RU / EN
text scale 1.0 / 1.3 / 2.0
light / dark
keyboard
mouse
pointer-touch
stylus-as-pointer
```

The semantic invariant remains:

```text
same request + catalog/generator/scoring versions
= same candidate ordering / fingerprints / reserved command semantics
```

Presentation transitions may reduce visual density for accessibility but must not change authoritative width classification, candidate identity, reservation, project version or history.

## 7. Cross-platform policy

P9.13 requires semantic equality for Linux, macOS and Windows through byte-comparable semantic artifacts.

Native target compilation additionally covers:

```text
Linux
Windows
macOS
Android
Apple iOS/iPadOS target
```

The repository currently contains a permanent macOS shell; missing platform shells are generated ephemerally by Flutter in CI only for the P9.13 compilation gate. Committing and production-hardening all permanent native shells remains P17 scope and is not represented as completed by P9.13.

## 8. Residual risks

### RR-01 — Flutter SDK is selected by `channel: stable`

P9.13 currently does not pin one exact Flutter SDK version in workflow configuration. This is a reproducibility risk for future reruns of the same source SHA, especially for performance observations.

Disposition: **non-functional hardening candidate before/at P17 unless an authoritative repository SDK version is established during P9.13 closure**. It must not be silently “fixed” by inventing a version unsupported by repository evidence.

### RR-02 — ephemeral native shells

Android/iOS/Windows/Linux shells missing from source control are generated on CI runners for compilation qualification.

Disposition: **accepted for P9 semantic/native compile qualification; permanent production shells remain P17 scope**.

### RR-03 — final measurements not yet rebound after remediation

The historical P9.13 PASS results were produced before the present hardening commits. The branch therefore remains qualification-incomplete until the full new matrix passes on one exact SHA.

Disposition: **merge blocker**.

## 9. Merge blockers

At the time this audit entry is created, final merge is blocked until all are simultaneously true on one exact final SHA:

```text
repository quality prerequisite                    PASS
A Domain qualification                            PASS
A-C performance + memory                          PASS
B-C engineering + transactional                   PASS
GJ-01..04                                         PASS
NG-01..10                                         PASS
D-F responsive phone/tablet/desktop               PASS
G Linux/macOS/Windows semantic equality           PASS
Linux/Windows/macOS native compilation            PASS
Android native compilation + responsive contract PASS
iOS/iPadOS compilation + responsive contract     PASS
H exact-SHA final audit                           PASS
branch behind main                               0
repository hygiene                               PASS
```

Any subsequent code/test/doc commit invalidates an older exact-SHA disposition and requires the workflow to run again.

## 10. Current decision

```text
P9 = IMPLEMENTED, QUALIFICATION INCOMPLETE
```

No functional expansion of P9 is authorized by this audit. Remaining work is acceptance hardening, correction of defects exposed by the hard gates, and final exact-SHA evidence.
