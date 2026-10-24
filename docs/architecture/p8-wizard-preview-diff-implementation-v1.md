# P8 Wizard + Preview/Diff Implementation Specification v1

## Status

Implementation specification for `feat/p8-wizard-preview-diff`.

This document refines P8 from the authoritative roadmap in:

- `docs/architecture/project-composition-foundation-decisions-v1.md`;
- `docs/architecture/project-template-wizard-v1.md`;
- `docs/architecture/project-composition-generation-v1.md`.

Apartment topology generation remains defined by:

- `docs/architecture/apartment-topology-catalog-v1.md`.

If this document conflicts with the foundation decisions, the foundation decisions win.

P8 is an implementation phase, not a parallel architecture. It must reuse the canonical ProjectAggregate, LocalProjectVersion, ProjectMutationSession, ProjectChangeSet, Undo/Redo, EntityIdFactory, ProjectRepository and canonical navigator contracts already present in the codebase.

## P8 objective

P8 introduces one production Wizard framework for deterministic candidate-first authoring with a visible preview and semantic diff before commit.

The first user-visible product goal is to make Wizard the normal start path for a new project and a discoverable insertion path from the existing Project Navigator.

The core user contract is:

```text
intent
→ typed parameters
→ deterministic candidate
→ validation
→ preview + semantic diff
→ explicit confirm
→ stale-version check
→ one atomic canonical commit
→ one Undo record
```

No preview action may mutate the live project.

## Scope boundary

P8 includes:

```text
P8A Wizard entry points and state machine
P8B typed Wizard/provider contracts
P8C deterministic candidate session
P8D semantic preview/diff
P8E vector/SVG-compatible preview projection
P8F atomic preview-to-commit lifecycle
P8G base project/building startup Wizard
P8H qualification and regression coverage
```

P8 explicitly does not include the full production implementation of:

```text
apartment generator 1..10              → P9
apartment topology catalog algorithms  → P9
cottage generator                       → P10
building/typical-floor generator        → P10
residential-complex generator           → P10
engineering starter generation          → P12
selective regeneration/provenance merge → P15
```

P8 MUST define stable provider interfaces for these later phases so they plug into the same Wizard without changing its transaction or preview architecture.

## Existing baseline that P8 must reuse

The current repository already contains the required canonical mutation primitives.

### ProjectMutationSession

`lib/src/application/project/project_mutation.dart` already provides:

```text
ProjectCommand
ProjectMutationRequest
ProjectMutationPreview
ProjectChangeSet
ProjectMutationSession.preview()
ProjectMutationSession.commit()
LocalProjectVersion stale checks
CandidateGraphValidator
Undo/Redo
```

P8 MUST NOT create a second transaction engine.

### Reserved preview/apply lifecycle

`lib/src/application/project/project_mutation_reservation.dart` already provides the stronger lifecycle required by Wizard preview:

```text
ReservedProjectCommand
MutationIdentityReservation
ReservedProjectMutationCoordinator
ReservedProjectMutationPreview
ReservedProjectMutationCommitResult
ProjectSemanticChangeSet
```

This is the mandatory commit backbone for P8.

The critical properties are already present:

```text
identity is reserved once for one preview/apply lifecycle;
preview does not mutate canonical state;
commit reuses the exact frozen preview candidate;
commit fails on stale LocalProjectVersion;
a preview is bound to its exact mutation coordinator/session;
a reservation cannot be consumed twice;
one commit enters the existing Undo stack once.
```

P8 extends this infrastructure with Wizard-specific contracts and presentation. It does not replace it.

## Architectural invariants

The following are non-negotiable.

### P8-I01 — One canonical state

Wizard never owns a second persistent project graph.

`GeneratedProjectCandidate` is temporary draft state only.

### P8-I02 — Explicit target context

Every Wizard session receives an explicit target scope. It never infers a Building or Level from stale widget state.

### P8-I03 — Typed parameters

Untyped `Map<String, Object?>` is forbidden as the authoritative Wizard parameter API.

### P8-I04 — Deterministic generation

Normalized parameters + template version + generator version + explicit target context must produce semantically equivalent candidates.

### P8-I05 — Preview is side-effect free

Opening, editing, regenerating, switching variants and cancelling the Wizard do not:

```text
increment LocalProjectVersion;
append Undo history;
write ProjectRepository;
change canonical semantic fingerprint;
change active canonical navigation as a persistent side effect.
```

