import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/associative_dimensions.dart';
import '../../domain/geometry.dart';
import 'associative_dimension_commands.dart';
import 'editor_controller.dart';
import 'spatial_canvas.dart';

class PlanDimensionLayer extends StatelessWidget {
  const PlanDimensionLayer({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final space = controller.selectedSpace;
        final dimensions = controller.selectedPlanDimensions;
        if (space == null ||
            dimensions.isEmpty ||
            !controller.dimensionsVisible) {
          return SpatialCanvas(controller: controller);
        }

        final bounds = space.boundary.bounds;
        final bottomLeft = _toScreen(
          MmPoint(bounds.left, bounds.bottom),
          size,
        );
        final bottomRight = _toScreen(
          MmPoint(bounds.right, bounds.bottom),
          size,
        );
        final topRight = _toScreen(MmPoint(bounds.right, bounds.top), size);

        final widthDimension = dimensions.firstWhere(
          (dimension) =>
              dimension.kind == AssociativeDimensionKind.roomWidth,
        );
        final heightDimension = dimensions.firstWhere(
          (dimension) =>
              dimension.kind == AssociativeDimensionKind.roomHeight,
        );

        final widthCenter = Offset(
          (bottomLeft.dx + bottomRight.dx) / 2,
          math.max(bottomLeft.dy, bottomRight.dy) + 28,
        );
        final heightCenter = Offset(
          topRight.dx + 46,
          (topRight.dy + bottomRight.dy) / 2,
        );

        return Stack(
          children: [
            Positioned.fill(child: SpatialCanvas(controller: controller)),
            _dimensionButton(
              context,
              dimension: widthDimension,
              center: widthCenter,
            ),
            _dimensionButton(
              context,
              dimension: heightDimension,
              center: heightCenter,
            ),
          ],
        );
      },
    );
  }

  Widget _dimensionButton(
    BuildContext context, {
    required AssociativeDimension dimension,
    required Offset center,
  }) {
    const width = 82.0;
    const height = 28.0;
    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
      width: width,
      height: height,
      child: Tooltip(
        message: dimension.editable
            ? 'Нажмите, чтобы изменить геометрию'
            : 'Этот размер пока только для чтения',
        child: TextButton(
          onPressed:
              dimension.editable ? () => _editDimension(context, dimension) : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(width, height),
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(
                  alpha: 0.88,
                ),
          ),
          child: Text(
            dimension.label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }

  Future<void> _editDimension(
    BuildContext context,
    AssociativeDimension dimension,
  ) async {
    final textController = TextEditingController(
      text: dimension.valueMm.toString(),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить размер'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Размер',
            suffixText: 'mm',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (raw) {
            final parsed = int.tryParse(raw.trim());
            if (parsed != null) Navigator.of(context).pop(parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(textController.text.trim());
              if (parsed != null) Navigator.of(context).pop(parsed);
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (value == null || !context.mounted) return;

    final result = controller.editAssociativeDimension(dimension, value);
    if (result case DimensionEditFailure(:final message)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Offset _toScreen(MmPoint point, Size size) {
    final base = Offset(
      point.x / SpatialCanvas.worldWidthMm * size.width,
      size.height - point.y / SpatialCanvas.worldHeightMm * size.height,
    );
    final center = Offset(size.width / 2, size.height / 2);
    return center + (base - center) * controller.zoom;
  }
}
