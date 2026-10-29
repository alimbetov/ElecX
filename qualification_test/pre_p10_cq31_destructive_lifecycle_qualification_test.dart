import 'dart:convert';
import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/project_space_semantics_commands.dart';
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
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/serialization/project/generation_provenance_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PRE10-CQ31 destructive full lifecycle roundtrip preserves canonical semantics',
    () {
      final fixture = _fixture();
      const candidateService = ApartmentCandidateSetService();
      final generated = candidateService.generate(
        input: _goldenRequest,
        target: fixture.target,
        project: fixture.project,
      );

      expect(generated.accepted, isTrue, reason: '${generated.failures}');
      final candidateSet = generated.candidateSet!;
      expect(candidateSet.candidates, isNotEmpty);
      final selected = candidateSet.recommendedCandidate;
      final parameters = ApartmentWizardParameters(
        request: _goldenRequest,
        selection: candidateSet.selectionFor(selected),
      );

      // Generate -> Preview -> Apply through the same production wizard and
      // shared canonical mutation port used by the P9.13 golden journey.
      final mutations = ProjectMutationSession(fixture.project);
      final wizard = WizardSession(
        target: fixture.target,
        registry: WizardProviderRegistry(const [ApartmentWizardProvider()]),
        mutations: SharedProjectWizardMutationPort(
          mutations: mutations,
          idFactory: SecureRandomEntityIdFactory(random: Random(1031001)),
        ),
      );

      final initialVersion = mutations.current.version;
      expect(wizard.begin(), isTrue);
      expect(wizard.selectFamily(ApartmentWizardProvider.familyId), isTrue);
      expect(wizard.updateParameters(parameters), isTrue);
      expect(wizard.generatePreview(), isTrue, reason: '${wizard.failure}');

      final preview = wizard.preview!;
      expect(preview.hasChanges, isTrue);
      expect(preview.observedVersion, initialVersion);
      expect(
          preview.normalizedIntentKey, contains(selected.candidateFingerprint));
      expect(
        const WizardDiffProjector()
            .project(before: mutations.current, preview: preview)
            .entries,
        isNotEmpty,
      );
      expect(mutations.current.version, initialVersion);

      expect(wizard.confirm(), isTrue, reason: '${wizard.failure}');
      expect(mutations.current.version.value, initialVersion.value + 1);
      _assertIntegrity(mutations.current);
      _assertTopologyOnlyProposalContract(mutations.current);

      final appliedRegistry =
          mutations.current.engineeringMetadata.generationProvenanceRegistry;
      expect(appliedRegistry.manifests, hasLength(1));
      final manifest = appliedRegistry.manifests.values.single;
      final generatedZone =
          mutations.current.stores.zones[manifest.apartmentZoneId];
      expect(generatedZone, isNotNull);
      expect(generatedZone!.spaceIds, isNotEmpty);

      final generatedAdjacencies = mutations.current.stores.adjacencies.keys
          .where((id) => appliedRegistry.provenanceFor(id) != null)
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      expect(
        generatedAdjacencies,
        isNotEmpty,
        reason: 'CQ31 requires a generated destructive target.',
      );
      final adjacencyId = generatedAdjacencies.first;
      final adjacencyProvenance = appliedRegistry.provenanceFor(adjacencyId)!;
      final generationKey = adjacencyProvenance.generationKey;
      final generationId = adjacencyProvenance.generationId;

      // Save -> Close -> Reopen. The codec payload must round-trip exactly.
      const codec = GenerationProvenanceAwareCanonicalProjectDocumentCodec();
      final firstSaved = codec.encode(_snapshot(mutations.current));
      final firstSavedFingerprint = _semanticFingerprint(mutations.current);
      final firstReopened = codec.decode(firstSaved);
      expect(
        jsonEncode(codec.encode(firstReopened).payload),
        jsonEncode(firstSaved.payload),
      );
      expect(
        _semanticFingerprint(firstReopened.aggregate),
        firstSavedFingerprint,
      );
      _assertIntegrity(firstReopened.aggregate);
      _assertTopologyOnlyProposalContract(firstReopened.aggregate);

      // Reopen owns a fresh mutation session. Edit a generated Space and prove
      // that provenance records the engineer override while revision advances.
      final reopenedMutations = ProjectMutationSession(firstReopened.aggregate);
      final editedSpaceId = generatedZone.spaceIds.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final spaceId = editedSpaceId.first;
      final versionBeforeEdit = reopenedMutations.current.version;
      final edit = reopenedMutations.commit(
        ProjectMutationRequest(
          expectedVersion: versionBeforeEdit,
          command: SetSpaceUsageCommand(
            spaceId: spaceId,
            usage: SpaceUsage.office,
          ),
        ),
      );
      expect(edit, isNotNull);
      expect(
        reopenedMutations.current.version.value,
        versionBeforeEdit.value + 1,
      );
      expect(reopenedMutations.current.stores.spaces[spaceId]!.usage,
          SpaceUsage.office);
      expect(
        reopenedMutations
            .current.engineeringMetadata.generationProvenanceRegistry
            .provenanceFor(spaceId)!
            .overriddenProperties,
        contains(GenerationPropertyKey.spaceUsage),
      );
      _assertIntegrity(reopenedMutations.current);
      _assertTopologyOnlyProposalContract(reopenedMutations.current);

      // Delete one generated semantic adjacency through the production command.
      // ProjectMutationSession must move its generation key into the manifest
      // tombstone set in the same canonical commit.
      final preDeleteFingerprint =
          _semanticFingerprint(reopenedMutations.current);
      final versionBeforeDelete = reopenedMutations.current.version;
      final deletion = reopenedMutations.commit(
        ProjectMutationRequest(
          expectedVersion: versionBeforeDelete,
          command: RemoveAdjacencyCommand(adjacencyId: adjacencyId),
        ),
      );
      expect(deletion, isNotNull);
      expect(
        reopenedMutations.current.version.value,
        versionBeforeDelete.value + 1,
      );
      expect(reopenedMutations.current.stores.adjacencies,
          isNot(contains(adjacencyId)));
      final deletedRegistry = reopenedMutations
          .current.engineeringMetadata.generationProvenanceRegistry;
      expect(deletedRegistry.provenanceFor(adjacencyId), isNull);
      expect(
        deletedRegistry.manifestFor(generationId)!.removedGenerationKeys,
        contains(generationKey),
      );
      expect(
        deletedRegistry.manifestFor(generationId)!.generatedEntityIds,
        isNot(contains(adjacencyId)),
      );
      final destructiveFingerprint =
          _semanticFingerprint(reopenedMutations.current);
      expect(destructiveFingerprint, isNot(preDeleteFingerprint));
      _assertIntegrity(reopenedMutations.current);
      _assertTopologyOnlyProposalContract(reopenedMutations.current);

      // Undo must restore the exact pre-delete semantic state while advancing
      // the logical project version once. Redo must restore the exact
      // destructive state, including the persisted tombstone.
      final versionBeforeUndo = reopenedMutations.current.version;
      final undo = reopenedMutations.undo(versionBeforeUndo);
      expect(undo, isNotNull);
      expect(
        reopenedMutations.current.version.value,
        versionBeforeUndo.value + 1,
      );
      expect(_semanticFingerprint(reopenedMutations.current),
          preDeleteFingerprint);
      expect(
          reopenedMutations.current.stores.adjacencies, contains(adjacencyId));
      final undoRegistry = reopenedMutations
          .current.engineeringMetadata.generationProvenanceRegistry;
      expect(undoRegistry.provenanceFor(adjacencyId), isNotNull);
      expect(
        undoRegistry.manifestFor(generationId)!.removedGenerationKeys,
        isNot(contains(generationKey)),
      );
      _assertIntegrity(reopenedMutations.current);

      final versionBeforeRedo = reopenedMutations.current.version;
      final redo = reopenedMutations.redo(versionBeforeRedo);
      expect(redo, isNotNull);
      expect(
        reopenedMutations.current.version.value,
        versionBeforeRedo.value + 1,
      );
      expect(
        _semanticFingerprint(reopenedMutations.current),
        destructiveFingerprint,
      );
      expect(reopenedMutations.current.stores.adjacencies,
          isNot(contains(adjacencyId)));
      final redoRegistry = reopenedMutations
          .current.engineeringMetadata.generationProvenanceRegistry;
      expect(redoRegistry.provenanceFor(adjacencyId), isNull);
      expect(
        redoRegistry.manifestFor(generationId)!.removedGenerationKeys,
        contains(generationKey),
      );
      _assertIntegrity(reopenedMutations.current);
      _assertTopologyOnlyProposalContract(reopenedMutations.current);

      // Re-Save -> Close -> Reopen must preserve the destructive state exactly,
      // including the edit override and removed generation-key tombstone.
      final secondSaved = codec.encode(_snapshot(reopenedMutations.current));
      final secondReopened = codec.decode(secondSaved);
      expect(
        jsonEncode(codec.encode(secondReopened).payload),
        jsonEncode(secondSaved.payload),
      );
      expect(
        _semanticFingerprint(secondReopened.aggregate),
        destructiveFingerprint,
      );
      expect(secondReopened.aggregate.stores.adjacencies,
          isNot(contains(adjacencyId)));
      expect(secondReopened.aggregate.stores.spaces[spaceId]!.usage,
          SpaceUsage.office);
      final finalRegistry = secondReopened
          .aggregate.engineeringMetadata.generationProvenanceRegistry;
      expect(finalRegistry.provenanceFor(adjacencyId), isNull);
      expect(
        finalRegistry.manifestFor(generationId)!.removedGenerationKeys,
        contains(generationKey),
      );
      expect(
        finalRegistry.provenanceFor(spaceId)!.overriddenProperties,
        contains(GenerationPropertyKey.spaceUsage),
      );
      _assertIntegrity(secondReopened.aggregate);
      _assertTopologyOnlyProposalContract(secondReopened.aggregate);
    },
  );
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
  final projectId = ProjectId('pre10-cq31-project');
  final siteId = SiteId('pre10-cq31-site');
  final buildingId = BuildingId('pre10-cq31-building');
  final levelId = LevelId('pre10-cq31-level');
  final version = LocalProjectVersion(31);
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'PRE10 CQ31 Site',
          buildingIds: {buildingId},
        ),
      },
      buildings: {
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'PRE10 CQ31 Building',
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
      name: 'PRE10 CQ31 destructive lifecycle',
      createdAt: DateTime.utc(2026, 10, 29, 4),
      updatedAt: DateTime.utc(2026, 10, 29, 4),
    );

