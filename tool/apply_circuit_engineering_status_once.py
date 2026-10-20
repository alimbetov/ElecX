from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))


# Testable readiness summary.
Path('lib/src/features/editor/circuit_engineering_status.dart').write_text(r'''import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';

enum CircuitEngineeringReadiness {
  missingLoadPower,
  missingProtection,
  missingCableSpecification,
  sizingEvidenceRequired,
}

final class CircuitEngineeringStatus {
  const CircuitEngineeringStatus({
    required this.readiness,
    required this.geometricLengthM,
    required this.installationLengthM,
    required this.loadPowerW,
    required this.nominalVoltageV,
    required this.estimatedCurrentA,
  });

  final CircuitEngineeringReadiness readiness;
  final double geometricLengthM;
  final double installationLengthM;
  final int? loadPowerW;
  final int nominalVoltageV;

  /// Preliminary P/U indication only. This is not design current: phase system,
  /// power factor, demand/diversity and normative evidence are not inferred.
  final double? estimatedCurrentA;

  bool get hasLoadData => loadPowerW != null && loadPowerW! > 0;

  String get headline => switch (readiness) {
        CircuitEngineeringReadiness.missingLoadPower =>
          'Укажите мощность нагрузки',
        CircuitEngineeringReadiness.missingProtection =>
          'Назначьте защиту группы',
        CircuitEngineeringReadiness.missingCableSpecification =>
          'Укажите кабель',
        CircuitEngineeringReadiness.sizingEvidenceRequired =>
          'Нужны данные для расчёта кабеля',
      };

  String get detail => switch (readiness) {
        CircuitEngineeringReadiness.missingLoadPower =>
          'Без мощности нельзя даже предварительно оценить ток нагрузки.',
        CircuitEngineeringReadiness.missingProtection =>
          'Связность и нагрузка заданы, но защитный аппарат ещё не выбран инженером.',
        CircuitEngineeringReadiness.missingCableSpecification =>
          'Группа подключена и защищена, но марка/спецификация кабеля не назначена.',
        CircuitEngineeringReadiness.sizingEvidenceRequired =>
          'Для PASS требуются ampacity по участкам и impedance evidence. ElecX не подменяет их предположениями.',
      };

  static CircuitEngineeringStatus evaluate({
    required ElectricalComponentPlacement load,
    required ElectricalCableRoute route,
    required CircuitCableBundle bundle,
  }) {
    final power = load.ratedPowerW;
    final current = power == null || power <= 0
        ? null
        : power / load.voltageV.toDouble();
    final cableSpec = bundle.cable.cableSpecId ?? route.cableType;
    final readiness = power == null || power <= 0
        ? CircuitEngineeringReadiness.missingLoadPower
        : bundle.protectiveDevice == null
            ? CircuitEngineeringReadiness.missingProtection
            : cableSpec == null || cableSpec.trim().isEmpty
                ? CircuitEngineeringReadiness.missingCableSpecification
                : CircuitEngineeringReadiness.sizingEvidenceRequired;
    return CircuitEngineeringStatus(
      readiness: readiness,
      geometricLengthM: route.geometricLengthMm / 1000,
      installationLengthM: route.installationLengthMm / 1000,
      loadPowerW: power,
      nominalVoltageV: load.voltageV,
      estimatedCurrentA: current,
    );
  }
}
''')

