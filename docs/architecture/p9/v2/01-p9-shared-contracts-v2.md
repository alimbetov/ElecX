# P9 Shared Cross-Stage Contracts v2

Status: **AUTHORITATIVE SHARED MODEL**  
Applies to: P9.1..P9.13

## 1. Purpose

This document prevents stage specifications from inventing incompatible representations for the same concept.

If a P9 stage needs a concept below, it MUST reuse the same semantic contract even if exact Dart class names differ.

## 2. Version set

Every candidate/result carries explicit version identity:

```dart
final class P9VersionSet {
  final int requestSchemaVersion;
  final int catalogVersion;
  final int templateVersion;
  final String generatorVersion;
  final String allocatorVersion;
  final String geometryAlgorithmVersion;
  final String scoringProfileVersion;
  final int provenanceSchemaVersion;
}
```

Not every intermediate stage needs every field, but the complete selected candidate/provenance path does.

Any semantic algorithm/data change capable of changing candidate output for identical normalized request MUST bump its owning version.

## 3. Template selection identity

```dart
final class ApartmentTopologyIdentity {
  final TemplateId templateId;
  final int templateVersion;
  final ApartmentTopologyFamily family;
  final String variantSeedId;
}
```

This is not persistent project entity identity.

## 4. User intent vs selection

```dart
final class NormalizedApartmentRequest {
  // P9.1 normalized semantic request
  final String intentFingerprint;
}

final class ApartmentCandidateSelection {
  final String candidateFingerprint;
  final String templateIdValue;
  final int templateVersion;
  final String variantSeedId;
}
```

Rule:

```text
intentFingerprint identifies WHAT the user requested
candidateFingerprint identifies WHICH exact generated answer was selected
```

They MUST NOT be conflated.

## 5. Area model

P9 v1:

```dart
enum ApartmentAreaBasis {
  interiorNetExcludingExteriorAppendages,
}

enum SpaceAreaParticipation {
  requestedInteriorArea,
  exteriorAppendage,
}
```

Canonical accounting:

```text
requestedInteriorArea
  = sum(fitted interior-participating spaces)

exteriorAppendageArea
  = sum(balcony/loggia/terrace fitted areas)

requestedInteriorArea does not include exteriorAppendageArea
```

Candidate summaries always label these separately when appendages exist.

## 6. Semantic generation key

Every generated semantic unit has a deterministic key before canonical IDs:

```text
zone:apartment
space:livingRoom:1
space:bedroom:1
space:bedroom:2
space:bathroom:1
boundary:bedroom:1:segment:0
adjacency:bedroom:1|corridor:1|sharedBoundary
opening:corridor:1|bedroom:1|door
```

Generation keys:

- are locale-independent;
- survive deterministic regeneration intent;
- are not reused for two entities inside one generation;
- are not substitutes for persistent `EntityId`.

## 7. Candidate fingerprint hierarchy

Recommended hierarchy:

```text
intentFingerprint
  -> draftFingerprint
  -> areaFitFingerprint
  -> geometryFingerprint
  -> candidateFingerprint
  -> candidateSetFingerprint
```

### 7.1 `candidateFingerprint`

Includes at least:

```text
intentFingerprint
P9VersionSet semantic versions
topology identity
areaFitFingerprint
geometryFingerprint
score profile version + score breakdown inputs needed for identity policy
```

Final ranking position SHOULD NOT itself be part of the candidate identity; it is a property of the candidate set/profile.

### 7.2 `candidateSetFingerprint`

Includes ordered selected/ranked candidate fingerprints plus scoring/diversity policy version.

## 8. Opening intent

P9.5 access semantics become exact P9.6/P9.11 opening intents.

```dart
enum ApartmentOpeningIntentKind {
  entryDoor,
  interiorDoor,
  openPassage,
}

final class OpeningIntent {
  final String generationKey;
  final ApartmentOpeningIntentKind kind;
  final String hostSpaceKey;
  final String? connectedSpaceKey;
  final String hostSemanticSegmentKey;
  final int widthMm;
  final int heightMm;
  final int baseElevationMm;
  final int offsetFromSegmentStartMm;
}
```

Rules:

