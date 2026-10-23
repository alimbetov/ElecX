import '../../application/project/project_mutation.dart';
import '../../application/project/project_space_semantics_editing.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_space_semantics.dart';
import 'canonical_space_semantics_adapter.dart';

enum SpaceSemanticsInspectorEditingIssueCode {
  projectMismatch,
  editingDisabled,
}

final class SpaceSemanticsInspectorEditingException implements Exception {
  const SpaceSemanticsInspectorEditingException({
    required this.code,
    required this.message,
    this.projectId,
  });

  final SpaceSemanticsInspectorEditingIssueCode code;
  final String message;
  final ProjectId? projectId;

  @override
  String toString() => '${code.name}: $message';
}

/// P6F presentation/application boundary for one projected canonical Space.
///
/// The projection version is always forwarded as expectedVersion. A stale
/// inspector therefore cannot overwrite a newer canonical semantic mutation.
final class SpaceSemanticsInspectorEditingCoordinator {
  const SpaceSemanticsInspectorEditingCoordinator(this.editing);

  final ProjectSpaceSemanticsEditingPort editing;

  ProjectMutationResult? setUsage(
    CanonicalSpaceSemanticsProjection projection,
    SpaceUsage usage,
  ) {
    if (!editing.canEdit) {
      throw const SpaceSemanticsInspectorEditingException(
        code: SpaceSemanticsInspectorEditingIssueCode.editingDisabled,
        message: 'Space semantics editing is disabled for this runtime.',
      );
    }
    if (editing.projectId != projection.projectId) {
      throw SpaceSemanticsInspectorEditingException(
        code: SpaceSemanticsInspectorEditingIssueCode.projectMismatch,
        projectId: editing.projectId,
        message: 'Inspector projection belongs to ${projection.projectId}, '
            'but editing port owns ${editing.projectId}.',
      );
    }
    return editing.setUsage(
      projection.spaceId,
      usage,
      expectedVersion: projection.projectVersion,
    );
  }
}
