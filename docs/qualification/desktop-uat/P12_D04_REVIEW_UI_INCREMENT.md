# P12 Desktop D04 — Read-only Engineering Review entry point

Status: **D04 partially implemented**. This work is a safe, additive
production UI entry point, not a completed P12 Preview/Apply integration.

## What is now accessible

The real production `UnifiedWorkspaceEditorScreen` AppBar now includes
`p12-review-open` in desktop and compact layouts. It opens a bounded,
scrollable `p12-review-dialog` and reads the **current** project through
`CanonicalEditorResolvedRuntime.session.project`. The UI never queries
the legacy editor's synthetic group as if it were P11 proof.

`P12EngineeringReviewPanel` shows:

- exact canonical project version;
- project-owned P11 logical circuit count;
- durable POWER circuit selection count and selected equipment IDs;
- durable group RCD assignments (v22);
- canonical diff **only** when the caller supplies a genuine frozen
  `baselineSelections`. An absent baseline is NOT treated as an empty
  project or used to manufacture a proposal;
- explicit messages about missing normative/fault/ADS/coordination evidence;
- permanently blocked production Apply, with required next steps.

If no canonical runtime belongs to the current screen, the panel explicitly
reports the missing runtime rather than showing legacy UI data as proof.

## Safeguards

This UI offers **no mutation control**, no temporary transaction guard,
no fabricated `EngineeringProposalDiff`, and no safety bypass. It never
changes `ProjectAggregateRoot`, `EngineeringGraph` or schema v22.
The authoritative P12 proposal generator, reviewed evidence source and
transaction-bound Apply have not yet been composed into the production
runtime, so **D04 remains PARTIAL** until those are qualified.

## Test scope

`test/p12_engineering_review_panel_test.dart` asserts that:

1. Missing canonical project is shown as unavailable with blocked Apply.
2. A real canonical project can be inspected without a fabricated diff.
3. Diff is displayed only when the test provides an actual before snapshot.

Next UAT on macOS: click the P12 action in both desktop and compact
windows, confirm scrollability, accurate project version and selections,
no UI overflow, no fake Diff, and blocked Apply after Save/Reopen.

Release gate: exact-SHA Flutter/macOS and all required acceptance jobs must
pass. PR #32 must not be merged as qualified P12 Apply before a complete
source-backed proposal/evidence flow has been accepted.
