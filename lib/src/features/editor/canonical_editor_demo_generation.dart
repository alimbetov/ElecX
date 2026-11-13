import '../../application/project/project_room_rectangle_authoring.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/surfaces.dart';
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
/// owner, materialized through [CanonicalEditorProductionMaterializer], and
/// saved through the ordinary canonical repository owner.
final class CanonicalEditorDemoGenerator {
  const CanonicalEditorDemoGenerator();

  Future<CanonicalEditorDemoGenerationResult> generate({
    required EditorProjectDocument initialDocument,
    required CanonicalEditorProductionHandle handle,
  }) async {
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

      // Use the same placement/history boundary as interactive authoring.
      // This fixture contains equipment only: no routes or unqualified design
      // values are pre-applied or presented as an approved electrical scheme.
      for (var index = 0; index < roomIds.length; index++) {
        final id = roomIds[index];
        final legacyId = handle.binding.legacySpaceIds[id]!;
        final topology = handle.session.project.index.boundary(id)!;
        final wall = RoomSurfaceRef.wallByBoundaryEdge(
          legacyId,
          topology.orderedEdgeIds.first,
        );
        if (index == 3) {
          editor.p2.placeComponent(
            type: ElectricalComponentType.distributionBoard,
            surface: wall,
            position: const SurfacePointMm(500, 1500),
          );
        } else {
          for (final x in [1000, 2500]) {
            editor.p2.placeComponent(
              type: ElectricalComponentType.socketOutlet,
              surface: wall,
              position: SurfacePointMm(x, 300),
            );
          }
          editor.p2.placeComponent(
            type: ElectricalComponentType.switchControl,
            surface: wall,
            position: const SurfacePointMm(500, 900),
          );
          editor.p2.placeComponent(
            type: ElectricalComponentType.lightingPoint,
            surface: RoomSurfaceRef.ceiling(legacyId),
            position: const SurfacePointMm(1800, 1700),
          );
        }
      }
      editor.p2.clearSelection();
      final document = EditorProjectDocument.capture(
        workspace,
        metadata: initialDocument.metadata,
      );
      await handle.saveCanonical();
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
    second: BoundaryPointMm(xMm: 4000, yMm: 3500),
  ),
  _DemoRoom(
    name: 'Спальня',
    first: BoundaryPointMm(xMm: 4000, yMm: 0),
    second: BoundaryPointMm(xMm: 8000, yMm: 3500),
  ),
  _DemoRoom(
    name: 'Кухня',
    first: BoundaryPointMm(xMm: 8000, yMm: 0),
    second: BoundaryPointMm(xMm: 11500, yMm: 3500),
  ),
  _DemoRoom(
    name: 'Коридор',
    first: BoundaryPointMm(xMm: 0, yMm: 3500),
    second: BoundaryPointMm(xMm: 11500, yMm: 5000),
  ),
];
