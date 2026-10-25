import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_diff.dart';
import 'package:elecx/src/application/project/wizard/wizard_preview_scene.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.10 P8 Preview/Diff integration', () {
    test('reserved preview materializes the exact selected canonical geometry',
        () {
      final harness = _Harness.create(seed: 9101);
      final session = harness.session;
      final versionBefore = harness.mutations.current.version;
      final undoBefore = harness.mutations.undoDepth;

      _prepare(session, harness.parameters);
      expect(session.generatePreview(), isTrue, reason: '${session.failure}');

      final preview = session.preview!;
      final candidate = preview.candidate;
      expect(preview.hasChanges, isTrue);
      expect(preview.observedVersion, versionBefore);
      expect(
        preview.normalizedIntentKey,
        contains(harness.card.candidateFingerprint),
      );
      expect(
        preview.normalizedIntentKey,
        contains('p9.apartment.materializer.v1'),
      );
      expect(harness.mutations.current.version, versionBefore);
      expect(harness.mutations.undoDepth, undoBefore);

      final apartmentZones = candidate.stores.zones.values
          .where((zone) => zone.kind == ProjectStructuralZoneKind.apartment)
          .toList();
      expect(apartmentZones, hasLength(1));
      final zone = apartmentZones.single;
      final selected = harness.card.rankedCandidate.candidate;
      final expectedSpaces = [
        ...selected.interiorSpaces,
        ...selected.exteriorAppendages,
      ];
      expect(zone.spaceIds, hasLength(expectedSpaces.length));

      final expectedPolygons = expectedSpaces
          .map((space) => space.polygon.stableSerialization)
          .toList()
        ..sort();
      final actualPolygons = zone.spaceIds.map((spaceId) {
        final topology = candidate.stores.boundaries[spaceId]!;
        return topology.orderedEdgeIds
            .map((edgeId) {
              final point = topology.edges[edgeId]!.start;
              return '${point.xMm},${point.yMm}';
            })
            .join(';');
      }).toList()
        ..sort();
      expect(actualPolygons, expectedPolygons);

      expect(
        candidate.stores.openings.values
            .where((opening) => opening.levelId == harness.fixture.levelId),
        hasLength(selected.openingIntents.length),
      );
      expect(
        candidate.stores.adjacencies.values.where(
          (adjacency) =>
              zone.spaceIds.contains(adjacency.spaceAId) &&
              zone.spaceIds.contains(adjacency.spaceBId),
        ),
        hasLength(
          selected.sharedBoundaries
              .map((boundary) => boundary.pair.stableKey)
              .toSet()
              .length,
        ),
      );

      for (final opening in candidate.stores.openings.values) {
        final hosts = opening.connectedSpaceIds
            .map(
              (spaceId) => candidate.engineeringMetadata
                  .boundaryHostedObjectRegistry
                  .openingHost(opening.id, spaceId),
            )
            .where((host) => host != null)
            .toList();
        expect(hosts, hasLength(1));
        expect(hosts.single!.startOffsetMm, isNotNull);
        expect(hosts.single!.endOffsetMm, isNotNull);
      }
    });

    test('shared WizardDiff exposes apartment semantic categories and grouping',
        () {
      final harness = _Harness.create(seed: 9102);
      _prepare(harness.session, harness.parameters);
      expect(harness.session.generatePreview(), isTrue,
          reason: '${harness.session.failure}');

      final model = const WizardDiffProjector().project(
        before: harness.fixture.project,
        preview: harness.session.preview!,
      );
      final categories = model.entries.map((entry) => entry.category).toSet();
      expect(categories, contains(WizardDiffEntityCategory.level));
      expect(categories, contains(WizardDiffEntityCategory.structuralZone));
      expect(categories, contains(WizardDiffEntityCategory.space));
      expect(categories, contains(WizardDiffEntityCategory.opening));
      expect(categories, contains(WizardDiffEntityCategory.adjacency));
      expect(categories, contains(WizardDiffEntityCategory.boundaryTopology));
      expect(
        model.entries
            .where((entry) =>
                entry.category == WizardDiffEntityCategory.boundaryTopology)
            .every((entry) => entry.title.startsWith('Boundary — ')),
        isTrue,
      );
      expect(
        model.grouped().any((group) =>
            group.key.startsWith('space:') &&
            group.entries.any((entry) =>
                entry.category == WizardDiffEntityCategory.boundaryTopology)),
        isTrue,
      );

      final baseline = model.entries.map((entry) => entry.semanticKey).toList();
      for (var run = 0; run < 10; run++) {
        final repeated = const WizardDiffProjector().project(
          before: harness.fixture.project,
          preview: harness.session.preview!,
        );
        expect(repeated.entries.map((entry) => entry.semanticKey).toList(),
            baseline);
      }
    });

    test('large preview is a canonical projection and inert SVG', () {
      final harness = _Harness.create(seed: 9103);
      _prepare(harness.session, harness.parameters);
      expect(harness.session.generatePreview(), isTrue,
          reason: '${harness.session.failure}');
      final preview = harness.session.preview!;

      final scene = const ApartmentWizardPreviewProjector().project(preview);
      final candidate = preview.candidate;
      final zone = candidate.stores.zones.values.singleWhere(
        (zone) => zone.kind == ProjectStructuralZoneKind.apartment,
      );
      final boundaryIds = <BoundaryEdgeId>{
        for (final spaceId in zone.spaceIds)
          ...candidate.stores.boundaries[spaceId]!.edges.keys,
      };
      final projectedBoundaryIds = scene.elements
          .where((element) => element.role == WizardPreviewRole.boundary)
          .map((element) => element.sourceEntityId)
          .whereType<BoundaryEdgeId>()
          .toSet();
      expect(projectedBoundaryIds, boundaryIds);
      expect(
        scene.elements
            .where((element) => element.role == WizardPreviewRole.spaceRegion),
        hasLength(zone.spaceIds.length),
      );
      expect(
        scene.elements.where((element) =>
            element.role == WizardPreviewRole.opening ||
            element.role == WizardPreviewRole.entryMarker),
        hasLength(candidate.stores.openings.length),
      );

      final svg = const WizardSvgProjector().toSvg(scene);
      expect(svg, contains('<polygon'));
      expect(svg, isNot(contains('<script')));
      expect(svg, isNot(contains('foreignObject')));
      expect(svg, isNot(contains('onload=')));
      expect(svg, isNot(contains('href=')));
    });

    test('Apply commits the frozen preview exactly once and Undo restores before',
        () {
      final harness = _Harness.create(seed: 9104);
      final versionBefore = harness.mutations.current.version;
      final beforeSignature = _canonicalSignature(harness.mutations.current);
      _prepare(harness.session, harness.parameters);
      expect(harness.session.generatePreview(), isTrue,
          reason: '${harness.session.failure}');
      final previewSignature = _canonicalSignature(harness.session.preview!.candidate);

      expect(harness.session.confirm(), isTrue,
          reason: '${harness.session.failure}');
      expect(harness.mutations.current.version.value, versionBefore.value + 1);
      expect(harness.mutations.undoDepth, 1);
      expect(_canonicalSignature(harness.mutations.current), previewSignature);
      expect(harness.session.confirm(), isFalse);
      expect(harness.mutations.current.version.value, versionBefore.value + 1);
      expect(harness.mutations.undoDepth, 1);

      final undo = harness.mutations.undo(harness.mutations.current.version);
      expect(undo, isNotNull);
      expect(_canonicalSignature(harness.mutations.current), beforeSignature);
    });

    test('Cancel after Preview leaves version, stores and Undo unchanged', () {
      final harness = _Harness.create(seed: 9105);
      final version = harness.mutations.current.version;
      final undoDepth = harness.mutations.undoDepth;
      final signature = _canonicalSignature(harness.mutations.current);
      _prepare(harness.session, harness.parameters);
      expect(harness.session.generatePreview(), isTrue,
          reason: '${harness.session.failure}');

      expect(harness.session.cancel(), isTrue);
      expect(harness.session.status, WizardSessionStatus.cancelled);
      expect(harness.mutations.current.version, version);
      expect(harness.mutations.undoDepth, undoDepth);
      expect(_canonicalSignature(harness.mutations.current), signature);
    });

    test('project mutation after Preview makes reserved Apply stale', () {
      final harness = _Harness.create(seed: 9106);
      _prepare(harness.session, harness.parameters);
      expect(harness.session.generatePreview(), isTrue,
          reason: '${harness.session.failure}');

      final external = harness.mutations.commit(
        ProjectMutationRequest(
          expectedVersion: harness.mutations.current.version,
          command: _RenameLevelCommand(harness.fixture.levelId),
        ),
      );
      expect(external, isNotNull);

      expect(harness.session.confirm(), isFalse);
      expect(harness.session.status, WizardSessionStatus.previewBlocked);
      expect(
        harness.session.blockReason,
        WizardPreviewBlockReason.staleBaseVersion,
      );
    });
  });
}

