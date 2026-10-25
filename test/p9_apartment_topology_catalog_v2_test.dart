import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v2.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.2 catalog v2 geometry feasibility', () {
    test('production catalog v2 is versioned and self-validating', () {
      final catalog = P9ApartmentTopologyCatalogV2.create();

      expect(catalog.catalogVersion, 2);
      expect(catalog.validate(), isEmpty);
      expect(
        catalog.templates.every((template) => template.templateVersion == 2),
        isTrue,
      );
    });

    test('wet service minima are realizable by declared dimensions', () {
      final catalog = P9ApartmentTopologyCatalogV2.create();
      final wetSpaces = catalog.templates
          .expand((template) => template.spaces)
          .where((space) => space.wetSpace)
          .toList();

      expect(wetSpaces, isNotEmpty);
      for (final space in wetSpaces) {
        final geometry = space.geometry;
        final longSide = geometry.minLongSideMm ?? geometry.minShortSideMm;
        expect(
          space.minAreaDm2 * 10000,
          greaterThanOrEqualTo(geometry.minShortSideMm * longSide),
          reason: space.semanticKey,
        );
        expect(geometry.minShortSideMm, 900);
        expect(geometry.minLongSideMm, 1200);
      }
    });

    test('catalog v2 rejects area smaller than minimum dimensions', () {
      final production = P9ApartmentTopologyCatalogV2.create();
      final source = production.templates.first;
      final original = source.spaces.first;
      final impossible = TopologySpaceSpec(
        semanticKey: original.semanticKey,
        usage: original.usage,
        type: original.type,
        multiplicityMin: original.multiplicityMin,
        multiplicityMax: original.multiplicityMax,
        areaParticipation: original.areaParticipation,
        minAreaDm2: 100,
        preferredAreaDm2: original.preferredAreaDm2,
        maxAreaDm2: original.maxAreaDm2,
        areaWeightBp: original.areaWeightBp,
        nearFixedArea: original.nearFixedArea,
        requiresExteriorExposure: original.requiresExteriorExposure,
        wetSpace: original.wetSpace,
        circulationSpace: original.circulationSpace,
        geometry: original.geometry,
      );
      final invalidTemplate = ApartmentTopologyTemplate(
        templateId: source.templateId,
        templateVersion: source.templateVersion,
        family: source.family,
        stableOrder: source.stableOrder,
        constraints: source.constraints,
        spaces: [
          impossible,
          ...source.spaces.skip(1),
        ],
        adjacencyRules: source.adjacencyRules,
        areaProfile: source.areaProfile,
        circulationPolicy: source.circulationPolicy,
        wetCorePolicy: source.wetCorePolicy,
        variantSeeds: source.variantSeeds,
      );
      final invalidCatalog = ApartmentTopologyCatalog(
        catalogVersion: 2,
        templates: [invalidTemplate],
      );

      expect(
        invalidCatalog.validate().map((issue) => issue.code),
        contains('p9.catalog.infeasible-space-geometry-area'),
      );
    });
  });
}
