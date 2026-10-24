import '../apartment_topology.dart';
import '../project_aggregate.dart';
import '../project_identity.dart';
import '../project_space_semantics.dart';

/// Explicit request compatibility envelope for one topology template.
final class ApartmentTemplateConstraints {
  ApartmentTemplateConstraints({
    required Iterable<int> supportedHabitableRoomCounts,
    required this.minInteriorAreaDm2,
    required this.maxInteriorAreaDm2,
    required Iterable<int> supportedBathroomCounts,
    required Iterable<int> supportedSeparateWcCounts,
    required Iterable<int> supportedBalconyCounts,
    required Iterable<ApartmentBalconyKind> supportedBalconyKinds,
    required Iterable<ApartmentKitchenMode> supportedKitchenModes,
    required Iterable<ApartmentCorridorMode> supportedCorridorModes,
    required Iterable<ApartmentExteriorExposurePreference>
        supportedExteriorExposurePreferences,
    required this.supportsDayNightSeparation,
  })  : supportedHabitableRoomCounts =
            Set.unmodifiable(supportedHabitableRoomCounts),
        supportedBathroomCounts = Set.unmodifiable(supportedBathroomCounts),
        supportedSeparateWcCounts = Set.unmodifiable(supportedSeparateWcCounts),
        supportedBalconyCounts = Set.unmodifiable(supportedBalconyCounts),
        supportedBalconyKinds = Set.unmodifiable(supportedBalconyKinds),
        supportedKitchenModes = Set.unmodifiable(supportedKitchenModes),
        supportedCorridorModes = Set.unmodifiable(supportedCorridorModes),
        supportedExteriorExposurePreferences =
            Set.unmodifiable(supportedExteriorExposurePreferences);

  final Set<int> supportedHabitableRoomCounts;
  final int minInteriorAreaDm2;
  final int maxInteriorAreaDm2;
  final Set<int> supportedBathroomCounts;
  final Set<int> supportedSeparateWcCounts;
  final Set<int> supportedBalconyCounts;
  final Set<ApartmentBalconyKind> supportedBalconyKinds;
  final Set<ApartmentKitchenMode> supportedKitchenModes;
  final Set<ApartmentCorridorMode> supportedCorridorModes;
  final Set<ApartmentExteriorExposurePreference>
      supportedExteriorExposurePreferences;
  final bool supportsDayNightSeparation;
}

final class TopologySpaceGeometryConstraints {
  const TopologySpaceGeometryConstraints({
    required this.minShortSideMm,
    required this.minAspectBp,
    required this.maxAspectBp,
    required this.maxVertices,
    this.minLongSideMm,
    this.minExteriorExposureMm,
  });

  final int minShortSideMm;
  final int? minLongSideMm;
  final int minAspectBp;
  final int maxAspectBp;
  final int? minExteriorExposureMm;
  final int maxVertices;
}

/// Semantic space recipe. Multiplicity is expanded by P9.3, not by catalog
/// filtering, so one template can scale across a bounded room-count range.
final class TopologySpaceSpec {
  const TopologySpaceSpec({
    required this.semanticKey,
    required this.usage,
    required this.type,
    required this.multiplicityMin,
    required this.multiplicityMax,
    required this.areaParticipation,
    required this.minAreaDm2,
    required this.preferredAreaDm2,
    required this.maxAreaDm2,
    required this.areaWeightBp,
    required this.nearFixedArea,
    required this.requiresExteriorExposure,
    required this.wetSpace,
    required this.circulationSpace,
    required this.geometry,
  });

  final String semanticKey;
  final SpaceUsage usage;
  final ProjectSpaceType type;
  final int multiplicityMin;
  final int multiplicityMax;
  final SpaceAreaParticipation areaParticipation;
  final int minAreaDm2;
  final int preferredAreaDm2;
  final int maxAreaDm2;
  final int areaWeightBp;
  final bool nearFixedArea;
  final bool requiresExteriorExposure;
  final bool wetSpace;
  final bool circulationSpace;
  final TopologySpaceGeometryConstraints geometry;
}

enum TopologyAdjacencyRequirement { required, preferred, forbidden }

