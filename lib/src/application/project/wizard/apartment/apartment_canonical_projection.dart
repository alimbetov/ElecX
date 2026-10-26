import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/canonical_engineering_graph.dart';
import '../../../../domain/component_placement.dart';
import '../../../../domain/engineering_graph.dart';
import '../../../../domain/project_identity.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

const String apartmentProjectionVersion = 'p9.projection.v1';

/// Immutable P9.3 canonical proposal fragment for the selected apartment.
///
/// [graph] owns WHAT + CONNECTIVITY. [placements] own WHERE. The envelope binds
/// both projections to the exact production lineage without allocating durable
/// ProjectAggregateRoot entities or mutating project state.
final class ApartmentEngineeringProjection {
  ApartmentEngineeringProjection({
    required this.projectionVersion,
    required this.selectedCandidateFingerprint,
    required this.draftFingerprint,
    required this.areaFitFingerprint,
    required this.geometryFingerprint,
    required this.graph,
    required Iterable<ComponentPlacement> placements,
    required this.graphFingerprint,
    required this.placementFingerprint,
    required this.projectionFingerprint,
  }) : placements = List.unmodifiable(placements) {
    final componentIds =
        graph.components.map((component) => component.id).toSet();
    final placedIds = <ComponentId>{};
    for (final placement in this.placements) {
      if (!componentIds.contains(placement.componentId)) {
        throw ArgumentError(
          'Placement ${placement.componentId} references an unknown component.',
        );
      }
      if (!placedIds.add(placement.componentId)) {
        throw ArgumentError(
          'Component ${placement.componentId} has more than one P9.3 placement.',
        );
      }
    }
    if (placedIds.length != componentIds.length) {
      throw ArgumentError(
        'Every P9.3 spatial component must have exactly one placement.',
      );
    }
  }

  final String projectionVersion;
  final String selectedCandidateFingerprint;
  final String draftFingerprint;
  final String areaFitFingerprint;
  final String geometryFingerprint;
  final CanonicalEngineeringGraph graph;
  final List<ComponentPlacement> placements;
  final String graphFingerprint;
  final String placementFingerprint;
  final String projectionFingerprint;
}

final class ApartmentCanonicalProjectionResult {
  ApartmentCanonicalProjectionResult({
    required this.projection,
    Iterable<P9Failure> failures = const [],
  }) : failures = List.unmodifiable(failures);

  final ApartmentEngineeringProjection? projection;
  final List<P9Failure> failures;

  bool get accepted =>
      projection != null && failures.every((failure) => !failure.isBlocker);
}

/// P9.3 exact-lineage projector.
///
/// It never reruns grammar, area fitting or geometry and never allocates random
/// identities. Logical IDs are derived only from selected semantic lineage;
/// geometry coordinates can therefore change WHERE without leaking into WHAT.
final class ApartmentCanonicalProjectionService {
  const ApartmentCanonicalProjectionService();

