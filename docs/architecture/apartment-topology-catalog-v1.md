# Apartment Topology Catalog v1

## Status

Pragmatic specification addendum for the ElecX Wizard apartment-generation path.

This document complements:

- `docs/architecture/project-template-wizard-v1.md`;
- `docs/architecture/project-composition-generation-v1.md`;
- `docs/architecture/project-composition-foundation-decisions-v1.md`.

If requirements conflict, the foundation decisions and native portability baseline win.

The goal is to provide useful, recognizable apartment-layout variants without introducing a universal architectural solver, AI-generated floor planning, or unconstrained optimization into the first Wizard implementation.

## Product objective

For apartment generation, the user provides a small set of understandable parameters and ElecX proposes several familiar apartment topology variants.

Example input:

```text
habitable rooms:      3
approximate area:     78 m2
bathrooms:            1
balconies/loggias:    1
kitchen mode:         separate | kitchen-living
corridor preference:  compact | central | none/prefer-open
```

The Wizard then:

```text
parameters
  -> compatible topology families
  -> deterministic variants
  -> validation
  -> ergonomic scoring
  -> SVG mini-previews
  -> user selects one variant
  -> canonical candidate generation
  -> normal Wizard diff/preview/commit
```

The generated layout is an approximate engineering-starting topology. The engineer remains free to adjust room dimensions and geometry to the real project after commit.

## Explicit non-goals for v1

The first version MUST NOT attempt to provide:

- a universal architectural floor-plan solver;
- AI/LLM-created free-form apartment geometry;
- arbitrary envelope fitting;
- code-compliant architectural design certification;
- furniture-level interior design;
- globally optimal room packing;
- automatic structural-wall design;
- automatic facade/window design from incomplete inputs.

These may be separate future research/product stages. They are not required for P8/P9 readiness.

## Wizard boundary

This feature does not create a second generation architecture.

It plugs into the existing Wizard pipeline:

```text
ApartmentWizardParameters
        |
        v
ApartmentTopologyCatalog
        |
        v
ApartmentTopologyCandidate[]
        |
        v
selection / preview
        |
        v
GeneratedProjectCandidate
        |
        v
CandidateGraphValidator
        |
        v
ProjectDiff
        |
        v
ProjectMutationSession
```

No topology card or SVG preview may mutate the live project.

## Minimal apartment parameters

The pragmatic v1 request extends/normalizes the existing apartment Wizard contract with the following user-facing inputs:

```text
roomCount            1..10 habitable rooms
approximateAreaM2    optional but strongly recommended
bathroomCount        1..N within supported template constraints
balconyCount         0..N within supported template constraints
kitchenMode          separate | kitchenLiving | openPlan
corridorMode         auto | compact | central | minimal
preferredFamily      optional
```

Existing advanced parameters such as entry side, facade/window sides and aspect ratio remain supported by the broader Wizard contract, but the simple apartment flow does not require all of them from the user.

The simple UI must not expose parameters that are not needed to produce meaningful variants.

## Topology families

The initial controlled catalog SHOULD include a small set of recognizable families:

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

A family is a semantic topology grammar, not an SVG asset and not a fixed final polygon.

Each family defines:

```text
family id
supported room-count range
supported area range or area guidance
allowed kitchen modes
allowed bathroom-count range
allowed balcony-count range
required semantic spaces
optional semantic spaces
adjacency rules
relative area weights
circulation policy
wet-core policy
exterior/facade preferences where known
variant seeds
```

The catalog may start with fewer families if qualification coverage is stronger.

## Template representation

Conceptually:

```dart
final class ApartmentTopologyTemplate {
  final TemplateId templateId;
  final int templateVersion;
  final ApartmentTopologyFamily family;
  final ApartmentTopologyConstraints constraints;
  final List<TopologySpaceSpec> spaces;
  final List<TopologyAdjacencySpec> adjacency;
  final TopologyAreaWeights areaWeights;
  final CirculationPolicy circulation;
  final WetCorePolicy wetCore;
  final List<TopologyVariantSeed> variants;
}
```

Exact implementation names may differ.

The authoritative data is semantic topology and constraints. SVG is a projection of this data.

## Candidate generation

Generation is deterministic.

For normalized parameters, the engine:

```text
1. filters incompatible topology templates;
2. expands a bounded set of predefined variant seeds;
3. assigns semantic spaces;
4. distributes approximate area using template weights and min/max constraints;
5. creates simple normalized geometry for preview/candidate use;
6. validates adjacency and overlap constraints;
7. scores valid candidates;
8. returns the best bounded result set.
```

