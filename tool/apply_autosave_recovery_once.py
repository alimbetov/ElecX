from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}: {old[:80]!r}')
    path.write_text(text.replace(old, new, 1))


root = Path('.')
editor = root / 'lib/src/features/editor'

(editor / 'project_save_diagnostics.dart').write_text(r'''import 'dart:io';

import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import 'editor_building_workspace.dart';


enum EditorProjectSaveIssueCode {
  activeTransform,
  unfinishedDraft,
  missingComponent,
  missingPort,
  incompatiblePorts,
  disconnectedRoute,
}

final class EditorProjectSaveIssue {
  const EditorProjectSaveIssue({
    required this.code,
    required this.title,
    required this.detail,
    this.routeId,
    this.componentId,
  });

  final EditorProjectSaveIssueCode code;
  final String title;
  final String detail;
  final String? routeId;
  final String? componentId;

  String get userMessage => '$title\n$detail';
}

final class EditorProjectSaveBlockedException implements Exception {
  const EditorProjectSaveBlockedException(this.issue);

  final EditorProjectSaveIssue issue;

  @override
  String toString() => issue.userMessage;
}

abstract final class EditorProjectSaveDiagnostics {
  static List<EditorProjectSaveIssue> validate(
    EditorBuildingWorkspace workspace,
  ) {
    final editor = workspace.editor;
    final issues = <EditorProjectSaveIssue>[];

    if (editor.p2.isManipulating) {
      issues.add(
        const EditorProjectSaveIssue(
          code: EditorProjectSaveIssueCode.activeTransform,
          title: 'Завершите редактирование компонента',
          detail:
              'Сейчас активен preview перемещения. Подтвердите его Enter/отпусканием указателя или отмените Escape, затем сохраните проект.',
        ),
      );
    }
    if (editor.routeSegments.isNotEmpty || editor.draftStart != null) {
      issues.add(
        const EditorProjectSaveIssue(
          code: EditorProjectSaveIssueCode.unfinishedDraft,
          title: 'Есть незавершённая трасса',
          detail:
              'Завершите построение кабеля или отмените черновик перед сохранением.',
        ),
      );
    }

    final components = {
      for (final component in editor.p2.components) component.id: component,
    };
    for (final route in editor.p2.routes) {
      final sourceComponent = components[route.source.componentId];
      if (sourceComponent == null) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.missingComponent,
            title: 'Кабель ссылается на отсутствующий компонент',
            detail:
                'Трасса ${route.id}: источник ${route.source.componentId} не найден. Переподключите или удалите повреждённую трассу.',
            routeId: route.id,
            componentId: route.source.componentId,
          ),
        );
        continue;
      }
      final targetComponent = components[route.target.componentId];
      if (targetComponent == null) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.missingComponent,
            title: 'Кабель ссылается на отсутствующий компонент',
            detail:
                'Трасса ${route.id}: приёмник ${route.target.componentId} не найден. Переподключите или удалите повреждённую трассу.',
            routeId: route.id,
            componentId: route.target.componentId,
          ),
        );
        continue;
      }

      final sourcePort = _port(sourceComponent, route.source.portId);
      if (sourcePort == null) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.missingPort,
            title: 'Не найден порт источника кабеля',
            detail:
                'Трасса ${route.id}: у «${sourceComponent.label}» нет порта ${route.source.portId}. Переподключите конец кабеля.',
            routeId: route.id,
            componentId: sourceComponent.id,
          ),
        );
        continue;
      }
      final targetPort = _port(targetComponent, route.target.portId);
      if (targetPort == null) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.missingPort,
            title: 'Не найден порт приёмника кабеля',
            detail:
                'Трасса ${route.id}: у «${targetComponent.label}» нет порта ${route.target.portId}. Переподключите конец кабеля.',
            routeId: route.id,
            componentId: targetComponent.id,
          ),
        );
        continue;
      }

      if (!ElectricalPortCompatibility.areCompatible(
        sourcePort.kind,
        targetPort.kind,
      )) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.incompatiblePorts,
            title: 'Кабель подключён не к тому типу порта',
            detail:
                'Трасса ${route.id}: «${sourceComponent.label}» ${sourcePort.kind.name} → «${targetComponent.label}» ${targetPort.kind.name}. Эти порты несовместимы. Выберите совместимый вход/выход и переподключите конец кабеля.',
            routeId: route.id,
            componentId: targetComponent.id,
          ),
        );
        continue;
      }

      if (route.segments.isEmpty) {
        issues.add(
          EditorProjectSaveIssue(
            code: EditorProjectSaveIssueCode.disconnectedRoute,
            title: 'У кабеля отсутствует геометрия трассы',
            detail:
                'Трасса ${route.id} подключена семантически, но не содержит ни одного физического сегмента. Постройте трассу заново.',
            routeId: route.id,
          ),
        );
      }
    }
    return List.unmodifiable(issues);
  }

  static EditorProjectSaveIssue? firstBlocking(
    EditorBuildingWorkspace workspace,
  ) {
    final issues = validate(workspace);
    return issues.isEmpty ? null : issues.first;
  }

  static String unexpectedPersistenceMessage(Object error) {
    if (error is FileSystemException) {
      return 'Не удалось записать файл проекта. Проверьте доступ к папке документов и свободное место на диске.';
    }
    return 'Не удалось записать проект из-за внутренней ошибки (${error.runtimeType}). Повторите сохранение; если ошибка повторится, откройте диагностику проекта.';
  }

  static ElectricalPortDefinition? _port(
    ElectricalComponentPlacement component,
    String portId,
  ) {
    for (final port in component.ports) {
      if (port.id == portId) return port;
    }
    return null;
  }
}
''')

