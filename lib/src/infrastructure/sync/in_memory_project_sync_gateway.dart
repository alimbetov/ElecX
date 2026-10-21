import 'project_sync_gateway.dart';

final class InMemoryProjectSyncGateway implements ProjectSyncGateway {
  final Map<String, List<RemoteProjectRevision>> _revisions =
      <String, List<RemoteProjectRevision>>{};

  @override
  Future<List<RemoteProjectHead>> listProjects() async {
    final result = <RemoteProjectHead>[];
    for (final entry in _revisions.entries) {
      if (entry.value.isEmpty) continue;
      final latest = entry.value.last;
      result.add(
        RemoteProjectHead(
          projectId: latest.projectId,
          revision: latest.revision,
          schemaVersion: latest.schemaVersion,
          updatedAt: latest.updatedAt,
        ),
      );
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<RemoteProjectHead>.unmodifiable(result);
  }

  @override
  Future<RemoteProjectHead?> getHead(String projectId) async {
    final revisions = _revisions[projectId];
    if (revisions == null || revisions.isEmpty) return null;
    final latest = revisions.last;
    return RemoteProjectHead(
      projectId: latest.projectId,
      revision: latest.revision,
      schemaVersion: latest.schemaVersion,
      updatedAt: latest.updatedAt,
    );
  }

  @override
  Future<RemoteProjectRevision?> downloadRevision(
    String projectId, {
    int? revision,
  }) async {
    final revisions = _revisions[projectId];
    if (revisions == null || revisions.isEmpty) return null;
    if (revision == null) return revisions.last;
    for (final candidate in revisions) {
      if (candidate.revision == revision) return candidate;
    }
    return null;
  }

  @override
  Future<PushRevisionResult> pushRevision(PushRevisionRequest request) async {
    if (request.document.projectId != request.projectId) {
      throw const FormatException(
        'Document projectId must match the sync request projectId.',
      );
    }

    final revisions = _revisions.putIfAbsent(
      request.projectId,
      () => <RemoteProjectRevision>[],
    );
    final remoteRevision = revisions.isEmpty ? 0 : revisions.last.revision;

    if (request.baseRevision != remoteRevision) {
      return PushRevisionConflict(
        projectId: request.projectId,
        baseRevision: request.baseRevision,
        remoteRevision: remoteRevision,
      );
    }

    final nextRevision = remoteRevision + 1;
    final stored = RemoteProjectRevision(
      projectId: request.projectId,
      revision: nextRevision,
      schemaVersion: request.schemaVersion,
      updatedAt: request.document.updatedAt,
      document: request.document,
    );
    revisions.add(stored);

    return PushRevisionAccepted(
      projectId: request.projectId,
      revision: nextRevision,
      updatedAt: stored.updatedAt,
    );
  }
}
