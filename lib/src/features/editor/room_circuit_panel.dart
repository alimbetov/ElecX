import 'package:flutter/material.dart';

import '../../domain/cable_spec.dart';
import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/project_model.dart';
import '../../engine/cable_sizing_engine.dart';
import 'circuit_engineering_status.dart';
import 'circuit_sizing_evidence.dart';
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
                  sizingEvidence: p2.sizingEvidenceForLoad(selected.id),
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
                        key: const ValueKey('edit-cable-sizing-evidence'),
                        onPressed:
                            route == null || bundle.cable.cableSpecId == null
                                ? null
                                : () => _editSizingEvidence(
                                      context,
                                      load: selected,
                                      route: route,
                                      bundle: bundle,
                                    ),
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Расчёт'),
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

  Future<void> _editSizingEvidence(
    BuildContext context, {
    required ElectricalComponentPlacement load,
    required ElectricalCableRoute route,
    required CircuitCableBundle bundle,
  }) async {
    final existing = controller.p2.sizingEvidenceForLoad(load.id);
    final preliminaryCurrent = load.ratedPowerW == null
        ? ''
        : (load.ratedPowerW! / load.voltageV).toStringAsFixed(2);
    var phaseSystem = existing?.phaseSystem ?? CircuitPhaseSystem.singlePhaseAc;
    var designCurrentText =
        existing?.designCurrentA.toString() ?? preliminaryCurrent;
    var powerFactorText = existing?.powerFactor.toString() ?? '1.0';
    var voltageDropText = existing == null
        ? '3.0'
        : (existing.maxVoltageDropRatio * 100).toString();
    var diameterText = existing?.cable.outerDiameterMm.toString() ?? '';
    var material =
        existing?.cable.conductorMaterial ?? ConductorMaterial.copper;
    var conductorCountText = existing?.cable.conductorCount?.toString() ?? '3';
    var crossSectionText =
        existing?.cable.conductorCrossSectionMm2?.toString() ?? '';
    var baseAmpacityText =
        existing?.ampacitySections.firstOrNull?.baseAmpacityA.toString() ?? '';
    var correctionText =
        existing?.ampacitySections.firstOrNull?.combinedFactor.toString() ??
            '1.0';
    var ampacitySource =
        existing?.ampacitySections.firstOrNull?.sourceKey ?? '';
    var resistanceText =
        existing?.impedanceEvidence?.resistanceOhmPerKm.toString() ?? '';
    var reactanceText =
        existing?.impedanceEvidence?.reactanceOhmPerKm.toString() ?? '0';
    var impedanceSource = existing?.impedanceEvidence?.sourceKey ?? '';
    var designCurrentSource = existing?.designCurrentSourceKey ?? '';

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          key: const ValueKey('cable-sizing-evidence-dialog'),
          title: const Text('Расчёт кабеля · evidence'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<CircuitPhaseSystem>(
                    initialValue: phaseSystem,
                    decoration: const InputDecoration(labelText: 'Система'),
                    items: const [
                      DropdownMenuItem(
                        value: CircuitPhaseSystem.singlePhaseAc,
                        child: Text('1-фаза AC'),
                      ),
                      DropdownMenuItem(
                        value: CircuitPhaseSystem.threePhaseAc,
                        child: Text('3-фазы AC'),
                      ),
                      DropdownMenuItem(
                        value: CircuitPhaseSystem.dc,
                        child: Text('DC'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setLocalState(() => phaseSystem = value);
                      }
                    },
                  ),
                  TextFormField(
                    key: const ValueKey('sizing-design-current'),
                    initialValue: designCurrentText,
                    decoration: InputDecoration(
                      labelText: 'Расчётный ток',
                      suffixText: 'A',
                      helperText: preliminaryCurrent.isEmpty
                          ? 'Введите подтверждённый расчётный ток.'
                          : 'P/U≈$preliminaryCurrent A только как подсказка; подтвердите расчётный ток.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => designCurrentText = value,
                  ),
                  TextFormField(
                    initialValue: designCurrentSource,
                    decoration: const InputDecoration(
                      labelText: 'Источник расчётного тока',
                    ),
                    onChanged: (value) => designCurrentSource = value,
                  ),
                  TextFormField(
                    initialValue: powerFactorText,
                    decoration: const InputDecoration(labelText: 'cosφ'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => powerFactorText = value,
                  ),
                  TextFormField(
                    initialValue: voltageDropText,
                    decoration: const InputDecoration(
                      labelText: 'Допустимое падение напряжения',
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => voltageDropText = value,
                  ),
                  const Divider(height: 24),
                  TextFormField(
                    initialValue: diameterText,
                    decoration: const InputDecoration(
                      labelText: 'Наружный диаметр кабеля',
                      suffixText: 'мм',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => diameterText = value,
                  ),
                  DropdownButtonFormField<ConductorMaterial>(
                    initialValue: material,
                    decoration: const InputDecoration(
                      labelText: 'Материал жил',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ConductorMaterial.copper,
                        child: Text('Cu'),
                      ),
                      DropdownMenuItem(
                        value: ConductorMaterial.aluminum,
                        child: Text('Al'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setLocalState(() => material = value);
                      }
                    },
                  ),
                  TextFormField(
                    initialValue: conductorCountText,
                    decoration: const InputDecoration(
                      labelText: 'Количество жил',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => conductorCountText = value,
                  ),
                  TextFormField(
                    initialValue: crossSectionText,
                    decoration: const InputDecoration(
                      labelText: 'Сечение жилы',
                      suffixText: 'мм²',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => crossSectionText = value,
                  ),
                  const Divider(height: 24),
                  TextFormField(
                    key: const ValueKey('sizing-base-ampacity'),
                    initialValue: baseAmpacityText,
                    decoration: const InputDecoration(
                      labelText: 'Base ampacity участка',
                      suffixText: 'A',
                      helperText:
                          'Оставьте пустым → current check = INDETERMINATE.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => baseAmpacityText = value,
                  ),
                  TextFormField(
                    initialValue: correctionText,
                    decoration: const InputDecoration(
                      labelText: 'Суммарный correction factor',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => correctionText = value,
                  ),
                  TextFormField(
                    initialValue: ampacitySource,
                    decoration: const InputDecoration(
                      labelText: 'Источник ampacity',
                    ),
                    onChanged: (value) => ampacitySource = value,
                  ),
                  TextFormField(
                    key: const ValueKey('sizing-resistance'),
                    initialValue: resistanceText,
                    decoration: const InputDecoration(
                      labelText: 'R',
                      suffixText: 'Ω/км',
                      helperText:
                          'Оставьте пустым → voltage-drop check = INDETERMINATE.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => resistanceText = value,
                  ),
                  TextFormField(
                    initialValue: reactanceText,
                    decoration: const InputDecoration(
                      labelText: 'X',
                      suffixText: 'Ω/км',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => reactanceText = value,
                  ),
                  TextFormField(
                    initialValue: impedanceSource,
                    decoration: const InputDecoration(
                      labelText: 'Источник impedance',
                    ),
                    onChanged: (value) => impedanceSource = value,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              key: const ValueKey('cable-sizing-evidence-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Рассчитать'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;

    double? parseDouble(String value) =>
        double.tryParse(value.trim().replaceAll(',', '.'));
    final designCurrent = parseDouble(designCurrentText);
    final powerFactor = parseDouble(powerFactorText);
    final voltageDropPercent = parseDouble(voltageDropText);
    final diameter = parseDouble(diameterText);
    final conductorCount = int.tryParse(conductorCountText.trim());
    final crossSection = parseDouble(crossSectionText);
    final baseAmpacity =
        baseAmpacityText.trim().isEmpty ? null : parseDouble(baseAmpacityText);
    final correction = parseDouble(correctionText);
    final resistance =
        resistanceText.trim().isEmpty ? null : parseDouble(resistanceText);
    final reactance = parseDouble(reactanceText) ?? 0;
    final specId = bundle.cable.cableSpecId;
    if (designCurrent == null ||
        designCurrent <= 0 ||
        powerFactor == null ||
        powerFactor <= 0 ||
        powerFactor > 1 ||
        voltageDropPercent == null ||
        voltageDropPercent <= 0 ||
        voltageDropPercent >= 100 ||
        diameter == null ||
        diameter <= 0 ||
        conductorCount == null ||
        conductorCount <= 0 ||
        crossSection == null ||
        crossSection <= 0 ||
        correction == null ||
        correction <= 0 ||
        specId == null) {
      _showResult(
        context,
        'Проверьте обязательные параметры расчёта и CableSpec.',
      );
      return;
    }
    if ((baseAmpacity != null && baseAmpacity <= 0) ||
        (resistance != null && resistance < 0) ||
        reactance < 0) {
      _showResult(
        context,
        'Ampacity/R/X не могут иметь отрицательные значения.',
      );
      return;
    }

    final cable = CableSpec(
      id: specId,
      name: specId,
      medium: route.medium,
      outerDiameterMm: diameter,
      segregationClass: CableSegregationClass.power,
      conductorMaterial: material,
      conductorCount: conductorCount,
      conductorCrossSectionMm2: crossSection,
      ratedVoltageV: load.voltageV,
    );
    final evidence = CircuitSizingEvidence(
      routeId: route.id,
      routeGeometrySignature: CircuitSizingEvidence.geometrySignature(route),
      cable: cable,
      phaseSystem: phaseSystem,
      designCurrentA: designCurrent,
      nominalVoltageV: load.voltageV.toDouble(),
      maxVoltageDropRatio: voltageDropPercent / 100,
      powerFactor: powerFactor,
      designCurrentSourceKey: designCurrentSource.trim().isEmpty
          ? null
          : designCurrentSource.trim(),
      ampacitySections: baseAmpacity == null
          ? const []
          : [
              SectionAmpacityEvidence(
                sectionId: '${route.id}:whole-route',
                baseAmpacityA: baseAmpacity,
                sourceKey: ampacitySource.trim().isEmpty
                    ? null
                    : ampacitySource.trim(),
                factors: [
                  ThermalCorrectionFactor(
                    id: 'combined-user-factor',
                    factor: correction,
                    reason: 'Engineer-supplied combined factor',
                  ),
                ],
              ),
            ],
      impedanceEvidence: resistance == null
          ? null
          : CableImpedanceEvidence(
              resistanceOhmPerKm: resistance,
              reactanceOhmPerKm: reactance,
              sourceKey: impedanceSource.trim().isEmpty
                  ? null
                  : impedanceSource.trim(),
            ),
    );
    final ok = controller.p2.setCircuitSizingEvidenceForLoad(
      loadComponentId: load.id,
      evidence: evidence,
    );
    _showResult(
      context,
      ok ? 'Расчёт кабеля обновлён.' : 'Не удалось сохранить evidence расчёта.',
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
