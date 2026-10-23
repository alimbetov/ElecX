import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A canonical production persistence owner', () {
    test(
      'accept is synchronous while disk durability remains explicit',
      () async {
        final repository = _MemoryProjectRepository();
        final before = _project(version: 0, siteName: 'Site');
        final owner = CanonicalProjectPersistenceOwner(
          snapshot: ProjectSnapshot(
            aggregate: before,
            name: 'Project',
            createdAt: DateTime.utc(2026, 10, 23, 5),
            updatedAt: DateTime.utc(2026, 10, 23, 5),
          ),
          repository: repository,
        );
        final after = _project(version: 1, siteName: 'Updated site');
        final result = _result(before: before, after: after);

        owner.acceptMutation(
          sessionProject: after,
          result: result,
          now: DateTime.utc(2026, 10, 23, 6),
        );

        expect(owner.project, same(after));
        expect(owner.version, LocalProjectVersion(1));
        expect(repository.saved, isNull);

        await owner.save();

        expect(repository.saved?.aggregate, same(after));
        expect(repository.saveCount, 1);
      },
    );

    test('replay and version gaps are rejected without changing owner', () {
      final repository = _MemoryProjectRepository();
      final before = _project(version: 0, siteName: 'Site');
      final owner = CanonicalProjectPersistenceOwner(
        snapshot: ProjectSnapshot(
          aggregate: before,
          name: 'Project',
          createdAt: DateTime.utc(2026, 10, 23, 5),
          updatedAt: DateTime.utc(2026, 10, 23, 5),
        ),
        repository: repository,
      );
      final after = _project(version: 1, siteName: 'Updated site');
      final result = _result(before: before, after: after);

      owner.acceptMutation(sessionProject: after, result: result);
      expect(
        () => owner.acceptMutation(sessionProject: after, result: result),
        throwsStateError,
      );
      expect(owner.project, same(after));

      final skipped = _project(version: 3, siteName: 'Skipped');
      final skippedResult = ProjectMutationResult(
        project: skipped,
        changeSet: ProjectChangeSet(
          kind: ProjectChangeKind.command,
          commandType: 'test.skip',
          beforeVersion: LocalProjectVersion(2),
          afterVersion: LocalProjectVersion(3),
          entityDiff: ProjectEntityDiff(
            updatedEntityIds: [skipped.siteId],
          ),
        ),
      );
      expect(
        () => owner.acceptMutation(
          sessionProject: skipped,
          result: skippedResult,
        ),
        throwsStateError,
      );
      expect(owner.project, same(after));
    });

    test('load restores the exact persisted canonical project', () async {
      final repository = _MemoryProjectRepository();
      final project = _project(version: 4, siteName: 'Persisted');
      repository.saved = ProjectSnapshot(
        aggregate: project,
        name: 'Project',
        createdAt: DateTime.utc(2026, 10, 23, 5),
        updatedAt: DateTime.utc(2026, 10, 23, 7),
      );

      final owner = await CanonicalProjectPersistenceOwner.load(
        repository: repository,
        projectId: project.id,
      );

      expect(owner, isNotNull);
      expect(owner!.project, same(project));
      expect(owner.version, LocalProjectVersion(4));
    });
  });
}

ProjectAggregateRoot _project(
    {required int version, required String siteName}) {
  final siteId = SiteId('site');
  return ProjectAggregateRoot(
    id: ProjectId('project'),
    siteId: siteId,
    version: LocalProjectVersion(version),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: siteName,
          buildingIds: const [],
        ),
      },
    ),
  );
}

ProjectMutationResult _result({
  required ProjectAggregateRoot before,
  required ProjectAggregateRoot after,
}) =>
    ProjectMutationResult(
      project: after,
      changeSet: ProjectChangeSet(
        kind: ProjectChangeKind.command,
        commandType: 'test.updateSite',
        beforeVersion: before.version,
        afterVersion: after.version,
        entityDiff: ProjectEntityDiff(updatedEntityIds: [after.siteId]),
      ),
    );

final class _MemoryProjectRepository implements ProjectRepository {
  ProjectSnapshot? saved;
  int saveCount = 0;

  @override
  Future<ProjectSnapshot?> load(ProjectId projectId) async =>
      saved?.id == projectId ? saved : null;

  @override
  Future<void> save(ProjectSnapshot snapshot) async {
    saved = snapshot;
    saveCount++;
  }

  @override
  Future<List<ProjectSummary>> list() async =>
      saved == null ? const [] : [saved!.toSummary()];
}
