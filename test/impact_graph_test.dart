import 'package:elecx/src/domain/impact_graph.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('component change propagates to connection route and circuit', () {
    final component = ImpactEntityRef.component(ComponentId('component-1'));
    final connection = ImpactEntityRef.engineeringConnection(
      EngineeringConnectionId('connection-1'),
    );
    final route = ImpactEntityRef.route(RouteId('route-1'));
    final circuit = ImpactEntityRef.circuit(CircuitId('circuit-1'));

    final graph = ImpactGraph(
      dependencies: [
        ImpactDependency(
          dependency: component,
          dependent: connection,
          kind: ImpactDependencyKind.connectivity,
        ),
        ImpactDependency(
          dependency: connection,
          dependent: route,
          kind: ImpactDependencyKind.routedBy,
        ),
        ImpactDependency(
          dependency: route,
          dependent: circuit,
          kind: ImpactDependencyKind.calculatedFrom,
        ),
      ],
    );

    expect(graph.directDependentsOf(component), {connection});
    expect(graph.transitiveDependentsOf(component), {
      connection,
      route,
      circuit,
    });
    expect(graph.isImpactedBy(candidate: circuit, changed: component), isTrue);
  });

  test('transitive impact calculation remains cycle safe', () {
    final a = ImpactEntityRef.component(ComponentId('a'));
    final b = ImpactEntityRef.component(ComponentId('b'));
    final graph = ImpactGraph(
      dependencies: [
        ImpactDependency(
          dependency: a,
          dependent: b,
          kind: ImpactDependencyKind.connectivity,
        ),
        ImpactDependency(
          dependency: b,
          dependent: a,
          kind: ImpactDependencyKind.connectivity,
        ),
      ],
    );

    expect(graph.transitiveDependentsOf(a), {b});
  });

  test('self dependency is rejected', () {
    final component = ImpactEntityRef.component(ComponentId('component-1'));

    expect(
      () => ImpactGraph(
        dependencies: [
          ImpactDependency(
            dependency: component,
            dependent: component,
            kind: ImpactDependencyKind.calculatedFrom,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
