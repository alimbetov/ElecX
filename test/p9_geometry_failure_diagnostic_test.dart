import 'package:elecx/src/application/project/wizard/apartment/apartment_area_fitter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_geometry_stage.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_semantic_validator.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_v4.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P9.6 diagnostic: 2-room separate rejection codes are visible', () {
    _expectGeometryPath(
      const ApartmentRequestInput(
        habitableRoomCount: 2,
        approximateAreaDm2: 5500,
        bathroomCount: 1,
        separateWcCount: 0,
        balconyCount: 0,
        balconyKind: ApartmentBalconyKind.none,
        kitchenMode: ApartmentKitchenMode.separate,
        corridorMode: ApartmentCorridorMode.auto,
        exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
      ),
    );
  });

  test('P9.6 diagnostic: 3-room separate rejection codes are visible', () {
    _expectGeometryPath(
      const ApartmentRequestInput(
        habitableRoomCount: 3,
        approximateAreaDm2: 7800,
        bathroomCount: 1,
        separateWcCount: 0,
        balconyCount: 0,
        balconyKind: ApartmentBalconyKind.none,
        kitchenMode: ApartmentKitchenMode.separate,
        corridorMode: ApartmentCorridorMode.auto,
        exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
      ),
    );
  });

  test('P9.6 diagnostic: 4-room separate rejection codes are visible', () {
    _expectGeometryPath(
      const ApartmentRequestInput(
        habitableRoomCount: 4,
        approximateAreaDm2: 10000,
        bathroomCount: 1,
        separateWcCount: 0,
        balconyCount: 0,
        balconyKind: ApartmentBalconyKind.none,
        kitchenMode: ApartmentKitchenMode.separate,
        corridorMode: ApartmentCorridorMode.auto,
        exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
      ),
    );
  });

  test('P9.6 diagnostic: 2-room open-plan rejection codes are visible', () {
    _expectGeometryPath(
      const ApartmentRequestInput(
        habitableRoomCount: 2,
        approximateAreaDm2: 6000,
        bathroomCount: 1,
        separateWcCount: 0,
        balconyCount: 0,
        balconyKind: ApartmentBalconyKind.none,
        kitchenMode: ApartmentKitchenMode.openPlan,
        corridorMode: ApartmentCorridorMode.auto,
        exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
      ),
    );
  });
}

void _expectGeometryPath(ApartmentRequestInput input) {
  final normalized =
      const ApartmentRequestNormalizer().normalize(input).request!;
  final catalog = P9ApartmentTopologyCatalogV4.create();
  final templates = const ApartmentTopologyCatalogFilter()
      .compatibleTemplates(catalog, normalized);
  final expansion = ApartmentTopologyGrammarEngine().expand(
    request: normalized,
    templates: templates,
  );

  final diagnostics = <String>[];
  var accepted = false;
  for (final draft in expansion.drafts) {
    final fitted = const ApartmentAreaFitter().fit(
      draft: draft,
      request: normalized,
    );
    if (!fitted.isValid) {
      diagnostics.add(
        '${draft.templateId.value}/${draft.variantSeedId}:area:'
        '${fitted.failures.map((failure) => failure.code).join(',')}',
      );
      continue;
    }
    final template = templates.firstWhere(
      (candidate) =>
          candidate.templateId == draft.templateId &&
          candidate.templateVersion == draft.templateVersion,
    );
    final semantic = const ApartmentSemanticValidator().validate(
      fittedDraft: fitted.fittedDraft!,
      request: normalized,
      template: template,
    );
    if (!semantic.accepted) {
      diagnostics.add(
        '${draft.templateId.value}/${draft.variantSeedId}:semantic:'
        '${semantic.blockers.map((issue) => issue.code).join(',')}',
      );
      continue;
    }
    final geometry = const ApartmentGeometryStage().generate(
      fittedDraft: fitted.fittedDraft!,
      semanticValidation: semantic,
      template: template,
      request: normalized,
    );
    if (geometry.accepted) {
      accepted = true;
      break;
    }
    diagnostics.add(
      '${draft.templateId.value}/${draft.variantSeedId}:geometry:'
      '${geometry.failures.map((failure) => failure.code).join(',')}|issues:'
      '${geometry.candidate?.validation.issues.map((issue) => issue.code).join(',') ?? 'no-candidate'}',
    );
  }

  expect(
    accepted,
    isTrue,
    reason: diagnostics.join('\n'),
  );
}
