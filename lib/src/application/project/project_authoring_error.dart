import '../../domain/project_identity.dart';

enum ProjectAuthoringIssueCode {
  buildingAlreadyExists,
  buildingNotFound,
  buildingHasLevels,
  levelAlreadyExists,
  levelNotFound,
  levelHasChildren,
  duplicateLevelNumber,
  structuralZoneAlreadyExists,
  structuralZoneNotFound,
  structuralZoneLevelMismatch,
  structuralZoneHasSpaces,
  spaceAlreadyExists,
  spaceNotFound,
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
  ///
  /// Destructive commands populate this set instead of exposing only an
  /// arbitrary first dependency. This allows future navigator/dialog UX to
  /// explain every direct blocker without re-deriving domain relationships.
  final Set<EntityId> blockingEntityIds;

  @override
  String toString() => '${code.name}: $message';
}
