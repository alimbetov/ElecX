import 'package:flutter/material.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'manual_cable_draft_persistence.dart';
import 'port_driven_cable_authoring.dart';
import 'surface_transition_navigator.dart';

/// Direct production entry points for placement and port-driven cable editing.
/// Uses existing canonical editor sessions; does not manufacture a connection.
class ComponentConnectionActions extends StatelessWidget {
  const ComponentConnectionActions({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([
          controller,
          controller.p2,
          controller.planPortPair,
        ]),
        builder: (context, _) {
          final selected = controller.p2.selectedComponent;
          final binding = controller.portDrivenCableStartBinding;
          final planPair = controller.planPortPair;
          if (selected == null && binding == null && !planPair.active) {
            return const SizedBox.shrink();
          }
          final hasDraft = controller.routeSegments.isNotEmpty;
          final ports = selected == null
              ? const <ElectricalPortDefinition>[]
              : controller.cableAuthoringPortsFor(selected);
          final targets = binding == null
              ? const <PortDrivenCableCompletionTarget>[]
              : controller.compatiblePortDrivenCableTargets;
          final ready = binding != null &&
              controller.portDrivenCableReadyToFinish &&
              controller.activeRouteSegment != null;
          final blockedRemote = binding != null &&
              controller.blockedCrossRoomCableTargets.isNotEmpty;
          final sourceLabel = binding == null
              ? null
              : controller.p2.components
                  .where((item) => item.id == binding.componentId)
                  .map((item) => item.label)
                  .firstOrNull;
          return Card(
            key: const ValueKey('component-connection-actions'),
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected == null
                        ? 'Прокладка кабеля'
                        : 'Устройство · ${selected.label}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: 6),
                    Text('Поверхность: ${_surfaceName(selected)}'),
                    Text(
                      'Координаты на поверхности: '
                      '${selected.position.xMm.toStringAsFixed(0)} × '
                      '${selected.position.yMm.toStringAsFixed(0)} мм',
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      key: const ValueKey('component-open-host'),
                      onPressed: hasDraft || planPair.active
                          ? null
                          : () {
                              if (!SurfaceTransitionNavigator.navigate(
                                controller,
                                selected.surface,
                              )) {
                                _showFailure(
                                  context,
                                  'Не удалось открыть поверхность устройства. '
                                  'Проверьте привязку к комнате и стене.',
                                );
                              }
                            },
                      icon: const Icon(Icons.open_in_full),
                      label: const Text('Открыть поверхность для перемещения'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (planPair.active) ...[
                    Text(
                      'Соединение на плане: '
                      '${planPair.sourceComponent?.label ?? planPair.sourceComponentId}'
                      ' · ${planPair.sourcePortId}',
                      key: const ValueKey('plan-port-source-status'),
                    ),
                    const SizedBox(height: 5),
                    if (!planPair.revisionCurrent)
                      const Text(
                        'Проект изменился. Отмените выбор и начните снова.',
                        key: ValueKey('plan-port-stale-warning'),
                      )
                    else if (planPair.choosingTarget)
                      const Text(
                        'Щёлкните по целевому устройству на плане. '
                        'Совместимый порт можно выбрать мышью.',
                        key: ValueKey('plan-port-pick-target-hint'),
                      )
                    else
                      Text(
                        'Приёмник: '
                        '${planPair.targetComponent?.label ?? planPair.targetComponentId}'
                        ' · ${planPair.targetPortId}. '
                        'Прямая трасса — кандидат, не нормативное подтверждение.',
                        key: const ValueKey('plan-port-preview-hint'),
                      ),
                    const SizedBox(height: 5),
                    FilledButton.icon(
                      key: const ValueKey('plan-port-apply'),
                      onPressed: planPair.ready
                          ? () {
                              if (!planPair.applyStraightRoute()) {
                                _showFailure(
                                  context,
                                  'Прямую физическую трассу построить нельзя. '
                                  'Используйте ручную прокладку по поверхности.',
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Проверить и проложить'),
                    ),
                    TextButton(
                      key: const ValueKey('plan-port-cancel'),
                      onPressed: planPair.reset,
                      child: const Text('Отмена соединения'),
                    ),
                  ] else if (binding == null && !hasDraft) ...[
                    const Text(
                      'Выберите начальный порт. Затем укажите путь и конечный '
                      'порт на той же поверхности или через подтверждённый '
                      'строительный переход.',
                    ),
                    if (ports.isEmpty)
                      const Text(
                          'У устройства нет доступных портов для кабеля.')
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final port in ports)
                            FilledButton.tonalIcon(
                              key:
                                  ValueKey('component-connect-port-${port.id}'),
                              onPressed: () {
                                if (!controller
                                    .beginPortDrivenCableFromSelectedPort(
                                  port.id,
                                )) {
                                  _showFailure(
                                    context,
                                    'Не удалось начать кабель от ${port.id}. '
                                    'Проверьте слои и физическую поверхность.',
                                  );
                                }
                              },
                              icon: const Icon(Icons.cable),
                              label: Text('Кабель от ${port.id}'),
                            ),
                            OutlinedButton.icon(
                              key: ValueKey('plan-port-start-${port.id}'),
                              onPressed:
                                  controller.viewMode == EditorViewMode.plan
                                      ? () {
                                          if (!planPair.start(
                                            componentId: selected!.id,
                                            portId: port.id,
                                          )) {
                                            _showFailure(
                                              context,
                                              'Не удалось начать выбор портов '
                                              'на плане. Проверьте слои и черновик.',
                                            );
                                          }
                                        }
                                      : null,
                              icon: const Icon(Icons.link),
                              label: Text('Соединить на плане · ${port.id}'),
                            ),
                        ],
                      ),
                  ] else if (binding != null) ...[
                    Text(
                      'Начало трассы: ${sourceLabel ?? binding.componentId}'
                      ' · порт ${binding.portId}',
                      key: const ValueKey('component-cable-source'),
                    ),
                    const SizedBox(height: 6),
                    if (ready)
                      const Text(
                        'Конечный порт привязан. Проверьте маршрут и завершите.',
                        key: ValueKey('component-cable-ready'),
                      )
                    else
                      const Text(
                        'Проложите кабель до приёмника на поверхности. '
                        'Выберите его совместимый порт ниже.',
                        key: ValueKey('component-cable-routing'),
                      ),
                    if (targets.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      const Text('Совместимые конечные порты'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final target in targets)
                            ActionChip(
                              key: ValueKey(
                                'component-complete-${target.componentId}-${target.portId}',
                              ),
                              label: Text(
                                '${target.componentLabel} · ${target.portId}',
                              ),
                              onPressed: () {
                                if (!controller
                                    .snapPortDrivenCableCompletionTarget(
                                  componentId: target.componentId,
                                  portId: target.portId,
                                )) {
                                  _showFailure(
                                    context,
                                    'Конечный порт нельзя привязать: '
                                    'проверьте непрерывность маршрута.',
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                    if (blockedRemote) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Устройства в других комнатах требуют подтверждённой '
                        'проходки. Прямое соединение заблокировано.',
                        key: ValueKey('component-cross-room-blocked'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const ValueKey('component-finish-route'),
                      onPressed: ready
                          ? () {
                              if (!controller.finishManualCableDraft()) {
                                _showFailure(
                                  context,
                                  'Не удалось сохранить кабель: проверьте '
                                  'геометрию, порты и строительные проходки.',
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Завершить кабель'),
                    ),
                  ] else
                    const Text(
                      'Идёт ручная прокладка. Завершите или отмените '
                      'черновик в панели трассы.',
                    ),
                  if (hasDraft || binding != null) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      key: const ValueKey('component-cancel-route'),
                      onPressed: () =>
                          controller.cancelManualCableDraft(exitTool: true),
                      icon: const Icon(Icons.close),
                      label: const Text('Отменить черновик кабеля'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );

  String _surfaceName(ElectricalComponentPlacement component) {
    final surface = component.surface;
    final roomName = controller.level.spaces
            .where((space) => space.id == surface.spaceId)
            .map((space) => space.name)
            .firstOrNull ??
        surface.spaceId;
    final typeLabel = switch (surface.type) {
      SurfacePlaneType.wall => 'Стена',
      SurfacePlaneType.ceiling => 'Потолок',
      SurfacePlaneType.floor => 'Пол',
    };
    return '$roomName · $typeLabel'
        '${surface.wallIndex == null ? '' : ' · №${surface.wallIndex! + 1}'}';
  }

  static void _showFailure(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