void _assertIntegrity(ProjectAggregateRoot project) {
  expect(
    ProjectAggregateValidator.validate(
      rootSiteId: project.siteId,
      stores: project.stores,
    ),
    isEmpty,
  );
  project.engineeringMetadata.boundaryHostedObjectRegistry
      .validateAgainst(project.stores.boundaries);
  project.engineeringMetadata.generationProvenanceRegistry.validateOrThrow(
    projectId: project.id,
    entityExists: (id) => _entityExists(project, id),
  );
}

void _assertTopologyOnlyProposalContract(ProjectAggregateRoot project) {
  expect(
    project.engineeringMetadata.appliedEngineeringProposalRegistry.byLevel,
    isEmpty,
    reason: 'CQ31 uses the explicit topology-only P9 journey; no stale or '
        'unvalidated engineering proposal may appear implicitly.',
  );
}

bool _entityExists(ProjectAggregateRoot project, EntityId id) {
  if (id is ZoneId) return project.stores.zones.containsKey(id);
  if (id is SpaceId) return project.stores.spaces.containsKey(id);
  if (id is OpeningId) return project.stores.openings.containsKey(id);
  if (id is SpaceAdjacencyId) {
    return project.stores.adjacencies.containsKey(id);
  }
  if (id is BoundaryEdgeId) {
    return project.stores.boundaries.values
        .any((topology) => topology.edges.containsKey(id));
  }
  return false;
}

