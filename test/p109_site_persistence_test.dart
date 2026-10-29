import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/common_core_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:elecx/src/serialization/project/site_composition_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p109_site_fixture.dart';

void main() {
  final fixture = P109SiteFixture();
  const codec = SiteCompositionAwareCanonicalProjectDocumentCodec();
  late ProjectAggregateRoot composed;
  setUpAll(() => composed = fixture.compose().current);
  test(
      'v17 byte round trip preserves all typed IDs, local geometry, transforms, shared anchors and lineage',
      () {
    final document = codec.encode(p109Snapshot(composed));
    expect(document.schemaVersion, 17);
    final reopened = codec.decode(document);
    expect(jsonEncode(codec.encode(reopened).payload),
        jsonEncode(document.payload));
    expect(
        reopened.aggregate.engineeringMetadata.siteLayout
            .sameAs(composed.engineeringMetadata.siteLayout),
        isTrue);
    expect(
        reopened.aggregate.engineeringMetadata.generationProvenanceRegistry
            .sameAs(composed.engineeringMetadata.generationProvenanceRegistry),
        isTrue);
    expect(reopened.aggregate.stores.spaces.keys.toSet(),
        composed.stores.spaces.keys.toSet());
  });
  test(
      'old documents migrate without guessed placements; older codecs reject lossy writes and disguised new data',
      () {
    const old = CommonCoreAwareCanonicalProjectDocumentCodec();
    final legacy = codec.decode(old.encode(p109Snapshot(fixture.project)));
    expect(legacy.aggregate.engineeringMetadata.siteLayout.isEmpty, isTrue);
    expect(() => old.encode(p109Snapshot(composed)), throwsFormatException);
    final document = codec.encode(p109Snapshot(composed));
    expect(() => old.decode(document), throwsFormatException);
    final disguised =
        ProjectDocument(schemaVersion: 16, payload: document.payload);
    expect(() => codec.decode(disguised), throwsFormatException);
    expect(() => old.decode(disguised), throwsFormatException);
  });
  test(
      'unknown schema/fields, invalid transforms, ownership, overlaps and shared bindings fail closed',
      () {
    final document = codec.encode(p109Snapshot(composed));
    void rejects(void Function(Map<String, dynamic>) edit) {
      final payload =
          jsonDecode(jsonEncode(document.payload)) as Map<String, dynamic>;
      edit(payload['siteLayout'] as Map<String, dynamic>);
      expect(
          () => codec
              .decode(ProjectDocument(schemaVersion: 17, payload: payload)),
          throwsFormatException);
    }

    rejects((root) => root['schemaVersion'] = 2);
    rejects((root) => root['coordinateFrame'] = 'canvas');
    rejects((root) => root['unknown'] = true);
    rejects((root) => root['placements'].first['unknown'] = true);
    rejects((root) => root['placements'].first['xMm'] = 1.5);
    rejects(
        (root) => root['placements'].first['orientationMilliDegrees'] = 45000);
    rejects(
        (root) => root['placements'].first['orientationMilliDegrees'] = 360000);
    rejects((root) => root['placements'].first['buildingId'] = 'foreign');
    rejects((root) => root['placements'].first['widthMm'] = 100);
    rejects((root) => root['placements'].add(root['placements'].first));
    rejects((root) {
      root['placements'].last['xMm'] = root['placements'].first['xMm'];
      root['placements'].last['yMm'] = root['placements'].first['yMm'];
      root['placements'].last['orientationMilliDegrees'] =
          root['placements'].first['orientationMilliDegrees'];
    });
    rejects((root) => root['sharedAnchors'].first['kind'] = 'untyped');
    rejects((root) => root['sharedAnchors'].first['siteId'] = 'foreign');
    rejects((root) => root['sharedAnchors'].first['servedBuildingIds'] = [
          'missing',
          'foreign'
        ]);
    rejects((root) => root['sharedAnchors']
        .first['servedBuildingIds']
        .add(root['sharedAnchors'].first['servedBuildingIds'].first));
    rejects((root) => root['sharedAnchors'].first['servedBuildingIds'] = [
          root['sharedAnchors'].first['servedBuildingIds'].first
        ]);
    rejects((root) => root['sharedAnchors'].first['unknown'] = true);
    rejects((root) => root['sharedAnchors'].add(root['sharedAnchors'].first));
  });
  test(
      'P10-Q11 production Save Reopen Edit Undo Redo Save Reopen keeps other buildings independent',
      () async {
    final directory = await Directory.systemTemp.createTemp('p109-site-');
    addTearDown(() => directory.delete(recursive: true));
    final repository =
        JsonProjectRepository(rootDirectory: directory, codec: codec);
    final owner = CanonicalProjectPersistenceOwner(
        repository: repository, snapshot: p109Snapshot(composed));
    await owner.save();
    final loaded = (await CanonicalProjectPersistenceOwner.load(
        repository: repository, projectId: fixture.projectId))!;
    final session = ProjectMutationSession(loaded.project);
    final registry =
        loaded.project.engineeringMetadata.generationProvenanceRegistry;
    final apartment = registry.manifests.values.first;
    final room =
        loaded.project.stores.zones[apartment.apartmentZoneId]!.spaceIds.first;
    final otherBuildings = loaded.project.stores.buildings.keys
        .where((id) => id != apartment.buildingId)
        .toSet();
    final siblingSpaces = loaded.project.stores.spaces.values
        .where((s) => otherBuildings
            .contains(loaded.project.stores.levels[s.levelId]!.buildingId))
        .toList();
    void accept(ProjectMutationResult result) => loaded.acceptMutation(
        sessionProject: session.current,
        result: result,
        now: DateTime.utc(2026, 10, 29, 2));
    accept(session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: RenameSpaceCommand(
            spaceId: room, name: 'Site custom apartment room')))!);
    accept(session.undo(session.current.version)!);
    accept(session.redo(session.current.version)!);
    await loaded.save();
    final reopened = (await CanonicalProjectPersistenceOwner.load(
        repository: repository, projectId: fixture.projectId))!;
    expect(reopened.project.stores.spaces[room]!.name,
        'Site custom apartment room');
    for (final space in siblingSpaces) {
      expect(reopened.project.stores.spaces[space.id]!.name, space.name);
    }
    expect(
        reopened.project.engineeringMetadata.generationProvenanceRegistry
            .provenanceFor(room)!
            .overriddenProperties,
        contains(GenerationPropertyKey.name));
    expect(
        reopened.project.engineeringMetadata.siteLayout
            .sameAs(composed.engineeringMetadata.siteLayout),
        isTrue);
  });
}
