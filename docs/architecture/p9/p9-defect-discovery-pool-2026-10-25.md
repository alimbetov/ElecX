# P9 Apartment Topology Generator — Defect Discovery Pool

Audit date: 2026-10-25  
Branch: `feat/p9-apartment-topology-generator`  
Audited HEAD: `41824e3f7fd5343b1e0a1cdf1caa4bba70f2c3b3`  
CI evidence: GitHub Actions run `40163914633`

## 1. Executive disposition

P9.1-P9.6 have substantial implementation, but P9.6 is **not eligible for exit/acceptance** and P9.7 should not become the main development focus yet.

Current CI is infrastructure-clean but functionally red:

```text
Dart format            PASS
flutter analyze        PASS
P8 NFR reference       PASS
P8 a11y/i18n           PASS
flutter test           FAIL
full test summary      1239 passed / 15 failed
```

The failures are not fifteen independent defects. They cluster around three architectural problems:

1. P9.4 has absorbed P9.6 geometry feasibility and now violates the stage boundary.
2. P9.6 access-spine geometry is stricter than the semantic grammar contract, especially for open-plan and larger layouts.
3. P9.5 -> P9.6 handoff loses geometric constraints that P9.6 is required to prove.

Severity legend:

```text
BLOCKER  blocks P9.6 exit / must be fixed before P9.7 is treated as production work
HIGH     can accept/reject the wrong topology or lose explicit user/template intent
MEDIUM   hardening/coverage defect that can become correctness-critical in P9.7-P9.11
LOW      maintainability/diagnostic risk without current acceptance impact
```

Evidence legend:

```text
CI        reproduced by current full-suite failure
STATIC    directly proven by current production code path
SPEC      current implementation conflicts with authoritative v2 P9 specification
LATENT    invariant is not enforced; current generator may avoid it accidentally
```

---

## 2. Priority defect pool

### P9-DEF-001 — P9.4 contains P9.6 geometry policy

Severity: **BLOCKER**  
Evidence: **CI + STATIC + SPEC**

Current `ApartmentAreaFitter` policy v3 invokes `ApartmentCirculationGeometryReserve` after the normal deterministic area allocation and transfers area between spaces to satisfy access-spine geometry.

This conflicts with authoritative P9.4 v2, which defines the stage as:

```text
min -> preferred -> max -> deterministic remainder -> exact fitted areas
```

P9.4 explicitly hands fitted areas to P9.6; it is not the geometry solver.

Current CI consequence:

```text
P9.4-AT-011
roomCount=3
family=compact
failure=p9.area.circulation-geometry-reserve
```

The failure then cascades into many P9.5 fixtures because `_qualified(...)` cannot obtain a fitted draft.

Required correction:

- remove P9.6 layout feasibility/rebalance from `ApartmentAreaFitter`;
- restore pure versioned area-allocation semantics;
- move bounded geometric alternative search/resolution to P9.6 (or a clearly defined P9.6 preparation stage);
- do not weaken P9.4 minimum/preferred/maximum contracts to make one layout algorithm fit.

Exit tests:

```text
P9.4 AT-001..012 green
P9.4 allocation independent from geometry algorithm version
same P9.4 fitted result usable by multiple P9.6 layout strategies
```

---

### P9-DEF-002 — Supported 1..10 corpus does not produce geometry

Severity: **BLOCKER**  
Evidence: **CI**

Current full suite fails:

```text
P9.6-AT-013 supported 1..10-room corpus has accepted geometry
rooms=4 must yield geometry

P9.6-AT-017 access intents survive geometry
rooms=4 must yield geometry

P9.6-AT-018 actual opening graph reaches every interior space
rooms=4 must yield geometry
```

This is an exit-gate failure, not only missing coverage.

Required correction:

- obtain a rejection matrix for every generated draft for the failing room count;
- identify whether rejection comes from area realization, spine dimensions, required/forbidden boundary, wet-core or exposure;
- fix the layout/search strategy rather than selecting the first convenient fixture;
- retain fail-closed validation.

Exit tests:

```text
at least one accepted production-catalog candidate for every supported room count 1..10
all accepted candidates pass post-packing access validation
no test skips unsupported intermediate candidates silently without diagnostics
```

---

### P9-DEF-003 — openPlan semantic graph conflicts with P9.6 star-topology precondition

Severity: **BLOCKER**  
Evidence: **CI + STATIC + SPEC**

P9.3 correctly models open plan as distinct `livingRoom` + `kitchen` with required `openConnection`.

