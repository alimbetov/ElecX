import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/residential_tower_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p108_tower_fixture.dart';

void main() {
  final fixture = P108TowerFixture();
  Matcher code(String expected) => isA<TowerCompositionException>()
      .having((e) => e.code, 'code', 'p10.tower.$expected');
  test('missing repeated levels, roof and required cores fail closed', () {
    expect(
        () => fixture.command(
            parameters: fixture.parameters(residentialLevels: 1)),
        throwsA(code('repeated-residential-levels-required')));
    expect(() => fixture.command(parameters: fixture.parameters(roof: false)),
        throwsA(code('roof-required')));
    expect(
        () =>
            fixture.command(parameters: fixture.parameters(technicalLevels: 2)),
        throwsA(code('technical-level-count')));
    expect(
        () => fixture.command(
            parameters: fixture.parameters(
                core: CommonCoreParameters.v2(
                    stairCount: 1,
                    liftCount: 1,
                    serviceShaftCount: 0,
                    electricalRiserCount: 0,
                    telecomRiserCount: 0,
                    corridorWidthMm: 2000))),
        throwsA(code('mandatory-cores-required')));
  });
  test(
      'unsupported input contracts, template versions and typical-floor selection fail closed',
      () {
    expect(
        () => fixture.command(
            parameters: fixture.parameters(
                core: CommonCoreParameters(
                    stairCount: 1,
                    liftCount: 1,
                    serviceShaftCount: 1,
                    corridorWidthMm: 2000))),
        throwsA(code('common-core-v2-required')));
    expect(
        () => fixture.command(
            parameters: fixture.parameters(
                template: BuildingTemplateRef(
                    id: TemplateId('p10.tower'),
                    templateVersion: 999,
                    catalogVersion: 1))),
        throwsArgumentError);
    expect(
        () => fixture.command(
            parameters: fixture.parameters(
                typicalFloor: TypicalFloorSelection(
                    definitionKey: 'residential.standard',
                    levelGenerationKeys: ['residential.1']))),
        throwsA(code('typical-floor-selection-mismatch')));
  });
  test(
      'invalid packing and non-grid placement cannot silently clip apartment geometry',
      () {
    expect(
        () => fixture.command(
            layout: fixture.layout(width: 25000, corridorLength: 20000)),
        throwsA(code('apartment-layout-overflow')));
    expect(() => fixture.command(layout: fixture.layout(originY: 4000)),
        throwsA(code('apartment-layout-overflow')));
    expect(() => fixture.command(layout: fixture.layout(width: 12000)),
        throwsA(code('common-layout-outside-footprint')));
    expect(
        () => fixture.command(
            parameters: fixture.parameters(
                placement: BuildingSitePlacement(
                    xMm: 1,
                    yMm: 0,
                    orientation: ProjectEngineeringNorth.fromDegrees(0)))),
        throwsA(code('off-grid-layout')));
    expect(
        () => fixture.command(
            parameters: fixture.parameters(
                placement: BuildingSitePlacement(
                    xMm: 0,
                    yMm: 0,
                    orientation: ProjectEngineeringNorth.fromDegrees(90)))),
        throwsA(code('rotated-site-placement-deferred')));
  });
  test('apartment slots require at least two distinct canonical keys', () {
    final request = fixture.requests.first;
    expect(() => fixture.command(requests: [request]),
        throwsA(code('invalid-apartment-slots')));
    expect(() => fixture.command(requests: [request, request]),
        throwsA(code('invalid-apartment-slots')));
  });
  test('foreign or occupied sites cannot receive an implicit tower replacement',
      () {
    final missing = ProjectAggregateRoot(
        id: fixture.projectId,
        siteId: SiteId('foreign'),
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(sites: {
          SiteId('foreign'): ProjectSiteEntity(
              id: SiteId('foreign'), name: 'Foreign', buildingIds: const []),
        }));
    expect(() => fixture.command(project: missing),
        throwsA(code('empty-site-required')));
    final mutations = ProjectMutationSession(fixture.project);
    final port = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(10890)));
    port.commitPreview(port.preview(fixture.command()));
    expect(() => fixture.command(project: mutations.current),
        throwsA(code('empty-site-required')));
  });
  test(
      'parent reservation rejects missing slots, aliases and existing definition identities',
      () {
    final command = fixture.command();
    final reservation = command
        .reserveIdentities(SecureRandomEntityIdFactory(random: Random(10891)));
    final bad = MutationIdentityReservation.allocate(
        factory: SecureRandomEntityIdFactory(),
        entitySlots: {'invalid': ReservedEntityIdKind.space});
    expect(
        () => command.validateReservation(
            current: fixture.project, reservation: bad),
        throwsStateError);
    expect(
        () => MutationIdentityReservation.combineEntityReservations(
            {'a': reservation, 'b': reservation}),
        throwsArgumentError);
    final shellBuilding = reservation.entityIds.whereType<BuildingId>().single;
    final site = fixture.project.stores.sites[fixture.siteId]!;
    final collision = ProjectAggregateRoot(
        id: fixture.projectId,
        siteId: fixture.siteId,
        version: fixture.project.version,
        stores: fixture.project.stores.copyWith(sites: {
          fixture.siteId: ProjectSiteEntity(
              id: site.id, name: site.name, buildingIds: [shellBuilding]),
        }, buildings: {
          shellBuilding: ProjectBuildingEntity(
              id: shellBuilding,
              siteId: fixture.siteId,
              name: 'Existing',
              levelIds: const [])
        }));
    expect(
        () => command.validateReservation(
            current: collision, reservation: reservation),
        throwsException);
  });
  test('tower supports multiple basements and omitting the technical level',
      () {
    final command = fixture.command(
        parameters: fixture.parameters(basements: 2, technicalLevels: 0));
    final mutations = ProjectMutationSession(fixture.project);
    final port = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(10892)));
    final preview = port.preview(command);
    expect(
        preview.candidate.stores.levels.values
            .where((l) => l.kind == ProjectLevelKind.basement),
        hasLength(2));
    expect(
        preview.candidate.stores.levels.values
            .where((l) => l.kind == ProjectLevelKind.technical),
        isEmpty);
    expect(
        preview.candidate.stores.verticalCores.values
            .every((c) => c.levelIds.length == 5),
        isTrue);
  });
}
