# P9 Apartment Topology Generator — Implementation Specification v1

## Status

Authoritative implementation specification for branch:

`feat/p9-apartment-topology-generator`

Baseline:

- P8 Wizard + Preview/Diff is merged into `main`;
- branch base: `c397302f183d023e4bdd670ac0c8b46c6fad994a`;
- P9 is the next phase in the authoritative `P0..P17` roadmap.

This specification refines P9 from:

- `docs/architecture/project-composition-foundation-decisions-v1.md`;
- `docs/architecture/project-composition-generation-v1.md`;
- `docs/architecture/p8-wizard-preview-diff-implementation-v1.md`;
- `docs/architecture/p8-development-roadmap-v1.md`;
- `docs/architecture/apartment-topology-catalog-v1.md`.

If requirements conflict, the order of authority is:

1. native portability/foundation decisions;
2. this P9 specification for apartment-generation behavior;
3. older apartment-topology addenda.

P9 extends the accepted P8 Wizard platform. It MUST NOT introduce a second transaction engine, second project graph, second preview lifecycle or provider-specific commit path.

---

# 1. Product objective

P9 turns the P8 Wizard framework into a production apartment-layout generator.

The user provides a bounded typed request, ElecX returns a small ranked set of recognizable apartment candidates, the user selects one, inspects the P8 Preview/Diff, and commits the exact frozen candidate as normal canonical project state.

North-star flow:

```text
Project Hub / Project Navigator
        ↓
Apartment Wizard
        ↓
ApartmentWizardParameters
        ↓
normalize + validate
        ↓
ApartmentTopologyCatalog
        ↓
compatible topology grammars
        ↓
bounded deterministic expansion
        ↓
area fitting
        ↓
adjacency / wet-core / geometry validation
        ↓
score + deterministic rank
        ↓
3..6 candidates
        ↓
dynamic vector/SVG previews
        ↓
user selection
        ↓
ApartmentWizardProvider
        ↓
P8 reserved Preview + semantic Diff
        ↓
Apply exact frozen candidate
        ↓
1 ProjectChangeSet + 1 UndoRecord
        ↓
canonical StructuralZone + Spaces + topology + provenance
```

The committed result is ordinary editable ElecX state. Generated apartments are not a separate document type.

---

# 2. Scope

P9 owns:

```text
P9.0  specification/audit
P9.1  ApartmentWizardParameters
P9.2  ApartmentTopologyCatalog
P9.3  topology families / grammars
P9.4  deterministic area fitting
P9.5  adjacency + wet-core rules
P9.6  geometry generation
P9.7  candidate scoring/ranking
P9.8  SVG/vector topology renderer
P9.9  ApartmentWizardProvider
P9.10 P8 Preview/Diff integration
P9.11 canonical Spaces/StructuralZone materialization
P9.12 provenance
P9.13 qualification / Golden Journey
```

P9 does NOT own:

```text
cottage generator                         → P10
whole-building/ЖК generator               → P10
full typical-floor generation             → P10
POWER/LIGHTING/LAN/CCTV/ACS/FIRE graph    → P11/P12
auto-placement                            → P13
auto-routing                              → P14
selective regeneration merge engine       → P15
new persistence architecture              → P16
AI/LLM floor planning                     → out of P9
unbounded/free-form architectural solver  → out of P9
normative architectural certification     → out of P9
```

P9 may prepare data needed by later engineering automation, especially canonical `SpaceUsage`, adjacency, wet-zone classification, boundary topology and generation provenance.

---

# 3. Non-negotiable architectural invariants

## P9-I01 — P8 remains the only Wizard transaction lifecycle

P9 plugs into existing:

```text
WizardProviderRegistry
WizardProvider
WizardSessionController / session state
ReservedProjectMutationCoordinator
ProjectMutationSession
ProjectChangeSet
Undo/Redo
```

No apartment-specific transaction manager is allowed.

## P9-I02 — Semantic model is authoritative; SVG is projection only

Forbidden:

```text
*.svg file → parse → canonical apartment geometry
```

Required:

```text
ApartmentTopologyCandidate
        ↓
TopologyVectorScene
        ↓
Flutter/vector/SVG projection
```

SVG/vector output is disposable presentation state.

## P9-I03 — Determinism

For the same:

```text
normalized parameters
+ target context
+ catalog version
+ template version
+ generator version
```

P9 produces semantically equivalent candidate sets in the same deterministic order.

No wall-clock time, random UUID, hash-map iteration order, platform-specific measurement or locale text may affect candidate semantics.

## P9-I04 — Candidate generation is side-effect free

Candidate enumeration, scoring, SVG rendering and candidate switching MUST NOT:

```text
mutate ProjectAggregateRoot;
increment LocalProjectVersion;
append Undo history;
write ProjectRepository;
allocate permanent project identity;
change canonical navigation state.
```

## P9-I05 — Bounded generation

P9 is not a brute-force optimizer.

Every generation stage must have an explicit bound:

```text
catalog templates considered
variant seeds per template
candidate geometries per seed
final candidates returned
```

No unbounded combinatorial search.

## P9-I06 — No silent coercion

