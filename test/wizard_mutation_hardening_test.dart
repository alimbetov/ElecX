import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same frozen preview can be committed at most once', () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final port = SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(401)),
    );
    final command = _command(project, name: 'Tower Once');
    final preview = port.preview(command);

    expect(port.commitPreview(preview), isNotNull);
    expect(mutations.undoDepth, 1);
    expect(
      () => port.commitPreview(preview),
      throwsA(isA<ConsumedMutationReservationException>()),
    );
    expect(mutations.undoDepth, 1);
  });

  test('foreign prepared preview is rejected even on the same mutation session',
      () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final first = SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(409)),
    );
    final second = SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(419)),
    );
    final preview = first.preview(_command(project, name: 'Tower Foreign'));

    expect(
      () => second.commitPreview(preview),
      throwsA(isA<ForeignMutationPreviewException>()),
    );
    expect(mutations.current.version, project.version);
    expect(mutations.undoDepth, 0);
  });

  test('parameter edit invalidates prepared preview and reserves fresh ids',
      () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final session = _session(
      project,
      mutations: mutations,
      randomSeed: 421,
    );

    session.begin();
    session.selectFamily(BasicBuildingWizardProvider.familyId);
    session.updateParameters(_parameters('Tower Draft'));
    expect(session.generatePreview(), isTrue);
    final firstId =
        session.preview!.reservation.entityId<BuildingId>('building');

    expect(session.updateParameters(_parameters('Tower Draft')), isTrue);
    expect(session.preview, isNull);
    expect(session.status, WizardSessionStatus.editingParameters);
    expect(session.generatePreview(), isTrue);
    final secondId =
        session.preview!.reservation.entityId<BuildingId>('building');
    expect(secondId, isNot(firstId));
  });

  test(
      'same parameters in a new session are a new intent with fresh identities',
      () {
    final firstProject = _project();
    final secondProject = _project();
    final firstPort = SharedProjectWizardMutationPort(
      mutations: ProjectMutationSession(firstProject),
      idFactory: SecureRandomEntityIdFactory(random: Random(431)),
    );
    final secondPort = SharedProjectWizardMutationPort(
      mutations: ProjectMutationSession(secondProject),
      idFactory: SecureRandomEntityIdFactory(random: Random(433)),
    );
    final first = firstPort.preview(_command(firstProject, name: 'Tower Same'));
    final second =
        secondPort.preview(_command(secondProject, name: 'Tower Same'));

    expect(first.normalizedIntentKey, second.normalizedIntentKey);
    expect(
      first.reservation.entityId<BuildingId>('building'),
      isNot(second.reservation.entityId<BuildingId>('building')),
    );
  });

  test('committed content equals frozen preview and Undo/Redo round-trips it',
      () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final port = SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(439)),
    );
    final preview = port.preview(_command(project, name: 'Tower Frozen'));
    final frozen = _fingerprint(preview.candidate);
    final original = _fingerprint(project);

    final result = port.commitPreview(preview)!;
    expect(_fingerprint(result.mutation.project), frozen);
    expect(_fingerprint(mutations.current), frozen);
    expect(result.mutation.changeSet.afterVersion.value, 1);
    expect(mutations.undoDepth, 1);

    final undo = mutations.undo(mutations.current.version)!;
    expect(_fingerprint(undo.project), original);
    expect(mutations.redoDepth, 1);

    final redo = mutations.redo(mutations.current.version)!;
    expect(_fingerprint(redo.project), frozen);
    expect(mutations.undoDepth, 1);
  });
}

WizardSession _session(
  ProjectAggregateRoot project, {
  required ProjectMutationSession mutations,
  required int randomSeed,
}) =>
    WizardSession(
      target: SiteWizardTarget(
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
      ),
      registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(randomSeed)),
      ),
    );

BasicBuildingWizardParameters _parameters(String name) =>
    BasicBuildingWizardParameters(
      buildingName: name,
      aboveGroundLevelCount: 2,
      basementLevelCount: 1,
      floorToFloorHeightMm: 3000,
      createGroundLevel: true,
    );

ReservedProjectCommand _command(ProjectAggregateRoot project,
    {required String name}) {
  final provider = BasicBuildingWizardProvider();
  final target = SiteWizardTarget(
    projectId: project.id,
    siteId: project.siteId,
    baseVersion: project.version,
  );
  return provider.generateTyped(
    _parameters(name),
    WizardGenerationContext(target: target, project: project),
  );
}

String _fingerprint(ProjectAggregateRoot project) {
  final buildings = project.stores.buildings.values.toList()
    ..sort((left, right) => left.id.value.compareTo(right.id.value));
  final levels = project.stores.levels.values.toList()
    ..sort((left, right) => left.id.value.compareTo(right.id.value));
  return [
    for (final building in buildings)
      'B|${building.id.value}|${building.siteId.value}|${building.name}|'
          '${building.displayOrder}|'
          '${(building.levelIds.map((id) => id.value).toList()..sort()).join(',')}',
    for (final level in levels)
      'L|${level.id.value}|${level.buildingId.value}|${level.name}|'
          '${level.levelNumber}|${level.elevationMm}|${level.kind.name}|'
          '${level.floorToFloorHeightMm}|${level.displayOrder}',
  ].join('\n');
}

ProjectAggregateRoot _project() {
  final projectId = ProjectId('project-hardening');
  final siteId = SiteId('site-hardening');
  return ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: const <BuildingId>{},
        ),
      },
    ),
  );
}
