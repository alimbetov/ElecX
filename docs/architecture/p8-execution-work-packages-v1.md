# P8 Execution Work Packages v1

## Status

Normative execution specification for `feat/p8-wizard-preview-diff`.

This document is part of the P8 technical specification pack and operationalizes:

- `p8-wizard-preview-diff-implementation-v1.md`;
- `p8-wizard-responsive-carousel-ux-v1.md`;
- `p8-development-roadmap-v1.md`;
- `project-composition-foundation-decisions-v1.md`.

A work package is complete only when its code, tests, integration evidence and exit gate are all satisfied. A visually working screen is not evidence that a package is complete.

---

# 1. Execution model

P8 is implemented as a sequence of contract-first work packages:

```text
WP00 readiness/spec freeze
  ↓
WP01 typed contracts
  ↓
WP02 provider registry
  ├──────────────→ WP03 responsive primitives
  ↓
WP04 base Building provider
  ↓
WP05 reserved mutation bridge
  ↓
WP06 candidate coordinator
  ├──────────────→ WP07 semantic diff
  ├──────────────→ WP08 preview scene/SVG
  └──────────────→ WP09 session state machine
                    ↓
              WP10 responsive Wizard shell
                    ↓
              WP11 candidate carousel
                    ↓
              WP12 Project Hub integration
                    ↓
              WP13 Navigator integration
                    ↓
              WP14 persistence/publication
                    ↓
              WP15 recovery/accessibility/performance
                    ↓
              WP16 qualification/closure/P9 handoff
```

The critical path is WP01 → WP02 → WP04 → WP05 → WP06 → WP09 → WP12/13/14 → WP16.

WP03, WP07 and WP08 may run in parallel once their contracts are frozen.

---

# 2. Cross-cutting invariants

Every work package must preserve these rules:

```text
X01 one canonical ProjectAggregateRoot
X02 no widget-side project mutation
X03 typed stable IDs only
X04 explicit Wizard target context
X05 preview cannot change LocalProjectVersion
X06 preview cannot create Undo history
X07 exact frozen preview is committed
X08 reserved IDs do not change between preview and commit
X09 stale LocalProjectVersion blocks Apply
X10 one Apply = one ProjectChangeSet = one Undo record
X11 Cancel/Back preserve canonical semantic fingerprint
X12 SVG/vector rendering is projection only
X13 responsive reflow never changes semantics
X14 candidate selection uses WizardCandidateId, never list index as authority
X15 ProjectRepository/persistence is reached only through canonical ownership path
X16 P9 must plug in without changing P8 transaction architecture
```

Any implementation that violates one of these invariants must be rejected even if the UI appears functional.

---

# 3. WP00 — Readiness and specification freeze

## Objective

Prove that P8 can be implemented on the current canonical foundation without inventing new ownership or transaction mechanisms.

## Inputs

```text
ProjectMutationSession
ReservedProjectMutationCoordinator
MutationIdentityReservation
ProjectNavigationState
CanonicalProjectPersistenceOwner
ProjectStructureAuthoringSession
Project Hub / Navigator production paths
legacy blank project compatibility seed
```

## Tasks

1. Enumerate all P8 invariants and map each to an owner layer: domain, application, presentation, integration or qualification.
2. Confirm `ReservedProjectMutationCoordinator` is the mandatory preview/apply backbone.
3. Confirm a Wizard command can build one composite candidate instead of executing N structural commands sequentially.
4. Confirm post-commit navigation can activate/reveal created hierarchy without a second project mutation.
5. Confirm current legacy blank Building/Level is treated only as compatibility data.
6. Freeze public names for Wizard target, provider, candidate, preview, diff and session contracts.
7. Record P8/P9/P10 ownership boundary.
8. Create a traceability matrix from invariant → work package → test → gate.

## Failure conditions