Unsupported or infeasible requests fail with typed reasons. P9 may suggest a nearest supported adjustment but may not silently change room count, bathrooms, kitchen mode, requested area or user-selected family.

## P9-I07 — Validation precedes ranking

Invalid candidates never receive a user-facing rank as though valid.

Pipeline:

```text
generate → validate hard constraints → score valid candidates → rank
```

## P9-I08 — One selected candidate, one atomic apply

One confirmed apartment generation creates exactly:

```text
1 canonical ProjectChangeSet
1 UndoRecord
1 generation provenance root
```

No N sequential room-creation commits.

## P9-I09 — Stable canonical identities are reserved only by the P8/P3 mutation path

Topology candidates use draft-scoped semantic keys. Permanent `ZoneId`, `SpaceId`, `BoundaryEdgeId` and other canonical IDs are reserved/materialized through the existing reserved mutation lifecycle.

## P9-I10 — Generated content remains editable

After Apply, the apartment must be editable by ordinary canonical commands. No hidden generator-only ownership may be required to move, split, merge, reclassify or delete spaces.

---

# 4. Target code decomposition

Recommended package structure:

```text
lib/src/application/project/apartment_wizard/
├── apartment_wizard_parameters.dart
├── apartment_topology_ids.dart
├── apartment_topology_family.dart
├── apartment_topology_template.dart
├── apartment_topology_catalog.dart
├── apartment_topology_constraints.dart
├── apartment_topology_candidate.dart
├── apartment_topology_generator.dart
├── apartment_area_fitter.dart
├── apartment_adjacency_validator.dart
├── apartment_wet_core_validator.dart
├── apartment_geometry_generator.dart
├── apartment_geometry_validator.dart
├── apartment_candidate_score.dart
├── apartment_candidate_ranker.dart
├── apartment_vector_scene.dart
├── apartment_vector_scene_projector.dart
├── apartment_wizard_provider.dart
├── apartment_materialization_plan.dart
├── apartment_generation_provenance.dart
└── apartment_generation_errors.dart
```

Presentation stays separate:

```text
lib/src/features/projects/apartment_wizard/
├── apartment_parameters_panel.dart
├── apartment_candidate_carousel.dart
├── apartment_candidate_card.dart
├── apartment_vector_preview.dart
└── apartment_candidate_details.dart
```

Core catalog/generation/scoring code MUST compile without Flutter imports.

---

# 5. P9.0 — Specification and architecture audit

## Goal

Freeze P9 boundaries before runtime code is added and prove P8/P6/P7 prerequisites are sufficient.

## Mandatory audit questions

```text
A01 Does P9 reuse TypedWizardProvider rather than creating a new Wizard API?
A02 Is LevelWizardTarget sufficient for apartment insertion?
A03 Is StructuralZone.apartment represented canonically?
A04 Are SpaceUsage values required by apartment generation available?
A05 Is adjacency representable canonically or does P9 require an application projection?
A06 Is stable BoundaryEdgeId available at materialization time?
A07 Can one ReservedProjectCommand reserve all zone/space/edge identities?
A08 Can P8 semantic diff present zone/space additions meaningfully?
A09 Can save/reopen preserve P9 semantic fingerprint and provenance?
A10 Are apartment candidate previews independent of canonical IDs?
A11 Does target Level belong to the expected Building/Site/Project?
A12 Does P9 avoid assumptions from legacy levelNumber / tree index / localized labels?
```

## Required decisions

P9.0 MUST explicitly record any prerequisite gap as one of:

```text
BLOCKER       implementation cannot safely proceed;
ADAPTER       existing canonical contract is sufficient via bounded adapter;
DEFERRED      not required for P9 acceptance;
CLOSED        prerequisite already satisfies P9.
```

## Exit gate P9-G00

```text
P8 integration path proven;
no second transaction model;
canonical target scope defined;
all permanent identities owned by reservation/materialization path;
no unresolved blocker in P6/P7 prerequisites;
P9 public contract names frozen enough for implementation.
```

---

# 6. P9.1 — ApartmentWizardParameters

## Goal

Define strongly typed apartment-generation intent.

Recommended contract:

```dart
final class ApartmentWizardParameters extends WizardParameters {
  const ApartmentWizardParameters({
    required this.habitableRoomCount,
    required this.approximateAreaM2,
    required this.bathroomCount,
    required this.balconyCount,
    required this.kitchenMode,
    required this.corridorMode,
    this.preferredFamily,
    this.entrySide,
    this.facadePreference,
    this.aspectRatioHint,
  });
}
```

## Required v1 fields

```text
habitableRoomCount   int     1..10
approximateAreaM2    double  required in production P9 v1
bathroomCount        int     >=1, upper bound catalog-driven
balconyCount         int     >=0, upper bound catalog-driven
kitchenMode          separate | kitchenLiving | openPlan
corridorMode         auto | compact | central | minimal
preferredFamily      optional
```

Advanced hints may be optional:

```text
entrySide
facade/window orientation preference
aspectRatioHint
accessibility preference
```

They MUST NOT change the meaning of the required v1 fields.

## Normalization

Normalization must be deterministic and explicit:

