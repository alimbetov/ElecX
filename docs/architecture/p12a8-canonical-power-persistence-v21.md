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

## P12A.8 reserved preview-only command (qualification pending)

`EngineeringReservedProjectCommand` composes existing canonical `ReservedProjectMutationCoordinator.preview()` with a frozen, typed `CanonicalPowerSelectionRegistry`. It requires that all P12A.7 proposal entries are selected, the catalog revision and selected cable/protection IDs match, and the observed P11 engineering-state and existing selection registry fingerprints are unchanged. It **does not create fake canonical IDs** for selected existing circuits and may not silently remove previously committed selections. Its project candidate is built via the existing `ProjectMutableState` and checked by `CandidateGraphValidator` and `ProjectAggregateRoot`.

The canonical `ProjectSemanticChangeSet` records `UpdateEntityOperation(CircuitId)` for each circuit selection change. The separate `CanonicalPowerSelectionDiff` retains before/after equipment and source details. The command implements `PreviewOnlyReservedProjectCommand`, and `commitPreview()` explicitly rejects it **before** the frozen commit is attempted. This restriction is independent of DTO/preview flags and remains in place until externally approved evidence, transaction-bound revalidation and electrical safety coordination are accepted.

CI qualification and production normative validation are outstanding. This is a read-only integration milestone, not authorization for electrical installation design or Apply.


## P12A.8 electrical safety preflight (read-only)

`PowerElectricalSafetyGate` evaluates one frozen v21 `CanonicalPowerCircuitSelection` per existing P11 `CircuitId`. Its input references the SHA-256 of that *whole* selected equipment snapshot; a stale calculator snapshot cannot produce an accepted provisional result. It uses the separately reviewed v21 evidence pins and a versioned `PowerSafetyRuleProfile` supplied by the normative-ingestion boundary, not a hard-coded country default.

The gate returns one `PowerSafetyVerdict` per criterion and circuit:

| Check | Required evidence / fail-closed rule |
| --- | --- |
| Normative applicability | Pinned normative source, matching jurisdiction and application scope, trusted registry review |
| Design current | Positive `Ib` and pinned corrected cable ampacity `Iz`; reject `Ib > Iz` |
| Overload | Selected protective-device rating `In` and verified `Ib <= In <= Iz` |
| Conventional trip | Explicit `I2` and *profile-supplied, reviewed* `I2/Iz` ceiling; no assumed device trip characteristic |
| Short-circuit interruption | Explicit maximum prospective fault current and catalog breaking capacity; reject insufficient interrupt rating |
| Short-circuit thermal | Explicit device let-through I²t and cable withstand I²t; reject energy exceedance |
| Short-circuit disconnection | Explicit fault-clearing time vs profile-supplied maximum, without substituting arbitrary default |
| RCD / RCBO | Separate pinned and externally reviewed claim; unknown or absent proof is INDETERMINATE |
| Selectivity | Separate pinned coordination claim; absent proof is INDETERMINATE |

Missing measurements, stale snapshots, unknown circuits, duplicate circuit evidence, revoked sources and mismatched normative profiles cannot produce a qualified result. This is not an independent electromagnetic device simulator: RCD/RCBO sensitivity, fault-loop impedance, earthing arrangement, upstream protective coordination and selectivity curves must be established in subsequent reviewed engineering evidence.

**Critical trust boundary:** The numeric rule configuration and proof status are supplied to the preflight by application code; the generic source registry only validates identity/approval/revision/scope, not the contents of the calculation report or manufacturer coordination tables. A provisional `PASS` is therefore **not** a certification of compliance with IEC, national codes or product standards. The API deliberately hard-codes `readyToApply == false`, and the `PreviewOnlyReservedProjectCommand` cannot commit via the coordinator.

### Required production Apply acceptance (future)

1. Define and authenticate the source of each electrical rule and trace its precise clauses, jurisdiction, revision and effective scope. Do not assume an IEC revision is automatically adopted in Kazakhstan.
2. Determine all relevant maximum/minimum prospective fault-current configurations, including alternate supply scenarios; verify breaker interruption and cable thermal withstand with manufacturer evidence.
3. Verify the applicable electric-shock protection conditions: earthing arrangement, PE continuity, fault-loop impedance and required automatic disconnection time; validate actual RCD/RCBO model characteristics and residual-current coordination.
4. Independently prove selectivity/backup protection with reviewed device curves/tables, including upstream/downstream relationship and the applicable fault-current range.
5. Pin the rule and evidence snapshot to the frozen Preview; at commit, revalidate the registry revision, revocation status, selected hardware and `LocalProjectVersion` within the transaction.
6. Qualify negative/fault-injection, stale/revoke-after-preview, Undo/Redo, Save/Reopen and cross-platform exact-SHA scenarios before replacing the preview-only guard.

The gate does not infer installation conditions, country-specific tables or a default conventional trip/clearing-time limit. Those values are provided only by a reviewed normative profile.


### Safety evidence purpose and subject hardening

The trusted `EngineeringEvidenceReviewRecord` now optionally carries `evidencePurpose` and `subjectCircuitId`. The provisional RCD claim requires purpose `rcd-protection`, and the selectivity claim requires `selectivity-coordination`; both must explicitly refer to the selected P11 `CircuitId`. An unrelated but generally approved manufacturer document or route survey must not satisfy either proof. Each proof is also bound to a source ID pinned in the v21 selection and checked for approval, revision, digest and jurisdiction.

These metadata checks **do not** independently validate proof contents, RCD trip curves or manufacturer selectivity tables. Those capabilities are still required for production certification and Apply. The target project jurisdiction/application scope is a separate required input and must match the chosen rule profile; a self-declared profile jurisdiction cannot authorize itself.
