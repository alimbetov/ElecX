import '../../features/editor/editor_project_document.dart';

abstract interface class ProjectSyncGateway {
  Future<List<RemoteProjectHead>> listProjects();

  Future<RemoteProjectHead?> getHead(String projectId);

  Future<RemoteProjectRevision?> downloadRevision(
    String projectId, {
    int? revision,
  });

  Future<PushRevisionResult> pushRevision(PushRevisionRequest request);
}

final class RemoteProjectHead {
  const RemoteProjectHead({
    required this.projectId,
    required this.revision,
    required this.schemaVersion,
    required this.updatedAt,
  });

  final String projectId;
  final int revision;
  final int schemaVersion;
  final DateTime updatedAt;
}

final class RemoteProjectRevision {
  const RemoteProjectRevision({
    required this.projectId,
    required this.revision,
    required this.schemaVersion,
    required this.updatedAt,
    required this.document,
  });

  final String projectId;
  final int revision;
  final int schemaVersion;
  final DateTime updatedAt;
  final EditorProjectDocument document;
}

final class PushRevisionRequest {
  const PushRevisionRequest({
    required this.projectId,
    required this.baseRevision,
    required this.schemaVersion,
    required this.deviceId,
    required this.document,
  });

  final String projectId;
  final int baseRevision;
  final int schemaVersion;
  final String deviceId;
  final EditorProjectDocument document;
}

sealed class PushRevisionResult {
  const PushRevisionResult();
}

final class PushRevisionAccepted extends PushRevisionResult {
  const PushRevisionAccepted({
    required this.projectId,
    required this.revision,
    required this.updatedAt,
  });

  final String projectId;
  final int revision;
  final DateTime updatedAt;
}

final class PushRevisionConflict extends PushRevisionResult {
  const PushRevisionConflict({
    required this.projectId,
    required this.baseRevision,
    required this.remoteRevision,
  });

  final String projectId;
  final int baseRevision;
  final int remoteRevision;
}