```text
trim textual values;
canonical enum values;
area rounded only at a documented precision boundary;
no locale-dependent decimal parsing inside domain contract;
no hidden room-count reinterpretation;
no conversion of unsupported request into a different request.
```

`habitableRoomCount` counts habitable rooms only. Kitchen/service spaces are modeled separately.

## Validation model

Validation produces stable machine-readable codes, e.g.:

```text
apartment.room-count.out-of-range
apartment.area.required
apartment.area.out-of-range
apartment.bathroom-count.invalid
apartment.balcony-count.invalid
apartment.family.unsupported
apartment.target.unsupported
```

Localized UI text is presentation-layer mapping, not the canonical error identity.

## Tests

```text
apartment_wizard_parameters_test.dart
apartment_parameter_normalization_test.dart
apartment_parameter_validation_test.dart
```

## Exit gate P9-G01

```text
all authoritative parameters typed;
normalization deterministic;
validation emits stable codes;
RU/EN presentation does not alter semantics;
1..10 room boundary covered.
```

---

# 7. P9.2 — ApartmentTopologyCatalog

## Goal

Provide a versioned curated semantic catalog from which deterministic candidates are generated.

## Catalog contract

Conceptually:

```dart
abstract interface class ApartmentTopologyCatalog {
  int get catalogVersion;

  List<ApartmentTopologyTemplate> compatibleTemplates(
    ApartmentWizardParameters parameters,
  );

  ApartmentTopologyTemplate? templateById(
    ApartmentTopologyTemplateId id,
    int version,
  );
}
```

Catalog order MUST be stable and explicit.

## Template identity

Each template has:

```text
templateId          stable machine ID
templateVersion     positive integer
familyId            stable topology family
generator contract version
supported room range
supported area range
supported kitchen modes
supported bathroom range
supported balcony range
semantic space grammar
adjacency rules
wet-core policy
area allocation profile
geometry grammar
variant seeds
```

Display names are localized metadata and never identifiers.

## Data storage

Initial P9 may compile templates as Dart const/data objects or load a packaged native asset, provided:

```text
schema is typed/versioned;
loading is deterministic;
no backend is required;
no mutable global registry affects generation order;
invalid catalog data fails qualification/startup clearly.
```

## Required operations

```text
filter compatible templates;
lookup exact template version;
validate catalog uniqueness;
validate family/template constraints;
produce deterministic iteration order.
```

## Tests

```text
apartment_topology_catalog_test.dart
apartment_catalog_uniqueness_test.dart
apartment_catalog_compatibility_test.dart
apartment_catalog_versioning_test.dart
```

## Exit gate P9-G02

```text
catalog has stable IDs and versions;
no SVG asset is authoritative;
duplicate template IDs rejected;
compatibility filter deterministic;
catalog is available offline.
```

---

# 8. P9.3 — Topology families and grammars

## Goal

Represent recognizable apartment planning patterns as semantic grammars rather than fixed drawings.

## Initial family set

Target v1 family vocabulary:

```text
compact
linear
corner
centralCorridor
corridorSpine
euro
openPlan
splitDayNight
```

Not every family must support every room count. Unsupported combinations are normal catalog behavior.

## Grammar content

Each family/template defines:

```text
required semantic spaces;
optional semantic spaces;
habitable-room role slots;
service-space slots;
required/preferred/forbidden adjacency;
entry relationship;
wet-core grouping;
facade/exterior requirements;
relative area weights;
shape/aspect guidance;
circulation strategy;
variant seeds;
mirror/rotation permissions where semantically equivalent.
```

## Example semantic grammar

```text
family: splitDayNight

entry → entranceHall                       required
entranceHall → circulation                 required
dayZone ↔ kitchen/kitchenLiving            required/preferred
bedroom[*] → nightZone                     required
bathroom/wc → wetCore                      required
bedroom[*] → exteriorBoundary              preferred
balcony/loggia → exteriorFacingSpace       required
entry → bedroom                            forbidden direct adjacency
```

## Variant seeds

A seed is a bounded deterministic variation instruction, not random state.

Example:

```text
seedId: split-day-night-a
mirrorAllowed: true
serviceCoreSide: east
entryPlacement: south
bedroomOrdering: [primary, secondary...]
```

Seed identity participates in candidate fingerprint/provenance.

## Qualification breadth

Minimum production catalog target before P9 acceptance:

```text
1-room  ≥ 3 qualified templates/variants
2-room  ≥ 4 qualified templates/variants
3-room  ≥ 4 qualified templates/variants
4-room  ≥ 4 qualified templates/variants
5-room  ≥ 3 qualified templates/variants
6..10   ≥ 2 qualified grammar paths per supported room count
```

These are qualification floors, not a promise that every request returns the same count.

## Exit gate P9-G03

```text
families are semantic, not artwork;
all rules machine-readable;
variant seeds bounded and versioned;
1..10 room capability has explicit support matrix;
unsupported combinations are distinguishable from generator failure.
```

---

# 9. P9.4 — Deterministic area fitting

## Goal

Allocate requested apartment area across semantic spaces without general-purpose stochastic optimization.

## Inputs

```text
requested total area
space specs
min preferred area
max preferred area
relative weight
near-fixed service-space preference
family/template constraints
```

