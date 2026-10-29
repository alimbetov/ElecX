import 'package:elecx/src/serialization/project/composition_provenance_aware_canonical_project_document_codec.dart';
import 'dart:convert';
import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/project_service_anchor_commands.dart';
import 'package:elecx/src/application/project/project_site_layout_commands.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/service_anchor_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_service_anchor.dart';
import 'package:elecx/src/domain/project_service_anchor_integrity.dart';
import 'package:elecx/src/domain/project_site_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1010_service_anchor_fixture.dart';
import 'support/p109_site_fixture.dart';

void main() {
  late P1010ServiceAnchorFixture fixture;
  setUpAll(() => fixture = P1010ServiceAnchorFixture());
  test(
      'P10.10 materializes all ten architectural purposes without equipment or geometry changes',
      () {
    final session = fixture.compose();
    final after = session.current;
    expect(after.stores, same(fixture.project.stores));
    expect(after.engineeringMetadata.siteLayout.serviceAnchors, hasLength(10));
    expect(
        after.engineeringMetadata.siteLayout.serviceAnchors.values
            .map((a) => a.kind)
            .toSet(),
        ProjectServiceAnchorKind.values.toSet());
    expect(
        after.engineeringMetadata.siteLayout.sharedAnchors.keys.toSet(),
        fixture.project.engineeringMetadata.siteLayout.sharedAnchors.keys
            .toSet());
    expect(
        after.engineeringMetadata.appliedEngineeringProposalRegistry.sameAs(
            fixture.project.engineeringMetadata
                .appliedEngineeringProposalRegistry),
        isTrue);
    expect(
        after.engineeringMetadata.generationProvenanceRegistry
            .copyWith(compositions: {}).sameAs(fixture
                .project.engineeringMetadata.generationProvenanceRegistry
                .copyWith(compositions: {})),
        isTrue);
    for (final anchor
        in after.engineeringMetadata.siteLayout.serviceAnchors.values) {
      final local = ProjectServiceAnchorResolver.position(after, anchor.id);
      final site = ProjectServiceAnchorResolver.position(after, anchor.id,
          siteCoordinates: true);
      if (anchor is ProjectBoundaryServiceAnchor ||
          anchor is ProjectSpaceServiceAnchor) {
        expect(local.buildingId, fixture.buildingId);
        expect(local.levelId, fixture.levelId);
        expect(
            site.point,
            after.engineeringMetadata.siteLayout.placements[fixture.buildingId]!
                .toSite(local.point));
      } else {
        expect(site.frame, ServiceAnchorCoordinateFrame.site);
      }
    }
  });
  test(
      'ID-free plan consumes selected P10 building intent with exact explicit locations',
      () {
    final parameters =
        ServiceAnchorParameters(kinds: BuildingServiceAnchorKind.values);
    final plan = const ServiceAnchorCompositionGenerator().forBuilding(
        project: fixture.project,
        buildingId: fixture.buildingId,
        compositionKey: 'input.services',
        parameters: parameters,
        locations: fixture.locations);
    expect(plan.requests, hasLength(10));
    expect(
        fixture.project.engineeringMetadata.siteLayout.serviceAnchors, isEmpty);
    expect(plan.requests.map((r) => r.kind).toSet(),
        ProjectServiceAnchorKind.values.toSet());
  });
  test(
      'request ordering is normalized and produces identical canonical bytes with one reservation',
      () {
    final a = fixture.command();
    final b = fixture.command(requests: fixture.requests.reversed);
    expect(a.plan.semanticFingerprint, b.plan.semanticFingerprint);
    preview(command) => SharedProjectWizardMutationPort(
            mutations: ProjectMutationSession(fixture.project),
            idFactory: SecureRandomEntityIdFactory(random: Random(101002)))
        .preview(command);
    final x = preview(a);
    final y = preview(b);
    expect(x.reservation.entityIds.whereType<ServiceEntryId>(), hasLength(10));
    expect(
        x.semanticChangeSet.operations
            .whereType<CreateEntityOperation>()
            .where((o) => o.entityId is ServiceEntryId),
        hasLength(10));
    const codec = CompositionProvenanceAwareCanonicalProjectDocumentCodec();
    expect(jsonEncode(codec.encode(p109Snapshot(x.candidate)).payload),
        jsonEncode(codec.encode(p109Snapshot(y.candidate)).payload));
  });
  test('one metadata-only Apply has one Undo and exact-ID host Redo', () {
    final session = fixture.compose();
    expect(session.undoDepth, 1);
    final before = session.current.engineeringMetadata;
    session.undo(session.current.version);
    expect(
        session.current.engineeringMetadata.siteLayout.serviceAnchors, isEmpty);
    expect(
        session.current.engineeringMetadata.boundaryHostedObjectRegistry.sameAs(
            fixture.project.engineeringMetadata.boundaryHostedObjectRegistry),
        isTrue);
    session.redo(session.current.version);
    expect(session.current.engineeringMetadata, before);
  });
  test(
      'renaming one entry preserves its ID and sole physical binding; remove/Undo is exact',
      () {
    final session = fixture.compose();
    final entry = session
        .current.engineeringMetadata.siteLayout.serviceAnchors.values
        .whereType<ProjectBoundaryServiceAnchor>()
        .first;
    final host = session
        .current.engineeringMetadata.boundaryHostedObjectRegistry
        .serviceEntryHost(entry.id)!;
    final result = session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: UpdateServiceAnchorCommand(
            anchor: ProjectBoundaryServiceAnchor(
                id: entry.id,
                siteId: entry.siteId,
                name: 'Main electrical input',
                kind: entry.kind,
                buildingId: entry.buildingId,
                levelId: entry.levelId,
                spaceId: entry.spaceId,
                heightMm: entry.heightMm))))!;
    expect(result.changeSet.engineeringMetadataDiff.siteLayoutChanged, isTrue);
    expect(result.changeSet.entityDiff.isEmpty, isTrue);
    final renamedHost = session
        .current.engineeringMetadata.boundaryHostedObjectRegistry
        .serviceEntryHost(entry.id)!;
    expect(renamedHost.host, host.host);
    expect(renamedHost.startOffsetMm, host.startOffsetMm);
    expect(
        result.changeSet.engineeringMetadataDiff
            .boundaryHostedObjectRegistryChanged,
        isFalse);
    session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: RemoveServiceAnchorCommand(entry.id)));
    expect(
        session.current.engineeringMetadata.boundaryHostedObjectRegistry
            .serviceEntryHost(entry.id),
        isNull);
    session.undo(session.current.version);
    expect(
        session.current.engineeringMetadata.siteLayout.serviceAnchors[entry.id]!
            .name,
        'Main electrical input');
    expect(
        ProjectServiceAnchorResolver.position(session.current, entry.id)
            .boundaryHost,
        host.host);
  });
  test(
      'moving a building transforms live attachment coordinates without rewriting local anchors/hosts',
      () {
    final session = fixture.compose();
    final before = session.current;
    final entry = before.engineeringMetadata.siteLayout.serviceAnchors.values
        .whereType<ProjectBoundaryServiceAnchor>()
        .first;
    final old =
        before.engineeringMetadata.siteLayout.placements[fixture.buildingId]!;
    final location = ProjectServiceAnchorResolver.position(before, entry.id);
    final moved = ProjectBuildingSitePlacement(
        xMm: -200000,
        yMm: -200000,
        orientation: old.orientation,
        widthMm: old.widthMm,
        depthMm: old.depthMm);
    // Use the same production transform command as P10.9.
    final command = UpdateBuildingSitePlacementCommand(
        buildingId: fixture.buildingId, placement: moved);
    session.commit(ProjectMutationRequest(
        expectedVersion: before.version, command: command));
    expect(
        session.current.engineeringMetadata.siteLayout.serviceAnchors[entry.id],
        same(entry));
    expect(
        ProjectServiceAnchorResolver.position(session.current, entry.id,
                siteCoordinates: true)
            .point,
        moved.toSite(location.point));
    expect(
        session.current.engineeringMetadata.boundaryHostedObjectRegistry
            .sameAs(before.engineeringMetadata.boundaryHostedObjectRegistry),
        isTrue);
  });
  test('empty selected input remains a side-effect-free no-op', () {
    final command = fixture.command(requests: []);
    final session = ProjectMutationSession(fixture.project);
    final port = SharedProjectWizardMutationPort(
        mutations: session, idFactory: SecureRandomEntityIdFactory());
    final preview = port.preview(command);
    expect(preview.preview.hasChanges, isFalse);
    expect(port.commitPreview(preview), isNull);
    expect(session.current, same(fixture.project));
  });
  test(
      'appending a P10.9 building retains existing service entities and wall hosts',
      () {
    final session = fixture.compose();
    final before = session.current.engineeringMetadata;
    final site = P109SiteFixture();
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(101004)));
    port.commitPreview(port.preview(site.command(
        project: session.current,
        slots: [site.cottageSlot(key: 'later', x: -100000, y: -100000)],
        anchors: [])));
    expect(session.current.stores.buildings, hasLength(4));
    for (final anchor in before.siteLayout.serviceAnchors.values) {
      expect(
          session
              .current.engineeringMetadata.siteLayout.serviceAnchors[anchor.id],
          same(anchor));
    }
    for (final entry
        in before.boundaryHostedObjectRegistry.references.entries) {
      expect(
          session.current.engineeringMetadata.boundaryHostedObjectRegistry
              .references[entry.key],
          same(entry.value));
    }
    session.undo(session.current.version);
    expect(
        session.current.engineeringMetadata.siteLayout
            .sameAs(before.siteLayout),
        isTrue);
    expect(
        session.current.engineeringMetadata.boundaryHostedObjectRegistry
            .sameAs(before.boundaryHostedObjectRegistry),
        isTrue);
    expect(
        session.current.engineeringMetadata.generationProvenanceRegistry
            .sameAs(before.generationProvenanceRegistry),
        isTrue);
  });
}
