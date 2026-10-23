import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing physical thickness fails closed', () {
    const requirement = BoundaryPenetrationRequirement(
      hostKind: BoundaryPenetrationHostKind.wall,
    );

    expect(
      () => requirement.create(
        penetrationId: 'p-1',
        routeId: 'r-1',
        entrySurface: RoomSurfaceRef.wall('room-a', 0),
        entryPoint: const SurfacePointMm(1000, 1200),
        exitSurface: RoomSurfaceRef.wall('room-b', 2),
        exitPoint: const SurfacePointMm(1000, 1200),
      ),
      throwsStateError,
    );
  });

  test('actual penetration path cannot be shorter than host thickness', () {
    final entry = BoundaryPenetrationAnchor(
      id: 'p-1:entry',
      penetrationId: 'p-1',
      side: PenetrationAnchorSide.entry,
      surface: RoomSurfaceRef.wall('room-a', 0),
      point: const SurfacePointMm(1000, 1200),
      routeId: 'r-1',
    );
    final exit = BoundaryPenetrationAnchor(
      id: 'p-1:exit',
      penetrationId: 'p-1',
      side: PenetrationAnchorSide.exit,
      surface: RoomSurfaceRef.wall('room-b', 2),
      point: const SurfacePointMm(1000, 1200),
      routeId: 'r-1',
    );

    expect(
      () => BoundaryPenetration(
        id: 'p-1',
        hostKind: BoundaryPenetrationHostKind.wall,
        entryAnchor: entry,
        exitAnchor: exit,
        hostThicknessMm: 180,
        pathLengthMm: 179,
      ),
      throwsArgumentError,
    );
  });

  test('paired anchors cannot silently switch route identity', () {
    final entry = BoundaryPenetrationAnchor(
      id: 'p-1:entry',
      penetrationId: 'p-1',
      side: PenetrationAnchorSide.entry,
      surface: RoomSurfaceRef.wall('room-a', 0),
      point: const SurfacePointMm(1000, 1200),
      routeId: 'route-a',
    );
    final exit = BoundaryPenetrationAnchor(
      id: 'p-1:exit',
      penetrationId: 'p-1',
      side: PenetrationAnchorSide.exit,
      surface: RoomSurfaceRef.wall('room-b', 2),
      point: const SurfacePointMm(1000, 1200),
      routeId: 'route-b',
    );

    expect(
      () => BoundaryPenetration(
        id: 'p-1',
        hostKind: BoundaryPenetrationHostKind.wall,
        entryAnchor: entry,
        exitAnchor: exit,
        hostThicknessMm: 180,
        pathLengthMm: 180,
      ),
      throwsArgumentError,
    );
  });
}
