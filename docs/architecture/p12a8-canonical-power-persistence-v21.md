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

### Independent finding required for RCD/selectivity PASS

An engineer or UI-supplied `PowerSafetyClaimStatus.supported` is never sufficient to return `PASS`. The trusted, authenticated evidence registry must also return an explicit `EngineeringVerifiedSafetyFinding.supported` on the matching document, purpose and P11 circuit. If the authenticated review has no finding, the result is `INDETERMINATE`; an authenticated contradictory finding or a contradictory caller claim returns `FAIL`. A source digest or approval ID proves an identity/review record, not the electrical calculation itself.

This improves trust-boundary separation but does not create a real protection-coordination engine: the review ingestion must still validate RCD/RCBO technical parameters, manufacturer curves, protection selectivity and jurisdictional applicability before those findings are fit for production.


### Authenticated numeric rule profile binding

The provisional `PowerSafetyRuleProfile` now exposes a deterministic `fingerprint` of its numerical limits, source identity, jurisdiction and application scope. A source review that merely attests the normative document does **not** attest values extracted from it. The trusted `EngineeringEvidenceReviewRecord.verifiedRuleProfileFingerprint` must match the **exact** selected policy fingerprint for `normativeApplicability = PASS`. Missing or changed numeric limits yield `INDETERMINATE` and prevent all downstream calculation criteria from passing.

Only the trusted normative ingestion boundary may populate this attestation after independent rule extraction, effective-date/applicability checking and engineering review. An in-memory test fixture is not evidence of real-world compliance. The `PreviewOnlyReservedProjectCommand` and `readyToApply == false` restrictions remain unchanged.


### Audit hardening: attested measurements and switchboard checks

Quantitative safety measurements are now bound to their exact authoritative circuit and frozen selection by `PowerCircuitSafetyEvidence.calculationFingerprint`. The independent trusted record for `calculationSourceId` must contain an identical `verifiedCalculationFingerprint`. A generic approved document, source ID, or unchanged equipment selection does not authorize caller-modified current, thermal energy or clearing time. Missing/mismatched measurements yield `INDETERMINATE` for the quantitative checks, not a provisional PASS.

Additional separate preliminary checks:
- `boardShortCircuitWithstand`: compare the explicitly supplied prospective maximum fault current with the reviewed board short-circuit withstand rating.
- `cableVoltageRating`: fail when the selected cable rated voltage is lower than the reviewed board rated voltage.

These checks are **not** a full switchboard assembly design evaluation. The board's catalog withstand type must match the actual manufacturer rating basis, protective-device coordination, duration, conditional rating assumptions and fault clearing scenarios before production approval. A non-verified source can never be promoted into a real certified electrical design by this preliminary gate.


### P12A.8 follow-up: provisional max/min fault envelope (2026-11-08)

`PowerCircuitFaultEnvelope` is a **read-only preflight** for one canonical P11 CircuitId. For each independently listed supply case (e.g. grid and standby power) it requires positive, ordered maximum/minimum prospective fault currents, maximum let-through thermal energy, cable withstand energy and minimum-fault clearing time. Different supply scenarios cannot be substituted for one another. A duplicated supply key, a missing case relative to the independently provided expected supply IDs, or a stale envelope yields a rejected/INDETERMINATE outcome.

`PowerFaultEnvelopeGate` compares the highest prospective fault current across cases with both protective-device breaking capacity and reviewed board withstand, checks thermal energy for *every* case, and checks minimum-fault disconnection time for *every* case against the attested normative profile. A trusted, non-revoked record must attest the exact entire envelope fingerprint, its pinned source revision/hash/approval, the canonical P11 CircuitId and `fault-envelope` evidence purpose. The normative timing rule profile fingerprint must also be independently attested. None of these values may be substituted from a country default.

**Remaining production blockers:** The preferred `evaluateForEngineeringState` entry point now derives expected source IDs from authoritative P11 `EngineeringProjectState.circuitSupplies` rather than caller-controlled values; however the actual transfer/supply-mode inventory and exclusivity scenarios are not yet fully qualified; the fault envelope must be cross-validated with electrical network parameters, source impedance, cable route impedance, earthing/PE continuity, breaker trip curves and verified upstream/downstream coordination. A separate preliminary envelope PASS must not grant production Apply or be construed as a certified electrical installation design. `readyToApply` remains false; `EngineeringReservedProjectCommand` remains preview-only.


### P12A.8 follow-up: device-specific RCD/RCBO, ADS and selectivity (2026-11-08)

`PowerProtectionDeviceGate` adds a **provisional**, independently reviewed
characteristics contract for concrete catalog devices:

- Residual-current device: selected protection catalog ID, device type,
  manufacturer/test source ID, rated residual current, measured operating
  residual current, applied test stimulus and measured trip time. The exact
  tuple is fingerprinted and must match an authenticated source record
  scoped to the same canonical P11 circuit and evidence purpose.
