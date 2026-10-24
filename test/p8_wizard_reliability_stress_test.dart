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
  group('P8 Wizard reliability stress qualification', () {
    test('1000 preview/cancel cycles create zero canonical mutations', () {
      final project = _project('preview-cancel');
      final mutations = ProjectMutationSession(project);

      for (var cycle = 0; cycle < 1000; cycle++) {
        final session = WizardSession(
          target: _target(mutations.current),
          registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
          mutations: SharedProjectWizardMutationPort(
            mutations: mutations,
            idFactory: SecureRandomEntityIdFactory(random: Random(cycle + 1)),
          ),
        );
        expect(session.begin(), isTrue, reason: 'cycle=$cycle');
        expect(
          session.selectFamily(BasicBuildingWizardProvider.familyId),
          isTrue,
          reason: 'cycle=$cycle',
        );
        expect(
          session.updateParameters(
            _parameters('Preview cancel $cycle'),
          ),
          isTrue,
          reason: 'cycle=$cycle',
        );
        expect(session.generatePreview(), isTrue, reason: 'cycle=$cycle');
        expect(session.preview, isNotNull, reason: 'cycle=$cycle');
        expect(session.cancel(), isTrue, reason: 'cycle=$cycle');
      }

      expect(mutations.current.version.value, 0);
      expect(mutations.undoDepth, 0);
      expect(mutations.redoDepth, 0);
      expect(mutations.current.stores.buildings, isEmpty);
      expect(mutations.current.stores.levels, isEmpty);
    });

    test('1000 duplicate Apply attempts never create a duplicate commit', () {
      final project = _project('duplicate-apply');
      final mutations = ProjectMutationSession(project);
      final port = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(9001)),
      );
      final preview = port.preview(_command(project, 'Exactly once'));

      final first = port.commitPreview(preview);
      expect(first, isNotNull);
      final committedFingerprint = _fingerprint(mutations.current);
      expect(mutations.current.version.value, 1);
      expect(mutations.undoDepth, 1);

      for (var attempt = 0; attempt < 1000; attempt++) {
        expect(
          () => port.commitPreview(preview),
          throwsA(isA<ConsumedMutationReservationException>()),
          reason: 'duplicate attempt=$attempt',
        );
        expect(
          _fingerprint(mutations.current),
          committedFingerprint,
          reason: 'duplicate attempt=$attempt changed project',
        );
        expect(mutations.current.version.value, 1);
        expect(mutations.undoDepth, 1);
      }
    });

    test('1000 discarded preview references remain permanently uncommittable',
        () {
      final project = _project('discarded-preview');
      final mutations = ProjectMutationSession(project);
      final port = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(9011)),
      );
      final retained = <ReservedProjectMutationPreview>[];

      for (var cycle = 0; cycle < 1000; cycle++) {
        final preview = port.preview(
          _command(mutations.current, 'Discarded $cycle'),
        );
        retained.add(preview);
        port.discardPreview(preview);
      }

      for (var index = 0; index < retained.length; index++) {
        expect(
          () => port.commitPreview(retained[index]),
          throwsA(isA<DiscardedWizardPreviewException>()),
          reason: 'discarded index=$index',
        );
      }
      expect(mutations.current.version.value, 0);
      expect(mutations.undoDepth, 0);
      expect(mutations.current.stores.buildings, isEmpty);
    });

    test('maximum supported Basic Building cardinality is deterministic', () {
      final firstProject = _project('max-a');
      final secondProject = _project('max-b');
      final provider = BasicBuildingWizardProvider();
      const parameters = BasicBuildingWizardParameters(
        buildingName: 'Maximum Building',
        aboveGroundLevelCount: 200,
        basementLevelCount: 30,
        floorToFloorHeightMm: 3000,
        createGroundLevel: true,
      );

      ReservedProjectMutationPreview generate(
        ProjectAggregateRoot project,
        int seed,
      ) {
        final port = SharedProjectWizardMutationPort(
          mutations: ProjectMutationSession(project),
          idFactory: SecureRandomEntityIdFactory(random: Random(seed)),
        );
        return port.preview(
          provider.generateTyped(
            parameters,
            WizardGenerationContext(
              target: _target(project),
              project: project,
            ),
          ),
        );
      }

      final first = generate(firstProject, 9021);
      final second = generate(secondProject, 9023);
      final firstLevels = first.candidate.stores.levels.values.toList()
        ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));
      final secondLevels = second.candidate.stores.levels.values.toList()
        ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));

      expect(firstLevels, hasLength(231));
      expect(secondLevels, hasLength(231));
      expect(firstLevels.first.levelNumber, -30);
      expect(firstLevels.first.elevationMm, -90000);
      expect(firstLevels[30].levelNumber, 0);
      expect(firstLevels[30].elevationMm, 0);
      expect(firstLevels.last.levelNumber, 200);
      expect(firstLevels.last.elevationMm, 600000);
      expect(
        firstLevels.map((level) => (level.levelNumber, level.elevationMm)),
        secondLevels.map((level) => (level.levelNumber, level.elevationMm)),
      );
      expect(first.normalizedIntentKey, contains('Maximum Building'));
    });
  });
}

BasicBuildingWizardParameters _parameters(String name) =>
    BasicBuildingWizardParameters(
      buildingName: name,
      aboveGroundLevelCount: 2,
      basementLevelCount: 1,
      floorToFloorHeightMm: 3000,
      createGroundLevel: true,
    );

SiteWizardTarget _target(ProjectAggregateRoot project) => SiteWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    );

ReservedProjectCommand _command(ProjectAggregateRoot project, String name) =>
    BasicBuildingWizardProvider().generateTyped(
      _parameters(name),
      WizardGenerationContext(target: _target(project), project: project),
    );

String _fingerprint(ProjectAggregateRoot project) {
  final buildings = project.stores.buildings.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  final levels = project.stores.levels.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  return <String>[
    'v=${project.version.value}',
    for (final building in buildings)
      'B|${building.id.value}|${building.siteId.value}|${building.name}|'
          '${building.displayOrder}|${building.levelIds.map((id) => id.value).join(',')}',
    for (final level in levels)
      'L|${level.id.value}|${level.buildingId.value}|${level.levelNumber}|'
          '${level.elevationMm}|${level.kind.name}|${level.displayOrder}',
  ].join('\n');
}

ProjectAggregateRoot _project(String suffix) {
  final projectId = ProjectId('p8-stress-project-$suffix');
  final siteId = SiteId('p8-stress-site-$suffix');
  return ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site $suffix',
          buildingIds: const <BuildingId>{},
        ),
      },
    ),
  );
}
