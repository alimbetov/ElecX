import 'dart:convert';
import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_navigation_state.dart';
import 'package:elecx/src/application/project/project_navigator_projection.dart';
import 'package:elecx/src/application/project/project_site_layout_commands.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_site_layout.dart';
import 'package:elecx/src/domain/project_site_layout_integrity.dart';
import 'package:elecx/src/serialization/project/site_composition_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p109_site_fixture.dart';

void main() {
  final fixture = P109SiteFixture();
  test(
      'P10-Q11 three independent buildings retain repeated display levels and shared typed anchors',
      () {
    final project = fixture.compose().current;
    expect(project.stores.buildings, hasLength(3));
    final layout = project.engineeringMetadata.siteLayout;
    expect(layout.placements, hasLength(3));
    expect(layout.sharedAnchors, hasLength(2));
    for (final anchor in layout.sharedAnchors.values) {
      expect(anchor.siteId, project.siteId);
      expect(anchor.servedBuildingIds, project.stores.buildings.keys.toSet());
    }
    final floorOnEachBuilding = <LevelId>{};
    for (final building in project.stores.buildings.values) {
      final level = building.levelIds
          .map((id) => project.stores.levels[id]!)
          .singleWhere((l) => l.levelNumber == 1);
      expect(level.name, '01');
      floorOnEachBuilding.add(level.id);
      for (final core in project.index.verticalCoresForBuilding(building.id)) {
        expect(
            project.stores.verticalCores[core]!.levelIds
                .every(building.levelIds.contains),
            isTrue);
      }
    }
    expect(floorOnEachBuilding, hasLength(3));
    expect(project.engineeringMetadata.projectNorth,
        ProjectEngineeringNorth.fromDegrees(37.5));
    expect(project.engineeringMetadata.generationProvenanceRegistry.manifests,
        hasLength(4));
    expect(
        project.engineeringMetadata.generationProvenanceRegistry.floorInstances,
        hasLength(2));
    for (final (index, building) in project.stores.buildings.values.indexed) {
      final otherSpaces = project.stores.spaces.values
          .where((s) =>
              project.stores.levels[s.levelId]!.buildingId != building.id)
          .map((s) => s.id)
          .toSet();
      final own = building.levelIds
          .expand((id) => project.stores.levels[id]!.spaceIds)
          .toSet();
      expect(own.intersection(otherSpaces), isEmpty, reason: 'building $index');
    }
  });
  test(
      'navigator and active editor context resolve repeated floor labels by typed identity',
      () {
    final project = fixture.compose().current;
    final projection = ProjectNavigatorProjection.build(project);
    var navigation = ProjectNavigationState.initial(project);
    for (final building in project.stores.buildings.values) {
      final level = building.levelIds
          .map((id) => project.stores.levels[id]!)
          .singleWhere((l) => l.levelNumber == 1);
      navigation = navigation.activateLevel(project, level.id);
      expect(navigation.activeBuildingId, building.id);
      expect(navigation.activeLevelId, level.id);
      expect(projection.parentById[level.id], building.id);
      expect(projection.parentById[building.id], project.siteId);
    }
  });
  test(
      'equivalent building and anchor ordering produces identical plan and canonical bytes',
      () {
    final basis = fixture.project;
    final a = fixture.command(project: basis);
    final b = fixture.command(
        project: basis,
        slots: fixture.slots.reversed,
        anchors: fixture.anchors.reversed);
    expect(a.plan.semanticFingerprint, b.plan.semanticFingerprint);
    ProjectAggregateRoot preview(command) => SharedProjectWizardMutationPort(
            mutations: ProjectMutationSession(basis),
            idFactory: SecureRandomEntityIdFactory(random: Random(10901)))
        .preview(command)
        .candidate;
    const codec = SiteCompositionAwareCanonicalProjectDocumentCodec();
    expect(jsonEncode(codec.encode(p109Snapshot(preview(a))).payload),
        jsonEncode(codec.encode(p109Snapshot(preview(b))).payload));
    expect(basis.stores.buildings, isEmpty);
  });
  test(
      'one parent Apply has one Undo and restores exact IDs, anchors and lineage on Redo',
      () {
    final session = fixture.compose();
    expect(session.undoDepth, 1);
    final layout = session.current.engineeringMetadata.siteLayout;
    final registry =
        session.current.engineeringMetadata.generationProvenanceRegistry;
    final buildings = session.current.stores.buildings.keys.toSet();
    final spaces = session.current.stores.spaces.keys.toSet();
    session.undo(session.current.version);
    expect(session.current.stores.buildings, isEmpty);
    expect(session.current.engineeringMetadata.siteLayout.isEmpty, isTrue);
    session.redo(session.current.version);
    expect(session.current.stores.buildings.keys.toSet(), buildings);
    expect(session.current.stores.spaces.keys.toSet(), spaces);
    expect(
        session.current.engineeringMetadata.siteLayout.sameAs(layout), isTrue);
    expect(
        session.current.engineeringMetadata.generationProvenanceRegistry
            .sameAs(registry),
        isTrue);
  });
  test(
      'moving/rotating a building changes only its Site transform and records a metadata-only mutation',
      () {
    final session = fixture.compose();
    final before = session.current;
    final entry =
        before.engineeringMetadata.siteLayout.placements.entries.first;
    final transform = ProjectBuildingSitePlacement(
        xMm: -100000,
        yMm: -100000,
        orientation: ProjectEngineeringNorth.fromDegrees(270),
        widthMm: entry.value.widthMm,
        depthMm: entry.value.depthMm);
    final result = session.commit(ProjectMutationRequest(
        expectedVersion: before.version,
        command: UpdateBuildingSitePlacementCommand(
            buildingId: entry.key, placement: transform)))!;
    expect(result.changeSet.engineeringMetadataDiff.siteLayoutChanged, isTrue);
    expect(result.changeSet.entityDiff.isEmpty, isTrue);
    expect(session.current.stores, same(before.stores));
    expect(
        session.current.engineeringMetadata.generationProvenanceRegistry
            .sameAs(before.engineeringMetadata.generationProvenanceRegistry),
        isTrue);
    final space = session.current.stores.spaces.values.firstWhere((s) =>
        session.current.stores.levels[s.levelId]!.buildingId == entry.key);
    final projection = ProjectSiteLayoutProjection(session.current);
    expect(
        projection.spaceOutline(space.id).first,
        transform.toSite(session
            .current.stores.boundaries[space.id]!.edges.values.first.start));
    session.undo(session.current.version);
    expect(
        session.current.engineeringMetadata.siteLayout
            .sameAs(before.engineeringMetadata.siteLayout),
        isTrue);
  });
  test(
      'a new building can be appended without changing existing canonical buildings or local geometry',
      () {
    final session = fixture.compose();
    final before = session.current;
    final command = fixture.command(project: before, slots: [
      fixture.cottageSlot(key: 'cottage.d', x: -100000, y: 0, angle: 270)
    ], anchors: []);
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10903)));
    port.commitPreview(port.preview(command));
    expect(session.current.stores.buildings, hasLength(4));
    for (final entry in before.stores.buildings.entries) {
      expect(session.current.stores.buildings[entry.key], same(entry.value));
    }
    for (final entry in before.stores.boundaries.entries) {
      expect(session.current.stores.boundaries[entry.key], same(entry.value));
    }
    expect(
        session.current.engineeringMetadata.siteLayout.sharedAnchors.keys
            .toSet(),
        before.engineeringMetadata.siteLayout.sharedAnchors.keys.toSet());
  });
}
