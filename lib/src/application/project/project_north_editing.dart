import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_orientation.dart';
import 'project_mutation.dart';
import 'project_orientation_commands.dart';

/// Narrow P5D application capability for canonical Project North editing.
///
/// Presentation code never constructs [ProjectMutationRequest] directly and
/// never mutates the legacy editor workspace. This port owns the translation
/// from an editing intent into the shared P3 mutation session.
abstract interface class ProjectNorthEditingPort {
  ProjectId get projectId;
  LocalProjectVersion get version;
  ProjectEngineeringNorth? get currentProjectNorth;
  bool get canEdit;

  ProjectMutationResult? setProjectNorth(ProjectEngineeringNorth value);
  ProjectMutationResult? clearProjectNorth();
}

final class ProjectNorthEditingSession implements ProjectNorthEditingPort {
  ProjectNorthEditingSession(this._mutations);

  final ProjectMutationSession _mutations;

  @override
  ProjectId get projectId => _mutations.current.id;

  @override
  LocalProjectVersion get version => _mutations.current.version;

  @override
  ProjectEngineeringNorth? get currentProjectNorth =>
      _mutations.current.engineeringMetadata.projectNorth;

  @override
  bool get canEdit => true;

  @override
  ProjectMutationResult? setProjectNorth(ProjectEngineeringNorth value) {
    return _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: _mutations.current.version,
        command: SetProjectNorthCommand(value),
      ),
    );
  }

  @override
  ProjectMutationResult? clearProjectNorth() {
    return _mutations.commit(
      ProjectMutationRequest(
        expectedVersion: _mutations.current.version,
        command: const ClearProjectNorthCommand(),
      ),
    );
  }
}
