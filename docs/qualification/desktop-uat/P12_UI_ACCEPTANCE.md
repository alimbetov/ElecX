# P12 production UI acceptance

Baseline 9f15d985; real main.dart GUI, screenshots 03 and 12.

| Check | Result |
|---|---|
| Production toolbar entry | PASS; real “P12 · Инженерная проверка” dialog |
| Project version | Displayed 6 before/after P2 edits; canonical revision not claimed to be P2 revision |
| P11 circuit count | 0, including after prototype circuit-1 creation |
| POWER selections / RCD assignments | 0 / 0, explicit missing-selection diagnostic |
| Authoritative proposal | BLOCKED: “Источник P12 proposal не подключён” |
| EngineeringProposalDiff | BLOCKED: no confirmed before-snapshot/proposal; no fabricated empty diff |
| selected/unresolved | BLOCKED for actual proposal; no selected state invented |
| Safety/evidence | PASS diagnostics: source/calculation/coordination confirmation missing |
| Production Apply | PASS safety state: unavailable and prerequisites explained |
| Stale snapshot in GUI | BLOCKED: no authoritative source to form one |
| Dialog layout | Readable in maximized native window; close reachable |

Existing source gate checks project ID/version and engineering/power-selection fingerprints (`p12_engineering_proposal_source.dart`). Unit coverage is supporting evidence, not executed stale production GUI acceptance. No mock provider installed. Building Wizard diff was not used as P12 evidence. Existing UAT D04 “no review UI” is superseded by this entry; complete engineering review remains PARTIAL.