  ApartmentCanonicalProjectionResult project({
    required String selectedCandidateFingerprint,
    required ApartmentTopologyDraft draft,
    required AreaFittedTopologyDraft fittedDraft,
    required ApartmentGeometryCandidate geometry,
    required LevelId targetLevelId,
  }) {
    final mismatch = _lineageMismatch(
      selectedCandidateFingerprint: selectedCandidateFingerprint,
      draft: draft,
      fittedDraft: fittedDraft,
      geometry: geometry,
    );
    if (mismatch != null) {
      return ApartmentCanonicalProjectionResult(
        projection: null,
        failures: [mismatch],
      );
    }

    try {
      final spaces = [...draft.spaces]..sort(
          (left, right) => left.semanticKey.compareTo(right.semanticKey),
        );
      final geometryBySpace = <String, GeneratedSpaceGeometry>{
        for (final space in geometry.interiorSpaces) space.semanticKey: space,
        for (final space in geometry.exteriorAppendages)
          space.semanticKey: space,
      };
      final expectedKeys = spaces.map((space) => space.semanticKey).toSet();
      if (geometryBySpace.length != expectedKeys.length ||
          !geometryBySpace.keys.toSet().containsAll(expectedKeys)) {
        return _failed(
          reason: 'selected-winner-space-lineage-mismatch',
          facts: {
            'draftSpaceCount': expectedKeys.length,
            'geometrySpaceCount': geometryBySpace.length,
          },
        );
      }

      final relations = _spatialRelations(draft: draft, geometry: geometry);
      for (final relation in relations) {
        if (!expectedKeys.contains(relation.leftKey) ||
            !expectedKeys.contains(relation.rightKey)) {
          return _failed(
            reason: 'selected-winner-connectivity-lineage-mismatch',
            facts: {
              'relation': relation.stableKey,
              'leftKey': relation.leftKey,
              'rightKey': relation.rightKey,
            },
          );
        }
      }

      final componentIds = <String, ComponentId>{
        for (final space in spaces)
          space.semanticKey: _componentId(draft, space.semanticKey),
      };

      final components = <EngineeringGraphComponent>[];
      for (final space in spaces) {
        final incidentRelations = relations
            .where(
              (relation) =>
                  relation.leftKey == space.semanticKey ||
                  relation.rightKey == space.semanticKey,
            )
            .toList();
        final ports = <EngineeringPortSpec>[
          for (final relation in incidentRelations)
            EngineeringPortSpec(
              id: _portId(draft, relation, space.semanticKey).value,
              direction: EngineeringPortDirection.bidirectional,
              allowedConnections: const {
                EngineeringConnectionType.custom,
              },
            ),
        ]..sort((left, right) => left.id.compareTo(right.id));
        components.add(
          EngineeringGraphComponent(
            id: componentIds[space.semanticKey]!,
            componentTypeId: 'apartment.space.${space.usage.name}',
            discipline: EngineeringDiscipline.architecture,
            systemClass: EngineeringSystemClass.custom,
            ports: ports,
          ),
        );
      }

      final connections = <EngineeringGraphConnection>[
        for (final relation in relations)
          EngineeringGraphConnection(
            id: _connectionId(draft, relation),
            fromComponentId: componentIds[relation.leftKey]!,
            fromPortId: _portId(draft, relation, relation.leftKey),
            toComponentId: componentIds[relation.rightKey]!,
            toPortId: _portId(draft, relation, relation.rightKey),
            connectionType: EngineeringConnectionType.custom,
            systemClass: EngineeringSystemClass.custom,
            semanticTypeId: relation.semanticTypeId,
          ),
      ];

      final graph = CanonicalEngineeringGraph(
        components: components,
        connections: connections,
      );
      final placements = <ComponentPlacement>[
        for (final space in spaces)
          _placement(
            componentId: componentIds[space.semanticKey]!,
            levelId: targetLevelId,
            geometry: geometryBySpace[space.semanticKey]!,
          ),
      ]..sort(
          (left, right) =>
              left.componentId.value.compareTo(right.componentId.value),
        );

      final graphSerialization = _stableGraphSerialization(graph);
      final placementSerialization = placements
          .map((placement) => placement.stableSerialization)
          .join('\n');
      final graphFingerprint = p9Sha256Hex(graphSerialization);
      final placementFingerprint = p9Sha256Hex(placementSerialization);
      final projectionFingerprint = p9Sha256Hex(<String>[
        apartmentProjectionVersion,
        'candidate=$selectedCandidateFingerprint',
        'draft=${draft.draftFingerprint}',
        'areaFit=${fittedDraft.areaFitFingerprint}',
        'geometry=${geometry.geometryFingerprint}',
        'graph=$graphFingerprint',
        'placement=$placementFingerprint',
      ].join('\n'));

      return ApartmentCanonicalProjectionResult(
        projection: ApartmentEngineeringProjection(
          projectionVersion: apartmentProjectionVersion,
          selectedCandidateFingerprint: selectedCandidateFingerprint,
          draftFingerprint: draft.draftFingerprint,
          areaFitFingerprint: fittedDraft.areaFitFingerprint,
          geometryFingerprint: geometry.geometryFingerprint,
          graph: graph,
          placements: placements,
          graphFingerprint: graphFingerprint,
          placementFingerprint: placementFingerprint,
          projectionFingerprint: projectionFingerprint,
        ),
      );
    } catch (error) {
      return _failed(
        reason: 'selected-winner-projection-failed',
        facts: {'errorType': error.runtimeType.toString()},
      );
    }
  }
}

final class _SpatialRelation {
  const _SpatialRelation({
    required this.leftKey,
    required this.rightKey,
    required this.semanticTypeId,
  });

  final String leftKey;
  final String rightKey;
  final String semanticTypeId;

  String get stableKey => '$leftKey|$rightKey|$semanticTypeId';
}

List<_SpatialRelation> _spatialRelations({
  required ApartmentTopologyDraft draft,
  required ApartmentGeometryCandidate geometry,
}) {
  final relations = <String, _SpatialRelation>{};
  for (final edge in draft.circulation.accessEdges) {
    final leftKey = edge.fromSpaceKey.compareTo(edge.toSpaceKey) <= 0
        ? edge.fromSpaceKey
        : edge.toSpaceKey;
    final rightKey =
        leftKey == edge.fromSpaceKey ? edge.toSpaceKey : edge.fromSpaceKey;
    final relation = _SpatialRelation(
      leftKey: leftKey,
      rightKey: rightKey,
      semanticTypeId: 'apartment.access.${edge.kind.name}',
    );
    relations[relation.stableKey] = relation;
  }
  for (final boundary in geometry.sharedBoundaries) {
    final relation = _SpatialRelation(
      leftKey: boundary.pair.leftKey,
      rightKey: boundary.pair.rightKey,
      semanticTypeId: 'apartment.adjacency.sharedBoundary',
    );
    relations[relation.stableKey] = relation;
  }
  return List.unmodifiable(
    relations.values.toList()
      ..sort((left, right) => left.stableKey.compareTo(right.stableKey)),
  );
}