## Required algorithmic properties

The implementation MUST be:

```text
deterministic;
bounded;
monotonic where feasible;
independent of list/hash iteration accident;
explicit about rounding;
capable of reporting infeasibility.
```

Recommended approach:

```text
1. reserve fixed/near-fixed service-space baseline;
2. assign each variable space its minimum;
3. compute remaining distributable area;
4. distribute by normalized weights;
5. clamp at maxima;
6. redistribute residual among remaining eligible spaces;
7. apply deterministic rounding correction to one stable semantic slot order;
8. verify final total within tolerance.
```

## Precision

Canonical fitting should use a stable engineering unit internally, preferably integer square millimetres or a documented decimal precision, so platform floating-point formatting cannot alter candidate identity.

User-facing m² is presentation.

## Failure modes

```text
areaBelowTemplateMinimum
areaAboveTemplateMaximum
allocationResidualUnresolved
spaceConstraintConflict
```

## Tests

Property/table tests must cover:

```text
same input → same allocation;
sum matches requested area within exact documented tolerance;
no space below hard min;
no space above hard max;
monotonic growth under increased total area when constraints allow;
rounding independent of locale/platform.
```

## Exit gate P9-G04

```text
area fitting is deterministic;
all hard bounds preserved;
no hidden area inflation/deflation;
infeasible request reported, not approximated silently.
```

---

# 10. P9.5 — Adjacency and wet-core rules

## Goal

Reject semantically incoherent candidates before scoring.

## Adjacency rule model

Support at least:

```text
required
preferred
forbidden
```

Required/forbidden rules are hard constraints. Preferred rules contribute to scoring only after hard validation.

Rules refer to semantic space keys/usages, never localized room labels.

## Wet-core model

Wet-core policy must represent:

```text
bathroom/wc/shower grouping;
kitchen wet-service relation where required/preferred;
maximum logical separation within the generated topology model;
optional shared service wall preference;
multiple wet-core allowance for larger apartments.
```

P9 wet-core validation is a topology/engineering-starting constraint, not a claim of jurisdictional plumbing compliance.

## Candidate validation result

```dart
final class ApartmentCandidateValidation {
  final List<ApartmentConstraintViolation> blockers;
  final List<ApartmentConstraintObservation> warnings;
}
```

Stable codes examples:

```text
adjacency.required.missing
adjacency.forbidden.present
wet-core.disconnected
wet-core.count.unsupported
balcony.exterior-host.missing
entry.connectivity.invalid
circulation.disconnected
```

## Exit gate P9-G05

```text
hard adjacency failures reject candidate;
wet spaces are semantically grouped per template policy;
preferred adjacency remains scoring input, not blocker;
no rule depends on localized labels.
```

---

# 11. P9.6 — Geometry generation

## Goal

Turn a validated semantic topology + fitted areas + variant seed into simple canonical-ready 2D geometry.

P9 v1 geometry is deliberately bounded. It is not an arbitrary envelope solver.

## Geometry representation

Candidate geometry should use the same coordinate/unit semantics as canonical project geometry or a lossless draft equivalent.

Required concepts:

```text
space polygon/rectilinear boundary;
shared boundary relationships;
exterior boundary markers;
entry opening anchor;
balcony/loggia attachment;
adjacency derived from actual shared topology;
no overlaps;
no negative/zero area;
closed valid polygons.
```

## Initial geometry class

P9 v1 MAY constrain generated geometry to:

```text
orthogonal rectilinear polygons;
finite bounded number of vertices;
axis-aligned normalized generation frame;
deterministic transforms (mirror/rotate) only when allowed by seed.
```

The committed model may later be manually edited into richer polygon shapes through normal authoring.

## Geometry generation pipeline

```text
semantic grammar
    ↓
area allocation
    ↓
layout slots
    ↓
deterministic packing per grammar
    ↓
shared-boundary construction
    ↓
geometry validation
    ↓
candidate topology graph
```

## Hard geometry validation

```text
all polygons valid/closed;
no self-intersection;
no unintended overlap;
all required adjacencies realized geometrically;
all spaces reachable from circulation/entry as declared;
exterior-dependent spaces actually touch exterior boundary;
shared boundaries are topologically consistent;
area deviation per room within documented tolerance;
total area within documented tolerance.
```

## Candidate fingerprint

Fingerprint input must be canonicalized:

```text
template ID/version
seed ID
normalized parameters
stable semantic space keys
normalized integer coordinates
semantic adjacency
```

It MUST exclude:

```text
localized names
paint colors
screen size
SVG path serialization trivia
permanent IDs not yet reserved
wall-clock timestamps.
```

## Exit gate P9-G06

```text
valid candidates contain real geometry, not icon-only placeholders;
geometry deterministic;
overlap/self-intersection blocked;
semantic adjacency agrees with geometry;
candidate fingerprint stable.
```

---

# 12. P9.7 — Candidate scoring and ranking

## Goal

Rank only valid candidates transparently and deterministically.

## Score dimensions

Initial score model:

```text
areaMatch
circulationEfficiency
corridorPenalty
wetCoreCompactness
roomAspectRatioQuality
privacySeparation
kitchenModeMatch
balconyAttachmentQuality
familyPreferenceMatch
facadePreferenceMatch (when input exists)
```

