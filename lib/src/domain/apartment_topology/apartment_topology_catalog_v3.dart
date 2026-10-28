import '../apartment_topology.dart';
import '../project_space_semantics.dart';
import 'apartment_topology_catalog.dart';
import 'apartment_topology_catalog_v2.dart';
import 'apartment_topology_models.dart';

/// Cross-stage-consistent production catalog for P9.3+.
///
/// V1 remains the historical semantic baseline and V2 records the geometry
/// feasibility correction. V3 versions the corridor multiplicity contract so
/// catalog compatibility cannot advertise a room count that the owning grammar
/// rejects solely because small layouts legitimately require no corridor.
abstract final class P9ApartmentTopologyCatalogV3 {
  static ApartmentTopologyCatalog create() {
    final previous = P9ApartmentTopologyCatalogV2.create();
    final catalog = ApartmentTopologyCatalog(
      catalogVersion: 3,
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
      spaces: [
        for (final space in source.spaces)
          _upgradeSpace(space, family: source.family),
      ],
      adjacencyRules: source.adjacencyRules,
      areaProfile: source.areaProfile,
      circulationPolicy: source.circulationPolicy,
      wetCorePolicy: source.wetCorePolicy,
      variantSeeds: source.variantSeeds,
    );

TopologySpaceSpec _upgradeSpace(
  TopologySpaceSpec source, {
  required ApartmentTopologyFamily family,
}) {
  final corridorMayBeAbsent = source.usage == SpaceUsage.corridor &&
      (family == ApartmentTopologyFamily.linear ||
          family == ApartmentTopologyFamily.corner ||
          family == ApartmentTopologyFamily.euro);

  return TopologySpaceSpec(
    semanticKey: source.semanticKey,
    usage: source.usage,
    type: source.type,
    multiplicityMin: corridorMayBeAbsent ? 0 : source.multiplicityMin,
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
    geometry: source.geometry,
  );
}
