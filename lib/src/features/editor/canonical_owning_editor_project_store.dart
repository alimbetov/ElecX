import 'canonical_editor_production_bootstrap.dart';
import 'editor_project_document.dart';

/// Production save boundary combining the existing editor document with the
/// canonical P7A sidecar for the same ProjectId.
///
/// Canonical state is flushed first. If the legacy write then fails, the next
/// production bootstrap validates canonical/legacy geometry and refuses write
/// capability rather than silently attaching the newer sidecar to stale
/// materialized geometry.
final class CanonicalOwningEditorProjectStore implements EditorProjectStore {
  const CanonicalOwningEditorProjectStore({
    required this.legacy,
    required this.canonical,
  });

  final EditorProjectStore legacy;
  final CanonicalEditorProductionHandle canonical;

  @override
  Future<void> save(EditorProjectDocument document) async {
    if (document.projectId != canonical.owner.projectId.value) {
      throw StateError(
        'Canonical save owner ${canonical.owner.projectId} cannot persist '
        'legacy project ${document.projectId}.',
      );
    }
    await canonical.saveCanonical();
    await legacy.save(document);
  }

  @override
  Future<EditorProjectDocument?> load(String projectId) => legacy.load(projectId);

  @override
  Future<List<EditorProjectDocument>> list() => legacy.list();
}
