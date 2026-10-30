import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/typical_floor_commands.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/applied_engineering_proposal_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:elecx/src/serialization/project/typical_floor_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p10_typical_floor_fixture.dart';

void main() {
  const codec = TypicalFloorAwareCanonicalProjectDocumentCodec();
  const oldCodec =
      AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec();
  late P10TypicalFloorFixture fixture;
  setUp(() => fixture = P10TypicalFloorFixture.create());

  group('P10.4 canonical persistence', () {
    test(
        'v14 round-trip preserves typed identities, overrides and canonical bytes',
        () {
      final session = fixture.registeredSession();
      session.commit(ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RenameSpaceCommand(
              spaceId: fixture.firstRoomId, name: 'Edited room')));
      final first = codec.encode(p10Snapshot(session.current));
      final reopened = codec.decode(first);
      expect(first.schemaVersion, 14);
      expect(
          reopened.aggregate.engineeringMetadata.generationProvenanceRegistry
              .sameAs(p10Registry(session)),
          isTrue);
      expect(reopened.aggregate.stores.spaces[fixture.firstRoomId]!.name,
          'Edited room');
      expect(jsonEncode(codec.encode(reopened).payload),
          jsonEncode(first.payload));
    });

    test('detached floors remain editable after definition deletion and reopen',
        () {
      final session = fixture.registeredSession();
      for (final instance in fixture.instances) {
        session.commit(ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: DetachTypicalFloorCommand(instance.levelId)));
      }
      session.commit(ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: RemoveTypicalFloorDefinitionCommand(fixture.definition.id)));
      final reopened = codec.decode(codec.encode(p10Snapshot(session.current)));
      final edits = ProjectMutationSession(reopened.aggregate);
      edits.commit(ProjectMutationRequest(
          expectedVersion: edits.current.version,
          command: RenameSpaceCommand(
              spaceId: fixture.firstRoomId, name: 'Detached room')));
      final savedAgain = codec.decode(codec.encode(p10Snapshot(edits.current)));
      expect(savedAgain.aggregate.stores.spaces[fixture.firstRoomId]!.name,
          'Detached room');
      expect(
          savedAgain.aggregate.engineeringMetadata.generationProvenanceRegistry
              .typicalFloorDefinitions,
          isEmpty);
      expect(
          savedAgain.aggregate.engineeringMetadata.generationProvenanceRegistry
              .floorInstances[fixture.firstLevelId]!.entities,
          fixture.instances.first.entities);
    });

    test('legacy v13 migrates with empty typical-floor metadata', () {
      final document = oldCodec.encode(p10Snapshot(fixture.project));
      final reopened = codec.decode(document);
      expect(
          reopened.aggregate.engineeringMetadata.generationProvenanceRegistry
              .hasTypicalFloorLineage,
          isFalse);
      expect(reopened.aggregate.stores.levels.keys,
          fixture.project.stores.levels.keys);
      expect(codec.encode(reopened).schemaVersion, 14);
    });

    test('v13 cannot silently discard new lineage on save or decode', () {
      final session = fixture.registeredSession();
      final snapshot = p10Snapshot(session.current);
      expect(() => oldCodec.encode(snapshot), throwsFormatException);
      final document = codec.encode(snapshot);
      expect(() => oldCodec.decode(document), throwsFormatException);
      final downgraded =
          ProjectDocument(schemaVersion: 13, payload: document.payload);
      expect(() => oldCodec.decode(downgraded), throwsFormatException);
      expect(() => codec.decode(downgraded), throwsFormatException);
    });

    test(
        'unknown versions/fields and foreign or dangling identities fail closed',
        () {
      final document =
          codec.encode(p10Snapshot(fixture.registeredSession().current));
      void rejects(void Function(Map<String, dynamic> lineage) edit) {
        final payload =
            jsonDecode(jsonEncode(document.payload)) as Map<String, dynamic>;
        edit(payload['typicalFloorLineage'] as Map<String, dynamic>);
        expect(
            () => codec
                .decode(ProjectDocument(schemaVersion: 14, payload: payload)),
            throwsFormatException);
      }

      rejects((lineage) => lineage['schemaVersion'] = 2);
      rejects((lineage) => lineage['futureField'] = true);
      rejects((lineage) =>
          (lineage['definitions'] as List).first['futureField'] = true);
      rejects((lineage) =>
          (lineage['instances'] as List).first['futureField'] = true);
      rejects((lineage) => (lineage['instances'] as List).first['entities']
          ['space:room']['value'] = 'missing-space');
      rejects((lineage) => (lineage['instances'] as List).first['entities']
          ['space:room']['kind'] = 'unknown-kind');
      rejects((lineage) => (lineage['instances'] as List)
          .add((lineage['instances'] as List).first));
      rejects((lineage) => (lineage['definitions'] as List)
          .first['patternFingerprint'] = 'invalid');
      rejects((lineage) => (lineage['instances'] as List)
          .first['generationKey'] = ' unnormalized ');
    });

    test(
        'production persistence owner saves, reloads, edits and saves lineage again',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('p10-typical-floor-');
      addTearDown(() => directory.delete(recursive: true));
      final repository =
          JsonProjectRepository(rootDirectory: directory, codec: codec);
      final session = fixture.registeredSession();
      final owner = CanonicalProjectPersistenceOwner(
          snapshot: p10Snapshot(session.current), repository: repository);
      await owner.save();
      final loaded = (await CanonicalProjectPersistenceOwner.load(
          repository: repository, projectId: fixture.project.id))!;
      expect(
          loaded.project.engineeringMetadata.generationProvenanceRegistry
              .sameAs(p10Registry(session)),
          isTrue);
      final edits = ProjectMutationSession(loaded.project);
      final result = edits.commit(ProjectMutationRequest(
          expectedVersion: edits.current.version,
          command: RenameSpaceCommand(
              spaceId: fixture.firstRoomId, name: 'After reopening')))!;
      loaded.acceptMutation(
          sessionProject: edits.current,
          result: result,
          now: DateTime.utc(2026, 10, 29, 1));
      await loaded.save();
      final reopened = (await CanonicalProjectPersistenceOwner.load(
          repository: repository, projectId: fixture.project.id))!;
      expect(reopened.project.stores.spaces[fixture.firstRoomId]!.name,
          'After reopening');
      expect(reopened.project.stores.spaces[fixture.secondRoomId]!.name,
          'Living room');
      expect(
          reopened.project.engineeringMetadata.generationProvenanceRegistry
              .floorInstances[fixture.firstLevelId]!.entities['level'],
          isA<LevelId>());
    });
  });
}
