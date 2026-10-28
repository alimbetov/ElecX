import '../apartment_topology.dart';
import '../project_aggregate.dart';
import '../project_identity.dart';
import '../project_space_semantics.dart';
import 'apartment_topology_models.dart';

final class DraftSpace {
  const DraftSpace({
    required this.semanticKey,
    required this.baseSemanticKey,
    required this.ordinal,
    required this.usage,
    required this.type,
    required this.areaParticipation,
    required this.sourceSpec,
  });

  final String semanticKey;
  final String baseSemanticKey;
  final int ordinal;
  final SpaceUsage usage;
  final ProjectSpaceType type;
  final SpaceAreaParticipation areaParticipation;
  final TopologySpaceSpec sourceSpec;
}

final class DraftAdjacencyIntent {
  const DraftAdjacencyIntent({
    required this.fromSpaceKey,
    required this.toSpaceKey,
    required this.requirement,
    required this.kind,
    this.minSharedBoundaryMm,
  });

  final String fromSpaceKey;
  final String toSpaceKey;
  final TopologyAdjacencyRequirement requirement;
  final TopologyAdjacencyKind kind;
  final int? minSharedBoundaryMm;

  String get normalizedPairKey => fromSpaceKey.compareTo(toSpaceKey) <= 0
      ? '$fromSpaceKey|$toSpaceKey'
      : '$toSpaceKey|$fromSpaceKey';
}

enum DraftAccessKind { door, openPassage }

final class DraftAccessEdge {
  const DraftAccessEdge({
    required this.fromSpaceKey,
    required this.toSpaceKey,
    required this.kind,
  });

  final String fromSpaceKey;
  final String toSpaceKey;
  final DraftAccessKind kind;

  String get normalizedPairKey => fromSpaceKey.compareTo(toSpaceKey) <= 0
      ? '$fromSpaceKey|$toSpaceKey'
      : '$toSpaceKey|$fromSpaceKey';
}

final class DraftCirculationGraph {
  DraftCirculationGraph({
    required this.entrySpaceKey,
    required Iterable<DraftAccessEdge> accessEdges,
  }) : accessEdges = List.unmodifiable(accessEdges);

  final String entrySpaceKey;
  final List<DraftAccessEdge> accessEdges;
}

enum DraftExteriorSide { west, north, east, south }

final class DraftExteriorExposure {
  DraftExteriorExposure(Map<String, DraftExteriorSide> assignments)
      : assignments = Map.unmodifiable(assignments);

  final Map<String, DraftExteriorSide> assignments;
}

final class DraftWetCoreGrouping {
  DraftWetCoreGrouping(Iterable<Iterable<String>> groups)
      : groups = List.unmodifiable(
          groups.map((group) => List<String>.unmodifiable(group)),
        );

  final List<List<String>> groups;
}

enum DraftLayoutAxis { horizontal, vertical }

final class DraftLayoutSkeleton {
  DraftLayoutSkeleton({
    required this.primaryAxis,
    required this.mirrored,
    required this.entrySide,
    required Iterable<String> stableRoleOrder,
    required Iterable<String> dayZoneKeys,
    required Iterable<String> nightZoneKeys,
  })  : stableRoleOrder = List.unmodifiable(stableRoleOrder),
        dayZoneKeys = List.unmodifiable(dayZoneKeys),
        nightZoneKeys = List.unmodifiable(nightZoneKeys);

  final DraftLayoutAxis primaryAxis;
  final bool mirrored;
  final TopologyEntrySide entrySide;
  final List<String> stableRoleOrder;
  final List<String> dayZoneKeys;
  final List<String> nightZoneKeys;
}

/// Semantic P9.3 output. It carries no final geometry and no canonical IDs.
final class ApartmentTopologyDraft {
  ApartmentTopologyDraft({
    required this.templateId,
    required this.templateVersion,
    required this.family,
    required this.variantSeedId,
    required this.intentFingerprint,
    required Iterable<DraftSpace> spaces,
    required Iterable<DraftAdjacencyIntent> adjacency,
    required this.circulation,
    required this.exteriorExposure,
    required this.wetCore,
    required this.layoutSkeleton,
    required this.semanticSignature,
    required this.draftFingerprint,
  })  : spaces = List.unmodifiable(spaces),
        adjacency = List.unmodifiable(adjacency);

  final TemplateId templateId;
  final int templateVersion;
  final ApartmentTopologyFamily family;
  final String variantSeedId;
  final String intentFingerprint;
  final List<DraftSpace> spaces;
  final List<DraftAdjacencyIntent> adjacency;
  final DraftCirculationGraph circulation;
  final DraftExteriorExposure exteriorExposure;
  final DraftWetCoreGrouping wetCore;
  final DraftLayoutSkeleton layoutSkeleton;

  /// Template/seed-independent semantic equivalence key used only for bounded
  /// duplicate suppression before P9.4.
  final String semanticSignature;

  /// Full draft identity includes request/template/seed lineage.
  final String draftFingerprint;
}
