# P9 Cross-Stage Architecture Audit v2

Date: 2026-10-24  
Branch: `feat/p9-apartment-topology-generator`  
Baseline: P8 merged `main@c397302f183d023e4bdd670ac0c8b46c6fad994a`

## Disposition

```text
P9.0 prerequisite audit                  PASS
P9 v2 shared contracts                   PASS
P9.1..P9.13 specification consistency    PASS
P8 transaction reuse                     PASS
P6/P7 semantic/topology reuse            PASS
Blocking design ambiguity                0
P9 runtime implementation                NOT STARTED
Design disposition                       READY FOR IMPLEMENTATION
```

This audit evaluates specification consistency, not runtime correctness.

## 1. Audit method

Reviewed the complete flow as one typed data pipeline:

```text
P9.1 request
 -> P9.2 catalog
 -> P9.3 grammar
 -> P9.4 area
 -> P9.5 semantics
 -> P9.6 geometry/opening intents
 -> P9.7 ranking
 -> P9.8 vector projection
 -> P9.9 provider/session
 -> P9.10 P8 preview/diff
 -> P9.11 canonical materialization
 -> P9.12 provenance
 -> P9.13 qualification
```

Checked for:

- conflicting meanings/units;
- hidden identity allocation;
- duplicated transaction paths;
- UI/domain coupling;
- non-deterministic ordering;
- incomplete physical topology;
- persistence/provenance gaps;
- unsupported claims of normative compliance;
- missing merge gates.

## 2. Findings and closure

### R01 — User intent and candidate selection were conflated

**Problem:** P8 provider receives one parameter object, while candidate exploration creates a later selection.

**Resolution:** CLOSED.

P9.1 now separates:

```text
ApartmentRequestInput
ApartmentCandidateSelection
ApartmentWizardParameters(request, selection)
```

`intentFingerprint` excludes selection. Semantic request edits invalidate selection.

### R02 — Apartment area meaning with balcony/loggia was ambiguous

**Problem:** Original wording could make balcony area either consume or not consume requested apartment area.

**Resolution:** CLOSED.

P9 v1 area basis is exactly:

```text
interiorNetExcludingExteriorAppendages
```

P9.4 allocates requested interior area only to interior participants. Balcony/loggia/terrace are separate appendage areas.

### R03 — `openPlan` vs `kitchenLiving` was under-specified

**Resolution:** CLOSED.

```text
kitchenLiving = one combined SpaceUsage.kitchenLiving, counts as one habitable room
openPlan      = distinct kitchen + living/day semantic spaces with explicit open connection
separate      = distinct enclosed kitchen + habitable day/room semantics
```

No normalization between modes.

### R04 — `facadePreference` could imply verified Building facade fit

**Resolution:** CLOSED.

Renamed semantically to `ApartmentExteriorExposurePreference`.

It describes candidate-local exposure pattern (`oneSide/corner/oppositeSides`) only. Actual building facade/orientation fitting is outside P9.

### R05 — Area constraints alone allowed pathological long/narrow rooms

**Resolution:** CLOSED.

P9.2 now requires `TopologySpaceGeometryConstraints` including:

```text
minShortSideMm
minLongSideMm?
min/max aspect
min exterior exposure
max vertices
```

P9.6 enforces these as product generation constraints.

### R06 — Balcony/loggia geometry vs interior envelope was ambiguous

**Resolution:** CLOSED.

P9.6 distinguishes:

```text
interiorEnvelope
interiorSpaces
exteriorAppendages
```

Appendages attach outside/on interior boundary, never consume interior requested area and never overlap interior area.

### R07 — Adjacency graph could produce a physically inaccessible committed apartment

**Resolution:** CLOSED.

P9.6 creates typed `OpeningIntent`s. P9.11 now requires:

```text
one stable-hosted apartment entry
one canonical door/open passage for each required access edge
BoundaryEdgeId-based host
```

No unhosted or wall-index-only fake openings.

