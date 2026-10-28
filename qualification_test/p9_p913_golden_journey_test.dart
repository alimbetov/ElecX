import 'dart:convert';
import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_diff.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/serialization/project/generation_provenance_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'GJ-01 exact apartment journey Preview Apply Undo Redo Save Reopen override',
      () {
    final fixture = _fixture();
    const service = ApartmentCandidateSetService();
    final generated = service.generate(
      input: _goldenRequest,
      target: fixture.target,
      project: fixture.project,
    );

    expect(generated.accepted, isTrue, reason: '${generated.failures}');
    final set = generated.candidateSet!;
    expect(set.candidates.length, inInclusiveRange(3, 6));
    final selected = set.recommendedCandidate;
    final parameters = ApartmentWizardParameters(
      request: _goldenRequest,
      selection: set.selectionFor(selected),
    );
    final mutations = ProjectMutationSession(fixture.project);
    final session = WizardSession(
      target: fixture.target,
      registry: WizardProviderRegistry(const [ApartmentWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(9130101)),
      ),
    );

    final beforeState = _canonicalStateSignature(mutations.current);
    final versionBefore = mutations.current.version;
    final undoBefore = mutations.undoDepth;

    expect(session.begin(), isTrue);
    expect(session.selectFamily(ApartmentWizardProvider.familyId), isTrue);
    expect(session.updateParameters(parameters), isTrue);
    expect(session.generatePreview(), isTrue, reason: '${session.failure}');

    final preview = session.preview!;
    expect(preview.observedVersion, versionBefore);
    expect(preview.hasChanges, isTrue);
    expect(
        preview.normalizedIntentKey, contains(selected.candidateFingerprint));
    expect(mutations.current.version, versionBefore);
    expect(mutations.undoDepth, undoBefore);

    final diff = const WizardDiffProjector().project(
      before: mutations.current,
      preview: preview,
    );
    expect(diff.entries, isNotEmpty);

    final previewState = _canonicalStateSignature(preview.candidate);
    final previewOpeningIds = preview.candidate.stores.openings.keys.toSet();
    final previewBoundaryIds = <BoundaryEdgeId>{
      for (final topology in preview.candidate.stores.boundaries.values)
        ...topology.edges.keys,
    };
    expect(previewOpeningIds, isNotEmpty);
    expect(previewBoundaryIds, isNotEmpty);

    expect(session.confirm(), isTrue, reason: '${session.failure}');
    expect(mutations.current.version.value, versionBefore.value + 1);
    expect(mutations.undoDepth, undoBefore + 1);
    expect(_canonicalStateSignature(mutations.current), previewState);
    expect(mutations.current.stores.openings.keys.toSet(), previewOpeningIds);
    expect(
      <BoundaryEdgeId>{
        for (final topology in mutations.current.stores.boundaries.values)
          ...topology.edges.keys,
      },
      previewBoundaryIds,
    );

    final appliedRegistry =
        mutations.current.engineeringMetadata.generationProvenanceRegistry;
    expect(appliedRegistry.manifests, hasLength(1));
    final appliedGenerationId = appliedRegistry.manifests.keys.single;

    final undo = mutations.undo(mutations.current.version);
    expect(undo, isNotNull);
    expect(_canonicalStateSignature(mutations.current), beforeState);

    final redo = mutations.redo(mutations.current.version);
    expect(redo, isNotNull);
    expect(_canonicalStateSignature(mutations.current), previewState);
    expect(mutations.current.stores.openings.keys.toSet(), previewOpeningIds);
    expect(
      <BoundaryEdgeId>{
        for (final topology in mutations.current.stores.boundaries.values)
          ...topology.edges.keys,
      },
      previewBoundaryIds,
    );
    expect(
      mutations.current.engineeringMetadata.generationProvenanceRegistry
          .manifests.keys.single,
      appliedGenerationId,
    );

    const codec = GenerationProvenanceAwareCanonicalProjectDocumentCodec();
    final saved = codec.encode(_snapshot(mutations.current));
    final reopened = codec.decode(saved);
    final reopenedPayload = codec.encode(reopened);
    expect(jsonEncode(reopenedPayload.payload), jsonEncode(saved.payload));
    expect(
      _canonicalStateSignature(reopened.aggregate),
      _canonicalStateSignature(mutations.current),
    );
    expect(reopened.aggregate.stores.openings.keys.toSet(), previewOpeningIds);
    expect(
      <BoundaryEdgeId>{
        for (final topology in reopened.aggregate.stores.boundaries.values)
          ...topology.edges.keys,
      },
      previewBoundaryIds,
    );

    final manifest = mutations.current.engineeringMetadata
        .generationProvenanceRegistry.manifests.values.single;
    final zone = mutations.current.stores.zones[manifest.apartmentZoneId]!;
    final spaceIds = zone.spaceIds.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final editedSpaceId = spaceIds.first;
    final provenanceBefore = mutations
        .current.engineeringMetadata.generationProvenanceRegistry
        .provenanceFor(editedSpaceId)!;

    final edit = mutations.commit(
      ProjectMutationRequest(
        expectedVersion: mutations.current.version,
        command: _RenameSpaceCommand(editedSpaceId, 'Engineer override'),
      ),
    );
    expect(edit, isNotNull);
    final provenanceAfter = mutations
        .current.engineeringMetadata.generationProvenanceRegistry
        .provenanceFor(editedSpaceId)!;
    expect(provenanceAfter.generationId, provenanceBefore.generationId);
    expect(provenanceAfter.generationKey, provenanceBefore.generationKey);
    expect(
      provenanceAfter.overriddenProperties,
      contains(GenerationPropertyKey.name),
    );

    final editedSaved = codec.encode(_snapshot(mutations.current));
    final editedReopened = codec.decode(editedSaved);
    final restoredProvenance = editedReopened
        .aggregate.engineeringMetadata.generationProvenanceRegistry
        .provenanceFor(editedSpaceId)!;
    expect(restoredProvenance.generationId, provenanceBefore.generationId);
    expect(restoredProvenance.generationKey, provenanceBefore.generationKey);
    expect(
      restoredProvenance.overriddenProperties,
      contains(GenerationPropertyKey.name),
    );
    expect(
      editedReopened.aggregate.stores.spaces[editedSpaceId]!.name,
      'Engineer override',
    );
  });
}

