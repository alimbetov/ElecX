# P8 Wizard + Preview/Diff Technical Audit v1

## Status

Normative technical audit for `feat/p8-wizard-preview-diff`.

Audit basis:

- branch diff against `main`;
- current P8 specification pack;
- canonical mutation/runtime/persistence code already present in the repository;
- explicit product assumption that RBAC is **not enforced in P8 v1**.

This audit is not a replacement for the P8 implementation specification. It records integration blockers and mandatory corrections discovered by comparing the specification with the current production runtime.

---

# 1. Branch status

At audit time the branch is specification-only.

```text
main -> feat/p8-wizard-preview-diff
6 commits ahead
0 commits behind
production code changes: 0
production tests added: 0
architecture/specification files added: 5+
```

Therefore the branch has high design maturity but implementation readiness is conditional on the runtime blockers below being addressed first.

---

# 2. Access-control scope: RBAC explicitly out of P8 v1

P8 v1 does not introduce role-based authorization.

Current repository code has no authoritative project-authoring RBAC contract (`role`, `permission`, `RBAC` are not part of the canonical mutation API).

Mandatory P8 rule:

```text
local/unlocked application session
+ canonical runtime available
+ valid explicit Wizard target
+ provider capability available
= Wizard may be used
```

P8 MUST NOT add conditions such as:

```text
role == engineer
role == admin
hasPermission('wizard.apply')
canEditBuildingByRole
```

inside:

```text
WizardProvider
WizardProviderRegistry
WizardSessionController
ApplyWizardCandidateCommand
ReservedProjectMutationCoordinator
ProjectMutationSession
```

`WizardProviderRegistry` availability in P8 is **capability/target/runtime availability**, not authorization.

Future RBAC may wrap Wizard entry/apply at a higher application/composition boundary, but it must not require redesign of:

```text
candidate generation
preview/diff
identity reservation
semantic diff
SVG/vector preview
transaction/undo protocol
```

No RBAC implementation is required for P8 exit gates.

---

# 3. Executive findings

## Critical

```text
C1 production Wizard mutation port is missing
C2 generic canonical ownership publication is not yet wired for Wizard
C3 new structural entities are not materializable in the current legacy editor runtime
```

## High

```text
H1 Basic Building v1 target scope is too broad for current single-building cutover
H2 new-project compatibility seed reuse policy must be explicit
H3 new canonical Level identity needs a restart-safe canonical<->legacy bridge
H4 variant carousel and reserved canonical preview must be two lifecycle phases
H5 Project Hub start semantics must define what Cancel means for the project container
```

## Medium

```text
M1 level numbering contract is still ambiguous
M2 persistence/recovery qualification must cover canonical-ahead-of-legacy structure
M3 provider availability must not be confused with future authorization
M4 implementation readiness cannot be inferred from specification completeness
```

---

# 4. C1 — production Wizard mutation port is missing

## Observation

`ReservedProjectMutationCoordinator` requires the exact `ProjectMutationSession` that owns canonical version/history.

Production runtime exposes `ProjectStructureAuthoringSession`, which internally owns that mutation session but keeps it private.

This is correct encapsulation, but P8 currently has no supported path to construct its reserved coordinator over the same canonical timeline.

## Risk

A naive implementation may create another `ProjectMutationSession` from `session.project`.

That would create:

```text
second version timeline
second Undo stack
stale preview behavior disconnected from editor history
foreign aggregate instances
persistence-owner rejection
```

This is prohibited.

## Required correction

Introduce a dedicated application-level Wizard mutation port owned by `ProjectStructureAuthoringSession` (exact class name may differ):

```dart
abstract interface class ProjectWizardMutationPort {
  ProjectAggregateRoot get project;
  LocalProjectVersion get version;

  ReservedProjectMutationPreview preview(ReservedProjectCommand command);

  ReservedProjectMutationCommitResult? commitPreview(
    ReservedProjectMutationPreview preview,
  );
}
```

Implementation requirements:

```text
uses the exact same ProjectMutationSession instance
uses the exact same EntityIdFactory source
uses one ReservedProjectMutationCoordinator bound to that session
never exposes a second mutable aggregate
```

`ProjectStructureAuthoringSession` may expose this port, but it MUST NOT expose raw private mutation internals merely for P8 convenience.

## Gate

New prerequisite gate:

```text
P8-G00A Wizard mutation port shares exact canonical timeline
```

Tests:

```text
wizard_mutation_port_same_version_test.dart
wizard_mutation_port_shared_undo_test.dart
wizard_mutation_port_foreign_preview_test.dart
```

