import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_space_semantics.dart';
import 'project_mutation.dart';
import 'project_space_semantics_commands.dart';
import 'project_structural_zone_commands.dart';

/// Narrow application capability for selected-space semantic authoring.
///
/// Presentation code never receives [ProjectMutationSession] directly. This
/// port translates semantic editing intents into the shared P3 mutation
/// timeline, preserving optimistic version checks, one ChangeSet and one Undo
/// boundary per semantic action.
abstract interface class ProjectSpaceSemanticsEditingPort {
  ProjectId get projectId;
  LocalProjectVersion get version;
  bool get canEdit;

  ProjectSpaceEntity? space(SpaceId spaceId);

  ProjectMutationResult? setType(
    SpaceId spaceId,
    ProjectSpaceType type, {
    LocalProjectVersion? expectedVersion,
  });

  ProjectMutationResult? setUsage(
    SpaceId spaceId,
    SpaceUsage usage, {
    LocalProjectVersion? expectedVersion,
  });

  /// Assigns [spaceId] to exactly one structural zone.
  ///
  /// Reassigning from another same-level zone is atomic. Cross-level
  /// assignment is rejected by the canonical P4 command before commit.
  ProjectMutationResult? assignStructuralZone(
    SpaceId spaceId,
    ZoneId zoneId, {
    LocalProjectVersion? expectedVersion,
  });

  /// Removes [spaceId] from its current structural zone, if any.
  ///
  /// An already-unassigned Space is a semantic no-op and does not advance the
  /// local project version or append Undo history.
  ProjectMutationResult? unassignStructuralZone(
    SpaceId spaceId, {
    LocalProjectVersion? expectedVersion,
  });
}

final class ProjectSpaceSemanticsEditingSession
    implements ProjectSpaceSemanticsEditingPort {
  ProjectSpaceSemanticsEditingSession(this._mutations);

  final ProjectMutationSession _mutations;

  @override
  ProjectId get projectId => _mutations.current.id;

  @override
  LocalProjectVersion get version => _mutations.current.version;

  @override
  bool get canEdit => true;

  @override
  ProjectSpaceEntity? space(SpaceId spaceId) =>
      _mutations.current.index.space(spaceId);

  @override
  ProjectMutationResult? setType(
    SpaceId spaceId,
    ProjectSpaceType type, {
    LocalProjectVersion? expectedVersion,
  }) {
    return _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: expectedVersion ?? _mutations.current.version,
        command: SetSpaceTypeCommand(spaceId: spaceId, type: type),
      ),
    );
  }

  @override
  ProjectMutationResult? setUsage(
    SpaceId spaceId,
    SpaceUsage usage, {
    LocalProjectVersion? expectedVersion,
  }) {
    return _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: expectedVersion ?? _mutations.current.version,
        command: SetSpaceUsageCommand(spaceId: spaceId, usage: usage),
      ),
    );
  }

  @override
  ProjectMutationResult? assignStructuralZone(
    SpaceId spaceId,
    ZoneId zoneId, {
    LocalProjectVersion? expectedVersion,
  }) {
    return _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: expectedVersion ?? _mutations.current.version,
        command: AssignSpaceToStructuralZoneCommand(
          spaceId: spaceId,
          zoneId: zoneId,
        ),
      ),
    );
  }

  @override
  ProjectMutationResult? unassignStructuralZone(
    SpaceId spaceId, {
    LocalProjectVersion? expectedVersion,
  }) {
    return _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: expectedVersion ?? _mutations.current.version,
        command: UnassignSpaceFromStructuralZoneCommand(spaceId: spaceId),
      ),
    );
  }
}
