import 'package:elecx/src/application/project/wizard/apartment/apartment_area_fitter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_catalog_filter.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_generation_diagnostics.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_semantic_validator.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_grammar.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_catalog_production.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9 production pipeline qualification', () {
    test('production catalog is the single qualified latest catalog', () {
      final catalog = P9ProductionApartmentTopologyCatalog.create();

      expect(catalog.catalogVersion, 4);
      expect(catalog.validate(), isEmpty);
      expect(catalog.templates, isNotEmpty);
      expect(
        catalog.templates.every((template) => template.templateVersion == 4),
        isTrue,
      );
    });

    test('1..10 rooms have an area+semantic qualified production path', () {
      final catalog = P9ProductionApartmentTopologyCatalog.create();
      const filter = ApartmentTopologyCatalogFilter();
      final grammar = ApartmentTopologyGrammarEngine();
      const fitter = ApartmentAreaFitter();
      const semanticValidator = ApartmentSemanticValidator();

      for (var roomCount = 1; roomCount <= 10; roomCount++) {
        final request = _request(roomCount, _representativeArea(roomCount));
        final templates = filter.compatibleTemplates(catalog, request);
        expect(
          templates,
          isNotEmpty,
          reason: 'roomCount=$roomCount production catalog coverage',
        );
        final expansion = grammar.expand(request: request, templates: templates);
        expect(
          expansion.drafts,
          isNotEmpty,
          reason: 'roomCount=$roomCount production grammar coverage',
        );

        var semanticQualified = 0;
        for (final draft in expansion.drafts) {
          final area = fitter.fit(draft: draft, request: request);
          if (!area.isValid) {
            continue;
          }
          final template = templates.firstWhere(
            (candidate) =>
                candidate.templateId == draft.templateId &&
                candidate.templateVersion == draft.templateVersion,
          );
          final semantic = semanticValidator.validate(
            fittedDraft: area.fittedDraft!,
            request: request,
            template: template,
          );
          if (semantic.accepted) {
            semanticQualified++;
          }
        }

        expect(
          semanticQualified,
          greaterThan(0),
          reason: 'roomCount=$roomCount must reach P9.6 with a valid draft',
        );
      }
    });

    test('diagnostic matrix is deterministic and never collapses to null', () {
      const diagnostics = ApartmentGenerationDiagnostics();

      for (var roomCount = 1; roomCount <= 10; roomCount++) {
        final request = _request(roomCount, _representativeArea(roomCount));
        final first = diagnostics.inspect(request: request);
        final second = diagnostics.inspect(request: request);

        expect(first.catalogVersion, 4);
        expect(first.entries, isNotEmpty, reason: 'roomCount=$roomCount');
        expect(second.stableSummary, first.stableSummary);
        expect(
          first.entries.every((entry) => entry.codes.every((code) => code.isNotEmpty)),
          isTrue,
          reason: 'roomCount=$roomCount diagnostic codes must be stable',
        );
      }
    });

    test('P9.4 no longer reports geometry-reserve failures', () {
      const diagnostics = ApartmentGenerationDiagnostics();

      for (var roomCount = 1; roomCount <= 10; roomCount++) {
        final report = diagnostics.inspect(
          request: _request(roomCount, _representativeArea(roomCount)),
        );
        final codes = report.entries.expand((entry) => entry.codes).toSet();

        expect(
          codes,
          isNot(contains('p9.area.circulation-geometry-reserve')),
          reason: 'roomCount=$roomCount P9.4 must remain geometry-agnostic',
        );
      }
    });
  });
}

NormalizedApartmentRequest _request(int roomCount, int areaDm2) =>
    const ApartmentRequestNormalizer()
        .normalize(
          ApartmentRequestInput(
            habitableRoomCount: roomCount,
            approximateAreaDm2: areaDm2,
            bathroomCount: 1,
            separateWcCount: 0,
            balconyCount: 0,
            balconyKind: ApartmentBalconyKind.none,
            kitchenMode: ApartmentKitchenMode.separate,
            corridorMode: ApartmentCorridorMode.auto,
            exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
          ),
        )
        .request!;

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
