# P8 Wizard + Preview/Diff Development Roadmap v1

## Status

Authoritative delivery roadmap for `feat/p8-wizard-preview-diff`.

This roadmap operationalizes:

- `docs/architecture/project-composition-foundation-decisions-v1.md`;
- `docs/architecture/project-template-wizard-v1.md`;
- `docs/architecture/project-composition-generation-v1.md`;
- `docs/architecture/p8-wizard-preview-diff-implementation-v1.md`;
- `docs/architecture/p8-wizard-responsive-carousel-ux-v1.md`;
- `docs/architecture/apartment-topology-catalog-v1.md`.

If this roadmap conflicts with the foundation decisions, the foundation decisions win.

P8 is complete only when its typed Wizard framework, candidate lifecycle, semantic diff, responsive preview shell, base structural provider, integration and qualification gates all pass together. A visually working Wizard that bypasses the canonical mutation lifecycle is not P8-complete.

---

# 1. North-star result

P8 must leave ElecX with one reusable Wizard platform that later P9/P10/P12 generators can plug into without changing transaction, preview, diff, responsive or commit architecture.

The user-visible end state is:

```text
Project Hub / existing Project Navigator
        ↓
Wizard entry
        ↓
provider selection
        ↓
typed parameters
        ↓
deterministic candidate generation
        ↓
optional candidate carousel
        ↓
large vector preview
        ↓
semantic diff + warnings
        ↓
Apply
        ↓
exact frozen candidate commit
        ↓
1 ProjectChangeSet
        ↓
1 Undo record
        ↓
canonical persistence + navigator activation
```

The architectural end state is:

```text
Flutter presentation
    ↓
WizardSessionController
    ↓
WizardProviderRegistry
    ↓
WizardProvider<P>
    ↓
GeneratedWizardCandidate / WizardMutationPlan
    ↓
ApplyWizardCandidateCommand : ReservedProjectCommand
    ↓
ReservedProjectMutationCoordinator
    ↓
ProjectMutationSession
    ↓
ProjectAggregateRoot
    ↓
Canonical persistence owner
```

P8 must not introduce:

```text
second project model
second transaction engine
widget-side project mutation
preview-side persistence
platform-specific project semantics
browser/WebView SVG dependency
provider-specific commit paths
raw index-based candidate identity
```

---

# 2. P8 / P9 / P10 boundary

The boundary is strict.

## P8 owns

```text
Wizard shell
Wizard state machine
Wizard target context
provider registry
provider descriptor contract
typed parameter root contract
parameter validation protocol
candidate lifecycle
variant-selection protocol
reserved identity lifecycle
semantic diff infrastructure
preview summary
vector preview scene
SVG-compatible projection contract
responsive layout system
candidate carousel component
preview/zoom interaction
atomic apply
stale preview handling
cancel/back invariants
Project Hub integration
Project Navigator integration
base Building Wizard provider
qualification harness
```

## P9 owns

```text
ApartmentWizardParameters production implementation
ApartmentTopologyCatalog
apartment family grammars
1..10 habitable-room generation
area fitting
adjacency rules
wet-core policies
candidate scoring/ranking
3..6 apartment candidate generation
apartment-specific WizardPreviewScene population
```

## P10 owns

```text
Cottage provider
advanced Building provider
Residential Complex provider
typical-floor generation
advanced vertical-core generation
```

P9/P10 providers must plug into P8 through the same provider and candidate contracts.

---

# 3. Hard prerequisites

Before implementation is considered safe, the following existing capabilities are treated as mandatory foundation rather than optional helpers.

```text
F-01 ProjectAggregateRoot is canonical ownership boundary
F-02 stable typed EntityId family exists
F-03 LocalProjectVersion guards mutation
F-04 CandidateGraphValidator is canonical validation gate
F-05 ProjectMutationSession.preview() is side-effect free
F-06 ProjectMutationSession.commit() is atomic
F-07 Undo/Redo already operates over canonical mutation state
F-08 ReservedProjectMutationCoordinator exists
F-09 MutationIdentityReservation exists
F-10 frozen preview commit semantics exist
F-11 canonical Project Navigator uses ID-backed context
F-12 canonical persistence owner can accept canonical mutation result
```

P8 must reuse these capabilities and add tests proving their composition with Wizard.

---

# 4. Master dependency graph

```text
P8.0 Specification freeze + readiness audit
  │
  ├───────────────┐
  ▼               ▼
P8.1 Contracts   P8.2 Responsive primitives
  │               │
  ▼               │
P8.3 Provider registry
  │               │
  ├───────┐       │
  ▼       ▼       │
P8.4 Base provider│
  │       │       │
  ▼       ▼       ▼
P8.5 Candidate + reservation lifecycle
  │
  ├───────────────┬───────────────────┐
  ▼               ▼                   ▼
P8.6 Semantic diff P8.7 Preview scene P8.8 Wizard state machine
  │               │                   │
  └───────┬───────┴───────────┬───────┘
          ▼                   ▼
     P8.9 Responsive shell   P8.10 Integration
          │                   │
          └─────────┬─────────┘
                    ▼
              P8.11 Hardening
                    │
                    ▼
              P8.12 Qualification
                    │
                    ▼
               P8 → P9 gate
```

The critical path is:

```text
contracts
→ provider registry
→ base provider
→ reserved candidate lifecycle
→ semantic preview/diff
→ Wizard controller
→ integration
→ qualification
```

Responsive primitives and vector-preview infrastructure may be developed in parallel after the contracts are frozen.

---

# 5. Workstreams

P8 is split into coordinated workstreams rather than isolated screens.

