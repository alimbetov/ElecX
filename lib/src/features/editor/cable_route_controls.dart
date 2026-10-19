import 'package:flutter/material.dart';

import '../../engine/normative_route_engine.dart';

class CableRouteControls extends StatelessWidget {
  const CableRouteControls({
    required this.mode,
    required this.onModeChanged,
    required this.segmentFocused,
    required this.segmentLocked,
    required this.onToggleSegmentLock,
    required this.pointFocused,
    required this.pointIsWaypoint,
    required this.onToggleWaypoint,
    super.key,
  });

  final CableRoutingMode mode;
  final ValueChanged<CableRoutingMode> onModeChanged;
  final bool segmentFocused;
  final bool segmentLocked;
  final VoidCallback? onToggleSegmentLock;
  final bool pointFocused;
  final bool pointIsWaypoint;
  final VoidCallback? onToggleWaypoint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Редактор трассы',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<CableRoutingMode>(
              segments: const [
                ButtonSegment(
                  value: CableRoutingMode.auto,
                  label: Text('AUTO'),
                  icon: Icon(Icons.auto_fix_high, size: 16),
                ),
                ButtonSegment(
                  value: CableRoutingMode.assisted,
                  label: Text('ASSIST'),
                  icon: Icon(Icons.assistant, size: 16),
                ),
                ButtonSegment(
                  value: CableRoutingMode.manualGuardrails,
                  label: Text('MANUAL'),
                  icon: Icon(Icons.edit_road, size: 16),
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (value) => onModeChanged(value.single),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: segmentLocked
                      ? 'Разблокировать выбранный сегмент'
                      : 'Зафиксировать выбранный сегмент',
                  child: IconButton.filledTonal(
                    onPressed: segmentFocused ? onToggleSegmentLock : null,
                    icon: Icon(
                      segmentLocked ? Icons.lock : Icons.lock_open,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: pointIsWaypoint
                      ? 'Снять обязательную точку'
                      : 'Сделать вершину обязательной точкой',
                  child: IconButton.filledTonal(
                    onPressed: pointFocused ? onToggleWaypoint : null,
                    icon: Icon(
                      pointIsWaypoint ? Icons.flag : Icons.outlined_flag,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              switch (mode) {
                CableRoutingMode.auto => 'Автотрасса и магнитные порты',
                CableRoutingMode.assisted =>
                  'Инженер двигает геометрию, сетка и нормы помогают',
                CableRoutingMode.manualGuardrails =>
                  'Свободное редактирование с обязательной проверкой',
              },
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
