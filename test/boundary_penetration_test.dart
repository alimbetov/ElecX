import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/project_identity.dart';
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

  test('canonical slab penetration preserves stable physical SlabId', () {
    final penetration = BoundaryPenetration.slab(
      id: 'p-slab-1',
      slabId: SlabId('slab-01-02'),
      entrySurface: RoomSurfaceRef.ceiling('room-l1'),
      entryPoint: const SurfacePointMm(1400, 1600),
      exitSurface: RoomSurfaceRef.floor('room-l2'),
      exitPoint: const SurfacePointMm(1400, 1600),
      hostThicknessMm: 200,
      routeId: 'C-201',
      materialId: 'reinforced-concrete',
    );

    expect(penetration.hostKind, BoundaryPenetrationHostKind.slab);
    expect(penetration.slabId, SlabId('slab-01-02'));
    expect(penetration.hasStableSlabHostIdentity, isTrue);
    expect(penetration.routeLengthContributionMm, 200);
  });

  test('slab requirement propagates SlabId into committed penetration', () {
    final requirement = BoundaryPenetrationRequirement(
      hostKind: BoundaryPenetrationHostKind.slab,
      hostThicknessMm: 220,
      materialId: 'reinforced-concrete',
      slabId: SlabId('slab-02-03'),
    );

    final penetration = requirement.create(
      penetrationId: 'p-slab-2',
      routeId: 'C-202',
      entrySurface: RoomSurfaceRef.ceiling('room-l2'),
      entryPoint: const SurfacePointMm(800, 900),
      exitSurface: RoomSurfaceRef.floor('room-l3'),
      exitPoint: const SurfacePointMm(800, 900),
    );

    expect(penetration.slabId, SlabId('slab-02-03'));
    expect(penetration.hostThicknessMm, 220);
  });

  test('wall penetration rejects accidental SlabId host assignment', () {
    expect(
      () => BoundaryPenetration.normal(
        id: 'p-wall-with-slab',
        hostKind: BoundaryPenetrationHostKind.wall,
        entrySurface: RoomSurfaceRef.wall('room-a', 0),
        entryPoint: const SurfacePointMm(1000, 1200),
        exitSurface: RoomSurfaceRef.wall('room-b', 2),
        exitPoint: const SurfacePointMm(1000, 1200),
        hostThicknessMm: 180,
        routeId: 'r-1',
        slabId: SlabId('slab-invalid'),
      ),
      throwsArgumentError,
    );
  });

  test('legacy slab penetration can remain unidentified until migration', () {
    final legacy = BoundaryPenetration.normal(
      id: 'legacy-slab',
      hostKind: BoundaryPenetrationHostKind.slab,
      entrySurface: RoomSurfaceRef.ceiling('room-l1'),
      entryPoint: const SurfacePointMm(400, 500),
      exitSurface: RoomSurfaceRef.floor('room-l2'),
      exitPoint: const SurfacePointMm(400, 500),
      hostThicknessMm: 180,
      routeId: 'legacy-route',
    );

    expect(legacy.slabId, isNull);
    expect(legacy.hasStableSlabHostIdentity, isFalse);
  });
}