String _semanticFingerprint(ProjectAggregateRoot project) {
  final registry = project.engineeringMetadata.generationProvenanceRegistry;
  final manifests = registry.manifests.values.toList()
    ..sort((a, b) => a.generationId.value.compareTo(b.generationId.value));
  final entities = registry.entities.values.toList()
    ..sort((a, b) => a.entityId.value.compareTo(b.entityId.value));

  return jsonEncode({
    'canonical': _canonicalStateSignature(project),
    'manifests': [
      for (final manifest in manifests)
        {
          'generationId': manifest.generationId.value,
          'candidate': manifest.selectedCandidateFingerprint,
          'generatedEntityIds':
              (manifest.generatedEntityIds.map((id) => id.value).toList()
                ..sort()),
          'removedGenerationKeys': (manifest.removedGenerationKeys.toList()
            ..sort()),
        },
    ],
    'entities': [
      for (final provenance in entities)
        {
          'entityId': provenance.entityId.value,
          'generationId': provenance.generationId.value,
          'generationKey': provenance.generationKey,
          'overridden':
              (provenance.overriddenProperties.map((key) => key.name).toList()
                ..sort()),
          'baseline': provenance.generatedBaselineFingerprint,
        },
    ],
    'proposalLevels': (project
        .engineeringMetadata.appliedEngineeringProposalRegistry.byLevel.keys
        .map((id) => id.value)
        .toList()
      ..sort()),
  });
}

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