- Normative device thresholds: residual operating limit and trip-time limit
  must be independently attested as an exact digest, linked to a separately
  authenticated numerical `PowerSafetyRuleProfile`. No hard-coded trip
  thresholds or default RCD type are used for production policy.
- Selectivity: an explicit downstream/upstream protective-device catalog pair
  plus a reviewed fault-current coverage interval endpoint. The trusted
  source attests the exact pair, upstream identity, source revision/digest,
  circuit and a positive manufacturer/engineering coordination finding.
  Measured time ordering *alone* is never treated as proof of selectivity.
- Automatic disconnection: a passing, source-reviewed max/min fault envelope
  with full supply coverage and a matching frozen envelope fingerprint is
  mandatory. A result from another circuit, supply scenario or outdated
  envelope cannot be reused.

`PowerApplySafetyRevalidation` composes the existing quantitative checks,
canonical P11 supply-based max/min fault envelope and device-specific protection
checks across **every** selected circuit. It rejects incomplete circuit coverage,
mismatched project/selection fingerprints or changes to the trusted registry
revision before/after evaluation. The existing
`ReservedProjectMutationCoordinator.commitPreview()` now requires
`TransactionalEngineeringSafetyRevalidation` on future P12 commands and invokes
it immediately before the normal canonical transaction; missing or rejecting
revalidation fails without consuming the reservation or mutating project state.

**Important:** this is a commit-boundary contract and a tested read-only
qualification path, not permission to Apply. The current
`EngineeringReservedProjectCommand` remains
`PreviewOnlyReservedProjectCommand` and is rejected by the coordinator first.
A future production-authorized P12 command must use authenticated, consistent
registry snapshots, authoritative upstream-device topology, real manufacturer
time-current/coordination evidence, earthing and fault-loop checks, applicable
jurisdictional rules and full exact-SHA CI/security qualification. This PR
**must not** be treated as certified RCD, ADS or selectivity engineering
without that validated ingestion and production acceptance.


### P12 safety hardening: combined evidence identities and mutation guard

Independent numerical review fields are mandatory for their individual roles:
`verifiedCalculationFingerprint` (Ib/In/Iz, thermal and fault inputs),
`verifiedFaultEnvelopeFingerprint` (all source max/min scenarios),
`verifiedProtectionLimitsFingerprint` (normative RCD thresholds),
and device-specific proof fingerprints tied to exact catalog IDs.
A single signed source may attest multiple disjoint engineering snapshots
without one proof overwriting another.

The coordination review must also name the authenticated
`verifiedUpstreamProtectionCatalogId` for the exact downstream/upstream pair;
an arbitrary caller-supplied upstream ID is not enough. A positive preliminary
review does not yet establish that the pair exists in the authoritative
distribution-board topology: that reconciliation is a production blocker.

The mutation coordinator now requires commit-boundary safety revalidation
whenever **canonical POWER selections change**, irrespective of the command's
claimed type/name. Renaming a mutating command cannot bypass the P12 guard.
The existing P12A.8 engineering command remains preview-only even if a
separate revalidation object passes. Production authorization is still closed.


### P12A.8 safety audit: ADS also requires earthing and PE evidence

Following the device review, automatic disconnection of supply (ADS) cannot
receive a provisional PASS merely because a reviewed breaker/fault scenario
contains a clearing time. `ReviewedEarthingDisconnectionEvidence` now requires
an explicit earthing arrangement, independently reviewed measured fault-loop
impedance, verified protective conductor continuity, exact P11 circuit and
protective-device catalog identity, and a pinned approved source record with
purpose `earthing-and-ads`. The whole measurement tuple is fingerprinted.

Missing/revoked/unmatched review leaves `earthingAndPeContinuity` and ADS
`INDETERMINATE`. Verified broken PE continuity is a hard `FAIL`. Passing
grounding/PE evidence is a necessary input to ADS but is **not** itself
proof of protection coordination. A production engineering review must check
the earthing arrangement, circuit-specific fault-loop impedance requirements,
device operating curve, protective bonding and relevant field tests.

The current test fixture reuses a pinned route/survey evidence source as a
mock of a trusted PE/earthing report; **this must be replaced by a dedicated,
authenticated installation measurement report in production**. The existing
preview-only restriction remains fully active. No code in P12A.8 may claim
that an installation meets a national or IEC standard solely from these
in-memory test fixtures.


### Device-kind integrity: MCB is not an RCD

The canonical v21 selection contains `protectionRatings.deviceKind`.
`PowerProtectionDeviceGate` now requires an actual `rcbo`-kind selection
with a matching reviewed RCBO manufacturer/test characteristic before an
RCD/RCBO claim can produce `PASS`. A selected ordinary `mcb` cannot be
promoted to residual-current protection by passing an unrelated source
claim, even when the caller writes "RCBO" in test metadata. Negative
regression coverage asserts this failure mode.