### P8-I06 — Exact preview is committed

Confirmation commits the frozen preview candidate, not a newly regenerated approximation.

### P8-I07 — One user intent, one commit

One confirmed Wizard operation creates exactly one canonical `ProjectChangeSet` and one Undo record.

### P8-I08 — Stale preview fails closed

If the canonical LocalProjectVersion changes after preview creation, confirm is blocked until the user regenerates/rebases the preview.

### P8-I09 — No widget graph mutation

Flutter widgets only edit Wizard draft state and invoke application services.

### P8-I10 — Native-only

No browser runtime, DOM, WebView, JavaScript or browser persistence is introduced.

## Product entry points

P8 has two production entry points.

### Entry A — Project Hub / New Project

Current behavior immediately creates a legacy blank document and opens the editor. P8 changes the user-visible flow to:

```text
New Project
    ↓
Project Start Wizard
    ↓
Choose start mode
    ├── Apartment             [provider appears when P9 is available]
    ├── Cottage               [provider appears when P10 is available]
    ├── Building              [P8 base provider]
    ├── Residential complex   [provider appears when P10 is available]
    └── Blank project         [manual authoring path]
```

Production UI MUST NOT show dead family buttons. Availability comes from a capability/provider registry.

`Demo` may remain a development/test entry but is not a normal production start option.

### Entry B — Canonical Project Navigator

The existing controls remain:

```text
+ Building
+ Level
+ Room
```

P8 adds a discoverable:

```text
Wizard
```

The Wizard receives the current canonical context explicitly.

Examples:

```text
site selected     → providers supporting site insertion
building active   → providers supporting building insertion
level active      → providers supporting level insertion
```

No provider is shown for a target scope it cannot handle.

## Product empty/start state

The current legacy path creates `EditorBuildingWorkspace.blank()`, which materializes one Building and Level 1 before the user has authored them.

P8 treats this as a compatibility seed, not as the desired product model.

The user-visible new-project start state MUST be:

```text
New project

Project structure is not configured yet.

[ Create with Wizard ]
[ Start blank ]
```

The UI must not present a compatibility placeholder building/level as though the user created it.

### Transitional compatibility rule

Until the editor can natively open a truly site-only legacy document, P8 may keep the existing legacy seed internally, but:

- it is hidden behind the startup gate;
- it must not be counted as Wizard output before confirm;
- a confirmed base-start Wizard must normalize/reuse/replace the seed deterministically through one canonical mutation plan;
- cancel must leave the pre-Wizard canonical fingerprint unchanged;
- no new feature may take a dependency on placeholder IDs or placeholder labels.

A later persistence migration may remove the compatibility seed without changing Wizard contracts.

## Wizard target scopes

P8 introduces explicit target scope types.

Conceptually:

```dart
sealed class WizardTargetContext {
  const WizardTargetContext();

  ProjectId get projectId;
  SiteId get siteId;
  LocalProjectVersion get baseVersion;
}

final class NewProjectWizardTarget extends WizardTargetContext {}
final class SiteWizardTarget extends WizardTargetContext {}
final class BuildingWizardTarget extends WizardTargetContext {
  final BuildingId buildingId;
}
final class LevelWizardTarget extends WizardTargetContext {
  final BuildingId buildingId;
  final LevelId levelId;
}
```

A provider declares the scopes it supports.

P8 code must not represent target context with raw tree paths or localized labels.

## Wizard family/provider architecture

P8 owns the common provider contract.

Conceptually:

```dart
abstract interface class WizardProvider<P extends WizardParameters> {
  WizardProviderDescriptor get descriptor;

  P defaultsFor(WizardTargetContext target);

  WizardParameterValidation validateParameters(
    P parameters,
    WizardTargetContext target,
  );

  GeneratedWizardCandidate generate(
    P parameters,
    WizardGenerationContext context,
  );
}
```

Descriptor:

```dart
final class WizardProviderDescriptor {
  final TemplateId templateId;
  final int templateVersion;
  final String generatorVersion;
  final WizardFamilyId familyId;
  final String displayName;
  final Set<WizardTargetScope> supportedScopes;
}
```

`WizardFamilyId` is a stable typed value, not a localized display label.

Provider registration is explicit:

```dart
final class WizardProviderRegistry {
  List<WizardProviderDescriptor> availableFor(WizardTargetContext target);
}
```

The registry owns capability discovery. UI must not hard-code assumptions such as "Apartment is always available".

## Typed Wizard parameters

Common root:

```dart
sealed class WizardParameters {
  const WizardParameters();
}
```

P8 base provider:

```dart
final class BasicBuildingWizardParameters extends WizardParameters {
  final String buildingName;
  final int aboveGroundLevelCount;
  final int basementLevelCount;
  final int floorToFloorHeightMm;
  final bool createGroundLevel;
}
```

Exact fields may evolve, but P8 base startup must be sufficient to produce a useful initial hierarchy without requiring P10's advanced building generator.

P8 base provider is deliberately structural only. It does not generate apartments, cores, facade design or engineering systems.

Future typed families plug in without weakening type safety:

```dart
ApartmentWizardParameters
CottageWizardParameters
BuildingWizardParameters
ResidentialComplexWizardParameters
```

## P8 base Building Wizard

The P8 base provider exists so the Wizard is functional before P9/P10.

Minimum UI inputs:

```text
project name            existing project metadata for new-project flow
building name
above-ground levels     1..200
basement levels         0..30
floor-to-floor height   positive integer mm
```

Optional P8 input:

```text
create explicit ground level / level numbering convention
```

The provider produces only canonical structural hierarchy:

```text
Site
└── Building
    ├── Basement levels if requested
    └── Above-ground levels
```

It does not create arbitrary rooms just to make the canvas non-empty.

Level IDs are stable identities. Level numbers/elevations are attributes.

Default deterministic elevation rule:

```text
ground/first authored reference elevation = 0 mm
next above-ground elevation += floorToFloorHeightMm
basement elevation -= floorToFloorHeightMm
```

The exact numbering convention must be normalized before generation and qualification-tested.

## Wizard session state machine

P8 introduces one application-level Wizard session state machine.

Required states:

```text
idle
selectingFamily
editingParameters
generating
selectingVariant
previewReady
previewBlocked
committing
completed
cancelled
failed
```

Not every provider needs `selectingVariant`.

Allowed main flow:

```text
selectingFamily
→ editingParameters
→ generating
→ selectingVariant? 
→ previewReady
→ committing
→ completed
```

Back navigation:

```text
previewReady → editingParameters
selectingVariant → editingParameters
editingParameters → selectingFamily
```

Back navigation never mutates the live project.

### Session contract

Conceptually:

```dart
final class WizardSession<P extends WizardParameters> {
  final WizardTargetContext target;
  final LocalProjectVersion baseVersion;
  final WizardProvider<P> provider;

  P parameters;
  GeneratedWizardCandidate? candidate;
  WizardPreviewModel? preview;
  WizardSessionStatus status;
}
```

The session owns draft UI state only.

## Normalization and deterministic intent key

Before candidate generation, provider parameters are normalized.

Examples:

```text
trim names;
normalize enum/default values;
canonicalize level counts;
canonicalize optional values;
reject impossible ranges;
```

The normalized intent is represented by a deterministic key used by `ReservedProjectCommand.normalizedIntentKey`.

The key must:

- include provider/template/generator version;
- include explicit target identity;
- include normalized semantic parameters;
- exclude newly reserved IDs;
- exclude localized labels not part of semantics;
- exclude transient UI state.

Equivalent normalized inputs must produce the same intent key.

## Candidate model

P8 uses a candidate model that can be validated and projected before commit.

Conceptually:

```dart
final class GeneratedWizardCandidate {
  final WizardCandidateId candidateId;
  final WizardProviderDescriptor provider;
  final WizardCandidateGraph graph;
  final WizardValidationReport validation;
  final WizardPreviewSummary summary;
  final WizardPreviewScene previewScene;
}
```

The candidate graph is not persisted.

For the base provider it may be represented as an immutable Wizard mutation plan that can materialize one `ProjectCommandCandidate` against a known canonical base.

P8 must not add a second full persistent ProjectAggregate type merely for Wizard.

## Identity lifecycle

P8 uses `MutationIdentityReservation` for identities that may become durable.

Lifecycle:

```text
normalize intent
→ reserve all required IDs once
→ build candidate using the reservation
→ preview exact candidate
→ confirm
→ commit frozen preview using same reservation
```