```text
second persistent Wizard graph required
provider must call Flutter widget APIs
preview requires persistence write
new project flow requires permanent dependence on placeholder IDs
one Wizard action can only be expressed as multiple commits
```

Any of these blocks implementation until architecture is corrected.

## Evidence

```text
P8 specification pack committed
all lower-layer dependencies identified
no unresolved transaction ownership question
```

## Exit gate

`P8-G00`.

---

# 4. WP01 — Typed Wizard contracts

## Objective

Create the stable application API that P8, P9, P10 and later engineering generators share.

## Target files

```text
lib/src/application/project/wizard/
  wizard_parameters.dart
  wizard_family.dart
  wizard_target_context.dart
  wizard_provider.dart
  wizard_provider_descriptor.dart
  wizard_validation.dart
  wizard_candidate_id.dart
  wizard_candidate.dart
  wizard_generation_context.dart
  wizard_preview_summary.dart
  wizard_mutation_plan.dart
  wizard_errors.dart
```

## Required types

### `WizardParameters`

Sealed root for all typed parameter sets. No authoritative `Map<String,Object?>`.

### `WizardTargetContext`

Required variants:

```text
NewProjectWizardTarget
SiteWizardTarget
BuildingWizardTarget
LevelWizardTarget
```

Every target carries:

```text
ProjectId
SiteId
LocalProjectVersion
optional BuildingId
optional LevelId
```

Constructor/factory validation must prove that target IDs belong to the expected canonical hierarchy when a project snapshot is available.

### `WizardProviderDescriptor`

Must contain stable machine metadata:

```text
TemplateId
templateVersion
generatorVersion
WizardFamilyId
localization/display key
supported target scopes
supportsVariants
preview capabilities
```

Display labels are not identity.

### `WizardValidationIssue`

Fields:

```text
stable issue code
severity: info/warning/blocker
optional field key
optional entity/target reference
human-facing message key/message
```

Blockers prevent candidate Apply.

### `WizardCandidateId`

Draft/session identity. It must be stable inside one generated candidate set but is not a persistent Project entity ID.

## Algorithmic requirements

Normalization must run before generation:

```text
trim text
normalize optional values
normalize enums/defaults
canonicalize numeric units
reject invalid ranges
produce deterministic normalized intent key
```

The normalized intent key includes provider/version/target/semantic parameters and excludes random reserved IDs and UI state.

## Edge cases

```text
blank/whitespace names
unsupported target scope
missing BuildingId for building target
stale base version already at session start
provider descriptor collision
invalid templateVersion/generatorVersion
```

## Tests

```text
wizard_target_context_test.dart
wizard_provider_descriptor_test.dart
wizard_parameter_normalization_test.dart
wizard_validation_test.dart
wizard_candidate_id_test.dart
wizard_contract_dependency_test.dart
```

`wizard_contract_dependency_test` must prove application contracts import neither Flutter nor persistence implementations.

## Exit evidence

```text
contracts compile independently of UI
contracts compile independently of repository implementation
all identities typed
future Apartment provider fits without API change
```

## Exit gate

`P8-G01`.

---

# 5. WP02 — Provider registry and capability discovery

## Objective

Make Wizard family availability data-driven and target-aware.

## Target files

```text
wizard_provider_registry.dart
wizard_provider_capability.dart
```

## API

```text
register(provider)
providersFor(target)
descriptorFor(familyId)
capabilitySnapshot(target)
```

## Rules

1. Provider order is deterministic.
2. Duplicate stable provider/family identifiers fail fast.
3. Registry contains no widgets.
4. UI never hard-codes `Apartment/Cottage/...` availability.
5. P9 Apartment option is absent until the P9 provider is actually registered.
6. `Blank project` is a shell/manual action, not a fake provider.

## Edge cases

```text
zero providers for target
same provider registered twice
same family/version collision
target supported by descriptor but rejected by runtime validation
provider becomes unavailable because target disappeared
```

## Tests