### R08 — P8 Diff did not understand apartment Zone/Space entities

**Resolution:** SPEC CLOSED / IMPLEMENTATION REQUIRED IN P9.10.

P9.10 defines first-class diff categories/titles/grouping for:

```text
StructuralZone
Space
BoundaryTopology
Adjacency
Opening
Provenance
```

Runtime acceptance closes this only when tests pass.

### R09 — Generation provenance was not yet durable enough for future P15

**Resolution:** SPEC CLOSED / IMPLEMENTATION REQUIRED IN P9.12.

P9.12 defines:

```text
GenerationManifest
EntityGenerationProvenance
generationKey
generatedProperties
overriddenProperties
lockedFromRegeneration
baseline fingerprint/value hooks
```

and requires core manual edit override tracking.

### R10 — Generated names could vary by RU/EN locale

**Resolution:** CLOSED.

Canonical generated fallback names are deterministic/locale-independent. Presentation may localize system-generated labels from semantic usage/generation key. Locale must not change canonical fingerprint.

### R11 — SVG could become accidental geometry authority

**Resolution:** CLOSED.

Single allowed direction:

```text
candidate geometry -> vector scene -> SVG/native paint
```

No SVG parsing into project state.

### R12 — Scoring could compensate for invalid plans

**Resolution:** CLOSED.

P9.7 only scores candidates with zero hard blockers. Hard semantic/geometry failures never become soft score penalties.

### R13 — Candidate diversity was unspecified

**Resolution:** CLOSED.

P9.7 defines deterministic duplicate/near-duplicate signatures, family diversity and score floor. The Wizard may return fewer than 3 rather than invent low-quality variants.

### R14 — P9 could silently grow into floor/building planner

**Resolution:** CLOSED.

P9 v1 generates exactly one apartment into an empty canonical Level.

Multi-apartment floor packing, real Building facade fitting, repeated floor/apartment composition and ЖК coordination belong to P10.

## 3. Deliberate non-goals / phase boundaries

These are not P9 blockers:

```text
arbitrary existing-envelope fitting                    -> later/P10+
multi-apartment floor packing                          -> P10
real Building facade/cardinal orientation fitting      -> P10/import authoring
structural columns/load-bearing optimization            -> later CAD scope
AI/ML free-form floor-plan generation                   -> optional future research
furniture-aware optimization                            -> future
statutory architectural compliance certification        -> separate normative validation
electrical/ELV equipment placement                      -> P12/P13
physical engineering auto-routing                       -> P14
selective regeneration execution                        -> P15
```

P9 output is deliberately engineered so these phases can consume canonical Spaces/boundaries/openings/provenance later.

## 4. Normative posture

P9 validates product-defined topology/ergonomic constraints.

It MUST NOT present generated apartments as legally/building-code compliant unless a separate qualified normative subsystem produces explicit evidence for the relevant jurisdiction/profile.

This distinction is mandatory in UX/product copy.

## 5. Data authority map

| Concern | Authority |
|---|---|
| user request | `NormalizedApartmentRequest` |
| topology definition | versioned catalog/template/grammar |
| candidate area | P9.4 integer allocation |
| semantic validity | P9.5 report |
| candidate geometry | P9.6 integer-mm model |
| candidate quality | P9.7 score breakdown |
| image/preview | P9.8 projection only |
| selected answer | exact `candidateFingerprint` |
| preview/apply identity | P8 reservation/coordinator |
| committed state | canonical ProjectAggregate |
| lineage | P9.12 persisted provenance |

No concern has two writable authorities.

## 6. Identity boundary audit

Before P8 reserved preview:

```text
semantic generation keys + candidate fingerprints only
```

At preview preparation:

```text
EntityIdFactory -> one MutationIdentityReservation
```

At Apply:

```text
exact frozen candidate + exact reservation
```

PASS. No P9 stage is permitted to allocate permanent IDs while browsing cards.

## 7. Determinism audit

