import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/project_space_semantics_commands.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/level_composition_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:elecx/src/serialization/project/typical_floor_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p105_composition_fixture.dart';

void main() {
  const codec = LevelCompositionAwareCanonicalProjectDocumentCodec();
  const previous = TypicalFloorAwareCanonicalProjectDocumentCodec();
  late P105CompositionFixture fixture;
  setUpAll(() => fixture = P105CompositionFixture.create());
  ProjectMutationSession compose() {
    final session = ProjectMutationSession(fixture.project);
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10590)));
    port.commitPreview(port.preview(fixture.command()));
    return session;
  }

  test(
      'P10-Q05 schema v15 keeps canonical bytes, parent/child IDs and transforms',
      () {
    final session = compose();
    final first = codec.encode(p105Snapshot(session.current));
    final reopened = codec.decode(first);
    expect(first.schemaVersion, 15);
    expect(
        reopened.aggregate.engineeringMetadata.generationProvenanceRegistry
            .sameAs(session
                .current.engineeringMetadata.generationProvenanceRegistry),
        isTrue);
    expect(
        jsonEncode(codec.encode(reopened).payload), jsonEncode(first.payload));
  });

  test(
      'v14 migration preserves old state and old codec rejects lossy new writes',
      () {
    final migrated =
        codec.decode(previous.encode(p105Snapshot(fixture.project)));
    expect(
        migrated.aggregate.engineeringMetadata.generationProvenanceRegistry
            .levelCompositions,
        isEmpty);
    final snapshot = p105Snapshot(compose().current);
    expect(() => previous.encode(snapshot), throwsFormatException);
    final document = codec.encode(snapshot);
    expect(() => previous.decode(document), throwsFormatException);
    final disguised =
        ProjectDocument(schemaVersion: 14, payload: document.payload);
    expect(() => codec.decode(disguised), throwsFormatException);
    expect(() => previous.decode(disguised), throwsFormatException);
  });

  test(
      'unknown versions/fields, child rebinding and foreign targets fail closed',
      () {
    final document = codec.encode(p105Snapshot(compose().current));
    void rejects(void Function(Map<String, dynamic>) edit) {
      final payload =
          jsonDecode(jsonEncode(document.payload)) as Map<String, dynamic>;
      edit(payload['levelApartmentCompositions'] as Map<String, dynamic>);
      expect(
          () => codec
              .decode(ProjectDocument(schemaVersion: 15, payload: payload)),
          throwsFormatException);
    }

    rejects((root) => root['schemaVersion'] = 2);
    rejects((root) => root['futureField'] = true);
    rejects((root) => root['manifests'].first['futureField'] = true);
    rejects((root) => root['manifests'].first['canonicalRequest'] = '{}');
    rejects((root) =>
        root['manifests'].first['apartments']['a']['transform']['xMm'] += 10);
    rejects(
        (root) => root['manifests'].first['generatorVersion'] = 'p10.future');
    rejects((root) => root['manifests'].first['levelId'] = 'foreign-level');
    rejects((root) => root['manifests'].first['apartments']['a']
            ['generationId'] =
        root['manifests'].first['apartments']['b']['generationId']);
    rejects((root) => root['manifests'].first['apartments']['a']
        ['sourceCandidateFingerprint'] = List.filled(64, '0').join());
    rejects((root) => root['manifests'].first['apartments']['a']
        ['accessSpaceId'] = 'missing-access');
    rejects((root) => root['manifests'].first['apartments']['a']['transform']
        ['clockwiseQuarterTurns'] = 4);
    rejects((root) =>
        root['manifests'].first['apartments']['a']['transform']['xMm'] = 0.5);
    rejects((root) =>
        root['manifests'].first['apartments']['a']['transform']['unknown'] = 1);
    rejects((root) => root['manifests'].add(root['manifests'].first));
  });

  test('removing a composition relation records a tombstone and Undo is exact',
      () {
    final session = compose();
    final before =
        session.current.engineeringMetadata.generationProvenanceRegistry;
    final parent = before.levelCompositions.values.single;
    final relation = parent.generatedAdjacencies.entries.first;
    session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: RemoveAdjacencyCommand(adjacencyId: relation.value)));
    final after = session.current.engineeringMetadata
        .generationProvenanceRegistry.levelCompositions[parent.generationId]!;
    expect(after.removedGenerationKeys, contains(relation.key));
    expect(after.generatedAdjacencies.containsKey(relation.key), isFalse);
    expect(() => codec.decode(codec.encode(p105Snapshot(session.current))),
        returnsNormally);
    session.undo(session.current.version);
    expect(
        session.current.engineeringMetadata.generationProvenanceRegistry
            .sameAs(before),
        isTrue);
  });

  test(
      'P10-Q06 production owner Save-Reopen-Edit-Save-Reopen keeps siblings independent',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('p105-composition-');
    addTearDown(() => directory.delete(recursive: true));
    final repository =
        JsonProjectRepository(rootDirectory: directory, codec: codec);
    final session = compose();
    final owner = CanonicalProjectPersistenceOwner(
        snapshot: p105Snapshot(session.current), repository: repository);
    await owner.save();
    final loaded = (await CanonicalProjectPersistenceOwner.load(
        repository: repository, projectId: fixture.project.id))!;
    final registry =
        loaded.project.engineeringMetadata.generationProvenanceRegistry;
    final parent = registry.levelCompositions.values.single;
    final a = loaded.project.stores
        .zones[parent.apartments['a']!.apartmentZoneId]!.spaceIds.first;
    final b = loaded.project.stores
        .zones[parent.apartments['b']!.apartmentZoneId]!.spaceIds.first;
    final sibling = loaded.project.stores.spaces[b]!.name;
    final edits = ProjectMutationSession(loaded.project);
    final edit = edits.commit(ProjectMutationRequest(
        expectedVersion: edits.current.version,
        command:
            RenameSpaceCommand(spaceId: a, name: 'Custom apartment A room')))!;
    loaded.acceptMutation(
        sessionProject: edits.current,
        result: edit,
        now: DateTime.utc(2026, 10, 29, 1));
    await loaded.save();
    final reopened = (await CanonicalProjectPersistenceOwner.load(
        repository: repository, projectId: fixture.project.id))!;
    expect(reopened.project.stores.spaces[a]!.name, 'Custom apartment A room');
    expect(reopened.project.stores.spaces[b]!.name, sibling);
    expect(
        reopened.project.engineeringMetadata.generationProvenanceRegistry
            .provenanceFor(a)!
            .overriddenProperties,
        contains(GenerationPropertyKey.name));
    expect(
        reopened.project.engineeringMetadata.generationProvenanceRegistry
            .levelCompositions.values.single
            .sameAs(parent),
        isTrue);
  });
}
