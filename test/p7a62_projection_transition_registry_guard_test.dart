import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projection transition cannot be constructed as canonical host state', () {
    final reference = BoundaryHostedReference.point(
      objectKey: 'route:r1:anchor:p7a-transition:r1:a:b:left:right',
      objectKind: BoundaryHostedObjectKind.routeAnchor,
      host: BoundaryEdgeHostRef(
        spaceId: SpaceId('space'),
        edgeId: BoundaryEdgeId('edge'),
      ),
      offsetMm: 100,
    );

    expect(
      () => BoundaryHostedObjectRegistry({reference.objectKey: reference}),
      throwsArgumentError,
    );
  });

  test('capture-style put ignores projection transition without mutation', () {
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
    final transition = BoundaryHostedReference.point(
      objectKey: 'route:r1:anchor:p7a-transition:r1:a:b:left:right',
      objectKind: BoundaryHostedObjectKind.routeAnchor,
      host: BoundaryEdgeHostRef(
        spaceId: SpaceId('space'),
        edgeId: BoundaryEdgeId('edge'),
      ),
      offsetMm: 100,
    );

    final result = original.put(transition);

    expect(result, same(original));
    expect(result.references, hasLength(1));
    expect(result[transition.objectKey], isNull);
  });
}
