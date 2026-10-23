import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opening key collision across legacy ids fails closed', () {
    final registry = BoundaryHostedObjectRegistry({
      'opening:a:b:c': BoundaryHostedReference.interval(
        objectKey: 'opening:a:b:c',
        objectKind: BoundaryHostedObjectKind.opening,
        host: BoundaryEdgeHostRef(
          spaceId: SpaceId('c'),
          edgeId: BoundaryEdgeId('edge-c'),
        ),
        startOffsetMm: 100,
        endOffsetMm: 900,
      ),
    });

    expect(
      () => registry.putOpening(
        openingId: OpeningId('a'),
        host: BoundaryEdgeHostRef(
          spaceId: SpaceId('b:c'),
          edgeId: BoundaryEdgeId('edge-bc'),
        ),
        startOffsetMm: 200,
        endOffsetMm: 1000,
      ),
      throwsStateError,
      reason: 'opening:a:b:c can represent (a:b,c) or (a,b:c); canonical '
          'ownership must not silently overwrite the existing host.',
    );
  });
}
