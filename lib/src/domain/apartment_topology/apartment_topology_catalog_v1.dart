import '../apartment_topology.dart';
import '../project_aggregate.dart';
import '../project_identity.dart';
import '../project_space_semantics.dart';
import 'apartment_topology_catalog.dart';
import 'apartment_topology_models.dart';

/// Bundled immutable P9 production catalog baseline.
///
/// P9.3 owns grammar expansion. This file declares only typed semantic recipes,
/// compatibility envelopes and bounded structural seeds.
abstract final class P9ApartmentTopologyCatalogV1 {
  static ApartmentTopologyCatalog create() {
    final catalog = ApartmentTopologyCatalog(
      catalogVersion: 1,
      templates: [
        _separateTemplate(
          id: 'p9-compact-separate',
          family: ApartmentTopologyFamily.compact,
          roomMin: 1,
          roomMax: 3,
          minAreaDm2: 2400,
          maxAreaDm2: 9000,
          stableOrder: 10,
          corridorMax: 1,
          exposure: const {
            ApartmentExteriorExposurePreference.oneSide,
            ApartmentExteriorExposurePreference.corner,
          },
        ),
        _separateTemplate(
          id: 'p9-linear-separate',
          family: ApartmentTopologyFamily.linear,
          roomMin: 1,
          roomMax: 4,
          minAreaDm2: 2500,
          maxAreaDm2: 13000,
          stableOrder: 20,
          corridorMax: 2,
          exposure: const {
            ApartmentExteriorExposurePreference.oneSide,
            ApartmentExteriorExposurePreference.oppositeSides,
          },
        ),
        _separateTemplate(
          id: 'p9-corner-separate',
          family: ApartmentTopologyFamily.corner,
          roomMin: 2,
          roomMax: 5,
          minAreaDm2: 3500,
          maxAreaDm2: 17000,
          stableOrder: 30,
          corridorMax: 2,
          exposure: const {ApartmentExteriorExposurePreference.corner},
        ),
        _separateTemplate(
          id: 'p9-central-corridor-separate',
          family: ApartmentTopologyFamily.centralCorridor,
          roomMin: 3,
          roomMax: 6,
          minAreaDm2: 5000,
          maxAreaDm2: 22000,
          stableOrder: 40,
          corridorMax: 2,
          exposure: const {
            ApartmentExteriorExposurePreference.oneSide,
            ApartmentExteriorExposurePreference.corner,
            ApartmentExteriorExposurePreference.oppositeSides,
          },
        ),
        _separateTemplate(
          id: 'p9-corridor-spine-separate',
          family: ApartmentTopologyFamily.corridorSpine,
          roomMin: 4,
          roomMax: 10,
          minAreaDm2: 6500,
          maxAreaDm2: 50000,
          stableOrder: 50,
          corridorMax: 3,
          exposure: const {
            ApartmentExteriorExposurePreference.oneSide,
            ApartmentExteriorExposurePreference.oppositeSides,
          },
        ),
        _separateTemplate(
          id: 'p9-split-day-night-separate',
          family: ApartmentTopologyFamily.splitDayNight,
          roomMin: 3,
          roomMax: 10,
          minAreaDm2: 5000,
          maxAreaDm2: 50000,
          stableOrder: 60,
          corridorMax: 3,
          supportsDayNight: true,
          exposure: const {
            ApartmentExteriorExposurePreference.oneSide,
            ApartmentExteriorExposurePreference.corner,
            ApartmentExteriorExposurePreference.oppositeSides,
          },
        ),
        _kitchenLivingTemplate(
          id: 'p9-compact-kitchen-living',
          family: ApartmentTopologyFamily.compact,
          roomMin: 1,
          roomMax: 3,
          minAreaDm2: 2200,
          maxAreaDm2: 9500,
          stableOrder: 70,
        ),
        _kitchenLivingTemplate(
          id: 'p9-euro-kitchen-living',
          family: ApartmentTopologyFamily.euro,
          roomMin: 1,
          roomMax: 4,
          minAreaDm2: 2400,
          maxAreaDm2: 15000,
          stableOrder: 80,
        ),
        _kitchenLivingTemplate(
          id: 'p9-corner-kitchen-living',
          family: ApartmentTopologyFamily.corner,
          roomMin: 2,
          roomMax: 5,
          minAreaDm2: 3400,
          maxAreaDm2: 18000,
          stableOrder: 90,
          exposure: const {ApartmentExteriorExposurePreference.corner},
        ),
        _openPlanTemplate(
          id: 'p9-open-plan',
          family: ApartmentTopologyFamily.openPlan,
          roomMin: 1,
          roomMax: 3,
          minAreaDm2: 2300,
          maxAreaDm2: 12000,
          stableOrder: 100,
        ),
        _openPlanTemplate(
          id: 'p9-linear-open-plan',
          family: ApartmentTopologyFamily.linear,
          roomMin: 1,
          roomMax: 4,
          minAreaDm2: 2500,
          maxAreaDm2: 14500,
          stableOrder: 110,
          exposure: const {
            ApartmentExteriorExposurePreference.oneSide,
            ApartmentExteriorExposurePreference.oppositeSides,
          },
        ),
      ],
    );
    catalog.validateOrThrow();
    return catalog;
  }
}