(editor / 'editor_project_recovery.dart').write_text(r'''import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'editor_project_document.dart';

final class EditorProjectRecoverySnapshot {
  const EditorProjectRecoverySnapshot({
    required this.capturedAt,
    required this.revision,
    required this.document,
  });

  static const formatVersion = 1;

  final DateTime capturedAt;
  final int revision;
  final EditorProjectDocument document;

  String get projectId => document.projectId;

  Map<String, Object?> toJson() => {
        'recoveryVersion': formatVersion,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'revision': revision,
        'document': document.toJson(),
      };

  factory EditorProjectRecoverySnapshot.fromJson(Map<String, Object?> json) {
    final version = json['recoveryVersion'];
    if (version != formatVersion) {
      throw FormatException('Unsupported ElecX recovery version $version.');
    }
    final rawDocument = json['document'];
    if (rawDocument is! Map) {
      throw const FormatException('Recovery document must be a JSON object.');
    }
    final revision = json['revision'];
    if (revision is! int || revision < 0) {
      throw const FormatException('Recovery revision must be non-negative.');
    }
    final capturedAtRaw = json['capturedAt'];
    if (capturedAtRaw is! String) {
      throw const FormatException('Recovery capturedAt must be a string.');
    }
    return EditorProjectRecoverySnapshot(
      capturedAt: DateTime.parse(capturedAtRaw).toUtc(),
      revision: revision,
      document: EditorProjectDocument.fromJson(
        rawDocument.map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
  }
}

abstract interface class EditorProjectRecoveryStore {
  Future<void> save(EditorProjectRecoverySnapshot snapshot);
  Future<EditorProjectRecoverySnapshot?> load(String projectId);
  Future<List<EditorProjectRecoverySnapshot>> list();
  Future<void> discard(String projectId);
}

final class JsonFileEditorProjectRecoveryStore
    implements EditorProjectRecoveryStore {
  JsonFileEditorProjectRecoveryStore(this.rootDirectory);

  final Directory rootDirectory;

  static Future<JsonFileEditorProjectRecoveryStore> openDefault() async {
    final documents = await getApplicationDocumentsDirectory();
    return JsonFileEditorProjectRecoveryStore(
      Directory(path.join(documents.path, 'ElecX', 'recovery')),
    );
  }

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {
    await rootDirectory.create(recursive: true);
    final encoded = jsonEncode(snapshot.toJson());
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw StateError('Encoded ElecX recovery is not a JSON object.');
    }
    EditorProjectRecoverySnapshot.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );

    final target = _target(snapshot.projectId);
    final temp = File('${target.path}.tmp');
    if (await temp.exists()) await temp.delete();
    await temp.writeAsString(encoded, flush: true);
    if (await target.exists()) await target.delete();
    await temp.rename(target.path);
  }

  @override
  Future<EditorProjectRecoverySnapshot?> load(String projectId) async {
    final target = _target(projectId);
    if (!await target.exists()) return null;
    final raw = jsonDecode(await target.readAsString());
    if (raw is! Map) {
      throw const FormatException('ElecX recovery root must be an object.');
    }
    final snapshot = EditorProjectRecoverySnapshot.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (snapshot.projectId != projectId) {
      throw const FormatException('Recovery project id mismatch.');
    }
    return snapshot;
  }

  @override
  Future<List<EditorProjectRecoverySnapshot>> list() async {
    if (!await rootDirectory.exists()) return const [];
    final result = <EditorProjectRecoverySnapshot>[];
    await for (final entity in rootDirectory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.elecx.recovery.json')) {
        continue;
      }
      final raw = jsonDecode(await entity.readAsString());
      if (raw is! Map) continue;
      result.add(
        EditorProjectRecoverySnapshot.fromJson(
          raw.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    }
    result.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List.unmodifiable(result);
  }

  @override
  Future<void> discard(String projectId) async {
    final target = _target(projectId);
    final temp = File('${target.path}.tmp');
    if (await target.exists()) await target.delete();
    if (await temp.exists()) await temp.delete();
  }

  File _target(String projectId) {
    final encoded = base64Url.encode(utf8.encode(projectId)).replaceAll('=', '');
    return File(path.join(rootDirectory.path, '$encoded.elecx.recovery.json'));
  }
}
''')

