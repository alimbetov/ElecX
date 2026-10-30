import 'dart:convert';

import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/project_space_semantics_commands.dart';
import 'package:elecx/src/application/project/typical_floor_commands.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/typical_floor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p10_typical_floor_fixture.dart';

void main() {
  late P10TypicalFloorFixture fixture;
  setUp(() => fixture = P10TypicalFloorFixture.create());
  ProjectMutationResult? commit(
          ProjectMutationSession session, ProjectCommand command) =>
      session.commit(ProjectMutationRequest(
          expectedVersion: session.current.version, command: command));

  group('P10-Q04 typical-floor independence', () {
    test('a definition cannot silently omit canonical floor content', () {
      final entities = <String, EntityId>{'level': fixture.firstLevelId};
      expect(
          () => TypicalFloorPattern.fingerprint(
              stores: fixture.project.stores, entities: entities),
          throwsA(isA<TypicalFloorLineageException>()));
    });
    test(
        'registration is a previewable metadata change and one Undo transaction',
        () {
      final session = ProjectMutationSession(fixture.project);
      final preview = session.preview(ProjectMutationRequest(
          expectedVersion: session.current.version, command: fixture.command));
      expect(preview.entityDiff.isEmpty, isTrue);
      expect(
          preview.engineeringMetadataDiff.generationProvenanceRegistryChanged,
          isTrue);
      expect(p10Registry(session).floorInstances, isEmpty);
      expect(session.undoDepth, 0);
      final result = commit(session, fixture.command)!;
      expect(result.changeSet.entityDiff.isEmpty, isTrue);
      expect(p10Registry(session).floorInstances, hasLength(2));
      expect(session.undoDepth, 1);
      final registered = p10Registry(session);
      session.undo(session.current.version);
      expect(p10Registry(session).floorInstances, isEmpty);
      session.redo(session.current.version);
      expect(p10Registry(session).sameAs(registered), isTrue);
    });

    test(
        'all Level, Zone, Space, Boundary, Opening and adjacency IDs are independent',
        () {
      final a = fixture.instances.first;
      final b = fixture.instances.last;
      expect(a.entities.values.toSet().intersection(b.entities.values.toSet()),
          isEmpty);
      expect(a.entities.values.map(typicalFloorEntityKind).toSet(),
          TypicalFloorEntityKind.values.toSet());
      expect(
          TypicalFloorPattern.fingerprint(
              stores: fixture.project.stores, entities: a.entities),
          TypicalFloorPattern.fingerprint(
              stores: fixture.project.stores, entities: b.entities));
      expect(() => a.entities.clear(), throwsUnsupportedError);
      expect(
          () => fixture.definition.entityKinds.clear(), throwsUnsupportedError);
    });

    test(
        'editing one instance records only its field override and keeps sibling unchanged',
        () {
      final session = fixture.registeredSession();
      final before = p10Registry(session);
      final sibling = jsonEncode(
          before.floorInstances[fixture.secondLevelId]!.toCanonicalJson());
      final boundary = session.current.stores.boundaries[fixture.secondRoomId]!;
      commit(
          session,
          RenameSpaceCommand(
              spaceId: fixture.firstRoomId, name: 'Custom living room'));
      final edited = p10Registry(session).floorInstances[fixture.firstLevelId]!;
      expect(edited.overriddenProperties['space:room'],
          {GenerationPropertyKey.name});
      expect(edited.definitionId, fixture.definition.id);
      expect(session.current.stores.spaces[fixture.secondRoomId]!.name,
          'Living room');
      expect(session.current.stores.boundaries[fixture.secondRoomId],
          same(boundary));
      expect(
          jsonEncode(p10Registry(session)
              .floorInstances[fixture.secondLevelId]!
              .toCanonicalJson()),
          sibling);
      session.undo(session.current.version);
      expect(p10Registry(session).sameAs(before), isTrue);
      session.redo(session.current.version);
      expect(
          p10Registry(session)
              .floorInstances[fixture.firstLevelId]!
              .sameAs(edited),
          isTrue);
    });

    test(
        'renumber preserves LevelId and records a floor-local structural override',
        () {
      final session = fixture.registeredSession();
      commit(session,
          RenumberLevelCommand(levelId: fixture.firstLevelId, levelNumber: 90));
      final instance =
          p10Registry(session).floorInstances[fixture.firstLevelId]!;
      expect(instance.entities['level'], fixture.firstLevelId);
      expect(instance.overriddenProperties['level'],
          {GenerationPropertyKey.levelStructure});
      expect(
          session.current.stores.levels[fixture.secondLevelId]!.levelNumber, 2);
    });

    test(
        'detach and deleting an unused definition preserve every canonical entity',
        () {
      final session = fixture.registeredSession();
      final stores = session.current.stores;
      expect(
          () => commit(session,
              RemoveTypicalFloorDefinitionCommand(fixture.definition.id)),
          throwsA(isA<TypicalFloorLineageException>()));
      for (final instance in fixture.instances) {
        commit(session, DetachTypicalFloorCommand(instance.levelId));
      }
      final detached = p10Registry(session);
      final removed = commit(
          session, RemoveTypicalFloorDefinitionCommand(fixture.definition.id))!;
      expect(removed.changeSet.entityDiff.isEmpty, isTrue);
      expect(session.current.stores, same(stores));
      expect(p10Registry(session).typicalFloorDefinitions, isEmpty);
      expect(
          p10Registry(session)
              .floorInstances
              .values
              .every((floor) => floor.detached),
          isTrue);
      expect(
          p10Registry(session).floorInstances[fixture.firstLevelId]!.entities,
          fixture.instances.first.entities);
      session.undo(session.current.version);
      expect(p10Registry(session).sameAs(detached), isTrue);
      session.redo(session.current.version);
      expect(p10Registry(session).typicalFloorDefinitions, isEmpty);
    });

    test(
        'deletion tombstones the instance slots and Undo restores exact lineage',
        () {
      final session = fixture.registeredSession();
      final mapping = fixture.instances.first.entities;
      commit(
          session,
          RemoveAdjacencyCommand(
              adjacencyId:
                  mapping['adjacency:room-hall']! as SpaceAdjacencyId));
      commit(
          session,
          RemoveOpeningCommand(
              openingId: mapping['opening:door']! as OpeningId));
      final before = p10Registry(session);
      commit(session, RemoveSpaceCommand(spaceId: fixture.firstRoomId));
      final floor = p10Registry(session).floorInstances[fixture.firstLevelId]!;
      expect(floor.entities.containsKey('space:room'), isFalse);
      expect(
          floor.removedGenerationKeys,
          containsAll([
            'space:room',
            'edge:room:0',
            'edge:room:1',
            'edge:room:2',
            'edge:room:3'
          ]));
      expect(
          p10Registry(session)
              .floorInstances[fixture.secondLevelId]!
              .removedGenerationKeys,
          isEmpty);
      session.undo(session.current.version);
      expect(p10Registry(session).sameAs(before), isTrue);
    });

    test('foreign or aliased entity references fail before mutation', () {
      final session = ProjectMutationSession(fixture.project);
      final foreign = fixture.instances.last.copyWith(entities: {
        ...fixture.instances.last.entities,
        'space:room': fixture.firstRoomId
      });
      expect(
          () => commit(
              session,
              RegisterTypicalFloorCommand(
                  definition: fixture.definition,
                  instances: [fixture.instances.first, foreign])),
          throwsA(isA<TypicalFloorLineageException>()));
      expect(session.current, same(fixture.project));
      expect(session.undoDepth, 0);
    });

    test('pattern mismatch and immutable-definition replacement fail closed',
        () {
      final session = ProjectMutationSession(fixture.project);
      commit(
          session,
          RenameSpaceCommand(
              spaceId: fixture.secondRoomId, name: 'Different pattern'));
      final before = session.current;
      expect(() => commit(session, fixture.command),
          throwsA(isA<TypicalFloorLineageException>()));
      expect(session.current, same(before));
      final registered = fixture.registeredSession();
      final definition = fixture.definition;
      final replacement = TypicalFloorDefinition(
          id: definition.id,
          buildingId: definition.buildingId,
          templateId: definition.templateId,
          templateVersion: 2,
          definitionKey: definition.definitionKey,
          patternFingerprint: definition.patternFingerprint,
          entityKinds: definition.entityKinds);
      expect(
          () => commit(
              registered,
              RegisterTypicalFloorCommand(
                  definition: replacement, instances: [])),
          throwsA(isA<TypicalFloorLineageException>()));
    });

    test('stale version cannot detach a linked floor', () {
      final session = fixture.registeredSession();
      expect(
          () => session.commit(ProjectMutationRequest(
              expectedVersion: fixture.project.version,
              command: DetachTypicalFloorCommand(fixture.firstLevelId))),
          throwsA(isA<StaleProjectMutationException>()));
      expect(
          p10Registry(session).floorInstances[fixture.firstLevelId]!.detached,
          isFalse);
    });
  });
}