---

# 5. C2 — canonical ownership publication is not yet wired for Wizard

## Observation

Production canonical ownership requires every committed canonical mutation to pass through the existing generic callback:

```text
onCanonicalMutationCommitted
```

`CanonicalProjectPersistenceOwner.acceptMutation()` requires the exact committed aggregate instance and contiguous version transition.

The current navigator path explicitly publishes authoring results after session mutation.

P8 Apply must do the same.

## Risk

If Wizard commits through `ReservedProjectMutationCoordinator` but does not call the generic canonical ownership callback:

```text
ProjectStructureAuthoringSession.project advances
CanonicalProjectPersistenceOwner remains on old version
save rejects/diverges
later mutations become inconsistent
```

## Required correction

Do not invent a special Wizard repository or a parallel ownership callback.

The P8 presentation/integration host must perform:

```text
commitPreview()
→ ProjectMutationResult
→ record one canonical document-history commit
→ onCanonicalMutationCommitted(session, result)
→ reconcile/adopt post-commit navigation
→ rematerialize/push canonical projection where supported
→ normal save/autosave path
```

Wizard application/domain code must not import the production callback type.

The callback remains an outer production composition concern.

Apply is enabled in production only when exact canonical ownership is available.

This requirement is runtime capability gating, not RBAC.

## Gate

```text
P8-G00B Wizard commit reaches canonical ownership exactly once
```

Tests:

```text
wizard_commit_owner_ack_test.dart
wizard_commit_owner_version_test.dart
wizard_commit_history_single_record_test.dart
```

---

# 6. C3 — structural materialization gap

## Observation

The current editor cutover is explicitly transitional and single-building.

`CanonicalEditorWorkspaceBinding` binds exactly one editable canonical Building to one legacy `EditorBuildingWorkspace`.

`ExistingBindingCanonicalEditorMaterializer` only treats already-bound levels/spaces as openable.

A new canonical Level with no legacy binding returns:

```text
blockedMissingRuntimeRepresentation
```

A canonical Building other than the currently bound Building is also rejected.

## Consequence

Without an additional P8 integration layer the following sequence is possible:

```text
Wizard preview valid
→ Apply succeeds canonically
→ new Level appears in canonical navigator
→ user selects new Level
→ legacy editor cannot open it
```

That is not acceptable as a completed P8 vertical slice.

## Required correction

P8 must add a **structural projection/materialization bridge for the new-project flow**.

The bridge is not allowed to become a second project model. Canonical state remains authoritative.

Recommended responsibilities:

```text
canonical committed Building/Level structure
→ project a compatible legacy structural shell
→ preserve existing bound geometry/spaces
→ create legacy representation for new empty Levels
→ maintain restart-safe canonical<->legacy identity binding
→ save through existing canonical-owning project store policy
```

The structural projector must be deterministic and independently testable.

Conceptual API:

```dart
abstract interface class CanonicalLegacyStructureProjector {
  EditorProjectDocument projectStructure({
    required EditorProjectDocument currentLegacy,
    required ProjectAggregateRoot canonical,
    required CanonicalEditorWorkspaceBinding binding,
  });
}
```

Exact location/API may differ. It belongs in the transitional editor/infrastructure integration layer, never inside WizardProvider.

## Gate

```text
P8-G00C every Basic Building committed Level can be reopened in production editor
```

Tests:

```text
wizard_level_structural_projection_test.dart
wizard_level_reopen_binding_test.dart
wizard_structure_projection_preserves_existing_spaces_test.dart
```

---

# 7. H1 — Basic Building v1 target scope must be narrowed

## Observation

The P8 documents define a general Site/Building target model and suggest that Basic Building can create hierarchy under a Site.

Current editor runtime supports one editable legacy Building workspace and fails closed for another canonical Building.

## Required v1 decision

`BasicBuildingWizardProvider` in P8 v1 is primarily a **New Project startup provider**.

Supported production scope for P8 v1:

```text
NewProjectWizardTarget -> YES
```

Existing project `SiteWizardTarget -> create second Building`:

```text
NOT exposed until multi-building workspace switching/materialization is qualified
```

The generic provider contracts continue to support Site/Building/Level scopes for P9/P10 and future work.

The Navigator may expose a generic Wizard entry, but it only shows providers actually supported for the active target.

No dead Basic Building option should be shown where the runtime cannot open the resulting Building.

---

# 8. H2 — compatibility seed must be reused, not destroyed casually

## Observation