## Score contract

Use explicit normalized ranges, e.g. each dimension `0..10000` integer basis points. Avoid floating tie noise.

Conceptually:

```dart
final class ApartmentCandidateScore {
  final int totalBasisPoints;
  final Map<ApartmentScoreDimension, int> dimensions;
}
```

Weights are versioned generator policy.

## Ranking rules

```text
1. hard-valid candidates only;
2. descending total score;
3. deterministic semantic tie-breakers:
   family order → templateId → templateVersion → seedId → fingerprint;
4. deduplicate semantically equivalent geometry/topology;
5. return bounded Top N, default 3..6.
```

A score is NOT a normative compliance rating.

UI must not label it as “compliant”, “safe” or “certified”.

## Diversity

Top N SHOULD avoid returning near-identical mirrored duplicates when more semantically diverse valid families are available.

Diversity filtering must itself be deterministic.

## Exit gate P9-G07

```text
ranking deterministic;
score explainable by dimensions;
invalid candidates never ranked;
ties stable;
Top N bounded;
near-duplicate suppression qualified.
```

---

# 13. P9.8 — SVG/vector topology renderer

## Goal

Render candidate cards and large preview from the same candidate model without creating a second geometry authority.

## Required pipeline

```text
ApartmentTopologyCandidate
        ↓
ApartmentVectorSceneProjector
        ↓
ApartmentVectorScene
        ↓
Flutter CustomPainter / SVG-compatible output
```

`ApartmentVectorScene` is presentation projection only.

## Scene primitives

At minimum:

```text
room polygon
shared/exterior wall stroke
semantic room label anchor
entry marker
door/opening marker when available
balcony/loggia marker
candidate bounds
optional wet-core highlight
```

## Renderer requirements

```text
stable normalized viewBox/bounds;
light/dark theme compatible;
no semantic differences across platforms;
no WebView/DOM/JavaScript;
no parsing SVG back into project state;
small-card legibility;
large-preview zoom/pan compatibility with P8 shell;
RU/EN labels must not alter geometry.
```

## Static SVG assets

Static assets MAY exist for documentation/tests, but production candidate identity and geometry MUST NOT derive from them.

## Tests

```text
apartment_vector_scene_projector_test.dart
apartment_vector_renderer_golden_test.dart
apartment_vector_dark_light_test.dart
apartment_vector_locale_invariance_test.dart
```

Golden tests validate rendering, not canonical semantics.

## Exit gate P9-G08

```text
renderer consumes candidate only;
no permanent ID allocation;
no canonical mutation;
RU/EN and theme changes preserve candidate fingerprint;
card and large preview use equivalent semantic scene.
```

---

# 14. P9.9 — ApartmentWizardProvider

## Goal

Plug apartment generation into the accepted P8 `WizardProviderRegistry` using `TypedWizardProvider<ApartmentWizardParameters>`.

## Required provider

Conceptually:

```dart
final class ApartmentWizardProvider
    extends TypedWizardProvider<ApartmentWizardParameters> {
  @override
  WizardProviderDescriptor get descriptor;

  @override
  ApartmentWizardParameters typedDefaultsFor(WizardTargetContext target);

  @override
  WizardParameterValidation validateTypedParameters(...);

  @override
  ReservedProjectCommand generateTyped(...);
}
```

## Supported target

P9 production v1 target is primarily:

```text
LevelWizardTarget
```

New-project apartment start MAY be supported through P8 composition only if the provider can deterministically materialize required Building/Level prerequisites in the same single reserved plan. P9 must not invent a second startup path.

If that composition is not yet production-safe, Project Hub Apartment entry may first compose:

```text
P8 Basic Building setup
→ explicit target Level
→ P9 Apartment provider
```

with a user-visible coherent flow and no hidden multi-commit partial state.

## Provider responsibilities

```text
normalize parameters;
query catalog;
generate bounded candidates;
validate;
rank;
retain selected candidate;
produce one ReservedProjectCommand/materialization plan;
expose P8 preview summary/diff semantics.
```

## Provider must not

```text
write repository;
create IDs directly in widget code;
commit on candidate selection;
re-generate silently during Apply;
use localized strings as semantic keys.
```

## Exit gate P9-G09

```text
provider registered by capability registry;
no dead Apartment button before provider availability;
Level target ownership validated;
selected candidate becomes exact reserved command input;
P8 shell needs no apartment-specific transaction branch.
```

---

# 15. P9.10 — P8 Preview/Diff integration

## Goal

Make the selected apartment candidate a first-class P8 prepared candidate with semantic diff.

## Required diff summary

Before Apply, user must be able to understand at least:

```text
StructuralZone apartment to add;
number of Spaces to add;
SpaceUsage distribution;
approximate total area;
added openings/entry anchors if materialized;
topology family/template/variant;
warnings;
conflicts/blockers;
target Building/Level.
```

## Diff granularity

Semantic diff entries should use canonical entity kinds and stable draft/materialization mapping rather than raw JSON paths.

Example:

