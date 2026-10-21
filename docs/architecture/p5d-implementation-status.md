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
| **P5D-E** | **presentation projection + `ProjectCompassOverlay` migration to defined / unspecified / unavailable** | **DONE + HARDENED** |
| P5D-F | application edit port, runtime identity affinity, production screen cutover | IN PROGRESS |
| P5D-G | full qualification matrix, regressions, closure | PENDING |

## P5D-E closure basis

P5D-E is considered `DONE + HARDENED` because the implementation now satisfies these invariants:

- `ProjectCompassOverlay` consumes presentation `CompassProjectionState`, not legacy `ProjectNorth`.
- States are explicit: `CompassNorthDefined`, `CompassNorthUnspecified`, `CompassUnavailable`.
- Cardinal projection is fixed for the current non-rotating `WorldCamera`: 0° up, 90° right, 180° down, 270° left.
- Unsupported projection paths fail closed as `CompassUnavailable`.
- `CompassNorthDefined` validates screen milli-degrees at runtime, not only through debug `assert`.
- Unspecified North is not represented as 0° and does not render a directional `N` arrow.
- Read-only overlay passes pointer/touch/wheel input through to the canvas.
- Defined and unspecified accessibility semantics are explicit.
- Light/dark theme smoke coverage exists.
- Overlay size and projection invariants are guarded fail-closed.
- Transitional legacy widget input has been removed as part of the following P5D-F cutover work; canonical production wiring no longer depends on the old overlay contract.

## Next gate

P5D-F must finish and be audited before P5D-G. P5D-G is the only stage allowed to mark the overall P5D package complete.
