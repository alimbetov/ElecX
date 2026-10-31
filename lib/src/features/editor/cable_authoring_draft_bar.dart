import 'package:flutter/material.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'manual_cable_draft_persistence.dart';
import 'port_driven_cable_authoring.dart';

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
    final binding = controller.portDrivenCableStartBinding;
    final selectedComponent = controller.p2.selectedComponent;
    final selectedPorts = selectedComponent == null
        ? const <ElectricalPortDefinition>[]
        : controller.cableAuthoringPortsFor(selectedComponent);
    final transitionDisconnected = hasDraft &&
        controller.activeSurface != null &&
        controller.activeRouteSegment == null;
    final canCommit = controller.routeSegments.any(
      (segment) => segment.points.length >= 2,
    );

    return Material(
      key: const ValueKey('cable-authoring-draft-bar'),
      elevation: 4,
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.alt_route, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Прокладка кабеля · $host',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  '${controller.routeLengthMm.round()} мм',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              transitionDisconnected
                  ? 'Переход на эту поверхность не подтверждён физическим '
                      'примыканием. Вернитесь к предыдущей поверхности и '
                      'доведите точку до общего ребра.'
                  : binding != null
                      ? 'Старт закреплён за ${binding.componentId}:'
                          '${binding.portId}. Первая точка совпадает с '
                          'физической позицией порта; продолжайте маршрут.'
                      : hasDraft
                          ? '$points точек. Для Wall↔Ceiling доведите кабель до '
                              'верхнего ребра стены и затем выберите «Потолок».'
                          : selectedComponent != null && selectedPorts.isNotEmpty
                              ? 'Выбран ${selectedComponent.label}. Укажите '
                                  'физический порт — первая точка будет создана '
                                  'точно в позиции компонента.'
                              : 'Выберите компонент или поверхность. Клик '
                                  'добавляет точку маршрута.',
              key: transitionDisconnected
                  ? const ValueKey('cable-host-transition-warning')
                  : binding != null
                      ? const ValueKey('cable-port-start-bound')
                      : null,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!hasDraft &&
                selectedComponent != null &&
                selectedPorts.isNotEmpty) ...[
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final port in selectedPorts)
                    FilledButton.tonalIcon(
                      key: ValueKey('cable-start-port-${port.id}'),
                      onPressed: () => _startFromPort(context, port),
                      icon: const Icon(Icons.cable_outlined, size: 18),
                      label: Text('${port.id} · ${port.kind.name}'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _wallHostMenu(context),
                ChoiceChip(
                  key: const ValueKey('cable-host-ceiling'),
                  selected: controller.activeSurface?.type ==
                      SurfacePlaneType.ceiling,
                  onSelected: controller.selectedSpace == null
                      ? null
                      : (_) => controller.showCeiling(),
                  avatar: const Icon(Icons.view_in_ar_outlined, size: 16),
                  label: const Text('Потолок'),
                ),
                ChoiceChip(
                  key: const ValueKey('cable-host-floor'),
                  selected:
                      controller.activeSurface?.type == SurfacePlaneType.floor,
                  onSelected: controller.selectedSpace == null
                      ? null
                      : (_) => controller.showFloor(),
                  avatar: const Icon(Icons.grid_on, size: 16),
                  label: const Text('Пол'),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  key: const ValueKey('cable-draft-cancel'),
                  onPressed: () =>
                      controller.cancelManualCableDraft(exitTool: true),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Отмена · Esc'),
                ),
                FilledButton.icon(
                  key: const ValueKey('cable-draft-commit'),
                  onPressed: canCommit && !transitionDisconnected
                      ? () => _commit(context)
                      : null,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Сохранить · Enter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wallHostMenu(BuildContext context) {
    final space = controller.selectedSpace;
    final wallCount = space?.boundary.vertices.length ?? 0;
    final active = controller.activeSurface;
    final activeWall = active?.type == SurfacePlaneType.wall;
    final label =
        activeWall ? 'Стена ${(active?.wallIndex ?? 0) + 1}' : 'Стена';

    return PopupMenuButton<int>(
      key: const ValueKey('cable-host-wall-menu'),
      enabled: wallCount > 0,
      tooltip: 'Выбрать стену для прокладки',
      onSelected: controller.showWall,
      itemBuilder: (context) => [
        for (var index = 0; index < wallCount; index++)
          PopupMenuItem<int>(
            key: ValueKey('cable-host-wall-$index'),
            value: index,
            child: Text('Стена ${index + 1}'),
          ),
      ],
      child: Chip(
        avatar: const Icon(Icons.crop_landscape, size: 16),
        label: Text(label),
        backgroundColor:
            activeWall ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
    );
  }

  void _startFromPort(BuildContext context, ElectricalPortDefinition port) {
    if (controller.beginPortDrivenCableFromSelectedPort(port.id)) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Не удалось начать трассу от выбранного порта: проверьте слой, '
          'выбор компонента и отсутствие другого активного черновика.',
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
    if (surface == null) return 'выберите поверхность';
    return switch (surface.type) {
      SurfacePlaneType.wall => 'Стена ${(surface.wallIndex ?? 0) + 1}',
      SurfacePlaneType.ceiling => 'Потолок',
      SurfacePlaneType.floor => 'Пол',
    };
  }
}
