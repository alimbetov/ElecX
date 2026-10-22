import 'package:flutter/material.dart';

import 'editor_ui_tokens.dart';

class CanvasViewportNavigator extends StatelessWidget {
  const CanvasViewportNavigator({
    required this.onPan,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    super.key,
  });

  final void Function(int dxSteps, int dySteps) onPan;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
      elevation: 3,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavButton(
              icon: Icons.keyboard_arrow_up,
              tooltip: 'Сместить фокус вверх',
              onPressed: () => onPan(0, 1),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavButton(
                  icon: Icons.keyboard_arrow_left,
                  tooltip: 'Сместить фокус влево',
                  onPressed: () => onPan(-1, 0),
                ),
                _NavButton(
                  icon: Icons.center_focus_strong_outlined,
                  tooltip: 'Вписать чертёж',
                  onPressed: onFit,
                ),
                _NavButton(
                  icon: Icons.keyboard_arrow_right,
                  tooltip: 'Сместить фокус вправо',
                  onPressed: () => onPan(1, 0),
                ),
              ],
            ),
            _NavButton(
              icon: Icons.keyboard_arrow_down,
              tooltip: 'Сместить фокус вниз',
              onPressed: () => onPan(0, -1),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavButton(
                  icon: Icons.remove,
                  tooltip: 'Отдалить',
                  onPressed: onZoomOut,
                ),
                _NavButton(
                  icon: Icons.add,
                  tooltip: 'Приблизить',
                  onPressed: onZoomIn,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
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
    icon: Icon(icon, size: 20),
  );
}
