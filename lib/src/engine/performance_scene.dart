import '../domain/geometry.dart';
import '../domain/project_model.dart';

final class PerformanceScene {
  const PerformanceScene({required this.spaces});

  final List<EngineeringSpace> spaces;

  static PerformanceScene grid({
    int columns = 100,
    int rows = 100,
    int roomWidthMm = 4000,
    int roomHeightMm = 3000,
    int gapMm = 500,
  }) {
    if (columns <= 0 || rows <= 0) {
      throw ArgumentError('columns and rows must be positive.');
    }
    final spaces = <EngineeringSpace>[];
    var sequence = 0;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final left = column * (roomWidthMm + gapMm);
        final bottom = row * (roomHeightMm + gapMm);
        final boundary = MmPolygon.rectangle(
          MmPoint(left, bottom),
          MmPoint(left + roomWidthMm, bottom + roomHeightMm),
        );
        spaces.add(
          EngineeringSpace(
            id: 'bench-room-${sequence++}',
            name: 'Room $sequence',
            type: SpaceType.room,
            boundary: boundary,
            referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
          ),
        );
      }
    }
    return PerformanceScene(spaces: List.unmodifiable(spaces));
  }
}
