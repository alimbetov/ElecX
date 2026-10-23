import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opaque route and anchor ids cannot alias canonical hosted key', () {
    const separator = ':anchor:';
    const routeA = 'route-a';
    final anchorA = RouteAnchorId('x${separator}y');
    final routeB = 'route-a${separator}x';
    final anchorB = RouteAnchorId('y');

    final legacyA = 'route:$routeA:anchor:${anchorA.value}';
    final legacyB = 'route:$routeB:anchor:${anchorB.value}';
    expect(legacyA, legacyB, reason: 'fixture must reproduce legacy alias');

    final canonicalA =
        BoundaryHostedObjectRegistry.routeAnchorObjectKey(routeA, anchorA);
    final canonicalB =
        BoundaryHostedObjectRegistry.routeAnchorObjectKey(routeB, anchorB);

    expect(canonicalA, isNot(canonicalB));
    expect(canonicalA, contains('${routeA.length}:$routeA'));
    expect(canonicalB, contains('${routeB.length}:$routeB'));
  });
}
