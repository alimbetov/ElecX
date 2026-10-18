import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/engineering_placement_cursor.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EngineeringPlacementCursor', () {
    test('nudges in surface-local millimetres', () {
      final surface = RoomSurfaceRef.floor('room-1');
      final state = EngineeringPlacementCursorState(
        surface: surface,
        position: const SurfacePointMm(1200, 900),
        componentType: ElectricalComponentType.socketOutlet,
      );

      final moved = EngineeringPlacementCursor.nudge(
        state,
        dxMm: 100,
        dyMm: -50,
      );

      expect(moved.position.xMm, 1300);
      expect(moved.position.yMm, 850);
      expect(moved.surface, surface);
      expect(moved.snapKind, PlacementCursorSnapKind.grid);
    });

    test('moveTo preserves component and reports snap source', () {
      final state = EngineeringPlacementCursorState(
        surface: RoomSurfaceRef.wall('room-1', 2),
        position: const SurfacePointMm(0, 0),
        componentType: ElectricalComponentType.switchControl,
      );

      final moved = EngineeringPlacementCursor.moveTo(
        state,
        const SurfacePointMm(900, 900),
        snapKind: PlacementCursorSnapKind.installationGuide,
        snapLabel: 'SWITCH 900',
      );

      expect(moved.position.xMm, 900);
      expect(moved.position.yMm, 900);
      expect(moved.componentType, ElectricalComponentType.switchControl);
      expect(moved.snapKind, PlacementCursorSnapKind.installationGuide);
      expect(moved.snapLabel, 'SWITCH 900');
      expect(moved.coordinateLabel, 'X 900 · Y 900 mm');
    });
  });
}
