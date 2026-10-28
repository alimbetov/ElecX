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

2. **Current PASS-1 defect ledger** — `pre-p10-pass1-findings-v2.md`
   - repository/architecture/platform inventory;
   - all currently confirmed `PRE10-Dxxx` defects;
   - exact detecting SHA/workflow evidence where executable evidence exists;
   - root cause and fix strategy;
   - regression and closure gates;
   - verified non-defects / already-strong areas;
   - active discovery probes.

## Historical document

`pre-p10-pass1-findings-v1.md` is retained as the first PASS-1 snapshot. It is superseded by v2 and must not be used as the current defect disposition.

## Governance

A newly confirmed defect must be added to the current defect ledger before or together with its fix. A fix is not `CLOSED` until repeatable qualification evidence exists. The branch cannot unblock P10 until one exact final SHA satisfies the parent acceptance contract and every P0/P1/P2 defect has an allowed final disposition.
