# P8 Wizard + Preview/Diff Technical Audit v4 — 2026-10-24

## Status

Final merge-readiness audit for `feat/p8-wizard-preview-diff`.

Runtime-qualified implementation SHA:

```text
afd2c3ef66c597a511bbbf3fee3c69c8fd76d338
```

Runtime qualification evidence:

```text
Flutter workflow 40100879727 = SUCCESS
macOS workflow   40100879726 = SUCCESS
```

The documentation-only commit that adds this audit must also retain green branch-head CI before PR #16 may merge.

---

# 1. Executive verdict

```text
P8 FEATURE VERTICAL SLICE = IMPLEMENTED
P8 ACCEPTANCE             = ACCEPTED
R22                        = CLOSED
R23                        = CLOSED
MERGE DISPOSITION          = ACCEPTED FOR MERGE, subject only to green actual branch HEAD CI
```

The accepted vertical slice remains:

```text
Project Hub
-> New Project
-> Create with Wizard
-> Basic Building typed parameters
-> Generate
-> deterministic frozen Preview
-> semantic Diff
-> Apply exact frozen candidate
-> Undo
-> Redo
-> Save
-> Close
-> Reopen
-> exact canonical Building/Level identities restored
```

The canonical transaction invariants from v3 remain unchanged: one production mutation timeline, preview is non-canonical, Apply commits the exact prepared candidate, stale/foreign/discarded previews fail closed, and one Apply creates one canonical mutation/history/Undo item.

---

# 2. R22 — inherited branch ancestry: CLOSED

## Previous risk

The original PR history contained 97 commits and inherited routing/measurement/authoring ancestry that predated the requested P8 audit baseline. Although the functional P8 slice was accepted, that history made the merge delta difficult to review and left R22 open.

## Closure action

The authoritative branch name was retained:

```text
feat/p8-wizard-preview-diff
```

The branch ref was moved with force-with-lease from the inherited lineage to the clean P8 lineage rooted directly on the current `main` baseline:

```text
main baseline / merge base:
56cb40ad2cc141262b064c61023a61baf257798f

first clean P8 rebuild commit:
888bd4514b449703ccdb2390eadf99f691984670
parent:
56cb40ad2cc141262b064c61023a61baf257798f
```

At runtime-qualified SHA `afd2c3ef...`:

```text
main...feat/p8-wizard-preview-diff
status      = ahead
behind_by   = 0
ahead_by    = 27
merge_base  = 56cb40ad2cc141262b064c61023a61baf257798f
```

Adding this audit contributes one documentation-only commit and does not reintroduce inherited ancestry.

## Scope classification

Existing production/editor files that remain modified in the P8 delta fall into two controlled categories:

1. required P8 production integration/adaptation, including production runtime, Project Navigator, Project Hub, canonical/legacy structure projection and tests that instantiate the production Wizard capability;
2. non-semantic Dart formatter normalization required by the repository's current Dart 3.47 formatter.

Formatter-only normalization is isolated in commit:

```text
81e92ce94c5eb240062e6e3a5cd4977f00a07195
style(p8): normalize inherited main files for Dart 3.47 formatter
```

Inspection confirms wrapping/indentation/conditional-expression formatting only; it does not carry routing or measurement behavior into P8.

## R22 disposition

```text
R22 = CLOSED
```

Exit criteria satisfied:

```text
same authoritative branch name retained
historical inherited ancestry removed
merge base == main baseline
behind_by == 0
P8 delta reviewable from main
remaining cross-file changes classified as P8 integration or non-semantic formatting
```

---

# 3. R23 — hard NFR / accessibility / localization: CLOSED

## Enforced qualification suites

```text
test/p8_wizard_nfr_a11y_i18n_qualification_test.dart
test/p8_wizard_r23_extended_qualification_test.dart
```

The GitHub Actions quality job executes both suites explicitly with `--concurrency=1` before the full repository regression suite.

## Hard performance and memory gates

The following numeric gates are executable and passed on the runtime-qualified SHA:

```text
semantic diff <= 10k entries:
  p95 <= 2.0s
  p99 <= 3.5s
  additional RSS <= 150 MiB

maximum Basic Building generation / preview:
  p95 <= 300ms for the existing hard generation/preview sample set
  p99 <= 500ms for the extended maximum-cardinality preview-ready sample set

local Wizard parameter interaction:
  p95 <= 100ms

frozen candidate commit:
  p95 <= 3.0s, excluding characterized storage synchronization
```