```text
wizard_provider_registry_test.dart
wizard_provider_order_test.dart
wizard_provider_capability_test.dart
wizard_provider_collision_test.dart
```

## Exit gate

`P8-G03`.

---

# 6. WP03 — Responsive presentation primitives

## Objective

Create reusable layout primitives before concrete Wizard screens are built.

## Target files

```text
lib/src/features/wizard/presentation/
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

Use actual available Wizard constraints, never OS/device detection.

## Behavior

### compact

```text
single column
sticky action bar
full-width step content
no permanent side inspector
no page-level horizontal overflow
```

### medium

```text
one/two-column form groups
preview prioritized
sticky action bar
```

### expanded

```text
parameter rail + preview workspace
collapsible diff/details
```

### wide

```text
parameters | large preview | diff/details
carousel remains visible
```

## State rule

Changing width/orientation/split-screen must not recreate `WizardSessionController`, regenerate candidates or allocate new IDs.

## Tests

```text
wizard_responsive_scope_test.dart
wizard_scaffold_compact_test.dart
wizard_scaffold_medium_test.dart
wizard_scaffold_expanded_test.dart
wizard_scaffold_wide_test.dart
wizard_resize_state_preservation_test.dart
wizard_safe_area_test.dart
```

Required sizes:

```text
390x844
844x390
768x1024
1024x768
1280x800
1440x900
1920x1080
```

## Exit gate

`P8-G02`.

---

# 7. WP04 — Basic Building Wizard provider

## Objective

Provide one real production generator to prove P8 end-to-end before P9/P10.

## Target files

```text
lib/src/application/project/wizard/providers/basic_building/
  basic_building_wizard_parameters.dart
  basic_building_wizard_provider.dart
  basic_building_wizard_plan.dart
  basic_building_wizard_validation.dart
