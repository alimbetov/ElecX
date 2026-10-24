# P9 Cross-Stage Architecture Audit v2

Date: 2026-10-24  
Branch: `feat/p9-apartment-topology-generator`  
Baseline: P8 merged `main@c397302f183d023e4bdd670ac0c8b46c6fad994a`

## Disposition

```text
P9.0 prerequisite audit                  PASS
P9 v2 shared contracts                   PASS
P9 cross-platform UX/input contract      PASS
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

And one cross-platform presentation/input architecture:

```text
presentation capabilities
 -> responsive width class
 -> semantic Wizard state
 -> responsive shell
 -> input operation mapping
 -> vector preview viewport
 -> P8 Preview/Diff
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
- missing merge gates;
- desktop/mobile semantic forks;
- responsive state reset/regeneration;
- hover/right-click/touch-only inaccessible operations;
- viewport/input state leaking into canonical fingerprints.

## 2. Findings and closure

### R01 — User intent and candidate selection were conflated

**Resolution:** CLOSED.

P9.1 separates:

```text
ApartmentRequestInput
ApartmentCandidateSelection
ApartmentWizardParameters(request, selection)
```

`intentFingerprint` excludes selection. Semantic request edits invalidate selection.

### R02 — Apartment area meaning with balcony/loggia was ambiguous

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

P9.2 requires `TopologySpaceGeometryConstraints` including:

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

P9.6 creates typed `OpeningIntent`s. P9.11 requires:

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

### R15 — Desktop/tablet/phone could diverge into separate semantic products

**Problem:** A desktop-first Wizard could later lead to separate mobile candidate generation, reduced candidate count or duplicated transaction paths.

**Resolution:** CLOSED.

`02-p9-cross-platform-responsive-input-contract-v2.md` establishes:

```text
same request + semantic versions
 -> same ordered candidate fingerprints
```

on supported platforms. Form factor changes only presentation/input mapping.

Phone/tablet MUST NOT run a weaker generator or simplified semantic Diff.

### R16 — OS detection could become the layout architecture

**Problem:** `Platform.isWindows`/`isAndroid` style layout branching would fail on resizable desktop windows, iPad split-screen and Android tablets with keyboard/mouse.

**Resolution:** CLOSED.

Layout derives from:

```text
logical viewport
precise pointer / hover
touch / stylus
hardware keyboard
text scale
reduced motion
```

with width classes:

```text
COMPACT < 600
MEDIUM 600..1023
EXPANDED 1024..1439
LARGE >= 1440
```

OS checks are secondary/native-convention adapters only.

### R17 — Responsive resize/orientation could regenerate or reset Wizard state

**Resolution:** CLOSED.

P9.9 explicitly separates semantic Wizard state from presentation shell. Resize/orientation/split-screen changes preserve request, candidate set/order and valid selection; they cannot trigger P9.2-P9.7 merely because layout changed.

Prepared P8 Preview/reservation remains the same semantic object.

### R18 — CAD input model could be locked to mouse or touch too early

**Resolution:** CLOSED.

P9 introduces one semantic input-operation layer and shared `PreviewViewportState`.

Required actions cannot be available only through:

```text
hover
right click
long press
stylus
multi-touch
```

Mouse/keyboard/touch/stylus are adapters to common operations. This becomes the foundation for P10-P14 CAD interactions.

### R19 — Small-screen Preview/Diff could hide semantic changes

**Resolution:** CLOSED.

COMPACT may present Preview/Diff as tabs/full-screen routes, but the underlying semantic Diff operation set is identical to desktop. All blockers and changes remain reachable before Apply.

### R20 — Preview zoom/pan could leak into engineering geometry

**Resolution:** CLOSED.

`PreviewViewportState(scale, translation)` is transient presentation state only.

It is excluded from:

```text
candidate fingerprints
P8 reservation
semantic Diff
provenance
canonical coordinates
```

