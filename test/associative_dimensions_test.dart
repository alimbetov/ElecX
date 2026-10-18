import 'package:elecx/src/domain/associative_dimensions.dart';
import 'package:elecx/src/features/editor/associative_dimension_commands.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editing room width mutates geometry and keeps left edge fixed', () {
    final controller = EditorController.demo();
    final before = controller.selectedSpace!.boundary.bounds;
    final width = controller.selectedPlanDimensions.firstWhere(
      (dimension) =>
          dimension.kind == AssociativeDimensionKind.roomWidth,
    );

    final result = controller.editAssociativeDimension(width, 5000);

    expect(result, isA<DimensionEditSuccess>());
    final after = controller.selectedSpace!.boundary.bounds;
    expect(after.left, before.left);
    expect(after.bottom, before.bottom);
    expect(after.width, 5000);
    expect(
      controller.selectedSpace!.referenceFrame.origin,
      after.center,
    );
  });

  test('dimension edit rejects dimensions below minimum room size', () {
    final controller = EditorController.demo();
    final height = controller.selectedPlanDimensions.firstWhere(
      (dimension) =>
          dimension.kind == AssociativeDimensionKind.roomHeight,
    );

    final result = controller.editAssociativeDimension(height, 299);

    expect(result, isA<DimensionEditFailure>());
    expect(controller.selectedSpace!.boundary.bounds.height, 3200);
  });
}
