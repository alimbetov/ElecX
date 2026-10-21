import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/infrastructure/sync/in_memory_project_sync_gateway.dart';
import 'package:elecx/src/infrastructure/sync/project_sync_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late EditorController editor;
  late EditorBuildingWorkspace workspace;
  late EditorProjectDocument document;

  setUp(() {
    editor = EditorController.demo();
    workspace = EditorBuildingWorkspace.demo(editor);
    document = EditorProjectDocument.capture(
      workspace,
      now: DateTime.utc(2026, 10, 21, 2),
    );
  });

  tearDown(() {
    workspace.dispose();
    editor.dispose();
  });

  test('first push creates revision one and can be downloaded', () async {
    final gateway = InMemoryProjectSyncGateway();

    final result = await gateway.pushRevision(
      PushRevisionRequest(
        projectId: document.projectId,
        baseRevision: 0,
        schemaVersion: 1,
        deviceId: 'macbook-test',
        document: document,
      ),
    );

    expect(result, isA<PushRevisionAccepted>());
    expect((result as PushRevisionAccepted).revision, 1);

    final downloaded = await gateway.downloadRevision(document.projectId);
    expect(downloaded, isNotNull);
    expect(downloaded!.revision, 1);
    expect(downloaded.document.toJson(), document.toJson());
  });

  test('stale base revision is rejected instead of overwriting remote head',
      () async {
    final gateway = InMemoryProjectSyncGateway();

    final first = await gateway.pushRevision(
      PushRevisionRequest(
        projectId: document.projectId,
        baseRevision: 0,
        schemaVersion: 1,
        deviceId: 'windows-test',
        document: document,
      ),
    );
    expect(first, isA<PushRevisionAccepted>());

    final stalePush = await gateway.pushRevision(
      PushRevisionRequest(
        projectId: document.projectId,
        baseRevision: 0,
        schemaVersion: 1,
        deviceId: 'ipad-test',
        document: document,
      ),
    );

    expect(stalePush, isA<PushRevisionConflict>());
    final conflict = stalePush as PushRevisionConflict;
    expect(conflict.baseRevision, 0);
    expect(conflict.remoteRevision, 1);

    final head = await gateway.getHead(document.projectId);
    expect(head, isNotNull);
    expect(head!.revision, 1);
  });

  test('matching base revision advances remote head monotonically', () async {
    final gateway = InMemoryProjectSyncGateway();

    await gateway.pushRevision(
      PushRevisionRequest(
        projectId: document.projectId,
        baseRevision: 0,
        schemaVersion: 1,
        deviceId: 'linux-test',
        document: document,
      ),
    );

    final second = await gateway.pushRevision(
      PushRevisionRequest(
        projectId: document.projectId,
        baseRevision: 1,
        schemaVersion: 1,
        deviceId: 'android-test',
        document: document,
      ),
    );

    expect(second, isA<PushRevisionAccepted>());
    expect((second as PushRevisionAccepted).revision, 2);
    expect((await gateway.getHead(document.projectId))!.revision, 2);
  });
}
