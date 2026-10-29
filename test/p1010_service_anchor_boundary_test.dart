import 'package:elecx/src/serialization/project/composition_provenance_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_boundary_topology_migration.dart';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_service_anchor_commands.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_service_anchor.dart';
import 'package:elecx/src/domain/project_service_anchor_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1010_boundary_fixture.dart';
import 'support/p109_site_fixture.dart';

void main() {
  test(
      'explicit rebind preserves the entry ID and rejects invalid edits atomically',
      () {
    final fixture = P1010BoundaryFixture();
    final session = fixture.compose();
    final entry = session
        .current.engineeringMetadata.siteLayout.serviceAnchors.values.single;
    final before = session.current;
    final original = ProjectServiceAnchorResolver.position(before, entry.id);
    expect(
        () => session.commit(ProjectMutationRequest(
            expectedVersion: before.version,
            command: UpdateServiceAnchorCommand(
                anchor: entry,
                boundaryBinding: ServiceAnchorBoundaryBinding(
                    host: fixture.host, offsetMm: 4001)))),
        throwsA(isA<BoundaryHostedRegistryException>().having((e) => e.code,
            'code', BoundaryHostedRegistryIssueCode.geometryOutsideEdge)));
    expect(session.current, same(before));
    expect(session.undoDepth, 1);
    session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: UpdateServiceAnchorCommand(
            anchor: entry,
            boundaryBinding: ServiceAnchorBoundaryBinding(
                host: fixture.host, offsetMm: 1500))));
    expect(
        session.current.engineeringMetadata.siteLayout.serviceAnchors[entry.id],
        same(entry));
    expect(
        ProjectServiceAnchorResolver.position(session.current, entry.id).point,
        const BoundaryPointMm(xMm: 1500, yMm: 0));
    session.undo(session.current.version);
    expect(
        ProjectServiceAnchorResolver.position(session.current, entry.id).point,
        original.point);
    session.redo(session.current.version);
    expect(
        ProjectServiceAnchorResolver.position(session.current, entry.id).point,
        const BoundaryPointMm(xMm: 1500, yMm: 0));
  });
  test(
      'P7 split remaps the sole wall host, preserving entry identity, position and v19 round trip',
      () {
    final fixture = P1010BoundaryFixture();
    final session = fixture.compose();
    final entry = session
        .current.engineeringMetadata.siteLayout.serviceAnchors.values.single;
    final before =
        ProjectServiceAnchorResolver.position(session.current, entry.id);
    final first = fixture.ids.newBoundaryEdgeId();
    final second = fixture.ids.newBoundaryEdgeId();
    final edit = ProjectBoundaryTopologyMigrationService(session).begin(
        spaceId: fixture.spaceId, expectedVersion: session.current.version);
    edit.previewSplitEdge(
        sourceEdgeId: fixture.edgeId,
        splitPoint: const BoundaryPointMm(xMm: 2000, yMm: 0),
        firstResultEdgeId: first,
        secondResultEdgeId: second);
    edit.commit();
    final after =
        ProjectServiceAnchorResolver.position(session.current, entry.id);
    expect(after.point, before.point);
    expect(after.boundaryHost!.edgeId, second);
    expect(
        session.current.engineeringMetadata.boundaryHostedObjectRegistry
            .serviceEntryHost(entry.id)!
            .startOffsetMm,
        500);
    expect(
        session.current.engineeringMetadata.siteLayout.serviceAnchors[entry.id],
        same(entry));
    const codec = CompositionProvenanceAwareCanonicalProjectDocumentCodec();
    final loaded =
        codec.decode(codec.encode(p109Snapshot(session.current))).aggregate;
    expect(ProjectServiceAnchorResolver.position(loaded, entry.id).point,
        before.point);
    session.undo(session.current.version);
    expect(
        ProjectServiceAnchorResolver.position(session.current, entry.id)
            .boundaryHost!
            .edgeId,
        fixture.edgeId);
    session.redo(session.current.version);
    expect(
        ProjectServiceAnchorResolver.position(session.current, entry.id)
            .boundaryHost!
            .edgeId,
        second);
  });
  test('hosted service entry blocks destructive Space and Building deletion',
      () {
    final fixture = P1010BoundaryFixture();
    final session = fixture.compose();
    final before = session.current;
    expect(
        () => session.commit(ProjectMutationRequest(
            expectedVersion: before.version,
            command: RemoveSpaceCommand(spaceId: fixture.spaceId))),
        throwsA(isA<ProjectAuthoringException>().having((e) => e.code, 'code',
            ProjectAuthoringIssueCode.spaceHasBoundaryDependencies)));
    expect(
        () => session.commit(ProjectMutationRequest(
            expectedVersion: before.version,
            command: RemoveBuildingCommand(buildingId: fixture.buildingId))),
        throwsA(isA<ProjectAuthoringException>().having((e) => e.code, 'code',
            ProjectAuthoringIssueCode.buildingHasSiteDependencies)));
    expect(session.current, same(before));
  });
  test('display renumbering retains physical host identity and elevation', () {
    final fixture = P1010BoundaryFixture();
    final session = fixture.compose();
    final entry = session
        .current.engineeringMetadata.siteLayout.serviceAnchors.values.single;
    final before =
        ProjectServiceAnchorResolver.position(session.current, entry.id);
    session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command:
            RenumberLevelCommand(levelId: fixture.levelId, levelNumber: 17)));
    final after =
        ProjectServiceAnchorResolver.position(session.current, entry.id);
    expect(after.levelId, before.levelId);
    expect(after.boundaryHost, before.boundaryHost);
    expect(after.point, before.point);
    expect(after.elevationMm, before.elevationMm);
  });
}