ApartmentTopologyTemplate _separateTemplate({
  required String id,
  required ApartmentTopologyFamily family,
  required int roomMin,
  required int roomMax,
  required int minAreaDm2,
  required int maxAreaDm2,
  required int stableOrder,
  required int corridorMax,
  required Set<ApartmentExteriorExposurePreference> exposure,
  bool supportsDayNight = false,
}) =>
    _template(
      id: id,
      family: family,
      roomMin: roomMin,
      roomMax: roomMax,
      minAreaDm2: minAreaDm2,
      maxAreaDm2: maxAreaDm2,
      stableOrder: stableOrder,
      kitchenMode: ApartmentKitchenMode.separate,
      supportsDayNight: supportsDayNight,
      exposure: exposure,
      corridorMax: corridorMax,
      daySpace: _space(
        key: 'livingRoom',
        usage: SpaceUsage.livingRoom,
        multiplicityMin: 1,
        multiplicityMax: 1,
        minAreaDm2: 800,
        preferredAreaDm2: 1600,
        maxAreaDm2: 4000,
        areaWeightBp: 1800,
        requiresExteriorExposure: true,
      ),
      kitchen: _space(
        key: 'kitchen',
        usage: SpaceUsage.kitchen,
        multiplicityMin: 1,
        multiplicityMax: 1,
        minAreaDm2: 450,
        preferredAreaDm2: 900,
        maxAreaDm2: 2200,
        areaWeightBp: 900,
        requiresExteriorExposure: true,
      ),
      extraAdjacency: const [
        TopologyAdjacencyRule(
          fromKey: 'livingRoom',
          toKey: 'kitchen',
          requirement: TopologyAdjacencyRequirement.preferred,
          kind: TopologyAdjacencyKind.directBoundary,
          minSharedBoundaryMm: 800,
        ),
      ],
    );

ApartmentTopologyTemplate _kitchenLivingTemplate({
  required String id,
  required ApartmentTopologyFamily family,
  required int roomMin,
  required int roomMax,
  required int minAreaDm2,
  required int maxAreaDm2,
  required int stableOrder,
  Set<ApartmentExteriorExposurePreference> exposure = const {
    ApartmentExteriorExposurePreference.oneSide,
    ApartmentExteriorExposurePreference.corner,
  },
}) =>
    _template(
      id: id,
      family: family,
      roomMin: roomMin,
      roomMax: roomMax,
      minAreaDm2: minAreaDm2,
      maxAreaDm2: maxAreaDm2,
      stableOrder: stableOrder,
      kitchenMode: ApartmentKitchenMode.kitchenLiving,
      supportsDayNight: family == ApartmentTopologyFamily.splitDayNight,
      exposure: exposure,
      corridorMax: 2,
      daySpace: _space(
        key: 'kitchenLiving',
        usage: SpaceUsage.kitchenLiving,
        multiplicityMin: 1,
        multiplicityMax: 1,
        minAreaDm2: 1200,
        preferredAreaDm2: 2200,
        maxAreaDm2: 5000,
        areaWeightBp: 2400,
        requiresExteriorExposure: true,
      ),
      kitchen: null,
    );

ApartmentTopologyTemplate _openPlanTemplate({
  required String id,
  required ApartmentTopologyFamily family,
  required int roomMin,
  required int roomMax,
  required int minAreaDm2,
  required int maxAreaDm2,
  required int stableOrder,
  Set<ApartmentExteriorExposurePreference> exposure = const {
    ApartmentExteriorExposurePreference.oneSide,
    ApartmentExteriorExposurePreference.corner,
  },
}) =>
    _template(
      id: id,
      family: family,
      roomMin: roomMin,
      roomMax: roomMax,
      minAreaDm2: minAreaDm2,
      maxAreaDm2: maxAreaDm2,
      stableOrder: stableOrder,
      kitchenMode: ApartmentKitchenMode.openPlan,
      supportsDayNight: false,
      exposure: exposure,
      corridorMax: 2,
      daySpace: _space(
        key: 'livingRoom',
        usage: SpaceUsage.livingRoom,
        multiplicityMin: 1,
        multiplicityMax: 1,
        minAreaDm2: 800,
        preferredAreaDm2: 1600,
        maxAreaDm2: 4000,
        areaWeightBp: 1800,
        requiresExteriorExposure: true,
      ),
      kitchen: _space(
        key: 'kitchen',
        usage: SpaceUsage.kitchen,
        multiplicityMin: 1,
        multiplicityMax: 1,
        minAreaDm2: 400,
        preferredAreaDm2: 800,
        maxAreaDm2: 1800,
        areaWeightBp: 800,
        requiresExteriorExposure: true,
      ),
      extraAdjacency: const [
        TopologyAdjacencyRule(
          fromKey: 'livingRoom',
          toKey: 'kitchen',
          requirement: TopologyAdjacencyRequirement.required,
          kind: TopologyAdjacencyKind.openConnection,
          minSharedBoundaryMm: 1200,
        ),
      ],
    );