```

## Parameters

```text
buildingName
aboveGroundLevelCount: 1..200
basementLevelCount: 0..30
floorToFloorHeightMm: >0
levelNumberingConvention
createExplicitGroundLevel / normalized equivalent
```

## Generation algorithm

1. Normalize name and numeric options.
2. Validate ranges.
3. Resolve deterministic level numbering convention.
4. Build a semantic `WizardMutationPlan` only; do not mutate project.
5. Produce deterministic level sequence.
6. Assign deterministic elevations in integer millimetres.
7. Produce semantic reservation slots such as `building`, `level:basement:1`, `level:above:1`.
8. Produce preview summary counts.
9. Do not create rooms, apartments, cores or engineering systems.

## Elevation policy

Reference authored ground/first level at `0 mm` according to normalized numbering mode. Above-ground levels increment by `floorToFloorHeightMm`; basements decrement by the same amount unless future typed policy explicitly says otherwise.

## Critical rule

The provider must not call `createBuilding()` and then `createLevel()` repeatedly. The whole generated hierarchy is one composite mutation plan.

## Edge cases

```text
200 levels
30 basements
name normalized to empty
integer overflow guard for elevation calculations
level-number collision with existing target building
existing building insertion target versus new building target
legacy compatibility seed normalization
```

## Tests

```text
basic_building_wizard_parameters_test.dart
basic_building_wizard_provider_test.dart
basic_building_wizard_plan_test.dart
basic_building_wizard_elevation_test.dart
basic_building_wizard_limits_test.dart
basic_building_wizard_existing_target_test.dart
```

## Exit gate

`P8-G04`.

---

# 8. WP05 — Composite reserved mutation bridge

## Objective

Convert a `WizardMutationPlan` into one reserved canonical mutation compatible with existing transaction infrastructure.

## Target file

```text
apply_wizard_candidate_command.dart
```

## Contract

`ApplyWizardCandidateCommand implements ReservedProjectCommand`.

## `reserveIdentities()`

Must allocate every identity that can become durable in the candidate before preview is exposed.

No later allocation is allowed between preview and commit.

## `validateReservation()`

Must prove:

```text
reserved IDs do not collide
explicit target still exists
Building/Level ownership still matches expected target
reservation slots are complete
no slot has wrong ID type
```

## `buildCandidate()`

Pure function of:

```text
current canonical snapshot
+ normalized mutation plan
+ immutable reservation
```

It returns one `ProjectCommandCandidate` containing the complete change.

## `semanticOperations()`

Must describe enough typed effects to build a human semantic diff without reverse engineering raw JSON.

## Edge cases

```text
foreign target
reserved ID collision
missing reservation slot
duplicate semantic operation
empty/no-op candidate
candidate invalid under CandidateGraphValidator
```

## Tests

```text
apply_wizard_candidate_command_test.dart
wizard_reservation_completeness_test.dart
wizard_reservation_collision_test.dart
wizard_composite_mutation_test.dart
wizard_candidate_validation_test.dart
```

## Exit gate

Part of `P8-G05`.

---

# 9. WP06 — Wizard candidate coordinator

## Objective

Own the full deterministic prepare/preview/apply lifecycle at application level.

## Target file

```text
wizard_candidate_coordinator.dart
```

## Prepare pipeline

```text
raw typed parameters
→ normalize
→ parameter validation
→ provider generation
→ mutation plan
→ ApplyWizardCandidateCommand
→ ReservedProjectMutationCoordinator.preview()
→ canonical CandidateGraphValidator
→ frozen ReservedProjectMutationPreview
→ WizardCandidateId
→ semantic diff projection input
→ preview summary
→ preview scene
→ WizardPreparedCandidate
```

## Prepared candidate must retain

```text
candidate ID
provider descriptor/version
normalized intent key
base LocalProjectVersion
explicit target
reserved preview handle
validation report
semantic diff
preview summary
preview scene
```

## Apply pipeline

```text
verify selected prepared candidate
verify no blocker
verify session still previewReady
commitPreview(exact prepared preview)
return ProjectMutationResult + relevant created IDs
```

No provider regeneration during Apply.

## Stale flow

If canonical version differs from candidate base version:

```text
state → previewBlocked
Apply unavailable
old candidate remains inspectable
user must Refresh Preview / Back / Cancel
```

Never auto-regenerate and silently apply a different candidate.

## Tests

```text
wizard_candidate_coordinator_test.dart
wizard_preview_side_effect_test.dart
wizard_reserved_identity_stability_test.dart
wizard_stale_preview_test.dart
wizard_double_apply_test.dart
wizard_cancel_fingerprint_test.dart
wizard_exact_candidate_commit_test.dart
```

## Exit gate

`P8-G05`.

---

# 10. WP07 — Semantic diff engine

## Objective

Explain to the user what Apply will change, not merely which internal IDs differ.

## Target files

```text
lib/src/application/project/wizard/diff/
  wizard_diff.dart
  wizard_diff_entry.dart
  wizard_field_change.dart
  wizard_diff_engine.dart
  wizard_diff_sort.dart
  wizard_diff_summary.dart
  wizard_entity_presenter.dart
```

## Public model

```text
WizardDiffKind: add/update/remove/preserve/conflict
WizardFieldKey: typed known field identifiers
WizardFieldChange: before/after typed display values
WizardDiffEntry: entity + owner + kind + field changes
WizardDiff: grouped entries + summary
```

P8 primarily emits add/update/remove; preserve/conflict are reserved now so P15 regeneration does not require redesign.

## Required field keys

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

## Ordering

```text
Site → Building → Level → Zone → Space → Opening → Boundary → VerticalCore → later engineering
```

Stable tie breaking must not depend on localized strings.

## UI projection

Compact: summary + expandable groups.

Wide: persistent/collapsible details panel.

## Edge cases

```text
entity created and parent updated
large 200-level candidate
diff with only metadata changes
unknown future entity kind
deterministic sorting across map iteration order
```

## Tests

```text
wizard_diff_engine_test.dart
wizard_diff_sort_test.dart
wizard_diff_field_change_test.dart
wizard_diff_summary_test.dart
wizard_diff_large_hierarchy_test.dart
```

## Exit gate

`P8-G06`.

---

# 11. WP08 — Vector preview scene and SVG projection

## Objective

Create one rendering-neutral preview model used by cards, large preview and optional deterministic SVG serialization.

## Application files

```text
lib/src/application/project/wizard/preview/
  wizard_preview_scene.dart
  wizard_preview_primitive.dart
  wizard_preview_style_role.dart
  wizard_svg_projector.dart
