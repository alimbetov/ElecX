import '../../application/project/project_room_rectangle_authoring.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_identity.dart';
import 'canonical_editor_production_bootstrap.dart';
import 'canonical_editor_production_materializer.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'editor_p2_session.dart';
import 'editor_project_document.dart';

/// Generates a small deterministic apartment-like demo through the same
/// canonical production authoring path used by interactive room creation.
///
/// The generator deliberately does not inject entities into stores and does not
/// write persistence JSON directly. Every room is committed through
/// [RoomRectangleAuthoringService], acknowledged by the production persistence
/// owner and materialized through [CanonicalEditorProductionMaterializer].
final class CanonicalEditorDemoGenerator {
  const CanonicalEditorDemoGenerator();

  CanonicalEditorDemoGenerationResult generate({
    required EditorProjectDocument initialDocument,
    required CanonicalEditorProductionHandle handle,
  }) {
    if (handle.session.project.stores.spaces.isNotEmpty ||
        handle.session.project.stores.boundaries.isNotEmpty) {
      throw StateError(
        'Demo generation requires a canonical project without authored spaces.',
      );
    }

    final levelId = handle.session.navigation.activeLevelId;
    if (levelId == null) {
      throw StateError('Demo generation requires an active canonical Level.');
    }

    final service = RoomRectangleAuthoringService(
      session: handle.session,
      mutations: handle.wizardMutations,
    );
    final roomIds = <SpaceId>[];
    for (final room in _rooms) {
      final result = service.commit(
        RoomRectangleAuthoringIntent(
          levelId: levelId,
          first: room.first,
          second: room.second,
          name: room.name,
        ),
      );
      handle.runtimeConfig.onCanonicalMutationCommitted!(
        handle.session,
        result.commit.mutation,
      );
      roomIds.add(result.spaceId);
    }

    final restored = initialDocument.restore();
    final workspace = restored.workspace;
    final editor = restored.editor;
    try {
      final adapter = CanonicalEditorWorkspaceAdapter(
        workspace: workspace,
        binding: handle.binding,
      );
      const materializer = CanonicalEditorProductionMaterializer();
      for (final roomId in roomIds) {
        handle.session.selectRoom(roomId);
        final result = materializer.materialize(
          project: handle.session.project,
          navigation: handle.session.navigation,
          adapter: adapter,
        );
        if (!result.canOpen) {
          throw StateError(
            'Demo room $roomId could not be materialized into the editor.',
          );
        }
      }

      final document = EditorProjectDocument.capture(
        workspace,
        metadata: initialDocument.metadata,
      );
      return CanonicalEditorDemoGenerationResult(
        document: document,
        canonicalHandle: handle.rebindToLegacy(document),
        roomIds: List<SpaceId>.unmodifiable(roomIds),
      );
    } finally {
      workspace.dispose();
      editor.disposeP2State();
      editor.dispose();
    }
  }
}

final class CanonicalEditorDemoGenerationResult {
  const CanonicalEditorDemoGenerationResult({
    required this.document,
    required this.canonicalHandle,
    required this.roomIds,
  });

  final EditorProjectDocument document;
  final CanonicalEditorProductionHandle canonicalHandle;
  final List<SpaceId> roomIds;
}

final class _DemoRoom {
  const _DemoRoom({
    required this.name,
    required this.first,
    required this.second,
  });

  final String name;
  final BoundaryPointMm first;
  final BoundaryPointMm second;
}

const List<_DemoRoom> _rooms = <_DemoRoom>[
  _DemoRoom(
    name: 'Гостиная',
    first: BoundaryPointMm(xMm: 0, yMm: 0),
    second: BoundaryPointMm(xMm: 6000, yMm: 4500),
  ),
  _DemoRoom(
    name: 'Кухня',
    first: BoundaryPointMm(xMm: 6000, yMm: 0),
    second: BoundaryPointMm(xMm: 9600, yMm: 3000),
  ),
  _DemoRoom(
    name: 'Спальня',
    first: BoundaryPointMm(xMm: 0, yMm: 4500),
    second: BoundaryPointMm(xMm: 4200, yMm: 8100),
  ),
  _DemoRoom(
    name: 'Санузел',
    first: BoundaryPointMm(xMm: 4200, yMm: 4500),
    second: BoundaryPointMm(xMm: 6600, yMm: 6700),
  ),
];