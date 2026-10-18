import '../../domain/associative_dimensions.dart';
import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import 'editor_controller.dart';

extension AssociativeDimensionCommands on EditorController {
  List<AssociativeDimension> get selectedPlanDimensions {
    final space = selectedSpace;
    if (space == null) return const [];
    final bounds = space.boundary.bounds;
    final editable = _isAxisAlignedRectangle(space.boundary);
    return [
      AssociativeDimension(
        id: '${space.id}:width',
        kind: AssociativeDimensionKind.roomWidth,
        ownerId: space.id,
        valueMm: bounds.width,
        editable: editable,
      ),
      AssociativeDimension(
        id: '${space.id}:height',
        kind: AssociativeDimensionKind.roomHeight,
        ownerId: space.id,
        valueMm: bounds.height,
        editable: editable,
      ),
    ];
  }

  DimensionEditResult editAssociativeDimension(
    AssociativeDimension dimension,
    int valueMm,
  ) {
    if (valueMm < 300) {
      return const DimensionEditFailure(
        'Размер помещения не может быть меньше 300 mm.',
      );
    }
    final space = selectedSpace;
    if (space == null || space.id != dimension.ownerId) {
      return const DimensionEditFailure('Помещение больше не выбрано.');
    }
    if (!_isAxisAlignedRectangle(space.boundary)) {
      return const DimensionEditFailure(
        'Редактирование размера V1 поддерживает только прямоугольные помещения.',
      );
    }

    final bounds = space.boundary.bounds;
    final nextBoundary = switch (dimension.kind) {
      AssociativeDimensionKind.roomWidth => MmPolygon.rectangle(
          MmPoint(bounds.left, bounds.bottom),
          MmPoint(bounds.left + valueMm, bounds.top),
        ),
      AssociativeDimensionKind.roomHeight => MmPolygon.rectangle(
          MmPoint(bounds.left, bounds.bottom),
          MmPoint(bounds.right, bounds.bottom + valueMm),
        ),
    };

    final nextSpace = EngineeringSpace(
      id: space.id,
      name: space.name,
      type: space.type,
      boundary: nextBoundary,
      referenceFrame: RoomReferenceFrame(origin: nextBoundary.bounds.center),
      grid: space.grid,
    );
    level = level.copyWith(
      spaces: [
        for (final item in level.spaces)
          if (item.id == space.id) nextSpace else item,
      ],
    );
    notifyListeners();

    final nextValue = switch (dimension.kind) {
      AssociativeDimensionKind.roomWidth => nextBoundary.bounds.width,
      AssociativeDimensionKind.roomHeight => nextBoundary.bounds.height,
    };
    return DimensionEditSuccess(
      AssociativeDimension(
        id: dimension.id,
        kind: dimension.kind,
        ownerId: dimension.ownerId,
        valueMm: nextValue,
        editable: true,
      ),
    );
  }

  bool _isAxisAlignedRectangle(MmPolygon polygon) {
    if (polygon.vertices.length != 4) return false;
    final bounds = polygon.bounds;
    final expected = {
      MmPoint(bounds.left, bounds.bottom),
      MmPoint(bounds.right, bounds.bottom),
      MmPoint(bounds.right, bounds.top),
      MmPoint(bounds.left, bounds.top),
    };
    return polygon.vertices.toSet().containsAll(expected);
  }
}
