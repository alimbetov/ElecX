import 'package:elecx/src/serialization/project/composition_provenance_aware_canonical_project_document_codec.dart';
import 'dart:convert';
import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_command.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/site_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_service_anchor.dart';

import 'p108_tower_fixture.dart';
import 'p109_site_fixture.dart';

BuildingCompositionWizardParameters p1011Parameters(
    BuildingCompositionWizardFamily family,
    {bool services = true}) {
  final tower = P108TowerFixture();
  final defaults =
      const BuildingCompositionWizardProvider().defaultsForSite(tower.siteId);
  final List<SiteBuildingSlot> source = switch (family) {
    BuildingCompositionWizardFamily.cottage => [
        SiteBuildingSlot(
            key: 'cottage.main',
            parameters: defaults.buildingParameters!,
            layout: defaults.layout!)
      ],
    BuildingCompositionWizardFamily.residentialTower => [
        SiteBuildingSlot(
            key: 'tower.main',
            parameters: tower.parameters(),
            layout: tower.layout(),
            apartments: tower.requests)
      ],
    BuildingCompositionWizardFamily.residentialComplex =>
      P109SiteFixture().slots,
  };
  final slots = <SiteBuildingSlot>[];
  final inputs = <BuildingWizardServiceAnchorInput>[];
  for (final (index, slot) in source.indexed) {
    final p = slot.parameters;
    final kinds = services && index == 0
        ? BuildingServiceAnchorKind.values.toSet()
        : <BuildingServiceAnchorKind>{};
    final params = BuildingGenerationParameters(
        kind: p.kind,
        siteId: p.siteId,
        displayName: p.displayName,
        placement: p.placement,
        levelStack: p.levelStack,
        commonCore: p.commonCore,
        serviceAnchors: ServiceAnchorParameters(kinds: kinds),
        typicalFloor: p.typicalFloor,
        template: p.template ??
            BuildingTemplateRef(
                id: TemplateId(p.kind == BuildingCompositionKind.detachedHouse
                    ? 'p10.cottage'
                    : 'p10.tower'),
                templateVersion: 1,
                catalogVersion: 1));
    slots.add(SiteBuildingSlot(
        key: slot.key,
        parameters: params,
        layout: slot.layout,
        apartments: slot.apartments));
    for (final kind in kinds) {
      final purpose = ProjectServiceAnchorKind.values.byName(kind.name);
      inputs.add(BuildingWizardServiceAnchorInput(
          key: 'service.${kind.name.toLowerCase()}',
          name: 'Architectural ${kind.name}',
          kind: purpose,
          buildingKey: slot.key,
          offsetMm: 300 + kind.index * 400,
          sitePoint: isServiceEntryKind(purpose)
              ? null
              : BoundaryPointMm(xMm: 900000 + kind.index * 2000, yMm: 900000)));
    }
  }
  return switch (family) {
    BuildingCompositionWizardFamily.cottage =>
      BuildingCompositionWizardParameters.cottage(
          compositionKey: slots.single.key,
          parameters: slots.single.parameters,
          layout: slots.single.layout,
          serviceAnchors: inputs),
    BuildingCompositionWizardFamily.residentialTower =>
      BuildingCompositionWizardParameters.residentialTower(
          compositionKey: slots.single.key,
          parameters: slots.single.parameters,
          layout: slots.single.layout,
          apartments: slots.single.apartments,
          serviceAnchors: inputs),
    BuildingCompositionWizardFamily.residentialComplex =>
      BuildingCompositionWizardParameters.residentialComplex(
          compositionKey: 'site.main',
          buildings: slots,
          serviceAnchors: inputs,
          sharedSiteAnchors: P109SiteFixture().anchors),
  };
}

final class P1011WizardRuntime {
  P1011WizardRuntime(
      {BuildingCompositionWizardFamily family =
          BuildingCompositionWizardFamily.cottage,
      ProjectCommitGuard? guard,
      int seed = 101111}) {
    final basis = P108TowerFixture().project;
    mutations = ProjectMutationSession(basis, commitGuard: guard);
    ids = SecureRandomEntityIdFactory(random: Random(seed));
    port =
        SharedProjectWizardMutationPort(mutations: mutations, idFactory: ids);
    wizard = WizardSession(
        target: SiteWizardTarget(
            projectId: basis.id,
            siteId: basis.siteId,
            baseVersion: basis.version),
        registry:
            WizardProviderRegistry(const [BuildingCompositionWizardProvider()]),
        mutations: port);
    wizard.begin();
    wizard.selectFamily(BuildingCompositionWizardProvider.familyId);
    wizard.updateParameters(p1011Parameters(family));
  }
  late final SecureRandomEntityIdFactory ids;
  late final ProjectMutationSession mutations;
  late final SharedProjectWizardMutationPort port;
  late final WizardSession wizard;
}

String p1011Bytes(ProjectAggregateRoot project, {bool includeVersion = true}) {
  final payload = jsonDecode(jsonEncode(
      const CompositionProvenanceAwareCanonicalProjectDocumentCodec()
          .encode(p109Snapshot(project))
          .payload)) as Map<String, dynamic>;
  if (!includeVersion) (payload['metadata'] as Map).remove('localVersion');
  return jsonEncode(payload);
}
