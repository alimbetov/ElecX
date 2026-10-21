import 'editor_project_document.dart';
import 'editor_project_recovery.dart';

Future<EditorProjectStore> openDefaultEditorProjectStore() =>
    JsonFileEditorProjectStore.openDefault();

Future<EditorProjectRecoveryStore> openDefaultEditorProjectRecoveryStore() =>
    JsonFileEditorProjectRecoveryStore.openDefault();
