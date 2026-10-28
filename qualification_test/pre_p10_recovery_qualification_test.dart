import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/canonical_project_document_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FailOnceProjectStore implements EditorProjectStore {
  var listCalls = 0;

  @override
  Future<List<EditorProjectDocument>> list() async {
    listCalls++;
    if (listCalls == 1) {
      throw const FileSystemException('simulated project-list failure');
    }
    return const [];
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) async => null;

  @override
  Future<void> save(EditorProjectDocument document) async {}
}

void main() {
  testWidgets('PRE10-Q04 Project Hub list failure exposes working Retry',
      (tester) async {
    final store = _FailOnceProjectStore();

    await tester.pumpWidget(MaterialApp(home: ProjectHubScreen(projectStore: store)));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось прочитать сохранённые проекты'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(store.listCalls, 1);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(store.listCalls, 2);
    expect(find.text('Не удалось прочитать сохранённые проекты'), findsNothing);
    expect(find.text('Нет сохранённого проекта'), findsOneWidget);
  });

  test('PRE10-Q05 corrupt primary falls back to valid canonical backup', () async {
    final root = await Directory.systemTemp.createTemp('elecx-pre10-recovery-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final repository = JsonProjectRepository(
      rootDirectory: root,
      codec: const CanonicalProjectDocumentCodec(),
    );
    final snapshot = _snapshot('project-backup-fallback');

    await repository.save(snapshot);
    final target = File(_targetPath(root, snapshot.id));
    final backup = File('${target.path}.bak');
    await target.copy(backup.path);
    await target.writeAsString('{ broken json', flush: true);

    final restored = await repository.load(snapshot.id);

    expect(restored, isNotNull);
    expect(restored!.id, snapshot.id);
    expect(restored.name, snapshot.name);
  });

  test('PRE10-Q05 corrupt primary and backup fail predictably', () async {
    final root = await Directory.systemTemp.createTemp('elecx-pre10-corrupt-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final repository = JsonProjectRepository(
      rootDirectory: root,
      codec: const CanonicalProjectDocumentCodec(),
    );
    final snapshot = _snapshot('project-double-corrupt');

    await repository.save(snapshot);
    final target = File(_targetPath(root, snapshot.id));
    final backup = File('${target.path}.bak');
    await target.writeAsString('{ broken primary', flush: true);
    await backup.writeAsString('{ broken backup', flush: true);

    await expectLater(repository.load(snapshot.id), throwsFormatException);
  });

  test('PRE10-Q05 corrupt project does not hide healthy projects from list',
      () async {
    final root = await Directory.systemTemp.createTemp('elecx-pre10-list-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final repository = JsonProjectRepository(
      rootDirectory: root,
      codec: const CanonicalProjectDocumentCodec(),
    );
    final healthy = _snapshot('project-healthy');
    final corrupt = _snapshot('project-corrupt');

    await repository.save(healthy);
    await repository.save(corrupt);
    await File(_targetPath(root, corrupt.id)).writeAsString(
      '{ corrupt project',
      flush: true,
    );

    final summaries = await repository.list();

    expect(summaries.map((summary) => summary.id), contains(healthy.id));
    expect(summaries.map((summary) => summary.id), isNot(contains(corrupt.id)));
  });
}

ProjectSnapshot _snapshot(String projectId) {
  final id = ProjectId(projectId);
  final siteId = SiteId('site-$projectId');
  return ProjectSnapshot(
    aggregate: ProjectAggregateRoot(
      id: id,
      siteId: siteId,
      version: LocalProjectVersion(1),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'Site $projectId',
            buildingIds: const [],
          ),
        },
      ),
    ),
    name: 'Project $projectId',
    createdAt: DateTime.utc(2026, 10, 28, 6),
    updatedAt: DateTime.utc(2026, 10, 28, 6, 1),
  );
}

String _targetPath(Directory root, ProjectId projectId) {
  final encoded = base64Url.encode(utf8.encode(projectId.value)).replaceAll('=', '');
  return '${root.path}${Platform.pathSeparator}$encoded.elecx.project.json';
}
