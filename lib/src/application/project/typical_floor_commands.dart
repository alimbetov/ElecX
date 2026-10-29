import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/typical_floor.dart';
import 'project_mutation.dart';

/// Associates an immutable pattern with already materialized canonical floors.
/// Generation allocates their identities through the existing reservation API.
/// Registering lineage never creates or replaces structural project entities.
final class RegisterTypicalFloorCommand implements ProjectCommand {
  RegisterTypicalFloorCommand(
      {required this.definition,
      required Iterable<TypicalFloorInstance> instances})
      : instances = List.unmodifiable(instances);

  final TypicalFloorDefinition definition;
  final List<TypicalFloorInstance> instances;

  @override
  String get commandType => 'p10.typical-floor.register';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final registry = current.engineeringMetadata.generationProvenanceRegistry
        .registerTypicalFloor(
      definition: definition,
      instances: instances,
    );
    TypicalFloorLineageIntegrity.validateOrThrow(
        definitions: registry.typicalFloorDefinitions,
        instances: registry.floorInstances,
        stores: current.stores);
    for (final instance in instances) {
      final level = current.stores.levels[instance.levelId]!;
      final expected = <EntityId>{
        level.id,
        ...level.zoneIds,
        ...level.spaceIds,
        for (final spaceId in level.spaceIds)
          ...?current.stores.boundaries[spaceId]?.orderedEdgeIds,
        for (final opening in current.stores.openings.values)
          if (opening.levelId == level.id) opening.id,
        for (final adjacency in current.stores.adjacencies.values)
          if (level.spaceIds.contains(adjacency.spaceAId) &&
              level.spaceIds.contains(adjacency.spaceBId))
            adjacency.id,
      };
      if (expected.length != instance.entities.length ||
          !expected.containsAll(instance.entities.values)) {
        throw const TypicalFloorLineageException(
            'p10.typical-floor.incomplete-pattern');
      }
      final actual = TypicalFloorPattern.fingerprint(
          stores: current.stores, entities: instance.entities);
      if (actual != definition.patternFingerprint) {
        throw const TypicalFloorLineageException(
            'p10.typical-floor.pattern-mismatch');
      }
    }
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
          engineeringMetadata: current.engineeringMetadata
              .withGenerationProvenanceRegistry(registry),
          stores: current.stores),
      affectedEntityIds: {
        definition.id,
        ...instances.map((instance) => instance.levelId)
      },
    );
  }
}

final class DetachTypicalFloorCommand implements ProjectCommand {
  const DetachTypicalFloorCommand(this.levelId);
  final LevelId levelId;

  @override
  String get commandType => 'p10.typical-floor.detach';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) =>
      ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
            engineeringMetadata: current.engineeringMetadata
                .withGenerationProvenanceRegistry(current
                    .engineeringMetadata.generationProvenanceRegistry
                    .detachTypicalFloor(levelId)),
            stores: current.stores),
        affectedEntityIds: {levelId},
      );
}

final class RemoveTypicalFloorDefinitionCommand implements ProjectCommand {
  const RemoveTypicalFloorDefinitionCommand(this.definitionId);
  final TypicalFloorDefinitionId definitionId;

  @override
  String get commandType => 'p10.typical-floor.remove-definition';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) =>
      ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
            engineeringMetadata: current.engineeringMetadata
                .withGenerationProvenanceRegistry(current
                    .engineeringMetadata.generationProvenanceRegistry
                    .removeTypicalFloorDefinition(definitionId)),
            stores: current.stores),
        affectedEntityIds: {definitionId},
      );
}
