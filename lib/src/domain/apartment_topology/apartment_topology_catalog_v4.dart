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
const int _corridorPreferredAreaDm2 = 2200;

ApartmentTopologyTemplate _upgradeTemplate(ApartmentTopologyTemplate source) =>
    ApartmentTopologyTemplate(
      templateId: source.templateId,
      templateVersion: source.templateVersion + 1,
      family: source.family,
      stableOrder: source.stableOrder,
      constraints: source.constraints,
      spaces: [for (final space in source.spaces) _upgradeSpace(space)],
      adjacencyRules: source.adjacencyRules,
      areaProfile: source.areaProfile,
      circulationPolicy: source.circulationPolicy,
      wetCorePolicy: source.wetCorePolicy,
      variantSeeds: source.variantSeeds,
    );

TopologySpaceSpec _upgradeSpace(TopologySpaceSpec source) {
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
            ? _entranceHallPreferredAreaDm2
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