doc = editor / 'editor_project_document.dart'
replace_once(
    doc,
    "import 'project_persistence_metadata.dart';\nimport 'project_schema_migrator.dart';",
    "import 'project_persistence_metadata.dart';\nimport 'project_save_diagnostics.dart';\nimport 'project_schema_migrator.dart';",
)
replace_once(
    doc,
    """    final editor = workspace.editor;
    if (editor.p2.isManipulating) {
      throw StateError('Cannot save while a component transform is active.');
    }
    if (editor.routeSegments.isNotEmpty || editor.draftStart != null) {
      throw StateError('Cannot save an unfinished editor draft.');
    }
    workspace.synchronizeActiveEditorState();
""",
    """    final editor = workspace.editor;
    final blockingIssue = EditorProjectSaveDiagnostics.firstBlocking(workspace);
    if (blockingIssue != null) {
      throw EditorProjectSaveBlockedException(blockingIssue);
    }
    workspace.synchronizeActiveEditorState();
""",
)

screen = editor / 'unified_workspace_editor_screen.dart'
replace_once(
    screen,
    "import 'package:flutter/material.dart';",
    "import 'dart:async';\n\nimport 'package:flutter/material.dart';",
)
replace_once(
    screen,
    "import 'editor_project_document.dart';\nimport 'project_persistence_metadata.dart';",
    "import 'editor_project_document.dart';\nimport 'editor_project_recovery.dart';\nimport 'project_persistence_metadata.dart';\nimport 'project_save_diagnostics.dart';",
)
replace_once(
    screen,
    """    this.projectStore,
    this.initialDocument,
    this.initialMetadata,
  });
""",
    """    this.projectStore,
    this.recoveryStore,
    this.autosaveDelay = const Duration(seconds: 2),
    this.initialDocument,
    this.initialMetadata,
  });
""",
)
replace_once(
    screen,
    """  final EditorProjectStore? projectStore;

  /// When provided, the screen starts from the persisted canonical document
""",
    """  final EditorProjectStore? projectStore;

  /// Recovery storage is intentionally separate from explicit project files.
  final EditorProjectRecoveryStore? recoveryStore;

  /// Debounce used by recovery autosave. Exposed for deterministic tests.
  final Duration autosaveDelay;

  /// When provided, the screen starts from the persisted canonical document
""",
)
replace_once(
    screen,
    """  Future<EditorProjectStore>? _projectStoreFuture;
  bool _projectIoBusy = false;
""",
    """  Future<EditorProjectStore>? _projectStoreFuture;
  Future<EditorProjectRecoveryStore>? _recoveryStoreFuture;
  Timer? _autosaveTimer;
  bool _autosaveInFlight = false;
  int _lastAutosavedRevision = -1;
  String? _saveFailureHint;
  bool _projectIoBusy = false;
""",
)
replace_once(
    screen,
    """    final injectedStore = widget.projectStore;
    if (injectedStore != null) {
      _projectStoreFuture = Future<EditorProjectStore>.value(injectedStore);
    }
  }

  Future<EditorProjectStore> _projectStore() =>
      _projectStoreFuture ??= JsonFileEditorProjectStore.openDefault();
""",
    """    final injectedStore = widget.projectStore;
    if (injectedStore != null) {
      _projectStoreFuture = Future<EditorProjectStore>.value(injectedStore);
    }
    final injectedRecoveryStore = widget.recoveryStore;
    if (injectedRecoveryStore != null) {
      _recoveryStoreFuture =
          Future<EditorProjectRecoveryStore>.value(injectedRecoveryStore);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleAutosave();
      _offerRecoveryIfNewer();
    });
  }

  Future<EditorProjectStore> _projectStore() =>
      _projectStoreFuture ??= JsonFileEditorProjectStore.openDefault();

  Future<EditorProjectRecoveryStore> _recoveryStore() =>
      _recoveryStoreFuture ??= JsonFileEditorProjectRecoveryStore.openDefault();
""",
)
replace_once(
    screen,
    """    _refresh();
  }

  Future<void> _saveProject() async {
""",
    """    _refresh();
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    if (!_hasUnsavedChanges) return;
    _autosaveTimer = Timer(widget.autosaveDelay, _writeRecoverySnapshot);
  }

  Future<void> _writeRecoverySnapshot() async {
    if (!mounted ||
        _autosaveInFlight ||
        _projectIoBusy ||
        !_hasUnsavedChanges ||
        _lastAutosavedRevision == _projectRevision) {
      return;
    }
    final issue = EditorProjectSaveDiagnostics.firstBlocking(workspace);
    if (issue != null) return;
    final revision = _projectRevision;
    _autosaveInFlight = true;
    try {
      final document = EditorProjectDocument.capture(
        workspace,
        metadata: _projectMetadata,
      );
      final store = await _recoveryStore();
      await store.save(
        EditorProjectRecoverySnapshot(
          capturedAt: DateTime.now().toUtc(),
          revision: revision,
          document: document,
        ),
      );
      _lastAutosavedRevision = revision;
    } catch (error) {
      debugPrint('ElecX recovery autosave skipped: $error');
    } finally {
      _autosaveInFlight = false;
    }
  }

  Future<void> _offerRecoveryIfNewer() async {
    try {
      final store = await _recoveryStore();
      final snapshot = await store.load(_projectMetadata.projectId);
      if (!mounted || snapshot == null) return;
      if (!snapshot.capturedAt.isAfter(_projectMetadata.updatedAt)) {
        await store.discard(_projectMetadata.projectId);
        return;
      }
      final restore = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('project-recovery-dialog'),
          title: const Text('Найдена аварийная копия'),
          content: Text(
            'Есть более свежая автокопия от ${snapshot.capturedAt.toLocal()}. '
            'Восстановить несохранённые изменения?',
          ),
          actions: [
            TextButton(
              key: const ValueKey('discard-project-recovery'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Удалить копию'),
            ),
            FilledButton(
              key: const ValueKey('restore-project-recovery'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Восстановить'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (restore == true) {
        final restored = snapshot.document.restore();
        _replaceProject(
          restored,
          snapshot.document.metadata,
          markSaved: false,
          recoveryRevision: snapshot.revision,
        );
        _lastAutosavedRevision = snapshot.revision;
        _showProjectMessage('Восстановлена аварийная копия');
      } else if (restore == false) {
        await store.discard(snapshot.projectId);
      }
    } catch (error) {
      debugPrint('ElecX recovery lookup skipped: $error');
    }
  }

  Future<void> _discardRecoveryBestEffort() async {
    _autosaveTimer?.cancel();
    try {
      final store = await _recoveryStore();
      await store.discard(_projectMetadata.projectId);
      _lastAutosavedRevision = -1;
    } catch (error) {
      debugPrint('ElecX recovery cleanup skipped: $error');
    }
  }

  Future<void> _showSaveFailure({
    required String title,
    required String detail,
  }) async {
    if (!mounted) return;
    setState(() {
      _saveStatus = EditorProjectSaveStatus.saveFailed;
      _saveFailureHint = detail;
    });
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('save-failure-dialog'),
        title: Text(title),
        content: Text(detail),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProject() async {
""",
)
replace_once(
    screen,
    """  Future<void> _saveProject() async {
    if (_projectIoBusy) return;
    final revisionAtCapture = _projectRevision;
""",
    """  Future<void> _saveProject() async {
    if (_projectIoBusy) return;
    final blockingIssue = EditorProjectSaveDiagnostics.firstBlocking(workspace);
    if (blockingIssue != null) {
      await _showSaveFailure(
        title: blockingIssue.title,
        detail: blockingIssue.detail,
      );
      return;
    }
    final revisionAtCapture = _projectRevision;
""",
)
replace_once(
    screen,
    """      _projectMetadata = touchedMetadata;
      _savedRevision = revisionAtCapture;
      _saveStatus = _projectRevision == revisionAtCapture
          ? EditorProjectSaveStatus.saved
          : EditorProjectSaveStatus.modified;
      _showProjectMessage('Проект сохранён');
    } catch (error) {
      if (!mounted) return;
      _saveStatus = EditorProjectSaveStatus.saveFailed;
      _showProjectMessage('Не удалось сохранить проект: $error', isError: true);
""",
    """      _projectMetadata = touchedMetadata;
      _savedRevision = revisionAtCapture;
      _saveFailureHint = null;
      _saveStatus = _projectRevision == revisionAtCapture
          ? EditorProjectSaveStatus.saved
          : EditorProjectSaveStatus.modified;
      if (_projectRevision == revisionAtCapture) {
        await _discardRecoveryBestEffort();
      } else {
        _scheduleAutosave();
      }
      _showProjectMessage('Проект сохранён');
    } on EditorProjectSaveBlockedException catch (error) {
      if (!mounted) return;
      await _showSaveFailure(
        title: error.issue.title,
        detail: error.issue.detail,
      );
    } catch (error) {
      if (!mounted) return;
      final detail =
          EditorProjectSaveDiagnostics.unexpectedPersistenceMessage(error);
      await _showSaveFailure(
        title: 'Не удалось сохранить проект',
        detail: detail,
      );
""",
)
replace_once(
    screen,
    """    setState(() => _projectIoBusy = true);
    try {
      final projectId = _projectMetadata.projectId;
""",
    """    await _discardRecoveryBestEffort();
    setState(() => _projectIoBusy = true);
    try {
      final projectId = _projectMetadata.projectId;
""",
)
replace_once(
    screen,
    """  void _replaceProject(
    RestoredEditorProject restored,
    EditorProjectMetadata metadata,
  ) {
""",
    """  void _replaceProject(
    RestoredEditorProject restored,
    EditorProjectMetadata metadata, {
    bool markSaved = true,
    int recoveryRevision = 1,
  }) {
""",
)
replace_once(
    screen,
    """    _projectMetadata = metadata;
    _projectRevision = 0;
    _savedRevision = 0;
    _saveStatus = EditorProjectSaveStatus.saved;
    siteInteraction.clear();
""",
    """    _projectMetadata = metadata;
    _projectRevision = markSaved ? 0 : (recoveryRevision <= 0 ? 1 : recoveryRevision);
    _savedRevision = 0;
    _saveStatus = markSaved
        ? EditorProjectSaveStatus.saved
        : EditorProjectSaveStatus.modified;
    _saveFailureHint = null;
    siteInteraction.clear();
""",
)
replace_once(
    screen,
    """    if (!discard || !mounted) return;
    setState(() => _allowPop = true);
""",
    """    if (!discard || !mounted) return;
    await _discardRecoveryBestEffort();
    if (!mounted) return;
    setState(() => _allowPop = true);
""",
)
replace_once(
    screen,
    """  void dispose() {
    shell.removeListener(_refresh);
""",
    """  void dispose() {
    _autosaveTimer?.cancel();
    shell.removeListener(_refresh);
""",
)
replace_once(
    screen,
    """                saveStatus: _saveStatus,
                onSaveProject: _saveProject,
""",
    """                saveStatus: _saveStatus,
                saveFailureHint: _saveFailureHint,
                onSaveProject: _saveProject,
""",
)
replace_once(
    screen,
    """    required this.saveStatus,
    required this.onSaveProject,
""",
    """    required this.saveStatus,
    required this.saveFailureHint,
    required this.onSaveProject,
""",
)
replace_once(
    screen,
    """  final EditorProjectSaveStatus saveStatus;
  final VoidCallback onSaveProject;
""",
    """  final EditorProjectSaveStatus saveStatus;
  final String? saveFailureHint;
  final VoidCallback onSaveProject;
""",
)
replace_once(
    screen,
    """            child: Center(
              child: Text(
                saveStatus.label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
""",
    """            child: Center(
              child: Tooltip(
                message: saveFailureHint ?? saveStatus.label,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (saveStatus == EditorProjectSaveStatus.saveFailed) ...[
                      const Icon(Icons.error_outline, size: 16),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      saveStatus.label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
""",
)

