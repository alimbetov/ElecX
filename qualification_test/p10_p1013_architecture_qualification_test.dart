import 'dart:io';

import 'package:elecx/src/application/project/composition_provenance_command.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/p1011_wizard_fixture.dart';
import '../test/support/p108_tower_fixture.dart';
import 'support/p10_qualification_fixture.dart';

void main() {
  test('P10-Q19 semantic corpus is deterministic for every composition family',
      () {
    expect(p10SemanticParity(), p10SemanticParity());
    final tower = (p10SemanticParity()['cases'] as List)[1] as Map;
    expect((tower['p9Candidates'] as List), hasLength(2));
  });
  test(
      'P10-Q20 production composition has no legacy identity, IO or mutation owner',
      () {
    final files = Directory('lib/src/application/project/wizard/building')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final source = f.readAsStringSync();
      for (final forbidden in [
        "domain/building_composition.dart",
        'cottage_site_builder.dart',
        'residential_tower_builder.dart',
        "'dart:io'",
        'ProjectMutationSession(',
        'SecureRandomEntityIdFactory(',
        'JsonProjectRepository(',
        'servedLevelNumbers'
      ]) {
        expect(source.contains(forbidden), isFalse,
            reason: '${f.path}: $forbidden');
      }
    }
    final p = P108TowerFixture().project;
    for (final family in BuildingCompositionWizardFamily.values) {
      final command = const BuildingCompositionWizardProvider().generateTyped(
          p1011Parameters(family),
          WizardGenerationContext(
              project: p,
              target: SiteWizardTarget(
                  projectId: p.id, siteId: p.siteId, baseVersion: p.version)));
      expect(command, isA<CompositionProvenanceSource>());
    }
  });
}
