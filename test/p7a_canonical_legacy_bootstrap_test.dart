import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/features/editor/canonical_editor_legacy_bootstrap.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy bootstrap is deterministic and preserves canonical edge identity',
    () {
      final polygon = MmPolygon.rectangle(
        const MmPoint(0, 0),
        const MmPoint(4000, 3000),
      );
      final space = EngineeringSpace(
        id: 'room-A',
        name: 'Room A',
        type: SpaceType.room,
        boundary: polygon,
        referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
      );
      final controller = EditorController.restored(
        level: BuildingLevel(
          id: 'level-1',
          name: 'Level 1',
          elevationMm: 0,
          spaces: [space],
        ),
        openings: const [],
      );
      final workspace = EditorBuildingWorkspace.blank(
        controller,
        projectId: 'P-100',
        projectName: 'Bootstrap project',
      );
      addTearDown(() {
        workspace.dispose();
        controller.disposeP2State();
        controller.dispose();
      });

      final document = EditorProjectDocument.capture(
        workspace,
        now: DateTime.utc(2026, 10, 23, 6),
      );
      final first = CanonicalEditorLegacyBootstrap.create(document);
      final second = CanonicalEditorLegacyBootstrap.create(document);

      expect(first.snapshot.id.value, document.projectId);
      expect(second.snapshot.id, first.snapshot.id);
      expect(second.snapshot.siteId, first.snapshot.siteId);
      expect(second.binding.buildingId, first.binding.buildingId);
      expect(second.binding.legacyLevelIds, first.binding.legacyLevelIds);
      expect(second.binding.legacySpaceIds, first.binding.legacySpaceIds);

      final firstSpaceId = first.binding.legacySpaceIds.entries
          .singleWhere((entry) => entry.value == 'room-A')
          .key;
      final secondSpaceId = second.binding.legacySpaceIds.entries
          .singleWhere((entry) => entry.value == 'room-A')
          .key;
      expect(secondSpaceId, firstSpaceId);

      final firstBoundary =
          first.snapshot.aggregate.index.boundary(firstSpaceId)!;
      final secondBoundary =
          second.snapshot.aggregate.index.boundary(secondSpaceId)!;
      expect(secondBoundary.orderedEdgeIds, firstBoundary.orderedEdgeIds);
      expect(firstBoundary.orderedEdgeIds, hasLength(4));
      expect(
        first.snapshot.aggregate.engineeringMetadata.boundaryEdgeIdentityRegistry
            .ownerOf(firstBoundary.orderedEdgeIds.first),
        firstSpaceId,
      );
    },
  );
}