```text
WS-A  Wizard contracts and typed target context
WS-B  Provider registry and capability discovery
WS-C  Base structural Building provider
WS-D  Candidate/reservation/commit lifecycle
WS-E  Semantic diff model and projector
WS-F  Vector preview + deterministic SVG projection
WS-G  Wizard session state machine
WS-H  Responsive shell and adaptive layout
WS-I  Apartment candidate carousel infrastructure
WS-J  Project Hub / Navigator integration
WS-K  Persistence, navigation and commit publication
WS-L  Accessibility + input modalities
WS-M  Performance + caching + telemetry hooks
WS-N  Qualification + regression + P9 handoff
```

No workstream may create its own alternative canonical state.

---

# 6. P8.0 — Specification freeze and readiness audit

## Goal

Convert current design documents into implementable invariants and prove that P8 does not depend on missing lower-layer architecture.

## Tasks

```text
P8.0.1 enumerate all P8 invariants
P8.0.2 map each invariant to owning code layer
P8.0.3 map each invariant to at least one qualification test
P8.0.4 verify ReservedProjectMutationCoordinator is sufficient for Wizard
P8.0.5 verify canonical persistence callback path
P8.0.6 verify Project Navigator can receive explicit post-commit location
P8.0.7 identify transitional legacy blank-project seed behavior
P8.0.8 record P8/P9/P10 boundaries
P8.0.9 freeze naming for public P8 contracts before UI implementation
```

## Deliverables

```text
p8-development-roadmap-v1.md
p8-wizard-preview-diff-implementation-v1.md
p8-wizard-responsive-carousel-ux-v1.md
```

## Exit gate P8-G00

```text
all P8 responsibilities have one owner
no unresolved second-state / second-transaction design
P8/P9 boundary explicit
legacy blank seed explicitly transitional
```

---

# 7. P8.1 — Typed Wizard contracts

## Goal

Create a stable application-layer API that all later Wizard providers use.

## Target package

```text
lib/src/application/project/wizard/
```

Recommended files:

```text
wizard_parameters.dart
wizard_family.dart
wizard_target_context.dart
wizard_provider.dart
wizard_provider_descriptor.dart
wizard_provider_registry.dart
wizard_validation.dart
wizard_candidate.dart
wizard_candidate_id.dart
wizard_preview_summary.dart
wizard_mutation_plan.dart
wizard_errors.dart
```

## Core contracts

### WizardParameters

```dart
sealed class WizardParameters {
  const WizardParameters();
}
```

No authoritative untyped parameter map.

### WizardTargetContext

```text
NewProjectWizardTarget
SiteWizardTarget
BuildingWizardTarget
LevelWizardTarget
```

Each target carries:

```text
ProjectId
SiteId
LocalProjectVersion
optional BuildingId
optional LevelId
```

No target lookup from labels, tree indexes or display numbers.

### WizardProviderDescriptor

Must include stable machine-facing metadata:

```text
templateId
templateVersion
generatorVersion
familyId
displayName / localization key
supported scopes
supports variants
preview capabilities
```

### WizardProvider<P>

Minimum responsibilities:

```text
defaultsFor(target)
normalize(parameters, target)
validateParameters(parameters, target)
generate(parameters, generationContext)
```

Generation is deterministic for normalized semantic inputs.

## Error model

Introduce typed Wizard-level failures:

```text
unsupportedTarget
invalidParameters
generationFailed
noValidCandidate
candidateBlocked
staleCandidate
foreignPreview
previewConsumed
commitFailed
persistenceFailed
```

Do not surface raw `StateError` as primary UI contract.

## Tests

```text
wizard_target_context_test.dart
wizard_provider_descriptor_test.dart
wizard_parameter_normalization_test.dart
wizard_validation_test.dart
```

## Exit gate P8-G01

```text
contracts compile without Flutter imports
contracts compile without persistence imports
all target identities typed
provider API supports future Apartment/Cottage/Building/RC providers
normalization deterministic
```

---

# 8. P8.2 — Responsive presentation primitives

## Goal

Build reusable adaptive layout rules before implementing a concrete Wizard screen.

## Target package

```text
lib/src/features/wizard/presentation/
```

Recommended files:

```text
wizard_breakpoints.dart
wizard_layout_class.dart
wizard_responsive_scope.dart
wizard_scaffold.dart
wizard_action_bar.dart
wizard_progress_header.dart
wizard_panel.dart
wizard_safe_area.dart
```

## Width classes

```text
compact   < 600
medium    600..899
expanded  900..1399
wide      >= 1400
```

The width is based on actual Wizard constraints, not device name or OS.

## Required behavior

```text
window resize preserves session
orientation change preserves session
split-screen preserves session
no platform-specific semantic branching
sticky primary actions on compact/medium
collapsible inspectors on expanded/wide
no horizontal page overflow
```

## Tests

Widget tests at representative sizes:

```text
390x844
844x390
768x1024
1024x768
1280x800
1440x900
1920x1080
```

## Exit gate P8-G02

```text
responsive shell primitives work independently of any provider
no Wizard session recreation on reflow
safe areas and software keyboard accounted for
```

---

# 9. P8.3 — Provider registry and capability discovery

## Goal

Decouple Wizard shell from hard-coded families.

## Contract

```text
WizardProviderRegistry
  register(provider)
  providersFor(target)
  descriptorFor(familyId)
  capabilitySnapshot(target)
```

Production UI must render only providers available for the explicit target.

## Rules

```text
no dead Apartment button before P9 provider exists
no dead Cottage/RC button before P10
provider order deterministic
provider IDs stable
registry contains no Flutter widgets
```

## Suggested initial provider set

```text
BasicBuildingWizardProvider   → P8
Blank/manual path             → shell action, not generator
Apartment provider            → absent until P9
Cottage provider              → absent until P10
Residential complex           → absent until P10
```