ApartmentTopologyTemplate _template({
  required String id,
  required ApartmentTopologyFamily family,
  required int roomMin,
  required int roomMax,
  required int minAreaDm2,
  required int maxAreaDm2,
  required int stableOrder,
  required ApartmentKitchenMode kitchenMode,
  required bool supportsDayNight,
  required Set<ApartmentExteriorExposurePreference> exposure,
  required int corridorMax,
  required TopologySpaceSpec daySpace,
  required TopologySpaceSpec? kitchen,
  List<TopologyAdjacencyRule> extraAdjacency = const [],
}) {
  final spaces = <TopologySpaceSpec>[
    daySpace,
    _space(
      key: 'bedroom',
      usage: SpaceUsage.bedroom,
      multiplicityMin: 0,
      multiplicityMax: roomMax - 1,
      minAreaDm2: 650,
      preferredAreaDm2: 1200,
      maxAreaDm2: 3000,
      areaWeightBp: 1400,
      requiresExteriorExposure: true,
    ),
    if (kitchen != null) kitchen,
    _space(
      key: 'bathroom',
      usage: SpaceUsage.bathroom,
      multiplicityMin: 1,
      multiplicityMax: 6,
      minAreaDm2: 250,
      preferredAreaDm2: 450,
      maxAreaDm2: 1000,
      areaWeightBp: 500,
      wetSpace: true,
      nearFixedArea: true,
    ),
    _space(
      key: 'wc',
      usage: SpaceUsage.wc,
      multiplicityMin: 0,
      multiplicityMax: 4,
      minAreaDm2: 120,
      preferredAreaDm2: 180,
      maxAreaDm2: 400,
      areaWeightBp: 250,
      wetSpace: true,
      nearFixedArea: true,
    ),
    _space(
      key: 'entranceHall',
      usage: SpaceUsage.entranceHall,
      multiplicityMin: 1,
      multiplicityMax: 1,
      minAreaDm2: 180,
      preferredAreaDm2: 300,
      maxAreaDm2: 900,
      areaWeightBp: 350,
      circulationSpace: true,
      nearFixedArea: true,
    ),
    _space(
      key: 'corridor',
      usage: SpaceUsage.corridor,
      type: ProjectSpaceType.corridor,
      multiplicityMin: roomMax >= 4 ? 1 : 0,
      multiplicityMax: corridorMax,
      minAreaDm2: 120,
      preferredAreaDm2: 260,
      maxAreaDm2: 1200,
      areaWeightBp: 300,
      circulationSpace: true,
      nearFixedArea: true,
    ),
    _appendage(
      key: 'balcony',
      usage: SpaceUsage.balcony,
      maxMultiplicity: 6,
    ),
    _appendage(
      key: 'loggia',
      usage: SpaceUsage.loggia,
      maxMultiplicity: 6,
    ),
  ];

  return ApartmentTopologyTemplate(
    templateId: TemplateId(id),
    templateVersion: 1,
    family: family,
    stableOrder: stableOrder,
    constraints: ApartmentTemplateConstraints(
      supportedHabitableRoomCounts: _range(roomMin, roomMax),
      minInteriorAreaDm2: minAreaDm2,
      maxInteriorAreaDm2: maxAreaDm2,
      supportedBathroomCounts: _range(1, 6),
      supportedSeparateWcCounts: _range(0, 4),
      supportedBalconyCounts: _range(0, 6),
      supportedBalconyKinds: const {
        ApartmentBalconyKind.none,
        ApartmentBalconyKind.balcony,
        ApartmentBalconyKind.loggia,
        ApartmentBalconyKind.either,
      },
      supportedKitchenModes: {kitchenMode},
      supportedCorridorModes: const {
        ApartmentCorridorMode.compact,
        ApartmentCorridorMode.central,
        ApartmentCorridorMode.minimal,
      },
      supportedExteriorExposurePreferences: exposure,
      supportsDayNightSeparation: supportsDayNight,
    ),
    spaces: spaces,
    adjacencyRules: [
      TopologyAdjacencyRule(
        fromKey: 'entranceHall',
        toKey: daySpace.semanticKey,
        requirement: TopologyAdjacencyRequirement.required,
        kind: TopologyAdjacencyKind.access,
      ),
      TopologyAdjacencyRule(
        fromKey: 'bathroom',
        toKey: 'entranceHall',
        requirement: TopologyAdjacencyRequirement.preferred,
        kind: TopologyAdjacencyKind.access,
      ),
      TopologyAdjacencyRule(
        fromKey: 'bedroom',
        toKey: daySpace.semanticKey,
        requirement: TopologyAdjacencyRequirement.preferred,
        kind: TopologyAdjacencyKind.directBoundary,
      ),
      ...extraAdjacency,
    ],
    areaProfile: const TopologyAreaProfile(
      maxCirculationAreaBp: 1800,
      serviceAreaWeightBp: 2500,
      habitableAreaWeightBp: 7500,
    ),
    circulationPolicy: CirculationPolicy(
      maxCirculationSpaceCount: corridorMax + 1,
      requireEntryDistribution: true,
    ),
    wetCorePolicy: const WetCorePolicy(
      maxWetCoreGroupCount: 2,
      maxGroupSeparationMm: 5000,
      preferSharedServiceBoundary: true,
    ),
    variantSeeds: _seeds(family),
  );
}

