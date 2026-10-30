import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/building_template_catalog.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p10_building_fixture.dart';

void main() {
  group('P10.2 versioned building template catalog', () {
    test('binding records exact template, catalog and request evidence', () {
      final catalog = BuildingTemplateCatalog.residentialV1();
      final request = p10Request(template: p10TemplateRef());
      final binding = catalog.bind(request);
      expect(binding.reference.id, TemplateId('p10.tower'));
      expect(binding.reference.templateVersion, 1);
      expect(binding.reference.catalogVersion, 1);
      expect(binding.catalogFingerprint, catalog.fingerprint);
      expect(binding.templateFingerprint, binding.definition.fingerprint);
      expect(binding.requestFingerprint, request.requestFingerprint);
    });

    test(
      'catalog iteration and template map/set order do not change evidence',
      () {
        final definitions = [
          _definition(),
          _definition(id: 'second', reversed: true),
        ];
        final catalog = BuildingTemplateCatalog(
          version: 1,
          templates: definitions,
        );
        final reordered = BuildingTemplateCatalog(
          version: 1,
          templates: definitions.reversed,
        );
        expect(reordered.fingerprint, catalog.fingerprint);
        expect(
          _definition(reversed: true).fingerprint,
          _definition().fingerprint,
        );
      },
    );

    test('unsupported template/catalog versions have no implicit fallback', () {
      final catalog = BuildingTemplateCatalog.residentialV1();
      for (final reference in [
        p10TemplateRef(id: 'missing'),
        p10TemplateRef(templateVersion: 2),
        p10TemplateRef(catalogVersion: 2),
      ]) {
        expect(
          () => catalog.bind(p10Request(template: reference)),
          throwsArgumentError,
        );
      }
      expect(() => catalog.bind(p10Request()), throwsArgumentError);
    });

    test(
      'incompatible type, core, level count and typical floor fail closed',
      () {
        final catalog = BuildingTemplateCatalog.residentialV1();
        for (final request in [
          p10Request(
            kind: BuildingCompositionKind.detachedHouse,
            template: p10TemplateRef(),
          ),
          p10Request(core: p10Core(lifts: 0), template: p10TemplateRef()),
          p10Request(core: p10Core(stairs: 0), template: p10TemplateRef()),
          p10Request(
            stack: LevelStackParameters(levels: [p10Level()]),
            template: p10TemplateRef(),
          ),
          p10Request(
            typicalFloor: TypicalFloorSelection(
              definitionKey: 'missing',
              levelGenerationKeys: ['residential.1'],
            ),
            template: p10TemplateRef(),
          ),
        ]) {
          expect(() => catalog.bind(request), throwsArgumentError);
        }
      },
    );

    test(
      'role compatibility is checked independently of display numbering',
      () {
        final definition = _definition(allowed: [ProjectLevelKind.ground]);
        final catalog = BuildingTemplateCatalog(
          version: 1,
          templates: [definition],
        );
        expect(
          () =>
              catalog.bind(p10Request(template: p10TemplateRef(id: 'custom'))),
          throwsArgumentError,
        );
      },
    );

    test(
      'published templates and existing bindings cannot be mutated by updates',
      () {
        final mutableDefinitions = [_definition()];
        final catalog = BuildingTemplateCatalog(
          version: 1,
          templates: mutableDefinitions,
        );
        final binding = catalog.bind(
          p10Request(template: p10TemplateRef(id: 'custom')),
        );
        final before = binding.templateFingerprint;
        mutableDefinitions.clear();
        final updated = BuildingTemplateCatalog(
          version: 2,
          templates: [_definition(version: 2)],
        );
        expect(updated.fingerprint, isNot(catalog.fingerprint));
        expect(binding.templateFingerprint, before);
        expect(binding.reference.templateVersion, 1);
        expect(() => catalog.templates.clear(), throwsUnsupportedError);
        expect(
          () => binding.definition.allowedLevelKinds.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => binding.definition.defaultFloorToFloorHeightsMm.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => binding.definition.typicalFloorDefinitionKeys.clear(),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'duplicate identities and invalid published constraints are rejected',
      () {
        expect(
          () => BuildingTemplateCatalog(
            version: 1,
            templates: [_definition(), _definition()],
          ),
          throwsArgumentError,
        );
        expect(
          () => BuildingTemplateCatalog(version: 0, templates: [_definition()]),
          throwsArgumentError,
        );
        expect(
          () => _definition(
            allowed: [ProjectLevelKind.unknown, ProjectLevelKind.ground],
          ),
          throwsArgumentError,
        );
        expect(() => _definition(allowed: []), throwsArgumentError);
      },
    );
  });
}

BuildingTemplateDefinition _definition({
  String id = 'custom',
  int version = 1,
  bool reversed = false,
  List<ProjectLevelKind>? allowed,
}) {
  final roles =
      allowed ?? [ProjectLevelKind.ground, ProjectLevelKind.residential];
  final ordered = reversed ? roles.reversed : roles;
  return BuildingTemplateDefinition(
    id: TemplateId(id),
    version: version,
    kind: BuildingCompositionKind.residentialTower,
    allowedLevelKinds: ordered,
    defaultFloorToFloorHeightsMm: {for (final role in ordered) role: 3000},
    minimumLevels: 1,
    maximumLevels: 231,
    commonCoreDefaults: p10Core(),
    serviceAnchorDefaults: ServiceAnchorParameters(),
    typicalFloorDefinitionKeys:
        reversed ? ['standard.b', 'standard.a'] : ['standard.a', 'standard.b'],
  );
}
