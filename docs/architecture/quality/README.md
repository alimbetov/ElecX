# PRE-P10 quality specification package

This directory is the authoritative PRE-P10 cross-platform hardening specification package for `feat/pre-p10-cross-platform-hardening`.

## Authoritative documents

1. **Acceptance contract** — `pre-p10-cross-platform-hardening-plan-v1.md`
   - scope and decision;
   - mandatory platforms;
   - positive journeys;
   - negative/recovery journeys;
   - responsive/a11y matrix;
   - semantic parity;
   - native runtime qualification;
   - severity/status/closure rules;
   - PRE-P10 exit criteria.

2. **Initial PASS-1 defect baseline** — `pre-p10-pass1-findings-v3.md`
   - repository/architecture/platform inventory;
   - established `PRE10-D001` through `PRE10-D012` baseline;
   - exact detecting SHA/workflow evidence where executable evidence exists;
   - root cause and fix strategy;
   - fix-candidate and awaiting-qualification states;
   - regression and closure gates;
   - verified non-defects / already-strong areas;
   - active discovery probes.

3. **PASS-1 second-search new-defect delta** — `pre-p10-pass1-second-search-findings-v1.md`
   - second independent repository/architecture/platform audit;
   - contains **only new defects `PRE10-D013` through `PRE10-D020`**;
   - explicitly excludes `D001`–`D012` from the new-defect count;
   - records evidence, risk and closure gates for each new failure class;
   - includes checked-but-not-counted cases to prevent duplicate defect inflation.

4. **P1–P9 traceability inventory** — `pre-p10-pass1-traceability-v1.md`
   - domain/application coverage;
   - Flutter UI/production-composition coverage;
   - native runtime gaps;
   - reused test families;
   - required PRE-P10 product journeys.

## Current defect disposition

The current PRE-P10 defect set is the union of:

```text
pre-p10-pass1-findings-v3.md
  D001–D012 baseline
+
pre-p10-pass1-second-search-findings-v1.md
  D013–D020 new-only delta
```

The second-search document intentionally does not repeat baseline defects. This keeps the new-defect count auditable while preserving one authoritative package-level disposition.

## Historical documents

`pre-p10-pass1-findings-v1.md` and `pre-p10-pass1-findings-v2.md` are retained as historical PASS-1 snapshots. They are superseded by v3 and must not be used as the current initial-baseline disposition.

## Governance

A newly confirmed defect must be added to the current defect package before or together with its fix. A fix is not `CLOSED` until repeatable qualification evidence exists. The branch cannot unblock P10 until one exact final SHA satisfies the parent acceptance contract and every P0/P1/P2 defect has an allowed final disposition.