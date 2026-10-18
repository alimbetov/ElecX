import '../domain/geometry.dart';
import '../domain/project_model.dart';
import '../domain/surfaces.dart';

/// Logical placement of one room surface in the Room World overview.
/// Coordinates are normalized layout units, not pixels or millimetres.
final class RoomWorldTile {
  const RoomWorldTile({
    required this.surface,
    required this.column,
    required this.row,
    required this.weight,
  });

  final RoomSurfaceRef surface;
  final int column;
  final int row;

  /// Relative horizontal weight used by the UI to preserve wall proportions.
  final double weight;
}

/// Gravity-aware connected layout for the six-or-more physical faces of a room.
///
/// Row 0: ceiling (always above).
/// Row 1: ordered walls (physical boundary order).
/// Row 2: floor (always below).
abstract final class RoomWorldLayout {
  static List<RoomWorldTile> build(EngineeringSpace space) {
    final walls = RoomSurfaceResolver.walls(space);
    return List.unmodifiable([
      RoomWorldTile(
        surface: RoomSurfaceRef.ceiling(space.id),
        column: 0,
        row: 0,
        weight: _horizontalWeight(space.boundary.bounds),
      ),
      for (var i = 0; i < walls.length; i++)
        RoomWorldTile(
          surface: walls[i].ref,
          column: i,
          row: 1,
          weight: walls[i].lengthMm,
        ),
      RoomWorldTile(
        surface: RoomSurfaceRef.floor(space.id),
        column: 0,
        row: 2,
        weight: _horizontalWeight(space.boundary.bounds),
      ),
    ]);
  }

  static double _horizontalWeight(MmBounds bounds) =>
      bounds.width <= 0 ? 1 : bounds.width.toDouble();
}
