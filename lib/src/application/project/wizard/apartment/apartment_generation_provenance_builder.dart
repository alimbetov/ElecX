import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/generation_provenance.dart';
import '../../../../domain/generation_provenance_integrity.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../project_mutation_reservation.dart';
import '../wizard_contracts.dart';
import 'apartment_candidate_identity.dart';
import 'p9_sha256.dart';

final class ApartmentGenerationProvenanceInput {
  const ApartmentGenerationProvenanceInput({
    required this.providerTemplateId,
    required this.providerTemplateVersion,
    required this.candidateIdentity,
    required this.familyId,
  });

  final TemplateId providerTemplateId;
  final int providerTemplateVersion;
  final ApartmentCandidateIdentity candidateIdentity;
  final String familyId;
}

final class ApartmentGenerationProvenanceBuilder {
  const ApartmentGenerationProvenanceBuilder();

  static const int provenanceSchemaVersion = 1;
  static const String allocatorVersion = 'p8.mutation-identity-reservation.v1';
  static const String generationSlot = 'generation:apartment';

  GenerationProvenanceRegistry build({
    required GenerationProvenanceRegistry current,
    required ProjectAggregateRoot materializedProject,
    required LevelWizardTarget target,
    required ApartmentGeometryCandidate candidate,
    required MutationIdentityReservation reservation,
    required ApartmentGenerationProvenanceInput input,
  }) {
    final generationId = reservation.entityId<GenerationId>(generationSlot);
    final zoneId = reservation.entityId<ZoneId>('zone:apartment');
    final generated = <EntityGenerationProvenance>[];
    final generatedIds = <EntityId>{};

    void add({
      required EntityId entityId,
      required String generationKey,
      required Set<GenerationPropertyKey> properties,
      required String baseline,
    }) {
      generatedIds.add(entityId);
      generated.add(
        EntityGenerationProvenance(
          entityId: entityId,
          generationId: generationId,
          generationKey: generationKey,
          generatedProperties: properties,
          generatedBaselineFingerprint: _baselineFingerprint(
            generationKey,
            baseline,
          ),
        ),
      );
    }

    add(
      entityId: zoneId,
      generationKey: 'zone:apartment',
      properties: const {
        GenerationPropertyKey.name,
        GenerationPropertyKey.zoneMembership,
      },
      baseline:
          'name=${materializedProject.stores.zones[zoneId]!.name}\nkind=apartment',
    );

    final spaces = <GeneratedSpaceGeometry>[
      ...candidate.interiorSpaces,
      ...candidate.exteriorAppendages,
    ]..sort((a, b) => a.semanticKey.compareTo(b.semanticKey));
    for (final generatedSpace in spaces) {
      final spaceId = reservation.entityId<SpaceId>(
        'space:${generatedSpace.semanticKey}',
      );
      final canonical = materializedProject.stores.spaces[spaceId];
      if (canonical == null) {
        throw StateError('Generated Space $spaceId is missing from candidate.');
      }
      add(
        entityId: spaceId,
        generationKey: 'space:${generatedSpace.semanticKey}',
        properties: const {
          GenerationPropertyKey.name,
          GenerationPropertyKey.spaceType,
          GenerationPropertyKey.spaceUsage,
          GenerationPropertyKey.geometry,
          GenerationPropertyKey.zoneMembership,
          GenerationPropertyKey.openingRelations,
          GenerationPropertyKey.adjacencyRelations,
        },
        baseline: <String>[
          'name=${canonical.name}',
          'type=${canonical.type.name}',
          'usage=${canonical.usage.name}',
          'geometry=${generatedSpace.polygon.stableSerialization}',
          'zone=zone:apartment',
        ].join('\n'),
      );
      for (var index = 0;
          index < generatedSpace.polygon.segments.length;
          index++) {
        final edgeId = reservation.entityId<BoundaryEdgeId>(
          'edge:${generatedSpace.semanticKey}:$index',
        );
        final edge = materializedProject.index.boundaryEdges[edgeId];
        if (edge == null) {
          throw StateError('Generated BoundaryEdge $edgeId is missing.');
        }
        add(
          entityId: edgeId,
          generationKey: 'boundary:${generatedSpace.semanticKey}:${index + 1}',
          properties: const {GenerationPropertyKey.geometry},
          baseline: '${edge.start.xMm},${edge.start.yMm}>'
              '${edge.end.xMm},${edge.end.yMm}',
        );
      }
    }

    for (var index = 0; index < candidate.openingIntents.length; index++) {
      final intent = candidate.openingIntents[index];
      final openingId = reservation.entityId<OpeningId>('opening:$index');
      final opening = materializedProject.stores.openings[openingId];
      if (opening == null) {
        throw StateError('Generated Opening $openingId is missing.');
      }
      add(
        entityId: openingId,
        generationKey: 'opening:${intent.kind.name}:${index + 1}',
        properties: const {GenerationPropertyKey.openingRelations},
        baseline: <String>[
          'kind=${opening.kind.name}',
          'from=${intent.fromSpaceKey ?? '-'}',
          'to=${intent.toSpaceKey ?? '-'}',
          'widthMm=${opening.widthMm}',
          'heightMm=${opening.heightMm}',
        ].join('\n'),
      );
    }

    final pairKeys = candidate.sharedBoundaries
        .map((boundary) => boundary.pair.stableKey)
        .toSet()
        .toList()
      ..sort();
    for (final pairKey in pairKeys) {
      final adjacencyId =
          reservation.entityId<SpaceAdjacencyId>('adj:$pairKey');
      final adjacency = materializedProject.stores.adjacencies[adjacencyId];
      if (adjacency == null) {
        throw StateError('Generated adjacency $adjacencyId is missing.');
      }
      add(
        entityId: adjacencyId,
        generationKey: 'adjacency:$pairKey',
        properties: const {GenerationPropertyKey.adjacencyRelations},
        baseline: 'pair=$pairKey\nkind=${adjacency.kind.name}',
      );
    }

    final identity = input.candidateIdentity;
    final manifest = GenerationManifest(
      provenanceSchemaVersion: provenanceSchemaVersion,
      generationId: generationId,
      originType: GenerationOriginType.wizard,
      providerTemplateId: input.providerTemplateId,
      providerTemplateVersion: input.providerTemplateVersion,
      catalogVersion: identity.catalogVersion,
      apartmentTemplateId: TemplateId(identity.templateIdValue),
      apartmentTemplateVersion: identity.templateVersion,
      familyId: input.familyId,
      variantSeedId: identity.variantSeedId,
      generatorVersion: identity.generatorVersion,
      scoringProfileVersion: identity.scoringProfileVersion,
      allocatorVersion: allocatorVersion,
      geometryAlgorithmVersion: identity.geometryAlgorithmVersion,
      normalizedIntentFingerprint: identity.intentFingerprint,
      selectedCandidateFingerprint: identity.candidateFingerprint,
      projectId: target.projectId,
      buildingId: target.buildingId,
      levelId: target.levelId,
      apartmentZoneId: zoneId,
      generatedEntityIds: generatedIds,
    );
    final registry =
        current.addGeneration(manifest: manifest, provenances: generated);
    GenerationProvenanceIntegrityValidator.validateOrThrow(registry);
    return registry;
  }

  String _baselineFingerprint(String generationKey, String baseline) =>
      p9Sha256Hex(
        'p9.generation.baseline.v1\n'
        'generationKey=$generationKey\n'
        '$baseline',
      );
}
