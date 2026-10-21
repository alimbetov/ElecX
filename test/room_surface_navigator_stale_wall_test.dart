import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/room_surface_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'stale removed wall fails closed to Plan instead of reusing wall index',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      controller.showWall(5);
      expect(controller.activeSurface?.wallIndex, 5);

      await tester.pumpWidget(
        MaterialApp(
          home: RoomSurfaceNavigator(
            controller: controller,
            canonicalSpaceId: SpaceId('canonical-stale-room'),
            legacySpaceId: 'stale-room',
            collapsed: false,
            onToggleCollapsed: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Current surface: Wall 6'), findsOneWidget);

      final reducedBoundary = MmPolygon.rectangle(
        const MmPoint(0, 0),
        const MmPoint(6000, 5000),
      );
      controller.level = controller.level.copyWith(
        spaces: [
          EngineeringSpace(
            id: 'stale-room',
            name: 'Stale Room',
            type: SpaceType.room,
            boundary: reducedBoundary,
            referenceFrame: RoomReferenceFrame(
              origin: reducedBoundary.bounds.center,
            ),
          ),
        ],
      );

      // Trigger a normal controller notification without repairing activeSurface.
      // The P5E projection must detect that wall index 5 no longer exists.
      controller.selectSpace('stale-room');
      await tester.pump();
      await tester.pump();

      expect(controller.viewMode, EditorViewMode.plan);
      expect(controller.activeSurface, isNull);
      expect(find.text('Current surface: Plan'), findsOneWidget);
    },
  );
}

EditorController _controller() {
  final boundary = MmPolygon(const [
    MmPoint(0, 0),
    MmPoint(6000, 0),
    MmPoint(6000, 2500),
    MmPoint(3500, 2500),
    MmPoint(3500, 5000),
    MmPoint(0, 5000),
  ]);
  final controller = EditorController.restored(
    level: BuildingLevel(
      id: 'stale-level',
      name: 'Stale Level',
      elevationMm: 0,
      spaces: [
        EngineeringSpace(
          id: 'stale-room',
          name: 'Stale Room',
          type: SpaceType.room,
          boundary: boundary,
          referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
        ),
      ],
    ),
    openings: const [],
  );
  controller.selectSpace('stale-room');
  return controller;
}
