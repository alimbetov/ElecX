# P8 Wizard + Preview/Diff Specification Pack v1

## Status

This file defines the authoritative technical-specification composition for `feat/p8-wizard-preview-diff`.

P8 is not specified by one isolated document. The following documents together form the normative P8 technical specification:

1. `project-composition-foundation-decisions-v1.md` — canonical ownership, identity, mutation, persistence and roadmap authority.
2. `project-template-wizard-v1.md` — product/domain Wizard contract.
3. `project-composition-generation-v1.md` — generation/preview/diff integration contract.
4. `p8-technical-audit-v1.md` — mandatory technical audit corrections, production-runtime bridge requirements and RBAC scope.
5. `p8-wizard-preview-diff-implementation-v1.md` — P8 implementation architecture.
6. `p8-wizard-responsive-carousel-ux-v1.md` — mandatory responsive/mobile/tablet/desktop and carousel UX contract.
7. `p8-development-roadmap-v1.md` — delivery dependency graph, milestones, gates and P9 handoff.
8. `p8-execution-work-packages-v1.md` — detailed executable work packages WP00..WP16 with files, algorithms, failure modes, tests and evidence.
9. `apartment-topology-catalog-v1.md` — future P9 apartment-generation semantics consumed by the P8 framework.

For P8 implementation, items 4–8 are all mandatory. Audit findings marked Critical/High are requirements, not advisory review notes.

If documents conflict, precedence is:

```text
project-composition-foundation-decisions-v1.md
        ↓
P8 Specification Pack authority rules (this document)
        ↓
p8-technical-audit-v1.md for audited runtime/integration corrections
        ↓
p8-wizard-preview-diff-implementation-v1.md
        ↓
p8-wizard-responsive-carousel-ux-v1.md for presentation/interaction concerns
        ↓
p8-development-roadmap-v1.md for delivery ordering/gates
        ↓
p8-execution-work-packages-v1.md for implementation decomposition/evidence
```

`apartment-topology-catalog-v1.md` governs P9 apartment semantics but may not redefine P8 transaction, preview, carousel, access baseline or responsive architecture.

---

# 1. Mandatory P8 scope

P8 MUST deliver all of the following as one coherent subsystem:

```text
typed Wizard contracts
explicit target contexts
provider registry/capability discovery
base structural Building startup provider
deterministic candidate generation
shared Wizard mutation port over the exact canonical timeline
reserved identity lifecycle
exact frozen preview-to-commit lifecycle
canonical ownership publication exactly once
semantic user-facing diff
rendering-neutral vector preview scene
deterministic SVG-compatible projection
application-level Wizard state machine
responsive mobile/tablet/desktop shell
provider-neutral candidate carousel
Project Hub start integration
Project Navigator contextual integration
canonical persistence/publication integration
restart-safe structural projection for Basic Building levels
post-commit navigation
error/recovery UX
accessibility across touch/pointer/keyboard
performance/rebuild discipline
qualification and architecture audit
P9 handoff without transaction redesign
```

None of these may be deferred to P9 when the requirement belongs to common Wizard infrastructure.

---

# 2. RBAC/access baseline for P8 v1

RBAC is explicitly outside P8 v1 scope.

P8 currently treats authoring availability as runtime/capability availability only:

```text
application locally unlocked
+ canonical production runtime ready
+ explicit valid Wizard target
+ provider supports that target
= Wizard available
```

P8 MUST NOT introduce role/permission checks inside:

```text
WizardProvider
WizardProviderRegistry
WizardSessionController
WizardCandidateCoordinator
ApplyWizardCandidateCommand
ProjectWizardMutationPort
ReservedProjectMutationCoordinator
ProjectMutationSession
```

Provider availability means:

```text
provider capability + target/runtime compatibility
```

It does not mean user authorization.

Future RBAC may be inserted at a higher composition/application entry boundary before Wizard entry and/or Apply, but it must not require changing candidate, diff, preview, identity, transaction, Undo or SVG contracts.

No RBAC implementation or RBAC qualification is required for P8 completion.

Mandatory qualification instead proves that absence of role data does not disable P8 when canonical runtime is valid.

---

# 3. Mandatory UX contract

The responsive/carousel specification is not optional styling guidance.

P8 MUST support:

```text
compact   < 600 logical px
medium    600..899
expanded  900..1399
wide      >= 1400
```

using actual Wizard surface width, not device/OS detection.

Session state must survive:

```text
phone orientation change
tablet orientation change
split screen
Stage Manager/window resize
desktop live resize
```

without candidate regeneration, new identity allocation or semantic state loss.

