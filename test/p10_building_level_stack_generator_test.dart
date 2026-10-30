import 'dart:math';

import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/building_level_stack_generator.dart';
import 'package:elecx/src/domain/physical_level_order.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p10_building_fixture.dart';

void main() {
  const generator = BuildingLevelStackGenerator();

  group('P10-Q02 generated level identity', () {
    test(
      'all roles receive exact elevations from the datum and adjacent heights',
      () {
        final parameters = generator.residentialParameters(
          basementLevels: 2,
          upperResidentialLevels: 2,
          technicalLevels: 1,
          groundElevationMm: 450,
          basementHeightMm: 2500,
          groundHeightMm: 4000,
          residentialHeightMm: 3200,
          technicalHeightMm: 2000,
        );
        final draft = generator.generate(
          buildingGenerationKey: 'tower.a',
          parameters: parameters,
        );
        expect(draft.levels.map((level) => level.elevationMm), [
          -4550,
          -2050,
          450,
          4450,
          7650,
          10850,
          12850,
        ]);
        expect(draft.levels.map((level) => level.parameters.kind), [
          ProjectLevelKind.basement,
          ProjectLevelKind.basement,
          ProjectLevelKind.ground,
          ProjectLevelKind.residential,
          ProjectLevelKind.residential,
          ProjectLevelKind.technical,
          ProjectLevelKind.roof,
        ]);
        expect(draft.levels.map((level) => level.parameters.code), [
          'B2',
          'B1',
          'G',
          '01',
          '02',
          'T1',
          'RF',
        ]);
      },
    );

    test(
      'physical order follows role/ordinal rather than display numbering',
      () {
        final parameters = LevelStackParameters(
          levels: [
            p10Level(
              key: 'upper',
              ordinal: 1,
              number: -2,
              code: 'B2',
              kind: ProjectLevelKind.residential,
            ),
            p10Level(number: 17, code: 'CUSTOM'),
          ],
        );
        final draft = generator.generate(
          buildingGenerationKey: 'tower.a',
          parameters: parameters,
        );
        expect(draft.levels.map((level) => level.parameters.levelNumber), [
          17,
          -2,
        ]);
        expect(draft.levels.map((level) => level.elevationMm), [0, 3000]);
      },
    );

    test(
        'revalidation reuses reservation IDs and produces canonical physical order',
        () {
      final draft = generator.generate(
        buildingGenerationKey: 'tower.a',
        parameters: generator.residentialParameters(upperResidentialLevels: 2),
      );
      final reservation = MutationIdentityReservation.allocate(
        factory: SecureRandomEntityIdFactory(random: Random(10)),
        entitySlots: draft.reservationSlots,
      );
      final first = draft.materialize(
        buildingId: BuildingId('building-a'),
        reservation: reservation,
      );
      final second = draft.materialize(
        buildingId: BuildingId('building-a'),
        reservation: reservation,
      );
      expect(second.idsByGenerationKey, first.idsByGenerationKey);
      expect(
        first.levels.map((level) => level.id).toSet(),
        hasLength(first.levels.length),
      );
      final ordered = PhysicalLevelOrder.tryResolve(
        first.levels.reversed.map(
          (level) => PhysicalLevelPlacement(
            levelId: level.id,
            buildingId: level.buildingId,
            elevationMm: level.elevationMm,
          ),
        ),
      );
      expect(
        ordered!.map((level) => level.levelId),
        first.levels.map((level) => level.id),
      );
      expect(() => first.levels.clear(), throwsUnsupportedError);
      expect(() => first.idsByGenerationKey.clear(), throwsUnsupportedError);
    });

    test(
      'canonical renumber preserves generated LevelId and owning building',
      () {
        final draft = generator.generate(
          buildingGenerationKey: 'tower.a',
          parameters: LevelStackParameters(levels: p10Levels()),
        );
        final reservation = MutationIdentityReservation.allocate(
          factory: SecureRandomEntityIdFactory(random: Random(12)),
          entitySlots: draft.reservationSlots,
        );
        final materialized = draft.materialize(
          buildingId: BuildingId('building-a'),
          reservation: reservation,
        );
        final project = _project({'building-a': materialized.levels});
        final mutations = ProjectMutationSession(project);
        final id = materialized.idsByGenerationKey['residential.1']!;
        final result = mutations.commit(
          ProjectMutationRequest(
            expectedVersion: project.version,
            command: RenumberLevelCommand(levelId: id, levelNumber: 99),
          ),
        )!;
        final level = result.project.stores.levels[id]!;
        expect(level.id, id);
        expect(level.buildingId, BuildingId('building-a'));
        expect(level.levelNumber, 99);
        expect(level.elevationMm, 3000);
      },
    );

    test('invalid counts/heights and missing reservations fail closed', () {
      expect(
        () => generator.residentialParameters(basementLevels: 31),
        throwsArgumentError,
      );
      expect(
        () => generator.residentialParameters(upperResidentialLevels: 200),
        throwsArgumentError,
      );
      expect(
        () => generator.residentialParameters(technicalLevels: -1),
        throwsArgumentError,
      );
      expect(
        () => generator.residentialParameters(groundHeightMm: 0),
        throwsArgumentError,
      );
      expect(
        () => generator.generate(
          buildingGenerationKey: '',
          parameters: LevelStackParameters(levels: p10Levels()),
        ),
        throwsArgumentError,
      );
      final draft = generator.generate(
        buildingGenerationKey: 'tower.a',
        parameters: LevelStackParameters(levels: p10Levels()),
      );
      final empty = MutationIdentityReservation.allocate(
        factory: SecureRandomEntityIdFactory(),
      );
      expect(
        () => draft.materialize(
          buildingId: BuildingId('building-a'),
          reservation: empty,
        ),
        throwsStateError,
      );
    });
  });

  group('P10-Q03 cross-building repeated display numbers', () {
    test(
        'two buildings share display numbers/codes while all LevelIds stay independent',
        () {
      final parameters = generator.residentialParameters(
        basementLevels: 1,
        upperResidentialLevels: 2,
      );
      final a = generator.generate(
        buildingGenerationKey: 'tower.a',
        parameters: parameters,
      );
      final b = generator.generate(
        buildingGenerationKey: 'tower.b',
        parameters: parameters,
      );
      expect(
        a.reservationSlots.keys.toSet().intersection(
              b.reservationSlots.keys.toSet(),
            ),
        isEmpty,
      );
      final reservation = MutationIdentityReservation.allocate(
        factory: SecureRandomEntityIdFactory(random: Random(20)),
        entitySlots: {...a.reservationSlots, ...b.reservationSlots},
      );
      final levelsA = a.materialize(
        buildingId: BuildingId('building-a'),
        reservation: reservation,
      );
      final levelsB = b.materialize(
        buildingId: BuildingId('building-b'),
        reservation: reservation,
      );
      expect(
        levelsA.levels.map((level) => level.levelNumber),
        levelsB.levels.map((level) => level.levelNumber),
      );
      expect(
        levelsA.idsByGenerationKey.values.toSet().intersection(
              levelsB.idsByGenerationKey.values.toSet(),
            ),
        isEmpty,
      );
      final project = _project({
        'building-a': levelsA.levels,
        'building-b': levelsB.levels,
      });
      expect(project.stores.levels, hasLength(levelsA.levels.length * 2));
    });

    test(
      'deterministic semantic plan does not depend on random persistent IDs',
      () {
        final parameters = generator.residentialParameters(
          upperResidentialLevels: 3,
        );
        final a = generator.generate(
          buildingGenerationKey: 'tower.a',
          parameters: parameters,
        );
        final reordered = LevelStackParameters(
          levels: parameters.levels.reversed,
        );
        final b = generator.generate(
          buildingGenerationKey: 'tower.a',
          parameters: reordered,
        );
        expect(a.semanticFingerprint, b.semanticFingerprint);
        final idsA = a.materialize(
          buildingId: BuildingId('building-a'),
          reservation: MutationIdentityReservation.allocate(
            factory: SecureRandomEntityIdFactory(random: Random(30)),
            entitySlots: a.reservationSlots,
          ),
        );
        final idsB = b.materialize(
          buildingId: BuildingId('building-b'),
          reservation: MutationIdentityReservation.allocate(
            factory: SecureRandomEntityIdFactory(random: Random(31)),
            entitySlots: b.reservationSlots,
          ),
        );
        expect(idsA.idsByGenerationKey, isNot(idsB.idsByGenerationKey));
        expect(a.semanticFingerprint, b.semanticFingerprint);
      },
    );
  });
}

ProjectAggregateRoot _project(Map<String, List<ProjectLevelEntity>> buildings) {
  final siteId = SiteId('site-a');
  return ProjectAggregateRoot(
    id: ProjectId('p10-test'),
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: buildings.keys.map(BuildingId.new),
        ),
      },
      buildings: {
        for (final entry in buildings.entries)
          BuildingId(entry.key): ProjectBuildingEntity(
            id: BuildingId(entry.key),
            siteId: siteId,
            name: entry.key,
            levelIds: entry.value.map((level) => level.id),
          ),
      },
      levels: {
        for (final levels in buildings.values)
          for (final level in levels) level.id: level,
      },
    ),
  );
}
