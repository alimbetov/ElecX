import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/route_host.dart';
import 'package:elecx/src/features/editor/vertical_route_continuation_marker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerticalRouteContinuationMarkerResolver', () {
    final lowerCeiling = RoomSurfaceRef.ceiling('space-l1');
    final upperFloor = RoomSurfaceRef.floor('space-l2');
    final transition = RouteHostTransition(
      id: 'penetration-1',
      kind: RouteHostTransitionKind.levelPenetration,
      fromHost: RouteHostRef.indoor(lowerCeiling),
      fromPoint: const MmPoint(1500, 1200),
      toHost: RouteHostRef.indoor(upperFloor),
      toPoint: const MmPoint(1500, 1200),
      requiresPenetration: true,
      slabId: SlabId('slab-01-02'),
    );

    test('lower ceiling exposes explicit upward continuation', () {
      final marker = VerticalRouteContinuationMarkerResolver.resolve(
        routeId: 'C-103',
        transition: transition,
        currentSurface: lowerCeiling,
      );

      expect(marker, isNotNull);
      expect(marker!.routeId, 'C-103');
      expect(marker.transitionId, 'penetration-1');
      expect(marker.slabId, SlabId('slab-01-02'));
      expect(marker.direction, VerticalRouteContinuationDirection.upward);
      expect(marker.glyph, '↑');
      expect(marker.targetSurface, upperFloor);
      expect(marker.semanticsLabel, contains('уровень выше'));
      expect(marker.semanticsLabel, contains('slab-01-02'));
    });

    test('upper floor exposes explicit downward continuation', () {
      final marker = VerticalRouteContinuationMarkerResolver.resolve(
        routeId: 'C-103',
        transition: transition,
        currentSurface: upperFloor,
      );

      expect(marker, isNotNull);
      expect(marker!.direction, VerticalRouteContinuationDirection.downward);
      expect(marker.glyph, '↓');
      expect(marker.targetSurface, lowerCeiling);
      expect(marker.semanticsLabel, contains('уровень ниже'));
    });

    test('wall penetration is never presented as an inter-level marker', () {
      final wallA = RoomSurfaceRef.wall('space-a', 0);
      final wallB = RoomSurfaceRef.wall('space-b', 2);
      final wallTransition = RouteHostTransition(
        id: 'wall-penetration',
        kind: RouteHostTransitionKind.roomPenetration,
        fromHost: RouteHostRef.indoor(wallA),
        fromPoint: const MmPoint(100, 900),
        toHost: RouteHostRef.indoor(wallB),
        toPoint: const MmPoint(100, 900),
        requiresPenetration: true,
      );

      expect(
        VerticalRouteContinuationMarkerResolver.resolve(
          routeId: 'C-103',
          transition: wallTransition,
          currentSurface: wallA,
        ),
        isNull,
      );
    });

    test('foreign surface cannot activate a marker by geometry coincidence', () {
      expect(
        VerticalRouteContinuationMarkerResolver.resolve(
          routeId: 'C-103',
          transition: transition,
          currentSurface: RoomSurfaceRef.ceiling('space-other'),
        ),
        isNull,
      );
    });
  });
}
