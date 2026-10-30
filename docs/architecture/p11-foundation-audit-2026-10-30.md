# P11 foundation audit — 2026-10-30

Audited branch: `feat/p11-engineering-graph-foundation`.
Baseline commit: `bc487a9b44ca4a3a67afd6981a1b14e8acf727f8` (tree
`044d8697d6be664809326ffea0fa4b2edcfc871c`). Main is
`06bb2dc8938871082c50a4dee0a25724788af6ff`; baseline is 20 commits ahead, 0 behind.
Baseline Flutter run [41017095372](https://github.com/alimbetov/ElecX/actions/runs/41017095372)
passed. The earlier P11.7 SHA `626a9a07ee4976f9026da7a6a206e16819203c6d` is
also verified green in run [41011272078](https://github.com/alimbetov/ElecX/actions/runs/41011272078).
Green baseline CI did not cover the defects below.

## Findings and remediation

| ID | Severity | Reproduction / consequence | Remediation |
| --- | --- | --- | --- |
| A01 | High | Supply starts traversal at a component instead of the declared port. A valid outgoing stub on port A can authorize a circuit fed only from port B. Traversal ignores medium and legacy system family, including the target edge. | Reachable **connection IDs** are computed from the exact source endpoint, matching both system key/family and explicit medium throughout. Source/circuit/target medium evidence is used; completely unspecified legacy media remain compatible. |
| A02 | High | An edited semantic connection does not impact its target component. A legal connection between different ports of the same component projects an illegal impact self-edge. | Changed connections invalidate downstream endpoints; declared semantic relations remain filterable, symmetric relations include both targets. Same-component semantic self-edges are omitted while connection -> component evidence remains. |
| A03 | High | Loops/groups and source metadata have canonical IDs but no impact references or membership projection. Their edits cannot seed selective recalculation. | Existing typed identities now project into the same ImpactGraph: connection -> loop, loop -> circuit, all group members -> group, component -> source identity -> supplied circuits. No new canonical owner. |
| A04 | Medium | A literal medium named `<unspecified>` collides with null in compatibility signatures. Opaque system keys containing the separator collide across field boundaries. Valid independent contracts are rejected as duplicates. | Signatures use JSON tuples with actual null and escaped values. Genuine duplicate/ambiguous contracts remain rejected. |
| A05 | High | Drift catalog writes only enum connection types and silently drops explicit P11 port media/capabilities. | Unsupported P11 evidence is rejected before any database call. Revalidation during transactional insertion protects against mutable catalog input changes. P11.9 must implement lossless storage before allowing these records. |

Regression suites: `test/p11_audit_regression_test.dart` (10 scenarios) and
`test/p11_legacy_catalog_storage_guard_test.dart` (2 cases, zero storage calls).
Existing P11.1–P11.8 graph suites, impact tests, P9/P10 regressions and full
repository quality/verification remain required on the remediation commit.

A standalone probe using the production domain classes reproduced A01, A02 and
A04 before changes, then verified rejection/correct traversal after changes.
Core domain analyzer passes locally. Full Flutter analyzer/tests run in CI,
including the actual Drift repository boundary test; the probe is not a
substitute for those gates. No native platform qualification is claimed here.

## Remaining P11 scope

P11.8 has graph-only fingerprint/diff primitives. This audit does not label the
package accepted and does not implement a partial persistence cutover.

One P11.8 acceptance boundary must cover:

1. One project-owned engineering aggregate including graph, circuits, ordered
   loops, groups, sources/assignments and explicit vocabulary/profile versions.
2. Existing EntityIdFactory/reservation/mutation owners for newly introduced IDs;
   candidate validation, stale rejection, one atomic commit and one Undo record.
3. Deterministic aggregate fingerprint/diff including every semantic field.
   Reordering sets must not change identity; loop order and source role changes
   must be visible. The current graph-only functions do not cover these fields.
4. Schema v20 codec and migration from v19 through the production repository
   factory; reject corrupt/unknown/duplicate/dangling evidence without partial state.
5. Production Save -> destroy in-memory state -> Reopen with exact IDs, identical
   aggregate fingerprint and empty semantic diff, plus Undo/Redo and failed-write
   qualification using the same persistence owner.

P11.9 remains Equipment Catalog mapping and lossless persistence integration.
P11.10 remains the combined hard-gate corpus and final acceptance. P12 and merge
into main remain downstream of full P11 acceptance. Readiness percentages are
not evidence of completion; qualification applies to explicit scope and SHA.