Current new-project creation persists a legacy `EditorBuildingWorkspace.blank()` containing one Building and Level 1 before canonical bootstrap.

That Building/Level also defines the initial canonical<->legacy binding.

Deleting the seed Building and replacing it with a new UUID Building would immediately break the current editable workspace binding.

## Required v1 mapping

For `NewProjectWizardTarget`, Basic Building generation must treat the compatibility seed as an implementation host and normalize it into the user's first authored hierarchy.

Mandatory behavior:

```text
reuse bound canonical BuildingId for the first/user Building
rename/update it as needed
reuse bound initial LevelId for the semantic first/reference Level when compatible
create additional Levels as new reserved identities
never expose placeholder seed labels as authored output before Apply
```

If a requested numbering convention cannot safely reuse the seed Level, the provider must either transform that Level by stable ID or fail closed; it must not silently delete/recreate the bound identity.

This rule is transitional and may be removed once the editor no longer depends on the legacy seed.

---

# 9. H3 — restart-safe identity bridge for newly materialized Levels

## Observation

Initial legacy bootstrap derives canonical IDs deterministically from legacy IDs.

New P8 Levels use `EntityIdFactory`/reservation and therefore have canonical UUID-like identities.

If P8 creates a new legacy Level using an unrelated legacy ID, the next bootstrap cannot reconstruct the same canonical LevelId and sidecar validation will diverge.

## Required correction

Introduce a transitional canonical identity marker/codec for P8-created legacy structural shells, or an equivalent persisted binding mechanism.

Recommended v1 direction:

```text
new canonical LevelId
→ encode canonical identity into a reserved legacy bridge ID form
→ on bootstrap/binding reconstruction detect bridge ID
→ recover exact canonical LevelId
```

Example concept only:

```text
legacy level id = canonical-level:<escaped canonical LevelId>
```

The precise encoding must be centralized and versioned; string parsing must not be scattered through UI code.

Requirements:

```text
old legacy IDs keep deterministic migration behavior
new bridge IDs round-trip exact canonical identity
no display label/level number participates in identity
malformed bridge IDs fail closed
```

Alternative: persist a separate binding map. If chosen, it must have equally strong restart/recovery qualification.

## Gate

```text
P8-G00D committed Wizard Level keeps same LevelId after save/reopen
```

---

# 10. H4 — carousel variants and reserved canonical previews are separate phases

## Observation

P9 will generate 3..6 apartment topology variants for carousel browsing.

Persistent identity reservation is needed for the exact final preview/apply lifecycle, not for every lightweight variant card.

## Required lifecycle

```text
provider parameters
→ pure provider variant set
→ WizardCandidateId + WizardPreviewScene for each variant
→ carousel browsing/selection
→ selected variant prepared for canonical preview
→ reserve durable IDs once
→ frozen canonical preview + semantic diff
→ Apply exact prepared preview
```

Do not allocate permanent entity reservations for every carousel card merely because it is visible.

Changing carousel selection before final preparation is side-effect free and reservation-free.

If the user returns to a previously prepared variant during the same unchanged generation set, reuse policy may be implemented, but it must remain explicit and bounded.

This split keeps P8 scalable and prevents candidate browsing from being conflated with canonical mutation preparation.

---

# 11. H5 — New Project / Cancel semantics

## Observation

Current Project Hub creates and saves the initial legacy project document before opening the editor.

The canonical bootstrap also persists the initial canonical sidecar before write capability is exposed.

Making Wizard the startup experience does not automatically make project creation itself transactional.

## P8 v1 decision

Unless a separate multi-store draft transaction is implemented, define Cancel precisely:

```text
New Project command creates the durable project container/compatibility seed.
Wizard then configures that project.
Cancel cancels Wizard mutation only.
Cancel does not promise deletion of the newly created project container.
```

The user-visible project remains structurally blank/unconfigured from the P8 perspective and can reopen the startup gate.

If product later requires "Cancel New Project leaves no project on disk", that is a separate project-creation transaction requirement and must atomically coordinate legacy store + canonical repository cleanup.

Do not imply that behavior without implementing it.

---

# 12. M1 — level numbering must be made exact

The current Basic Building wording leaves multiple interpretations around `createExplicitGroundLevel`.

P8 v1 should use a typed enum rather than a boolean with ambiguous semantics.

Recommended baseline:

```dart
enum WizardLevelNumberingConvention {
  oneBasedGround,
  zeroBasedGround,
}
```

Recommended default:

```text
oneBasedGround
above-ground: 1..N
first/reference Level elevation: 0 mm
basements: -1..-B
```

For `zeroBasedGround`:

```text
ground: 0 at 0 mm
upper levels: 1..N-1
basements: -1..-B
```

The exact interpretation of `aboveGroundLevelCount` must be tested for both modes.

No implicit localized "ground floor" convention may alter semantics.

---

# 13. Persistence/recovery sequence

Current `CanonicalOwningEditorProjectStore.save()` persists canonical sidecar first and legacy document second.

P8 structural projection must preserve the canonical-as-authority rule.

Required P8 behavior:

1. Build/validate the legacy structural projection in memory from the committed canonical state.
2. Persist canonical owner through the existing canonical save path.
3. Persist projected legacy document.
4. If legacy projection/save fails, do not roll back canonical state by inventing a second transaction protocol.
5. Keep the failure recoverable and do not present the new target as openable until projection succeeds.
6. On reopen, validation must detect/recover missing structural projection rather than silently bind by level number/name.

Qualification must include canonical-ahead-of-legacy structural recovery.

---

# 14. Revised implementation prerequisites

Before ordinary WP01 development is considered production-safe, close these audit prerequisites:

```text
A0 RBAC-free access baseline accepted
A1 shared Wizard mutation port designed
A2 canonical ownership publication path designed
A3 Basic Building v1 scope = NewProject startup
A4 compatibility seed reuse policy fixed
A5 structural Level projection strategy fixed
A6 restart-safe canonical<->legacy Level binding fixed
A7 variant-set vs prepared-preview lifecycle fixed
A8 level numbering contract fixed
```

These are specification corrections, not excuses to implement another architecture.

---

# 15. Revised critical path

```text
P8-A0 audit corrections/runtime bridge design
    ↓
WP01 typed Wizard contracts
    ↓
WP02 provider registry
    ↓
WP04 Basic Building plan with seed-reuse semantics
    ↓
WP05 shared reserved mutation port
    ↓
WP06 candidate coordinator
    ↓
WP08 preview scene
    ↓
Project Hub startup Wizard
    ↓
canonical commit ownership
    ↓
legacy structural projection + restart-safe binding
    ↓
open editor on exact committed structure
    ↓
WP07/WP09/WP10/WP11 hardening and UX
    ↓
qualification
```

Responsive primitives may still proceed in parallel once contracts stabilize.

---

# 16. Required additional qualification scenarios

```text
P8-Q080 RBAC absence does not hide/disable Wizard when runtime is otherwise ready
P8-Q081 provider registry capability result is independent of user role data
P8-Q082 Wizard preview and manual authoring share one LocalProjectVersion timeline
P8-Q083 Wizard Apply adds exactly one entry to the same Undo history
P8-Q084 Wizard Apply reaches CanonicalProjectPersistenceOwner exactly once
P8-Q085 Basic Building reuses bound seed BuildingId
P8-Q086 first compatible Level reuses bound seed LevelId
P8-Q087 additional Wizard Level is materialized/openable after Apply
P8-Q088 additional Wizard Level preserves LevelId after save/reopen
P8-Q089 second Building provider is not exposed in current single-building runtime
P8-Q090 carousel browsing allocates no durable entity reservation
P8-Q091 selected final candidate reserves IDs exactly once before final preview
P8-Q092 Cancel startup Wizard leaves canonical fingerprint unchanged from pre-Wizard seed
P8-Q093 canonical-ahead-of-legacy projection failure is detected/recoverable
P8-Q094 malformed canonical legacy-bridge ID fails closed
```

---

# 17. Technical readiness rating

After this audit:

```text
Specification architecture quality: high
Responsive/carousel contract: high
Canonical mutation foundation: high
P8 production runtime integration readiness: medium/blocked until C1-C3 resolved
RBAC dependency: none by design
Implementation completeness: not started
```

P8 should not begin with `WizardScreen` implementation.

The correct first implementation work is the shared mutation/ownership/materialization bridge, then typed Wizard contracts and Basic Building vertical slice.

---

# 18. Final audit decision

`feat/p8-wizard-preview-diff` is architecturally promising and consistent with the canonical ElecX direction, but it is **not yet implementation-ready without corrections** because the current transitional editor runtime cannot open newly generated structural hierarchy and the reserved Wizard mutation lifecycle is not exposed through the production authoring session.

RBAC is not a blocker and must remain outside P8 v1.

P8 becomes implementation-ready when C1-C3 and H1-H4 are incorporated into the normative specification and qualification gates.