No new ID allocation is allowed between preview and commit.

Reserved IDs are not persistence merely because preview exists. They become durable only if commit succeeds.

Cancel discards the reservation with no project mutation.

## Wizard ReservedProjectCommand

P8 introduces a Wizard command family implementing the existing reserved-command contract.

Conceptually:

```dart
final class ApplyWizardCandidateCommand implements ReservedProjectCommand {
  final WizardMutationPlan plan;
  final WizardTargetContext target;
  final String normalizedIntentKey;
}
```

Responsibilities:

```text
reserveIdentities()
  allocate every new canonical identity required by the plan

validateReservation()
  prove no reserved identity collides with current canonical state
  prove target entities still exist and belong to expected owners

buildCandidate()
  apply the complete Wizard plan to current canonical state
  return one validated ProjectCommandCandidate

semanticOperations()
  describe typed semantic effects for preview/diff
```

The command does not access Flutter, persistence APIs, filesystem APIs or backend services.

## Candidate validation

Validation occurs in layers.

### Layer 1 — Parameter validation

Examples:

```text
empty building name
level count out of supported range
non-positive floor-to-floor height
unsupported provider/target combination
```

### Layer 2 — Provider candidate validation

Provider-specific invariants.

For P8 base Building provider:

```text
unique planned level numbers within building
monotonic deterministic elevations
valid building ownership
no empty structural names after normalization
```

### Layer 3 — Canonical candidate validation

The final `ProjectCommandCandidate` MUST pass existing `CandidateGraphValidator` through `ProjectMutationSession.preview()`.

P8 must not duplicate canonical graph validation in widgets.

### Validation severity

```dart
enum WizardIssueSeverity {
  info,
  warning,
  blocker,
}
```

Only `blocker` prevents preview confirmation.

Warnings are visible and never silently dropped.

## Preview architecture

Preview has three independent but synchronized projections:

```text
A. Summary projection
B. Semantic diff projection
C. Vector/spatial preview projection
```

All are derived from the same frozen candidate.

### A — Summary

Minimum summary fields:

```text
provider/family
building count delta
level count delta
zone count delta
space count delta
warnings/blockers
```

Later providers may add:

```text
area
room count
topology family
engineering counts
```

### B — Semantic diff

The existing `ProjectEntityDiff` is necessary for canonical invalidation/history but is not sufficient as a user-facing diff because it only identifies entity additions/updates/removals.

P8 therefore adds a semantic presentation layer over:

```text
ReservedProjectMutationPreview.semanticChangeSet
ProjectMutationPreview.entityDiff
before canonical snapshot
frozen candidate snapshot
```

Conceptually:

```dart
enum WizardDiffKind {
  add,
  update,
  remove,
  preserve,
  conflict,
}

final class WizardDiffEntry {
  final WizardDiffKind kind;
  final WizardEntityRef entity;
  final WizardEntityRef? owner;
  final List<WizardFieldChange> fields;
}
```

P8 generation normally uses `add`, `update` and `remove`.

`preserve` and `conflict` are reserved in the contract for P15 selective regeneration and may remain unused by base P8 providers.

### Field-level changes

Where an entity is updated, the preview should show meaningful fields rather than only "updated".

Initial typed field categories:

```text
name
displayOrder
levelNumber
levelKind
elevationMm
floorToFloorHeightMm
hierarchyMembership
spaceType
spaceUsage
geometry
boundaryTopology
```

P8 must not implement the authoritative field-aware provenance model early; it only defines typed diff presentation keys compatible with that later work.

### Diff ordering

Diff output must be deterministic.

Default ordering:

```text
Site
Building
Level
StructuralZone
Space
Boundary/Opening
other entities
```

Within one owner/type group:

```text
display order / semantic order
then stable ID as deterministic tie-breaker
```

The same candidate must render the same diff ordering on all supported native platforms.

## Vector and SVG-compatible preview

P8 separates topology semantics from preview rendering.

Authoritative preview data is a small vector scene, not SVG text and not a widget tree.

Conceptually:

```dart
final class WizardPreviewScene {
  final WizardPreviewBounds bounds;
  final List<WizardPreviewPolygon> polygons;
  final List<WizardPreviewSegment> segments;
  final List<WizardPreviewLabel> labels;
  final List<WizardPreviewMarker> markers;
}
```

