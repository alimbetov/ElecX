# P8 Wizard + Preview/Diff Specification Pack v2 — 2026-10-24

## Status

Current composition and acceptance authority for `feat/p8-wizard-preview-diff`.

```text
P8 = ACCEPTED
```

Historical specification pack:

```text
p8-specification-pack-v1.md
```

Current acceptance audit:

```text
p8-technical-audit-v3-2026-10-24.md
```

Requested v3 audit baseline:

```text
073e3421dc0830974df4cee3e8b5c0df6396f933
```

Acceptance-qualified implementation SHA:

```text
e595901bda262cc9f76507f35b77dce3d2f47197
```

Acceptance workflow:

```text
GitHub Actions run 40094369613
quality      = PASS
verification = PASS
Dart format  = PASS
flutter analyze = PASS
flutter test = PASS
```

`p8-technical-audit-v1.md` and `p8-technical-audit-v2-2026-10-24.md` are historical evidence only. Current implementation and acceptance status is determined by v3.

---

# 1. Composition

P8 is governed by:

1. `project-composition-foundation-decisions-v1.md` — canonical ownership, mutation, identity and persistence authority.
2. `p8-specification-pack-v1.md` — normative P8 product/transaction design.
3. `p8-wizard-preview-diff-implementation-v1.md` — implementation architecture.
4. `p8-wizard-responsive-carousel-ux-v1.md` — responsive and candidate UX contract.
5. `p8-development-roadmap-v1.md` — dependency graph and delivery gates.
6. `p8-execution-work-packages-v1.md` — WP00..WP16 implementation decomposition.
7. `p8-technical-audit-v3-2026-10-24.md` — **final acceptance closure matrix, Golden Journey evidence and residual-risk disposition**.

Precedence for current status:

```text
project-composition-foundation-decisions-v1.md
        ↓
P8 normative product/transaction invariants from p8-specification-pack-v1.md
        ↓
p8-technical-audit-v3-2026-10-24.md
        ↓
p8-wizard-preview-diff-implementation-v1.md
        ↓
p8-wizard-responsive-carousel-ux-v1.md
        ↓
p8-development-roadmap-v1.md
        ↓
p8-execution-work-packages-v1.md
```

---

# 2. Frozen accepted architecture

The accepted P8 implementation preserves:

```text
one canonical ProjectMutationSession timeline
one ReservedProjectMutationCoordinator prepared-preview lifecycle
preview is non-canonical and side-effect free
Apply commits the exact frozen prepared candidate
no provider regeneration/random allocation during Apply
stale preview fails closed
explicit refresh/rebase invalidates the old reservation
one successful Apply = one canonical change/history item = one Undo item
typed target-aware provider contracts
whole-candidate Apply/Cancel
WizardPreviewScene is projection, never project authority
SVG is output only and never parsed back into canonical geometry
NewProject seed normalization is production integration, not widget-side mutation
contextual Project Navigator Wizard reuses the exact production-composed ProjectWizardMutationPort
```

No follow-up work may silently introduce a second project model, second Undo stack, Wizard-specific persistence repository or direct widget-to-aggregate mutation path.

---

# 3. Accepted production path

The mandatory production-composition path is qualified:

```text
Project Hub
-> New Project
-> Create with Wizard
-> Basic Building
-> typed parameters
-> Generate
-> deterministic Preview
-> semantic Changes/Diff
-> Apply exact frozen candidate
-> one canonical change/history item
-> Undo
-> Redo exact candidate
-> structural materialization
-> Save
-> Close
-> Reopen
-> exact canonical identities and semantic fingerprint restored
```

A contextual editor path is also qualified:

```text
Canonical Project Navigator
-> Wizard
-> SiteWizardTarget at current canonical version
-> Basic Building
-> Preview/Diff
-> Apply
-> existing canonical owner/history/rematerialization path
```

---

# 4. Acceptance evidence

Primary direct evidence:

```text
test/p8_project_hub_wizard_flow_test.dart
test/p8_wizard_golden_journey_test.dart
test/canonical_project_navigator_test.dart
test/canonical_wizard_production_owner_test.dart
test/p8_wizard_crash_window_recovery_test.dart
test/wizard_mutation_hardening_test.dart
test/wizard_diff_preview_test.dart
test/p8_wizard_responsive_carousel_qualification_test.dart
test/p8_wizard_reliability_stress_test.dart
test/p8_wizard_accessibility_qualification_test.dart
```

The Golden Journey proves:

```text
before fingerprint != applied fingerprint
Undo restores exact before fingerprint
Redo restores exact applied fingerprint
Building IDs after Redo == IDs after Apply
Level IDs after Redo == IDs after Apply
reopened fingerprint == applied fingerprint
reopened Building IDs == applied Building IDs
reopened Level IDs == applied Level IDs
reopened canonical<->legacy binding preserves exact applied Level IDs
```

---

# 5. Accepted residuals

P8 feature acceptance does not falsely close two separate release/review concerns.

## R22 — inherited branch ancestry

```text
status = ACCEPTED RESIDUAL
owner = ElecX Engineering / PR reviewer
```

The branch contains pre-P8 routing/measurement/authoring ancestry that predates the requested `073e342` audit baseline. The PR must disclose this and the reviewer must confirm it is intended or request split/rebase before merge.

## R23 — hard NFR / extended accessibility / localization qualification

```text
status = ACCEPTED RESIDUAL
owner = ElecX Engineering / QA
exit = production-release qualification
```

Reference-hardware timing/memory budgets plus the complete screen-reader, text-scaling, reduced-motion and RU/EN localization matrix remain a production-release gate. Existing reliability, 48dp, keyboard, responsive and SVG-safety evidence is accepted for the P8 feature merge.

No unmeasured numeric NFR target is claimed as satisfied.

---

# 6. Merge disposition

```text
P8 = ACCEPTED
GO = open PR feat/p8-wizard-preview-diff -> main
```

Merge remains subject to:

```text
actual PR branch HEAD CI green
explicit review of R22 inherited ancestry
R23 retained as production-release gate
normal code review
```

The PR may be opened after final branch-head CI verification. It must not be auto-merged solely because P8 feature acceptance is complete.
