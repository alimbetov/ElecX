import 'editor_building_workspace.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'editor_project_document.dart';
import 'project_persistence_metadata.dart';

/// Creates the first durable legacy editor document for a new ProjectId.
///
/// Production uses this before canonical sidecar bootstrap so canonical identity
/// can never be persisted without a matching legacy project document.
EditorProjectDocument createInitialEditorProjectDocument(
  EditorProjectMetadata metadata,
) {
  final controller = EditorController.blank(
    levelId: 'level-${metadata.projectId}-1',
  );
  final workspace = EditorBuildingWorkspace.blank(
    controller,
    projectId: metadata.projectId,
    projectName: metadata.projectName,
  );
  try {
    return EditorProjectDocument.capture(
      workspace,
      metadata: metadata,
      now: metadata.createdAt,
    );
  } finally {
    workspace.dispose();
    controller.disposeP2State();
    controller.dispose();
  }
}
