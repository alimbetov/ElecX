import 'package:flutter/material.dart';

import '../../engine/normative_route_engine.dart';
import 'cad_visual_tokens.dart';

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
    this.validation,
    this.previewInvalid = false,
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
  final RouteConstraintResult? validation;

  /// True when an active interaction has no committable semantic preview yet,
  /// for example while a cable endpoint is outside every compatible port.
  final bool previewInvalid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _status(scheme);
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
            Text(
              'Редактор трассы',
              style: Theme.of(context).textTheme.labelLarge,
            ),
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
                style: Theme.of(context).textTheme.labelSmall),
            if (status != null) ...[
              const SizedBox(height: 7),
              Semantics(
                liveRegion: true,
                label: status.text,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: status.color.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(status.icon, size: 16, color: status.color),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          status.text,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: status.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _CableValidationStatus? _status(ColorScheme scheme) {
    if (previewInvalid) {
      return _CableValidationStatus(
        icon: Icons.error_outline,
        color: CadVisualTokens.invalidPreview(scheme),
        text:
            'Недопустимый preview: выберите совместимый порт или допустимую трассу.',
      );
    }
    final result = validation;
    if (result == null) return null;
    final errors = result.issues
        .where((issue) => issue.severity == RouteConstraintSeverity.error)
        .toList(growable: false);
    if (errors.isNotEmpty) {
      return _CableValidationStatus(
        icon: Icons.error_outline,
        color: CadVisualTokens.invalidPreview(scheme),
        text: errors.first.message,
      );
    }
    final warnings = result.issues
        .where((issue) => issue.severity == RouteConstraintSeverity.warning)
        .toList(growable: false);
    if (warnings.isNotEmpty) {
      return _CableValidationStatus(
        icon: Icons.warning_amber_rounded,
        color: CadVisualTokens.warning(scheme),
        text: warnings.first.message,
      );
    }
    return _CableValidationStatus(
      icon: Icons.check_circle_outline,
      color: CadVisualTokens.validPreview(scheme),
      text: 'Маршрут допустим к фиксации.',
    );
  }
}

final class _CableValidationStatus {
  const _CableValidationStatus({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;
}
