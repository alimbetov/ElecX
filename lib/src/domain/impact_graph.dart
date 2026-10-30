import 'dart:collection';

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
  loop,
  engineeringGroup,
  supplySource,
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

  factory ImpactEntityRef.loop(LoopId id) =>
      ImpactEntityRef._(ImpactEntityKind.loop, id);
  factory ImpactEntityRef.engineeringGroup(EngineeringGroupId id) =>
      ImpactEntityRef._(ImpactEntityKind.engineeringGroup, id);
  factory ImpactEntityRef.supplySource(EngineeringSupplySourceId id) =>
      ImpactEntityRef._(ImpactEntityKind.supplySource, id);

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

/// Legacy dependency family retained for existing callers and persisted intent.
///
/// P11.7 adds [ImpactDependencyRelationKey] as the extensible semantic identity.
/// New custom relations use [custom] plus an explicit relation key.
enum ImpactDependencyKind {
  connectivity,
  hostedBy,
  routedBy,
  calculatedFrom,
  generatedFrom,
  constrainedBy,
  controls,
  suppliedBy,
  memberOf,
  communicatesWith,
  protects,
  custom,
}

/// Stable extensible relation identity used by P11/P15 dependency traversal.
final class ImpactDependencyRelationKey {
  factory ImpactDependencyRelationKey(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Relation id must be non-empty.');
    }
    return ImpactDependencyRelationKey._(id);
  }

  const ImpactDependencyRelationKey._(this.id);

  final String id;

  static const connectivity =
      ImpactDependencyRelationKey._('core.connectivity');
  static const hostedBy = ImpactDependencyRelationKey._('core.hosted-by');
  static const routedBy = ImpactDependencyRelationKey._('core.routed-by');
  static const calculatedFrom =
      ImpactDependencyRelationKey._('core.calculated-from');
  static const generatedFrom =
      ImpactDependencyRelationKey._('core.generated-from');
  static const constrainedBy =
      ImpactDependencyRelationKey._('core.constrained-by');
  static const controls = ImpactDependencyRelationKey._('engineering.controls');
  static const suppliedBy =
      ImpactDependencyRelationKey._('engineering.supplied-by');
  static const memberOf =
      ImpactDependencyRelationKey._('engineering.member-of');
  static const communicatesWith =
      ImpactDependencyRelationKey._('engineering.communicates-with');
  static const protects = ImpactDependencyRelationKey._('engineering.protects');

  static ImpactDependencyRelationKey fromKind(ImpactDependencyKind kind) =>
      switch (kind) {
        ImpactDependencyKind.connectivity => connectivity,
        ImpactDependencyKind.hostedBy => hostedBy,
        ImpactDependencyKind.routedBy => routedBy,
        ImpactDependencyKind.calculatedFrom => calculatedFrom,
        ImpactDependencyKind.generatedFrom => generatedFrom,
        ImpactDependencyKind.constrainedBy => constrainedBy,
        ImpactDependencyKind.controls => controls,
        ImpactDependencyKind.suppliedBy => suppliedBy,
        ImpactDependencyKind.memberOf => memberOf,
        ImpactDependencyKind.communicatesWith => communicatesWith,
        ImpactDependencyKind.protects => protects,
        ImpactDependencyKind.custom => throw ArgumentError(
            'Custom impact dependency kind requires an explicit relation key.',
          ),
      };

  static ImpactDependencyKind? builtInKindFor(
    ImpactDependencyRelationKey relation,
  ) =>
      switch (relation.id) {
        'core.connectivity' => ImpactDependencyKind.connectivity,
        'core.hosted-by' => ImpactDependencyKind.hostedBy,
        'core.routed-by' => ImpactDependencyKind.routedBy,
        'core.calculated-from' => ImpactDependencyKind.calculatedFrom,
        'core.generated-from' => ImpactDependencyKind.generatedFrom,
        'core.constrained-by' => ImpactDependencyKind.constrainedBy,
        'engineering.controls' => ImpactDependencyKind.controls,
        'engineering.supplied-by' => ImpactDependencyKind.suppliedBy,
        'engineering.member-of' => ImpactDependencyKind.memberOf,
        'engineering.communicates-with' =>
          ImpactDependencyKind.communicatesWith,
        'engineering.protects' => ImpactDependencyKind.protects,
        _ => null,
      };

  bool get isBuiltIn => builtInKindFor(this) != null;

  @override
  bool operator ==(Object other) =>
      other is ImpactDependencyRelationKey && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// Direction is dependency -> dependent. If [dependency] changes, [dependent]
/// is a direct impact candidate.
final class ImpactDependency {
  const ImpactDependency({
    required this.dependency,
    required this.dependent,
    required this.kind,
    ImpactDependencyRelationKey? relationKey,
  }) : _relationKey = relationKey;