The first version SHOULD return a small number of useful alternatives, for example:

```text
3..6 candidates
```

It MUST NOT generate hundreds of low-value permutations.

## Area fitting

Area fitting is deliberately simple in v1.

Each semantic space uses:

```text
minimum preferred area
maximum preferred area
relative weight
fixed/near-fixed service-space preference where applicable
```

The requested apartment area is distributed within those bounds.

The algorithm may use deterministic weighted allocation; a general-purpose nonlinear optimization engine is not required.

If the requested area cannot be represented by the selected family without violating template constraints, that candidate is rejected.

The Wizard may propose another compatible family instead of silently producing implausible room sizes.

## Semantic spaces

Generated candidates use canonical `SpaceType + SpaceUsage` semantics.

Typical apartment spaces include:

```text
livingRoom
bedroom
kitchen
kitchenLiving
bathroom
wc
corridor
entranceHall
wardrobe
storage
balcony
loggia
```

`roomCount` counts conventional habitable rooms only. Service spaces are modeled separately.

No semantic meaning is inferred from localized display labels.

## Adjacency rules

Each topology template declares required/preferred/forbidden adjacency.

Examples:

```text
entranceHall -> corridor/living zone          required
bathroom -> wet-core group                    preferred
kitchen -> livingRoom                         preferred for open/euro mode
balcony/loggia -> exterior-facing room        required
bedroom -> direct entrance door               normally forbidden
```

These rules are intentionally lightweight in v1 and exist to prevent obviously incoherent candidates, not to replace a full architectural expert system.

## Ergonomic scoring

Valid candidates are ranked with a transparent deterministic score.

The first scoring model may include:

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
```

The score is for ranking Wizard alternatives only. It is not a normative compliance score.

A candidate MUST satisfy validation before it can receive a ranking score.

## Dynamic SVG topology preview

Wizard cards use dynamically generated SVG-like vector previews from the topology candidate/model.

The preview is diagrammatic, not a full architectural drawing.

Required characteristics:

```text
stable normalized canvas
consistent wall/stroke grammar
semantic room fills or symbols
entrance marker
optional balcony/loggia marker
clear comparison at small card size
native light/dark theme compatibility
```

Pipeline:

```text
ApartmentTopologyCandidate
        |
        v
TopologyIconModel
        |
        v
TopologyIconLayout
        |
        v
vector/SVG renderer
```

The renderer MUST NOT become an authoritative source of geometry or project semantics.

SVG/vector output is presentation only.

The same topology candidate can also feed the larger 2D Wizard preview.

## Variant identity

A topology variant has draft-scoped identity during preview.

Conceptually:

```text
family
base template id/version
variant seed
normalized parameters
candidate fingerprint
```

Selecting a card does not allocate permanent project entity IDs.

Stable permanent IDs are assigned/reused only through the existing Wizard commit path and `EntityIdFactory`/generation mapping.

## Commit/materialization boundary

P8 owns:

```text
typed inputs
topology catalog contract
candidate enumeration
validation
ranking
SVG/vector preview
selection
preview/diff/cancel semantics
```

P9 owns production apartment materialization into canonical project geometry:

```text
StructuralZone apartment
canonical Spaces
SpaceUsage
adjacency
boundary topology
openings when supported
GenerationManifest/provenance
```

The P9 result is an ordinary editable canonical ElecX project structure.

After commit, the engineer may:

```text
move boundaries
resize rooms
split/merge spaces
adjust openings
change room usage
```

using normal canonical mutation paths.

## Provenance

Committed generated entities retain normal Wizard provenance:

```text
originType = wizard
generationId
templateId
templateVersion
generatorVersion
generationKey
overriddenProperties
lockedFromRegeneration
```

The topology family/variant selection must be traceable in the generation manifest so later selective regeneration can distinguish generated baseline from manual edits.

## Simple UX

Recommended first-flow:

```text
Apartment Wizard

Step 1 — Basics
- approximate area
- habitable room count
- bathrooms
- balconies/loggias

Step 2 — Preferences
- kitchen: separate / kitchen-living / open
- corridor: auto / compact / central / minimal

Step 3 — Choose topology
[ Compact ] [ Linear ] [ Corner ] [ Euro ] ...
SVG/vector mini-preview
approximate area breakdown
short topology description
rank/recommendation indicator