A deterministic SVG projection may be generated from the scene:

```dart
abstract interface class WizardSvgProjector {
  String project(WizardPreviewScene scene);
}
```

Rules:

- SVG is a projection, never the source of topology truth;
- output ordering and numeric formatting are deterministic;
- no script, external URL, embedded HTML or active content;
- all geometry is derived from normalized integer-mm/domain geometry;
- SVG generation is pure and side-effect free.

### Flutter rendering

P8 should render the same `WizardPreviewScene` natively with `CustomPainter` to avoid making SVG parsing a domain/runtime dependency.

The deterministic SVG string is still generated and snapshot-testable for topology mini-preview interoperability.

If a future UI chooses `flutter_svg`, it must be an adapter over `WizardPreviewScene/WizardSvgProjector`, not a domain dependency.

### P9 apartment preview handoff

P9's apartment engine plugs into this exact flow:

```text
ApartmentWizardParameters
→ ApartmentTopologyCatalog
→ bounded candidate variants
→ WizardPreviewScene per variant
→ deterministic SVG projection
→ user selects variant
→ normal P8 preview/diff/commit
```

P9 does not create another Wizard transaction path.

## Preview UX

Desktop/tablet layout:

```text
┌──────────────────────────────────────────────────────────────┐
│ Wizard: Building                                      [ X ] │
├──────────────────────┬───────────────────────────────────────┤
│ Parameters           │ Preview                               │
│                      │                                       │
│ Building name        │ vector plan / topology                │
│ Floors               │                                       │
│ Basements            │                                       │
│ Height               │                                       │
├──────────────────────┴───────────────────────────────────────┤
│ Changes: +1 building, +5 levels · 0 blockers · 1 warning    │
│ [Back]                         [Cancel] [Apply changes]       │
└──────────────────────────────────────────────────────────────┘
```

Mobile uses a page/step flow rather than forcing a desktop split pane.

### Preview actions

Required:

```text
Back
Regenerate
Cancel
Apply changes
```

Variant providers additionally expose:

```text
Previous variant / Next variant
variant cards
```

Apply is disabled when:

```text
validation has blockers;
preview is stale;
commit is in flight;
provider failed to generate a candidate.
```

## New-project start UX

Recommended production flow:

```text
Project Hub
  ↓
New Project
  ↓
Step 1: project name
  ↓
Step 2: start type
  ├ Apartment
  ├ Cottage
  ├ Building
  ├ Residential complex
  └ Blank
  ↓
provider parameters
  ↓
variant selection if applicable
  ↓
preview + diff
  ↓
confirm
  ↓
open editor at the committed canonical location
```

The first editor screen after confirm must navigate to the created/selected canonical Building/Level using stable IDs.

It must not locate the result by level number, display name or tree index.

## Existing-project Wizard UX

From the Project Navigator:

```text
Wizard
  ↓
provider registry filtered by explicit target
  ↓
parameters
  ↓
preview/diff against current project
  ↓
confirm
  ↓
canonical commit
  ↓
navigator reconciles to resulting target
```

If a provider creates a Building, navigation activates that Building.

If it creates one or more Levels, navigation activates the provider-defined primary Level.

Navigation changes after commit are presentation/application reconciliation and must not create a second project mutation.

## Stale preview behavior

P8 must expose stale state clearly.

Scenario:

```text
Wizard preview created at LocalProjectVersion 12
another action commits version 13
user clicks Apply
```

Required behavior:

```text
commit rejected
Wizard remains open
message: project changed after preview
Apply disabled
[Regenerate preview] offered
```

The system must never silently apply version-12 assumptions to version 13.

Automatic hidden rebase at commit is forbidden in P8.

## Cancel behavior

Cancel from any pre-commit state:

```text
closes Wizard;
discards draft parameters;
discards reserved IDs;
discards candidate/preview;
does not persist;
does not append Undo;
does not change LocalProjectVersion.
```

Qualification compares canonical semantic fingerprint before and after cancel.

## Commit behavior

Confirmation uses the existing reserved mutation coordinator.

Required pipeline:

```text
WizardSession.previewReady
→ verify no blockers
→ ReservedProjectMutationCoordinator.commitPreview()
→ stale/version/session/reservation checks
→ ProjectMutationSession.commit(frozen candidate)
→ CandidateGraphValidator
→ one ProjectChangeSet
→ one UndoRecord
→ canonical persistence owner accepts mutation
→ save/autosave through repository owner
→ reconcile navigator
→ completed
```

