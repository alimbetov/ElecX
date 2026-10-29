import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:elecx/src/features/editor/initial_editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:elecx/src/features/projects/project_hub_screen.dart';
import 'package:elecx/src/features/shared/production_error_boundary.dart';
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

final class _RecordingProjectStore implements EditorProjectStore {
  _RecordingProjectStore({
    required this.document,
    required this.events,
    this.loadFailure,
  });

  final EditorProjectDocument document;
  final List<String> events;
  final Object? loadFailure;

  @override
  Future<List<EditorProjectDocument>> list() async => [document];

  @override
  Future<EditorProjectDocument?> load(String projectId) async {
    events.add('project:load');
    if (loadFailure case final failure?) throw failure;
    return document;
  }

  @override
  Future<void> save(EditorProjectDocument document) async {}
}

final class _RecordingRecoveryStore implements EditorProjectRecoveryStore {
  _RecordingRecoveryStore({
    this.listedSnapshot,
    List<String>? events,
  }) : events = events ?? <String>[];

  EditorProjectRecoverySnapshot? listedSnapshot;
  EditorProjectRecoverySnapshot? loadedSnapshot;
  final List<String> events;
  var discardCalls = 0;

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {
    loadedSnapshot = snapshot;
  }

  @override
  Future<EditorProjectRecoverySnapshot?> load(String projectId) async =>
      loadedSnapshot?.projectId == projectId ? loadedSnapshot : null;

  @override
  Future<List<EditorProjectRecoverySnapshot>> list() async =>
      listedSnapshot == null ? const [] : [listedSnapshot!];

  @override
  Future<void> discard(String projectId) async {
    events.add('recovery:discard');
    discardCalls++;
    if (listedSnapshot?.projectId == projectId) listedSnapshot = null;
    if (loadedSnapshot?.projectId == projectId) loadedSnapshot = null;
  }
}