## Tests

```text
wizard_provider_registry_test.dart
wizard_provider_capability_test.dart
```

## Exit gate P8-G03

```text
registry can discover providers by target scope
UI needs no family-specific switch statement
future P9 provider can register without shell changes
```

---

# 10. P8.4 — Basic Building Wizard provider

## Goal

Deliver one real production provider proving end-to-end P8 without pulling P10 into scope.

## Parameters

```text
buildingName
aboveGroundLevelCount
basementLevelCount
floorToFloorHeightMm
level numbering convention
optional explicit ground level mode
```

## Constraints

Recommended v1 baseline:

```text
building name non-empty after trim
above-ground levels 1..200
basements 0..30
floor-to-floor height > 0
level numbers unique per building
planned elevations deterministic
```

## Output

```text
WizardMutationPlan
├── create/reuse Building
└── create planned Levels
```

No arbitrary rooms are generated.

## Important design decision

The provider does not sequentially call existing `createBuilding()` then `createLevel()` N times because that would create N+1 independent undo records and expose partial state.

Instead it must materialize one composite reserved canonical mutation candidate.

## Identity reservation slots

Conceptual slots:

```text
building
level:basement:1
level:basement:2
level:above:1
level:above:2
...
```

Slot names are deterministic semantic generation slots, not persistence IDs.

## Tests

```text
basic_building_wizard_parameters_test.dart
basic_building_wizard_provider_test.dart
basic_building_wizard_plan_test.dart
basic_building_wizard_identity_reservation_test.dart
```

## Exit gate P8-G04

```text
provider generates deterministic hierarchy plan
all permanent IDs reserved exactly once
one provider operation can be applied as one canonical mutation
no room/apartment semantics invented
```

---

# 11. P8.5 — Candidate + reserved preview/apply lifecycle

## Goal

Bind Wizard candidate generation to the existing reserved mutation protocol.

## Main application service

Recommended:

```text
WizardCandidateCoordinator
```

Responsibilities:

```text
normalize typed parameters
validate parameters
ask provider to create mutation plan
construct ApplyWizardCandidateCommand
invoke ReservedProjectMutationCoordinator.preview()
freeze candidate
create WizardCandidateId
build summary
build semantic diff input
return WizardPreparedCandidate
```

## ApplyWizardCandidateCommand

Implements:

```text
ReservedProjectCommand
```

Required behavior:

```text
normalizedIntentKey deterministic
reserveIdentities() complete
validateReservation() fail closed
buildCandidate() pure over current + reservation
semanticOperations() complete enough for user diff projection
```

## Frozen candidate rule

The exact `ReservedProjectMutationPreview` produced for the selected candidate is what `Apply` commits.

No regeneration between:

```text
previewReady → Apply
```

## Stale behavior

If LocalProjectVersion changes:

```text
Apply disabled
status → previewBlocked
user sees "Project changed; refresh preview"
user may regenerate/rebase candidate
old reservation remains uncommitted and discarded
```

Never silently recompute and commit a different candidate.

## Tests

```text
wizard_candidate_coordinator_test.dart
wizard_reserved_preview_test.dart
wizard_stale_preview_test.dart
wizard_double_apply_test.dart
wizard_cancel_fingerprint_test.dart
```

## Exit gate P8-G05

```text
preview creates no mutation
preview creates no undo
commit uses exact reserved IDs
commit uses exact frozen candidate
stale commit blocked
one successful apply = one undo record
```

---

# 12. P8.6 — Semantic diff engine

## Goal

Turn low-level entity diff into a professional user-facing semantic change model.

## Target package

```text
lib/src/application/project/wizard/diff/
```

Recommended files:

```text
wizard_diff.dart
wizard_diff_entry.dart
wizard_field_change.dart
wizard_diff_engine.dart
wizard_diff_sort.dart
wizard_diff_summary.dart
wizard_entity_presenter.dart
```

## Model

```text
WizardDiff
├── added
├── updated
├── removed
├── preserved
├── conflicts
└── summary
```

Initial P8 kinds:

```text
ADD
UPDATE
REMOVE
```

`PRESERVE` and `CONFLICT` are included in the public model now because P15 selective regeneration will need them.

## Field-level changes

At minimum support typed keys for:

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

Do not expose arbitrary JSON paths as primary user diff.

## Sorting

Stable semantic order:

```text
Site
Building
Level
Zone
Space
Opening
Boundary
VerticalCore
Engineering entities later
```

Within owner:

```text
add
update
remove
then stable identity/display order tie-break
```

## Diff UX requirements

Compact:

```text
summary first
expandable grouped changes
```

Wide:

```text
persistent/collapsible right inspector
```

## Tests

```text
wizard_diff_engine_test.dart
wizard_diff_sort_test.dart
wizard_diff_field_change_test.dart
wizard_diff_summary_test.dart
```

Golden semantic fixtures should compare structured diff, not localized display text only.

## Exit gate P8-G06

```text
user can understand exactly what Apply changes
ordering deterministic
same candidate yields same structured diff
low-level EntityId diff is not directly dumped into UI
```

---

# 13. P8.7 — Vector preview scene + SVG projection

## Goal

Create one rendering-neutral spatial preview model usable by Flutter cards, large preview and deterministic SVG serialization.

## Target package

```text
lib/src/application/project/wizard/preview/
lib/src/features/wizard/preview/
```

## Application model

```text
WizardPreviewScene
├── bounds
├── polygons
├── polylines
├── lines
├── labels
├── markers
└── metadata
```

Primitive identities should be stable within one candidate scene when practical.

## Coordinate policy

Semantic geometry remains integer-mm based.

Presentation applies:

```text
fit-to-bounds
padding
viewport transform
zoom/pan
```