The Widget must not call `ProjectRepository` directly.

## Persistence ownership

P8 respects current production ownership boundaries.

The canonical mutation owner/publisher is responsible for accepting committed project state.

Wizard UI must not:

```text
write JSON files;
call Drift directly;
use dart:io;
use path_provider;
open backend HTTP connections.
```

P8 is fully offline-capable.

## Error model

P8 introduces typed Wizard errors where useful.

Conceptually:

```dart
enum WizardFailureCode {
  unsupportedTarget,
  invalidParameters,
  generationFailed,
  candidateInvalid,
  stalePreview,
  foreignPreview,
  consumedReservation,
  commitRejected,
}
```

Domain/application exceptions remain the authoritative low-level cause.

UI maps them to actionable messages without hiding diagnostics.

## Proposed source layout

P8 should keep Wizard application logic near the project application layer and UI under project features.

Target layout:

```text
lib/src/application/project/wizard/
  wizard_parameters.dart
  wizard_provider.dart
  wizard_provider_registry.dart
  wizard_target_context.dart
  wizard_session.dart
  wizard_candidate.dart
  wizard_validation.dart
  wizard_mutation_plan.dart
  wizard_apply_command.dart
  wizard_diff.dart
  wizard_preview_scene.dart
  wizard_svg_projector.dart

lib/src/features/projects/wizard/
  project_start_wizard.dart
  wizard_shell.dart
  wizard_family_step.dart
  wizard_parameters_step.dart
  wizard_variant_step.dart
  wizard_preview_step.dart
  wizard_diff_panel.dart
  wizard_preview_canvas.dart

lib/src/application/project/wizard/providers/
  basic_building_wizard_provider.dart
```

Later phases add providers without changing the shell:

```text
P9  apartment_wizard_provider.dart
P10 cottage_wizard_provider.dart
P10 building_generator_wizard_provider.dart
P10 residential_complex_wizard_provider.dart
```

Exact file names may be adjusted during implementation, but ownership boundaries must remain.

## Integration changes

Expected existing files to change in P8:

```text
lib/src/features/projects/project_hub_screen.dart
  - route New Project through project-start Wizard
  - do not immediately expose compatibility seed as authored structure

lib/src/features/editor/canonical_project_navigator.dart
  - expose Wizard action/callback
  - pass explicit canonical target context

lib/src/features/editor/project_structure_authoring_controls.dart
  - add discoverable Wizard control without embedding mutation logic

lib/src/features/editor/unified_workspace_editor_screen.dart
  - host/open Wizard shell and reconcile navigation after commit

lib/src/features/editor/canonical_editor_production_runtime.dart
  - expose the canonical mutation/session capability required by Wizard
  - preserve persistence ownership boundary
```

P8 must avoid adding Wizard logic to legacy `EditorBuildingWorkspace`.

## Basic provider implementation plan

### Step P8A — contracts

Implement:

```text
WizardParameters
WizardTargetContext
WizardProviderDescriptor
WizardProvider<P>
WizardProviderRegistry
WizardValidationReport
```

Gate:

```text
no Flutter imports in application Wizard contracts
```

### Step P8B — base provider

Implement deterministic structural Building provider.

Gate:

```text
same normalized parameters produce semantically equivalent plan
```

### Step P8C — reserved command bridge

Implement Wizard mutation plan + `ReservedProjectCommand` adapter.

Gate:

```text
preview identity == committed identity
preview fingerprint leaves live project unchanged
```

### Step P8D — semantic diff

Implement deterministic presentation diff derived from reserved semantic changes plus before/candidate state.

Gate:

```text
counts/order/field changes are stable
```

### Step P8E — preview scene/SVG

Implement vector scene and deterministic SVG projector.

Gate:

```text
same candidate produces byte-stable normalized SVG on all supported test platforms
```

Semantic cross-platform correctness remains more important than pixel equality.

### Step P8F — Wizard shell

Implement desktop/tablet/mobile step shell.

Gate:

```text
Back/Cancel never mutate canonical project
Apply disabled on blockers/stale state
```

### Step P8G — entry points

Integrate Project Hub and canonical navigator.

Gate:

```text
Wizard is discoverable from New Project and Project Navigator
```

