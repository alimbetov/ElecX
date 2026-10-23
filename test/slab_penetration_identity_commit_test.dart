import 'package:elecx/src/domain/boundary_penetration.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new slab penetration requirement without SlabId fails closed', () {
    const requirement = BoundaryPenetrationRequirement(
      hostKind: BoundaryPenetrationHostKind.slab,
      hostThicknessMm: 200,
      materialId: 'reinforced-concrete',
    );

    expect(
      () => requirement.create(
        penetrationId: 'slab-anonymous',
        routeId: 'C-vertical',
        entrySurface: RoomSurfaceRef.ceiling('space-l1'),
        entryPoint: const SurfacePointMm(1200, 900),
        exitSurface: RoomSurfaceRef.floor('space-l2'),
        exitPoint: const SurfacePointMm(1200, 900),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('SlabId'),
        ),
      ),
    );
  });
}
