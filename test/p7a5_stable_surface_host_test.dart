import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-5 stable wall surface host', () {
    test('canonical wall identity is BoundaryEdgeId, not wall ordinal', () {
      final edgeId = BoundaryEdgeId('edge-stable');
      final surface = RoomSurfaceRef.wallByBoundaryEdge('room-a', edgeId);

      expect(surface.type, SurfacePlaneType.wall);
      expect(surface.boundaryEdgeId, edgeId);
      expect(surface.wallIndex, isNull);
      expect(surface.isCanonicalWall, isTrue);
      expect(surface.id, 'room-a:boundary:edge-stable');
    });

    test('legacy wall ordinal remains explicitly transitional', () {
      final surface = RoomSurfaceRef.wall('room-a', 2);

      expect(surface.boundaryEdgeId, isNull);
      expect(surface.wallIndex, 2);
      expect(surface.isLegacyWall, isTrue);
      expect(surface.isCanonicalWall, isFalse);
    });

    test('stable and ordinal wall refs never alias', () {
      expect(
        RoomSurfaceRef.wallByBoundaryEdge(
          'room-a',
          BoundaryEdgeId('edge-2'),
        ),
        isNot(RoomSurfaceRef.wall('room-a', 2)),
      );
    });
  });
}
