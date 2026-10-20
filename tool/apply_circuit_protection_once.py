from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))


path = 'lib/src/features/editor/editor_p2_session.dart'
replace_once(path,
"  CircuitCableBundle? circuitBundleForLoad(String componentId) {\n    for (final bundle in state.circuitBundles) {\n      if (bundle.cable.endB.componentId == componentId) return bundle;\n    }\n    return null;\n  }\n",
"  CircuitCableBundle? circuitBundleForLoad(String componentId) {\n    for (final bundle in state.circuitBundles) {\n      if (bundle.cable.endB.componentId == componentId) return bundle;\n    }\n    return null;\n  }\n\n  bool assignProtectiveDeviceToLoad({\n    required String loadComponentId,\n    required String designation,\n    int? poleCount,\n    double? ratedCurrentA,\n  }) {\n    final normalizedDesignation = designation.trim();\n    if (normalizedDesignation.isEmpty ||\n        (poleCount != null && poleCount <= 0) ||\n        (ratedCurrentA != null && ratedCurrentA <= 0)) {\n      return false;\n    }\n    final bundle = circuitBundleForLoad(loadComponentId);\n    if (bundle == null) return false;\n    final route = _routeForId(bundle.cable.routeId);\n    final boardId = bundle.circuit.boardId;\n    if (route == null || boardId == null) return false;\n\n    final device = ProtectiveDeviceRef(\n      id: bundle.protectiveDevice?.id ?? 'protection-${bundle.circuit.id}',\n      boardId: boardId,\n      designation: normalizedDesignation,\n      poleCount: poleCount,\n      ratedCurrentA: ratedCurrentA,\n    );\n    final circuit = CircuitRef(\n      id: bundle.circuit.id,\n      name: bundle.circuit.name,\n      boardId: boardId,\n      protectiveDeviceId: device.id,\n    );\n    final replacement = CircuitCableBundle(\n      circuit: circuit,\n      cable: bundle.cable,\n      protectiveDevice: device,\n    );\n    final registry = CircuitCableRegistry()\n      ..registerBundle(\n        route: route,\n        circuit: circuit,\n        cable: bundle.cable,\n        protectiveDevice: device,\n      );\n    if (registry.bundleByRouteId(route.id) == null) return false;\n\n    final after = state.copyWith(\n      circuitBundles: [\n        for (final item in state.circuitBundles)\n          if (item.cable.routeId == route.id) replacement else item,\n      ],\n    );\n    history.execute(\n      _ReplaceEditorStateCommand(\n        before: state,\n        after: after,\n        label: 'Assign circuit protective device',\n      ),\n    );\n    notifyListeners();\n    return true;\n  }\n")

