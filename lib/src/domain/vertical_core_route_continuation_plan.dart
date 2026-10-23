import 'project_aggregate.dart';
import 'project_identity.dart';
import 'vertical_core_route_authoring.dart';
import 'vertical_core_slab_crossing_resolver.dart';

final class VerticalCoreRouteContinuationHop {
  const VerticalCoreRouteContinuationHop({
    required this.verticalCoreId,
    required this.slabId,
    required this.fromLevelId,
    required this.toLevelId,
    required this.toSpaceId,
    required this.direction,
  });

  final VerticalCoreId verticalCoreId;
  final SlabId slabId;
  final LevelId fromLevelId;
  final LevelId toLevelId;
  final SpaceId toSpaceId;
  final VerticalCoreCrossingDirection direction;
}

/// Ordered UX-safe continuation plan through one canonical VerticalCore.
///
/// VerticalCore geometry identifies the physical routing volume but does not
/// own room identity. Callers must therefore provide an explicit target SpaceId
/// for every destination level. The planner only validates those selections; it
/// never guesses a room from footprint overlap or iteration order.
final class VerticalCoreRouteContinuationPlan {
  VerticalCoreRouteContinuationPlan({
    required this.verticalCoreId,
    required this.routePlan,
    required Iterable<VerticalCoreRouteContinuationHop> hops,
  }) : hops = List.unmodifiable(hops) {
    if (this.hops.length != routePlan.crossings.length) {
      throw ArgumentError(
        'Continuation hop count must match VerticalCore slab crossings.',
      );
    }
  }

  final VerticalCoreId verticalCoreId;
  final VerticalCoreRouteAuthoringPlan routePlan;
  final List<VerticalCoreRouteContinuationHop> hops;
}

abstract final class VerticalCoreRouteContinuationPlanner {
  static VerticalCoreRouteContinuationPlan? resolve({
    required ProjectAggregateRoot project,
    required VerticalCoreRouteAuthoringPlan routePlan,
    required Map<LevelId, SpaceId> targetSpaceByLevel,
  }) {
    final core = project.index.verticalCore(routePlan.verticalCoreId);
    if (core == null) return null;
    if (routePlan.crossings.isEmpty) return null;

    final hops = <VerticalCoreRouteContinuationHop>[];
    for (final crossing in routePlan.crossings) {
      if (crossing.verticalCoreId != core.id ||
          !core.servesLevel(crossing.fromLevelId) ||
          !core.servesLevel(crossing.toLevelId)) {
        return null;
      }
      final targetSpaceId = targetSpaceByLevel[crossing.toLevelId];
      if (targetSpaceId == null) return null;
      final targetSpace = project.index.space(targetSpaceId);
      if (targetSpace == null || targetSpace.levelId != crossing.toLevelId) {
        return null;
      }
      final targetLevel = project.index.level(crossing.toLevelId);
      if (targetLevel == null || targetLevel.buildingId != core.buildingId) {
        return null;
      }
      hops.add(
        VerticalCoreRouteContinuationHop(
          verticalCoreId: core.id,
          slabId: crossing.slabId,
          fromLevelId: crossing.fromLevelId,
          toLevelId: crossing.toLevelId,
          toSpaceId: targetSpaceId,
          direction: crossing.direction,
        ),
      );
    }

    return VerticalCoreRouteContinuationPlan(
      verticalCoreId: core.id,
      routePlan: routePlan,
      hops: hops,
    );
  }
}