```

## Feature files

```text
lib/src/features/wizard/preview/
  wizard_preview_painter.dart
  wizard_preview_viewport.dart
  wizard_preview_controller.dart
```

## Scene primitives

```text
bounds
polygon
polyline
line
label
marker
semantic role metadata
```

Semantic source geometry remains integer millimetres.

## Rendering pipeline

```text
semantic candidate
→ WizardPreviewScene
→ fit/viewport transform
→ CustomPainter runtime rendering
→ optional deterministic SVG serialization
```

Never parse internally generated SVG back into the canonical model.

## SVG rules

```text
deterministic viewBox
stable primitive order
escaped labels
no JavaScript
no external URL
no remote font
no WebView
same scene → semantically equivalent SVG
```

## Density modes

```text
thumbnail
card
large
```

They may hide nonessential labels but must preserve topology.

## Tests

```text
wizard_preview_scene_test.dart
wizard_preview_transform_test.dart
wizard_svg_projector_test.dart
wizard_svg_security_test.dart
wizard_preview_painter_test.dart
wizard_preview_density_equivalence_test.dart
```

## Exit gate

`P8-G07`.

---

# 12. WP09 — Wizard session state machine

## Objective

Make workflow semantics testable independently of Flutter widget callbacks.

## Target files

```text
lib/src/application/project/wizard/session/
  wizard_session_state.dart
  wizard_session_event.dart
  wizard_session_controller.dart
  wizard_session_snapshot.dart
  wizard_session_transition.dart
