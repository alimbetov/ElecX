# P5D implementation status

Branch: `feat/project-structure-authoring`

This file is the current implementation tracker for P5D. Historical audit documents remain point-in-time records and are not rewritten to hide earlier findings.

## Status

| Stage | Scope | Status |
| --- | --- | --- |
| P5D-0 | semantic split, daylight compatibility, provenance boundary | DONE |
| P5D-A | canonical `ProjectEngineeringNorth` + `ProjectEngineeringMetadata` | DONE |
| P5D-B | P3 mutable root state, metadata diff, Set/Clear, Undo/Redo | DONE + HARDENED |
| P5D-C | canonical codec v2, v1→v2 migration, semantic fingerprint, repository round-trip | DONE + HARDENED |
| P5D-D | transient requested/effective visibility and Focus Mode semantics | DONE + HARDENED |
| P5D-E | presentation projection + `ProjectCompassOverlay` migration to defined / unspecified / unavailable | DONE + HARDENED |
| **P5D-F** | **application edit port, runtime identity affinity, production screen cutover** | **DONE + HARDENED** |
| **P5D-G** | **full qualification matrix, regressions, closure** | **IN PROGRESS — FINAL HEAD CI GATE** |

## P5D-F closure basis

P5D-F is considered `DONE + HARDENED` because production wiring now satisfies these invariants:

- Project North editing is exposed through `ProjectNorthEditingPort` and shares the same P3 mutation timeline as structural authoring.
- production editing is enabled only for exact screen/canonical/persistence-owner project identity affinity;
- missing ownership callback or persistence-owner mismatch keeps the compass read-only;
- canonical Project North commits never dirty the legacy editor document as a fallback persistence path;
- same normalized Project North is a no-op and does not emit an ownership receipt;
- stale dialog/version context fails closed before mutation;
- open/workspace replacement re-resolves the canonical runtime rather than retaining stale bindings;
- production canonical wiring contains no `workspace.updateProjectNorth()` fallback;
- synchronous `CanonicalAuthoringOwnershipReceipt` is explicitly not a durable-save acknowledgement;
- baseline HEAD `3fab65b49bee9fbc850d92bb564fdf6ac28940a3` passed Flutter #1911 and macOS Desktop #231.

## P5D-G qualification

P5D-G is now active. The authoritative qualification record is:

```text
docs/architecture/p5d-g-closure-note.md
```

Additional closure coverage is provided by:

```text
test/p5d_g_closure_test.dart
```

It explicitly qualifies schema-v2 null round-trip, canonical repository Project North persistence, presentation-only shell state, and same-number cross-building Level identity isolation.

## Final gate

P5D-G is the only stage allowed to mark the overall P5D package complete. It moves to `DONE + HARDENED` only after the final branch HEAD containing the qualification record passes the complete Flutter and macOS Desktop workflows.
