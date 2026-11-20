import 'package:flutter/material.dart';

import '../../domain/electrical_placement.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'port_driven_cable_authoring.dart';
import 'surface_transition_navigator.dart';

/// Direct production entry points for placement and port-driven cable editing.
/// Uses existing canonical editor sessions; does not manufacture a connection.
class ComponentConnectionActions extends StatelessWidget {
  const ComponentConnectionActions({required this.controller, super.key});

  final EditorController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller.p2,
        builder: (context, _) {
          final selected = controller.p2.selectedComponent;
          if (selected == null) {
            return const SizedBox.shrink();
          }
          final ports = controller.cableAuthoringPortsFor(selected);
          return Card(
            key: const ValueKey('component-connection-actions'),
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Устройство · ${selected.label}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
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
                    onPressed: () {
                      if (!SurfaceTransitionNavigator.navigate(
                        controller,
                        selected.surface,
                      )) {
                        _showFailure(
                          context,
                          'Не удалось открыть поверхность устройства. '
                          'Проверьте его привязку к комнате и стене.',
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('Открыть и переместить на поверхности'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Кабель: выберите начальный порт. Затем на поверхности '
                    'укажите точки маршрута и совместимый конечный порт.',
                  ),
                  if (ports.isEmpty)
                    const Text('У устройства нет доступных портов для кабеля.')
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final port in ports)
                          FilledButton.tonalIcon(
                            key: ValueKey('component-connect-port-${port.id}'),
                            onPressed: () {
                              if (!controller
                                  .beginPortDrivenCableFromSelectedPort(
                                port.id,
                              )) {
                                _showFailure(
                                  context,
                                  'Не удалось начать кабель от порта '
                                  '${port.id}. Проверьте активный черновик, '
                                  'слои и физическую поверхность.',
                                );
                              }
                            },
                            icon: const Icon(Icons.cable),
                            label: Text('Кабель от ${port.id}'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      );

  static String _surfaceName(ElectricalComponentPlacement component) {
    final surface = component.surface;
    return '${surface.spaceId} · ${surface.type.name}'
        '${surface.wallIndex == null ? '' : ' · стена ${surface.wallIndex! + 1}'}';
  }

  static void _showFailure(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
