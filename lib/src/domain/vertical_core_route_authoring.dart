import 'boundary_penetration.dart';
import 'boundary_topology.dart';
import 'project_aggregate.dart';
import 'project_identity.dart';
import 'surfaces.dart';
import 'vertical_core_path_resolver.dart';
import 'vertical_core_route_leg.dart';
import 'vertical_core_slab_crossing_resolver.dart';

/// One concrete slab boundary in a planned route through a VerticalCore.
final class VerticalCoreRouteCrossingPlan {
  const VerticalCoreRouteCrossingPlan({
    required this.verticalCoreId,
    required this.slabId,
    required this.fromLevelId,
    required this.toLevelId,
    required this.planPoint,
    required this.direction,
    required this.hostThicknessMm,
    required this.materialId,
  });

  final VerticalCoreId verticalCoreId;
  final SlabId slabId;
  final LevelId fromLevelId;
  final LevelId toLevelId;
  final BoundaryPointMm planPoint;
  final VerticalCoreCrossingDirection direction;
  final int hostThicknessMm;
  final String materialId;

  /// Materializes the physical hole only after the editor supplies the exact
  /// canonical ceiling/floor surfaces for this level pair.
  BoundaryPenetration createPenetration({
    required String penetrationId,
    required String routeId,
    required RoomSurfaceRef entrySurface,
    required SurfacePointMm entryPoint,
    required RoomSurfaceRef exitSurface,
    required SurfacePointMm exitPoint,
  }) =>
      BoundaryPenetration.slab(
        id: penetrationId,
        slabId: slabId,
        verticalCoreId: verticalCoreId,
        entrySurface: entrySurface,
        entryPoint: entryPoint,
        exitSurface: exitSurface,
        exitPoint: exitPoint,
        hostThicknessMm: hostThicknessMm,
        routeId: routeId,
        materialId: materialId,
      );
}

/// Fail-closed physical plan for a cable run through one stable riser/shaft.
///
/// [intermediateVerticalLengthMm] is the hidden straight-Z run inside the core
/// between consecutive slab penetrations. Individual slab thickness remains
/// owned by penetration entities and is exposed separately so callers never
/// double-count it. [verticalLegs] carries the same length as durable physical
/// evidence per consecutive slab pair.
final class VerticalCoreRouteAuthoringPlan {
  VerticalCoreRouteAuthoringPlan({
    required this.verticalCoreId,
    required this.fromLevelId,
    required this.toLevelId,
    required Iterable<VerticalCoreRouteCrossingPlan> crossings,
    required this.intermediateVerticalLengthMm,
    Iterable<VerticalCoreRouteLeg> verticalLegs = const [],
  })  : crossings = List.unmodifiable(crossings),
        verticalLegs = List.unmodifiable(verticalLegs) {
    if (this.crossings.isEmpty) {
      throw ArgumentError('VerticalCore route plan requires a slab crossing.');
    }
    if (intermediateVerticalLengthMm < 0) {
      throw ArgumentError.value(
        intermediateVerticalLengthMm,
        'intermediateVerticalLengthMm',
      );
    }
    final legLength = this.verticalLegs.fold<int>(
          0,
          (sum, leg) => sum + leg.lengthMm,
        );
    if (this.verticalLegs.isNotEmpty &&
        legLength != intermediateVerticalLengthMm) {
      throw ArgumentError(
        'VerticalCore leg length $legLength does not match planned hidden '
        'length $intermediateVerticalLengthMm.',
      );
    }
    for (final leg in this.verticalLegs) {
      if (leg.verticalCoreId != verticalCoreId) {
        throw ArgumentError(
          'VerticalCore route leg ${leg.fromSlabId}->${leg.toSlabId} belongs '
          'to ${leg.verticalCoreId}, not $verticalCoreId.',
        );
      }
    }
  }

  final VerticalCoreId verticalCoreId;
  final LevelId fromLevelId;
  final LevelId toLevelId;
  final List<VerticalCoreRouteCrossingPlan> crossings;
  final int intermediateVerticalLengthMm;
  final List<VerticalCoreRouteLeg> verticalLegs;

  int get penetrationLengthMm => crossings.fold(
        0,
        (sum, crossing) => sum + crossing.hostThicknessMm,
      );

  int get totalHiddenLengthMm =>
      intermediateVerticalLengthMm + penetrationLengthMm;
}

abstract final class VerticalCoreRouteAuthoring {
  static VerticalCoreRouteAuthoringPlan? plan({
    required ProjectAggregateRoot project,
    required VerticalCoreId verticalCoreId,
    required LevelId fromLevelId,
    required LevelId toLevelId,
    required BoundaryPointMm planPoint,
  }) {
    final core = project.index.verticalCore(verticalCoreId);
    if (core == null) return null;
    final path = VerticalCorePathResolver.resolve(
      project: project,
      core: core,
      fromLevelId: fromLevelId,
      toLevelId: toLevelId,
      planPoint: planPoint,
    );
    if (path == null) return null;

    final crossings = <VerticalCoreRouteCrossingPlan>[];
    for (final crossing in path.crossings) {
      final slab = project.index.slab(crossing.slabId);
      if (slab == null) return null;
      crossings.add(
        VerticalCoreRouteCrossingPlan(
          verticalCoreId: verticalCoreId,
          slabId: slab.id,
          fromLevelId: crossing.fromLevelId,
          toLevelId: crossing.toLevelId,
          planPoint: crossing.planPoint,
          direction: crossing.direction,
          hostThicknessMm: slab.thicknessMm,
          materialId: slab.materialId,
        ),
      );
    }

    var intermediateLength = 0;
    final verticalLegs = <VerticalCoreRouteLeg>[];
    for (var index = 0; index + 1 < path.crossings.length; index++) {
      final current = project.index.slab(path.crossings[index].slabId);
      final next = project.index.slab(path.crossings[index + 1].slabId);
      if (current == null || next == null) return null;
      final gap = path.direction == VerticalCoreCrossingDirection.up
          ? next.bottomElevationMm - current.topElevationMm
          : current.bottomElevationMm - next.topElevationMm;
      if (gap < 0) return null;
      intermediateLength += gap;
      verticalLegs.add(
        VerticalCoreRouteLeg(
          verticalCoreId: verticalCoreId,
          fromSlabId: current.id,
          toSlabId: next.id,
          lengthMm: gap,
        ),
      );
    }

    return VerticalCoreRouteAuthoringPlan(
      verticalCoreId: verticalCoreId,
      fromLevelId: fromLevelId,
      toLevelId: toLevelId,
      crossings: crossings,
      intermediateVerticalLengthMm: intermediateLength,
      verticalLegs: verticalLegs,
    );
  }
}