Reference environment is logged by CI rather than assumed. The accepted run used the GitHub `ubuntu-24.04` hosted-runner class with 4 vCPU, approximately 16 GiB RAM, Flutter 3.47.8 and Dart 3.13.7. The gate is therefore tied to the logged hosted-runner qualification class, not to an undocumented developer workstation.

## RU/EN localization

P8 owns a centralized typed localization surface:

```text
ProjectWizardLocalizations
supported locales = en, ru
```

Flutter Material/Widgets/Cupertino localization delegates are registered, and qualification verifies complete Wizard resource rendering in both languages.

## Screen-reader semantics

The executable matrix covers:

```text
locales: en, ru
widths:  390, 900, 1440 dp
```

Primary Wizard controls, input fields and preview semantics must remain discoverable with non-empty localized semantic labels.

## Text scaling

The extended qualification matrix is exhaustive for the accepted P8 release gate:

```text
locales:    en, ru
text scale: 1.0, 1.3, 2.0
widths:     390, 900, 1440 dp
```

No RenderFlex overflow is permitted.

The strengthened matrix found two real defects before closure:

```text
RU + 200% + 390dp -> horizontal action-bar overflow
RU + 200% + 900dp -> vertical parameter-panel overflow
```

They were fixed rather than waived by:

```text
text-scale-aware responsive breakpoints
unconstrained ground-level toggle layout
icon-only localized/tooltip actions at extreme scale on narrow screens
48dp minimum action targets retained
```

The exact regression matrix passes at `afd2c3ef...`.

## Reduced motion

The candidate carousel is explicitly qualified for both RU and EN with:

```text
MediaQuery.disableAnimations = true
```

Selection changes use a non-animated path and leave no transient animation callbacks.

## R23 disposition

```text
R23 = CLOSED
```

Exit criteria satisfied:

```text
hard p95/p99 gates executable and passing
memory gate executable and passing
RU/EN resources qualified
RU/EN screen-reader matrix qualified
RU/EN text-scale matrix through 200% qualified
RU/EN reduced-motion behavior qualified
48dp target qualification retained
full repository regression green
macOS analyze/test/build/runtime smoke green
```

---

# 4. CI evidence

Runtime-qualified SHA:

```text
afd2c3ef66c597a511bbbf3fee3c69c8fd76d338
```

Flutter workflow:

```text
run 40100879727 = SUCCESS
Dart format = PASS
flutter analyze = PASS
P8 NFR/a11y/i18n acceptance = PASS
full flutter test = PASS
verification analyze/test = PASS
```

macOS Desktop workflow:

```text
run 40100879726 = SUCCESS
Analyze = PASS
Test = PASS
Build macOS debug app = PASS
Runtime path_provider smoke = PASS
```

The actual post-audit branch HEAD must repeat green CI before merge; the PR must not rely solely on this pre-documentation runtime SHA.

---

# 5. Final risk register

```text
R1  second Wizard mutation engine                    CLOSED
R2  second Wizard Undo timeline                      CLOSED
R3  preview writes canonical state                   CLOSED
R4  regeneration/random allocation during Apply      CLOSED
R5  stale Apply overwrites newer version             CLOSED
R6  repository format/analyze/test gate              CLOSED
R7  preview candidate == committed candidate         CLOSED
R8  duplicate Apply                                  CLOSED
R9  failed commit reservation semantics              CLOSED
R10 one Apply == one production history/Undo item    CLOSED
R11 save/reopen exact identity                       CLOSED
R12 canonical owner acknowledgement                  CLOSED
R13 NewProject Basic Building unavailable            CLOSED
R14 Project Hub Wizard entry absent                  CLOSED
R15 Apply/Undo/Redo/save/reopen E2E absent           CLOSED
R16 semantic human diff absent                       CLOSED
R17 vector preview scene absent                      CLOSED
R18 responsive shell absent                         CLOSED
R19 candidate carousel absent                        CLOSED
R20 Navigator Wizard entry absent                    CLOSED
R21 structural Level materialization/reopen gap      CLOSED
R22 inherited branch ancestry                        CLOSED
R23 hard NFR/extended a11y/i18n qualification        CLOSED
```

No P8 acceptance risk remains OPEN or ACCEPTED RESIDUAL.

---

# 6. Final acceptance decision

```text
P8 = ACCEPTED FOR MERGE
```

Merge preconditions:

```text
1. actual feat/p8-wizard-preview-diff HEAD CI = green;
2. Flutter quality + verification = SUCCESS;
3. macOS Desktop = SUCCESS;
4. PR #16 remains mergeable into main;
5. expected PR head SHA matches the qualified branch head.
```

Only after those checks may PR #16 be merged into `main`.