```text
ADD StructuralZone  Apartment 3A
ADD Space           Living room
ADD Space           Bedroom 1
ADD Space           Bedroom 2
ADD Space           Kitchen
ADD Space           Bathroom
...
```

## Frozen-candidate invariant

Once P8 preview is prepared:

```text
selected fingerprint F
reserved preview candidate F
Apply commits F
```

Changing any apartment parameter or selected variant invalidates/discards the old prepared preview and requires a new preview reservation.

## Stale project rule

If `LocalProjectVersion` changes after preview:

```text
Apply disabled;
old preview cannot be committed;
user explicitly refreshes/regenerates;
new candidate is shown/diffed before confirmation.
```

## Exit gate P9-G10

```text
preview side-effect free;
semantic diff meaningful;
selected candidate fingerprint bound to prepared preview;
no regeneration during Apply;
stale preview fails closed;
Cancel preserves canonical fingerprint.
```

---

# 16. P9.11 — Canonical Spaces / StructuralZone materialization

## Goal

Convert one selected topology candidate into ordinary canonical project entities atomically.

## Materialized minimum

One accepted apartment creates:

```text
StructuralZone(kind: apartment)
    ├── Space(living/bedroom/...)
    ├── Space(kitchen/kitchenLiving)
    ├── Space(bathroom/wc/...)
    ├── Space(entranceHall/corridor)
    ├── optional Space(storage/wardrobe)
    └── optional balcony/loggia representation per canonical model
```

Each Space receives explicit canonical:

```text
SpaceType
SpaceUsage
geometry
LevelId
zone membership
stable identity
```

No room semantics inferred from display names.

## Boundary topology

Where canonical P7 boundary topology is available, materialization must construct stable boundary/edge identity through the reserved mutation plan.

Shared boundaries must not be represented as unrelated duplicate lines if the canonical model has a shared-topology contract.

## Openings

P9 must at minimum materialize an apartment entry relationship/anchor if the canonical opening model supports it safely. Internal door generation may be staged, but required adjacency must remain semantically represented.

If openings are deferred for a template, that capability is explicit in template/provider metadata; it is not silently faked in SVG.

## Atomicity

Materialization is one composite `ReservedProjectCommand`.

Forbidden:

```text
create zone commit
create room 1 commit
create room 2 commit
...
```

Required:

```text
reserve all identities
→ build full candidate aggregate
→ validate graph
→ compute one ProjectChangeSet
→ commit once
```

## Collision/conflict checks

Before commit validate:

```text
target Level still exists;
target belongs to Building/Site/Project;
no identity collision;
zone membership valid;
space geometry valid;
new apartment geometry does not violate applicable target-level overlap policy;
all references resolve.
```

## Exit gate P9-G11

```text
canonical zone/spaces created atomically;
all canonical IDs stable;
SpaceUsage explicit;
materialized geometry matches selected candidate;
Undo removes entire generation in one action;
Redo restores exact semantic result.
```

---

# 17. P9.12 — Provenance

## Goal

Make generated apartment origin traceable and future P15 selective regeneration possible without implementing P15 merge behavior now.

## Required provenance

At generation root and/or entity level preserve:

```text
originType = wizard
generationId
templateId
templateVersion
catalogVersion
generatorVersion
familyId
variantSeedId
candidateFingerprint
normalizedIntentFingerprint
generationKey
created semantic role
overriddenProperties = empty initially
lockedFromRegeneration = false initially
```

## Generation key

Use stable semantic keys such as:

```text
zone:apartment
space:entrance
space:living
space:bedroom:1
space:bedroom:2
space:kitchen
space:bathroom:1
space:balcony:1
```

Generation keys are not display labels and are not permanent IDs.

## Manual edits after commit

P9 does not need to implement selective regeneration, but ordinary edits must not erase provenance accidentally.

Future P15 must be able to distinguish:

```text
generated baseline
manual override
manual entity
removed generated entity
locked generated entity
```

## Exit gate P9-G12

```text
family/template/seed traceable after save/reopen;
semantic generation keys stable;
manual editing does not require deleting provenance;
P15 can consume provenance without reverse-engineering SVG or names.
```

---

# 18. P9.13 — Qualification and Golden Journey

## Goal

Prove P9 as a production vertical slice, not just a generator demo.

## Mandatory Golden Journey

```text
Project Hub
→ New Project
→ Create with Wizard
→ establish/select Building + Level through canonical P8 flow
→ Apartment provider
→ enter typed parameters
→ Generate
→ receive deterministic ranked candidates
→ inspect SVG/vector cards
→ select candidate
→ open P8 Preview
→ inspect semantic Diff
→ Apply
→ verify one canonical ProjectChangeSet
→ Undo
→ verify pre-generation fingerprint restored
→ Redo
→ verify exact generated fingerprint restored
→ Save
→ Close
→ Reopen
→ verify canonical semantic fingerprint equal
→ verify provenance equal
→ manually edit one generated Space
→ save/reopen
→ verify normal canonical editability retained
```

## Functional qualification matrix

At minimum:

