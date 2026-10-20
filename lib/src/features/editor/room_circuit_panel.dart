import 'package:flutter/material.dart';

import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/project_model.dart';
import 'circuit_engineering_status.dart';
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
          final route = p2.routes
              .where((item) => item.id == bundle.cable.routeId)
              .firstOrNull;
          final engineeringStatus = route == null
              ? null
              : CircuitEngineeringStatus.evaluate(
                  load: selected,
                  route: route,
                  bundle: bundle,
                );
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
                  Text(
                    'Кабель: ${bundle.cable.designation}'
                    '${bundle.cable.cableSpecId == null ? '' : ' · ${bundle.cable.cableSpecId}'}',
                  ),
                  if (engineeringStatus != null) ...[
                    Text(
                      'Трасса: ${engineeringStatus.geometricLengthM.toStringAsFixed(2)} м'
                      ' · с резервом ${engineeringStatus.installationLengthM.toStringAsFixed(2)} м',
                    ),
                    Text(
                      engineeringStatus.estimatedCurrentA == null
                          ? 'Нагрузка: мощность не задана · ${engineeringStatus.nominalVoltageV} В'
                          : 'Нагрузка: ${engineeringStatus.loadPowerW} Вт · ${engineeringStatus.nominalVoltageV} В'
                              ' · I≈${engineeringStatus.estimatedCurrentA!.toStringAsFixed(2)} A (P/U)',
                    ),
                    const SizedBox(height: 6),
                    Container(
                      key: const ValueKey('circuit-engineering-readiness'),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            engineeringStatus.headline,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            engineeringStatus.detail,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('edit-load-electrical-data'),
                        onPressed: () => _editLoadData(context, selected),
                        icon: const Icon(Icons.bolt_outlined),
                        label: const Text('Нагрузка'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('assign-cable-specification'),
                        onPressed: () => _editCableSpecification(
                          context,
                          loadComponentId: selected.id,
                          bundle: bundle,
                        ),
                        icon: const Icon(Icons.cable_outlined),
                        label: const Text('Кабель'),
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

  Future<void> _editLoadData(
    BuildContext context,
    ElectricalComponentPlacement load,
  ) async {
    var powerText = load.ratedPowerW?.toString() ?? '';
    var voltageText = load.voltageV.toString();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('load-electrical-data-dialog'),
        title: Text('Параметры · ${load.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: powerText,
              decoration: const InputDecoration(
                labelText: 'Номинальная мощность',
                suffixText: 'Вт',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => powerText = value,
            ),
            TextFormField(
              initialValue: voltageText,
              decoration: const InputDecoration(
                labelText: 'Номинальное напряжение',
                suffixText: 'В',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => voltageText = value,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ток P/U показывается как предварительный индикатор. Расчётный ток цепи требует фазности, cosφ и коэффициентов нагрузки.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('load-electrical-data-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final power = int.tryParse(powerText.trim());
    final voltage = int.tryParse(voltageText.trim());
    final ok = power != null &&
        voltage != null &&
        controller.p2.updateLoadElectricalData(
          componentId: load.id,
          ratedPowerW: power,
          voltageV: voltage,
        );
    _showResult(
      context,
      ok
          ? 'Параметры нагрузки обновлены.'
          : 'Мощность и напряжение должны быть положительными числами.',
    );
  }

  Future<void> _editCableSpecification(
    BuildContext context, {
    required String loadComponentId,
    required CircuitCableBundle bundle,
  }) async {
    var value = bundle.cable.cableSpecId ?? '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('cable-specification-dialog'),
        title: const Text('Кабель группы'),
        content: TextFormField(
          initialValue: value,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Марка / specification ID',
            helperText: 'Например: VVGng-LS-3x2.5 или catalog cableSpecId',
          ),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('cable-specification-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final ok = controller.p2.assignCableSpecificationToLoad(
      loadComponentId: loadComponentId,
      cableSpecId: value,
    );
    _showResult(
      context,
      ok
          ? 'Кабель группы обновлён.'
          : 'Укажите непустую марку/спецификацию кабеля.',
    );
  }

  static void _showResult(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
