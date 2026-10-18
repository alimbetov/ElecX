import '../domain/project_model.dart';
import '../domain/surfaces.dart';
import 'plan_pull_measure.dart';

/// Canonical engineering dimensions for one room wall.
///
/// L = physical wall edge length in plan.
/// D = room depth from this edge to the nearest parallel boundary.
/// H = wall profile height.
///
/// D is intentionally not called wall thickness: physical wall thickness is
/// not yet represented by the spatial domain model.
final class WallDimensionSet {
  const WallDimensionSet({
    required this.lengthMm,
    required this.heightMm,
    this.depthMm,
  });

  final int lengthMm;
  final int? depthMm;
  final int heightMm;

  String get lengthLabel => 'L $lengthMm mm';
  String? get depthLabel => depthMm == null ? null : 'D $depthMm mm';
  String get heightLabel => 'H $heightMm mm';
}

abstract final class WallDimensionResolver {
  static WallDimensionSet resolve({
    required EngineeringSpace space,
    required int wallIndex,
  }) {
    final wall = RoomSurfaceResolver.wall(space, wallIndex);
    final depth = PlanPullMeasureResolver.nearestParallelBoundary(
      space: space,
      edgeIndex: wallIndex,
    );
    return WallDimensionSet(
      lengthMm: wall.lengthMm.round(),
      depthMm: depth?.distanceMm,
      heightMm: wall.heightMm,
    );
  }
}