Step 4 — Preview
larger plan candidate
warnings
semantic summary

Step 5 — Apply
normal Wizard diff + atomic commit
```

The user may return to previous steps and regenerate candidates without mutating the live project.

## Fallback behavior

If no catalog candidate supports the request:

```text
- do not invent geometry;
- show that the combination is unsupported;
- identify the blocking parameters;
- optionally show the nearest supported parameter change as a suggestion;
- preserve user input until explicitly changed.
```

No silent coercion is allowed.

## Performance constraints

The topology-card experience should feel immediate.

The v1 implementation therefore:

- uses a bounded catalog;
- uses bounded variant seeds;
- avoids exhaustive combinatorial search;
- avoids backend calls;
- avoids AI inference;
- avoids full engineering generation while selecting topology cards;
- may cache pure preview projections by normalized request + template version.

Caching must not turn preview identity into persistent project identity.

## Qualification

Minimum acceptance scenarios:

```text
AT01  simple parameters produce multiple recognizable candidates
AT02  same normalized request/template versions produce equivalent candidates
AT03  changing bathroom count filters/regenerates candidates deterministically
AT04  changing balcony count filters/regenerates candidates deterministically
AT05  separate kitchen and kitchen-living produce semantically different candidates
AT06  corridor preference changes eligible/ranked topology families
AT07  invalid/unsupported combination fails before project mutation
AT08  candidates satisfy declared adjacency constraints
AT09  area allocation remains within template limits
AT10  candidate ranking is deterministic
AT11  SVG/vector preview derives from candidate topology, not an unrelated asset
AT12  SVG/vector preview does not allocate permanent entity IDs
AT13  topology selection does not mutate live canonical state
AT14  cancel preserves canonical semantic fingerprint
AT15  confirmed selection enters standard GeneratedProjectCandidate/diff/commit path
AT16  one confirmed apartment generation is one atomic ProjectChangeSet + UndoRecord
AT17  committed apartment is manually editable through normal canonical commands
AT18  save/reopen preserves committed semantic fingerprint
AT19  generated baseline retains template/family/variant provenance
AT20  no backend, Web runtime, AI service or universal solver is required
```

## Implementation decomposition

This addendum does not change the authoritative P0..P17 order.

It refines existing Wizard stages:

```text
P8/G1 typed Wizard contracts

P8/G2 deterministic template catalog
  - ApartmentTopologyFamily
  - ApartmentTopologyTemplate
  - compatibility filtering
  - bounded variant seeds
  - deterministic area allocation
  - lightweight adjacency validation
  - ergonomic candidate scoring
  - dynamic vector/SVG topology cards

P8/G3 candidate validator + diff
P8/G4 preview/cancel semantics

P9/G5 apartment generator 1..10
  - selected topology -> canonical candidate geometry
  - canonical SpaceUsage / StructuralZone
  - stable boundary topology at commit

P9/G6 apartment topology library
  - expand qualified topology families/templates
  - qualification fixtures
```

## Deferred extensions

Explicitly deferred beyond pragmatic v1:

```text
arbitrary external-envelope fitting
constraint solver for free-form floor plans
ML ranking from user/project history
AI-generated topology
automatic window/facade synthesis
furniture-aware optimization
regional architectural catalog marketplace
```

These extensions must reuse the same typed/candidate-first contracts rather than bypass them.

## Definition of done

The pragmatic apartment topology catalog is ready when:

```text
- user can enter room count, approximate area, bathroom count and balcony count;
- kitchen and corridor preferences are explicit;
- the catalog returns several recognizable, valid variants when supported;
- variants are generated deterministically from semantic templates;
- each variant has a dynamic vector/SVG preview derived from the same candidate model;
- unsupported combinations fail clearly without mutating the project;
- user selection proceeds through the standard Wizard candidate/diff/preview path;
- committed result becomes ordinary canonical editable ElecX structure;
- no AI, backend dependency or universal architectural solver is required.
```

## Conclusion

For the first ElecX Apartment Wizard, quality and predictability are more valuable than unrestricted procedural generation.

The production path is therefore:

```text
small typed request
   -> curated topology catalog
   -> bounded deterministic variations
   -> validate + rank
   -> dynamic SVG/vector previews
   -> engineer selects familiar topology
   -> canonical candidate
   -> refine real dimensions in the normal editor
```

This gives the Wizard useful generative behavior while keeping implementation complexity, qualification scope and architectural risk under control.