The grammar connects the distribution hub to the day space; the kitchen is connected through the required open connection. P9.6, however, computes all interior non-hub spaces as `spokes` and rejects if any spoke is not a direct semantic access neighbour of the distribution hub:

```text
missingHubEdges -> p9.geometry.unsupported-access-shape
```

This hidden star requirement contradicts the more general P9.5 access graph and directly explains the current failure:

```text
P9.6-AT-006 open-plan required boundary is realized -> FAIL
```

Required correction:

- make P9.6 layout operate on access/shared-boundary units or a bounded circulation tree, not `hub -> every room`;
- a unit may connect to the hub through one member while internal members realize required open/direct connections;
- do not add artificial extra doors solely to satisfy the current geometry algorithm.

Exit tests:

```text
openPlan: hub -> living -> kitchen(open passage) is accepted
required living/kitchen boundary meets minimum shared length
actual opening graph remains fully reachable
```

---

### P9-DEF-004 — `corner` is advertised by production catalog but P9.6 always rejects it

Severity: **BLOCKER**  
Evidence: **STATIC + SPEC**

`CatalogV4` inherits compatibility constraints from previous catalogs. Multiple templates advertise `ApartmentExteriorExposurePreference.corner`.

`ApartmentAccessSpineGeometryGenerator.generate()` explicitly returns:

```text
p9.geometry.exposure-preference-mismatch
```

for every `corner` request.

The authoritative P9.6 spec requires candidate-local evaluation for:

```text
oneSide
corner
oppositeSides
```

and P9.6-AT-012 is an acceptance test, not a deferred capability.

Required correction — choose one coherent contract:

1. implement corner/multi-side layout before P9.6 exit; **preferred**, or
2. remove corner from production catalog/request compatibility and version that semantic change.

Do not leave a production-advertised preference that deterministically yields zero candidates.

---

### P9-DEF-005 — `minSharedBoundaryMm` is lost in P9.5 -> P9.6 handoff

Severity: **HIGH**  
Evidence: **STATIC + SPEC**

`DraftAdjacencyIntent` carries `minSharedBoundaryMm`; catalog rules use it, including open-plan `1200 mm`.

`ApartmentSemanticValidator._geometryHandoff()` converts required direct/open relations into plain `SemanticSpacePair`. The minimum length is discarded.

P9.6 later validates only:

```text
required pair exists in sharedBoundaries
```

not:

```text
shared length >= required minSharedBoundaryMm
```

This violates P9.6-FR-008.

Required correction:

Introduce a typed handoff constraint, e.g.:

```text
RequiredSharedBoundaryIntent
  pair
  relation kind
  minSharedBoundaryMm
```

and validate exact integer segment length in P9.6.

Exit tests:

```text
1190 mm open-plan boundary rejected when minimum=1200
1200 mm accepted
constraint survives source-order permutation/fingerprint
```

---

### P9-DEF-006 — semantic exterior side assignments are discarded before geometry

Severity: **HIGH**  
Evidence: **STATIC + SPEC**

P9.3 computes `DraftExteriorExposure.assignments` and includes them in semantic signature/fingerprint. For example, grammar can assign `west/east` for opposite-side intent or `west/north` for corner intent.

P9.5 handoff keeps only `requiredExteriorSpaceKeys`, losing the requested side per semantic space.

P9.6 therefore cannot prove that the geometry realizes the semantic exposure topology; it only proves that each required room owns *some* exterior segment.

Required correction:

- carry typed candidate-local exposure assignments into `TopologyGeometryHandoff`;
- validate room-to-side realization after geometry;
- separately validate aggregate request pattern (`oneSide`, `corner`, `oppositeSides`).

Exit tests:

```text
oneSide -> all qualified exposure roles on one candidate-local side
corner -> at least two adjacent candidate-local sides as declared
oppositeSides -> required roles span two opposite candidate-local sides
per-space semantic side assignment preserved
```

---

### P9-DEF-007 — primary entry validation does not bind entry to semantic entry identity/host

Severity: **HIGH**  
Evidence: **STATIC**

`ApartmentGeometryAccessValidator` verifies:

- exactly one primary entry;
- `fromSpaceKey != null`;
- reachability from that key.

It does **not** independently verify:

```text
primaryEntry.fromSpaceKey == semantic draft entrySpaceKey
primaryEntry.hostSegment belongs to that entry space exterior boundary
```

`TopologyGeometryHandoff` currently does not even carry an explicit `entrySpaceKey`; it only exposes a sorted list of circulation anchors.

The current generator creates the right entry, but the post-packing validator is the acceptance boundary and must reject a malformed alternative generator/candidate.

