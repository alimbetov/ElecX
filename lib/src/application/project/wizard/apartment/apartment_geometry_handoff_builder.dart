import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';

/// Lossless P9.5 -> P9.6 handoff builder.
///
/// The semantic validator remains authoritative for acceptance. This builder
/// converts the already accepted semantic draft into the exact geometry
/// constraints P9.6 must realize without re-inferring meaning from labels.
final class ApartmentGeometryHandoffBuilder {
  const ApartmentGeometryHandoffBuilder();

  TopologyGeometryHandoff build(ApartmentTopologyDraft draft) {
    final requiredShared = <RequiredSharedBoundaryIntent>[];
    final forbiddenShared = <SemanticSpacePair>[];

    for (final intent in draft.adjacency) {
      if (intent.kind != TopologyAdjacencyKind.directBoundary &&
          intent.kind != TopologyAdjacencyKind.openConnection) {
        continue;
      }
      if (intent.requirement == TopologyAdjacencyRequirement.required) {
        requiredShared.add(
          RequiredSharedBoundaryIntent(
            fromSpaceKey: intent.fromSpaceKey,
            toSpaceKey: intent.toSpaceKey,
            kind: intent.kind,
            minSharedBoundaryMm: intent.minSharedBoundaryMm ?? 1,
          ),
        );
      } else if (intent.requirement == TopologyAdjacencyRequirement.forbidden) {
        forbiddenShared.add(
          SemanticSpacePair(intent.fromSpaceKey, intent.toSpaceKey),
        );
      }
    }

    final requiredExterior = <String>[
      for (final space in draft.spaces)
        if (space.sourceSpec.requiresExteriorExposure ||
            space.areaParticipation == SpaceAreaParticipation.exteriorAppendage)
          space.semanticKey,
    ];
    final anchors = <String>[
      draft.circulation.entrySpaceKey,
      for (final space in draft.spaces)
        if (space.sourceSpec.circulationSpace) space.semanticKey,
    ];

    return TopologyGeometryHandoff(
      requiredSharedBoundaries: requiredShared,
      forbiddenSharedBoundaryPairs: forbiddenShared,
      requiredExteriorSpaceKeys: requiredExterior,
      requiredExteriorAssignments: draft.exteriorExposure.assignments,
      wetCoreGroups: draft.wetCore.groups,
      accessIntents: [
        for (final edge in draft.circulation.accessEdges)
          SemanticAccessIntent(
            fromSpaceKey: edge.fromSpaceKey,
            toSpaceKey: edge.toSpaceKey,
            kind: edge.kind,
          ),
      ],
      circulationAnchorKeys: anchors,
      entrySpaceKey: draft.circulation.entrySpaceKey,
    );
  }
}