void _prepare(WizardSession session, ApartmentWizardParameters parameters) {
  expect(session.begin(), isTrue);
  expect(session.selectFamily(ApartmentWizardProvider.familyId), isTrue);
  expect(session.updateParameters(parameters), isTrue);
}

final class _Harness {
  _Harness({
    required this.fixture,
    required this.card,
    required this.parameters,
    required this.mutations,
    required this.session,
  });

  factory _Harness.create({required int seed}) {
    final fixture = _fixture();
    final request = _request();
    final generation = const ApartmentCandidateSetService().generate(
      input: request,
      target: fixture.target,
      project: fixture.project,
    );
    expect(generation.accepted, isTrue);
    final set = generation.candidateSet!;
    final card = set.candidates.first;
    final parameters = ApartmentWizardParameters(
      request: request,
      selection: set.selectionFor(card),
    );
    final mutations = ProjectMutationSession(fixture.project);
    final provider = const ApartmentWizardProvider();
    final session = WizardSession(
      target: fixture.target,
      registry: WizardProviderRegistry([provider]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(seed)),
      ),
    );
    return _Harness(
      fixture: fixture,
      card: card,
      parameters: parameters,
      mutations: mutations,
      session: session,
    );
  }

  final _Fixture fixture;
  final ApartmentCandidateCard card;
  final ApartmentWizardParameters parameters;
  final ProjectMutationSession mutations;
  final WizardSession session;
}

