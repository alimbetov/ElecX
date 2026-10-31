import 'package:flutter/material.dart';

import '../../domain/surfaces.dart';
import 'editor_controller.dart';
import 'manual_cable_draft_persistence.dart';

/// User-visible lifecycle/status surface for manual cable authoring.
///
/// This widget intentionally delegates persistence to
/// [ManualCableDraftPersistence]. It does not manufacture a parallel route
/// model: points remain transient until the production physical route commit
/// boundary accepts the complete draft.
class CableAuthoringDraftBar extends StatelessWidget {
  const CableAuthoringDraftBar({
    required this.controller,
    super.key,
  });

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.tool != EditorTool.cableRoute) {
      return const SizedBox.shrink();
    }

    final host = _hostLabel(controller.activeSurface);
    final points = controller.routeSegments.fold<int>(
      0,
      (sum, segment) => sum + segment.points.length,
    );
    final hasDraft = controller.routeSegments.isNotEmpty;
    final canCommit = controller.routeSegments.any(
      (segment) => segment.points.length >= 2,
    );

    return Material(
      key: const ValueKey('cable-authoring-draft-bar'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.alt_route, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Прокладка кабеля · $host',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDraft
                        ? '$points точек · ${controller.routeLengthMm.round()} мм. '
                            'Для перехода на стену/потолок выберите соседнюю '
                            'поверхность в точке их физического примыкания.'
                        : 'Начните у порта компонента. Клик добавляет точку; '
                            'Стена/Потолок/Пол выше меняют физическую поверхность.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              key: const ValueKey('cable-draft-cancel'),
              onPressed: () => controller.cancelManualCableDraft(exitTool: true),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Отмена · Esc'),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              key: const ValueKey('cable-draft-commit'),
              onPressed: canCommit ? () => _commit(context) : null,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Сохранить · Enter'),
            ),
          ],
        ),
      ),
    );
  }

  void _commit(BuildContext context) {
    final committed = controller.finishManualCableDraft();
    if (committed) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Маршрут не сохранён: начало и конец должны попасть на совместимые '
          'порты, а каждый переход между поверхностями — иметь физическое '
          'подтверждение.',
        ),
      ),
    );
  }

  static String _hostLabel(RoomSurfaceRef? surface) {
    if (surface == null) return 'поверхность не выбрана';
    return switch (surface.type) {
      SurfacePlaneType.wall => 'Стена ${(surface.wallIndex ?? 0) + 1}',
      SurfacePlaneType.ceiling => 'Потолок',
      SurfacePlaneType.floor => 'Пол',
    };
  }
}
