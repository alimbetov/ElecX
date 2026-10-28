import 'project_identity.dart';

enum ImpactEntityKind {
  component,
  engineeringConnection,
  circuit,
  route,
  boundary,
  slab,
  opening,
  generation,
}

/// Typed reference used by dependency/impact analysis.
final class ImpactEntityRef {
  ImpactEntityRef._(this.kind, this.id);

  factory ImpactEntityRef.component(ComponentId id) =>
      ImpactEntityRef._(ImpactEntityKind.component, id);
  factory ImpactEntityRef.engineeringConnection(EngineeringConnectionId id) =>
      ImpactEntityRef._(ImpactEntityKind.engineeringConnection, id);
  factory ImpactEntityRef.circuit(CircuitId id) =>
      ImpactEntityRef._(ImpactEntityKind.circuit, id);
  factory ImpactEntityRef.route(RouteId id) =>
      ImpactEntityRef._(ImpactEntityKind.route, id);
  factory ImpactEntityRef.boundary(BoundaryEdgeId id) =>
      ImpactEntityRef._(ImpactEntityKind.boundary, id);
  factory ImpactEntityRef.slab(SlabId id) =>
      ImpactEntityRef._(ImpactEntityKind.slab, id);
  factory ImpactEntityRef.opening(OpeningId id) =>
      ImpactEntityRef._(ImpactEntityKind.opening, id);
  factory ImpactEntityRef.generation(GenerationId id) =>
      ImpactEntityRef._(ImpactEntityKind.generation, id);

  final ImpactEntityKind kind;
  final EntityId id;

  @override
  bool operator ==(Object other) =>
      other is ImpactEntityRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => '${kind.name}:${id.value}';
}

enum ImpactDependencyKind {
  connectivity,
  hostedBy,
  routedBy,
  calculatedFrom,
  generatedFrom,
  constrainedBy,
}

/// Direction is dependency -> dependent. If [dependency] changes, [dependent]
/// is a direct impact candidate.
final class ImpactDependency {
  const ImpactDependency({
    required this.dependency,
    required this.dependent,
    required this.kind,
  });

  final ImpactEntityRef dependency;
  final ImpactEntityRef dependent;
  final ImpactDependencyKind kind;

  @override
  bool operator ==(Object other) =>
      other is ImpactDependency &&
      other.dependency == dependency &&
      other.dependent == dependent &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(dependency, dependent, kind);
}

/// Immutable typed dependency graph used to calculate direct and transitive
/// impacts before recalculation/regeneration.
final class ImpactGraph {
  ImpactGraph({Iterable<ImpactDependency> dependencies = const []})
      : _dependencies = Set.unmodifiable(dependencies) {
    for (final edge in _dependencies) {
      if (edge.dependency == edge.dependent) {
        throw ArgumentError(
          'Impact dependency cannot reference itself: ${edge.dependency}.',
        );
      }
    }
  }

  final Set<ImpactDependency> _dependencies;

  Set<ImpactDependency> get dependencies => _dependencies;

  Set<ImpactEntityRef> directDependentsOf(ImpactEntityRef changed) =>
      Set.unmodifiable(
        _dependencies
            .where((edge) => edge.dependency == changed)
            .map((edge) => edge.dependent),
      );

  /// Cycle-safe transitive impact closure. The changed entity itself is never
  /// returned, even when the dependency graph contains a cycle.
  Set<ImpactEntityRef> transitiveDependentsOf(ImpactEntityRef changed) {
    final impacted = <ImpactEntityRef>{};
    final queue = <ImpactEntityRef>[changed];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final dependent in directDependentsOf(current)) {
        if (dependent == changed || !impacted.add(dependent)) continue;
        queue.add(dependent);
      }
    }
    return Set.unmodifiable(impacted);
  }

  bool isImpactedBy({
    required ImpactEntityRef candidate,
    required ImpactEntityRef changed,
  }) =>
      transitiveDependentsOf(changed).contains(candidate);
}