### Step P8H — hardening

Run full regression and qualification suite.

## Qualification test matrix

P8 requires dedicated tests. Suggested names are normative in intent, not exact filename requirements.

### Contract tests

```text
P8-Q01 provider registry filters by target scope
P8-Q02 normalized parameters are deterministic
P8-Q03 invalid parameters fail before reservation
P8-Q04 target identities are explicit and typed
P8-Q05 no Wizard application contract imports Flutter
```

### Reservation / transaction tests

Existing reserved-mutation tests remain mandatory.

Add:

```text
P8-Q06 Wizard preview reserves all new IDs once
P8-Q07 commit uses exact preview IDs
P8-Q08 commit uses exact frozen candidate
P8-Q09 preview creates no Undo record
P8-Q10 confirm creates exactly one Undo record
P8-Q11 cancel leaves Undo depth unchanged
P8-Q12 stale preview fails closed
P8-Q13 foreign preview fails closed
P8-Q14 consumed reservation cannot commit twice
```

### Fingerprint tests

```text
P8-Q15 open Wizard → cancel = fingerprint unchanged
P8-Q16 edit parameters repeatedly → cancel = fingerprint unchanged
P8-Q17 preview regeneration = live fingerprint unchanged
P8-Q18 failed candidate = fingerprint unchanged
P8-Q19 stale commit attempt = fingerprint unchanged from latest canonical state
```

### Base Building provider tests

```text
P8-Q20 creates one building and one level
P8-Q21 creates multiple above-ground levels
P8-Q22 creates requested basements
P8-Q23 every level has independent stable LevelId
P8-Q24 duplicate planned level numbers are rejected
P8-Q25 elevations are deterministic
P8-Q26 floor-to-floor height must be positive
P8-Q27 building/level hierarchy validates canonically
```

### Diff tests

```text
P8-Q28 add building/levels produces correct semantic summary
P8-Q29 updated seed normalization reports update, not duplicate entity creation
P8-Q30 diff ordering is deterministic
P8-Q31 field-level changes show typed field keys
P8-Q32 entity diff and semantic diff cannot contradict candidate changes
```

### Preview scene/SVG tests

```text
P8-Q33 scene generation is deterministic
P8-Q34 SVG output contains no script/external URLs
P8-Q35 SVG ordering/numeric formatting is deterministic
P8-Q36 empty/non-spatial structural candidate still renders a valid hierarchy preview
```

### Widget tests

```text
P8-Q37 New Project opens Wizard start flow
P8-Q38 provider tiles reflect registry availability
P8-Q39 Back does not commit
P8-Q40 Cancel does not commit
P8-Q41 blocker disables Apply
P8-Q42 Apply enters busy state and prevents double commit
P8-Q43 stale preview shows regenerate action
P8-Q44 successful commit closes Wizard and updates navigator
P8-Q45 mobile layout has no desktop-only overflow
```

### Persistence integration tests

```text
P8-Q46 committed Wizard result survives save/reopen
P8-Q47 semantic fingerprint survives save/reopen
P8-Q48 cancel performs no repository save caused by Wizard
```

### Regression gates

At minimum:

```text
flutter analyze
flutter test
existing P3 mutation tests
existing reserved mutation lifecycle tests
existing P5C navigator/authoring tests
existing P6/P7 qualification suites
```

P8 must not weaken earlier gates to make Wizard tests pass.

## UX acceptance criteria

P8 is not complete unless all of the following are true.

```text
AC-01 New Project exposes Wizard as the primary structured start path.
AC-02 User is not forced to discover a small bottom +Building button to begin.
AC-03 Project Navigator still supports direct +Building/+Level/+Room expert actions.
AC-04 Wizard is available from the Project Navigator.
AC-05 Wizard shows only providers valid for current target.
AC-06 Parameter errors are visible before preview.
AC-07 Preview visibly summarizes what will be created/changed/removed.
AC-08 Preview has a spatial/vector view when provider supplies geometry.
AC-09 Apartment provider can later supply SVG topology mini-previews without shell changes.
AC-10 Cancel is safe and immediate.
AC-11 Apply is explicit; no auto-commit when changing a parameter or selecting a variant.
AC-12 Stale preview cannot overwrite a newer project version.
AC-13 One confirmed Wizard action is one Undo action.
AC-14 After commit, user lands in the created canonical context.
```

