import '../../domain/project_aggregate.dart';
import '../../domain/project_orientation.dart';
import 'project_mutation.dart';

/// Sets canonical engineering Project North through the P3 mutation boundary.
final class SetProjectNorthCommand implements ProjectCommand {
  const SetProjectNorthCommand(this.north);

  final ProjectEngineeringNorth north;

  @override
  String get commandType => 'project.set-project-north';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata:
            current.engineeringMetadata.withProjectNorth(north),
        stores: current.stores,
      ),
    );
  }
}

/// Clears canonical engineering Project North back to the explicit unspecified
/// state. This command does not touch legacy true-north/daylight metadata.
final class ClearProjectNorthCommand implements ProjectCommand {
  const ClearProjectNorthCommand();

  @override
  String get commandType => 'project.clear-project-north';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata.withoutProjectNorth(),
        stores: current.stores,
      ),
    );
  }
}