Required correction:

- add explicit entry semantic identity to handoff;
- validate primary entry space identity;
- validate the host segment is an exterior segment owned by the entry space;
- preserve one-entry invariant.

Adversarial test: mutate a valid candidate so the primary entry references another reachable room; validation must fail.

---

### P9-DEF-008 — `corridorMode` is effectively a semantic no-op

Severity: **HIGH**  
Evidence: **STATIC**

`corridorMode` participates in normalized request serialization and changes `intentFingerprint`.

Catalog filter checks explicit modes, but production templates support the same mode set and grammar `corridorCount()` implementations do not branch on `request.corridorMode`; they branch only on room count/family.

Result: `compact`, `central` and `minimal` may produce identical semantic topology while carrying different intent fingerprints.

Required correction:

Define versioned semantics for each mode, e.g.:

```text
minimal -> minimize circulation node count/area
compact -> bounded short distribution
central -> require central circulation role where family permits
```

If the product does not intend this input to affect topology, remove it from P9 v1 user intent rather than retaining a fake control.

Exit tests: same base request with each explicit corridor mode must either produce a documented distinct qualified topology or an explicit incompatibility reason.

---

### P9-DEF-009 — eight family classes do not yet implement eight family grammars

Severity: **HIGH**  
Evidence: **STATIC + SPEC**

All family classes inherit `_BaseApartmentTopologyGrammar`. Most currently differ only in `corridorCount`; `centralCorridor` also changes the primary axis. The common base constructs essentially the same hub-and-spoke access graph.

This does not fully implement the P9.3 family contracts:

```text
linear            ordered circulation sequence
corner            two-direction exterior topology
centralCorridor   central node + short branches
corridorSpine     scalable spine + bounded branches
splitDayNight     explicit public/private subgraphs
```

Existing P9.3 tests prove family enum coverage and shallow attributes, but not graph-shape distinctness.

Impact:

- lower real candidate diversity than the catalog suggests;
- P9.7 would rank near-equivalent topology under different family labels;
- geometry is forced to compensate for missing grammar structure.

Required correction:

Add family-specific graph/layout skeleton builders and structural assertions, not only subclasses with different counts.

---

### P9-DEF-010 — balcony/loggia placement supports only west/east host boundaries

Severity: **HIGH**  
Evidence: **STATIC + SPEC**

`_appendagePlacement()` accepts a host only when:

```text
host.minX == envelope.minX
or
host.maxX == envelope.maxX
```

A valid exterior-facing room whose usable attachment edge is north/south cannot host a balcony/loggia and receives `p9.geometry.appendage-attachment`.

P9.6-FR-013 is side-neutral.

Required correction:

- select an actual qualified exterior segment of the declared host;
- place appendage normal to that segment for all four candidate-local sides;
- track used intervals per host segment, not only a scalar offset per host room.

Exit tests: north/south/east/west attachment fixtures plus multiple appendages on one host without overlap.

---

### P9-DEF-011 — compatibility envelope can admit request combinations that cannot satisfy expanded minima

Severity: **MEDIUM**  
Evidence: **STATIC**

P9.2 filter compares request area only to one template-wide `minInteriorAreaDm2/maxInteriorAreaDm2`. It does not derive the concrete minimum/maximum for the requested room/bathroom/WC cardinalities.

Catalog integrity similarly checks a coarse recipe envelope based on multiplicity minima/maxima rather than each advertised request combination.

Therefore a request may be reported as template-compatible and fail only after grammar expansion/P9.4 because concrete minima exceed the requested area.

This is currently allowed by the coarse P9.2 invariant, so it is a cross-stage product/UX defect rather than a direct spec contradiction.

Recommended correction:

- add request-expanded feasibility filtering, or
- expose a deterministic post-expansion incompatibility before candidate generation/cards.

Add boundary tests for 1..10 rooms with min/max service counts and area envelope edges.

---

### P9-DEF-012 — P9.6 does not enforce `maxVertices`

Severity: **MEDIUM**  
Evidence: **STATIC + SPEC**

`TopologySpaceGeometryConstraints.maxVertices` is catalog-validated, and P9.6 spec requires it. Current access-spine `_validate()` checks area, min dimensions and aspect ratio but never compares polygon vertex count with `maxVertices`.

Current generated room/appendage shapes are rectangles, so this is latent today but becomes correctness-critical as bounded L-shaped/rectilinear spaces are enabled.

Required test: candidate with `vertices.length > maxVertices` must fail with `p9.geometry.vertex-limit`.

---

### P9-DEF-013 — overlap validation is incomplete

