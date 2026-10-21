# Project Structure Authoring — Pre-implementation Plan v1

## Status

Execution plan for converting the current ElecX editor runtime into the architecture required by `feat/project-structure-authoring`.

This document is subordinate to:

- `docs/architecture/native-project-portability-and-sync.md`
- `docs/architecture/project-composition-foundation-decisions-v1.md`

It exists to prevent direct implementation of the new UX on top of transitional single-building / level-number / wall-index ownership.

## Current-runtime findings

The current runtime is useful as a compatibility layer but not as the final foundation.

Known transitional constraints:

```text
EditorBuildingWorkspace
- owns one ComposedBuilding
- also owns ComposedProjectSite containing Building copies
- active level is selected by levelNumber
- openings are keyed by levelNumber
- synchronizes editor state by rebuilding Building/ComposedBuilding/Site copies

EditorProjectDocument
- persists one full ComposedBuilding plus Site
- stores activeLevelNumber
- stores openings by level number
- combines document codec and native file-store concerns in one implementation area

BuildingLevelRepeater
- clones entities using level-number-prefixed String IDs
- does not represent typical-floor lineage

UnifiedSiteNavigator / SiteNavigationProjection
- projects one active ComposedBuilding
- uses level-number-derived tree IDs
- contains demo-specific expansion behavior

RoomSurfaceRef / EngineeringSpace.wallProfiles
- durable wall references are based on wallIndex
```

These behaviors are not to be expanded by the new authoring feature.

## Target module boundaries

```text
lib/src/domain/project/
├── ids.dart
├── project_aggregate.dart
├── site_aggregate.dart
├── building_aggregate.dart
├── level_model.dart
├── space_model.dart
├── structural_zone.dart
├── boundary_topology.dart
├── opening_model.dart
├── vertical_core.dart
├── project_index.dart
└── validation.dart

lib/src/application/project/
├── entity_id_factory.dart
├── project_repository.dart
├── project_command.dart
├── project_mutation_session.dart
├── project_change_set.dart
├── project_navigation_state.dart
└── undo_manager.dart

lib/src/serialization/project/
├── project_document.dart
├── project_document_codec.dart
└── migrations/

lib/src/infrastructure/project/
├── json_project_repository.dart
└── drift_project_repository.dart   // later P16

lib/src/features/editor/
├── adapters to canonical project state
├── navigator projection
├── Room Surface Navigator projection
└── native interaction UI
```

Exact file names may differ, but dependency direction must remain equivalent.

## P0 — contract-test preparation

Before production refactor, add tests that capture current data needed for safe migration while asserting target invariants.

Required tests:

```text
P0-01 legacy project can be loaded
P0-02 ProjectId != SiteId in target fixture
P0-03 two Buildings can each contain a visually named Floor 2
P0-04 renumber does not imply identity replacement
P0-05 failed mutation fingerprint unchanged
P0-06 selected wall removed cannot silently select another edge
P0-07 legacy JSON fixture remains available for migration testing
```

Do not freeze incorrect legacy behavior such as level-number identity as a desired contract.

## P1A — typed identities

Introduce zero/low-behavior typed wrappers first.

Minimum:

```text
ProjectId
SiteId
BuildingId
LevelId
ZoneId
SpaceId
BoundaryEdgeId
OpeningId
VerticalCoreId
ServiceEntryId
ComponentId
CircuitId
RouteId
GenerationId
TemplateId
```

Requirements:

- value equality;
- deterministic serialization to string;
- validation of non-empty representation;
- no domain meaning encoded in textual ID format;
- ID values generated only by `EntityIdFactory` for new persistent entities.

### Compatibility

Legacy string IDs may be wrapped during migration without immediate re-keying if they are unique and valid.

New IDs must not be generated as:

```text
room-$counter
opening-$counter
L$levelNumber:$oldId
building-$projectId
```

## P1B — canonical ProjectAggregateRoot

Introduce authoritative state without immediately deleting legacy workspace classes.

Conceptual API:

```dart
final class ProjectAggregateRoot {
  final ProjectId id;
  final SiteId siteId;
  final LocalProjectVersion version;
  final ProjectEntityStores stores;
  final ProjectIndex index;
}
```

`ProjectEntityStores` may contain immutable maps rather than one nested giant object.

Minimum direct lookup:

```text
BuildingId → BuildingAggregate
LevelId → LevelEntity
SpaceId → SpaceEntity
BoundaryEdgeId → BoundaryEdge
OpeningId → Opening
```

### Invariant

There is no independent mutable copy of one Building inside both Site and Workspace.

## P1C — LocalProjectVersion + ProjectIndex

Every successful canonical commit increments `LocalProjectVersion` exactly once.

Every command carries `expectedVersion`.

ProjectIndex must support O(1)/indexed lookups for navigator/editor hot paths.

Required index integrity tests run after every candidate commit in debug/test builds.

## P2A — ProjectRepository interface

Introduce the application boundary before moving persistence internals.

Conceptually:

```dart
abstract interface class ProjectRepository {
  Future<ProjectSnapshot?> load(ProjectId projectId);
  Future<void> save(ProjectSnapshot project);
  Future<List<ProjectSummary>> list();
}
```

Feature code depends only on this interface.

## P2B — ProjectDocumentCodec

Move encode/decode/migration responsibilities behind a codec boundary.

```text
ProjectAggregate/ProjectSnapshot
↕
ProjectDocumentCodec
↕
versioned document representation
```

`dart:io` and `path_provider` are forbidden in codec/domain/application code.

## P2C — Legacy JSON adapter

Current JSON persistence becomes an infrastructure adapter.

Responsibilities:

- native filesystem path;
- temp/backup atomic replacement;
- document codec invocation;
- corrupt-file isolation in project listing.

Preserve existing recovery behavior where valid.

## P2D — multi-building document shape

Migrate from:

```text
one full building + site containing Building copies
```

to:

```text
project metadata
site metadata/relations
full building store
engineering graph
resume state
```

ProjectId is always serialized explicitly and is never derived from SiteId.

## P3 — canonical mutation engine

Introduce:

```text
ProjectCommand
ProjectMutationRequest
ProjectMutationSession
CandidateGraphValidator
ProjectChangeSet
UndoRecord
```

Commit protocol:

```text
read version N
→ build candidate against N
→ validate
→ compare current version
→ if still N: commit + version N+1
→ publish ProjectChangeSet
→ append UndoRecord
```

No widget directly edits canonical entity stores.

## P4 — structural authoring commands

Implement application commands before buttons/dialogs.

Required first wave:

```text
CreateBuilding
RenameBuilding
CreateLevel
RenameLevel
Renumber/ReorderLevel
CreateStructuralZone
CreateSpace
RenameSpace
ChangeSpaceType
ChangeSpaceUsage
RemoveSpace
```

Then destructive commands with dependency checks.

### Room rectangle reuse

Existing rectangle gesture remains useful only as interaction collection:

```text
pointer gesture
→ rectangle candidate
→ CreateSpaceCommand
```

It must no longer directly append an `EngineeringSpace` into `EditorController.level` as the final authoring path.

## P5 — navigation projection and authoring UX

Introduce one `ProjectNavigationState`:

```text
active SiteId
active BuildingId
active LevelId
selected ZoneId?
selected SpaceId?
```

Navigator tree, breadcrumb and editor derive from it.

### Project Navigator

Target desktop layout:

```text
PROJECT

Site
├── Building A
│   ├── B1
│   ├── Floor 1
│   ├── Floor 2      ← CURRENT
│   │   └── Bedroom  ← SELECTED
│   └── Roof
└── Building B

[ + Building ]
[ + Level ] [ + Room ]
[ Wizard ]
```

Remove:

- hard-coded `building-a` expansion;
- level-number canonical node IDs;
- one-building projection API as the target path.

### Room Surface Navigator shell

P5 may implement:

- visibility/collapse shell;
- Plan/Floor/Ceiling controls;
- lightweight room projection;
- read-only transitional wall highlighting where safe.

Durable wall-host actions must wait for P7 stable boundary-edge identity.

## P6 — semantic spaces / adjacency / overlays

Introduce canonical `SpaceUsage` and migrate old spaces safely.

Introduce structural zone vs overlay classification separation.

Harden opening/adjacency contracts.

Do not derive room semantics from translated display labels.

## P7 — stable boundary topology + vertical topology + typical floors

### Boundary topology

Introduce `BoundaryEdgeId` and edge lineage.

Polygon edit result must report:

```text
preserved edge mapping
split edge mapping
merged edge mapping
created edges
removed edges
```

Hosted objects are remapped/conflicted through that mapping.

### Vertical topology

Replace level-number keys with LevelId-backed nodes and physical transition anchors.

### Typical floors

Replace `L$levelNumber:*` identity generation with EntityIdFactory + explicit definition/instance lineage.

## P8+ — Wizard and generation

Only after P1-P7 applicable gates pass:

```text
Typed WizardParameters
→ GeneratedProjectCandidate
→ validate
→ diff
→ preview
→ version guard
→ atomic ProjectChangeSet
```

No Wizard code mutates `EditorBuildingWorkspace` directly.

## Compatibility-adapter strategy

Do not perform a Big Bang rewrite of the editor.

Use adapters:

```text
Canonical ProjectAggregate
        ↓
LegacyEditorWorkspaceAdapter
        ↓
existing canvas/editor while migration proceeds
```

The adapter may project one active Building/Level into the old editor, but all committed structural changes return through canonical commands.

The adapter must be removable; no new domain semantics may be implemented only inside it.

## Pre-implementation test matrix

Before starting P4 UI, all must pass:

```text
T01 create two Buildings
T02 create Floor 2 in both Buildings
T03 IDs differ and navigation remains unambiguous
T04 create Room through command → one change-set/undo
T05 duplicate Level display number rejected within one Building
T06 renumber Level preserves LevelId and dependencies
T07 failed command leaves fingerprint unchanged
T08 stale LocalProjectVersion rejected
T09 save/reopen multi-building fingerprint equal
T10 ProjectId remains distinct from SiteId
T11 legacy JSON fixture migrates
T12 same selected Room resolves through ProjectIndex
T13 wall edge removal cannot silently reuse old wall index semantics
```

## Definition of foundation ready

Foundation is READY for authoring UI only when:

```text
- typed IDs are active in new application contracts;
- one canonical ownership model exists;
- LocalProjectVersion exists;
- ProjectIndex exists;
- ProjectRepository + codec boundary exists;
- multi-building persistence shape exists;
- ProjectCommand/ChangeSet/Undo path exists;
- failed mutation fingerprint tests pass;
- legacy editor can operate through adapter without becoming source of truth.
```

## Non-negotiable conclusion

Implementation starts by replacing ownership and identity assumptions, not by adding more buttons to `UnifiedSiteNavigator` or more direct mutations to `EditorController`.

The safe migration path is:

```text
legacy runtime
   ↓ adapters
canonical aggregate + IDs
   ↓
repository + codec
   ↓
command/change-set/undo
   ↓
structural authoring UI
   ↓
navigator + Room Surface Navigator
   ↓
Wizard/generation
```