```

## States

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

## Events

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

## Invariants

```text
Apply only from previewReady
blockers disable Apply
selected candidate must belong to current candidate set
Back/Cancel never mutate canonical project
resize/orientation is presentation-only and not a session event
stale canonical version forces previewBlocked
completed/consumed candidate cannot Apply twice
```

## State ownership

Application session owns provider, parameters, validation, candidate set, selected candidate ID, prepared preview, diff, summary, status and typed errors.

Presentation owns hover, focus, scroll offset, panel collapse, zoom/pan and animations.

## Tests

```text
wizard_session_transition_test.dart
wizard_session_forbidden_transition_test.dart
wizard_session_stale_test.dart
wizard_session_cancel_test.dart
wizard_session_double_apply_test.dart
wizard_session_candidate_selection_test.dart
```

## Exit gate

`P8-G08`.

---

# 13. WP10 — Responsive Wizard shell and forms

## Objective

Build one professional shell across mobile, tablet and desktop using the same session/controller.

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

## Form rules

```text
progressive disclosure
strong defaults
units always explicit
numeric keyboard/input formatters where applicable
validation adjacent to field
advanced options collapsed initially
keyboard must not cover mandatory action/field on compact layouts
```

## Compact behavior

```text
single focused step
sticky Back / Continue / Apply
full-screen preview sheet allowed
```

## Expanded/wide behavior

```text
avoid dialog chains
keep candidate switching visible while inspecting large plan
collapse details rather than hide preview
```

## Tests

```text
wizard_shell_compact_test.dart
wizard_shell_medium_test.dart
wizard_shell_expanded_test.dart
wizard_shell_wide_test.dart
wizard_form_keyboard_test.dart
wizard_form_validation_test.dart
wizard_live_resize_test.dart
```

## Exit gate

`P8-G09`.

---

# 14. WP11 — Provider-neutral candidate carousel

## Objective

Implement the reusable candidate selector required by P9 apartment topology variants.

## Target components

```text
WizardCandidateCarousel
WizardCandidateCard
WizardCandidateCarouselController
```

## Inputs

```text
candidate IDs
preview scene per candidate
summary metadata
selectedCandidateId
selection callback
semantic description builder
```

## Required behavior

```text
horizontal swipe/scroll
snap to one stable candidate
neighboring context visible
programmatic selection
mouse click
trackpad momentum
keyboard Left/Right/Home/End
Enter/Space selection
screen reader semantics
```

## Density targets

```text
compact   1.10..1.20 visible cards
medium    1.35..2.20
expanded  2.20..3.40
wide      3..5
```

These are adaptive behavior targets, not business values.

## Selection rules

1. `WizardCandidateId` is authoritative.
2. Page/scroll index is presentation state only.
3. Selection changes after snap settles, not continuously for every pixel.
4. Resize preserves selected candidate.
5. Candidate ordering is deterministic and never reshuffles while rendering.

## Performance rules

```text
candidate generation never runs during scroll
ProjectAggregate is never rebuilt during scroll
preview scenes immutable/cached
selected and neighbor scenes pre-cached
hover does not rebuild whole Wizard
```

## Accessibility

Each card is one semantic control. Internal SVG primitives are not individual accessibility nodes. Selected state must not rely on color only.

## Tests

```text
wizard_candidate_carousel_test.dart
wizard_candidate_carousel_snap_test.dart
wizard_candidate_carousel_keyboard_test.dart
wizard_candidate_carousel_touch_test.dart
wizard_candidate_carousel_trackpad_test.dart
wizard_candidate_carousel_semantics_test.dart
wizard_candidate_carousel_resize_test.dart
wizard_candidate_carousel_performance_test.dart
```

Use mock sets of 3 and 6 candidates.

## Exit gate

`P8-G09A`.

---

# 15. WP12 — Project Hub / new-project integration

## Objective

Make Wizard the primary discoverable start path while containing legacy blank-project compatibility behavior.

## Target change

`ProjectHubScreen` creation flow must expose:

```text
Create with Wizard
Start blank
```

Provider family choices come from registry capability snapshot.

## Legacy seed strategy

Until true site-only legacy opening exists:

```text
placeholder Building/Level may exist internally
placeholder remains hidden behind start gate
provider cannot depend on placeholder IDs
candidate explicitly reuses/normalizes/replaces seed where required
Cancel leaves canonical fingerprint unchanged
preview is not persisted
```

## Apply sequence

```text
new-project metadata / compatibility bootstrap
→ Wizard target snapshot
→ candidate prepare
→ preview/diff
→ Apply
→ canonical commit
→ persistence owner acceptance
→ editor opens/reveals committed hierarchy
```

## Tests

```text
project_hub_wizard_entry_test.dart
new_project_wizard_cancel_test.dart
new_project_wizard_apply_test.dart
new_project_legacy_seed_compatibility_test.dart
new_project_wizard_provider_availability_test.dart
```

## Exit gate

`P8-G10A`.

---

# 16. WP13 — Project Navigator integration

## Objective

Expose contextual Wizard authoring beside manual `+Building/+Level/+Room`.

## Rule

Capture target IDs and base version when Wizard opens. Do not silently retarget when navigator selection later changes.

## Provider availability examples

```text
Site target     → Basic Building
Building target → only providers declaring Building scope
Level target    → only providers declaring Level scope
```

## Post-commit navigation

After successful Apply:

```text
activate relevant created Building
activate preferred created Level if applicable
clear invalid old selection
reveal node in tree
preserve canonical ID semantics
```

This is navigation projection, not a second project mutation.

## Tests

```text
canonical_project_navigator_wizard_entry_test.dart
wizard_explicit_target_test.dart
wizard_no_silent_retarget_test.dart
wizard_post_commit_navigation_test.dart
wizard_manual_authoring_regression_test.dart
```

## Exit gate

`P8-G10B`.

---

# 17. WP14 — Persistence and commit publication

## Objective

Make Wizard use exactly the same canonical ownership and save path as other authoring.

## Sequence

```text
Wizard Apply
→ ReservedProjectMutationCoordinator.commitPreview()
→ ProjectMutationResult
→ canonical persistence owner accepts mutation
→ feature publication hook
→ repository/autosave
→ UI completed
```

## Rules

```text
no Wizard-specific repository
no direct JSON write
no direct dart:io/path_provider usage
no preview persistence
no alternative rollback protocol
```

If commit succeeds but persistence callback fails, existing canonical owner recovery policy governs the failure.

## Tests

```text
wizard_persistence_owner_integration_test.dart
wizard_commit_publication_test.dart
wizard_double_apply_integration_test.dart
wizard_save_reopen_fingerprint_test.dart
wizard_undo_redo_persistence_test.dart
```

## Exit gate

`P8-G10C`.

---

# 18. WP15 — Recovery, accessibility and performance hardening

## Objective

Close non-happy-path behavior before P8 qualification.

## Error groups

```text
parameter error
generation error
blocker
warning
stale preview
missing target
reservation conflict
commit failure
persistence failure
unexpected internal failure
```

Every group maps to a deterministic session state and user action. No `Apply anyway` for stale/blocker states.

## Accessibility

```text
48x48 logical minimum primary touch targets
logical Tab order
candidate card = one semantics node
selected state announced
warnings/blockers announced
large text supported
selected state distinguishable without color
reduced-motion respected
```

## Performance discipline

```text
parameter edit does not mutate canonical aggregate
carousel frame does not regenerate candidates
semantic diff computed once per frozen candidate
preview scene cached
resize reflows without regeneration
large preview reuses scene
```

## Instrumentable timings

```text
validation
generation
canonical preview
semantic diff
scene creation
first card paint
commit
```

Instrumentation must not affect semantics.

## Tests

```text
wizard_error_mapping_test.dart
wizard_stale_recovery_test.dart
wizard_accessibility_test.dart
wizard_large_text_test.dart
wizard_reduced_motion_test.dart
wizard_preview_cache_test.dart
wizard_no_regeneration_on_resize_test.dart
wizard_no_regeneration_on_scroll_test.dart
```

## Exit gates

`P8-G11A`, `P8-G11B`, `P8-G11C`.

---

# 19. WP16 — Qualification, architecture audit and P9 handoff

## Objective

Prove P8 as a reusable platform, not only a functioning Building Wizard.

## Mandatory qualification groups

### Lifecycle

```text
open/edit/generate/switch/back/cancel do not mutate canonical state
Apply increments version exactly once
Apply adds one Undo record
Undo reverts whole Wizard operation
Redo restores whole operation
stale preview rejected
double Apply rejected
reserved preview IDs equal committed IDs
```

### Basic Building

```text
1 level
200 levels
0 basements
30 basements
invalid height
blank name
duplicate numbering
CandidateGraphValidator pass
```

### Diff

```text
added Building visible
levels grouped under Building
field before/after correct
ordering deterministic
```

### Preview/SVG

```text
same scene deterministic
thumbnail/card/large topology equivalent
SVG no script/external URL
zoom/pan no semantic mutation
```

### Responsive/carousel

```text
390x844
844x390
768x1024
1024x768
1280x800
1440x900
1920x1080
3 candidate carousel
6 candidate carousel
resize/orientation selection preservation
touch/mouse/trackpad/keyboard
large text
```

### Integration

```text
Project Hub apply/cancel
Navigator explicit target
post-commit reveal
persistence owner acceptance
save/reopen fingerprint
one-step Undo/Redo
```

## Architecture audit questions

1. Can P9 register an Apartment provider without changing Wizard shell transaction logic?
2. Can P9 return 3..6 candidates and use the existing carousel unchanged?
3. Can P9 use existing `WizardPreviewScene` without making SVG authoritative?
4. Can P9 use the same Apply/Undo/stale protocol unchanged?
5. Are mobile/tablet/desktop presentation differences purely presentation?
6. Does any provider know `ProjectHubScreen` or concrete persistence implementation?
7. Does any preview path write canonical state?

Any `no`/violation blocks P8 closure.

## P9 handoff contract

P9 may add only:

```text
ApartmentWizardParameters
ApartmentTopologyCatalog
ApartmentTopologyGenerator
ApartmentCandidateScorer
Apartment provider
Apartment parameter form sections
Apartment preview-scene mapper
```

P9 must not need to redesign:

```text
transaction protocol
reserved identity lifecycle
Undo/Redo
stale candidate handling
candidate ID/selection protocol
carousel
responsive shell
semantic diff core
Project Hub/Navigator commit path
```

## Exit gate

`P8-G12` plus architecture closure note.

---

# 20. Commit-to-work-package map

```text
P8-C01  WP01 typed contracts
P8-C02  WP02 provider registry
P8-C03  WP03 responsive primitives
P8-C04  WP04 Basic Building provider
P8-C05  WP05 reserved command bridge
P8-C06  WP06 candidate coordinator
P8-C07  WP07 semantic diff
P8-C08  WP08 preview scene/SVG
P8-C09  WP09 session state machine
P8-C10  WP10 responsive Wizard shell
P8-C11  WP11 candidate carousel
P8-C12  WP12 Project Hub integration
P8-C13  WP13 Navigator integration
P8-C14  WP14 persistence/publication
P8-C15  WP15 recovery/accessibility/performance
P8-C16  WP16 qualification + closure + P9 handoff
```

Commits may be further split for reviewability, but dependencies and gates may not be bypassed.

---

# 21. Traceability matrix

```text
Invariant  Owner WP    Primary proof
X01        WP05/06     candidate/commit integration tests
X02        WP09/10     session + widget dependency tests
X03        WP01/05     typed target/reservation tests
X04        WP01/13     explicit-target tests
X05        WP06        preview-side-effect tests
X06        WP06        undo-depth preview tests
X07        WP05/06     exact-candidate commit tests
X08        WP05/06     reserved-id stability tests
X09        WP06/09     stale-preview tests
X10        WP05/14     one-change-set/one-undo tests
X11        WP06/09/12  fingerprint cancel/back tests
X12        WP08        preview/SVG equivalence tests
X13        WP03/10/11  resize/orientation tests
X14        WP01/11     candidate selection identity tests
X15        WP14        persistence-owner integration tests
X16        WP16        P9 handoff architecture audit
```

---

# 22. Final Definition of Ready for implementation

Implementation may start when:

```text
specification pack is committed
WP01 public contract names accepted
P8/P9 boundary accepted
ReservedProjectMutationCoordinator confirmed as backbone
legacy seed treated as transitional
responsive/carousel requirements accepted
```

# 23. Final Definition of Done

P8 is done only when all WP00..WP16 gates are green and the following end-to-end flow passes:

```text
New Project / Navigator
→ Wizard
→ typed parameters
→ deterministic candidate(s)
→ optional responsive carousel
→ large vector preview
→ semantic diff
→ Apply
→ exact frozen candidate
→ one canonical commit
→ one Undo
→ canonical persistence
→ post-commit navigator reveal
→ save/reopen semantic fingerprint preserved
```

The defining architectural success criterion is simple:

```text
P9 can add apartment generation without reopening P8 transaction, preview, diff, carousel or responsive architecture.
```
