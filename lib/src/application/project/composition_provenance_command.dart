import 'dart:convert';

import '../../domain/composition_generation_provenance.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/semantic_sha256.dart';
import 'project_mutation.dart';
import 'project_mutation_reservation.dart';

/// Explicit opt-in by production generators. The generic coordinator adds
/// evidence on its existing reservation boundary, once per user operation.
abstract interface class CompositionProvenanceSource
    implements ReservedProjectCommand {
  CompositionGenerationEvidence get generationEvidence;
}

final class CompositionGenerationEvidence {
  CompositionGenerationEvidence(
      {required this.generatorVersion,
      required this.candidateFingerprint,
      this.canonicalRequest,
      Map<String, Object?> templates = const {}})
      : templates = Map.unmodifiable(templates);
  final String? canonicalRequest;
  final String generatorVersion;
  final String candidateFingerprint;
  final Map<String, Object?> templates;
}

final class ProvenanceReservedProjectCommand implements ReservedProjectCommand {
  ProvenanceReservedProjectCommand(this.source);
  final CompositionProvenanceSource source;
  static const _slot = 'composition.generation';
  @override
  String get commandType => source.commandType;
  @override
  String get normalizedIntentKey => source.normalizedIntentKey;
  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.combineEntityReservations({
        'command': source.reserveIdentities(factory),
        'provenance': MutationIdentityReservation.allocate(
            factory: factory,
            entitySlots: {_slot: ReservedEntityIdKind.generation})
      });
  @override
  void validateReservation(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    final child = reservation.selectEntityScope('command');
    final provenance = reservation.selectEntityScope('provenance');
    if (provenance.slots.length != 1 ||
        reservation.slots.length != child.slots.length + 1) {
      throw StateError('p10.provenance.invalid-reservation');
    }
    final id = provenance.entityId<GenerationId>(_slot);
    final registry = current.engineeringMetadata.generationProvenanceRegistry;
    if (registry.compositions.containsKey(id) ||
        registry.manifests.containsKey(id) ||
        registry.levelCompositions.containsKey(id) ||
        child.entityIds.contains(id)) {
      throw StateError('p10.provenance.reservation-collision');
    }
    if (child.entityIds
        .whereType<GenerationId>()
        .any(registry.compositions.containsKey)) {
      throw StateError('p10.provenance.reservation-collision');
    }
    source.validateReservation(current: current, reservation: child);
  }

  @override
  ProjectCommandCandidate buildCandidate(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    validateReservation(current: current, reservation: reservation);
    final child = reservation.selectEntityScope('command');
    final candidate =
        source.buildCandidate(current: current, reservation: child);
    final state = candidate.resolveState(current);
    var project = ProjectAggregateRoot(
        id: current.id,
        siteId: current.siteId,
        version: current.version,
        stores: state.stores,
        engineeringMetadata: state.engineeringMetadata);
    final entries = <String, CompositionGeneratedEntity>{};
    for (final slot in child.slots) {
      final id = child.entityId<EntityId>(slot);
      final fields = compositionEntityFields(project, id);
      if (fields != null && compositionEntityFields(current, id) == null) {
        entries[slot] = CompositionGeneratedEntity(id: id, baseline: {
          for (final f in fields.entries) f.key: compositionHash(f.value)
        });
      }
    }
    if (entries.isEmpty) return candidate;
    final evidence = source.generationEvidence;
    final registry = state.engineeringMetadata.generationProvenanceRegistry;
    final id = reservation
        .selectEntityScope('provenance')
        .entityId<GenerationId>(_slot);
    final manifest = CompositionGenerationManifest(
        id: id,
        projectId: current.id,
        siteId: current.siteId,
        commandType: commandType,
        canonicalEvidence: jsonEncode({
          'generatorVersion': evidence.generatorVersion,
          'request': evidence.canonicalRequest ?? normalizedIntentKey,
          'requestFingerprint': semanticSha256Hex(
              evidence.canonicalRequest ?? normalizedIntentKey),
          'candidateFingerprint': evidence.candidateFingerprint,
          'templates': evidence.templates
        }),
        entities: entries,
        children: {
          for (final e in registry.levelCompositions.entries)
            if (!current.engineeringMetadata.generationProvenanceRegistry
                .levelCompositions
                .containsKey(e.key))
              e.key: e.value.candidateFingerprint
        });
    project = ProjectAggregateRoot(
        id: project.id,
        siteId: project.siteId,
        version: project.version,
        stores: project.stores,
        engineeringMetadata: project.engineeringMetadata
            .withGenerationProvenanceRegistry(registry.copyWith(
                compositions: {...registry.compositions, id: manifest})));
    return ProjectCommandCandidate.fromState(
        state: ProjectMutableState.fromProject(project),
        affectedEntityIds: {...candidate.affectedEntityIds, id});
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations(
      {required ProjectAggregateRoot before,
      required ProjectAggregateRoot candidate,
      required MutationIdentityReservation reservation}) sync* {
    yield* source.semanticOperations(
        before: before,
        candidate: candidate,
        reservation: reservation.selectEntityScope('command'));
    final id = reservation
        .selectEntityScope('provenance')
        .entityId<GenerationId>(_slot);
    if (candidate.engineeringMetadata.generationProvenanceRegistry.compositions
        .containsKey(id)) {
      yield CreateEntityOperation(entityId: id, ownerId: before.siteId);
    }
  }
}
