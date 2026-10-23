import 'physical_level_order.dart';
import 'project_identity.dart';
import 'vertical_core.dart';

typedef VerticalCoreBuildingLevelIdsResolver = Iterable<LevelId>? Function(
  BuildingId buildingId,
);
typedef VerticalCoreLevelPlacementResolver = PhysicalLevelPlacement? Function(
  LevelId levelId,
);
typedef VerticalCorePhysicalAdjacencyResolver
    = Iterable<PhysicalLevelAdjacency>? Function(BuildingId buildingId);

enum VerticalCoreContinuityIssueCode {
  unresolvedPhysicalTopology,
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
/// The validator fails closed when the canonical building/level snapshot cannot
/// be resolved. Ordering is derived from physical elevation plus canonical slab
/// adjacency; levelNumber, displayOrder and insertion order are non-semantic.
abstract final class VerticalCoreContinuityValidator {
  static List<VerticalCoreContinuityIssue> validate({
    required Map<VerticalCoreId, ProjectVerticalCore> verticalCores,
    required VerticalCoreBuildingLevelIdsResolver buildingLevelIdsResolver,
    required VerticalCoreLevelPlacementResolver levelPlacementResolver,
    VerticalCorePhysicalAdjacencyResolver? physicalAdjacencyResolver,
  }) {
    final issues = <VerticalCoreContinuityIssue>[];

    for (final core in verticalCores.values) {
      final buildingLevelIds = buildingLevelIdsResolver(core.buildingId);
      if (buildingLevelIds == null) {
        issues.add(
          VerticalCoreContinuityIssue(
            code: VerticalCoreContinuityIssueCode.unresolvedPhysicalTopology,
            verticalCoreId: core.id,
            message: 'Vertical core ${core.id} cannot resolve canonical levels '
                'for building ${core.buildingId}.',
          ),
        );
        continue;
      }

      final placements = <PhysicalLevelPlacement>[];
      var unresolvedLevelId = null as LevelId?;
      for (final levelId in buildingLevelIds) {
        final placement = levelPlacementResolver(levelId);
        if (placement == null || placement.buildingId != core.buildingId) {
          unresolvedLevelId = levelId;
          break;
        }
        placements.add(placement);
      }
      if (unresolvedLevelId != null) {
        issues.add(
          VerticalCoreContinuityIssue(
            code: VerticalCoreContinuityIssueCode.unresolvedPhysicalTopology,
            verticalCoreId: core.id,
            message: 'Vertical core ${core.id} cannot resolve canonical '
                'physical placement for level $unresolvedLevelId in building '
                '${core.buildingId}.',
          ),
        );
        continue;
      }

      final adjacencies = physicalAdjacencyResolver?.call(core.buildingId);
      if (physicalAdjacencyResolver != null && adjacencies == null) {
        issues.add(
          VerticalCoreContinuityIssue(
            code: VerticalCoreContinuityIssueCode.unresolvedPhysicalTopology,
            verticalCoreId: core.id,
            message: 'Vertical core ${core.id} cannot resolve canonical slab '
                'adjacency for building ${core.buildingId}.',
          ),
        );
        continue;
      }

      final ordered = PhysicalLevelOrder.tryResolve(
        placements,
        adjacencies: adjacencies ?? const [],
      );
      if (ordered == null) {
        issues.add(
          VerticalCoreContinuityIssue(
            code: VerticalCoreContinuityIssueCode.ambiguousPhysicalLevelOrder,
            verticalCoreId: core.id,
            message: 'Vertical core ${core.id} cannot resolve one unique '
                'physical level order in building ${core.buildingId} from '
                'canonical elevation and slab topology.',
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
