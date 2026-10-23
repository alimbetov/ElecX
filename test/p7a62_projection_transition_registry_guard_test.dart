import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic registry does not infer projection semantics from opaque key',
      () {
    final reference = BoundaryHostedReference.point(
      objectKey:
          'route:r1:anchor:user:anchor:p7a-transition:literal-but-durable',
      objectKind: BoundaryHostedObjectKind.routeAnchor,
      host: BoundaryEdgeHostRef(
        spaceId: SpaceId('space'),
        edgeId: BoundaryEdgeId('edge'),
      ),
      offsetMm: 100,
    );

    final registry = BoundaryHostedObjectRegistry({
      reference.objectKey: reference,
    });

    expect(registry[reference.objectKey], same(reference));
  });

  test('put preserves durable anchor containing transition text internally',
      () {
    final original = BoundaryHostedObjectRegistry({
      'component:c1': BoundaryHostedReference.point(
        objectKey: 'component:c1',
        objectKind: BoundaryHostedObjectKind.component,
        host: BoundaryEdgeHostRef(
          spaceId: SpaceId('space'),
          edgeId: BoundaryEdgeId('edge'),
        ),
        offsetMm: 50,
      ),
    });
    final durable = BoundaryHostedReference.point(
      objectKey: 'route:r1:anchor:user:anchor:p7a-transition:still-durable',
      objectKind: BoundaryHostedObjectKind.routeAnchor,
      host: BoundaryEdgeHostRef(
        spaceId: SpaceId('space'),
        edgeId: BoundaryEdgeId('edge'),
      ),
      offsetMm: 100,
    );

    final result = original.put(durable);

    expect(result.references, hasLength(2));
    expect(result[durable.objectKey], same(durable));
  });
}