ApartmentRequestInput _request() => const ApartmentRequestInput(
      habitableRoomCount: 3,
      approximateAreaDm2: 7800,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 0,
      balconyKind: ApartmentBalconyKind.none,
      kitchenMode: ApartmentKitchenMode.separate,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );

final class _Fixture {
  const _Fixture({
    required this.project,
    required this.target,
    required this.levelId,
  });

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
  final LevelId levelId;
}

_Fixture _fixture() {
  final projectId = ProjectId('p9-preview-project');
  final siteId = SiteId('p9-preview-site');
  final buildingId = BuildingId('p9-preview-building');
  final levelId = LevelId('p9-preview-level');
  final version = LocalProjectVersion(3);
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: {buildingId},
        ),
      },
      buildings: {
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'Building',
          levelIds: {levelId},
        ),
      },
      levels: {
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Level 1',
          levelNumber: 1,
          elevationMm: 3000,
          kind: ProjectLevelKind.residential,
        ),
      },
    ),
  );
  return _Fixture(
    project: project,
    levelId: levelId,
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}

String _canonicalSignature(ProjectAggregateRoot project) {
  final lines = <String>[];
  for (final level in project.stores.levels.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value))) {
    lines.add(
      'level|${level.id.value}|${level.name}|'
      '${(level.zoneIds.map((id) => id.value).toList()..sort()).join(',')}|'
      '${(level.spaceIds.map((id) => id.value).toList()..sort()).join(',')}',
    );
  }
  for (final zone in project.stores.zones.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value))) {
    lines.add(
      'zone|${zone.id.value}|${zone.levelId.value}|${zone.name}|${zone.kind.name}|'
      '${(zone.spaceIds.map((id) => id.value).toList()..sort()).join(',')}',
    );
  }
  for (final space in project.stores.spaces.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value))) {
    lines.add(
      'space|${space.id.value}|${space.levelId.value}|${space.name}|'
      '${space.type.name}|${space.usage.name}',
    );
  }
  for (final entry in project.stores.boundaries.entries.toList()
    ..sort((a, b) => a.key.value.compareTo(b.key.value))) {
    final topology = entry.value;
    lines.add(
      'boundary|${entry.key.value}|${topology.orderedEdgeIds.map((edgeId) {
        final edge = topology.edges[edgeId]!;
        return '${edgeId.value}:${edge.start.xMm},${edge.start.yMm}>'
            '${edge.end.xMm},${edge.end.yMm}';
      }).join(';')}',
    );
  }
  for (final opening in project.stores.openings.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value))) {
    lines.add(
      'opening|${opening.id.value}|${opening.kind.name}|${opening.widthMm}|'
      '${opening.heightMm}|${opening.baseElevationMm}|'
      '${(opening.connectedSpaceIds.map((id) => id.value).toList()..sort()).join(',')}',
    );
  }
  for (final adjacency in project.stores.adjacencies.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value))) {
    lines.add(
      'adj|${adjacency.id.value}|${adjacency.spaceAId.value}|'
      '${adjacency.spaceBId.value}|${adjacency.kind.name}|'
      '${adjacency.openingId?.value ?? ''}',
    );
  }
  final owners = project.engineeringMetadata.boundaryEdgeIdentityRegistry.owners
      .entries
      .toList()
    ..sort((a, b) => a.key.value.compareTo(b.key.value));
  for (final entry in owners) {
    lines.add('edge-owner|${entry.key.value}|${entry.value.value}');
  }
  final hosts = project.engineeringMetadata.boundaryHostedObjectRegistry.references
      .entries
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final entry in hosts) {
    final host = entry.value;
    lines.add(
      'host|${entry.key}|${host.host.spaceId.value}|${host.host.edgeId.value}|'
      '${host.startOffsetMm}|${host.endOffsetMm}',
    );
  }
  return lines.join('\n');
}

final class _RenameLevelCommand implements ProjectCommand {
  const _RenameLevelCommand(this.levelId);

  final LevelId levelId;

  @override
  String get commandType => 'test.rename-level';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final level = current.stores.levels[levelId]!;
    final next = ProjectLevelEntity(
      id: level.id,
      buildingId: level.buildingId,
      name: '${level.name} changed',
      levelNumber: level.levelNumber,
      elevationMm: level.elevationMm,
      kind: level.kind,
      floorToFloorHeightMm: level.floorToFloorHeightMm,
      displayOrder: level.displayOrder,
      zoneIds: level.zoneIds,
      spaceIds: level.spaceIds,
    );
    return ProjectCommandCandidate(
      stores: current.stores.copyWith(
        levels: {...current.stores.levels, levelId: next},
      ),
      affectedEntityIds: {levelId},
    );
  }
}
