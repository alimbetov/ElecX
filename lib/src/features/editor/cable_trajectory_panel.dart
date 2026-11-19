import 'package:flutter/material.dart';

import '../../domain/surfaces.dart';
import 'cable_editor_ui_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'route_selection_session.dart';
import 'surface_transition_navigator.dart';

/// Entry point from the apartment plan into the actual editable host plane.
/// Wall height is never inferred from a flattened plan projection.
class CableTrajectoryPanel extends StatelessWidget {
  const CableTrajectoryPanel({required this.controller, super.key});
  final EditorController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([
          controller.cableUi,
          controller.routeSelection,
          controller.p2,
        ]),
        builder: (context, _) {
          if (!controller.cableUi.trajectoryEditing) {
            return const SizedBox.shrink();
          }
          final routes = controller.p2.routes;
          final selected = controller.routeSelection.selectedRoute;
          final names = {
            for (final c in controller.p2.components) c.id: c.label,
          };
          final rooms = {
            for (final s in controller.level.spaces) s.id: s.name,
          };
          return Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: SizedBox(
              width: 320,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(child: Text('Траектории кабелей')),
                      IconButton(
                        tooltip: 'Завершить редактирование трасс',
                        onPressed: () =>
                            controller.cableUi.setTrajectoryEditing(false),
                        icon: const Icon(Icons.close),
                      ),
                    ]),
                    if (routes.isEmpty) ...[
                      const Text('В проекте пока нет кабельных трасс.'),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        key: const ValueKey('trajectory-start-manual-route'),
                        onPressed: () {
                          controller.cableUi.setTrajectoryEditing(false);
                          controller.setTool(EditorTool.cableRoute);
                        },
                        icon: const Icon(Icons.alt_route),
                        label: const Text('Проложить кабель вручную'),
                      ),
                    ] else
                      DropdownButton<String>(
                        key: const ValueKey('trajectory-route-picker'),
                        isExpanded: true,
                        hint: const Text('Выберите кабель'),
                        value: selected?.id,
                        items: [
                          for (final route in routes)
                            DropdownMenuItem(
                              value: route.id,
                              child: Text(
                                '${names[route.target.componentId] ?? route.target.componentId} · ${route.id.substring(0, route.id.length.clamp(0, 8))}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          if (id != null) controller.routeSelection.select(id);
                        },
                      ),
                    if (selected == null && routes.isNotEmpty)
                      const Text(
                        '1. Выберите кабель в списке или нажмите на его '
                        'линию на плане. 2. Выберите поверхность. '
                        '3. Переместите изгиб и сохраните проект.',
                        key: ValueKey('trajectory-empty-selection-hint'),
                      ),
                    if (selected != null) ...[
                      CableTrajectorySummary(
                        sourceLabel: names[selected.source.componentId] ??
                            selected.source.componentId,
                        targetLabel: names[selected.target.componentId] ??
                            selected.target.componentId,
                        geometricLengthMm: selected.geometricLengthMm,
                        installationLengthMm: selected.installationLengthMm,
                        segmentCount: selected.segments.length,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Выберите участок ниже. Квадратная ручка '
                        'перемещает отрезок, круглая вершина меняет '
                        'поворот. Undo отменяет изменение.',
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (var i = 0; i < selected.segments.length; i++)
                            ActionChip(
                              key: ValueKey('trajectory-segment-$i'),
                              label: Text(
                                '${i + 1}: ${rooms[selected.segments[i].surface.spaceId] ?? ""} · ${switch (selected.segments[i].surface.type) {
                                  SurfacePlaneType.wall => 'Стена',
                                  SurfacePlaneType.ceiling => 'Потолок',
                                  SurfacePlaneType.floor => 'Пол',
                                }}',
                              ),
                              onPressed: () {
                                final routeId = selected.id;
                                if (SurfaceTransitionNavigator.navigate(
                                  controller,
                                  selected.segments[i].surface,
                                )) {
                                  controller.routeSelection.select(routeId);
                                  controller.cableUi.focusGeometry(
                                    routeId: routeId,
                                    segmentIndex: i,
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
}

/// Compact, read-only cable metrics sourced exclusively from the committed
/// physical route. No estimates or normative qualification are inferred.
class CableTrajectorySummary extends StatelessWidget {
  const CableTrajectorySummary({
    required this.sourceLabel,
    required this.targetLabel,
    required this.geometricLengthMm,
    required this.installationLengthMm,
    required this.segmentCount,
    super.key,
  });

  final String sourceLabel;
  final String targetLabel;
  final double geometricLengthMm;
  final double installationLengthMm;
  final int segmentCount;

  @override
  Widget build(BuildContext context) => Column(
        key: const ValueKey('trajectory-selected-summary'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Откуда: $sourceLabel'),
          Text('Куда: $targetLabel'),
          Text('Геометрическая длина: ${geometricLengthMm.toStringAsFixed(0)} мм'),
          Text('Монтажная длина: ${installationLengthMm.toStringAsFixed(0)} мм'),
          Text('Участков: $segmentCount'),
        ],
      );
}