Zoom/pan never modifies semantic geometry.

## SVG serializer

Optional but specified:

```text
WizardSvgProjector
```

Requirements:

```text
deterministic viewBox
no JavaScript
no external URLs
no WebView requirement
no remote fonts
stable primitive order
escaped labels
same scene → semantically equivalent SVG
```

## Flutter renderer

Use native Flutter vector rendering / `CustomPainter` for runtime.

Do not require parsing serialized SVG just to draw an internally generated candidate.

## Preview density levels

```text
thumbnail
card
large
```

All derive from the same scene; smaller levels may suppress nonessential labels but never alter topology.

## Tests

```text
wizard_preview_scene_test.dart
wizard_preview_transform_test.dart
wizard_svg_projector_test.dart
wizard_preview_painter_test.dart
```

## Exit gate P8-G07

```text
preview independent from canonical editor canvas
same candidate drives card + large preview + optional SVG
vector rendering deterministic
```

---

# 14. P8.8 — Wizard session state machine

## Goal

Move all Wizard workflow semantics out of ad-hoc widget callbacks.

## Target package

```text
lib/src/application/project/wizard/session/
```

Recommended files:

```text
wizard_session_state.dart
wizard_session_event.dart
wizard_session_controller.dart
wizard_session_snapshot.dart
wizard_session_transition.dart
```

## Required states

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

## Main events

```text
start
selectProvider
updateParameters
validate
requestGeneration
generationSucceeded
generationFailed
selectCandidate
openPreview
back
cancel
refreshPreview
apply
commitSucceeded
commitFailed
```

## Transition invariants

Examples:

```text
Apply allowed only from previewReady
Apply impossible with blocker issues
selectCandidate requires candidate from current generation set
back never mutates canonical state
cancel never commits
resize/orientation is not a session transition
stale canonical version forces previewBlocked
completed cannot Apply again
```

## State ownership

Session owns:

```text
provider selection
parameter draft
validation report
candidate set
selected WizardCandidateId
prepared reserved preview
semantic diff
preview scene
status/errors
```

Presentation owns:

```text
hover
focus
scroll offset
panel collapse state
zoom/pan
animation controllers
```

Do not mix these boundaries.

## Tests

State-machine tests should enumerate allowed and forbidden transitions.

```text
wizard_session_controller_test.dart
wizard_session_transition_test.dart
wizard_session_stale_test.dart
wizard_session_cancel_test.dart
```

## Exit gate P8-G08

```text
workflow reproducible without Flutter widget test
illegal transitions fail predictably
presentation reflow cannot regenerate session
```

---

# 15. P8.9 — Responsive Wizard shell

## Goal

Build one native shell that adapts from phone to large desktop without separate business flows.

## Target components

```text
WizardScreen
WizardScaffold
WizardProgressHeader
WizardFamilySelector
WizardParameterForm
WizardValidationPanel
WizardCandidateWorkspace
WizardPreviewPanel
WizardDiffPanel
WizardActionBar
```

## Compact layout

```text
header/progress
current step
full-width content
sticky Back / Continue / Apply
```

## Medium layout

```text
full-width or two-column parameter groups
carousel/preview prioritized
sticky action bar
```

## Expanded layout

```text
parameter rail | preview workspace
               | carousel / summary
collapsible diff
```

## Wide layout

```text
parameters | large preview | diff/details
           | carousel      |
```

## No-dialog rule

Ordinary candidate switching and preview inspection on expanded/wide surfaces should not require nested modal dialogs.

## Form ergonomics

```text
numeric fields use appropriate keyboard/input formatter
units shown explicitly
validation adjacent to field
reasonable defaults
advanced options collapsed by default
no mandatory field hidden below inaccessible keyboard
```

## Exit gate P8-G09

```text
single shell supports all width classes
same session survives live resize
no desktop-only business flow
no mobile-only business flow
```

---

# 16. P8.9A — Candidate carousel infrastructure

## Goal

Implement a reusable carousel now, even though apartment content arrives in P9.

The component is provider-neutral.

Recommended widget:

```text
WizardCandidateCarousel
```

Inputs:

```text
candidate IDs
preview scene per candidate
candidate summary metadata
selectedCandidateId
onCandidateSelected
semantics builder
```

## Behavior

```text
horizontal navigation
snap-to-candidate
stable selected candidate
neighbor context visible
programmatic selection support
keyboard navigation
trackpad support
mouse support
touch support
screen-reader semantics
```

## Density

```text
compact   ~1.1..1.2 cards
medium    ~1.35..2.2
expanded  ~2.2..3.4
wide      ~3..5
```

These are behavioral targets, not persisted values.

## Selection semantics

Candidate identity is `WizardCandidateId`.

Never use scroll page index as the authoritative selection identity.

## Performance

```text
pre-cache selected + immediate neighbors
reuse immutable preview scenes
no generation during scroll frame
no ProjectAggregate rebuild during swipe
avoid whole-shell rebuild on hover
```

## Tests

```text
wizard_candidate_carousel_test.dart
wizard_candidate_carousel_keyboard_test.dart
wizard_candidate_carousel_semantics_test.dart
wizard_candidate_carousel_resize_test.dart
```

## Exit gate P8-G09A

```text
3..6 mock candidates usable on phone/tablet/desktop
snap deterministic
selection preserved on resize
mouse/touch/keyboard all supported
```

This gate is the direct UI handoff point for P9 apartment candidates.

---

# 17. P8.10 — New Project integration

## Goal

Make Wizard the discoverable primary creation path without allowing legacy seed behavior to leak into product semantics.

## Current constraint

Legacy `createInitialEditorProjectDocument()` creates a blank workspace containing a compatibility Building + Level 1.

P8 does not pretend this is user-authored structure.

