# P12 Manufacturer Evidence Registry R1 — evidence admission and device coordination

Status: **implementation and CI qualification in progress**. This is an additive
P12A.8 preflight in PR #32, not a production electrical certification and not
an authorization to commit `EngineeringReservedProjectCommand`.

## Source separation

1. **Official article identity (discovery only):** identify an actual
   manufacturer and article from its official product page, without inferring
   protection suitability or pair selectivity.
2. **Immutable manufacturer document:** obtain the exact PDF/datasheet or
   coordination-table artifact as bytes. Compute SHA-256 of the unmodified
   bytes. Record the publisher's HTTPS URL and the stated document revision.
   The hash alone does not establish authentic publisher origin.
3. **Publisher authentication:** `ManufacturerPublisherProvenanceVerifier`
   is the explicit external trust boundary. It must use independently
   configured publisher trust (not caller-supplied hostnames or a preview).
   Reject untrusted publisher artifacts.
4. **Independent engineering review:** the trusted registry must pin the
   document source revision, SHA-256, approval, jurisdiction, scope, circuit
   and `verifiedManufacturerPairFingerprint` of the exact model articles,
   coordination table and reviewed fault coverage. Revocation/contradiction
   is independently checked.
5. **P11/v22 integration:** `ManufacturerProjectCoordinationGate` binds
   each admitted document row to the actual canonical selected MCB catalog
   ID, assigned upstream RCD catalog ID, P11 circuit and fault envelope.
   The baseline P11 state/POWER selection/RCD registry fingerprints and
   registry revision must remain unchanged.

No PDF extraction or automatic self-approval is performed by the ingestion
boundary. A qualified reviewer must produce and sign the structured
coordination row, with the reviewed operating conditions. The current
`ManufacturerPublisherProvenanceVerifier` is **an interface**: a production
key-pinned verification adapter and a durable revocation store have not yet
been delivered. The unit-test publisher verifier is deliberately synthetic.

## Concrete manufacturer discovery (article identity only)

Official Schneider Electric source references:

| Article | Identity from official manufacturer | Source | Qualification |
| --- | --- | --- | --- |
| A9F74116 | Acti9 iC60N MCB, 1-pole, 16 A, curve C | https://www.se.com/sg/en/product/A9F74116/ic60n-miniature-circuit-breaker-1p-16a-c-curve/ | Article identity; **not** an approved R1 pair |
| A9R11240 | Acti9 iID RCCB, 2-pole, 40 A, 30 mA, type AC | https://www.se.com/ae/en/product/A9R11240/residual-current-circuit-breaker-rccb-acti9-iid-2p-40a-ac-type-30ma/ | Article identity; **not** an approved R1 pair |
| LVPED318033EN, v4.0 (03 Aug 2026) | Selectivity, Cascading and Coordination Guide 2026 | https://www.se.com/be/en/download/document/LVPED318033EN/ | Documentation to review; no specific article pair certified in this PR |

A generic `mcb-b16` test fixture is **not** the actual Schneider article
A9F74116. Nor is a generic `rcd-a40` fixture the actual article A9R11240.
The model currently requires exact equality with canonical catalog IDs and
P11 device type IDs, so these examples are not silently inserted into a
project. A future verified catalog migration/selection must explicitly
reference the corresponding real article numbers.

The two real articles above are *not claimed to be selective together*.
An RCCB and an MCB cover different protection functions, and the device
pair needs manufacturer-approved coordination, fault-current duty,
earthing/disconnection and field-specific applicability evidence. Do not
extrapolate a short-circuit selectivity table into differential trip
selectivity.

## R1 negative and positive coverage

The regression tests use synthetic `TEST-VENDOR` artifacts; they verify:
exact document-byte digest; trusted publisher boundary; exact revision,
source approval and P11 circuit; source revocation; explicitly contradicted
review; stale registry; missing catalog row; changed selected article;
project fingerprint drift; and failure outside reviewed fault-current duty.

Every new result reports `readyToApply == false`. Preview-only production
barriers stay intact.

## Remaining acceptance

- Provision an independently operated, cryptographic publisher trust verifier
  and review-signature validator, plus durable evidence revision/revocation.
- Obtain a byte-exact source document and a qualified, extracted
  coordination table for a *real, compatible* model pair, under verified
  applicability conditions. Do not synthesize compatibility from catalog
  descriptions.
- Add explicit electrical distinction between MCB short-circuit
  discrimination, RCCB residual-current discrimination and RCD/MCB
  backup/coordination.
- Green CI on a single exact SHA, including Android native SQLite SHA-256
  verification and Gradle distribution retrieval.
- Project transaction version/evidence revision atomicity, rollback,
  persistence, reopen and authoritative Apply acceptance.

Until all of these are green, PR #32 must remain Draft.


## R1 implementation extension: explicit coordination categories

`ManufacturerPairCoordinationCategory` now distinguishes:

- `shortCircuitSelectivity`: both reviewed downstream and upstream products
  must be devices capable of applicable overcurrent discrimination, such as
  the relevant MCB/MCCB/ACB/RCBO combinations.
- `residualDeviceBackup`: an MCB/RCBO downstream from a separately reviewed
  RCD/RCCB, where the manufacturer's *conditional* coordination/backup
  evidence explicitly supports that exact pair.

This category enters the reviewed row fingerprint, so a reviewed backup
table cannot later be reused to declare short-circuit selectivity.
Residual-current discrimination between two RCDs is a **different**
engineering calculation and is not implemented by this R1 gate.

The reference-only `ManufacturerArticleDiscoveryDirectory` includes two
actual articles from official Schneider Electric product pages. Its records
carry `isManufacturerCoordinationQualified == false`; reference identity
cannot be used to authorize the reviewed coordination or project Apply.

`ManufacturerEvidenceIngestion` accepts the original unmodified PDF bytes
and checks their SHA-256, external publisher provenance verifier, exact
approved evidence source, revision and fingerprint. Its admission type has
a library-private constructor, reducing accidental forgery by UI code.
A production `ManufacturerPublisherProvenanceVerifier` with real
cryptographic publisher identity verification has **not** been installed.
The test implementation only simulates this independent boundary.

`ManufacturerProjectCoordinationGate` evaluates these admitted records
against the permanent project-owned P11/v22 RCD topology and each selected
circuit's maximum reviewed fault case. It checks the frozen engineering
state, power-selection, RCD registry and trusted review revisions. It is
a **non-authorizing preflight** with `readyToApply == false`.
