import 'package:elecx/src/features/editor/browser_project_store.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryBrowserStorage implements BrowserKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Iterable<String> get keys => List<String>.unmodifiable(values.keys);

  @override
  String? read(String key) => values[key];

  @override
  void remove(String key) => values.remove(key);

  @override
  void write(String key, String value) {
    values[key] = value;
  }
}

void main() {
  late EditorController editor;
  late EditorBuildingWorkspace workspace;
  late EditorProjectDocument document;

  setUp(() {
    editor = EditorController.demo();
    workspace = EditorBuildingWorkspace.demo(editor);
    document = EditorProjectDocument.capture(
      workspace,
      now: DateTime.utc(2026, 10, 21, 1),
    );
  });

  tearDown(() {
    workspace.dispose();
    editor.dispose();
  });

  test('browser project store round-trips canonical document', () async {
    final backend = _MemoryBrowserStorage();
    final store = BrowserEditorProjectStore(backend);

    await store.save(document);
    final restored = await store.load(document.projectId);

    expect(restored, isNotNull);
    expect(restored!.toJson(), document.toJson());
    expect(await store.list(), hasLength(1));
  });

  test('damaged browser project does not hide healthy projects', () async {
    final backend = _MemoryBrowserStorage();
    final store = BrowserEditorProjectStore(backend);

    await store.save(document);
    backend.write('elecx.project.v1.corrupt', '{not-json');

    final projects = await store.list();

    expect(projects, hasLength(1));
    expect(projects.single.projectId, document.projectId);
  });

  test('browser recovery store round-trips and discards snapshot', () async {
    final backend = _MemoryBrowserStorage();
    final store = BrowserEditorProjectRecoveryStore(backend);
    final snapshot = EditorProjectRecoverySnapshot(
      capturedAt: DateTime.utc(2026, 10, 21, 1, 5),
      revision: 7,
      document: document,
    );

    await store.save(snapshot);
    final restored = await store.load(document.projectId);

    expect(restored, isNotNull);
    expect(restored!.revision, 7);
    expect(restored.document.toJson(), document.toJson());

    await store.discard(document.projectId);
    expect(await store.load(document.projectId), isNull);
  });
}
