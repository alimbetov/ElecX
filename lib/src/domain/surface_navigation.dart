import 'project_model.dart';
import 'surfaces.dart';

enum WallNavigationEdge { start, end, floor, ceiling }

abstract final class SurfaceNavigationResolver {
  static RoomSurfaceRef targetForWallEdge({
    required EngineeringSpace space,
    required int wallIndex,
    required WallNavigationEdge edge,
  }) {
    final wallCount = space.boundary.vertices.length;
    _validateWallIndex(wallIndex, wallCount);

    return switch (edge) {
      WallNavigationEdge.floor => RoomSurfaceRef.floor(space.id),
      WallNavigationEdge.ceiling => RoomSurfaceRef.ceiling(space.id),
      WallNavigationEdge.start => RoomSurfaceRef.wall(
          space.id,
          (wallIndex - 1 + wallCount) % wallCount,
        ),
      WallNavigationEdge.end => RoomSurfaceRef.wall(
          space.id,
          (wallIndex + 1) % wallCount,
        ),
    };
  }

  static RoomSurfaceRef targetForHorizontalBoundary({
    required EngineeringSpace space,
    required int boundaryEdgeIndex,
  }) {
    final wallCount = space.boundary.vertices.length;
    _validateWallIndex(boundaryEdgeIndex, wallCount);
    return RoomSurfaceRef.wall(space.id, boundaryEdgeIndex);
  }

  static void _validateWallIndex(int wallIndex, int wallCount) {
    if (wallIndex < 0 || wallIndex >= wallCount) {
      throw RangeError.range(wallIndex, 0, wallCount - 1, 'wallIndex');
    }
  }
}