The provider-neutral candidate carousel is mandatory common P8 infrastructure so P9 apartment variants can plug in directly.

The carousel MUST support:

```text
touch swipe
mouse click
trackpad horizontal navigation
keyboard Left/Right/Home/End
snap to one stable candidate
stable WizardCandidateId selection
screen-reader semantics
selected state not relying on color alone
```

Candidate cards use `WizardPreviewScene`; SVG/vector output is presentation only and never canonical project data.

---

# 4. Mandatory candidate lifecycle

P8 separates lightweight provider variants from a prepared canonical preview.

Required lifecycle:

```text
typed parameters
→ normalize + validate
→ pure provider candidate/variant set
→ WizardCandidateId + WizardPreviewScene
→ optional carousel browsing
→ select one candidate
→ prepare selected candidate
→ reserve durable identities once
→ canonical preview + semantic diff
→ explicit user confirmation
→ stale LocalProjectVersion check
→ commit exact frozen preview
→ exactly one ProjectChangeSet
→ exactly one Undo record
→ canonical ownership/persistence path
```

For a provider with one candidate, the variant-selection stage may be skipped.

Carousel browsing MUST NOT allocate durable project IDs simply because cards are visible.

No provider regeneration occurs during Apply.

Forbidden patterns:

```text
Widget → createBuilding() → createLevel() → createLevel() ...
Widget-side direct ProjectAggregate mutation
preview-side repository writes
allocate durable IDs for every carousel card by default
regenerate candidate during Apply
allocate replacement IDs during Apply
silently rebase stale candidate
special Wizard persistence repository
SVG → canonical geometry reconstruction
```

---

# 5. Mandatory shared mutation port

The production Wizard MUST use the exact same `ProjectMutationSession` timeline and Undo/Redo history as ordinary canonical authoring.

`ProjectStructureAuthoringSession` currently encapsulates this session; P8 must add a dedicated application-level Wizard mutation port instead of constructing a second session from `session.project`.

Conceptually:

```text
ProjectStructureAuthoringSession
        └── ProjectWizardMutationPort
                └── ReservedProjectMutationCoordinator
                        └── exact same ProjectMutationSession
```

Required properties:

```text
same LocalProjectVersion
same Undo/Redo stack
same EntityIdFactory source
foreign preview rejected
reserved IDs stable
no raw private mutation session leaked to Flutter
```

This is mandatory before candidate coordinator implementation is production-safe.

---

# 6. Mandatory canonical ownership publication

A successful Wizard commit is not production-owned merely because the mutation session advanced.

Required integration sequence:

```text
commitPreview(exact prepared preview)
→ ProjectMutationResult
→ record one canonical document-history commit
→ generic onCanonicalMutationCommitted(session, result)
→ canonical owner accepts exact aggregate/version
→ post-commit navigation/materialization
→ normal save/autosave
```

P8 MUST reuse the existing generic canonical ownership callback. It must not create a Wizard-specific persistence repository.

Production Apply is enabled only when exact canonical ownership is available.

This is capability gating, not RBAC.

---

# 7. Mandatory production runtime contract

The production Wizard requires canonical runtime ownership from the moment a candidate is prepared.

The normal application path opens `PlatformProjectHubScreen`, which initializes the canonical `ProjectRepository` and passes it into `ProjectHubScreen`.

P8 formalizes:

```text
production Project Hub
→ canonical ProjectRepository available
→ canonical bootstrap/owner available
→ Wizard canonical preview/apply available
```

The nullable `canonicalProjectRepository` constructor seam on `ProjectHubScreen` is compatibility/test infrastructure and MUST NOT become a second production Wizard mode.

Required behavior:

```text
canonical repository available
  → Wizard may be enabled

canonical repository unavailable in a test/legacy host
  → Wizard canonical generation disabled/fails closed
  → no fallback to legacy widget-side generation
```

A Wizard provider must never mutate `EditorProjectDocument`/`EditorBuildingWorkspace` because canonical runtime is missing.

---

# 8. Basic Building P8 v1 scope

The current editor cutover supports exactly one bound editable Building workspace.

Therefore P8 v1 `BasicBuildingWizardProvider` is a startup provider first:

```text
NewProjectWizardTarget → supported
```

Creating a second Building in an already-bound existing Site is NOT exposed by P8 v1 until multi-building runtime switching/materialization is qualified.

Generic Wizard contracts still support Site/Building/Level target types for future providers.

The Navigator may expose the generic Wizard action, but provider registry must return only providers actually supported by the active runtime target.

No dead Basic Building option is shown where the resulting Building cannot be opened.

---