(root / 'test/project_recovery_and_save_diagnostics_test.dart').write_text(r'''import 'dart:io';

import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/editor/project_save_diagnostics.dart';
import 'package:elecx/src/features/editor/unified_workspace_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryProjectStore implements EditorProjectStore {
  final Map<String, EditorProjectDocument> documents = {};
  int saves = 0;

  @override
  Future<void> save(EditorProjectDocument document) async {
    saves++;
    documents[document.projectId] = document;
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) async =>
      documents[projectId];

  @override
  Future<List<EditorProjectDocument>> list() async =>
      List.unmodifiable(documents.values);
}

final class _MemoryRecoveryStore implements EditorProjectRecoveryStore {
  final Map<String, EditorProjectRecoverySnapshot> snapshots = {};
  int saves = 0;
  int discards = 0;

  @override
  Future<void> save(EditorProjectRecoverySnapshot snapshot) async {
    saves++;
    snapshots[snapshot.projectId] = snapshot;
  }

  @override
  Future<EditorProjectRecoverySnapshot?> load(String projectId) async =>
      snapshots[projectId];

  @override
  Future<List<EditorProjectRecoverySnapshot>> list() async =>
      List.unmodifiable(snapshots.values);

  @override
  Future<void> discard(String projectId) async {
    discards++;
    snapshots.remove(projectId);
  }
}

EditorProjectDocument _invalidCableDocument() {
  final controller = EditorController.demo();
  final workspace = EditorBuildingWorkspace.demo(controller);
  final metadata = EditorProjectMetadata.create(projectName: 'Invalid cable');
  final base = EditorProjectDocument.capture(workspace, metadata: metadata);
  final surface = RoomSurfaceRef.wall(controller.level.spaces.first.id, 1);
  final source = ElectricalComponentPlacement(
    id: 'source',
    type: ElectricalComponentType.powerSource,
    surface: surface,
    position: const SurfacePointMm(200, 600),
    label: 'Источник',
    ports: ElectricalComponentDefaults.portsFor(
      ElectricalComponentType.powerSource,
    ),
  );
  final target = ElectricalComponentPlacement(
    id: 'light',
    type: ElectricalComponentType.lightingPoint,
    surface: surface,
    position: const SurfacePointMm(1200, 1200),
    label: 'Светильник',
    ports: ElectricalComponentDefaults.portsFor(
      ElectricalComponentType.lightingPoint,
    ),
  );
  final invalidState = EditorP2State(
    components: [source, target],
    routes: [
      ElectricalCableRoute(
        id: 'route-wrong-port',
        source: const ElectricalEndpointRef(
          componentId: 'source',
          portId: 'power-out',
        ),
        target: const ElectricalEndpointRef(
          componentId: 'light',
          portId: 'control-in',
        ),
        segments: [
          ElectricalRouteSegment(
            surface: surface,
            points: const [SurfacePointMm(200, 600), SurfacePointMm(1200, 600)],
          ),
        ],
      ),
    ],
  );
  final document = EditorProjectDocument(
    schemaVersion: base.schemaVersion,
    metadata: base.metadata,
    building: base.building,
    site: base.site,
    workspaceContext: base.workspaceContext,
    activeLevelNumber: base.activeLevelNumber,
    selectedZoneId: base.selectedZoneId,
    activeOutdoorZoneId: base.activeOutdoorZoneId,
    openingsByLevel: base.openingsByLevel,
    resume: base.resume,
    p2State: invalidState,
  );
  workspace.dispose();
  controller.disposeP2State();
  controller.dispose();
  return document;
}

void main() {
  test('save diagnostics explain incompatible cable ports', () {
    final document = _invalidCableDocument();
    final restored = document.restore();
    final issues = EditorProjectSaveDiagnostics.validate(restored.workspace);
    expect(issues, hasLength(1));
    expect(issues.single.code, EditorProjectSaveIssueCode.incompatiblePorts);
    expect(issues.single.detail, contains('powerOut'));
    expect(issues.single.detail, contains('controlIn'));
    expect(issues.single.detail, contains('route-wrong-port'));
    restored.workspace.dispose();
    restored.editor.disposeP2State();
    restored.editor.dispose();
  });

  test('recovery snapshot round-trips separately from project save', () async {
    final temp = await Directory.systemTemp.createTemp('elecx-recovery-');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final controller = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(controller);
    final document = EditorProjectDocument.capture(
      workspace,
      metadata: EditorProjectMetadata.create(projectName: 'Recovery'),
    );
    final store = JsonFileEditorProjectRecoveryStore(temp);
    final snapshot = EditorProjectRecoverySnapshot(
      capturedAt: DateTime.utc(2026, 10, 20, 10, 30),
      revision: 7,
      document: document,
    );
    await store.save(snapshot);
    final loaded = await store.load(document.projectId);
    expect(loaded, isNotNull);
    expect(loaded!.revision, 7);
    expect(loaded.projectId, document.projectId);
    expect(loaded.document.updatedAt, document.updatedAt);
    await store.discard(document.projectId);
    expect(await store.load(document.projectId), isNull);
    workspace.dispose();
    controller.disposeP2State();
    controller.dispose();
  });

  testWidgets('autosave writes recovery but never marks project Saved',
      (tester) async {
    final projects = _MemoryProjectStore();
    final recovery = _MemoryRecoveryStore();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: projects,
          recoveryStore: recovery,
          autosaveDelay: const Duration(milliseconds: 10),
          initialMetadata: EditorProjectMetadata.create(
            projectName: 'Autosave project',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(recovery.saves, greaterThanOrEqualTo(1));
    expect(projects.saves, 0);
    expect(find.text('Modified'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();
    expect(projects.saves, 1);
    expect(recovery.snapshots, isEmpty);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('Save failed shows actionable incompatible cable hint',
      (tester) async {
    final projects = _MemoryProjectStore();
    final recovery = _MemoryRecoveryStore();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedWorkspaceEditorScreen(
          projectStore: projects,
          recoveryStore: recovery,
          initialDocument: _invalidCableDocument(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-failure-dialog')), findsOneWidget);
    expect(find.text('Кабель подключён не к тому типу порта'), findsOneWidget);
    expect(find.textContaining('powerOut'), findsOneWidget);
    expect(find.textContaining('controlIn'), findsOneWidget);
    expect(find.text('Save failed'), findsOneWidget);
    expect(projects.saves, 0);
  });
}
''')