## Determinism requirements

P8 deterministic outputs include:

```text
normalized intent key
provider candidate semantic structure
semantic diff ordering
summary counts
preview scene primitive ordering
normalized SVG output
```

The following are explicitly non-deterministic and must not affect semantic equality:

```text
fresh UUID values allocated by EntityIdFactory
wall-clock timestamps not under semantic test
Flutter paint rasterization details
platform font rasterization
```

Tests compare normalized semantic forms where UUID values are intentionally fresh.

## Performance requirements

P8 must avoid full-project work on every text-field keystroke.

Rules:

- parameter edits update draft state immediately;
- candidate regeneration is explicit or debounced;
- old generation results are ignored if superseded by a newer draft revision;
- diff/preview works from indexed canonical state and one candidate, not repeated deep persistence round-trips;
- UI never writes repository state during preview;
- expensive future providers may move generation to an isolate without changing application contracts.

The first P8 base provider should remain synchronous because its structural plan is small and deterministic.

## Accessibility and interaction

Wizard controls must be keyboard reachable on desktop.

Required semantics:

```text
clear labels for Back/Cancel/Apply
focus order follows visible step order
validation messages are textual, not color-only
selected variant has non-color indication
busy state prevents duplicate apply
Escape may close only when not committing and after normal cancel handling
```

## Security/safety of preview markup

Generated SVG is internal deterministic markup.

P8 MUST NOT accept arbitrary SVG/HTML from provider user input.

If SVG text is displayed by an adapter:

```text
no scripts
no event handlers
no foreignObject
no external href/src
no network-loaded assets
no embedded executable content
```

## P9 apartment handoff contract

P9 implementation must be able to arrive without changing P8 transaction semantics.

Required integration:

```text
ApartmentWizardProvider implements WizardProvider<ApartmentWizardParameters>
ApartmentTopologyCatalog returns bounded variants
variant owns semantic topology + WizardPreviewScene
WizardSvgProjector creates deterministic SVG mini-preview
selected variant becomes Wizard mutation plan
P8 ReservedProjectMutationCoordinator previews/commits it
```

P9 owns:

```text
1..10 habitable-room generation
topology family compatibility
area fitting
adjacency grammar
variant scoring
apartment candidate geometry
```

P8 owns:

```text
Wizard shell
target context
provider registration
session/state machine
validation presentation
preview lifecycle
semantic diff
vector/SVG projection contract
atomic commit
stale handling
cancel semantics
```

This separation is mandatory.

## Definition of Done

P8 may be considered complete only when:

```text
1. Wizard contracts are typed and implemented.
2. Provider registry is implemented.
3. Base Building provider produces deterministic canonical candidates.
4. Wizard uses ReservedProjectMutationCoordinator for preview/apply.
5. Preview does not mutate live project.
6. User-facing semantic diff exists and is deterministic.
7. Vector preview scene + deterministic SVG projection exist.
8. New Project starts through Wizard/Blank choice instead of silently presenting a fake authored hierarchy.
9. Canonical Project Navigator exposes Wizard.
10. Stale preview is visible and fail-closed.
11. One confirm = one ProjectChangeSet = one Undo.
12. Cancel/failure preserve canonical semantic fingerprint.
13. Save/reopen preserves committed Wizard result.
14. P9 can register Apartment provider without modifying P8 core contracts.
15. flutter analyze and full regression tests pass.
```

## Non-negotiable implementation conclusion

P8 is not "a set of dialogs".

It is the canonical preview/apply authoring protocol for all future deterministic project generation in ElecX.

The implementation direction is:

```text
Typed Wizard Provider
        ↓
Normalized intent
        ↓
ReservedProjectCommand
        ↓
MutationIdentityReservation
        ↓
Frozen canonical candidate
        ↓
Validation + semantic diff + vector/SVG preview
        ↓
Explicit user confirmation
        ↓
ReservedProjectMutationCoordinator.commitPreview()
        ↓
ProjectMutationSession
        ↓
one ProjectChangeSet + one Undo
        ↓
canonical persistence owner
```

Never:

```text
Wizard widget
→ mutate EditorBuildingWorkspace directly
→ regenerate different IDs at commit
→ create several structural commits for one Wizard confirmation
→ infer target from labels/level numbers
→ persist preview state
→ hide stale-version conflicts
```
