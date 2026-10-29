import '../../domain/project_identity.dart';

enum ProjectAuthoringIssueCode {
  buildingAlreadyExists,
  buildingNotFound,
  buildingHasLevels,
  buildingHasSiteDependencies,
  buildingHasPhysicalSlabs,
  levelAlreadyExists,
  levelNotFound,
  levelHasChildren,
  levelHasPhysicalSlabs,
  levelHasVerticalCores,
  duplicateLevelNumber,
  slabAlreadyExists,
  slabNotFound,
  verticalCoreAlreadyExists,
  verticalCoreNotFound,
  verticalCoreUnresolvedPhysicalTopology,
  verticalCoreAmbiguousPhysicalLevelOrder,
  verticalCoreNonContiguousLevelRange,
  structuralZoneAlreadyExists,
  structuralZoneNotFound,
  structuralZoneLevelMismatch,
  structuralZoneHasSpaces,
  spaceAlreadyExists,
  spaceNotFound,
  spaceHasSemanticDependencies,
  spaceHasBoundaryDependencies,
  openingAlreadyExists,
  openingNotFound,
  openingHasBoundaryDependencies,
  adjacencyAlreadyExists,
  adjacencyNotFound,
  overlayAlreadyExists,
  overlayNotFound,
}

final class ProjectAuthoringException implements Exception {
  const ProjectAuthoringException({
    required this.code,
    required this.message,
    this.entityId,
    this.relatedEntityId,
    this.blockingEntityIds = const <EntityId>{},
  });

  final ProjectAuthoringIssueCode code;
  final String message;
  final EntityId? entityId;

  /// Primary related entity for compact diagnostics and legacy callers.
  final EntityId? relatedEntityId;

  /// Complete set of direct canonical entities blocking an authoring action.
  final Set<EntityId> blockingEntityIds;

  @override
  String toString() => '${code.name}: $message';
}