Residential boards may legitimately have **MCB + separate upstream RCD**
instead of RCBO on each outgoing circuit. That topology is **not** represented
as a complete linked protective-device pair in the current canonical POWER
selection. The correct result for such circuits is `INDETERMINATE` pending
explicitly persisted RCD device identity, upstream ownership, affected
circuits, earthing/protection review and manufacturer coordination evidence.
The temporary RCBO-qualified test fixture is distinct from the original
MCB selection and does not overwrite P12A.7's MCB catalogue behavior.


### Dedicated upstream RCD coverage for a canonical MCB circuit (proposal-stage)

`CanonicalResidualProtectionAssignment` now provides an immutable,
fingerprinted P11 `CircuitId` coverage list with owning board `ComponentId`,
downstream MCB catalog ID, upstream RCD catalog ID and independently pinned
source ID. `PowerProtectionDeviceGate` may treat a canonical MCB as having
residual-current protection only when a distinct reviewed RCD device
characteristic matches that **exact** upstream catalog and
`EngineeringEvidenceReviewRecord.verifiedResidualTopologyFingerprint`
matches the full assignment, in addition to normal approval, purpose,
revision, source hash, jurisdiction and circuit checks. Missing reviews
and a substituted circuit remain `INDETERMINATE`.

`PowerApplySafetyRevalidation` accepts optional per-circuit upstream RCD
assignments and passes them into the protection gate. No assignment is
automatically inferred from proximity, board membership or a manufacturer
document.

**Lifecycle limitation:** this assignment is currently a frozen,
reviewed **proposal-side object**. It is not yet durably encoded in project
schema v21 and not cross-checked against independently materialized upstream
protective-device entities in the authoritative P11 graph. Consequently it
cannot authorize production Apply; next acceptance requires an additive
canonical persistence revision, complete group-RCD topology and protection
selectivity between all actual associated devices. Existing
`EngineeringReservedProjectCommand` remains preview-only.


### Canonical v22 group-RCD persistence and P11 physical-device ownership

P12 now uses `CanonicalResidualProtectionRegistry` as a **project-owned**
immutable ledger in `ProjectEngineeringMetadata.residualProtection`, not a
detached engineering sidecar. The project is written by
`ResidualProtectionAwareCanonicalProjectDocumentCodec` as **schema v22**,
with an additive `residualProtection.assignments` payload. Native repository
construction uses this codec. Schema v1–v21 documents decode with an empty
ledger; the v21 codec rejects writes of non-empty v22 group-RCD data instead
of silently discarding them.

Every durable assignment carries both P11 `boardComponentId` and a distinct
P11 `upstreamResidualComponentId`, plus a manufacturer/catalog key,
explicit covered `CircuitId` values, downstream MCB catalog ID, and
pinned evidence source. Validation happens on **every**
`ProjectAggregateRoot` construction and insists that (a) the actual RCD
component exists with a matching component type, (b) its input is wired from
the declared board, (c) each covered circuit is routed outward through that
RCD, (d) that circuit cannot bypass the RCD directly from its board, and
(e) each MCB circuit is selected in the canonical POWER registry. Duplicate
device IDs and double protection ownership are rejected. Distinct physical
RCD devices may use the same manufacturer catalog part.

The canonical mutation diff now tracks `residualProtectionChanged`.
Dedicated regression tests cover v21→v22 migration, v22 JSON repository
Save/Reopen, deterministic re-encoding, missing P11 entities, foreign board,
duplicate ownership, metadata diffs and Undo/Redo. The mutation core
`ProjectMutationSession.commit/undo/redo` now fails closed for POWER/RCD
changes when no `ProjectCommitGuard` is installed. The reserved coordinator
also requires transaction-bound engineering revalidation; that preflight
compares every caller-supplied RCD proposal with the **exact durable
candidate RCD ledger**. A transient RCD review cannot authorize a mutation
of unrelated project ownership.

**Not yet a production release:** An authenticated production commit guard
must re-check registry/source revisions and real electrical engineering
evidence in the same consistency boundary as the canonical project update.
Test commit guards are mock callbacks and are not electrical authorization.
Multi-circuit group RCDs with different downstream MCB catalogs need a
per-circuit catalog mapping before generalized production authoring.

### Manufacturer catalog and coordination intake — acceptance requirements

Manufacturer-specific RCD, RCBO and MCB approval must be grounded in an
actual product article/model, rated characteristics, test conditions and
the **exact** manufacturer coordination table and revision for the two
selected protective devices. `ReviewedProtectionCoordination` now
requires `manufacturerId`, `coordinationDocumentRevision` and
`coordinationTableId` before any preliminary selectivity PASS; all fields
are covered by the trusted source fingerprint. A generic approved report
or a nominal breaker label such as `mcb-b16` does not qualify.

