import 'canonical_engineering_graph.dart';
import 'engineering_circuit_topology.dart';
import 'engineering_supply_topology.dart';
import 'impact_graph.dart';

/// Stable semantic ids carried by [EngineeringGraphConnection.semanticTypeId].
///
/// These values describe logical engineering intent only. They do not imply a
/// physical route, calculation policy or regeneration decision by themselves.
abstract final class EngineeringDependencySemanticTypeId {
  static const controls = 'engineering.controls';
  static const suppliedBy = 'engineering.supplied-by';
  static const memberOf = 'engineering.member-of';
  static const communicatesWith = 'engineering.communicates-with';
  static const protects = 'engineering.protects';
}

/// Maps one connection semantic id into an impact relation.
///
/// Custom disciplines may register additional definitions without changing the
/// closed legacy dependency enum. Symmetry is explicit because impact edges are
/// always stored directionally as dependency -> dependent.
final class EngineeringDependencyRelationDefinition {
  EngineeringDependencyRelationDefinition({
    required String semanticTypeId,
    required this.relationKey,
    this.symmetric = false,
  }) : semanticTypeId = _nonEmpty(semanticTypeId, 'semanticTypeId');

  final String semanticTypeId;
  final ImpactDependencyRelationKey relationKey;
  final bool symmetric;
}

/// Projects canonical P11 engineering topology into the existing [ImpactGraph].
///
/// The result is a derived traversal view, not another project store. Canonical
/// graph/topology/supply identities remain owned by their existing domain
/// objects; P15 may later consume this projection for selective recalculation.
final class EngineeringImpactDependencyProjector {
  EngineeringImpactDependencyProjector({
    required this.topology,
    this.supplyTopology,
    Iterable<EngineeringDependencyRelationDefinition> extensionRelations =
        const [],
  }) {
    final supply = supplyTopology;
    if (supply != null && !identical(supply.topology, topology)) {
      throw ArgumentError(
        'Supply topology must reference the same canonical engineering '
        'topology.',
      );
    }

    final definitions = <String, EngineeringDependencyRelationDefinition>{};
    for (final definition in _builtInRelationDefinitions) {
      definitions[definition.semanticTypeId] = definition;
    }
    for (final definition in extensionRelations) {
      if (definitions.containsKey(definition.semanticTypeId)) {
        throw ArgumentError(
          'Duplicate engineering dependency semantic id '
          '${definition.semanticTypeId}.',
        );
      }
      definitions[definition.semanticTypeId] = definition;
    }
    _relationsBySemanticType = Map.unmodifiable(definitions);
  }

  final CanonicalEngineeringTopology topology;
  final CanonicalEngineeringSupplyTopology? supplyTopology;

  late final Map<String, EngineeringDependencyRelationDefinition>
      _relationsBySemanticType;

  ImpactGraph project() {
    final dependencies = <ImpactDependency>{};
    final graph = topology.graph;

    for (final connection in graph.connections) {
      final connectionRef =
          ImpactEntityRef.engineeringConnection(connection.id);
      final fromRef = ImpactEntityRef.component(connection.fromComponentId);
      final toRef = ImpactEntityRef.component(connection.toComponentId);

      dependencies.add(
        ImpactDependency.typed(
          dependency: fromRef,
          dependent: connectionRef,
          relationKey: ImpactDependencyRelationKey.connectivity,
        ),
      );
      dependencies.add(
        ImpactDependency.typed(
          dependency: toRef,
          dependent: connectionRef,
          relationKey: ImpactDependencyRelationKey.connectivity,
        ),
      );

      final routeId = connection.routeId;
      if (routeId != null) {
        dependencies.add(
          ImpactDependency.typed(
            dependency: connectionRef,
            dependent: ImpactEntityRef.route(routeId),
            relationKey: ImpactDependencyRelationKey.routedBy,
          ),
        );
      }

      final circuit = topology.circuitForConnection(connection.id);
      if (circuit != null) {
        dependencies.add(
          ImpactDependency.typed(
            dependency: connectionRef,
            dependent: ImpactEntityRef.circuit(circuit.id),
            relationKey: ImpactDependencyRelationKey.memberOf,
          ),
        );
      }

      final semanticTypeId = connection.semanticTypeId;
      if (semanticTypeId != null) {
        final definition = _relationsBySemanticType[semanticTypeId];
        if (definition == null) {
          throw ArgumentError(
            'Engineering connection ${connection.id} uses undeclared '
            'dependency semantic $semanticTypeId.',
          );
        }
        dependencies.add(
          ImpactDependency.typed(
            dependency: fromRef,
            dependent: toRef,
            relationKey: definition.relationKey,
          ),
        );
        if (definition.symmetric) {
          dependencies.add(
            ImpactDependency.typed(
              dependency: toRef,
              dependent: fromRef,
              relationKey: definition.relationKey,
            ),
          );
        }
      }
    }

    final supply = supplyTopology;
    if (supply != null) {
      for (final source in supply.sources) {
        final sourceRef = ImpactEntityRef.component(source.endpoint.componentId);
        for (final circuit in supply.circuitsForSource(source.id)) {
          dependencies.add(
            ImpactDependency.typed(
              dependency: sourceRef,
              dependent: ImpactEntityRef.circuit(circuit.id),
              relationKey: ImpactDependencyRelationKey.suppliedBy,
            ),
          );
        }
      }
    }

    return ImpactGraph(dependencies: dependencies);
  }
}

final List<EngineeringDependencyRelationDefinition>
    _builtInRelationDefinitions = List.unmodifiable([
  EngineeringDependencyRelationDefinition(
    semanticTypeId: EngineeringDependencySemanticTypeId.controls,
    relationKey: ImpactDependencyRelationKey.controls,
  ),
  EngineeringDependencyRelationDefinition(
    semanticTypeId: EngineeringDependencySemanticTypeId.suppliedBy,
    relationKey: ImpactDependencyRelationKey.suppliedBy,
  ),
  EngineeringDependencyRelationDefinition(
    semanticTypeId: EngineeringDependencySemanticTypeId.memberOf,
    relationKey: ImpactDependencyRelationKey.memberOf,
  ),
  EngineeringDependencyRelationDefinition(
    semanticTypeId: EngineeringDependencySemanticTypeId.communicatesWith,
    relationKey: ImpactDependencyRelationKey.communicatesWith,
    symmetric: true,
  ),
  EngineeringDependencyRelationDefinition(
    semanticTypeId: EngineeringDependencySemanticTypeId.protects,
    relationKey: ImpactDependencyRelationKey.protects,
  ),
]);

String _nonEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return value;
}
