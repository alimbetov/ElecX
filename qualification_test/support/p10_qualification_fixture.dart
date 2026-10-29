import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_command.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/site_composition.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';

import '../../test/support/p1011_wizard_fixture.dart';
import '../../test/support/p108_tower_fixture.dart';

/// One corpus is used by native parity and production lifecycle qualification.
/// The tower contains B2/B1, ground, 16 repeated floors, technical and roof.
BuildingCompositionWizardParameters p10QualificationParameters(
    BuildingCompositionWizardFamily family) {
  final source = p1011Parameters(family);
  if (family == BuildingCompositionWizardFamily.cottage) return source;
  final tower = P108TowerFixture();
  BuildingGenerationParameters extended(BuildingGenerationParameters old) {
    final stack =
        tower.parameters(residentialLevels: 16, basements: 2).levelStack;
    return BuildingGenerationParameters(
        kind: old.kind,
        siteId: old.siteId,
        displayName: old.displayName,
        placement: old.placement,
        levelStack: stack,
        commonCore: old.commonCore,
        serviceAnchors: old.serviceAnchors,
        typicalFloor: old.typicalFloor,
        template: old.template);
  }

  if (family == BuildingCompositionWizardFamily.residentialTower) {
    return BuildingCompositionWizardParameters.residentialTower(
        compositionKey: source.compositionKey,
        parameters: extended(source.buildingParameters!),
        layout: source.layout!,
        apartments: source.towerApartments,
        serviceAnchors: source.serviceAnchors);
  }
  return BuildingCompositionWizardParameters.residentialComplex(
      compositionKey: source.compositionKey,
      buildings: [
        for (final b in source.siteBuildings)
          SiteBuildingSlot(
              key: b.key,
              parameters:
                  b.parameters.kind == BuildingCompositionKind.residentialTower
                      ? extended(b.parameters)
                      : b.parameters,
              layout: b.layout,
              apartments: b.apartments)
      ],
      serviceAnchors: source.serviceAnchors,
      sharedSiteAnchors: source.sharedSiteAnchors);
}

Map<String, Object?> p10SemanticParity() {
  final fixture = P108TowerFixture();
  final project = fixture.project;
  final cases = <Object?>[];
  for (final family in BuildingCompositionWizardFamily.values) {
    final parameters = p10QualificationParameters(family);
    final command = const BuildingCompositionWizardProvider().generateTyped(
            parameters,
            WizardGenerationContext(
                project: project,
                target: SiteWizardTarget(
                    projectId: project.id,
                    siteId: project.siteId,
                    baseVersion: project.version)))
        as BuildingCompositionWizardCommand;
    final c = command.composition;
    cases.add({
      'family': family.name,
      'requestFingerprint': c.requestFingerprint,
      'candidateFingerprint': c.candidateFingerprint,
      'rank': c.deterministicRank,
      'templates': command.generationEvidence.templates,
      'p9Candidates': c.apartmentCandidateFingerprints,
      'buildings': [
        for (final b in c.architecture.plan.buildings)
          {
            'key': b.slot.key,
            'fingerprint': b.fingerprint,
            'placement': b.placement.toCanonicalJson(),
            'levels': b.slot.parameters.levelStack.toCanonicalJson()
          }
      ]
    });
  }
  return {'schema': 'p10.13-semantic-parity-v1', 'cases': cases};
}
