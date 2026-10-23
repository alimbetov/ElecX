import 'project_identity.dart';
import 'vertical_core.dart';

typedef VerticalCoreBuildingExists = bool Function(BuildingId buildingId);
typedef VerticalCoreLevelBuildingResolver = BuildingId? Function(
  LevelId levelId,
);

enum VerticalCoreProjectIssueCode {
  danglingBuilding,
  danglingLevel,
  levelBuildingMismatch,
}

final class VerticalCoreProjectIssue {
  const VerticalCoreProjectIssue({
    required this.code,
    required this.verticalCoreId,
    required this.message,
    this.relatedEntityId,
  });

  final VerticalCoreProjectIssueCode code;
  final VerticalCoreId verticalCoreId;
  final EntityId? relatedEntityId;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

/// Cross-reference validation for canonical vertical cores.
///
/// Local geometry/identity invariants remain in [VerticalCoreTopologyValidator].
/// This validator proves only project ownership: the building must exist and
/// every level traversed by the core must exist in that same building.
abstract final class VerticalCoreProjectValidator {
  static List<VerticalCoreProjectIssue> validate({
    required Map<VerticalCoreId, ProjectVerticalCore> verticalCores,
    required VerticalCoreBuildingExists buildingExists,
    required VerticalCoreLevelBuildingResolver levelBuildingResolver,
  }) {
    final issues = <VerticalCoreProjectIssue>[];

    for (final core in verticalCores.values) {
      if (!buildingExists(core.buildingId)) {
        issues.add(
          VerticalCoreProjectIssue(
            code: VerticalCoreProjectIssueCode.danglingBuilding,
            verticalCoreId: core.id,
            relatedEntityId: core.buildingId,
            message: 'Vertical core ${core.id} references missing building '
                '${core.buildingId}.',
          ),
        );
      }

      for (final levelId in core.levelIds) {
        final levelBuildingId = levelBuildingResolver(levelId);
        if (levelBuildingId == null) {
          issues.add(
            VerticalCoreProjectIssue(
              code: VerticalCoreProjectIssueCode.danglingLevel,
              verticalCoreId: core.id,
              relatedEntityId: levelId,
              message: 'Vertical core ${core.id} references missing level '
                  '$levelId.',
            ),
          );
          continue;
        }
        if (levelBuildingId != core.buildingId) {
          issues.add(
            VerticalCoreProjectIssue(
              code: VerticalCoreProjectIssueCode.levelBuildingMismatch,
              verticalCoreId: core.id,
              relatedEntityId: levelId,
              message: 'Vertical core ${core.id} belongs to building '
                  '${core.buildingId} but level $levelId belongs to '
                  '$levelBuildingId.',
            ),
          );
        }
      }
    }

    return List.unmodifiable(issues);
  }

  static void validateOrThrow({
    required Map<VerticalCoreId, ProjectVerticalCore> verticalCores,
    required VerticalCoreBuildingExists buildingExists,
    required VerticalCoreLevelBuildingResolver levelBuildingResolver,
  }) {
    final topologyIssues =
        VerticalCoreTopologyValidator.validate(verticalCores);
    if (topologyIssues.isNotEmpty) {
      throw VerticalCoreTopologyValidationException(topologyIssues);
    }
    final issues = validate(
      verticalCores: verticalCores,
      buildingExists: buildingExists,
      levelBuildingResolver: levelBuildingResolver,
    );
    if (issues.isNotEmpty) {
      throw VerticalCoreProjectValidationException(issues);
    }
  }
}

final class VerticalCoreProjectValidationException implements Exception {
  VerticalCoreProjectValidationException(
    Iterable<VerticalCoreProjectIssue> issues,
  ) : issues = List.unmodifiable(issues);

  final List<VerticalCoreProjectIssue> issues;

  @override
  String toString() => 'Invalid vertical core project ownership:\n'
      '${issues.join('\n')}';
}
