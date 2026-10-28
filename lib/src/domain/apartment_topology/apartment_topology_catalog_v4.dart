import '../apartment_topology.dart';
import '../project_space_semantics.dart';
import 'apartment_topology_catalog.dart';
import 'apartment_topology_catalog_v3.dart';
import 'apartment_topology_models.dart';

/// Production catalog for access-preserving P9.6 geometry.
///
/// V4 versions the circulation dimensional/area profile. Corridors are
/// allowed to be long, narrow distribution spines; habitable/service-room
/// constraints remain unchanged. The preferred circulation areas are sized so
/// P9.4 can stay geometry-agnostic while still handing P9.6 a physically
/// realizable access spine for the qualified 1..10-room corpus.
///
/// Open-plan templates reserve a slightly larger entrance hall because P9.6
/// must host the hard access edges from the entry distribution space while the
/// living/kitchen pair also preserves its required open connection.
///
/// V4 also makes the catalog-level entrance -> day access a preference. P9.3
/// emits the hard access edge against the actual distribution space: directly
/// to the entrance hall when there is no corridor, or through the corridor
/// when one is present. This avoids manufacturing a physically unnecessary
/// access triangle in corridor-backed layouts.
///
/// These are product-generation heuristics, not normative compliance claims.
abstract final class P9ApartmentTopologyCatalogV4 {
  static ApartmentTopologyCatalog create() {
    final previous = P9ApartmentTopologyCatalogV3.create();
    final catalog = ApartmentTopologyCatalog(
      catalogVersion: 4,
      templates: [
        for (final template in previous.templates) _upgradeTemplate(template),
      ],
    );
    catalog.validateOrThrow();
    return catalog;
  }
}

const int _entranceHallPreferredAreaDm2 = 500;
const int _openPlanEntranceHallPreferredAreaDm2 = 650;
const int _corridorPreferredAreaDm2 = 2200;

ApartmentTopologyTemplate _upgradeTemplate(ApartmentTopologyTemplate source) {
  final openPlan = source.constraints.supportedKitchenModes.contains(
    ApartmentKitchenMode.openPlan,
  );
  return ApartmentTopologyTemplate(
    templateId: source.templateId,
    templateVersion: source.templateVersion + 1,
    family: source.family,
    stableOrder: source.stableOrder,
    constraints: source.constraints,
    spaces: [
      for (final space in source.spaces)
        _upgradeSpace(space, openPlan: openPlan),
    ],
    adjacencyRules: [
      for (final rule in source.adjacencyRules) _upgradeAdjacencyRule(rule),
    ],
    areaProfile: source.areaProfile,
    circulationPolicy: source.circulationPolicy,
    wetCorePolicy: source.wetCorePolicy,
    variantSeeds: source.variantSeeds,
  );
}

TopologyAdjacencyRule _upgradeAdjacencyRule(TopologyAdjacencyRule source) {
  final catalogEntryToDayAccess = source.fromKey == 'entranceHall' &&
      source.kind == TopologyAdjacencyKind.access &&
      source.requirement == TopologyAdjacencyRequirement.required;
  if (!catalogEntryToDayAccess) {
    return source;
  }
  return TopologyAdjacencyRule(
    fromKey: source.fromKey,
    toKey: source.toKey,
    requirement: TopologyAdjacencyRequirement.preferred,
    kind: source.kind,
    minSharedBoundaryMm: source.minSharedBoundaryMm,
  );
}

TopologySpaceSpec _upgradeSpace(
  TopologySpaceSpec source, {
  required bool openPlan,
}) {
  final corridor = source.usage == SpaceUsage.corridor;
  final entranceHall = source.usage == SpaceUsage.entranceHall;
  final geometry = switch (source.usage) {
    SpaceUsage.corridor => TopologySpaceGeometryConstraints(
        minShortSideMm: 900,
        minLongSideMm: 1200,
        minAspectBp: 700,
        maxAspectBp: 140000,
        minExteriorExposureMm: source.geometry.minExteriorExposureMm,
        maxVertices: source.geometry.maxVertices,
      ),
    SpaceUsage.entranceHall => TopologySpaceGeometryConstraints(
        minShortSideMm: 900,
        minLongSideMm: 1200,
        minAspectBp: 1800,
        maxAspectBp: 55000,
        minExteriorExposureMm: source.geometry.minExteriorExposureMm,
        maxVertices: source.geometry.maxVertices,
      ),
    _ => source.geometry,
  };

  return TopologySpaceSpec(
    semanticKey: source.semanticKey,
    usage: source.usage,
    type: source.type,
    multiplicityMin: source.multiplicityMin,
    multiplicityMax: source.multiplicityMax,
    areaParticipation: source.areaParticipation,
    minAreaDm2: source.minAreaDm2,
    preferredAreaDm2: corridor
        ? _corridorPreferredAreaDm2
        : entranceHall
            ? openPlan
                ? _openPlanEntranceHallPreferredAreaDm2
                : _entranceHallPreferredAreaDm2
            : source.preferredAreaDm2,
    maxAreaDm2: corridor ? _corridorPreferredAreaDm2 : source.maxAreaDm2,
    areaWeightBp: source.areaWeightBp,
    nearFixedArea: source.nearFixedArea,
    requiresExteriorExposure: source.requiresExteriorExposure,
    wetSpace: source.wetSpace,
    circulationSpace: source.circulationSpace,
    geometry: geometry,
  );
}