Severity: **MEDIUM**  
Evidence: **STATIC + SPEC**

P9.6 spec requires no interior-space or appendage overlap and defines explicit error codes. Current validation relies largely on construction and the envelope-area equation. There is no independent pairwise polygon-area overlap validation, and exterior appendage overlap is not explicitly checked.

A validator should not accept correctness only because the current generator normally avoids a bad state.

Required correction:

- exact integer polygon intersection/overlap check for interior/interior, appendage/interior and appendage/appendage;
- shared zero-area boundaries remain allowed;
- typed blocker codes.

---

### P9-DEF-014 — stepped-envelope side classification is heuristic

Severity: **MEDIUM**  
Evidence: **STATIC**

`_side()` classifies:

- horizontal global min/max as north/south;
- vertical segments by `x <= spineX` as west/east;
- other horizontal stepped segments by envelope midpoint.

For a concave/stepped envelope this is position-based, not based on polygon edge orientation/outward normal. It can mislabel candidate-local facade side and corrupt future P9.7 exposure scoring or `corner/oppositeSides` validation.

Required correction: derive side/orientation from normalized envelope winding and the segment's outward normal, with tests for concave stepped envelopes.

---

### P9-DEF-015 — one shared segment per room pair loses multi-segment contact

Severity: **MEDIUM**  
Evidence: **STATIC**

`_sharedBoundaries()` retains only the longest collinear overlap for each space pair.

With current rectangular spaces this is usually sufficient, but P9.6 explicitly permits bounded rectilinear/L-shaped spaces. Two rectilinear rooms can share multiple disjoint boundary segments. Keeping only the longest loses geometry needed for:

- minimum total shared-boundary validation;
- opening host selection;
- later P7/P9.11 boundary materialization.

Required correction: model all normalized shared segments for a semantic pair, or explicitly constrain P9 v1 accepted room polygons to a single connected shared segment and version that restriction.

---

### P9-DEF-016 — qualification tests use mixed catalog generations

Severity: **HIGH (QA/evidence)**  
Evidence: **STATIC + CI**

Examples on current HEAD:

```text
P9.3 grammar tests                  CatalogV1
P9.4 production 1..10 corpus       CatalogV1
P9.5 semantic validator fixtures   CatalogV1
catalog↔grammar consistency         CatalogV3
P9.6 geometry corpus                CatalogV4
```

`CatalogV4` changes template versions and circulation geometry/area profiles. Therefore green lower-stage tests do not necessarily qualify the same production contract consumed by P9.6.

Required correction:

- expose one explicit `P9ProductionApartmentTopologyCatalog.create()` alias/factory;
- all current acceptance/GJ tests use production catalog;
- V1/V2/V3 tests remain only as historical version regression tests.

---

### P9-DEF-017 — corpus diagnostics collapse root cause into `null`

Severity: **MEDIUM (QA/diagnostics)**  
Evidence: **CI + STATIC**

Several acceptance helpers iterate drafts and return only first accepted candidate; if none is accepted, tests fail with messages such as:

```text
rooms=4 must yield geometry
Bad state: No qualified P9 fixture
```

The rejection matrix is lost. This caused many P9.5 failures to look independent even though they cascade from P9.4.

Required correction:

Create a reusable qualification harness that records, per request/template/seed:

```text
catalog compatibility reasons
grammar failures
area failures
semantic blockers
geometry failures/validation issues
accepted fingerprint
```

On corpus failure, print a stable summarized rejection matrix.

---

### P9-DEF-018 — P9.5 wet-core precondition is membership-heavy, not feasibility-complete

Severity: **MEDIUM**  
Evidence: **STATIC + SPEC**

Current `_validateWetCore()` checks group count, invalid references and exactly-once wet membership. It does not materially prove P9.5-FR-007: that semantic topology makes compact wet grouping possible and does not impose contradictory placement anchors.

Geometry later checks max separation, but obvious semantic impossibility should fail before P9.6.

Required correction:

- define typed wet-core semantic relations/anchors;
- validate required/preferred service relationships before geometry;
- keep geometric separation as the P9.6 second gate.

---

## 3. Previously reported defects — current disposition

### OLD-01 — access intent silently lost when no shared wall

Disposition: **ARCHITECTURALLY CLOSED, regression evidence still depends on green suite**.

Current production path uses:

```text
ApartmentGeometryStage
  -> ApartmentAccessSpineGeometryGenerator
  -> ApartmentGeometryAccessValidator
```