## Target UX

```text
New Project
    ↓
start surface
    ├── Create with Wizard
    └── Start blank
```

`Create with Wizard` launches the Wizard before presenting compatibility seed structure as user-created project content.

## Transitional strategy

Until a site-only legacy document is supported:

```text
legacy seed may exist internally
seed hidden behind startup gate
Wizard candidate must explicitly normalize/reuse/replace seed
candidate diff must not misleadingly count seed as user-created Wizard output
Cancel preserves original canonical fingerprint
no provider may depend on legacy seed IDs
```

## Persistence rule

Do not save preview candidate merely because the user opened Wizard.

Save only after successful canonical commit through the existing persistence owner workflow.

## Tests

```text
project_hub_wizard_entry_test.dart
new_project_wizard_cancel_test.dart
new_project_wizard_apply_test.dart
new_project_legacy_seed_compatibility_test.dart
```

## Exit gate P8-G10A

```text
user can create project through Wizard
cancel does not produce Wizard-authored structure
legacy seed not exposed as real authored result
```

---

# 18. P8.10B — Project Navigator integration

## Goal

Expose Wizard as a contextual authoring accelerator alongside manual `+Building / +Level / +Room` controls.

## UI

Add a discoverable action:

```text
Wizard
```

Provider availability uses current explicit canonical context.

Examples:

```text
Site context       → Basic Building provider
Building context   → later P10/P9 insert providers as supported
Level context      → later apartment/room generators as supported
```

## Important rule

The Navigator captures the target IDs when the Wizard opens.

If active navigation changes elsewhere while Wizard is open, the original Wizard target remains explicit; stale target/version checks protect commit.

Never silently retarget an open Wizard to a newly selected navigator node.

## Post-commit navigation

After successful Apply:

```text
activate created/relevant Building
activate preferred created Level when applicable
clear invalid previous selection
reveal canonical tree node
```

Navigation changes after commit are projection state; they do not create another project mutation.

## Tests

```text
canonical_project_navigator_wizard_entry_test.dart
wizard_explicit_target_test.dart
wizard_post_commit_navigation_test.dart
```

## Exit gate P8-G10B

```text
Wizard target explicit and stable
manual authoring controls remain functional
successful Wizard apply updates navigator coherently
```

---

# 19. P8.10C — Persistence and commit publication

## Goal

Ensure Wizard uses the same production ownership and persistence pipeline as other canonical authoring.

## Required sequence

```text
Wizard Apply
→ ReservedProjectMutationCoordinator.commitPreview()
→ ProjectMutationResult
→ canonical owner accepts mutation
→ feature hook / publication
→ repository/autosave path
→ UI completion
```

## Failure boundaries

### Commit fails before canonical mutation

```text
live state unchanged
Wizard remains recoverable
```

### Canonical mutation commits but persistence callback fails

Must follow the existing canonical owner failure/recovery policy. P8 must not invent a second rollback protocol.

### Double Apply

Second Apply must be disabled or rejected by consumed reservation/session state.

## Tests

```text
wizard_persistence_owner_integration_test.dart
wizard_commit_publication_test.dart
wizard_double_apply_integration_test.dart
```

## Exit gate P8-G10C

```text
Wizard commit acknowledged by canonical persistence owner
no special Wizard persistence path
```

---

# 20. P8.11 — Error, recovery and conflict UX

## Goal

Make failure behavior explicit and non-destructive.

## Error groups

```text
parameter errors
candidate-generation errors
validation blockers
warnings
stale preview
missing/changed target
reserved identity conflict
commit failure
persistence failure
unexpected internal failure
```

## User-visible stale flow

```text
Project changed while this preview was open.
[Refresh preview]
[Back to parameters]
[Cancel]
```

No "Apply anyway" option.

## Blocker flow

Candidate remains inspectable but Apply disabled.

## Warning flow

Candidate may be applied only where warning is explicitly non-blocking.

## Internal errors

Log/report with enough typed context for diagnostics:

```text
provider ID
template version
generator version
Wizard state
base LocalProjectVersion
target IDs
candidate ID
```

Do not log private project data unnecessarily.

## Exit gate P8-G11A

```text
all known failure classes map to deterministic Wizard behavior
no error path silently mutates project
```

---

# 21. P8.11B — Accessibility and input modalities

## Goal

Make the same Wizard usable through touch, pointer, keyboard and assistive technologies.

## Touch

```text
48x48 logical minimum primary targets
horizontal carousel swipe
safe vertical/horizontal gesture arbitration
pinch/pan in enlarged preview
```

## Mouse/trackpad

```text
click candidate
trackpad horizontal scroll
optional arrow controls
pointer hover non-essential
```

## Keyboard

```text
Tab logical focus order
Left/Right candidate navigation
Home/End first/last
Enter/Space select
Esc/back behavior only where consistent with shell
```

## Semantics

Each candidate card is one semantic item.

Do not expose every SVG/vector primitive as accessibility nodes.

Candidate semantics derive from typed metadata.

## Text scaling

Qualification must include enlarged text without clipping Apply/Back or hiding blockers.

## Exit gate P8-G11B

```text
complete primary flow possible touch-only
complete primary flow possible keyboard/pointer-only
selected state not color-only
```

---

# 22. P8.11C — Performance and rebuild discipline

## Goal

Keep P8 smooth on mobile/tablet and efficient on desktop.

## Rules

```text
parameter edits do not mutate canonical aggregate
carousel frame does not regenerate candidates
candidate scene cached per candidate
large preview reuses scene
hover does not rebuild provider generation
resize reflows without regeneration
semantic diff computed once per frozen preview unless candidate changes
```

## Performance boundaries

Current P9 target is 3..6 apartment candidates, so all lightweight scenes may stay resident.