P9Failure? _lineageMismatch({
  required String selectedCandidateFingerprint,
  required ApartmentTopologyDraft draft,
  required AreaFittedTopologyDraft fittedDraft,
  required ApartmentGeometryCandidate geometry,
}) {
  final mismatch = selectedCandidateFingerprint.trim().isEmpty ||
      !identical(fittedDraft.draft, draft) ||
      fittedDraft.draft.draftFingerprint != draft.draftFingerprint ||
      geometry.areaFitFingerprint != fittedDraft.areaFitFingerprint ||
      geometry.templateId != draft.templateId ||
      geometry.templateVersion != draft.templateVersion ||
      geometry.family != draft.family ||
      geometry.variantSeedId != draft.variantSeedId ||
      !geometry.validation.accepted;
  if (!mismatch) return null;
  return P9Failure(
    code: 'INTERNAL_GENERATION_ERROR',
    stage: P9FailureStage.materialization,
    severity: P9FailureSeverity.blocker,
    facts: {
      'reason': 'selected-winner-lineage-mismatch',
      'draftFingerprint': draft.draftFingerprint,
      'fittedDraftFingerprint': fittedDraft.draft.draftFingerprint,
      'areaFitFingerprint': fittedDraft.areaFitFingerprint,
      'geometryAreaFitFingerprint': geometry.areaFitFingerprint,
      'geometryFingerprint': geometry.geometryFingerprint,
    },
  );
}

ApartmentCanonicalProjectionResult _failed({
  required String reason,
  Map<String, Object?> facts = const {},
}) =>
    ApartmentCanonicalProjectionResult(
      projection: null,
      failures: [
        P9Failure(
          code: 'INTERNAL_GENERATION_ERROR',
          stage: P9FailureStage.materialization,
          severity: P9FailureSeverity.blocker,
          facts: {'reason': reason, ...facts},
        ),
      ],
    );

ComponentId _componentId(ApartmentTopologyDraft draft, String semanticKey) =>
    ComponentId(
      'p9c-${p9Sha256Hex('p9.component.v1|${draft.draftFingerprint}|$semanticKey')}',
    );

PortId _portId(
  ApartmentTopologyDraft draft,
  _SpatialRelation relation,
  String semanticKey,
) =>
    PortId(
      'p9p-${p9Sha256Hex('p9.port.v1|${draft.draftFingerprint}|${relation.stableKey}|$semanticKey')}',
    );

EngineeringConnectionId _connectionId(
  ApartmentTopologyDraft draft,
  _SpatialRelation relation,
) =>
    EngineeringConnectionId(
      'p9e-${p9Sha256Hex('p9.connection.v1|${draft.draftFingerprint}|${relation.stableKey}')}',
    );

ComponentPlacement _placement({
  required ComponentId componentId,
  required LevelId levelId,
  required GeneratedSpaceGeometry geometry,
}) {
  final footprint = [
    for (final point in geometry.polygon.vertices)
      HostLocalPointMm(uMm: point.xMm, vMm: point.yMm),
  ];
  return ComponentPlacement(
    componentId: componentId,
    host: LevelComponentHost(levelId),
    position: footprint.first,
    footprint: footprint,
  );
}

String _stableGraphSerialization(CanonicalEngineeringGraph graph) {
  final components = [...graph.components]
    ..sort((left, right) => left.id.value.compareTo(right.id.value));
  final connections = [...graph.connections]
    ..sort((left, right) => left.id.value.compareTo(right.id.value));
  return <String>[
    for (final component in components)
      _stableComponentSerialization(component),
    for (final connection in connections)
      <String>[
        'connection=${connection.id.value}',
        'from=${connection.fromComponentId.value}:${connection.fromPortId.value}',
        'to=${connection.toComponentId.value}:${connection.toPortId.value}',
        'type=${connection.connectionType.name}',
        'system=${connection.systemClass.name}',
        'semanticType=${connection.semanticTypeId ?? '-'}',
        'route=${connection.routeId?.value ?? '-'}',
        'circuit=${connection.circuitId?.value ?? '-'}',
      ].join('|'),
  ].join('\n');
}

String _stableComponentSerialization(EngineeringGraphComponent component) {
  final ports = [...component.ports]
    ..sort((left, right) => left.id.compareTo(right.id));
  return <String>[
    'component=${component.id.value}',
    'type=${component.componentTypeId}',
    'discipline=${component.discipline.name}',
    'system=${component.systemClass.name}',
    'ratedPowerW=${component.ratedPowerW ?? '-'}',
    'voltageV=${component.voltageV ?? '-'}',
    'quantity=${component.quantity}',
    for (final port in ports)
      'port=${port.id}:${port.direction.name}:${(port.allowedConnections.map((type) => type.name).toList()..sort()).join(',')}',
  ].join('|');
}