path = 'lib/src/features/editor/room_circuit_panel.dart'
replace_once(path,
"                  Row(\n                    children: [\n                      const Icon(Icons.warning_amber_outlined, size: 16),\n                      const SizedBox(width: 6),\n                      Expanded(\n                        child: Text(\n                          bundle.protectiveDevice == null\n                              ? 'Защита не назначена — требуется подбор автомата.'\n                              : 'Защита: ${bundle.protectiveDevice!.designation}',\n                          style: Theme.of(context).textTheme.bodySmall,\n                        ),\n                      ),\n                    ],\n                  ),\n",
"                  Row(\n                    children: [\n                      Icon(\n                        bundle.protectiveDevice == null\n                            ? Icons.warning_amber_outlined\n                            : Icons.verified_outlined,\n                        size: 16,\n                      ),\n                      const SizedBox(width: 6),\n                      Expanded(\n                        child: Text(\n                          bundle.protectiveDevice == null\n                              ? 'Защита не назначена — требуется инженерный выбор.'\n                              : _protectionLabel(bundle.protectiveDevice!),\n                          style: Theme.of(context).textTheme.bodySmall,\n                        ),\n                      ),\n                    ],\n                  ),\n                  const SizedBox(height: 8),\n                  OutlinedButton.icon(\n                    key: const ValueKey('assign-circuit-protection'),\n                    onPressed: () => _editProtection(\n                      context,\n                      loadComponentId: selected.id,\n                      bundle: bundle,\n                    ),\n                    icon: const Icon(Icons.shield_outlined),\n                    label: Text(\n                      bundle.protectiveDevice == null\n                          ? 'Назначить защиту'\n                          : 'Изменить защиту',\n                    ),\n                  ),\n")
replace_once(path,
"  EngineeringSpace? _spaceById(String spaceId) {\n",
"  Future<void> _editProtection(\n    BuildContext context, {\n    required String loadComponentId,\n    required dynamic bundle,\n  }) async {\n    var designation = bundle.protectiveDevice?.designation as String? ??\n        'QF-${(bundle.circuit.id as String).replaceFirst('circuit-', '')}';\n    var ratedCurrentText = bundle.protectiveDevice?.ratedCurrentA?.toString() ?? '';\n    var poleCountText = bundle.protectiveDevice?.poleCount?.toString() ?? '';\n    final accepted = await showDialog<bool>(\n      context: context,\n      builder: (dialogContext) => AlertDialog(\n        key: const ValueKey('circuit-protection-dialog'),\n        title: const Text('Защита электрической группы'),\n        content: Column(\n          mainAxisSize: MainAxisSize.min,\n          children: [\n            TextFormField(\n              initialValue: designation,\n              decoration: const InputDecoration(labelText: 'Обозначение'),\n              onChanged: (value) => designation = value,\n            ),\n            TextFormField(\n              initialValue: ratedCurrentText,\n              decoration: const InputDecoration(\n                labelText: 'Номинальный ток',\n                suffixText: 'A',\n              ),\n              keyboardType: const TextInputType.numberWithOptions(decimal: true),\n              onChanged: (value) => ratedCurrentText = value,\n            ),\n            TextFormField(\n              initialValue: poleCountText,\n              decoration: const InputDecoration(labelText: 'Число полюсов'),\n              keyboardType: TextInputType.number,\n              onChanged: (value) => poleCountText = value,\n            ),\n            const SizedBox(height: 8),\n            const Text(\n              'ElecX сохраняет выбранную защиту как инженерное решение пользователя; автоматический подбор номинала здесь не выполняется.',\n            ),\n          ],\n        ),\n        actions: [\n          TextButton(\n            onPressed: () => Navigator.of(dialogContext).pop(false),\n            child: const Text('Отмена'),\n          ),\n          FilledButton(\n            key: const ValueKey('circuit-protection-confirm'),\n            onPressed: () => Navigator.of(dialogContext).pop(true),\n            child: const Text('Применить'),\n          ),\n        ],\n      ),\n    );\n    if (accepted != true || !context.mounted) return;\n    final ratedCurrent = ratedCurrentText.trim().isEmpty\n        ? null\n        : double.tryParse(ratedCurrentText.replaceAll(',', '.'));\n    final poleCount = poleCountText.trim().isEmpty\n        ? null\n        : int.tryParse(poleCountText);\n    final ok = controller.p2.assignProtectiveDeviceToLoad(\n      loadComponentId: loadComponentId,\n      designation: designation,\n      ratedCurrentA: ratedCurrent,\n      poleCount: poleCount,\n    );\n    final messenger = ScaffoldMessenger.of(context);\n    messenger\n      ..hideCurrentSnackBar()\n      ..showSnackBar(\n        SnackBar(\n          content: Text(\n            ok\n                ? 'Защита группы назначена.'\n                : 'Не удалось назначить защиту: проверьте обозначение и параметры.',\n          ),\n        ),\n      );\n  }\n\n  static String _protectionLabel(dynamic device) {\n    final details = <String>[device.designation as String];\n    final current = device.ratedCurrentA as double?;\n    final poles = device.poleCount as int?;\n    if (current != null) details.add('${current.toStringAsFixed(current.truncateToDouble() == current ? 0 : 1)} A');\n    if (poles != null) details.add('${poles}P');\n    return 'Защита: ${details.join(' · ')}';\n  }\n\n  EngineeringSpace? _spaceById(String spaceId) {\n")
# Replace dynamic with concrete type by adding import and signatures.
replace_once(path,
"import '../../domain/electrical_placement.dart';\n",
"import '../../domain/circuit_cable_registry.dart';\nimport '../../domain/electrical_placement.dart';\n")
replace_once(path, '    required dynamic bundle,\n', '    required CircuitCableBundle bundle,\n')
replace_once(path, '  static String _protectionLabel(dynamic device) {\n', '  static String _protectionLabel(ProtectiveDeviceRef device) {\n')
replace_once(path, '    final details = <String>[device.designation as String];\n    final current = device.ratedCurrentA as double?;\n    final poles = device.poleCount as int?;\n', '    final details = <String>[device.designation];\n    final current = device.ratedCurrentA;\n    final poles = device.poleCount;\n')
replace_once(path, "    var designation = bundle.protectiveDevice?.designation as String? ??\n        'QF-${(bundle.circuit.id as String).replaceFirst('circuit-', '')}';\n", "    var designation = bundle.protectiveDevice?.designation ??\n        'QF-${bundle.circuit.id.replaceFirst('circuit-', '')}';\n")

path = 'test/room_circuit_workflow_test.dart'
append = r'''

test('manual protective device assignment is undoable engineering evidence', () {
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
  final depthBefore = editor.p2.history.undoDepth;

  expect(
    editor.p2.assignProtectiveDeviceToLoad(
      loadComponentId: load.id,
      designation: 'QF-1',
      ratedCurrentA: 16,
      poleCount: 1,
    ),
    isTrue,
  );
  final protected = editor.p2.circuitBundleForLoad(load.id)!;
  expect(protected.circuit.protectiveDeviceId, protected.protectiveDevice!.id);
  expect(protected.protectiveDevice!.designation, 'QF-1');
  expect(protected.protectiveDevice!.ratedCurrentA, 16);
  expect(editor.p2.history.undoDepth, depthBefore + 1);

  editor.p2.undo();
  expect(editor.p2.circuitBundleForLoad(load.id)!.protectiveDevice, isNull);
  editor.p2.redo();
  expect(editor.p2.circuitBundleForLoad(load.id)!.protectiveDevice, isNotNull);
});
'''
p = Path(path)
text = p.read_text()
idx = text.rfind('\n}')
if idx == -1:
    raise SystemExit('test main closing brace missing')
p.write_text(text[:idx] + append + text[idx:])