Architecture must still support future bounded larger sets through lazy card rendering.

## Instrumentable points

Without coupling domain to telemetry, UI/application may expose timings for:

```text
parameter validation
generation
candidate canonical preview
semantic diff projection
preview scene creation
first card paint
Apply commit
```

These hooks must not alter semantics.

## Exit gate P8-G11C

```text
no obvious jank in candidate browsing
no project regeneration during scroll
no session recreation on resize
```

---

# 23. P8.12 — Qualification strategy

## Goal

Prove P8 as an architectural subsystem, not merely as a working happy path.

Qualification is split into six layers.

## Q1 — Pure contracts

```text
typed target identity
provider descriptor
parameter normalization
validation severity
candidate IDs
```

## Q2 — Candidate lifecycle

```text
preview side-effect free
reserved IDs stable
exact frozen candidate commit
stale version blocked
double apply blocked
cancel fingerprint unchanged
```

## Q3 — Semantic diff

```text
add/update/remove grouping
field-level changes
stable ordering
summary counts
```

## Q4 — Presentation

```text
responsive breakpoints
no overflow
sticky actions
carousel snap
selection persistence
zoom/pan isolation
```

## Q5 — Integration

```text
Project Hub → Wizard → Apply
Navigator → Wizard → Apply
canonical persistence acceptance
post-commit navigation
Undo one-step reversal
Redo one-step restoration
save/reopen semantic fingerprint
```

## Q6 — Native platform compatibility

Required semantic qualification targets:

```text
Windows
macOS
Linux
Android
iOS
iPadOS
```

Not every CI environment must visually golden-test every OS, but project semantics must remain platform-independent.

---

# 24. Mandatory qualification scenarios

The following are P8 release gates.

## Lifecycle

```text
P8-Q001 open Wizard → canonical version unchanged
P8-Q002 edit parameters → canonical fingerprint unchanged
P8-Q003 generate preview → canonical version unchanged
P8-Q004 switch candidate → canonical version unchanged
P8-Q005 Back → canonical fingerprint unchanged
P8-Q006 Cancel → canonical fingerprint unchanged
P8-Q007 Apply → version advances exactly once
P8-Q008 Apply → Undo depth increases exactly once
P8-Q009 Undo reverses whole Wizard operation in one step
P8-Q010 Redo restores whole Wizard operation in one step
P8-Q011 old preview rejected after unrelated canonical mutation
P8-Q012 consumed preview cannot apply twice
P8-Q013 preview reserved IDs equal committed IDs
```

## Base Building provider

```text
P8-Q020 1 above-ground level generates valid candidate
P8-Q021 200 above-ground levels handled within supported contract
P8-Q022 zero basements valid
P8-Q023 configured basements have deterministic negative elevations
P8-Q024 duplicate planned level numbers rejected
P8-Q025 invalid floor height blocked
P8-Q026 blank building name blocked
P8-Q027 resulting hierarchy passes CandidateGraphValidator
```

## Diff

```text
P8-Q030 added building visible in semantic diff
P8-Q031 added levels grouped below building
P8-Q032 field changes show before/after
P8-Q033 diff ordering deterministic
P8-Q034 same candidate produces equivalent diff
```

## Preview

```text
P8-Q040 same scene projects deterministically
P8-Q041 thumbnail and large preview share topology
P8-Q042 SVG contains no script/external URL
P8-Q043 zoom/pan leaves candidate semantic fingerprint unchanged
```

## Responsive/carousel

```text
P8-Q050 390x844 no horizontal page overflow
P8-Q051 768x1024 usable tablet layout
P8-Q052 1024x768 useful landscape layout
P8-Q053 1440x900 multi-panel layout
P8-Q054 1920x1080 does not waste preview workspace
P8-Q055 resize wide→compact preserves session
P8-Q056 orientation change preserves selected candidate
P8-Q057 3 candidates snap correctly
P8-Q058 6 candidates snap correctly
P8-Q059 keyboard Left/Right selects candidates
P8-Q060 touch swipe selects candidates
P8-Q061 trackpad navigation snaps correctly
P8-Q062 selected state distinguishable without color only
P8-Q063 large text keeps primary actions accessible
```

## Integration

```text
P8-Q070 New Project Wizard apply persists
P8-Q071 New Project Wizard cancel leaves no Wizard mutation
P8-Q072 Navigator Wizard explicit target does not retarget silently
P8-Q073 post-commit navigator activates created hierarchy
P8-Q074 save/reopen preserves semantic fingerprint
P8-Q075 no browser/WebView dependency introduced
```

---

# 25. CI gates

Recommended P8-specific gates:

```text
flutter analyze
flutter test test/wizard_*.dart
flutter test test/project_*wizard*.dart
flutter test test/p8_qualification_test.dart
existing project mutation reservation regression tests
existing canonical persistence tests
existing navigator tests
```

If the repository uses consolidated qualification scripts, add one P8 entry that fails closed on any required scenario.

A P8 merge must not rely on manually observed screenshots only.

---

# 26. Suggested implementation file map

