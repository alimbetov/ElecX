import 'canonical_boundary_host_projection.dart';
import 'editor_controller.dart';
import 'editor_document_history.dart';
import 'editor_p2_session.dart';

/// Applies one already-calculated canonical hosted-object projection to the
/// transitional editor without manufacturing architecture/P2 history entries.
///
/// Canonical P3 remains the authority. The legacy editor state is only a
/// materialized view and can always be reconstructed again after Undo/Redo.
abstract final class CanonicalBoundaryHostMaterializer {
  static void apply(
    EditorController controller,
    EditorP2Session p2,
    CanonicalBoundaryHostMaterialization materialization,
  ) {
    final selected = controller.selectedSpace;
    if (selected == null || selected.id != materialization.space.id) {
      throw StateError(
        'Canonical host materialization must target the selected legacy room.',
      );
    }

    final level = controller.level.copyWith(
      spaces: [
        for (final space in controller.level.spaces)
          if (space.id == materialization.space.id)
            materialization.space
          else
            space,
      ],
    );

    controller.documentHistory.runCanonicalProjection(() {
      controller.restoreDocumentArchitecture(
        level: level,
        openings: materialization.openings,
        roomSequence: controller.roomSequence,
        openingSequence: controller.openingSequence,
        selectedSpaceId: materialization.space.id,
        selectedOpeningId: controller.selectedOpeningId,
      );

      // This is a projection replacement, not an electrical authoring command.
      // Keep the P2 command stack intact; EditorDocumentHistory suppresses the
      // resulting mutation revision while inside runCanonicalProjection().
      p2.history.replaceState(
        materialization.p2State,
        clearHistory: false,
      );

      // EditorP2Session intentionally keeps ChangeNotifier encapsulation. A
      // same-value presentation setter emits one notification without creating
      // history, allowing existing P2 widgets to rebuild from projected state.
      p2.setPlacementType(p2.placementType);
    });
  }
}
