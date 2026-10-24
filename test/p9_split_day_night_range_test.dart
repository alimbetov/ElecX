import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v1.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9.3 splitDayNight remains reachable at 10 rooms', () {
    final catalog = P9ApartmentTopologyCatalogV1.create();
    final template = catalog.templates.firstWhere(
      (item) => item.templateId.value == 'p9-split-day-night-separate',
    );
    const normalizer = ApartmentRequestNormalizer();
    final request = normalizer
        .normalize(
          const ApartmentRequestInput(
            habitableRoomCount: 10,
            approximateAreaDm2: 28000,
            bathroomCount: 1,
            separateWcCount: 0,
            balconyCount: 0,
            balconyKind: ApartmentBalconyKind.none,
            kitchenMode: ApartmentKitchenMode.separate,
            corridorMode: ApartmentCorridorMode.auto,
            exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
            preferredFamily: ApartmentTopologyFamily.splitDayNight,
            preferDayNightSeparation: true,
          ),
        )
        .request!;

    final result = ApartmentTopologyGrammarEngine().expand(
      request: request,
      templates: [template],
    );

    expect(result.failures, isEmpty);
    expect(result.drafts, isNotEmpty);
    final draft = result.drafts.first;
    expect(draft.layoutSkeleton.dayZoneKeys, isNotEmpty);
    expect(draft.layoutSkeleton.nightZoneKeys, isNotEmpty);
    expect(
      draft.spaces.where((space) => space.baseSemanticKey == 'corridor'),
      hasLength(1),
    );
  });
}
