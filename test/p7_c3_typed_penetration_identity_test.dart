import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7 C3 typed penetration identity', () {
    test('canonical slab construction preserves one typed id end to end', () {
      final id = BoundaryPenetrationId('penetration-01');
      final slabId = SlabId('slab-01');
      final coreId = VerticalCoreId('core-01');

      final penetration = BoundaryPenetration.slabTyped(
        id: id,
        slabId: slabId,
        verticalCoreId: coreId,
        entrySurface: RoomSurfaceRef.ceiling('space-l1'),
        entryPoint: const SurfacePointMm(100, 100),
        exitSurface: RoomSurfaceRef.floor('space-l2'),
        exitPoint: const SurfacePointMm(100, 100),
        hostThicknessMm: 200,
        routeId: 'route-01',
      );

      expect(penetration.id, id);
      expect(penetration.entryAnchor.penetrationId, id);
      expect(penetration.exitAnchor.penetrationId, id);
      expect(penetration.slabId, slabId);
      expect(penetration.verticalCoreId, coreId);
      expect(penetration.hostKind, BoundaryPenetrationHostKind.slab);
    });

    test('typed requirement materializes without scalar identity regeneration',
        () {
      final id = BoundaryPenetrationId('penetration-02');
      final requirement = BoundaryPenetrationRequirement(
        hostKind: BoundaryPenetrationHostKind.slab,
        hostThicknessMm: 180,
        slabId: SlabId('slab-02'),
      );

      final penetration = requirement.createTyped(
        penetrationId: id,
        routeId: 'route-02',
        entrySurface: RoomSurfaceRef.ceiling('space-l1'),
        entryPoint: const SurfacePointMm(25, 25),
        exitSurface: RoomSurfaceRef.floor('space-l2'),
        exitPoint: const SurfacePointMm(25, 25),
      );

      expect(penetration.id, id);
      expect(penetration.entryAnchor.penetrationId, id);
      expect(penetration.exitAnchor.penetrationId, id);
    });

    test('legacy scalar ingress is promoted losslessly without regeneration', () {
      const legacyId = 'legacy-persisted-penetration';
      final penetration = BoundaryPenetration.slab(
        id: legacyId,
        slabId: SlabId('slab-legacy'),
        entrySurface: RoomSurfaceRef.ceiling('space-l1'),
        entryPoint: const SurfacePointMm(50, 50),
        exitSurface: RoomSurfaceRef.floor('space-l2'),
        exitPoint: const SurfacePointMm(50, 50),
        hostThicknessMm: 220,
        routeId: 'route-legacy',
      );

      expect(penetration.id, BoundaryPenetrationId(legacyId));
      expect(penetration.id.value, legacyId);
      expect(
        penetration.entryAnchor.penetrationId,
        BoundaryPenetrationId(legacyId),
      );
      expect(
        penetration.exitAnchor.penetrationId,
        BoundaryPenetrationId(legacyId),
      );
      expect(penetration.hostKind, BoundaryPenetrationHostKind.slab);
      expect(penetration.slabId, SlabId('slab-legacy'));
    });

    test('canonical typed boundary fails closed on empty penetration identity',
        () {
      expect(
        () => BoundaryPenetration.slabTyped(
          id: BoundaryPenetrationId(''),
          slabId: SlabId('slab-03'),
          entrySurface: RoomSurfaceRef.ceiling('space-l1'),
          entryPoint: const SurfacePointMm(10, 10),
          exitSurface: RoomSurfaceRef.floor('space-l2'),
          exitPoint: const SurfacePointMm(10, 10),
          hostThicknessMm: 200,
          routeId: 'route-03',
        ),
        throwsArgumentError,
      );
    });

    test('identity factory allocates typed non-empty penetration ids', () {
      final factory = SecureRandomEntityIdFactory();
      final first = factory.newBoundaryPenetrationId();
      final second = factory.newBoundaryPenetrationId();

      expect(first.trim(), isNotEmpty);
      expect(second.trim(), isNotEmpty);
      expect(first, isNot(second));
    });
  });
}