The post-packing validator checks every semantic access intent and BFS reachability over actual generated openings. `P9.6-AT-017/018` cover this behavior, but the tests currently cannot complete for the 4-room corpus because of P9-DEF-002.

### OLD-02 — catalog advertises room counts rejected by grammar corridor contract

Disposition: **CLOSED for V3 consistency evidence**.

`p9_catalog_grammar_consistency_test.dart` validates advertised room counts after grammar expansion. The remaining issue is P9-DEF-016: production acceptance must run the same consistency matrix on V4/current production alias.

---

## 4. Fix waves

### Wave A — restore architectural boundaries and green semantic pipeline

Order:

```text
A1 P9-DEF-001 remove geometry reserve from P9.4
A2 P9-DEF-016 unify acceptance tests on production catalog
A3 rerun P9.4 + P9.5 full corpus
A4 P9-DEF-017 install rejection-matrix qualification harness
```

Gate:

```text
P9.1-P9.5 acceptance green on production catalog
no geometry-policy dependency inside P9.4
```

### Wave B — make P9.6 geometry semantically complete

Order:

```text
B1 P9-DEF-003 remove hidden direct-hub/star access restriction
B2 P9-DEF-005 preserve/enforce minimum shared boundary lengths
B3 P9-DEF-007 harden semantic entry identity/host validation
B4 P9-DEF-006 preserve/enforce exposure side assignments
B5 P9-DEF-004 implement corner or remove it from production compatibility
B6 P9-DEF-010 four-side appendage placement
B7 P9-DEF-002 close 1..10 production corpus
```

Gate:

```text
P9.6 AT-001..018 green
1..10 corpus accepted
openPlan accepted
oneSide/corner/oppositeSides qualified
all access/reachability invariants green
```

### Wave C — restore real topology diversity before P9.7

Order:

```text
C1 P9-DEF-008 corridorMode semantics
C2 P9-DEF-009 family-specific graph/layout semantics
C3 P9-DEF-011 request-expanded feasibility diagnostics
C4 diversity/dedup corpus by semantic fingerprint
```

Gate:

```text
families are structurally distinct where specification says they are
explicit user intent changes topology or returns incompatibility
P9.7 receives meaningful alternatives, not label variants
```

### Wave D — geometry hardening before canonical materialization

```text
D1 P9-DEF-012 maxVertices
D2 P9-DEF-013 overlap validator
D3 P9-DEF-014 correct outward-side classification
D4 P9-DEF-015 multi-segment shared-boundary representation
D5 P9-DEF-018 wet-core semantic feasibility
```

Gate:

```text
adversarial geometry fixtures fail closed
candidate geometry is suitable for P9.11/P7 materialization
```

---

## 5. Recommended no-go gates

Do **not** declare P9.6 complete while any of these are true:

```text
full flutter test is red
P9.4 depends on P9.6 geometry algorithm
any supported room count 1..10 has zero accepted production candidate
openPlan has zero accepted candidate
corner remains advertised but deterministically rejected
required minSharedBoundaryMm can be lost
semantic exposure assignments are not proven by geometry
primary entry identity/host is not independently validated
```

Do **not** use P9.7 scoring to hide P9.6 invalidity. Scoring may rank only already-valid candidates.

---

## 6. Recommended next implementation sequence

```text
1. Revert/refactor P9.4 v3 geometry reserve out of area fitting.
2. Add production-catalog qualification harness with rejection matrix.
3. Get P9.1-P9.5 green again.
4. Generalize P9.6 from direct-hub spokes to bounded access/shared-boundary units.
5. Preserve minSharedBoundary + entry + exposure assignments in typed handoff.
6. Close openPlan and 1..10 geometry corpus.
7. Implement candidate-local corner/opposite-side proof and four-side appendages.
8. Add adversarial geometry validators (overlap, vertex limit, host mismatch).
9. Deepen actual family/corridor-mode semantics.
10. Only then start P9.7 ranking as the primary workstream.
```

## 7. Audit disposition

```text
P9.1 parameter foundation             PASS WITH HARDENING ITEMS
P9.2 catalog foundation               PASS WITH CROSS-STAGE FEASIBILITY GAP
P9.3 grammar engine                    PARTIAL — family semantics too shallow
P9.4 area fitting                      REGRESSED / BLOCKED
P9.5 semantic validation               IMPLEMENTED, CI BLOCKED BY P9.4 + handoff gaps
P9.6 geometry                          HARDENING / BLOCKED
P9.7+                                  NOT READY AS PRIMARY IMPLEMENTATION TRACK

merge/acceptance disposition           NO-GO
next focus                              Wave A -> Wave B
```
