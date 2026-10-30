import 'package:elecx/src/serialization/project/composition_provenance_aware_canonical_project_document_codec.dart';
import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_service_anchor_commands.dart';
import 'package:elecx/src/domain/project_service_anchor.dart';
import 'package:elecx/src/domain/project_service_anchor_integrity.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:elecx/src/serialization/project/site_composition_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1010_service_anchor_fixture.dart';
import 'support/p109_site_fixture.dart';

void main() {
  late P1010ServiceAnchorFixture fixture;
  const codec = CompositionProvenanceAwareCanonicalProjectDocumentCodec();
  setUpAll(() => fixture = P1010ServiceAnchorFixture());
  test(
      'v19 canonical bytes retain all purposes, bindings, shared anchors and P9 lineage',
      () {
    final project = fixture.compose().current;
    final document = codec.encode(p109Snapshot(project));
    final reopened = codec.decode(document);
    expect(document.schemaVersion, 19);
    expect(jsonEncode(codec.encode(reopened).payload),
        jsonEncode(document.payload));
    expect(reopened.aggregate.engineeringMetadata, project.engineeringMetadata);
    expect(reopened.aggregate.stores.spaces.keys.toSet(),
        project.stores.spaces.keys.toSet());
  });
  test(
      'v17 migration preserves existing data and rejects lossy writes or disguised v18 data',
      () {
    const old = SiteCompositionAwareCanonicalProjectDocumentCodec();
    final migrated = codec.decode(
        old.encode(p10HistoricalSnapshot(p109Snapshot(fixture.project))));
    expect(
        migrated.aggregate.engineeringMetadata.generationProvenanceRegistry
            .compositions,
        isEmpty);
    expect(
        migrated.aggregate.engineeringMetadata.siteLayout
            .sameAs(fixture.project.engineeringMetadata.siteLayout),
        isTrue);
    expect(migrated.aggregate.engineeringMetadata.siteLayout.serviceAnchors,
        isEmpty);
    final snapshot = p109Snapshot(fixture.compose().current);
    expect(() => old.encode(snapshot), throwsFormatException);
    final disguised = ProjectDocument(
        schemaVersion: 17, payload: codec.encode(snapshot).payload);
    expect(() => codec.decode(disguised), throwsFormatException);
    expect(() => old.decode(disguised), throwsFormatException);
  });
  test(
      'strict v19 rejects malformed purpose, owner, geometry, identity and wall joins',
      () {
    final document = codec.encode(p109Snapshot(fixture.compose().current));
    void rejects(void Function(Map<String, dynamic>) edit) {
      final payload =
          jsonDecode(jsonEncode(document.payload)) as Map<String, dynamic>;
      edit(payload['serviceAnchors'] as Map<String, dynamic>);
      expect(
          () => codec
              .decode(ProjectDocument(schemaVersion: 19, payload: payload)),
          throwsFormatException);
    }

    dynamic boundary(Map<String, dynamic> r) => (r['anchors'] as List)
        .firstWhere((e) => e['anchor']['hostType'] == 'boundary');
    dynamic room(Map<String, dynamic> r) => (r['anchors'] as List)
        .firstWhere((e) => e['anchor']['hostType'] == 'space');
    dynamic site(Map<String, dynamic> r) => (r['anchors'] as List)
        .firstWhere((e) => e['anchor']['hostType'] == 'site');
    rejects((r) => r['schemaVersion'] = 2);
    rejects((r) => r['unknown'] = true);
    rejects((r) => boundary(r)['unknown'] = true);
    rejects((r) => boundary(r)['anchor']['hostType'] = 'canvas');
    rejects((r) => boundary(r)['anchor']['kind'] = 'generic');
    rejects((r) => boundary(r)['anchor']['kind'] = 'generatorArea');
    rejects((r) => boundary(r)['anchor']['siteId'] = 'foreign');
    rejects((r) => boundary(r)['anchor']['buildingId'] = 'foreign');
    rejects((r) => boundary(r)['anchor']['levelId'] = 'foreign');
    rejects((r) => boundary(r)['anchor']['spaceId'] = 'foreign');
    rejects((r) => boundary(r)['anchor']['heightMm'] = 999999);
    rejects((r) => boundary(r)['anchor']['xMm'] = 100);
    rejects((r) => boundary(r)['wallBinding'] = null);
    rejects((r) => boundary(r)['wallBinding']['edgeId'] = 'missing');
    rejects((r) =>
        boundary(r)['wallBinding']['spaceId'] = fixture.technicalSpaceId.value);
    rejects((r) => boundary(r)['wallBinding']['offsetMm'] = -1);
    rejects((r) => boundary(r)['wallBinding']['offsetMm'] = 999999);
    rejects((r) => boundary(r)['wallBinding']['offsetMm'] = 1.5);
    rejects((r) => room(r)['wallBinding'] = boundary(r)['wallBinding']);
    rejects((r) => room(r)['anchor']['xMm'] = -999990);
    rejects((r) => site(r)['anchor']['xMm'] = 1);
    rejects((r) => site(r)['anchor']['servedBuildingIds'] = ['foreign']);
    rejects((r) => site(r)['anchor']['servedBuildingIds']
        .add(site(r)['anchor']['servedBuildingIds'].first));
    rejects((r) => r['anchors'].add(r['anchors'].first));
    rejects((r) => r['anchors'].first['anchor']['id'] = fixture
        .project.engineeringMetadata.siteLayout.sharedAnchors.keys.first.value);
    rejects((r) {
      final duplicate = jsonDecode(jsonEncode(boundary(r)));
      duplicate['anchor']['id'] = 'other-service-id';
      r['anchors'].add(duplicate);
    });
    expect(
        () => codec.decode(
            ProjectDocument(schemaVersion: 20, payload: document.payload)),
        throwsFormatException);
  });
  test(
      'P10-Q12 production Apply Save Reopen Edit Undo Redo Save Reopen preserves physical identity',
      () async {
    final generated = fixture.compose().current;
    final directory = await Directory.systemTemp.createTemp('p1010-service-');
    addTearDown(() => directory.delete(recursive: true));
    final repository =
        JsonProjectRepository(rootDirectory: directory, codec: codec);
    final owner = CanonicalProjectPersistenceOwner(
        repository: repository, snapshot: p109Snapshot(generated));
    await owner.save();
    final loaded = (await CanonicalProjectPersistenceOwner.load(
        repository: repository, projectId: generated.id))!;
    final session = ProjectMutationSession(loaded.project);
    final entry = loaded
        .project.engineeringMetadata.siteLayout.serviceAnchors.values
        .whereType<ProjectBoundaryServiceAnchor>()
        .first;
    final original =
        ProjectServiceAnchorResolver.position(loaded.project, entry.id);
    void accept(ProjectMutationResult result) => loaded.acceptMutation(
        sessionProject: session.current,
        result: result,
        now: DateTime.utc(2026, 10, 29, 3));
    accept(session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: UpdateServiceAnchorCommand(
            anchor: ProjectBoundaryServiceAnchor(
                id: entry.id,
                siteId: entry.siteId,
                name: 'Edited service input',
                kind: entry.kind,
                buildingId: entry.buildingId,
                levelId: entry.levelId,
                spaceId: entry.spaceId,
                heightMm: entry.heightMm))))!);
    accept(session.undo(session.current.version)!);
    expect(
        session.current.engineeringMetadata.siteLayout.serviceAnchors[entry.id]!
            .name,
        entry.name);
    accept(session.redo(session.current.version)!);
    await loaded.save();
    final reopened = (await CanonicalProjectPersistenceOwner.load(
        repository: repository, projectId: generated.id))!;
    final finalEntry = reopened
        .project.engineeringMetadata.siteLayout.serviceAnchors[entry.id]!;
    expect(finalEntry.name, 'Edited service input');
    final finalPosition =
        ProjectServiceAnchorResolver.position(reopened.project, entry.id);
    expect(finalPosition.boundaryHost, original.boundaryHost);
    expect(finalPosition.point, original.point);
    expect(finalPosition.elevationMm, original.elevationMm);
    expect(
        reopened.project.engineeringMetadata.boundaryHostedObjectRegistry
            .sameAs(generated.engineeringMetadata.boundaryHostedObjectRegistry),
        isTrue);
    expect(
        reopened.project.engineeringMetadata.generationProvenanceRegistry
            .copyWith(compositions: {}).sameAs(generated
                .engineeringMetadata.generationProvenanceRegistry
                .copyWith(compositions: {})),
        isTrue);
    expect(
        reopened.project.engineeringMetadata.siteLayout.serviceAnchors.keys
            .toSet(),
        generated.engineeringMetadata.siteLayout.serviceAnchors.keys.toSet());
  });
}