# 9. Compatibility seed normalization

Current new-project bootstrap creates a compatibility Building + Level 1 before canonical runtime opens.

For the startup Basic Building Wizard:

```text
bound compatibility BuildingId is reused as the user's first Building
bound Building is renamed/updated rather than deleted/recreated
bound initial LevelId is reused for the semantic first/reference Level when compatible
additional Levels use reserved persistent identities
placeholder labels are not presented as authored Wizard output before Apply
```

P8 must not delete/recreate the bound seed Building simply to make diff output look cleaner.

Stable binding takes precedence over cosmetic implementation simplicity.

The seed remains transitional and may disappear after legacy workspace retirement without changing Wizard contracts.

---

# 10. Structural projection/materialization requirement

Current `ExistingBindingCanonicalEditorMaterializer` cannot open a new canonical Level without a legacy runtime binding.

Therefore Basic Building is not complete when canonical Apply succeeds; every committed startup Level must become openable in the production editor.

P8 adds a transitional structural projection/materialization boundary outside WizardProvider:

```text
committed canonical Building/Level structure
→ deterministic legacy structural projection
→ preserve existing geometry/spaces
→ create empty legacy shell for new Levels
→ maintain exact canonical<->legacy identity binding
→ persist through normal canonical-owning store policy
```

Canonical state remains authoritative. The legacy representation is a projection only.

No apartment/room geometry is invented by this Basic Building projector.

---

# 11. Restart-safe canonical/legacy identity bridge

New P8 Levels receive stable IDs from `EntityIdFactory`/reservation.

The legacy structural representation must round-trip those exact IDs across save/reopen.

P8 must implement one centralized strategy:

```text
A. versioned canonical identity encoded in transitional legacy structural IDs
or
B. separately persisted canonical<->legacy binding map
```

Whichever strategy is selected, qualification must prove:

```text
old migrated legacy IDs remain supported
new Wizard LevelId survives save/reopen unchanged
level number/name never acts as identity
malformed bridge data fails closed
```

Scattered ad-hoc string parsing is forbidden.

---

# 12. New Project / Cancel semantics

Current Project Hub persists the project container/compatibility seed before editor use.

P8 v1 therefore defines:

```text
New Project creates the durable project container/seed.
Wizard configures that project.
Cancel cancels Wizard mutation only.
Cancel preserves the pre-Wizard canonical fingerprint.
Cancel does not promise deletion of the newly created project container.
```

The project can reopen into the startup gate as unconfigured.

If future product requirements demand `Cancel New Project = no project on disk`, that requires a separate multi-store project-creation transaction and cleanup contract.

---

# 13. Level numbering contract

P8 v1 uses a typed numbering convention, not an ambiguous boolean.

Recommended baseline contract:

```dart
enum WizardLevelNumberingConvention {
  oneBasedGround,
  zeroBasedGround,
}
```

Default:

```text
oneBasedGround
above-ground Levels: 1..N
Level 1 elevation: 0 mm
basements: -1..-B
```

For `zeroBasedGround`:

```text
Level 0 elevation: 0 mm
remaining above-ground Levels: 1..N-1
basements: -1..-B
```

The exact interpretation of `aboveGroundLevelCount` is part of tests and cannot vary by locale.

---

# 14. Mandatory preview contract for every provider

Every production provider must supply a meaningful `WizardPreviewScene`, even if it does not generate floor-plan geometry.

For Basic Building the preview SHOULD be a deterministic schematic building/elevation stack derived from the same mutation plan:

```text
Building
├── Level +N
├── ...
├── reference Level
├── Basement -1
└── Basement -N
```

The schematic may show level names/codes, elevations and counts. It is derived from semantic candidate data and is never a second source of truth.

P9 Apartment providers use the same preview infrastructure for spatial apartment topology and the SVG/vector carousel.

---

# 15. Persistence/recovery contract

`CanonicalOwningEditorProjectStore` persists canonical sidecar before legacy document. P8 keeps canonical state authoritative.

For Basic Building structural projection:

```text
1. build and validate legacy structural projection in memory;
2. canonical commit is accepted by owner;
3. canonical owner is saved by normal path;
4. projected legacy document is saved;
5. if legacy projection/save fails, do not invent canonical rollback;
6. do not present unsupported target as openable;
7. provide retry/recovery path;
8. save/reopen must restore exact canonical LevelIds.
```

Qualification must include canonical-ahead-of-legacy structural recovery.

---

# 16. Mandatory execution decomposition

Implementation follows WP00..WP16 plus audit prerequisites A0..A8.

Audit prerequisites:

```text
A0 RBAC-free access baseline accepted
A1 shared Wizard mutation port designed
A2 canonical ownership publication path designed
A3 Basic Building v1 scope fixed to startup capability
A4 compatibility seed reuse policy fixed
A5 structural Level projection strategy fixed
A6 restart-safe canonical<->legacy Level binding fixed
A7 variant-set vs prepared-preview lifecycle fixed
A8 level numbering contract fixed
```

Then:

```text
WP00 readiness/spec freeze
WP01 typed contracts
WP02 provider registry
WP03 responsive primitives
WP04 Basic Building provider
WP05 composite reserved mutation bridge
WP06 candidate coordinator
WP07 semantic diff
WP08 vector preview/SVG
WP09 session state machine
WP10 responsive Wizard shell
WP11 candidate carousel
WP12 Project Hub integration
WP13 Navigator integration
WP14 persistence/publication + structural projection
WP15 recovery/accessibility/performance
WP16 qualification/closure/P9 handoff
```

Each package is incomplete until its specified tests and exit evidence are green.

---

# 17. Traceability requirement

Every production requirement must be traceable through:

```text
requirement/invariant
→ owning work package
→ source file/class
→ automated test or qualification scenario
→ exit gate
```

Minimum traceability:

```text
RBAC-free baseline                     → A0/WP02    → P8-Q080..081
shared canonical timeline              → A1/WP05    → P8-Q082..083
owner acknowledgement exactly once     → A2/WP14    → P8-Q084
seed Building identity reuse           → A4/WP04    → P8-Q085
seed Level reuse when compatible        → A4/WP04    → P8-Q086
new Level openable after Apply          → A5/WP14    → P8-Q087
new Level ID stable after reopen        → A6/WP14    → P8-Q088
no unsupported second Building option   → A3/WP02    → P8-Q089
carousel browsing reservation-free      → A7/WP06/11 → P8-Q090
selected final preview reserves once    → A7/WP06    → P8-Q091
startup Cancel fingerprint unchanged    → WP12       → P8-Q092
projection recovery                     → WP14/15    → P8-Q093
malformed bridge fails closed           → A6/WP15    → P8-Q094
one canonical state                     → WP05/WP06  → P8-G05
preview side-effect free                → WP06       → P8-Q001..006
exact frozen candidate commit           → WP05/WP06  → P8-Q013
one Apply = one Undo                    → WP05/WP14  → P8-Q007..010
stale preview blocked                   → WP06/WP09  → P8-Q011
semantic human diff                     → WP07       → P8-G06
SVG projection only                     → WP08       → P8-Q040..043
responsive session preservation         → WP03/WP10  → P8-Q050..056
carousel stable candidate selection     → WP11       → P8-Q057..063
Project Hub canonical integration       → WP12/WP14  → P8-Q070..071
Navigator explicit target               → WP13       → P8-Q072..073
save/reopen fingerprint                 → WP14/WP16  → P8-Q074
P9 no architecture redesign             → WP16       → architecture audit
```

---

# 18. Definition of Ready

Coding P8 feature logic may proceed when:

```text
specification pack committed
technical audit accepted as normative
A0..A8 resolved at design level
WP01 public contract naming accepted
P8/P9/P10 ownership boundary accepted
ReservedProjectMutationCoordinator confirmed as mandatory backbone
legacy new-project seed explicitly transitional
responsive/carousel contract mandatory
production canonical runtime requirement accepted
```

UI implementation is not the first production task.

---

# 19. Definition of Done

P8 is complete only when:

```text
all audit Critical/High findings are closed
all WP00..WP16 exit gates are green
all P8 completion gates are green
mandatory qualification scenarios pass
existing canonical mutation/persistence/navigation regressions pass
mobile/tablet/desktop flows are first-class
candidate carousel is reusable with 3..6 mock candidates
one full Basic Building startup Wizard vertical slice works end to end
all created startup Levels are openable after Apply
all created startup LevelIds survive save/reopen unchanged
Basic Building provider proves meaningful vector preview before P9
Undo/Redo reverses/restores the whole Wizard operation in one step
save/reopen preserves canonical semantic fingerprint
production Wizard has no legacy-only fallback path
RBAC remains non-enforcing in P8 v1
architecture audit proves P9 can plug in without transaction/preview/carousel redesign
```

Final acceptance question:

> Can P9 add `ApartmentWizardParameters + ApartmentTopologyGenerator + Apartment provider` and immediately obtain the existing responsive carousel, preview, diff, Apply, stale-version, Undo and persistence behavior without modifying their core contracts?

If the answer is no, P8 is not finished.
