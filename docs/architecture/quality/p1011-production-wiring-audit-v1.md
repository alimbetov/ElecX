# P10.11 production wiring audit and remediation

Date: 2026-10-29
Branch: `feat/p10-building-residential-composition`
Audited baseline: `ca5739afbcb058503cff39fa9f57da68ced7ffaf`

**P10.11 ACCEPTED: YES — implementation `b38b76d35d3dcb70a2caf157233684bfb030a2e1`.**

Both `quality` and `verification` passed on that exact implementation SHA in
[run 40928831209](https://github.com/alimbetov/ElecX/actions/runs/40928831209).
The accepted source includes all production wiring and strengthened gates below;
`ca5739af` is the audited baseline, not the acceptance SHA.

The baseline contained the TemplateId import and shared WizardSession failed-Apply
cleanup fixes. Its `verification` job passed, but `quality` failed at formatting
in [run 40922361333](https://github.com/alimbetov/ElecX/actions/runs/40922361333).
The earlier green run on `b6a38e2b` did not qualify the subsequent lifecycle fix
or the missing production UI.

## Findings and changes

| Finding | Impact | Remediation |
| --- | --- | --- |
| Site Building Wizard opened the P8 structural screen/provider | P10 could not be reached through production wiring | Site actions now open `BuildingCompositionWizardScreen` with `BuildingCompositionWizardProvider` and the existing registered Wizard port |
| Building activation resolves an active Level; the old contextual control exposed Apartment Wizard instead | A populated production project had no reachable Site-level composition action | The Site node has its own guarded Building Wizard action, independent of active Level and apartment engineering capability |
| The Q15 fixture failed while building Preview | It did not prove failure atomicity during Apply | Q15 now injects a synchronous fault in the shared canonical session after full candidate validation/change-set construction, before publishing state/history |
| Standalone cottage/tower commands required an empty Site | A usable screen alone would still fail on ordinary populated projects | Wizard orchestration reuses P10.9 Site composition for single and multiple buildings; existing unplaced buildings require explicit reviewed placements |
| P10.1 selected service purposes could remain deferred | Preview could omit requested physical entries | Selected purposes require complete explicit locations; one parent reservation materializes architecture plus P10.10 anchors in the same Apply |
| Generic Diff did not resolve cores, slabs, service anchors or typical-floor definitions | Drill-down displayed opaque IDs and omitted physical host detail | Typed projection exposes these objects, wall binding/offset and Site placement fields; the default view summarizes composition counts |
| Preview's total counted only selected categories | The reported canonical-entity total was incomplete | Total derives from the canonical added-entity diff plus additive anchor/definition metadata; apartments and shared anchors have separate counts |
| Narrow action bar overflowed at 200% text scale | Apply/Cancel could become inaccessible | Compact icon actions retain localized tooltips and 48dp targets |

## Production flow and ownership

Canonical Site → P10 screen/provider → domain-backed draft → Generate → one
ReservedProjectCommand → one frozen canonical candidate → Site/floor Preview +
semantic Diff → stale check → Apply → one canonical commit → one Undo record.

The screen supports cottage, residential tower and mixed residential complex;
published v1 template binding; physical level stack; repeated apartment mix;
common/core dimensions; local/Site placement; explicit service locations; and
optional shared Site service areas. Missing legacy placement values start blank
and are never inferred from names or display level numbers.

The ID-free candidate carries normalized request/candidate fingerprints, exact
published template bindings, generator version, selected P9 candidate evidence,
validation evidence and deterministic rank. Only the shared reserved preview
materializes canonical identities. Apply uses that frozen candidate; it does not
rerun P9 selection or allocate replacement IDs.

Generated entry targets use explicit source building/level slots, typed SpaceUsage
and a selected building-local wall/offset/height. Their applied authority is the
same canonical BuildingId/LevelId/SpaceId plus P7 BoundaryEdgeId/offset registry
used by P10.10. No room-name matching, display-number identity or cached wall XY
is introduced. Areas have explicit Site coordinates.

No screen-local ProjectMutationSession, EntityIdFactory, history, recovery store
or persistence owner is created. Navigator resolves the existing production port
from CanonicalEditorWizardRuntimeRegistry and returns the ordinary commit result
to the existing authoring/owner callback. Save/reopen uses the current v18 codec.

Startup remains **New Project → P8 BasicBuildingWizardProvider → ProjectWizardScreen**.
The P10 provider supports Site scope only and does not replace the compatibility
seed or change the legacy startup binding.

ProjectCommitGuard is an optional synchronous rejection/fault-injection boundary
on the existing ProjectMutationSession. Preview and no-op commands do not call it.
For Q15 it throws after canonical validation and change-set construction, before
`_current`, the durable edge ledger, Undo or Redo stacks are changed. Production
without a guard keeps the existing behavior. The gate is commit-time atomicity;
asynchronous Save continues to use the existing persistence/recovery contract.

## Qualification matrix

| Gate | Evidence | Assertion |
| --- | --- | --- |
| P10-Q13 | `p1011_commit_lifecycle_qualification_test.dart`, all three families | Cancel preserves full canonical bytes/version/history; 0 active previews; retained preview cannot commit |
| P10-Q14 | Same suite, all three families | Concurrent North edit is the only mutation; stale Apply discards preview/command/reservation; explicit rebase creates a fresh preview |
| P10-Q15 | Same suite, all three families | Successful Preview precedes a fully validated commit-time fault; exact original bytes/version, 0 Undo/Redo, 0 active previews, retained reservation rejected |
| P10-Q16 | Same suite, all three families | Exactly one Apply/Undo boundary; Undo removes architecture, anchors and child lineage; Redo matches complete canonical bytes and IDs except monotonic LocalProjectVersion |
| UI-01 | `p1011_site_wizard_production_ui_test.dart` | Site node opens the actual P10 screen/provider through the registered shared port; system Back discards preview; all three family controls generate production candidates |
| UI-02 | `p8_project_hub_wizard_flow_test.dart` | New Project still opens P8 screen/provider and creates the compatible startup structure |
| OWNER-01 | UI production-handle test and `p1011_provider_contract_test.dart` | Same live canonical owner/session/port accepts one Apply; Undo/Redo and save/reopen preserve the seed and exact generated identities |
| Presentation | UI and provider-contract suites | Parameter edits invalidate reservations; private exception text is not rendered; typed Diff and canonical Site/floor scenes use the frozen candidate; 360/900/1440px and 100%/200% text scale are covered |

The focused P10.11/runtime/bootstrap run passed 41 tests, including 32 new tests.
All 1803 repository tests passed locally with `flutter test --no-pub --concurrency=2`.
Analyzer is clean, all 832 lib/test Dart files are formatted and `git diff --check`
passed. The exact-SHA GitHub run above passed the default-concurrency full test
suites in both jobs, formatting, analyzer and P8 NFR/accessibility/i18n gates.
The branch's documentation closure is also subject to its own HEAD CI check;
no green check from an earlier implementation is substituted for a changed source.

P10.12 building/site parent provenance and the full P10.13 platform/qualification
matrix are outside this remediation. Existing P9 and typical-floor lineage are
preserved and qualified; P10.12 implementation has not started.
