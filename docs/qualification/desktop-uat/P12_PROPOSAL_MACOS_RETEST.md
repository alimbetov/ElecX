# P12 EngineeringProposalDiff Desktop UAT — execution protocol

**Status:** NOT YET EXECUTED ON REAL MAC GUI FOR THIS SHA.
GitHub Actions is not evidence that a human or desktop UI agent
clicked the production P12 review after a fresh native app relaunch.

## Scope and engineering boundaries

The production UI now accepts an optional `P12EngineeringProposalSource` from
the canonical editor bootstrap. This port is not currently populated by a
production evidence provider; a normal launch must honestly show an unavailable
proposal. No mock source must be injected into production to obtain a green UAT.

The read gate rejects a source result unless it matches the currently
opened `ProjectAggregateRoot.id`, project version, P11 engineering state
fingerprint and POWER selections fingerprint. The UI renders the exact
`EngineeringProposalDiff.entries` and `issues` only for accepted snapshots.
The external producer remains responsible for authentic P12A.7 engine/evidence
provenance and refreshing stale results. Neither proposal display nor a
successful read gate qualifies Production Apply.

## macOS Codex execution (same branch, do not merge)

1. In a clean worktree on `feat/p12a8-engineering-preview-diff`:
   `git fetch origin`, `git rev-parse HEAD`, `git status --short`.
   Record exact branch and commit SHA. Preserve existing local user work.
2. With the project-pinned Flutter 3.47.7:
   `flutter doctor -v`, `flutter pub get`, `flutter analyze`,
   `flutter test test/p12_engineering_proposal_source_test.dart`,
   `flutter test test/p12_engineering_review_panel_test.dart`.
3. Launch real application: `flutter run -d macos -t lib/main.dart`.
   Verify titlebar and that the production editor, not an integration-test
   runner, is foregrounded.
4. Through UI only: unlock, create/open a project, create a building and
   four rooms, place a board and a socket, connect a group, enter load
   and unqualified protection, save.
5. Click `p12-review-open` in desktop (1280×800) and compact (~800×628).
   Verify the canonical project version and P11/POWER/RCD counts; the
   prototype group does **not** become an authoritative P12 selection.
   In the normal unconfigured production launch, assert
   `p12-review-proposal-unavailable`, `p12-review-diff-unavailable`
   and `p12-review-apply-blocked`; verify no Apply control can be used.
   Close the dialog and check no keyboard/focus trap or overflow.
6. Save, exit using Cmd+Q, relaunch the ordinary main.dart application,
   unlock, open the same project and verify the stored geometry, equipment,
   group parameters, and the same P12 review states. Do not seed Drift
   or canonical repositories directly.
7. Run the native integration scenario separately from the ordinary app:
   `flutter test integration_test/desktop_user_journey_test.dart -d macos`.
   Record warnings about leftover runner processes; terminate only this
   test's processes and relaunch main.dart for final production screenshots.
8. Keep genuine screenshots, an AX accessibility transcript, test logs and
   actual PNG dimensions (read PNG IHDR, not signed/endianness-swapped data).
   Report PASS/PARTIAL/FAIL per step, exact SHA, and reproduction steps
   for each visual defect.

## Distinguish success states

- **UI wiring PASS**: button opens, canonical state and blocked reasons are
  displayed correctly and survive actual Save/Reopen.
- **Proposal rendering PASS (test/injected capability)**: separately
  validated source-backend integration supplies a properly pinned
  `EngineeringProposalDiff`, with selected/unresolved entries and issue codes,
  and bad project/version/fingerprints are rejected.
- **Production proposal qualification PASS**: requires the real P12A.7
  provider, independently authenticated manufacturer/normative evidence and
  source-bound calculation inputs. This has **not** been achieved.
- **Production Apply PASS**: requires separate full safety acceptance and
  transactional revalidation. Currently BLOCKED intentionally.

Write any new native screenshots and an updated
`docs/qualification/desktop-uat/FINAL_REPORT.md` with observed results.
Do not mark a step PASS merely because CI is green. Do not push/merge
unrelated changes or bypass SHA-256 / safety checks.