# Undoable load data and cable specification edits.
path = 'lib/src/features/editor/editor_p2_session.dart'
anchor = """  bool assignProtectiveDeviceToLoad({
"""
methods = """  bool updateLoadElectricalData({
    required String componentId,
    required int ratedPowerW,
    required int voltageV,
  }) {
    if (ratedPowerW <= 0 || voltageV <= 0) return false;
    final component = _componentForId(state, componentId);
    if (component == null ||
        component.type == ElectricalComponentType.distributionBoard ||
        layers.isLocked(EditorLayerId.electrical)) {
      return false;
    }
    final replacement = component.copyWith(
      ratedPowerW: ratedPowerW,
      voltageV: voltageV,
    );
    history.execute(
      _ReplaceComponentCommand(before: component, after: replacement),
    );
    notifyListeners();
    return true;
  }

  bool assignCableSpecificationToLoad({
    required String loadComponentId,
    required String cableSpecId,
  }) {
    final normalized = cableSpecId.trim();
    if (normalized.isEmpty || layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }
    final bundle = circuitBundleForLoad(loadComponentId);
    if (bundle == null) return false;
    final route = _routeForId(bundle.cable.routeId);
    if (route == null) return false;
    final replacementRoute = ElectricalCableRoute(
      id: route.id,
      source: route.source,
      target: route.target,
      segments: route.segments,
      cableType: normalized,
      medium: route.medium,
      reservePercent: route.reservePercent,
    );
    final replacementCable = CableIdentity(
      id: bundle.cable.id,
      routeId: bundle.cable.routeId,
      circuitId: bundle.cable.circuitId,
      designation: bundle.cable.designation,
      endA: bundle.cable.endA,
      endB: bundle.cable.endB,
      cableSpecId: normalized,
    );
    final replacementBundle = CircuitCableBundle(
      circuit: bundle.circuit,
      cable: replacementCable,
      protectiveDevice: bundle.protectiveDevice,
    );
    final registry = CircuitCableRegistry()
      ..registerBundle(
        route: replacementRoute,
        circuit: replacementBundle.circuit,
        cable: replacementBundle.cable,
        protectiveDevice: replacementBundle.protectiveDevice,
      );
    if (registry.bundleByRouteId(route.id) == null) return false;
    final after = state.copyWith(
      routes: [
        for (final item in routes)
          if (item.id == route.id) replacementRoute else item,
      ],
      circuitBundles: [
        for (final item in state.circuitBundles)
          if (item.cable.routeId == route.id) replacementBundle else item,
      ],
    );
    history.execute(
      _ReplaceEditorStateCommand(
        before: state,
        after: after,
        label: 'Assign circuit cable specification',
      ),
    );
    notifyListeners();
    return true;
  }

"""
replace_once(path, anchor, methods + anchor)

