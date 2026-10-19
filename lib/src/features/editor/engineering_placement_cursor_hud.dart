import 'package:flutter/material.dart';

import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'engineering_placement_cursor_session.dart';

class EngineeringPlacementCursorHud extends StatelessWidget {
  const EngineeringPlacementCursorHud({
    required this.controller,
    super.key,
  });

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller.p2,
        controller.placementCursor,
        controller.componentCatalog,
      ]),
      builder: (context, _) {
        final componentTypeId = controller.placementCursor.activeComponentTypeId;
        if (componentTypeId == null || controller.activeSurface == null) {
          return const SizedBox.shrink();
        }
        final cursor = controller.placementCursor.ensure();
        if (cursor == null) return const SizedBox.shrink();
        final entry = controller.componentCatalog.byId(cursor.componentTypeId);
        if (entry == null) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        final step = controller.selectedSpace?.grid.minorStepMm ?? 100;
        final validColor = cursor.isValid ? scheme.primary : scheme.error;

        return Material(
          elevation: 2,
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: validColor.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location, size: 15, color: validColor),
                    const SizedBox(width: 5),
                    Text(
                      entry.name,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    if (controller.placementCursor.repeatPlacement) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.repeat, size: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cursor.coordinateLabel,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${cursor.surface.type.name.toUpperCase()} · '
                  '${cursor.snapLabel ?? cursor.snapKind.name.toUpperCase()} · '
                  '${entry.systemClass.name} · шаг $step mm',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (controller.placementCursor.repeatPlacement) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Повтор: после установки режим останется активным',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NudgeButton(
                      icon: Icons.arrow_left,
                      tooltip: '← $step mm',
                      onPressed: () => controller.placementCursor.nudgeGrid(
                        dxSteps: -1,
                        dySteps: 0,
                      ),
                    ),
                    _NudgeButton(
                      icon: Icons.arrow_right,
                      tooltip: '→ $step mm',
                      onPressed: () => controller.placementCursor.nudgeGrid(
                        dxSteps: 1,
                        dySteps: 0,
                      ),
                    ),
                    _NudgeButton(
                      icon: Icons.arrow_upward,
                      tooltip: '↑ $step mm',
                      onPressed: () => controller.placementCursor.nudgeGrid(
                        dxSteps: 0,
                        dySteps: 1,
                      ),
                    ),
                    _NudgeButton(
                      icon: Icons.arrow_downward,
                      tooltip: '↓ $step mm',
                      onPressed: () => controller.placementCursor.nudgeGrid(
                        dxSteps: 0,
                        dySteps: -1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Установить (Enter)',
                      onPressed: cursor.isValid
                          ? controller.placementCursor.confirm
                          : null,
                      icon: const Icon(Icons.check, size: 18),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Отмена (Esc)',
                      onPressed: controller.placementCursor.cancel,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      );
}
