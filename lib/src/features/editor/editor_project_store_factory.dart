import 'editor_project_document.dart';
import 'editor_project_recovery.dart';
import 'editor_project_store_factory_native.dart' as platform;

Future<EditorProjectStore> openDefaultEditorProjectStore() =>
    platform.openDefaultEditorProjectStore();

Future<EditorProjectRecoveryStore> openDefaultEditorProjectRecoveryStore() =>
    platform.openDefaultEditorProjectRecoveryStore();