  factory ImpactDependency.typed({
    required ImpactEntityRef dependency,
    required ImpactEntityRef dependent,
    required ImpactDependencyRelationKey relationKey,
  }) =>
      ImpactDependency(
        dependency: dependency,
        dependent: dependent,
        kind: ImpactDependencyRelationKey.builtInKindFor(relationKey) ??
            ImpactDependencyKind.custom,
        relationKey: relationKey,
      );

  final ImpactEntityRef dependency;
  final ImpactEntityRef dependent;
  final ImpactDependencyKind kind;
  final ImpactDependencyRelationKey? _relationKey;

  ImpactDependencyRelationKey get relationKey =>
      _relationKey ?? ImpactDependencyRelationKey.fromKind(kind);

  ImpactDependencyRelationKey? get _comparableRelationKey =>
      kind == ImpactDependencyKind.custom
          ? _relationKey
          : _relationKey ?? ImpactDependencyRelationKey.fromKind(kind);

  @override
  bool operator ==(Object other) =>
      other is ImpactDependency &&
      other.dependency == dependency &&
      other.dependent == dependent &&
      other.kind == kind &&
      other._comparableRelationKey == _comparableRelationKey;

  @override
  int get hashCode =>
      Object.hash(dependency, dependent, kind, _comparableRelationKey);
}

/// Immutable typed dependency graph used to calculate direct and transitive
/// impacts before recalculation/regeneration.
final class ImpactGraph {
  ImpactGraph({Iterable<ImpactDependency> dependencies = const []}) {
    final dependencySet = Set<ImpactDependency>.unmodifiable(dependencies);
    final outgoing = <ImpactEntityRef, List<ImpactDependency>>{};

    for (final edge in dependencySet) {
      if (edge.dependency == edge.dependent) {
        throw ArgumentError(
          'Impact dependency cannot reference itself: ${edge.dependency}.',
        );
      }
      _validateRelation(edge);
      (outgoing[edge.dependency] ??= []).add(edge);
    }

    _dependencies = dependencySet;
    _outgoing = Map.unmodifiable({
      for (final entry in outgoing.entries)
        entry.key: List<ImpactDependency>.unmodifiable(entry.value),
    });
  }

  late final Set<ImpactDependency> _dependencies;
  late final Map<ImpactEntityRef, List<ImpactDependency>> _outgoing;

  Set<ImpactDependency> get dependencies => _dependencies;

  Set<ImpactDependency> directDependenciesFrom(
    ImpactEntityRef changed, {
    Set<ImpactDependencyRelationKey>? relations,
  }) =>
      Set.unmodifiable(
        (_outgoing[changed] ?? const <ImpactDependency>[])
            .where((edge) => _includesRelation(edge, relations)),
      );

  Set<ImpactEntityRef> directDependentsOf(
    ImpactEntityRef changed, {
    Set<ImpactDependencyRelationKey>? relations,
  }) =>
      Set.unmodifiable(
        directDependenciesFrom(changed, relations: relations)
            .map((edge) => edge.dependent),
      );

  /// Cycle-safe transitive impact closure. The changed entity itself is never
  /// returned, even when the dependency graph contains a cycle.
  Set<ImpactEntityRef> transitiveDependentsOf(
    ImpactEntityRef changed, {
    Set<ImpactDependencyRelationKey>? relations,
  }) {
    final impacted = <ImpactEntityRef>{};
    final queue = ListQueue<ImpactEntityRef>()..add(changed);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final dependent in directDependentsOf(
        current,
        relations: relations,
      )) {
        if (dependent == changed || !impacted.add(dependent)) continue;
        queue.add(dependent);
      }
    }
    return Set.unmodifiable(impacted);
  }

  bool isImpactedBy({
    required ImpactEntityRef candidate,
    required ImpactEntityRef changed,
    Set<ImpactDependencyRelationKey>? relations,
  }) =>
      transitiveDependentsOf(changed, relations: relations).contains(candidate);

  static void _validateRelation(ImpactDependency edge) {
    final explicit = edge._relationKey;
    if (edge.kind == ImpactDependencyKind.custom) {
      if (explicit == null) {
        throw ArgumentError(
          'Custom impact dependency requires an explicit relation key.',
        );
      }
      if (explicit.isBuiltIn) {
        throw ArgumentError(
          'Built-in relation ${explicit.id} must use its built-in dependency '
          'kind.',
        );
      }
      return;
    }

    final expected = ImpactDependencyRelationKey.fromKind(edge.kind);
    if (explicit != null && explicit != expected) {
      throw ArgumentError(
        'Impact dependency kind ${edge.kind.name} conflicts with relation '
        '${explicit.id}; expected ${expected.id}.',
      );
    }
  }

  static bool _includesRelation(
    ImpactDependency edge,
    Set<ImpactDependencyRelationKey>? relations,
  ) =>
      relations == null || relations.contains(edge.relationKey);
}
