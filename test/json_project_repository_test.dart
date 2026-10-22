import 'dart:io';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
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

  test(
    'canonical codec repository round-trip preserves Project North',
    () async {
      final canonicalRepository = JsonProjectRepository(
        rootDirectory: root,
        codec: const CanonicalProjectDocumentCodec(),
      );
      final north = ProjectEngineeringNorth.fromDegrees(123.456);
      final snapshot = _snapshot(
        id: 'project-north',
        name: 'Project North',
        updatedAt: DateTime.utc(2026, 10, 21, 10),
        north: north,
      );

      await canonicalRepository.save(snapshot);
      final loaded = await canonicalRepository.load(ProjectId('project-north'));

      expect(loaded, isNotNull);
      expect(loaded!.aggregate.engineeringMetadata.projectNorth, north);
      expect(loaded.localVersion, snapshot.localVersion);
      expect(
        loaded.aggregate.index.site(loaded.siteId)?.name,
        'Site project-north',
      );
    },
  );

  test('rejects a lossy codec before touching the project file', () async {
    final lossyRepository = JsonProjectRepository(
      rootDirectory: root,
      codec: _DroppingProjectNorthCodec(),
    );
    final snapshot = _snapshot(
      id: 'lossy-project',
      name: 'Lossy Project',
      updatedAt: DateTime.utc(2026, 10, 21, 10),
      north: ProjectEngineeringNorth.fromDegrees(45),
    );

    await expectLater(
      lossyRepository.save(snapshot),
      throwsA(isA<StateError>()),
    );

    final projectFiles = await root
        .list()
        .where(
          (entity) =>
              entity is File && entity.path.endsWith('.elecx.project.json'),
        )
        .toList();
    expect(projectFiles, isEmpty);
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
    await File('${root.path}/corrupt.elecx.project.json')
        .writeAsString('{broken json', flush: true);

    final summaries = await repository.list();
    expect(summaries, hasLength(1));
    expect(summaries.single.id, ProjectId('healthy'));
  });
}

ProjectSnapshot _snapshot({
  required String id,
  required String name,
  required DateTime updatedAt,
  ProjectEngineeringNorth? north,
}) {
  final projectId = ProjectId(id);
  final siteId = SiteId('site-$id');
  return ProjectSnapshot(
    aggregate: ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(2),
      engineeringMetadata: ProjectEngineeringMetadata(projectNorth: north),
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

final class _DroppingProjectNorthCodec implements ProjectDocumentCodec {
  static const _delegate = CanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => _delegate.currentSchemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) =>
      _delegate.encode(snapshot);

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    final decoded = _delegate.decode(document);
    final aggregate = decoded.aggregate;
    return decoded.copyWith(
      aggregate: ProjectAggregateRoot(
        id: aggregate.id,
        siteId: aggregate.siteId,
        version: aggregate.version,
        stores: aggregate.stores,
      ),
    );
  }
}
