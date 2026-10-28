import 'canonical_engineering_graph.dart';
import 'impact_graph.dart';

/// Projects canonical engineering connectivity into recalculation dependencies.
///
/// Direction is deliberately `changed dependency -> impacted dependent`:
/// component changes invalidate the connection; connection changes invalidate
/// route geometry; route changes invalidate circuit calculations. When a
/// connection has no physical route, the circuit depends directly on it.
abstract final class EngineeringImpactProjection {
  static ImpactGraph fromGraph(CanonicalEngineeringGraph graph) {
    final dependencies = <ImpactDependency>[];

    for (final connection in graph.connections) {
      final connectionRef =
          ImpactEntityRef.engineeringConnection(connection.id);

      dependencies.add(
        ImpactDependency(
          dependency: ImpactEntityRef.component(connection.fromComponentId),
          dependent: connectionRef,
          kind: ImpactDependencyKind.connectivity,
        ),
      );
      dependencies.add(
        ImpactDependency(
          dependency: ImpactEntityRef.component(connection.toComponentId),
          dependent: connectionRef,
          kind: ImpactDependencyKind.connectivity,
        ),
      );

      final routeId = connection.routeId;
      final circuitId = connection.circuitId;
      if (routeId != null) {
        final routeRef = ImpactEntityRef.route(routeId);
        dependencies.add(
          ImpactDependency(
            dependency: connectionRef,
            dependent: routeRef,
            kind: ImpactDependencyKind.routedBy,
          ),
        );
        if (circuitId != null) {
          dependencies.add(
            ImpactDependency(
              dependency: routeRef,
              dependent: ImpactEntityRef.circuit(circuitId),
              kind: ImpactDependencyKind.calculatedFrom,
            ),
          );
        }
      } else if (circuitId != null) {
        dependencies.add(
          ImpactDependency(
            dependency: connectionRef,
            dependent: ImpactEntityRef.circuit(circuitId),
            kind: ImpactDependencyKind.calculatedFrom,
          ),
        );
      }
    }

    return ImpactGraph(dependencies: dependencies);
  }
}
