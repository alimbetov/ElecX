import 'project_aggregate.dart';
import 'project_identity.dart';
import 'vertical_core.dart';

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
    required ProjectEntityStores stores,
    required Map<VerticalCoreId, ProjectVerticalCore> verticalCores,
  }) {
    final issues = <VerticalCoreProjectIssue>[];

    for (final core in verticalCores.values) {
      final building = stores.buildings[core.buildingId];
      if (building == null) {
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
        final level = stores.levels[levelId];
        if (level == null) {
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
        if (level.buildingId != core.buildingId) {
          issues.add(
            VerticalCoreProjectIssue(
              code: VerticalCoreProjectIssueCode.levelBuildingMismatch,
              verticalCoreId: core.id,
              relatedEntityId: level.id,
              message: 'Vertical core ${core.id} belongs to building '
                  '${core.buildingId} but level ${level.id} belongs to '
                  '${level.buildingId}.',
            ),
          );
        }
      }
    }

    return List.unmodifiable(issues);
  }

  static void validateOrThrow({
    required ProjectEntityStores stores,
    required Map<VerticalCoreId, ProjectVerticalCore> verticalCores,
  }) {
    final topologyIssues = VerticalCoreTopologyValidator.validate(verticalCores);
    if (topologyIssues.isNotEmpty) {
      throw VerticalCoreTopologyValidationException(topologyIssues);
    }
    final issues = validate(stores: stores, verticalCores: verticalCores);
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