- exactly one `entryDoor` per P9 v1 apartment;
- every required access graph edge has a corresponding interior door/open passage intent;
- dimensions/offset fit the selected host segment;
- intent uses semantic segment keys before `BoundaryEdgeId` reservation;
- P9.11 maps semantic host segment to exact reserved `BoundaryEdgeId`;
- an unhostable mandatory intent rejects candidate before commit.

## 9. Exterior appendage contract

Balcony/loggia/terrace is represented as a normal semantic Space plus explicit geometry role:

```text
SpaceUsage balcony/loggia/terrace
SpaceAreaParticipation exteriorAppendage
primaryAttachmentHostSpaceKey
attachmentBoundarySemanticKey
```

It is owned by the apartment StructuralZone but excluded from requested interior-area accounting.

## 10. Failure envelope

```dart
enum P9FailureSeverity { info, warning, blocker }

enum P9FailureStage {
  parameters,
  catalog,
  grammar,
  area,
  semantics,
  geometry,
  scoring,
  rendering,
  provider,
  preview,
  materialization,
  provenance,
  qualification,
}

final class P9Failure {
  final String code;
  final P9FailureStage stage;
  final P9FailureSeverity severity;
  final Map<String, Object?> facts;
  final List<P9Suggestion> suggestions;
}
```

`code` and `facts` are locale-independent. UI maps to RU/EN text.

## 11. Candidate validation report

A candidate carries validation evidence rather than a single boolean:

```dart
final class P9CandidateValidationReport {
  final List<P9Failure> blockers;
  final List<P9Failure> warnings;
  final TopologySemanticMetrics semanticMetrics;
  final GeometryMetrics geometryMetrics;
}
```

A candidate is selectable only when `blockers.isEmpty`.

## 12. Candidate model boundary

Conceptually:

```dart
final class RankedApartmentCandidate {
  final ApartmentTopologyIdentity topologyIdentity;
  final NormalizedApartmentRequest request;
  final AreaFittedTopologyDraft areaFit;
  final ApartmentGeometryCandidate geometry;
  final ApartmentScoreBreakdown score;
  final P9CandidateValidationReport validation;
  final String candidateFingerprint;
}
```

This remains draft/application state until P8 reservation/materialization.

## 13. Stable ordering

Every P9 collection that affects output MUST define an explicit comparator.

Default semantic-key ordering:

```text
zone first
entry/day/circulation roles by declared stable role order
habitable repeated roles by numeric ordinal
service roles by declared stable role order
appendages
then lexical generationKey fallback
```

Do not use enum index as persisted semantic order unless enum order is explicitly versioned.

## 14. Canonical serialization

Fingerprint serialization uses:

- UTF-8;
- explicit field names/version;
- fixed field order;
- integers in base-10 without locale formatting;
- booleans `true/false`;
- enums by stable string code, not ordinal;
- lists in explicit stable order;
- maps converted to sorted key/value sequences;
- no timestamps unless the timestamp is itself semantic input (P9 v1: none).

## 15. Hashing

SHA-256 is recommended for deterministic fingerprints.

Fingerprints are integrity/identity evidence, not secrets and not cryptographic authentication.

## 16. Cache key

Pure candidate-generation cache MAY use:

```text
intentFingerprint
catalogVersion
generatorVersion
```

plus any stage-specific version needed for correctness.

Cache values contain no canonical project IDs and may be discarded at any time.

## 17. Canonical-ID boundary

Before P8 reserved preview:

```text
NO permanent ZoneId/SpaceId/BoundaryEdgeId/OpeningId
```

At preview preparation:

```text
MutationIdentityReservation allocates IDs once
```

At Apply:

```text
exact same IDs + exact frozen candidate are committed
```

## 18. Normative posture

P9 semantic/geometry constraints are generation-quality rules. Unless a rule carries separately qualified normative evidence/profile, it MUST NOT be represented to the user as statutory compliance.

Future normative validation consumes canonical output and publishes separate evidence.

## 19. Shared contract acceptance

Before P9 implementation proceeds beyond early domain stages, contract tests MUST prove:

```text
canonical serialization stable
hash stable
intent vs candidate selection separated
area accounting separated
opening intent complete
failure codes locale-independent
no draft canonical IDs
version fields explicit
```

## 20. Presentation capability model

Responsive presentation uses a capability value object separate from domain state.

Conceptual contract:

```dart
final class ElecXPresentationCapabilities {
  final double logicalWidth;
  final double logicalHeight;
  final bool hasPrecisePointer;
  final bool hasHover;
  final bool hasTouch;
  final bool hasStylus;
  final bool hasHardwareKeyboard;
  final bool animationsDisabled;
  final double textScaleFactor;
}
```

This object MAY be recomputed whenever window/device capabilities change.

It MUST NOT participate in:

```text
intentFingerprint
candidateFingerprint
candidateSetFingerprint
generation provenance
canonical project state
```

## 21. Responsive width class

```dart
enum ElecXResponsiveWidthClass {
  compact,   // < 600
  medium,    // 600..1023
  expanded,  // 1024..1439
  large,     // >= 1440
}
```

Width class is derived from current logical viewport and is presentation-only.

A width-class change MUST NOT recreate or invalidate the semantic Wizard session.

## 22. Semantic Wizard navigation state

Presentation routes/panes/tabs map onto one semantic state model.

```dart
enum ApartmentWizardSemanticStep {
  parameters,
  candidates,
  candidateDetails,
  preview,
  completed,
}
```

Desktop may render multiple steps/panes simultaneously; phone may render one full-screen route at a time. The underlying semantic session remains singular.

## 23. Input operation abstraction

Widgets/gestures SHOULD map to platform-neutral operations rather than directly mutating business state.

```dart
enum ApartmentWizardInputOperation {
  selectCandidate,
  nextCandidate,
  previousCandidate,
  openCandidateDetails,
  generate,
  openPreview,
  openDiff,
  apply,
  cancel,
  back,
  zoomIn,
  zoomOut,
  zoomToFit,
  panPreview,
}
```

Exact command classes MAY differ, but semantics MUST remain modality-independent.

Examples:

```text
mouse click     -> selectCandidate
keyboard Enter  -> selectCandidate
finger tap      -> selectCandidate
stylus tap      -> selectCandidate
```

## 24. Preview viewport state

```dart
final class PreviewViewportState {
  final double scale;
  final double translationX;
  final double translationY;
}
```

Viewport state is transient presentation state.

Rules:

- finite/bounded values;
- changing it cannot alter geometry/candidate fingerprints;
- `zoomToFit` restores a usable view;
- same candidate vector scene is rendered regardless of viewport state;
- viewport state is not persisted as generation provenance.

## 25. Input modality invariants

No required action may be available only through:

```text
hover
right click
long press
stylus
multi-touch
```

Each required action has at least one explicit discoverable control or keyboard/focus path appropriate to the form factor.

Touch targets for touch-capable surfaces use minimum `48 x 48` logical px.

## 26. Responsive state equivalence

The following are presentation-only transitions:

```text
portrait <-> landscape
compact <-> medium <-> expanded <-> large
window resize
split-screen resize
light <-> dark theme
text scale change
mouse attached/detached
tablet keyboard attached/detached
```

They MUST preserve, when still semantically valid:

```text
request input
candidate set
candidate order
selected candidate
P8 prepared preview/reservation
validation state
```

They MUST NOT allocate canonical IDs or rerun generation merely because layout changed.

## 27. Cross-platform semantic equality

For equal normalized request + semantic versions/catalog contents:

```text
Windows
macOS
Linux
iPadOS
Android
iOS
```

must observe the same ordered candidate fingerprints where the platform participates in qualification.

Pixel rendering may differ; vector-scene semantic fingerprint and candidate semantics may not.

## 28. Forward reuse contract

The shared presentation/input contracts above are intentionally provider-neutral foundations for P10-P14.

Later phases may extend operations for:

```text
CAD select
move
resize
snap
route edit
placement
multi-select
context actions
stylus precision
```

but must preserve:

```text
one semantic command layer
one responsive capability model
one viewport abstraction
one canonical project model
```

No later phase should introduce separate desktop/mobile domain models because P9 failed to establish responsive/input boundaries.