```text
lib/src/application/project/wizard/
├── wizard_parameters.dart
├── wizard_family.dart
├── wizard_target_context.dart
├── wizard_provider.dart
├── wizard_provider_descriptor.dart
├── wizard_provider_registry.dart
├── wizard_validation.dart
├── wizard_candidate.dart
├── wizard_candidate_id.dart
├── wizard_generation_context.dart
├── wizard_preview_summary.dart
├── wizard_mutation_plan.dart
├── wizard_candidate_coordinator.dart
├── apply_wizard_candidate_command.dart
├── wizard_errors.dart
├── diff/
│   ├── wizard_diff.dart
│   ├── wizard_diff_entry.dart
│   ├── wizard_field_change.dart
│   ├── wizard_diff_engine.dart
│   └── wizard_diff_sort.dart
├── preview/
│   ├── wizard_preview_scene.dart
│   ├── wizard_preview_primitive.dart
│   └── wizard_svg_projector.dart
└── session/
    ├── wizard_session_state.dart
    ├── wizard_session_event.dart
    ├── wizard_session_controller.dart
    └── wizard_session_snapshot.dart

lib/src/features/wizard/
├── wizard_screen.dart
├── wizard_entry.dart
├── wizard_family_selector.dart
├── wizard_parameter_form.dart
├── wizard_candidate_workspace.dart
├── wizard_candidate_carousel.dart
├── wizard_candidate_card.dart
├── wizard_preview_panel.dart
├── wizard_diff_panel.dart
├── wizard_validation_panel.dart
├── wizard_action_bar.dart
├── wizard_progress_header.dart
├── presentation/
│   ├── wizard_breakpoints.dart
│   ├── wizard_layout_class.dart
│   ├── wizard_responsive_scope.dart
│   └── wizard_scaffold.dart
└── preview/
    ├── wizard_preview_painter.dart
    ├── wizard_preview_viewport.dart
    └── wizard_preview_controller.dart

lib/src/application/project/wizard/providers/basic_building/
├── basic_building_wizard_parameters.dart
├── basic_building_wizard_provider.dart
├── basic_building_wizard_plan.dart
└── basic_building_wizard_validation.dart
```

Exact names may be tuned, but dependency direction must remain:

```text
features → application → domain
```

Never:

```text
application → Flutter widgets
provider → ProjectHubScreen
provider → EditorProjectDocument
```

---

# 27. Recommended commit sequence

Keep commits reviewable and qualification-aligned.

```text
P8-C01  feat(p8): add typed wizard contracts
P8-C02  feat(p8): add wizard provider registry
P8-C03  feat(p8): add basic building wizard provider
P8-C04  feat(p8): bind wizard candidates to reserved mutations
P8-C05  feat(p8): add semantic wizard diff model
P8-C06  feat(p8): add vector preview scene and svg projector
P8-C07  feat(p8): add wizard session state machine
P8-C08  feat(p8): add responsive wizard shell
P8-C09  feat(p8): add adaptive candidate carousel
P8-C10  feat(p8): integrate project hub wizard entry
P8-C11  feat(p8): integrate canonical navigator wizard entry
P8-C12  feat(p8): connect persistence and post-commit navigation
P8-C13  test(p8): add lifecycle and semantic qualification
P8-C14  test(p8): add responsive carousel qualification
P8-C15  perf(p8): harden preview/carousel rebuild behavior
P8-C16  docs(p8): close qualification and p9 handoff
```

Do not combine the entire P8 implementation into one giant commit.

---

# 28. Parallelization plan

After P8-C01 contracts land, work can proceed in controlled parallel lanes.

## Lane A — Application

```text
registry
base provider
candidate coordinator
reserved command bridge
semantic diff
session controller
```

## Lane B — Preview

```text
preview scene
vector primitives
SVG projector
preview viewport
```

## Lane C — UX

```text
responsive shell
carousel
input modalities
accessibility
```

## Lane D — Integration/QA

Starts after candidate lifecycle stabilizes:

```text
Project Hub
Navigator
persistence
qualification
```

Merge ordering still follows dependency gates even if development happens in parallel.

---

# 29. Architecture review checkpoints

Run explicit architecture reviews at these points.

## AR-P8-1 after contracts

Questions:

```text
Can P9 register Apartment provider without shell changes?
Are all target identities typed?
Is any persistence/UI type leaking into provider API?
```

## AR-P8-2 after candidate lifecycle

```text
Is exact preview committed?
Can IDs change after preview?
Can one Wizard action create multiple Undo records?
Can stale candidate overwrite newer state?
```

## AR-P8-3 after diff/preview

```text
Does user diff describe semantics rather than raw store changes?
Is SVG only a projection?
Can carousel selection alter canonical state?
```

## AR-P8-4 after integration

```text
Does Project Hub bypass canonical owner anywhere?
Does Navigator retarget an open Wizard?
Does Cancel persist anything?
```

## AR-P8-5 before merge

```text
Can P9 start without reopening P8 architecture?
Are mobile/tablet/desktop all first-class?
Do qualification gates prove invariants rather than only visuals?
```

---

# 30. Risk register

## R1 — Legacy blank seed becomes permanent dependency

Mitigation:

```text
encapsulate compatibility logic
never expose seed IDs in new contracts
qualify Cancel and Apply against fingerprint
```

## R2 — Wizard creates multiple mutations

Mitigation:

```text
composite ReservedProjectCommand
one frozen candidate
one commit
```

## R3 — Preview and committed IDs diverge

Mitigation:

```text
MutationIdentityReservation
commitPreview()
no ID allocation after preview
```

## R4 — UI knows too much about providers

Mitigation:

```text
registry + descriptors + generic candidate workspace
```

## R5 — Apartment P9 forces Wizard redesign

Mitigation:

```text
candidate-set protocol
variant selection state
carousel infrastructure in P8
preview scene abstraction
```

## R6 — Responsive UI forks business logic

Mitigation:

```text
one session/controller
width-based layout only
presentation-only reflow
```

## R7 — SVG becomes hidden source of truth

Mitigation:

```text
semantic candidate → preview scene → SVG
never SVG → canonical model
```

## R8 — Diff too low-level for humans

Mitigation:

```text
semantic diff projection
field-aware typed changes
group by hierarchy
```

## R9 — Carousel jank on mobile

Mitigation:

```text
small bounded candidate set
immutable cached scenes
pre-cache neighbors
no generation on scroll
```

