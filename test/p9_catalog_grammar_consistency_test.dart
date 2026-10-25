import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v3.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.2/P9.3 catalog grammar consistency', () {
    test('every advertised template room count expands without contract failure',
        () {
      final catalog = P9ApartmentTopologyCatalogV3.create();
      for (final template in catalog.templates) {
        final roomCounts = template.constraints.supportedHabitableRoomCounts
            .toList()
          ..sort();
        for (final roomCount in roomCounts) {
          final normalized = const ApartmentRequestNormalizer()
              .normalize(_requestForTemplate(template, roomCount))
              .request!;
          final compatible = const ApartmentTopologyCatalogFilter()
              .compatibleTemplates(catalog, normalized)
              .where((candidate) => candidate.templateId == template.templateId)
              .toList();
          expect(
            compatible,
            isNotEmpty,
            reason:
                '${template.templateId.value} advertises roomCount=$roomCount',
          );

          final expansion = ApartmentTopologyGrammarEngine().expand(
            request: normalized,
            templates: [template],
          );
          expect(
            expansion.failures.map((failure) => failure.code),
            isNot(contains('p9.grammar.invalid-template-contract')),
            reason: '${template.templateId.value} roomCount=$roomCount',
          );
          expect(
            expansion.drafts,
            isNotEmpty,
            reason:
                '${template.templateId.value} roomCount=$roomCount must expand',
          );
        }
      }
    });

    test('1..10 room family coverage is measured after grammar expansion', () {
      final catalog = P9ApartmentTopologyCatalogV3.create();
      for (var roomCount = 1; roomCount <= 10; roomCount++) {
        final normalized = const ApartmentRequestNormalizer()
            .normalize(
              ApartmentRequestInput(
                habitableRoomCount: roomCount,
                approximateAreaDm2: _representativeArea(roomCount),
                bathroomCount: 1,
                separateWcCount: 0,
                balconyCount: 0,
                balconyKind: ApartmentBalconyKind.none,
                kitchenMode: ApartmentKitchenMode.separate,
                corridorMode: ApartmentCorridorMode.auto,
                exteriorExposurePreference:
                    ApartmentExteriorExposurePreference.any,
              ),
            )
            .request!;
        final compatible = const ApartmentTopologyCatalogFilter()
            .compatibleTemplates(catalog, normalized);
        final expansion = ApartmentTopologyGrammarEngine().expand(
          request: normalized,
          templates: compatible,
        );
        final families = expansion.drafts.map((draft) => draft.family).toSet();

        expect(
          families.length,
          greaterThanOrEqualTo(2),
          reason:
              'roomCount=$roomCount families=${families.map((family) => family.code).toList()..sort()}',
        );
      }
    });
  });
}

ApartmentRequestInput _requestForTemplate(
  ApartmentTopologyTemplate template,
  int roomCount,
) {
  final constraints = template.constraints;
  final kitchens = constraints.supportedKitchenModes.toList()
    ..sort((left, right) => left.code.compareTo(right.code));
  final bathrooms = constraints.supportedBathroomCounts.toList()..sort();
  final wcs = constraints.supportedSeparateWcCounts.toList()..sort();
  final balconies = constraints.supportedBalconyCounts.toList()..sort();

  return ApartmentRequestInput(
    habitableRoomCount: roomCount,
    approximateAreaDm2: _boundedArea(
      _representativeArea(roomCount),
      constraints.minInteriorAreaDm2,
      constraints.maxInteriorAreaDm2,
    ),
    bathroomCount: bathrooms.first,
    separateWcCount: wcs.contains(0) ? 0 : wcs.first,
    balconyCount: balconies.contains(0) ? 0 : balconies.first,
    balconyKind: ApartmentBalconyKind.none,
    kitchenMode: kitchens.first,
    corridorMode: ApartmentCorridorMode.auto,
    exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    preferredFamily: template.family,
    preferDayNightSeparation: false,
  );
}

int _boundedArea(int preferred, int minimum, int maximum) {
  if (preferred < minimum) {
    return minimum;
  }
  if (preferred > maximum) {
    return maximum;
  }
  return preferred;
}

int _representativeArea(int roomCount) => switch (roomCount) {
      1 => 4000,
      2 => 5500,
      3 => 7800,
      4 => 10000,
      5 => 13000,
      6 => 16000,
      7 => 19000,
      8 => 22000,
      9 => 25000,
      10 => 28000,
      _ => throw RangeError.range(roomCount, 1, 10),
    };
