# P12A.8 canonical POWER persistence mapping — v21 draft audit

## Architecture

P11 remains the **only** canonical engineering graph. `ProjectAggregateRoot.engineeringMetadata.engineeringState` owns the authoritative P11 components/circuits and is persisted by the project schema v20 codec.

P12A.8 adds `ProjectAggregateRoot.engineeringMetadata.powerSelections` as a **typed canonical evidence/selection registry** keyed by existing P11 `CircuitId`. It is a field of the same root metadata, not a second engineering graph, not a separate repository, and not a project-scoped UI cache.

A selection refers to:
- existing canonical `CircuitId` and board `ComponentId`;
- stable generation key, catalog snapshot and board type;
- board electrical ratings (busbar current, short-circuit withstand, nominal voltage, enclosure protection, manufacturer evidence);
- selected cable catalog key, conductor count/cross-section, rated voltage, governing ampacity and calculated voltage-drop ratio;
- selected protective device catalog key, rated current, breaking capacity, pole count, kind and characteristic;
- route length and SHA-256 evidence fingerprint;
- normative, route, fault-current, manufacturer, cable and protection source IDs;
- immutable, sorted source pins (source ID/revision/content SHA-256/approval ID).

Every stored numeric rating is explicit and finite; the registry does not infer values. Source IDs, revisions and SHA-256 preserve what was used, **not** whether an external norm or manufacturer claim is true or applicable.

## Read-only canonical Diff

`CanonicalPowerSelectionDiff.between(before, after)` returns typed `add`, `update`, `remove` operations keyed by P11 `CircuitId`, retaining full before/after canonical selection values, equipment/provenance change flags, stable sort order and deterministic fingerprint. This is not yet a `ReservedProjectCommand` and does not expose Apply.

## Persistence

- `lib/src/domain/canonical_power_selection.dart`: immutable DTOs with strict to/from canonical JSON, stable fingerprint, uniqueness and source completeness checks.
- `lib/src/domain/project_orientation.dart`: adds `powerSelections` to `ProjectEngineeringMetadata`, copyWith, equality and hash.
- `lib/src/application/project/project_mutation.dart`: `ProjectEngineeringMetadataDiff.powerSelectionsChanged`, making selection changes visible to existing canonical preview/change history.
- `lib/src/serialization/project/power_selection_aware_canonical_project_document_codec.dart`: additive document schema **v21**, decodes v1–v20 with empty registry and rejects v21 payloads disguised as older schemas; validates that selected circuit and board IDs exist in the P11 state.
- The schema v20 writer refuses a non-empty v21 selection registry. v21 encoding builds a transient v20-compatible snapshot for its base encoding, then writes the original registry as the v21 field. Production native repository factory selects v21.

P12A.8 does not introduce a second `ProjectRepository`, `ProjectMutationSession`, or Undo/Redo owner.

## Acceptance / important unresolved items

1. Execute and qualify schema v21 codec round-trip, negative malformed/duplicate tests and migration from v20 on exact SHA.
2. Add positive **non-empty** v21 project Save/Reopen through native JSON repository, using an existing real P11 graph/circuit/board fixture; confirm identical IDs/evidence and same canonical fingerprint.
3. Ensure project snapshot/revision-aware sync and other entry points use schema v21 or explicitly reject lossy writes. Audit all direct uses of older codecs.
4. Complete canonical before/after typed Engineering Diff and a reserved command only **after** this persistence layer is green; map ID-free generation proposals to an existing/reserved P11 `CircuitId`, never use catalog IDs as persistent entity IDs.
5. Technical approval and independently authenticated normative records are still missing; `readyToApply` remains false. `commitPreview()` wiring, single atomic transaction, Undo/Redo and Save/Reopen acceptance are not authorized by this mapping slice.

**Verdict:** type/codec implementation is a candidate for CI qualification, not accepted for production Apply.
