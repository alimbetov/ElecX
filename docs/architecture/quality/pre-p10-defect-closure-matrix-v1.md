# PRE-P10 Defect Closure Matrix v1

**Branch:** `feat/pre-p10-defect-remediation`  
**Rule:** a code change is not `CLOSED` until regression/platform evidence is bound to an exact qualification SHA.

## Status values

`CONFIRMED` · `IMPLEMENTING` · `FIXED / AWAITING QUALIFICATION` · `CLOSED` · `ACCEPTED DISPOSITION`

## PRE-P10 defects

| Defect | Sev | Status | Fix commit | Regression / CQ | CI job | Platforms | Qualification SHA | Evidence |
|---|---:|---|---|---|---|---|---|---|
| PRE10-D001 | P1 | CONFIRMED | — | PRE10-CQ02 | — | Linux/Windows/macOS/Android/iOS | — | — |
| PRE10-D002 | P2 | IMPLEMENTING | — | PRE10-CQ01 | — | all CI | — | — |
| PRE10-D003 | P1 | CONFIRMED | — | PRE10-CQ03 | — | five families | — | — |
| PRE10-D004 | P1 | CONFIRMED | — | PRE10-CQ03..CQ04 | — | five families | — | — |
| PRE10-D005 | P2 | FIXED / AWAITING QUALIFICATION | existing candidate | existing Q02 | PRE-P10 discovery/final | desktop native | — | — |
| PRE10-D006 | P2 | FIXED / AWAITING QUALIFICATION | existing candidate | existing Q03 | PRE-P10 discovery/final | all | — | — |
| PRE10-D007 | P1 | FIXED / AWAITING QUALIFICATION | existing candidate | existing Q01 | PRE-P10 discovery/final | all form factors | — | — |
| PRE10-D008 | P2 | CONFIRMED | — | PRE10-CQ05 | — | all | — | — |
| PRE10-D009 | P1 | FIXED / AWAITING QUALIFICATION | existing candidate | existing Q06 | PRE-P10 discovery/final | all | — | — |
| PRE10-D010 | P3 | CONFIRMED | — | documentation review | — | docs | — | — |
| PRE10-D011 | P1 | CONFIRMED | — | PRE10-CQ04 | — | Android/iOS + parity | — | — |
| PRE10-D012 | P2 | FIXED / AWAITING QUALIFICATION | existing candidate | existing Q02b | PRE-P10 discovery/final | all | — | — |
| PRE10-D013 | P1 | CONFIRMED | — | PRE10-CQ06 | — | all UI modalities | — | — |
| PRE10-D014 | P1 | CONFIRMED | — | PRE10-CQ08 | — | persistence | — | — |
| PRE10-D015 | P1 | CONFIRMED | — | PRE10-CQ09/CQ10 | — | project creation | — | — |
| PRE10-D016 | P1 | CONFIRMED | — | PRE10-CQ11 | — | editor/recovery | — | — |
| PRE10-D017 | P1 | CONFIRMED | — | PRE10-CQ12 | — | persistence/recovery | — | — |
| PRE10-D018 | P2 | CONFIRMED | — | PRE10-CQ07 | — | production UI | — | — |
| PRE10-D019 | P1 | CONFIRMED | — | PRE10-CQ13 | — | recovery | — | — |
| PRE10-D020 | P1 | CONFIRMED | — | PRE10-CQ14 | — | editor/canonical | — | — |

## P9 late-audit remediation

| Defect | Sev | Status | Regression / CQ | Qualification SHA | Evidence |
|---|---:|---|---|---|---|
| P9-DEF-018 | P1 | CONFIRMED | PRE10-CQ16 | — | — |
| P9-DEF-019 | P1 | CONFIRMED | PRE10-CQ17 | — | — |
| P9-DEF-020 | P1 | CONFIRMED | PRE10-CQ18 | — | — |
| P9-DEF-021 | P1 | CONFIRMED | PRE10-CQ19 | — | — |
| P9-DEF-022 | P1 | CONFIRMED | PRE10-CQ20 | — | — |
| P9-DEF-023 | P2 | CONFIRMED | PRE10-CQ21 | — | — |
| P9-DEF-024 | P1 | CONFIRMED | PRE10-CQ22 | — | — |
| P9-DEF-025 | P2 | CONFIRMED | PRE10-CQ23 | — | — |
| P9-DEF-026 | P2 | CONFIRMED | PRE10-CQ24 | — | — |
| P9-DEF-027 | P2 | CONFIRMED | PRE10-CQ25 | — | — |
| P9-DEF-028 | P1 | CONFIRMED | PRE10-CQ26 | — | — |
| P9-DEF-029 | P1 | CONFIRMED | PRE10-CQ27 | — | — |
| P9-DEF-030 | P2 | CONFIRMED | PRE10-CQ28 | — | — |
| P9-DEF-031 | P2 | CONFIRMED | PRE10-CQ29/CQ30 | — | — |
| P9-DEF-032-Q | qualification | QUALIFICATION REQUIRED | PRE10-CQ15 | — | — |

## Final campaign

`PRE10-CQ31` is the mandatory destructive full-lifecycle roundtrip and does not replace individual closure tests.