```text
Q01  roomCount=1 valid request generates ≥1 valid candidate
Q02  roomCount=10 supported request generates ≥1 valid candidate
Q03  same normalized request generates same candidate fingerprints/order
Q04  changing bathroom count deterministically changes/filter candidates
Q05  changing balcony count deterministically changes/filter candidates
Q06  separate kitchen vs kitchenLiving changes semantic topology
Q07  corridor mode affects eligibility/ranking deterministically
Q08  preferred family affects eligibility/ranking without violating hard constraints
Q09  infeasible area fails with typed reason
Q10  required adjacency missing → candidate rejected
Q11  forbidden adjacency present → candidate rejected
Q12  disconnected wet-core under required policy → rejected
Q13  overlap/self-intersection → rejected
Q14  total area and per-space bounds satisfy tolerance
Q15  ranking ties have stable deterministic order
Q16  candidate set is bounded
Q17  vector preview derives from exact selected candidate
Q18  theme/locale changes do not alter semantic fingerprint
Q19  candidate selection does not mutate canonical project
Q20  Cancel preserves pre-Wizard fingerprint
Q21  Apply commits exact frozen candidate
Q22  stale LocalProjectVersion blocks Apply
Q23  double Apply impossible
Q24  one Apply = one UndoRecord
Q25  Undo restores exact pre-generation fingerprint
Q26  Redo restores exact post-generation fingerprint
Q27  save/reopen preserves zone/spaces/geometry/usage/provenance
Q28  generated apartment remains editable by normal commands
Q29  target Level ownership mismatch fails closed
Q30  no backend/AI/Web dependency required
```

## Catalog qualification

Every production template/seed requires fixture coverage:

```text
catalog schema valid;
compatibility boundaries valid;
area min/max cases;
adjacency rules;
wet-core policy;
geometry validity;
score determinism;
preview projection;
materialization mapping.
```

No unqualified production template may be registered.

## Performance gates

Reference CI environment MUST be recorded like P8.

Initial hard targets for P9 v1:

```text
parameter normalization + compatibility filtering:
  p95 <= 50 ms

bounded candidate generation + validation + ranking
for normal request returning <=6 final candidates:
  p95 <= 500 ms
  p99 <= 1000 ms

vector scene projection for 6 candidate cards:
  p95 <= 100 ms

prepared P8 preview from selected P9 candidate:
  inherits P8 hard gate

additional RSS attributable to one P9 generation session:
  <= 200 MiB
```

If CI evidence proves these thresholds unrealistic for the accepted reference runner, thresholds may change only through an explicit documented architecture decision before merge; tests must never be weakened ad hoc to pass.

## Scale gates

Qualification datasets include:

```text
1 room
3 rooms
5 rooms
10 rooms
1 bathroom
multiple bathrooms
0 balconies
multiple balconies
minimum supported area
maximum supported area
mixed family catalog with rejected candidates
```

## Accessibility / localization

P9 reuses P8 acceptance baseline:

```text
RU + EN
keyboard navigation
screen reader semantics
390 / 900 / 1440 widths
text scale 1.0 / 1.3 / 2.0
reduced motion
48dp minimum interactive targets
```

Candidate cards expose semantic summaries independently of tiny vector labels.

## Platform gates

At minimum before P9 merge:

```text
dart format
flutter analyze
P9 focused unit/widget qualification
full flutter test
macOS workflow / debug build smoke
```

Windows/Linux/mobile semantic behavior is covered by native cross-platform architecture constraints and later P17, while P9 must not introduce platform-specific candidate semantics.

## Exit gate P9-G13

P9 may be declared `ACCEPTED FOR MERGE` only when:

```text
P9-G00..P9-G12 pass;
Golden Journey passes;
all Q01..Q30 pass;
performance/memory hard gates pass;
RU/EN/a11y matrix passes;
full regression suite passes;
macOS CI passes;
no open P9 BLOCKER remains;
a final P9 technical audit records residuals explicitly.
```

---

# 19. Dependency graph

```text
P8 ACCEPTED
   │
   ▼
P9.0 audit/spec freeze
   │
   ├──────────────┐
   ▼              ▼
P9.1 parameters  P9.2 catalog
   │              │
   └──────┬───────┘
          ▼
     P9.3 grammars
          │
     ┌────┼─────────────┐
     ▼    ▼             ▼
  P9.4  P9.5          P9.6
  area   rules         geometry
     └────┬─────────────┘
          ▼
     P9.7 ranking
          │
     ┌────┴───────┐
     ▼            ▼
  P9.8 vector   P9.9 provider
                  │
                  ▼
             P9.10 P8 integration
                  │
                  ▼
             P9.11 materialization
                  │
                  ▼
             P9.12 provenance
                  │
                  ▼
             P9.13 qualification
                  │
                  ▼
             P9 ACCEPTED
```

P9.8 may progress in parallel after the candidate contract is frozen. It may not define candidate semantics.

---

# 20. Error taxonomy

P9 should expose typed errors/issues with stable codes grouped by layer.

```text
parameters.*
catalog.*
topology.*
area.*
adjacency.*
wet-core.*
geometry.*
ranking.*
materialization.*
target.*
preview.*
```

Examples:

```text
apartment.catalog.no-compatible-template
apartment.topology.no-valid-candidate
apartment.area.infeasible
apartment.geometry.overlap
apartment.geometry.invalid-polygon
apartment.target.level-missing
apartment.target.foreign-building
apartment.preview.stale
apartment.materialization.conflict
```

Raw exceptions are diagnostic details, not the primary UX contract.

---

# 21. Observability

P9 generation should expose structured diagnostic telemetry hooks without collecting personal data.

Useful fields:

```text
generatorVersion
catalogVersion
roomCount bucket
candidate templates considered
candidate seeds expanded
candidates rejected by reason
valid candidates ranked
final candidate count
generation duration
vector projection duration
selected family/template/seed
```

Do not log full project contents by default.

---

# 22. Security and robustness

Even though P9 is local-first and catalog-driven:

```text
validate packaged/externalized catalog schema;
reject duplicate IDs/version conflicts;
never execute code embedded in catalog data;
cap list sizes and numeric ranges;
cap geometry vertex counts;
fail closed on malformed template data;
keep SVG/vector projection non-executable;
never accept arbitrary script/HTML as topology content.
```

If future catalog import is added, it requires a separate trust/validation specification.

---

# 23. Product UX requirements

Recommended production flow:

```text
Step 1 — Basics
  area
  habitable rooms
  bathrooms
  balconies/loggias

Step 2 — Preferences
  kitchen mode
  corridor mode
  optional topology family

Step 3 — Choose topology
  3..6 ranked cards
  vector mini-preview
  family
  approximate area breakdown
  concise rationale
  warnings

Step 4 — Preview / Diff
  large P8 preview
  semantic additions
  warnings/blockers

Step 5 — Apply
  exact frozen candidate commit
```

The UI must distinguish:

```text
unsupported request
no valid geometry
valid but lower-ranked alternative
warning
hard blocker
```

No “magic regenerate” action may mutate the live project.

---

# 24. P9 → future engineering automation contract

P9 must deliberately produce semantics useful to later P11–P14 without implementing those phases.

Expected future consumers:

```text
SpaceUsage
        ├── POWER socket profile
        ├── LIGHTING profile
        ├── LAN outlet profile
        ├── FIRE detector profile
        ├── CCTV/ACS relevance
        └── HVAC/other future profiles

adjacency/openings
        └── switch/access/routing reasoning

wet zones
        └── electrical placement restrictions / validation

boundary topology
        └── wall-hosted components / route anchors
```

This is a contract-quality requirement: P9 should not generate anonymous rectangles that later engineering stages must re-interpret from names.

---

# 25. Explicit deferred items

Not required for P9 v1 acceptance:

```text
AI-generated floorplans;
ML candidate ranking;
arbitrary imported envelope fitting;
free-form constraint-solver packing;
furniture placement;
window/facade synthesis from incomplete data;
structural engineering;
regional architectural code certification;
cloud catalog marketplace;
collaborative server-side generation;
selective regeneration merge UI;
automatic electrical device generation.
```

Any future implementation must plug into the same typed/candidate-first/P8 mutation architecture.

---

# 26. Definition of Done

P9 is complete only when all statements are true:

```text
1. Apartment provider is discoverable through the P8 registry.
2. User enters typed apartment parameters for 1..10 habitable rooms.
3. Catalog filtering is versioned and deterministic.
4. Topology families are semantic grammars, not SVG assets.
5. Area fitting is deterministic and fails clearly when infeasible.
6. Hard adjacency/wet-core constraints reject invalid candidates.
7. Generated geometry is real, valid and non-overlapping.
8. Valid candidates receive deterministic explainable scores.
9. 3..6 useful candidates are returned when the request supports them.
10. Vector/SVG previews derive from the exact candidate model.
11. Candidate selection does not mutate canonical state.
12. P8 Preview/Diff shows the exact selected candidate meaningfully.
13. Apply commits the exact frozen candidate atomically.
14. One Apply creates one Undo record.
15. Canonical StructuralZone/Spaces/SpaceUsage/geometry are materialized.
16. Provenance records template/family/variant/generator identity.
17. Undo/Redo preserve semantic fingerprints exactly.
18. Save/Close/Reopen preserves generated semantics and provenance.
19. Generated spaces remain normally editable.
20. Hard performance/memory/a11y/localization gates pass.
21. Full Flutter regression + macOS CI are green.
22. Final P9 audit has no unresolved BLOCKER.
```

Only after these gates may P9 be declared:

```text
P9 APARTMENT TOPOLOGY GENERATOR = ACCEPTED FOR MERGE
```

---

# 27. Recommended first implementation slice

The safest first runtime slice after this specification is:

```text
Slice A
  P9.1 parameters
  P9.2 catalog schema
  P9.3 two initial families
  P9.4 deterministic fitting
  P9.5 semantic validation
  no Flutter UI yet

Slice B
  P9.6 geometry
  P9.7 score/rank
  qualification fixtures

Slice C
  P9.8 vector scene
  P9.9 provider registration
  P9.10 P8 integration

Slice D
  P9.11 materialization
  P9.12 provenance
  P9.13 Golden Journey + hardening
```

This ordering keeps UI work behind deterministic domain/application contracts and prevents the candidate carousel from becoming the accidental source of truth.
