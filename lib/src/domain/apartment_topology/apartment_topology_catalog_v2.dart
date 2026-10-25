import '../project_space_semantics.dart';
import 'apartment_topology_catalog.dart';
import 'apartment_topology_catalog_v1.dart';
import 'apartment_topology_models.dart';

/// Geometry-feasible production catalog used by P9.6+.
///
/// Catalog v1 remains immutable for reproducibility. V2 preserves template IDs
/// and semantic recipes while versioning the dimensional contract that P9.6
/// must realize. Wet service spaces use a compact service-room geometry profile
/// instead of the habitable-room profile inherited by v1.
abstract final class P9ApartmentTopologyCatalogV2 {
  static ApartmentTopologyCatalog create() {
    final previous = P9ApartmentTopologyCatalogV1.create();
    final catalog = ApartmentTopologyCatalog(
      catalogVersion: 2,
      templates: [
        for (final template in previous.templates) _upgradeTemplate(template),
      ],
    );
    catalog.validateOrThrow();
    return catalog;
  }
}

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
  final geometry = source.wetSpace
      ? TopologySpaceGeometryConstraints(
          minShortSideMm: 900,
          minLongSideMm: 1200,
          minAspectBp: 3000,
          maxAspectBp: 35000,
          minExteriorExposureMm: source.geometry.minExteriorExposureMm,
          maxVertices: source.geometry.maxVertices,
        )
      : source.geometry;

  return TopologySpaceSpec(
    semanticKey: source.semanticKey,
    usage: source.usage,
    type: source.type,
    multiplicityMin: source.multiplicityMin,
    multiplicityMax: source.multiplicityMax,
    areaParticipation: source.areaParticipation,
    minAreaDm2: source.minAreaDm2,
    preferredAreaDm2: source.preferredAreaDm2,
    maxAreaDm2: source.maxAreaDm2,
    areaWeightBp: source.areaWeightBp,
    nearFixedArea: source.nearFixedArea,
    requiresExteriorExposure: source.requiresExteriorExposure,
    wetSpace: source.wetSpace,
    circulationSpace: source.circulationSpace,
    geometry: geometry,
  );
}

bool isP9WetServiceUsage(SpaceUsage usage) =>
    usage == SpaceUsage.bathroom ||
    usage == SpaceUsage.wc ||
    usage == SpaceUsage.showerRoom ||
    usage == SpaceUsage.laundry;