void main() {
  testWidgets('PRE10-Q04 Project Hub list failure exposes working Retry',
      (tester) async {
    final store = _FailOnceProjectStore();

    await tester
        .pumpWidget(MaterialApp(home: ProjectHubScreen(projectStore: store)));
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось прочитать сохранённые проекты'),
      findsOneWidget,
    );
    expect(find.text('Повторить'), findsOneWidget);
    expect(store.listCalls, 1);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(store.listCalls, 2);
    expect(find.text('Не удалось прочитать сохранённые проекты'), findsNothing);
    expect(find.text('Нет сохранённого проекта'), findsOneWidget);
  });

  testWidgets('PRE10-CQ06 D013 recovery discard requires explicit confirmation',
      (tester) async {
    final document = _legacyDocument('d013-confirmation');
    final recoveryStore = _RecordingRecoveryStore(
      listedSnapshot: EditorProjectRecoverySnapshot(
        capturedAt: DateTime.utc(2026, 10, 29, 1),
        revision: 7,
        document: document,
      ),
    );
    final projectStore = _RecordingProjectStore(
      document: document,
      events: <String>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectHubScreen(
          projectStore: _EmptyProjectStore(),
          recoveryStore: recoveryStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('discard-recovery-${document.projectId}')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discard-recovery-confirmation-dialog')),
      findsOneWidget,
    );
    expect(recoveryStore.discardCalls, 0);

    await tester.tap(find.byKey(const ValueKey('cancel-discard-recovery')));
    await tester.pumpAndSettle();
    expect(recoveryStore.discardCalls, 0);
    expect(
      find.byKey(ValueKey('recovery-project-${document.projectId}')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ValueKey('discard-recovery-${document.projectId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-discard-recovery')));
    await tester.pumpAndSettle();

    expect(recoveryStore.discardCalls, 1);
    expect(
      find.byKey(ValueKey('recovery-project-${document.projectId}')),
      findsNothing,
    );
    expect(projectStore.events, isEmpty);
  });

  testWidgets('PRE10-CQ06 D016 failed saved-version load preserves recovery',
      (tester) async {
    const sentinel = 'PRIVATE_LOAD_SENTINEL_DO_NOT_EXPOSE';
    final document = _legacyDocument('d016-load-failure');
    final events = <String>[];
    final recoveryStore = _RecordingRecoveryStore(events: events);
    final projectStore = _RecordingProjectStore(
      document: document,
      events: events,
      loadFailure: StateError(sentinel),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: projectStore,
          recoveryStore: recoveryStore,
          initialDocument: document,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('project-open')));
    await tester.pumpAndSettle();

    expect(events, contains('project:load'));
    expect(events, isNot(contains('recovery:discard')));
    expect(recoveryStore.discardCalls, 0);
    expect(find.textContaining('PX-EDITOR-002'), findsOneWidget);
    expect(find.textContaining(sentinel), findsNothing);
  });

  testWidgets(
      'PRE10-CQ06 D016 successful restore discards recovery only after load',
      (tester) async {
    final document = _legacyDocument('d016-load-success');
    final events = <String>[];
    final recoveryStore = _RecordingRecoveryStore(events: events);
    final projectStore = _RecordingProjectStore(
      document: document,
      events: events,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: projectStore,
          recoveryStore: recoveryStore,
          initialDocument: document,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('project-open')));
    await tester.pumpAndSettle();

    expect(events, ['project:load', 'recovery:discard']);
    expect(recoveryStore.discardCalls, 1);
    expect(find.text('Проект открыт из сохранённой версии'), findsOneWidget);
  });

  test('PRE10-CQ07 D018 safe boundary never leaks sentinel exception text', () {
    const sentinel = 'PRIVATE_SENTINEL_DO_NOT_EXPOSE';
    FlutterErrorDetails? captured;

    final failure = ProductionErrorBoundary.report(
      error: StateError(sentinel),
      stackTrace: StackTrace.current,
      code: ProductionDiagnosticCode.savedProjectOpen,
      safeSummary: 'Не удалось открыть сохранённую версию проекта.',
      library: 'qualification',
      operation: 'sentinel qualification',
      diagnosticSink: (details) => captured = details,
    );

    expect(failure.userMessage, contains('PX-EDITOR-002'));
    expect(failure.userMessage, isNot(contains(sentinel)));
    expect(captured, isNotNull);
    expect(captured!.exception.toString(), contains(sentinel));
    expect(captured!.context.toString(), contains('PX-EDITOR-002'));
  });

  test('PRE10-CQ13 D019 logical revision outranks wall-clock recovery time',
      () async {
    final root = await Directory.systemTemp.createTemp('elecx-pre10-cq13-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    const projectId = 'd019-revision-first';
    final document = _legacyDocument(projectId);
    final target = File(_recoveryTargetPath(root, projectId));
    final backup = File('${target.path}.bak');
    final temp = File('${target.path}.tmp');
    await root.create(recursive: true);

    final lowerRevisionNewerClock = EditorProjectRecoverySnapshot(
      capturedAt: DateTime.utc(2036, 1, 1),
      revision: 8,
      document: document,
    );
    final higherRevisionOlderClock = EditorProjectRecoverySnapshot(
      capturedAt: DateTime.utc(2020, 1, 1),
      revision: 9,
      document: document,
    );
    final oldestRevisionNewestClock = EditorProjectRecoverySnapshot(
      capturedAt: DateTime.utc(2046, 1, 1),
      revision: 7,
      document: document,
    );

    await target.writeAsString(
      jsonEncode(lowerRevisionNewerClock.toJson()),
      flush: true,
    );
    await backup.writeAsString(
      jsonEncode(higherRevisionOlderClock.toJson()),
      flush: true,
    );
    await temp.writeAsString(
      jsonEncode(oldestRevisionNewestClock.toJson()),
      flush: true,
    );

    final store = JsonFileEditorProjectRecoveryStore(root);
    final loaded = await store.load(projectId);
    final listed = await store.list();

    expect(loaded, isNotNull);
    expect(loaded!.revision, 9);
    expect(loaded.capturedAt, DateTime.utc(2020, 1, 1));
    expect(listed, hasLength(1));
    expect(listed.single.revision, 9);
    expect(listed.single.capturedAt, DateTime.utc(2020, 1, 1));
  });

  test('PRE10-CQ13 D019 wall-clock is tie-breaker only for equal revision',
      () async {
    final root = await Directory.systemTemp.createTemp('elecx-pre10-cq13-tie-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    const projectId = 'd019-equal-revision';
    final document = _legacyDocument(projectId);
    final target = File(_recoveryTargetPath(root, projectId));
    final backup = File('${target.path}.bak');
    await root.create(recursive: true);

    final olderClock = EditorProjectRecoverySnapshot(
      capturedAt: DateTime.utc(2026, 10, 29, 1),
      revision: 11,
      document: document,
    );
    final newerClock = EditorProjectRecoverySnapshot(
      capturedAt: DateTime.utc(2026, 10, 29, 2),
      revision: 11,
      document: document,
    );

    await target.writeAsString(jsonEncode(olderClock.toJson()), flush: true);
    await backup.writeAsString(jsonEncode(newerClock.toJson()), flush: true);

    final loaded =
        await JsonFileEditorProjectRecoveryStore(root).load(projectId);

    expect(loaded, isNotNull);
    expect(loaded!.revision, 11);
    expect(loaded.capturedAt, DateTime.utc(2026, 10, 29, 2));
  });

  test('PRE10-Q05 corrupt primary falls back to valid canonical backup',
      () async {
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

final class _EmptyProjectStore implements EditorProjectStore {
  @override
  Future<List<EditorProjectDocument>> list() async => const [];

  @override
  Future<EditorProjectDocument?> load(String projectId) async => null;

  @override
  Future<void> save(EditorProjectDocument document) async {}
}

EditorProjectDocument _legacyDocument(String projectId) =>
    createInitialEditorProjectDocument(
      EditorProjectMetadata.create(
        projectName: 'Project $projectId',
        projectId: projectId,
        now: DateTime.utc(2026, 10, 29),
      ),
    );

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
  final encoded =
      base64Url.encode(utf8.encode(projectId.value)).replaceAll('=', '');
  return '${root.path}${Platform.pathSeparator}$encoded.elecx.project.json';
}

String _recoveryTargetPath(Directory root, String projectId) {
  final encoded = base64Url.encode(utf8.encode(projectId)).replaceAll('=', '');
  return '${root.path}${Platform.pathSeparator}$encoded.elecx.recovery.json';
}
