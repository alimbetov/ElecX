import 'package:flutter/material.dart';

import 'editor_ui_tokens.dart';

class CanvasComponentControls extends StatelessWidget {
  const CanvasComponentControls({
    required this.label,
    required this.stepMm,
    required this.onStepChanged,
    required this.onMove,
    required this.onDelete,
    super.key,
  });

  final String label;
  final int stepMm;
  final ValueChanged<int> onStepChanged;
  final void Function(int dxSteps, int dySteps) onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
      elevation: 3,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_with, size: 16),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MoveButton(
                  icon: Icons.arrow_left,
                  tooltip: 'Влево на $stepMm мм',
                  onPressed: () => onMove(-1, 0),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MoveButton(
                      icon: Icons.arrow_drop_up,
                      tooltip: 'Вверх на $stepMm мм',
                      onPressed: () => onMove(0, 1),
                    ),
                    _MoveButton(
                      icon: Icons.arrow_drop_down,
                      tooltip: 'Вниз на $stepMm мм',
                      onPressed: () => onMove(0, -1),
                    ),
                  ],
                ),
                _MoveButton(
                  icon: Icons.arrow_right,
                  tooltip: 'Вправо на $stepMm мм',
                  onPressed: () => onMove(1, 0),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: EditorUiTokens.minimumTouchTarget,
                  child: PopupMenuButton<int>(
                    tooltip: 'Шаг перемещения',
                    initialValue: stepMm,
                    onSelected: onStepChanged,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 10, child: Text('10 мм')),
                      PopupMenuItem(value: 100, child: Text('100 мм')),
                      PopupMenuItem(value: 500, child: Text('500 мм')),
                    ],
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('$stepMm мм'),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Удалить компонент',
                  visualDensity: VisualDensity.standard,
                  constraints: const BoxConstraints.tightFor(
                    width: EditorUiTokens.minimumTouchTarget,
                    height: EditorUiTokens.minimumTouchTarget,
                  ),
                  color: scheme.error,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.standard,
    constraints: const BoxConstraints.tightFor(
      width: EditorUiTokens.minimumTouchTarget,
      height: EditorUiTokens.minimumTouchTarget,
    ),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    icon: Icon(icon, size: 22),
  );
}
