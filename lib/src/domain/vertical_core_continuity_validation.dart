import 'physical_level_order.dart';
import 'project_identity.dart';
import 'vertical_core.dart';

typedef VerticalCoreBuildingLevelIdsResolver = Iterable<LevelId>? Function(
  BuildingId buildingId,
);
typedef VerticalCoreLevelPlacementResolver = PhysicalLevelPlacement? Function(
  LevelId levelId,
);

enum VerticalCoreContinuityIssueCode {
  ambiguousPhysicalLevelOrder,
  nonContiguousLevelRange,
}

final class VerticalCoreContinuityIssue {
  const VerticalCoreContinuityIssue({
    required this.code,
    required this.verticalCoreId,
    required this.message,
  });

  final VerticalCoreContinuityIssueCode code;
  final VerticalCoreId verticalCoreId;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

/// P7-C4 validation for one uninterrupted physical VerticalCore span.
///
/// Ownership/dangling-reference checks remain in VerticalCoreProjectValidator.
/// This validator runs only when the building's canonical level set and every
/// level placement can be resolved. It never derives adjacency from
/// levelNumber, displayOrder or Set insertion order.
abstract final class VerticalCoreContinuityValidator {
  static List<VerticalCoreContinuityIssue> validate({
    required Map<VerticalCoreId, ProjectVerticalCore> verticalCores,
    required VerticalCoreBuildingLevelIdsResolver buildingLevelIdsResolver,
    required VerticalCoreLevelPlacementResolver levelPlacementResolver,
  }) {
    final issues = <VerticalCoreContinuityIssue>[];

    for (final core in verticalCores.values) {
      final buildingLevelIds = buildingLevelIdsResolver(core.buildingId);
      if (buildingLevelIds == null) continue;

      final placements = <PhysicalLevelPlacement>[];
      var unresolved = false;
      for (final levelId in buildingLevelIds) {
        final placement = levelPlacementResolver(levelId);
        if (placement == null || placement.buildingId != core.buildingId) {
          unresolved = true;
          break;
        }
        placements.add(placement);
      }
      if (unresolved) continue;

      final ordered = PhysicalLevelOrder.tryResolve(placements);
      if (ordered == null) {
        issues.add(
          VerticalCoreContinuityIssue(
            code: VerticalCoreContinuityIssueCode.ambiguousPhysicalLevelOrder,
            verticalCoreId: core.id,
            message: 'Vertical core ${core.id} cannot resolve a unique physical '
                'level order in building ${core.buildingId}: at least two '
                'canonical levels share the same elevation.',
          ),
        );
        continue;
      }

      if (!PhysicalLevelOrder.isContiguousSelection(
        orderedLevels: ordered,
        selectedLevelIds: core.levelIds,
      )) {
        issues.add(
          VerticalCoreContinuityIssue(
            code: VerticalCoreContinuityIssueCode.nonContiguousLevelRange,
            verticalCoreId: core.id,
            message: 'Vertical core ${core.id} must serve one uninterrupted '
                'physical level range in building ${core.buildingId}.',
          ),
        );
      }
    }

    return List.unmodifiable(issues);
  }
}
