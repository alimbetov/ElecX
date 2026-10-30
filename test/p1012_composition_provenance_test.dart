import 'package:elecx/src/application/project/wizard/wizard_diff.dart';
import 'dart:math';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/building_level_stack_generator.dart';
import 'package:elecx/src/application/project/wizard/building/building_common_core_composition.dart';
import 'package:elecx/src/application/project/wizard/building/cottage_composition.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'support/p108_tower_fixture.dart';
import 'dart:convert';

import 'package:elecx/src/application/project/project_building_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_service_anchor_commands.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_command.dart';
import 'package:elecx/src/domain/composition_generation_provenance.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_service_anchor.dart';
import 'package:elecx/src/serialization/project/composition_provenance_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:elecx/src/serialization/project/service_anchor_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1011_wizard_fixture.dart';
import 'support/p109_site_fixture.dart';

void main() {
  test(
      'P10-Q18 generated Space Zone Level Building deletion requires explicit dependency order and tombstones exact IDs',
      () {
    final fixture = P108TowerFixture();
    final basis = fixture.project;
    final parameters = BuildingGenerationParameters(
        kind: BuildingCompositionKind.detachedHouse,
        siteId: basis.siteId,
        displayName: 'Single-floor cottage',
        placement: BuildingSitePlacement(
            xMm: 0,
            yMm: 0,
            orientation: ProjectEngineeringNorth.fromDegrees(0)),
        levelStack: const BuildingLevelStackGenerator()
            .residentialParameters(includeRoof: false),
        commonCore: CommonCoreParameters.v2(
            stairCount: 0,
            liftCount: 0,
            serviceShaftCount: 0,
            electricalRiserCount: 0,
            telecomRiserCount: 0,
            corridorWidthMm: 1600,
            includeTechnicalRoom: false,
            serviceSpacePolicy: const CommonServiceSpacePolicy(
                includeCommonHall: false,
                includeElevatorHall: false,
                includeElectricalRoomCandidate: false,
                includeTelecomRoomCandidate: false,
                includeFireControlRoomCandidate: false,
                includeUtilityRoomCandidate: false)),
        serviceAnchors: ServiceAnchorParameters());
    final command = CottageCompositionCommand.create(
        project: basis,
        compositionKey: 'delete.cottage',
        parameters: parameters,
        layout: CottageCompositionLayout(
            footprintWidthMm: 12000,
            footprintDepthMm: 12000,
            commonCore: CommonCoreLayoutParameters(
                originXmm: 1000, originYmm: 5000, corridorLengthMm: 10000)));
    final session = ProjectMutationSession(basis);
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(101218)));
    port.commitPreview(port.preview(command));
    final p = session.current;
    expect(p.stores.spaces, hasLength(1));
    expect(
        () => session.commit(ProjectMutationRequest(
            expectedVersion: p.version,
            command: RemoveLevelCommand(levelId: p.stores.levels.keys.single))),
        throwsA(isA<Exception>()));
    for (final remove in <ProjectCommand>[
      RemoveSpaceCommand(spaceId: p.stores.spaces.keys.single),
      RemoveStructuralZoneCommand(zoneId: p.stores.zones.keys.single),
      RemoveLevelCommand(levelId: p.stores.levels.keys.single),
      RemoveBuildingCommand(buildingId: p.stores.buildings.keys.single)
    ]) {
      final before = p1011Bytes(session.current, includeVersion: false);
      session.commit(ProjectMutationRequest(
          expectedVersion: session.current.version, command: remove));
      final after = p1011Bytes(session.current, includeVersion: false);
      session.undo(session.current.version);
      expect(p1011Bytes(session.current, includeVersion: false), before);
      session.redo(session.current.version);
      expect(p1011Bytes(session.current, includeVersion: false), after);
    }
    final parent = session.current.engineeringMetadata
        .generationProvenanceRegistry.compositions.values.single;
    expect(parent.entities.values.every((e) => e.removed), isTrue);
    CompositionProvenanceIntegrity.validate(session.current);
    expect(
        () => session.commit(ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: CreateBuildingCommand(
                buildingId: p.stores.buildings.keys.single,
                name: 'Illicit ID reuse'))),
        throwsStateError);
  });
  const codec = CompositionProvenanceAwareCanonicalProjectDocumentCodec();
  for (final family in BuildingCompositionWizardFamily.values) {
    test(
        'P10-Q17 ${family.name}: complete parent lineage and field overrides survive v19',
        () {
      final r = P1011WizardRuntime(family: family);
      expect(r.wizard.generatePreview(), isTrue, reason: '${r.wizard.failure}');
      final p = r.wizard.preview!.candidate;
      final registry = p.engineeringMetadata.generationProvenanceRegistry;
      final parent = registry.compositions.values.single;
      expect(parent.children.keys.toSet(),
          registry.levelCompositions.keys.toSet());
      for (final floor in registry.levelCompositions.values) {
        for (final child in floor.apartments.values) {
          expect(
              parent.entities.values.map((e) => e.id).toSet(),
              containsAll(
                  registry.manifests[child.generationId]!.generatedEntityIds));
        }
      }
      final ids = parent.entities.values.map((e) => e.id).toSet();
      expect(
          ids,
          containsAll([
            ...p.stores.buildings.keys,
            ...p.stores.levels.keys,
            ...p.stores.slabs.keys,
            ...p.stores.verticalCores.keys,
            ...p.stores.spaces.keys,
            ...p.index.boundaryEdges.keys,
            ...p.engineeringMetadata.siteLayout.serviceAnchors.keys
          ]));
      final evidence = jsonDecode(parent.canonicalEvidence) as Map;
      expect(evidence['templates'], isNotEmpty);
      final source =
          (r.wizard.generatedCommand as BuildingCompositionWizardCommand)
              .composition;
      expect(evidence['requestFingerprint'], source.requestFingerprint);
      expect(evidence['candidateFingerprint'], source.candidateFingerprint);
      final diff = const WizardDiffProjector()
          .project(before: r.mutations.current, preview: r.wizard.preview!);
      final origin = diff.entries.singleWhere((e) => e.entityId == parent.id);
      expect(origin.category, WizardDiffEntityCategory.provenance);
      expect(origin.title, 'Composition origin');
      expect(origin.title.contains(parent.id.value), isFalse);
      expect(() => parent.entities.clear(), throwsUnsupportedError);
      expect(r.wizard.confirm(), isTrue);
      final building = p.stores.buildings.keys.first;
      final space = p.stores.spaces.keys.first;
      for (final command in <ProjectCommand>[
        RenameBuildingCommand(buildingId: building, name: 'Manual building'),
        RenameSpaceCommand(spaceId: space, name: 'Manual space')
      ]) {
        r.mutations.commit(ProjectMutationRequest(
            expectedVersion: r.mutations.current.version, command: command));
      }
      final updated = r.mutations.current.engineeringMetadata
          .generationProvenanceRegistry.compositions[parent.id]!;
      for (final id in [building, space]) {
        expect(updated.entities.values.singleWhere((e) => e.id == id).overrides,
            {'name'});
      }
      expect(
          updated.entities.values
              .where((e) => e.id != building && e.id != space)
              .every((e) => e.overrides.isEmpty),
          isTrue);
      expect(updated.canonicalEvidence, parent.canonicalEvidence);
      final doc = codec.encode(p109Snapshot(r.mutations.current));
      final loaded = codec.decode(doc);
      expect(jsonEncode(codec.encode(loaded).payload), jsonEncode(doc.payload));
      expect(
          loaded.aggregate.engineeringMetadata.generationProvenanceRegistry
              .sameAs(r.mutations.current.engineeringMetadata
                  .generationProvenanceRegistry),
          isTrue);
    });
    test(
        'P10-Q18 ${family.name}: anchor deletion persists tombstone and exact Undo Redo',
        () {
      final r = P1011WizardRuntime(family: family);
      expect(r.wizard.generatePreview(), isTrue);
      expect(r.wizard.confirm(), isTrue);
      final original = p1011Bytes(r.mutations.current, includeVersion: false);
      final id = r.mutations.current.engineeringMetadata.siteLayout
          .serviceAnchors.keys.first;
      r.mutations.commit(ProjectMutationRequest(
          expectedVersion: r.mutations.current.version,
          command: RemoveServiceAnchorCommand(id)));
      final parent = r.mutations.current.engineeringMetadata
          .generationProvenanceRegistry.compositions.values.single;
      expect(parent.entities.values.singleWhere((e) => e.id == id).removed,
          isTrue);
      final removed = p1011Bytes(r.mutations.current, includeVersion: false);
      final reopened =
          codec.decode(codec.encode(p109Snapshot(r.mutations.current)));
      expect(
          reopened.aggregate.engineeringMetadata.generationProvenanceRegistry
              .sameAs(r.mutations.current.engineeringMetadata
                  .generationProvenanceRegistry),
          isTrue);
      r.mutations.undo(r.mutations.current.version);
      expect(p1011Bytes(r.mutations.current, includeVersion: false), original);
      r.mutations.redo(r.mutations.current.version);
      expect(p1011Bytes(r.mutations.current, includeVersion: false), removed);
    });
  }
  test(
      'v19 strict rejection of malformed, aliased, dangling or downgraded provenance',
      () {
    final r = P1011WizardRuntime();
    expect(r.wizard.generatePreview(), isTrue);
    final snapshot = p109Snapshot(r.wizard.preview!.candidate);
    final doc = codec.encode(snapshot);
    void rejects(void Function(Map<String, dynamic>) edit) {
      final payload =
          jsonDecode(jsonEncode(doc.payload)) as Map<String, dynamic>;
      edit(payload['compositionProvenance'] as Map<String, dynamic>);
      expect(
          () => codec
              .decode(ProjectDocument(schemaVersion: 19, payload: payload)),
          throwsFormatException);
    }

    Map manifest(Map root) => (root['manifests'] as List).first as Map;
    rejects((root) => root['schemaVersion'] = 2);
    rejects((root) => root['unknown'] = true);
    rejects((root) => (root['manifests'] as List).add(manifest(root)));
    rejects((root) => manifest(root)['siteId'] = 'foreign-site');
    rejects((root) => manifest(root)['children'] = {'missing-child': '0' * 64});
    rejects((root) => ((manifest(root)['entities'] as Map).values.first
        as Map)['removed'] = true);
    rejects((root) => ((manifest(root)['entities'] as Map).values.first
        as Map)['overrides'] = ['unknown']);
    rejects((root) => ((manifest(root)['entities'] as Map).values.first
        as Map)['baseline'] = {'name': '0' * 64});
    rejects((root) => manifest(root)['canonicalEvidence'] = '{}');
    const old = ServiceAnchorAwareCanonicalProjectDocumentCodec();
    expect(() => old.encode(snapshot), throwsFormatException);
    expect(() => old.decode(doc), throwsFormatException);
    expect(
        () => codec
            .decode(ProjectDocument(schemaVersion: 18, payload: doc.payload)),
        throwsFormatException);
    final historical = p10HistoricalSnapshot(snapshot);
    final migrated = codec.decode(old.encode(historical));
    expect(
        migrated.aggregate.engineeringMetadata.generationProvenanceRegistry
            .compositions,
        isEmpty);
    expect(migrated.aggregate.stores.spaces.keys.toSet(),
        snapshot.aggregate.stores.spaces.keys.toSet());
  });
  test('anchor name overrides and wall-host changes retain original baseline',
      () {
    final r = P1011WizardRuntime();
    expect(r.wizard.generatePreview(), isTrue);
    expect(r.wizard.confirm(), isTrue);
    final p = r.mutations.current;
    final anchor = p.engineeringMetadata.siteLayout.serviceAnchors.values
        .whereType<ProjectSiteServiceAnchor>()
        .first;
    final parent = p.engineeringMetadata.generationProvenanceRegistry
        .compositions.values.single;
    r.mutations.commit(ProjectMutationRequest(
        expectedVersion: p.version,
        command: UpdateServiceAnchorCommand(
            anchor: ProjectSiteServiceAnchor(
                id: anchor.id,
                siteId: anchor.siteId,
                name: 'Manual area',
                kind: anchor.kind,
                point: anchor.point,
                servedBuildingIds: anchor.servedBuildingIds))));
    final after = r.mutations.current.engineeringMetadata
        .generationProvenanceRegistry.compositions.values.single;
    final entry = after.entities.values.singleWhere((e) => e.id == anchor.id);
    expect(entry.overrides, {'name'});
    expect(entry.baseline,
        parent.entities.values.singleWhere((e) => e.id == anchor.id).baseline);
    final wall = p.engineeringMetadata.siteLayout.serviceAnchors.values
        .whereType<ProjectBoundaryServiceAnchor>()
        .first;
    final binding = p.engineeringMetadata.boundaryHostedObjectRegistry
        .serviceEntryHost(wall.id)!;
    r.mutations.commit(ProjectMutationRequest(
        expectedVersion: r.mutations.current.version,
        command: UpdateServiceAnchorCommand(
            anchor: wall,
            boundaryBinding: ServiceAnchorBoundaryBinding(
                host: binding.host, offsetMm: binding.startOffsetMm! + 100))));
    final finalParent = r.mutations.current.engineeringMetadata
        .generationProvenanceRegistry.compositions.values.single;
    expect(
        finalParent.entities.values
            .singleWhere((e) => e.id == wall.id)
            .overrides,
        {'wallBinding'});
    CompositionProvenanceIntegrity.validate(r.mutations.current);
  });
}
