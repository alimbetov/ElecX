import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_space_semantics.dart';
import 'project_mutation.dart';
import 'project_space_semantics_commands.dart';

/// Narrow P6F application capability for selected-space semantic authoring.
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

  ProjectMutationResult? setUsage(
    SpaceId spaceId,
    SpaceUsage usage, {
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
}
