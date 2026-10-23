import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectSnapshot', () {
    test('normalizes metadata and preserves typed project identity', () {
      final snapshot = ProjectSnapshot(
        aggregate: _aggregate(),
        name: '  Demo project  ',
        createdAt: DateTime.parse('2026-10-21T08:00:00+05:00'),
        updatedAt: DateTime.parse('2026-10-21T09:00:00+05:00'),
      );

      expect(snapshot.id, ProjectId('project-1'));
      expect(snapshot.siteId, SiteId('site-1'));
      expect(snapshot.name, 'Demo project');
      expect(snapshot.createdAt.isUtc, isTrue);
      expect(snapshot.updatedAt.isUtc, isTrue);
      expect(snapshot.toSummary().localVersion, LocalProjectVersion(3));
    });

    test('rejects empty name and reversed timestamps', () {
      expect(
        () => ProjectSnapshot(
          aggregate: _aggregate(),
          name: '   ',
          createdAt: DateTime.utc(2026, 10, 21, 8),
          updatedAt: DateTime.utc(2026, 10, 21, 9),
        ),
        throwsArgumentError,
      );
      expect(
        () => ProjectSnapshot(
          aggregate: _aggregate(),
          name: 'Demo',
          createdAt: DateTime.utc(2026, 10, 21, 9),
          updatedAt: DateTime.utc(2026, 10, 21, 8),
        ),
        throwsArgumentError,
      );
    });
  });

  group('ProjectRepository', () {
    test('loads and lists projects strictly by typed ProjectId', () async {
      final repository = _MemoryProjectRepository();
      final snapshot = ProjectSnapshot(
        aggregate: _aggregate(),
        name: 'Demo',
        createdAt: DateTime.utc(2026, 10, 21, 8),
        updatedAt: DateTime.utc(2026, 10, 21, 9),
      );

      await repository.save(snapshot);

      expect(await repository.load(ProjectId('project-1')), same(snapshot));
      expect(await repository.load(ProjectId('missing')), isNull);
      final summaries = await repository.list();
      expect(summaries, hasLength(1));
      expect(summaries.single.id, ProjectId('project-1'));
    });
  });

  group('ProjectDocument', () {
    test('owns an immutable payload snapshot and validates schema version', () {
      final mutable = <String, Object?>{'projectId': 'project-1'};
      final document = ProjectDocument(schemaVersion: 1, payload: mutable);
      mutable.clear();

      expect(document.payload['projectId'], 'project-1');
      expect(() => document.payload.clear(), throwsUnsupportedError);
      expect(
        () => ProjectDocument(schemaVersion: 0, payload: const {}),
        throwsArgumentError,
      );
    });
  });
}

ProjectAggregateRoot _aggregate() {
  final siteId = SiteId('site-1');
  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(3),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: const [],
        ),
      },
    ),
  );
}

final class _MemoryProjectRepository implements ProjectRepository {
  final Map<ProjectId, ProjectSnapshot> _items = {};

  @override
  Future<ProjectSnapshot?> load(ProjectId projectId) async => _items[projectId];

  @override
  Future<void> save(ProjectSnapshot snapshot) async {
    _items[snapshot.id] = snapshot;
  }

  @override
  Future<List<ProjectSummary>> list() async =>
      _items.values.map((snapshot) => snapshot.toSummary()).toList();
}