TopologySpaceSpec _space({
  required String key,
  required SpaceUsage usage,
  required int multiplicityMin,
  required int multiplicityMax,
  required int minAreaDm2,
  required int preferredAreaDm2,
  required int maxAreaDm2,
  required int areaWeightBp,
  ProjectSpaceType type = ProjectSpaceType.room,
  bool nearFixedArea = false,
  bool requiresExteriorExposure = false,
  bool wetSpace = false,
  bool circulationSpace = false,
}) =>
    TopologySpaceSpec(
      semanticKey: key,
      usage: usage,
      type: type,
      multiplicityMin: multiplicityMin,
      multiplicityMax: multiplicityMax,
      areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
      minAreaDm2: minAreaDm2,
      preferredAreaDm2: preferredAreaDm2,
      maxAreaDm2: maxAreaDm2,
      areaWeightBp: areaWeightBp,
      nearFixedArea: nearFixedArea,
      requiresExteriorExposure: requiresExteriorExposure,
      wetSpace: wetSpace,
      circulationSpace: circulationSpace,
      geometry: TopologySpaceGeometryConstraints(
        minShortSideMm: circulationSpace ? 900 : 1600,
        minLongSideMm: circulationSpace ? 1200 : 2200,
        minAspectBp: 3500,
        maxAspectBp: circulationSpace ? 50000 : 28000,
        minExteriorExposureMm: requiresExteriorExposure ? 1600 : null,
        maxVertices: 8,
      ),
    );

TopologySpaceSpec _appendage({
  required String key,
  required SpaceUsage usage,
  required int maxMultiplicity,
}) =>
    TopologySpaceSpec(
      semanticKey: key,
      usage: usage,
      type: ProjectSpaceType.room,
      multiplicityMin: 0,
      multiplicityMax: maxMultiplicity,
      areaParticipation: SpaceAreaParticipation.exteriorAppendage,
      minAreaDm2: 180,
      preferredAreaDm2: 350,
      maxAreaDm2: 1200,
      areaWeightBp: 300,
      nearFixedArea: true,
      requiresExteriorExposure: false,
      wetSpace: false,
      circulationSpace: false,
      geometry: const TopologySpaceGeometryConstraints(
        minShortSideMm: 800,
        minLongSideMm: 1200,
        minAspectBp: 2500,
        maxAspectBp: 50000,
        maxVertices: 8,
      ),
    );

List<TopologyVariantSeed> _seeds(ApartmentTopologyFamily family) => [
      TopologyVariantSeed(
        seedId: '${family.code}-a',
        entrySide: TopologyEntrySide.west,
        mirrored: false,
        dayNightOrientation: family == ApartmentTopologyFamily.splitDayNight
            ? DayNightOrientation.dayFirst
            : DayNightOrientation.none,
        balconyStrategy: BalconyAttachmentStrategy.bestExteriorExposure,
        stableOrder: 0,
      ),
      TopologyVariantSeed(
        seedId: '${family.code}-b',
        entrySide: TopologyEntrySide.east,
        mirrored: true,
        dayNightOrientation: family == ApartmentTopologyFamily.splitDayNight
            ? DayNightOrientation.nightFirst
            : DayNightOrientation.none,
        balconyStrategy: BalconyAttachmentStrategy.daySpace,
        stableOrder: 1,
      ),
    ];

Set<int> _range(int start, int end) => {
      for (var value = start; value <= end; value++) value,
    };
