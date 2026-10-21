import '../../domain/project_identity.dart';

enum ProjectAuthoringIssueCode {
  buildingAlreadyExists,
  buildingNotFound,
  levelAlreadyExists,
  levelNotFound,
  duplicateLevelNumber,
  structuralZoneAlreadyExists,
  structuralZoneNotFound,
}

final class ProjectAuthoringException implements Exception {
  const ProjectAuthoringException({
    required this.code,
    required this.message,
    this.entityId,
    this.relatedEntityId,
  });

  final ProjectAuthoringIssueCode code;
  final String message;
  final EntityId? entityId;
  final EntityId? relatedEntityId;

  @override
  String toString() => '${code.name}: $message';
}