enum TopologyAdjacencyKind { directBoundary, access, openConnection }

/// A P9.2 relation references declared semantic recipe keys. P9.3 expands
/// multiplicity into concrete `semanticKey:ordinal` relations.
final class TopologyAdjacencyRule {
  const TopologyAdjacencyRule({
    required this.fromKey,
    required this.toKey,
    required this.requirement,
    required this.kind,
    this.minSharedBoundaryMm,
  });

  final String fromKey;
  final String toKey;
  final TopologyAdjacencyRequirement requirement;
  final TopologyAdjacencyKind kind;
  final int? minSharedBoundaryMm;

  String get normalizedPairKey => fromKey.compareTo(toKey) <= 0
      ? '$fromKey|$toKey'
      : '$toKey|$fromKey';
}

final class TopologyAreaProfile {
  const TopologyAreaProfile({
    required this.maxCirculationAreaBp,
    required this.serviceAreaWeightBp,
    required this.habitableAreaWeightBp,
  });

  final int maxCirculationAreaBp;
  final int serviceAreaWeightBp;
  final int habitableAreaWeightBp;
}

final class CirculationPolicy {
  const CirculationPolicy({
    required this.maxCirculationSpaceCount,
    required this.requireEntryDistribution,
  });

  final int maxCirculationSpaceCount;
  final bool requireEntryDistribution;
}

final class WetCorePolicy {
  const WetCorePolicy({
    required this.maxWetCoreGroupCount,
    required this.maxGroupSeparationMm,
    required this.preferSharedServiceBoundary,
  });

  final int maxWetCoreGroupCount;
  final int maxGroupSeparationMm;
  final bool preferSharedServiceBoundary;
}

enum TopologyEntrySide { west, east, north, south, controlledMidpoint }

enum DayNightOrientation { none, dayFirst, nightFirst }

enum BalconyAttachmentStrategy { daySpace, bedroom, bestExteriorExposure }

final class TopologyVariantSeed {
  const TopologyVariantSeed({
    required this.seedId,
    required this.entrySide,
    required this.mirrored,
    required this.dayNightOrientation,
    required this.balconyStrategy,
    required this.stableOrder,
  });

  final String seedId;
  final TopologyEntrySide entrySide;
  final bool mirrored;
  final DayNightOrientation dayNightOrientation;
  final BalconyAttachmentStrategy balconyStrategy;
  final int stableOrder;
}

final class ApartmentTopologyTemplate {
  ApartmentTopologyTemplate({
    required this.templateId,
    required this.templateVersion,
    required this.family,
    required this.stableOrder,
    required this.constraints,
    required Iterable<TopologySpaceSpec> spaces,
    required Iterable<TopologyAdjacencyRule> adjacencyRules,
    required this.areaProfile,
    required this.circulationPolicy,
    required this.wetCorePolicy,
    required Iterable<TopologyVariantSeed> variantSeeds,
  })  : spaces = List.unmodifiable(spaces),
        adjacencyRules = List.unmodifiable(adjacencyRules),
        variantSeeds = List.unmodifiable(variantSeeds);

  final TemplateId templateId;
  final int templateVersion;
  final ApartmentTopologyFamily family;
  final int stableOrder;
  final ApartmentTemplateConstraints constraints;
  final List<TopologySpaceSpec> spaces;
  final List<TopologyAdjacencyRule> adjacencyRules;
  final TopologyAreaProfile areaProfile;
  final CirculationPolicy circulationPolicy;
  final WetCorePolicy wetCorePolicy;
  final List<TopologyVariantSeed> variantSeeds;
}

final class TemplateIncompatibilityReason {
  const TemplateIncompatibilityReason({
    required this.code,
    required this.field,
    required this.actualValue,
  });

  final String code;
  final String field;
  final Object? actualValue;
}

final class TemplateCompatibility {
  TemplateCompatibility({
    required this.template,
    required Iterable<TemplateIncompatibilityReason> reasons,
  }) : reasons = List.unmodifiable(reasons);

  final ApartmentTopologyTemplate template;
  final List<TemplateIncompatibilityReason> reasons;

  bool get compatible => reasons.isEmpty;
}