Reference manufacturer publications for ingestion research:
- Schneider Electric 2026 Selectivity, Cascading and Coordination Guide:
  https://www.se.com/sa/en/download/document/LVPED318033EN/
- Schneider Electric RCD coordination guidance:
  https://www.se.com/be/en/faqs/FAQ000277195/
- Schneider Electric time-current characteristic overview:
  https://www.se.com/uk/en/faqs/FAQ000283725/

These references define the type of records the system must ingest; they
do not prove compatibility of any particular unnamed project device pair.
All `TEST-MANUFACTURER` identifiers and numeric test fixtures are synthetic.
No real manufacturer compatibility certificate has yet been loaded into
the authenticated registry. The current P12A.8 engineering command is
still PreviewOnly and cannot commit to production.


### P12A.8 follow-up: v22 mixed-MCB group coverage and feed bypass review

The v22 group-RCD ledger supports one physical RCD protecting a group of
P11 circuits with *different* downstream MCB catalog articles. The immutable
`downstreamCatalogOverrides` field is keyed by canonical `CircuitId`,
strictly persisted as part of the v22 document and group fingerprint.
Selection matching uses the actual per-circuit MCB catalog identity, never
the nominal group default for an overridden circuit. Both missing and foreign
override keys are rejected. Separate physical RCD component IDs may reuse a
manufacturer model number without incorrectly colliding.

P11 validation checks the board→RCD feed globally, then the RCD→protected
circuit path separately for each circuit. This supports a common upstream
feed, rather than incorrectly demanding separate physical board→RCD wires
for every outgoing circuit. A circuit-specific directed graph traversal
excluding the RCD rejects an alternate direct **or indirect** board→load
feed that would bypass the device. This is a necessary structural topology
check, but not proof of neutral grouping, actual terminal placement,
conductor sizing, terminal limits, polarity or installed wiring. Those remain
required independent field/device verification evidence.

Manufacturer tests in this PR use synthetic `TEST-MANUFACTURER` documents
and catalog codes. Official sources such as Schneider Electric's 2026
coordination guide and the RCD coordination guidance are used to define
required ingestion fields only. A production manufacturer pair cannot
be accepted without the exact product/model numbers, the applicable
table and revision, source content hash, measured/reviewed characteristics,
operating conditions and an independently approved coordination result.


### P12 Manufacturer Evidence Registry — article-pair qualification (2026-11-08)

The new `manufacturer_protection_pair_gate.dart` contains a typed,
immutable `ManufacturerCoordinationCatalogSnapshot` and an
independently attested `ManufacturerPairEvidenceGate`.

- The downstream MCB/RCBO and upstream protective device must have **exact
  manufacturer identifiers, article numbers, device kinds and catalog
  revisions**. Generic B16, type A and rated current labels are insufficient.
- Every coordination row identifies its exact P11 `circuitId`, manufacturer
  document revision, document SHA-256, table ID and covered prospective
  fault-current range endpoint. Pair rows with identical circuit/article
  identities cannot coexist ambiguously in one snapshot.
- The selected canonical protection catalog ID must equal the attested
  downstream article, and the upstream article must match the selected
  upstream product. Cross-circuit and cross-article reuse fails closed.
- An independently provisioned `TrustedEngineeringEvidenceRegistry` must
  verify **all** existing source pins, approval, jurisdiction and application
  scope, and additionally attest
  `verifiedManufacturerPairFingerprint` with purpose
  `manufacturer-coordination`. A document hash alone, caller-created
  snapshot or unsigned catalogue row does not yield PASS.
- Explicitly contradicted review yields FAIL. Missing, revoked, mismatched
  or unverified evidence yields INDETERMINATE. A verified pair whose
  prospective short-circuit duty exceeds its reviewed coverage yields FAIL.
- `ManufacturerPairAssessment.readyToApply` remains **false**. This
  is a preflight module, not yet an authorizing part of production Apply.

Tests use fabricated `TEST-VENDOR` articles and proof digests. They
exercise immutability, duplicate-pair rejection, review identity,
revocation, contradicted evidence and fault range. **No genuine device
coordination is asserted**. Engineering release still requires verified
manufacturer documents and an authenticated ingestion adapter with
consistent versioned snapshot semantics.

The Android native acceptance failures on the previously evaluated SHA
are separate from this engineering contract: a Gradle distribution download
returned HTTP 504, while Android SQLite hook downloads produced unexpected
SHA-256 hashes. Never accept a mismatched binary or disable native asset
integrity verification. Until those issues and the new exact-SHA CI resolve,
PR #32 remains Draft and Apply remains PreviewOnly.