# UI engineering summary and data dialogs.
path = 'lib/src/features/editor/room_circuit_panel.dart'
replace_once(path,
"import 'editor_controller.dart';\n",
"import 'circuit_engineering_status.dart';\nimport 'editor_controller.dart';\n")
replace_once(path,
"          return Card(\n            key: const ValueKey('room-circuit-status'),\n",
"          final route = p2.routes\n              .where((item) => item.id == bundle.cable.routeId)\n              .firstOrNull;\n          final engineeringStatus = route == null\n              ? null\n              : CircuitEngineeringStatus.evaluate(\n                  load: selected,\n                  route: route,\n                  bundle: bundle,\n                );\n          return Card(\n            key: const ValueKey('room-circuit-status'),\n")
replace_once(path,
"                  Text('Кабель: ${bundle.cable.designation}'),\n                  const SizedBox(height: 6),\n",
"                  Text(\n                    'Кабель: ${bundle.cable.designation}'\n                    '${bundle.cable.cableSpecId == null ? '' : ' · ${bundle.cable.cableSpecId}'}',\n                  ),\n                  if (engineeringStatus != null) ...[\n                    Text(\n                      'Трасса: ${engineeringStatus.geometricLengthM.toStringAsFixed(2)} м'\n                      ' · с резервом ${engineeringStatus.installationLengthM.toStringAsFixed(2)} м',\n                    ),\n                    Text(\n                      engineeringStatus.estimatedCurrentA == null\n                          ? 'Нагрузка: мощность не задана · ${engineeringStatus.nominalVoltageV} В'\n                          : 'Нагрузка: ${engineeringStatus.loadPowerW} Вт · ${engineeringStatus.nominalVoltageV} В'\n                              ' · I≈${engineeringStatus.estimatedCurrentA!.toStringAsFixed(2)} A (P/U)',\n                    ),\n                    const SizedBox(height: 6),\n                    Container(\n                      key: const ValueKey('circuit-engineering-readiness'),\n                      padding: const EdgeInsets.all(8),\n                      decoration: BoxDecoration(\n                        border: Border.all(\n                          color: Theme.of(context).colorScheme.outlineVariant,\n                        ),\n                        borderRadius: BorderRadius.circular(8),\n                      ),\n                      child: Column(\n                        crossAxisAlignment: CrossAxisAlignment.start,\n                        children: [\n                          Text(\n                            engineeringStatus.headline,\n                            style: Theme.of(context).textTheme.labelLarge,\n                          ),\n                          const SizedBox(height: 2),\n                          Text(\n                            engineeringStatus.detail,\n                            style: Theme.of(context).textTheme.bodySmall,\n                          ),\n                        ],\n                      ),\n                    ),\n                  ],\n                  const SizedBox(height: 6),\n")
replace_once(path,
"                  const SizedBox(height: 8),\n                  OutlinedButton.icon(\n                    key: const ValueKey('assign-circuit-protection'),\n",
"                  const SizedBox(height: 8),\n                  Wrap(\n                    spacing: 6,\n                    runSpacing: 6,\n                    children: [\n                      OutlinedButton.icon(\n                        key: const ValueKey('edit-load-electrical-data'),\n                        onPressed: () => _editLoadData(context, selected),\n                        icon: const Icon(Icons.bolt_outlined),\n                        label: const Text('Нагрузка'),\n                      ),\n                      OutlinedButton.icon(\n                        key: const ValueKey('assign-cable-specification'),\n                        onPressed: () => _editCableSpecification(\n                          context,\n                          loadComponentId: selected.id,\n                          bundle: bundle,\n                        ),\n                        icon: const Icon(Icons.cable_outlined),\n                        label: const Text('Кабель'),\n                      ),\n                    ],\n                  ),\n                  const SizedBox(height: 8),\n                  OutlinedButton.icon(\n                    key: const ValueKey('assign-circuit-protection'),\n")
anchor = """  Future<void> _editProtection(
"""
helpers = r'''  Future<void> _editLoadData(
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
      ok ? 'Параметры нагрузки обновлены.' : 'Мощность и напряжение должны быть положительными числами.',
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
      ok ? 'Кабель группы обновлён.' : 'Укажите непустую марку/спецификацию кабеля.',
    );
  }

  static void _showResult(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

'''
replace_once(path, anchor, helpers + anchor)

# Unit status + persistence/undo for load and cable data.
Path('test/circuit_engineering_status_test.dart').write_text(r'''import 'package:elecx/src/domain/cable_identity.dart';
import 'package:elecx/src/domain/circuit_cable_registry.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/circuit_engineering_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-1', 0);
  final load = ElectricalComponentPlacement(
    id: 'load-1',
    type: ElectricalComponentType.socketOutlet,
    surface: surface,
    position: const SurfacePointMm(2000, 1000),
    label: 'Розетка',
    ratedPowerW: 2300,
    voltageV: 230,
    ports: ElectricalComponentDefaults.portsFor(
      ElectricalComponentType.socketOutlet,
    ),
  );
  final route = ElectricalCableRoute(
    id: 'route-1',
    source: const ElectricalEndpointRef(
      componentId: 'board-1',
      portId: 'power-out',
    ),
    target: const ElectricalEndpointRef(
      componentId: 'load-1',
      portId: 'power-in',
    ),
    segments: [
      ElectricalRouteSegment(
        surface: surface,
        points: const [
          SurfacePointMm(0, 1000),
          SurfacePointMm(2000, 1000),
        ],
      ),
    ],
    cableType: 'VVGng-LS-3x2.5',
  );
  final circuit = CircuitRef(
    id: 'circuit-1',
    name: 'Розетки',
    boardId: 'board-1',
    protectiveDeviceId: 'qf-1',
  );
  final cable = CableIdentity(
    id: 'cable-1',
    routeId: route.id,
    circuitId: circuit.id,
    designation: 'CAB-1',
    cableSpecId: 'VVGng-LS-3x2.5',
    endA: const CableTerminationRef(
      componentId: 'board-1',
      portId: 'power-out',
    ),
    endB: const CableTerminationRef(
      componentId: 'load-1',
      portId: 'power-in',
    ),
  );

  test('status exposes route length and preliminary P/U current', () {
    final status = CircuitEngineeringStatus.evaluate(
      load: load,
      route: route,
      bundle: CircuitCableBundle(
        circuit: circuit,
        cable: cable,
        protectiveDevice: const ProtectiveDeviceRef(
          id: 'qf-1',
          boardId: 'board-1',
          designation: 'QF-1',
          ratedCurrentA: 16,
          poleCount: 1,
        ),
      ),
    );

    expect(status.geometricLengthM, 2);
    expect(status.installationLengthM, 2.1);
    expect(status.estimatedCurrentA, closeTo(10, 0.0001));
    expect(
      status.readiness,
      CircuitEngineeringReadiness.sizingEvidenceRequired,
    );
    expect(status.detail, contains('ampacity'));
  });

  test('status never fabricates current when load power is missing', () {
    final noPower = ElectricalComponentPlacement(
      id: load.id,
      type: load.type,
      surface: load.surface,
      position: load.position,
      label: load.label,
      voltageV: load.voltageV,
      ports: load.ports,
    );
    final status = CircuitEngineeringStatus.evaluate(
      load: noPower,
      route: route,
      bundle: CircuitCableBundle(circuit: circuit, cable: cable),
    );
    expect(status.estimatedCurrentA, isNull);
    expect(status.readiness, CircuitEngineeringReadiness.missingLoadPower);
  });
}
''')

