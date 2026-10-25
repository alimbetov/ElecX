import '../../domain/generation_provenance.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_mutation.dart';

final class GenerationProvenanceCommandException implements Exception {
  const GenerationProvenanceCommandException(this.code, [this.entityId]);

  final String code;
  final EntityId? entityId;

  @override
  String toString() => code;
}

/// Canonical metadata-only command used by P9.12 and future P15 regeneration.
///
/// Lock state participates in the same LocalProjectVersion, Undo/Redo and
/// persistence lifecycle as the generated entity. It never changes generationId
/// or generationKey.
final class SetGeneratedEntityRegenerationLockCommand implements ProjectCommand {
  const SetGeneratedEntityRegenerationLockCommand({
    required this.entityId,
    required this.locked,
  });

  final EntityId entityId;
  final bool locked;

  @override
  String get commandType => 'p9.provenance.set-regeneration-lock';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final registry = current.engineeringMetadata.generationProvenanceRegistry;
    final provenance = registry.provenanceFor(entityId);
    if (provenance == null) {
      throw GenerationProvenanceCommandException(
        'p9.provenance.entity-not-generated',
        entityId,
      );
    }
    final next = registry.setLocked(entityId, locked: locked);
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata:
            current.engineeringMetadata.withGenerationProvenanceRegistry(next),
        stores: current.stores,
      ),
      affectedEntityIds: {entityId},
    );
  }
}