## R10 — Apply succeeds but UI loses location

Mitigation:

```text
post-commit navigation contract
explicit created/relevant IDs
navigator reveal test
```

---

# 31. Product-quality principles

P8 should feel like a professional engineering configurator, not a CRUD wizard.

Required product qualities:

```text
progressive disclosure
strong defaults
visual comparison
explicit preview before commit
clear warnings
reversible atomic action
no dead controls
no hidden mutation
fast return to parameter editing
same mental model across mobile/tablet/desktop
```

For future Apartment flow:

```text
parameters
→ generate bounded variants
→ swipe/scroll SVG carousel
→ inspect selected plan
→ understand diff
→ apply once
```

The user should never need to understand internal ProjectAggregate mechanics to use the Wizard safely.

---

# 32. P8 completion gates

P8 is not complete until all gates are green.

```text
P8-G00 specification/readiness
P8-G01 typed contracts
P8-G02 responsive primitives
P8-G03 provider registry
P8-G04 basic provider
P8-G05 reserved candidate lifecycle
P8-G06 semantic diff
P8-G07 vector preview/SVG
P8-G08 state machine
P8-G09 responsive shell
P8-G09A carousel
P8-G10A Project Hub integration
P8-G10B Navigator integration
P8-G10C persistence/publication
P8-G11A errors/recovery
P8-G11B accessibility/input
P8-G11C performance
P8-G12 qualification
```

A gate cannot be waived by saying "P9 will fix it" if it belongs to common Wizard infrastructure.

---

# 33. P8 → P9 handoff contract

P9 may begin production integration when the following are stable:

```text
WizardProvider<P>
WizardProviderDescriptor
WizardTargetContext
WizardCandidateId
GeneratedWizardCandidate
candidate-set selection protocol
WizardPreviewScene
WizardPreviewSummary
WizardDiff
WizardSessionController
WizardCandidateCarousel
ApplyWizardCandidateCommand / reserved lifecycle
```

P9 must only need to add:

```text
ApartmentWizardParameters
ApartmentTopologyCatalog
ApartmentTopologyGenerator
ApartmentCandidateScorer
Apartment preview-scene mapping
Apartment provider registration
Apartment-specific parameter form sections
```

P9 must not need to change:

```text
commit protocol
undo protocol
stale version protocol
carousel selection identity
responsive shell architecture
semantic diff core
Project Hub commit lifecycle
Navigator commit lifecycle
```

If P9 requires changing those, P8 is not architecturally finished.

---

# 34. Recommended P8 milestone grouping

For delivery tracking, group the work into five milestones.

## M1 — Foundation

```text
P8.0
P8.1
P8.2
P8.3
```

Result:

```text
stable Wizard contracts + adaptive shell primitives + provider discovery
```

## M2 — First canonical vertical slice

```text
P8.4
P8.5
```

Result:

```text
Basic Building parameters
→ frozen candidate
→ reserved preview
→ one atomic commit
```

This is the first point where P8 proves architectural viability.

## M3 — Professional preview

```text
P8.6
P8.7
P8.8
```

Result:

```text
semantic diff
vector preview
state-machine driven workflow
```

## M4 — Product UX

```text
P8.9
P8.9A
P8.10A/B/C
```

Result:

```text
mobile/tablet/desktop Wizard
carousel-ready candidate selector
real Project Hub/Navigator integration
```

## M5 — Production hardening

```text
P8.11
P8.12
```

Result:

```text
failure-safe, accessible, performant, qualified P8
```

---

# 35. Definition of Done

P8 Definition of Done is all of the following together:

```text
1. Wizard uses typed provider contracts.
2. Target context is explicit and ID-backed.
3. Provider registry controls availability.
4. Basic Building provider works end to end.
5. Preview never mutates live canonical state.
6. IDs are reserved once and committed unchanged.
7. Exact frozen preview is committed.
8. Stale preview cannot overwrite newer project state.
9. One Apply creates one ProjectChangeSet and one Undo record.
10. Semantic diff explains user-visible structural change.
11. Preview scene is vector and rendering-neutral.
12. SVG is a deterministic projection only.
13. Wizard session is an application-level state machine.
14. Mobile/tablet/desktop share one workflow and session.
15. Candidate carousel supports touch/mouse/trackpad/keyboard.
16. Resize/orientation change does not regenerate or lose selection.
17. Project Hub exposes Wizard start path.
18. Navigator exposes contextual Wizard path.
19. Successful commit is accepted by canonical persistence owner.
20. Post-commit navigation activates relevant created hierarchy.
21. Cancel/Back preserve semantic fingerprint.
22. Qualification proves lifecycle, diff, preview, responsive and integration invariants.
23. No Web/browser runtime path is introduced.
24. P9 Apartment provider can plug in without changing P8 transaction architecture.
```

---

# 36. Final execution order

The recommended actual implementation order in `feat/p8-wizard-preview-diff` is:

```text
01 contracts
02 registry
03 responsive primitives
04 base Building provider
05 composite Wizard mutation plan
06 reserved candidate coordinator
07 semantic diff
08 vector preview scene
09 SVG projector + Flutter preview renderer
10 session state machine
11 Wizard shell
12 candidate carousel
13 Project Hub integration
14 Navigator integration
15 persistence + post-commit navigation
16 error/accessibility/performance hardening
17 full P8 qualification
18 architecture audit
19 P8 closure note
20 P9 handoff
```

The single most important implementation principle is:

```text
Do not start from the screen.
Start from the exact candidate/commit contract, then build the screen around it.
```

That ordering is what keeps the mobile/tablet/desktop Wizard, SVG apartment carousel and later generators aligned with one canonical ElecX engineering model instead of becoming a parallel UI subsystem.
