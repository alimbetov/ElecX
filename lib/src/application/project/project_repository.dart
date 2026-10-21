import '../../domain/project_identity.dart';
import 'project_snapshot.dart';

/// Application boundary for loading and saving canonical projects.
///
/// Implementations may use legacy JSON, Drift/SQLite or another native storage
/// adapter. Feature/domain code must not depend on those implementation details.
abstract interface class ProjectRepository {
  Future<ProjectSnapshot?> load(ProjectId projectId);

  Future<void> save(ProjectSnapshot snapshot);

  Future<List<ProjectSummary>> list();
}
