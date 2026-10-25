import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v4.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.2 catalog v4 circulation geometry feasibility', () {
    test('production catalog v4 is versioned and self-validating', () {
      final catalog = P9ApartmentTopologyCatalogV4.create();

      expect(catalog.catalogVersion, 4);
      expect(catalog.validate(), isEmpty);
      expect(
        catalog.templates.every((template) => template.templateVersion == 4),
        isTrue,
      );
    });

    test('circulation targets can fund the qualified access spine', () {
      final catalog = P9ApartmentTopologyCatalogV4.create();

      for (final template in catalog.templates) {
        final entranceHall = template.spaces.firstWhere(
          (space) => space.usage == SpaceUsage.entranceHall,
        );
        final corridor = template.spaces.firstWhere(
          (space) => space.usage == SpaceUsage.corridor,
        );

        expect(
          entranceHall.preferredAreaDm2,
          500,
          reason: template.templateId.value,
        );
        expect(
          corridor.preferredAreaDm2,
          2200,
          reason: template.templateId.value,
        );
        expect(
          corridor.maxAreaDm2,
          2200,
          reason: template.templateId.value,
        );
        expect(
          corridor.preferredAreaDm2 * 10000,
          greaterThanOrEqualTo(
            corridor.geometry.minShortSideMm *
                (corridor.geometry.minLongSideMm ??
                    corridor.geometry.minShortSideMm),
          ),
          reason: template.templateId.value,
        );
      }
    });
  });
}