Potential non-determinism sources and controls:

| Risk | Control |
|---|---|
| Map/Set iteration | explicit stable sort |
| floating scoring | integer basis points |
| area remainder | stable semantic-key tie-break |
| geometry vertex order | normalized winding/start vertex |
| mirror duplicates | semantic/geometry fingerprint dedupe |
| locale | localized text excluded from semantics |
| random generation | forbidden in v1 |
| clock/time | excluded from candidate identity |
| platform pixel metrics | excluded from generation |

Design disposition: PASS.

## 8. Persistence/provenance audit

Required persisted additions in implementation:

```text
generation manifests
entity provenance
generation keys
override sets
lock state
version/fingerprint lineage
```

Legacy projects migrate to valid empty generation state.

No P9-specific runtime object is required to edit committed apartments.

Design disposition: PASS, implementation gate P9.12.

## 9. Performance budget composition

P9.13 total hard generation budget:

```text
p95 <= 500 ms
p99 <= 900 ms
```

Substage budgets are intentionally tighter so one stage cannot consume the whole budget:

```text
P9.1 <= 5 ms p99
P9.2 filter <= 10 ms p99
P9.3 expand <= 30 ms p99
P9.4 batch <= 40 ms p99
P9.5 per candidate <= 3 ms p99
P9.6 batch <= 350 ms p99
P9.7 batch <= 25 ms p99
P9.8 six cards <= 200 ms p99 (separate render gate)
```

CI evidence, not arithmetic sum, decides final pass.

## 10. Implementation package direction

Recommended dependency direction:

```text
application/wizard/apartment
  parameters + orchestration + provider
        ↓
domain/apartment_topology
  catalog + grammar + area + semantics + geometry + scoring contracts
        ↓
domain/project canonical contracts

presentation
  Wizard screens/cards/vector painting
        ↓
application services
```

Forbidden dependencies:

```text
domain -> Flutter
catalog -> UI localization
geometry -> SVG parser
provider -> repository direct write
renderer -> canonical mutation
```

## 11. Recommended implementation order

```text
Gate A  Shared contracts + P9.1
Gate B  P9.2 catalog + integrity fixtures
Gate C  P9.3 grammar + P9.4 area + P9.5 semantics
Gate D  P9.6 geometry + opening intents
Gate E  P9.7 scoring/diversity + P9.8 renderer
Gate F  P9.9 provider/session
Gate G  P9.10 apartment Diff
Gate H  P9.11 atomic materialization/openings
Gate I  P9.12 provenance/persistence/override hooks
Gate J  P9.13 Golden Journey/NFR/cross-platform
```

Do not begin presentation-heavy work before Gates A-D have stable typed contracts.

## 12. Risk register

| Risk | Severity | Containment |
|---|---|---|
| insufficient catalog diversity | medium | catalog coverage matrix + diversity gate |
| unsatisfiable geometry for valid semantics | medium | fail candidate, multiple templates/seeds, property corpus |
| performance blow-up from variants | high | raw candidate caps + bounded grammars |
| locale changes canonical output | high | typed semantics/fingerprint tests RU vs EN |
| opening host instability | high | mandatory BoundaryEdgeId host gate |
| P8 regression | high | reserved-preview exactness + full test suite |
| provenance schema incomplete | high | P9.12 merge blocker |
| false compliance claim | high | explicit normative posture |

No risk is accepted without a qualification/containment path.

## 13. Design Definition of Done

P9 specification is considered high-quality/implementation-ready when:

```text
all stage v2 specs exist
shared contracts exist
cross-stage ambiguities R01-R14 are CLOSED
all units/area semantics are explicit
opening/access semantics are physically materializable
identity/version/fingerprint rules are explicit
P8 transaction authority remains singular
persistence/provenance path is defined
negative/error behavior is typed
hard NFRs are measurable
Golden Journey is production-path based
no blocking open question remains
```

Current design disposition: **READY FOR IMPLEMENTATION**.