path = 'test/room_circuit_workflow_test.dart'
append = r'''

test('load data and cable specification edits are undoable and persisted', () {
  final editor = EditorController.demo();
  final workspace = EditorBuildingWorkspace.demo(editor);
  addTearDown(() {
    editor.disposeP2State();
    workspace.dispose();
    editor.dispose();
  });
  final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
  final board = editor.p2.placeComponent(
    type: ElectricalComponentType.distributionBoard,
    surface: surface,
    position: const SurfacePointMm(300, 2200),
  );
  final load = editor.p2.placeComponent(
    type: ElectricalComponentType.socketOutlet,
    surface: surface,
    position: const SurfacePointMm(1400, 2200),
  );
  expect(
    editor.p2.connectLoadToBoard(
      loadComponentId: load.id,
      boardComponentId: board.id,
      space: editor.selectedSpace,
    ),
    isNotNull,
  );
  expect(
    editor.p2.updateLoadElectricalData(
      componentId: load.id,
      ratedPowerW: 2300,
      voltageV: 230,
    ),
    isTrue,
  );
  expect(
    editor.p2.assignCableSpecificationToLoad(
      loadComponentId: load.id,
      cableSpecId: 'VVGng-LS-3x2.5',
    ),
    isTrue,
  );
  final currentLoad = editor.p2.components.singleWhere((item) => item.id == load.id);
  expect(currentLoad.ratedPowerW, 2300);
  expect(editor.p2.circuitBundleForLoad(load.id)!.cable.cableSpecId, 'VVGng-LS-3x2.5');
  expect(editor.p2.routes.single.cableType, 'VVGng-LS-3x2.5');

  final restored = EditorProjectDocument.fromJson(
    EditorProjectDocument.capture(workspace).toJson(),
  ).restore();
  addTearDown(() {
    restored.editor.disposeP2State();
    restored.workspace.dispose();
    restored.editor.dispose();
  });
  final restoredLoad = restored.editor.p2.components.singleWhere((item) => item.id == load.id);
  expect(restoredLoad.ratedPowerW, 2300);
  expect(restored.editor.p2.circuitBundleForLoad(load.id)!.cable.cableSpecId, 'VVGng-LS-3x2.5');
});
'''
p = Path(path)
text = p.read_text()
idx = text.rfind('\n}')
if idx == -1:
    raise SystemExit('room circuit test closing brace missing')
p.write_text(text[:idx] + append + text[idx:])