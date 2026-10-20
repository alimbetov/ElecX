import 'package:flutter/material.dart';

import '../../domain/circuit_cable_registry.dart';
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
                      Icon(
                        bundle.protectiveDevice == null
                            ? Icons.warning_amber_outlined
                            : Icons.verified_outlined,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bundle.protectiveDevice == null
                              ? 'Защита не назначена — требуется инженерный выбор.'
                              : _protectionLabel(bundle.protectiveDevice!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('assign-circuit-protection'),
                    onPressed: () => _editProtection(
                      context,
                      loadComponentId: selected.id,
                      bundle: bundle,
                    ),
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(
                      bundle.protectiveDevice == null
                          ? 'Назначить защиту'
                          : 'Изменить защиту',
                    ),
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

  Future<void> _editProtection(
    BuildContext context, {
    required String loadComponentId,
    required CircuitCableBundle bundle,
  }) async {
    var designation = bundle.protectiveDevice?.designation ??
        'QF-${bundle.circuit.id.replaceFirst('circuit-', '')}';
    var ratedCurrentText =
        bundle.protectiveDevice?.ratedCurrentA?.toString() ?? '';
    var poleCountText = bundle.protectiveDevice?.poleCount?.toString() ?? '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('circuit-protection-dialog'),
        title: const Text('Защита электрической группы'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: designation,
              decoration: const InputDecoration(labelText: 'Обозначение'),
              onChanged: (value) => designation = value,
            ),
            TextFormField(
              initialValue: ratedCurrentText,
              decoration: const InputDecoration(
                labelText: 'Номинальный ток',
                suffixText: 'A',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => ratedCurrentText = value,
            ),
            TextFormField(
              initialValue: poleCountText,
              decoration: const InputDecoration(labelText: 'Число полюсов'),
              keyboardType: TextInputType.number,
              onChanged: (value) => poleCountText = value,
            ),
            const SizedBox(height: 8),
            const Text(
              'ElecX сохраняет выбранную защиту как инженерное решение пользователя; автоматический подбор номинала здесь не выполняется.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('circuit-protection-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final ratedCurrent = ratedCurrentText.trim().isEmpty
        ? null
        : double.tryParse(ratedCurrentText.replaceAll(',', '.'));
    final poleCount =
        poleCountText.trim().isEmpty ? null : int.tryParse(poleCountText);
    final ok = controller.p2.assignProtectiveDeviceToLoad(
      loadComponentId: loadComponentId,
      designation: designation,
      ratedCurrentA: ratedCurrent,
      poleCount: poleCount,
    );
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Защита группы назначена.'
                : 'Не удалось назначить защиту: проверьте обозначение и параметры.',
          ),
        ),
      );
  }

  static String _protectionLabel(ProtectiveDeviceRef device) {
    final details = <String>[device.designation];
    final current = device.ratedCurrentA;
    final poles = device.poleCount;
    if (current != null) {
      details.add(
        '${current.toStringAsFixed(current.truncateToDouble() == current ? 0 : 1)} A',
      );
    }
    if (poles != null) {
      details.add('${poles}P');
    }
    return 'Защита: ${details.join(' · ')}';
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
