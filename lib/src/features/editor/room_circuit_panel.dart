import 'package:flutter/material.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/project_model.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

class RoomCircuitPanel extends StatelessWidget {
  const RoomCircuitPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final p2 = controller.p2;
    return AnimatedBuilder(
      animation: p2,
      builder: (context, _) {
        final selected = p2.selectedComponent;
        if (selected == null) {
          return const _CircuitCard(
            title: 'Электрическая группа',
            body: 'Выберите нагрузку, чтобы подключить её к щиту.',
          );
        }
        if (selected.type == ElectricalComponentType.distributionBoard) {
          return _CircuitCard(
            title: selected.label,
            body: 'Щит готов как источник групп. Выберите нагрузку в комнате.',
          );
        }
        final bundle = p2.circuitBundleForLoad(selected.id);
        if (bundle != null) {
          final board = p2.components
              .where((item) => item.id == bundle.circuit.boardId)
              .firstOrNull;
          return Card(
            key: const ValueKey('room-circuit-status'),
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Электрическая группа',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('Нагрузка: ${selected.label}'),
                  Text('Щит: ${board?.label ?? bundle.circuit.boardId ?? '—'}'),
                  Text('Группа: ${bundle.circuit.name}'),
                  Text('Кабель: ${bundle.cable.designation}'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bundle.protectiveDevice == null
                              ? 'Защита не назначена — требуется подбор автомата.'
                              : 'Защита: ${bundle.protectiveDevice!.designation}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final boards = p2.components
            .where(
              (item) =>
                  item.type == ElectricalComponentType.distributionBoard &&
                  item.surface.spaceId == selected.surface.spaceId,
            )
            .toList(growable: false);
        if (boards.isEmpty) {
          return const _CircuitCard(
            title: 'Электрическая группа',
            body: 'В этой комнате нет щита. Разместите щит из каталога.',
          );
        }
        final space = _spaceById(selected.surface.spaceId);
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Подключить к щиту',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(selected.label),
                const SizedBox(height: 8),
                for (final board in boards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: FilledButton.tonalIcon(
                      key: ValueKey('connect-load-to-board-${board.id}'),
                      onPressed: space == null
                          ? null
                          : () {
                              final bundle = p2.connectLoadToBoard(
                                loadComponentId: selected.id,
                                boardComponentId: board.id,
                                space: space,
                              );
                              final messenger = ScaffoldMessenger.of(context);
                              messenger
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      bundle == null
                                          ? 'Не удалось построить допустимую трассу до щита.'
                                          : 'Нагрузка подключена к ${board.label}.',
                                    ),
                                  ),
                                );
                            },
                      icon: const Icon(Icons.electrical_services_outlined),
                      label: Text(board.label),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  EngineeringSpace? _spaceById(String spaceId) {
    for (final space in controller.level.spaces) {
      if (space.id == spaceId) return space;
    }
    return null;
  }
}

class _CircuitCard extends StatelessWidget {
  const _CircuitCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