const _goldenRequest = ApartmentRequestInput(
  habitableRoomCount: 3,
  approximateAreaDm2: 7850,
  bathroomCount: 1,
  separateWcCount: 0,
  balconyCount: 1,
  balconyKind: ApartmentBalconyKind.loggia,
  kitchenMode: ApartmentKitchenMode.kitchenLiving,
  corridorMode: ApartmentCorridorMode.auto,
  exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
);

final class _Fixture {
  const _Fixture({required this.project, required this.target});

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_Fixture _fixture() {
  final projectId = ProjectId('p9-p913-gj-project');
  final siteId = SiteId('p9-p913-gj-site');
  final buildingId = BuildingId('p9-p913-gj-building');
  final levelId = LevelId('p9-p913-gj-level');
  final version = LocalProjectVersion(13);
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'P9.13 Site',
          buildingIds: {buildingId},
        ),
      },
      buildings: {
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'P9.13 Building',
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
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}

ProjectSnapshot _snapshot(ProjectAggregateRoot aggregate) => ProjectSnapshot(
      aggregate: aggregate,
      name: 'P9.13 Golden Journey',
      createdAt: DateTime.utc(2026, 10, 28, 4),
      updatedAt: DateTime.utc(2026, 10, 28, 4),
    );

String _canonicalStateSignature(ProjectAggregateRoot project) {
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
  final hosts = project
      .engineeringMetadata.boundaryHostedObjectRegistry.references.entries
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

final class _RenameSpaceCommand implements ProjectCommand {
  const _RenameSpaceCommand(this.spaceId, this.name);

  final SpaceId spaceId;
  final String name;

  @override
  String get commandType => 'p9.13.gj.rename-space';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final space = current.stores.spaces[spaceId]!;
    final next = ProjectSpaceEntity(
      id: space.id,
      levelId: space.levelId,
      name: name,
      type: space.type,
      usage: space.usage,
    );
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          spaces: {...current.stores.spaces, spaceId: next},
        ),
      ),
      affectedEntityIds: {spaceId},
    );
  }
}