Screen pixels never become authoritative apartment geometry.

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
full precision phone CAD authoring parity               -> later product decision
```

P9 output and interaction architecture are deliberately engineered so these phases can reuse canonical Spaces/boundaries/openings/provenance and responsive input infrastructure.

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
| vector image/preview scene | P9.8 projection only |
| selected answer | exact `candidateFingerprint` |
| Wizard semantic state | P9.9/P8 session state machine |
| responsive layout | presentation capability policy |
| preview zoom/pan | transient `PreviewViewportState` |
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

Responsive/input transitions allocate no permanent identity.

PASS.

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
| viewport/orientation | presentation only |
| input modality | semantic operation adapter only |
| theme/text scale | excluded from fingerprints |

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

Responsive presentation state and preview viewport state are NOT generation provenance.

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

Responsive relayout has a separate rule: it may rebuild/reflow presentation but MUST NOT invoke P9.1-P9.7 solely because viewport/input capabilities changed.

CI evidence, not arithmetic sum, decides final pass.

## 10. Responsive/input architecture audit

Required shared foundations:

```text
ElecXPresentationCapabilities
ElecXResponsiveWidthClass
semantic Wizard navigation state
input-operation abstraction
PreviewViewportState
central shortcut mapping
focus/a11y order
safe-area/window-resize handling
```

Expected reuse:

```text
P10 multi-candidate building/floor compare
P11 EngineeringGraph navigation
P12 engineering Wizard/Preview/Diff
P13 auto-placement pointer/touch/stylus commands
P14 route editing / CAD viewport
```

Forbidden:

```text
desktop-only application state
mobile-specific domain model
separate desktop/mobile transaction engines
gesture directly mutating canonical state without semantic command
screen pixel coordinates persisted as engineering geometry
```

Design disposition: PASS.

## 11. Implementation package direction

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
  responsive Wizard shells/cards/vector painting/input adapters
        ↓
application services / semantic operations
```

Forbidden dependencies:

```text
domain -> Flutter
catalog -> UI localization
geometry -> SVG parser
provider -> repository direct write
renderer -> canonical mutation
responsive width class -> generator algorithm
OS platform -> candidate ranking
```

## 12. Recommended implementation order

```text
Gate A  Shared domain + responsive/input contracts + P9.1
Gate B  P9.2 catalog + integrity fixtures
Gate C  P9.3 grammar + P9.4 area + P9.5 semantics
Gate D  P9.6 geometry + opening intents
Gate E  P9.7 scoring/diversity + P9.8 responsive renderer/viewport
Gate F  P9.9 provider/session + responsive state shell
Gate G  P9.10 apartment Diff + responsive Preview/Diff
Gate H  P9.11 atomic materialization/openings
Gate I  P9.12 provenance/persistence/override hooks
Gate J  P9.13 Golden Journey/NFR/cross-platform/input qualification
```

Do not begin presentation-heavy work before Gates A-D have stable typed contracts.

## 13. Risk register

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
| mobile/desktop semantic divergence | high | P9-PLAT fingerprint equality gate |
| resize resets session | high | responsive state-preservation tests |
| input modality inaccessible | high | keyboard/touch operation qualification |
| future P10-P14 interaction rewrite | high | shared capability/input/viewport abstractions in P9 |

No risk is accepted without a qualification/containment path.

## 14. Design Definition of Done

P9 specification is considered high-quality/implementation-ready when:

```text
all stage v2 specs exist
shared contracts exist
cross-platform responsive/input contract exists
cross-stage ambiguities R01-R20 are CLOSED
all units/area semantics are explicit
opening/access semantics are physically materializable
identity/version/fingerprint rules are explicit
P8 transaction authority remains singular
persistence/provenance path is defined
responsive width/input state cannot alter generator semantics
phone/tablet/desktop expose one semantic Wizard flow
Preview/Diff remains complete at COMPACT
keyboard/touch input paths are specified
preview viewport is explicitly non-canonical
P10-P14 reuse path is defined
negative/error behavior is typed
hard NFRs are measurable
Golden Journey is production-path based
no blocking open question remains
```

Current design disposition: **READY FOR IMPLEMENTATION**.
