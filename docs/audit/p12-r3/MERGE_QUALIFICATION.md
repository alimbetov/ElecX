# Merge qualification

Baseline: `4811b57de49e9ad66e9bb5e3d0387d2ea0737a0c`. Target: `feat/p12a8-engineering-preview-diff`, never main. Dedicated fix branch: `fix/p12-r3-multilevel-routing-qualification`.

Production fixes:

- `01fd6693` — derive route qualification from current committed state.
- `d86299b4` — bind riser qualification to mapped passage rooms.
- `13e32a7f` — retain replaced active level through Save/Reopen.
- `3c830cefd91d5e655fbc81a07908eda5159a983f` — expanded evidence mutation/locality regression (latest code/test SHA before this report-only commit).

Final PR SHA and six exact-SHA workflow results will be linked from the PR head/checks. A report cannot contain its own commit hash; this report's version is identified by the PR commit that contains it. Baseline CI is not reused as final qualification.

Baseline independently verified: Flutter 42822649846, macOS Desktop 42822649870, P9.13 Final Acceptance 42822649866, PRE-P10 PASS-1 Discovery 42822649915, P10 Final Acceptance 42822649892, PRE-P12 Production Authoring 42822649988 — all success on 4811b57d.

Local production fixes have RED→GREEN regression, formatter/analyzer, full 2099 tests and native basic Save/Quit/Reopen evidence. Expanded test-only matrix passed 27 relevant tests. See TEST_EXECUTION.md and DESKTOP_ACCEPTANCE.md.

Merge decision: HOLD. Full native three-level route authoring/qualification is BLOCKED in the inspected production editor. The task explicitly requires Desktop qualification GREEN; passing API tests or six CI workflows does not override this acceptance gate. Leave PR open if that gate remains blocked. Do not bypass protection, dismiss blocking review comments, force push, merge to main or claim a merged SHA.

PR URL, exact final SHA and completed check snapshot are supplied in the final PR description and final response after submission/CI monitoring. Main is untouched by this audit.
