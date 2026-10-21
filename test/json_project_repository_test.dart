import 'dart:io';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late JsonProjectRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('elecx-project-repository-');
    repository = JsonProjectRepository(
      rootDirectory: root,
      codec: _TestProjectDocumentCodec(),
    );
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('saves, loads and lists canonical snapshots', () async {
    final first = _snapshot(
      id: 'project-a',
      name: 'Project A',
      updatedAt: DateTime.utc(2026, 10, 21, 8),
    );
    final second = _snapshot(
      id: 'project-b',
      name: 'Project B',
      updatedAt: DateTime.utc(2026, 10, 21, 9),
    );

    await repository.save(first);
    await repository.save(second);

    final loaded = await repository.load(ProjectId('project-a'));
    expect(loaded?.id, ProjectId('project-a'));
    expect(loaded?.name, 'Project A');
    expect(loaded?.localVersion, LocalProjectVersion(2));

    final summaries = await repository.list();
    expect(summaries.map((item) => item.id), [
      ProjectId('project-b'),
      ProjectId('project-a'),
    ]);
  });

  test('returns null for a project that has never been saved', () async {
    expect(await repository.load(ProjectId('missing')), isNull);
  });

  test('falls back to a valid backup when primary JSON is corrupt', () async {
    final snapshot = _snapshot(
      id: 'project-a',
      name: 'Project A',
      updatedAt: DateTime.utc(2026, 10, 21, 8),
    );
    await repository.save(snapshot);

    final primary = await root
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .firstWhere((file) => file.path.endsWith('.elecx.project.json'));
    final backup = File('${primary.path}.bak');
    await primary.copy(backup.path);
    await primary.writeAsString('{broken json', flush: true);

    final loaded = await repository.load(ProjectId('project-a'));
    expect(loaded?.id, ProjectId('project-a'));
    expect(loaded?.name, 'Project A');

    final summaries = await repository.list();
    expect(summaries, hasLength(1));
    expect(summaries.single.id, ProjectId('project-a'));
  });

  test('isolates a corrupt project during listing', () async {
    await repository.save(
      _snapshot(
        id: 'healthy',
        name: 'Healthy',
        updatedAt: DateTime.utc(2026, 10, 21, 8),
      ),
    );
    await File('${root.path}/corrupt.elecx.project.json').writeAsString(
      '{broken json',
      flush: true,
    );

    final summaries = await repository.list();
    expect(summaries, hasLength(1));
    expect(summaries.single.id, ProjectId('healthy'));
  });
}

ProjectSnapshot _snapshot({
  required String id,
  required String name,
  required DateTime updatedAt,
}) {
  final projectId = ProjectId(id);
  final siteId = SiteId('site-$id');
  return ProjectSnapshot(
    aggregate: ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(2),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'Site $id',
            buildingIds: const [],
          ),
        },
      ),
    ),
    name: name,
    createdAt: DateTime.utc(2026, 10, 21, 7),
    updatedAt: updatedAt,
  );
}

final class _TestProjectDocumentCodec implements ProjectDocumentCodec {
  @override
  int get currentSchemaVersion => 1;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) => ProjectDocument(
        schemaVersion: currentSchemaVersion,
        payload: {
          'projectId': snapshot.id.value,
          'siteId': snapshot.siteId.value,
          'localVersion': snapshot.localVersion.value,
          'name': snapshot.name,
          'createdAt': snapshot.createdAt.toIso8601String(),
          'updatedAt': snapshot.updatedAt.toIso8601String(),
          'siteName': snapshot.aggregate.index.site(snapshot.siteId)!.name,
        },
      );

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported test schema ${document.schemaVersion}.',
      );
    }
    final payload = document.payload;
    final projectId = ProjectId(payload['projectId']! as String);
    final siteId = SiteId(payload['siteId']! as String);
    final aggregate = ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(payload['localVersion']! as int),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: payload['siteName']! as String,
            buildingIds: const [],
          ),
        },
      ),
    );
    return ProjectSnapshot(
      aggregate: aggregate,
      name: payload['name']! as String,
      createdAt: DateTime.parse(payload['createdAt']! as String),
      updatedAt: DateTime.parse(payload['updatedAt']! as String),
    );
  }
}
