from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}: {old[:140]!r}')
    p.write_text(text.replace(old, new, 1))


# F01 — electrical session mutations must participate in document dirty lifecycle.
path = 'lib/src/features/editor/unified_workspace_editor_screen.dart'
replace_once(
    path,
    "    siteInteraction = SiteMapInteractionController();\n",
    "    controller.p2.addListener(_onProjectChanged);\n    siteInteraction = SiteMapInteractionController();\n",
)
replace_once(
    path,
    "    } finally {\n      _autosaveInFlight = false;\n    }\n  }\n",
    "    } finally {\n      _autosaveInFlight = false;\n      if (mounted &&\n          _hasUnsavedChanges &&\n          _lastAutosavedRevision != _projectRevision) {\n        _scheduleAutosave();\n      }\n    }\n  }\n",
)
replace_once(
    path,
    "    previousWorkspace.removeListener(_onProjectChanged);\n    previousController.removeListener(_onProjectChanged);\n    previousController.disposeP2State();\n",
    "    previousWorkspace.removeListener(_onProjectChanged);\n    previousController.removeListener(_onProjectChanged);\n    previousController.p2.removeListener(_onProjectChanged);\n    previousController.disposeP2State();\n",
)
replace_once(
    path,
    "    controller = restored.editor..addListener(_onProjectChanged);\n    workspace = restored.workspace..addListener(_onProjectChanged);\n",
    "    controller = restored.editor..addListener(_onProjectChanged);\n    workspace = restored.workspace..addListener(_onProjectChanged);\n    controller.p2.addListener(_onProjectChanged);\n",
)
replace_once(
    path,
    "    controller.removeListener(_onProjectChanged);\n    controller.disposeP2State();\n",
    "    controller.removeListener(_onProjectChanged);\n    controller.p2.removeListener(_onProjectChanged);\n    controller.disposeP2State();\n",
)

# F02 — a route segment touching polygon vertices must still be inside for every interval.
path = 'lib/src/engine/normative_route_engine.dart'
replace_once(
    path,
    """  static bool _segmentInsideBoundary(\n    SurfacePointMm a,\n    SurfacePointMm b,\n    List<SurfacePointMm> boundary,\n  ) {\n    if (!_insideOrBoundary(a, boundary) || !_insideOrBoundary(b, boundary)) {\n      return false;\n    }\n    for (var i = 0; i < boundary.length; i++) {\n      final c = boundary[i];\n      final d = boundary[(i + 1) % boundary.length];\n      if (_properlyIntersects(a, b, c, d)) return false;\n    }\n    return true;\n  }\n\n""",
    """  static bool _segmentInsideBoundary(\n    SurfacePointMm a,\n    SurfacePointMm b,\n    List<SurfacePointMm> boundary,\n  ) {\n    if (!_insideOrBoundary(a, boundary) || !_insideOrBoundary(b, boundary)) {\n      return false;\n    }\n    for (var i = 0; i < boundary.length; i++) {\n      final c = boundary[i];\n      final d = boundary[(i + 1) % boundary.length];\n      if (_properlyIntersects(a, b, c, d)) return false;\n    }\n\n    // Proper-intersection tests alone miss the case where a segment exits a\n    // concave polygon exactly through one vertex and re-enters through another.\n    // Split the segment at every boundary vertex lying on it, then require the\n    // midpoint of every open interval to remain inside/on the polygon.\n    final cuts = <double>[0, 1];\n    final dx = b.xMm - a.xMm;\n    final dy = b.yMm - a.yMm;\n    for (final vertex in boundary) {\n      if (!_onSegment(a, vertex, b)) continue;\n      final t = dx.abs() >= dy.abs()\n          ? (dx == 0 ? 0.0 : (vertex.xMm - a.xMm) / dx)\n          : (dy == 0 ? 0.0 : (vertex.yMm - a.yMm) / dy);\n      if (t > 0 && t < 1) cuts.add(t);\n    }\n    cuts.sort();\n    final unique = <double>[];\n    for (final value in cuts) {\n      if (unique.isEmpty || (value - unique.last).abs() > 1e-9) {\n        unique.add(value);\n      }\n    }\n    for (var i = 1; i < unique.length; i++) {\n      final t = (unique[i - 1] + unique[i]) / 2;\n      final x = a.xMm + dx * t;\n      final y = a.yMm + dy * t;\n      if (!_insideOrBoundaryAt(x, y, boundary)) return false;\n    }\n    return true;\n  }\n\n  static bool _insideOrBoundaryAt(\n    double x,\n    double y,\n    List<SurfacePointMm> polygon,\n  ) {\n    var inside = false;\n    const epsilon = 1e-7;\n    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {\n      final a = polygon[j];\n      final b = polygon[i];\n      final cross = (b.xMm - a.xMm) * (y - a.yMm) -\n          (b.yMm - a.yMm) * (x - a.xMm);\n      if (cross.abs() <= epsilon &&\n          x >= math.min(a.xMm, b.xMm) - epsilon &&\n          x <= math.max(a.xMm, b.xMm) + epsilon &&\n          y >= math.min(a.yMm, b.yMm) - epsilon &&\n          y <= math.max(a.yMm, b.yMm) + epsilon) {\n        return true;\n      }\n      final crosses = (a.yMm > y) != (b.yMm > y);\n      if (!crosses) continue;\n      final crossingX =\n          (b.xMm - a.xMm) * (y - a.yMm) / (b.yMm - a.yMm) + a.xMm;\n      if (x < crossingX) inside = !inside;\n    }\n    return inside;\n  }\n\n""",
)
# Ensure dart:math is present for midpoint boundary checks.
p = Path(path)
text = p.read_text()
if "import 'dart:math' as math;" not in text:
    p.write_text("import 'dart:math' as math;\n\n" + text)

# F04 — route rebind and circuit/cable identity are one document command.
path = 'lib/src/features/editor/editor_p2_session.dart'
old = """    final afterConstraints = beforeConstraints.reconcile([\n      for (final segment in after.segments) segment.points,\n    ]);\n    history.execute(\n      _ReplaceCableRouteCommand(\n        before: current,\n        after: after,\n        beforeConstraints: beforeConstraints,\n        afterConstraints: afterConstraints,\n      ),\n    );\n    notifyListeners();\n    return true;\n"""
new = """    final afterConstraints = beforeConstraints.reconcile([\n      for (final segment in after.segments) segment.points,\n    ]);\n\n    final assignedBundle = circuitBundleForRoute(after.id);\n    CircuitCableBundle? reboundBundle;\n    if (assignedBundle != null) {\n      if (assignedBundle.protectiveDevice != null &&\n          after.source.componentId != before.source.componentId) {\n        // Moving a protected circuit to another board requires an explicit\n        // protective-device reassignment workflow; never do it implicitly.\n        return false;\n      }\n      final targetComponent = _componentForId(state, after.target.componentId);\n      final reboundCircuit = CircuitRef(\n        id: assignedBundle.circuit.id,\n        name: targetComponent == null\n            ? assignedBundle.circuit.name\n            : 'Группа · ${targetComponent.label}',\n        boardId: assignedBundle.circuit.boardId == before.source.componentId\n            ? after.source.componentId\n            : assignedBundle.circuit.boardId,\n        protectiveDeviceId: assignedBundle.circuit.protectiveDeviceId,\n      );\n      final reboundCable = CableIdentity(\n        id: assignedBundle.cable.id,\n        routeId: assignedBundle.cable.routeId,\n        circuitId: assignedBundle.cable.circuitId,\n        designation: assignedBundle.cable.designation,\n        cableSpecId: assignedBundle.cable.cableSpecId,\n        endA: CableTerminationRef(\n          componentId: after.source.componentId,\n          portId: after.source.portId,\n        ),\n        endB: CableTerminationRef(\n          componentId: after.target.componentId,\n          portId: after.target.portId,\n        ),\n      );\n      reboundBundle = CircuitCableBundle(\n        circuit: reboundCircuit,\n        cable: reboundCable,\n        protectiveDevice: assignedBundle.protectiveDevice,\n      );\n      final registry = CircuitCableRegistry()\n        ..registerBundle(\n          route: after,\n          circuit: reboundCircuit,\n          cable: reboundCable,\n          protectiveDevice: assignedBundle.protectiveDevice,\n        );\n      if (registry.bundleByRouteId(after.id) == null) return false;\n    }\n\n    final nextConstraints = Map<String, CableRouteConstraints>.of(\n      state.routeConstraints,\n    );\n    if (afterConstraints.isEmpty) {\n      nextConstraints.remove(after.id);\n    } else {\n      nextConstraints[after.id] = afterConstraints;\n    }\n    final nextEvidence = Map<String, CircuitSizingEvidence>.of(\n      state.sizingEvidenceByRoute,\n    )..remove(after.id);\n    final nextState = state.copyWith(\n      routes: [\n        for (final route in routes)\n          if (route.id == after.id) after else route,\n      ],\n      routeConstraints: Map.unmodifiable(nextConstraints),\n      circuitBundles: reboundBundle == null\n          ? state.circuitBundles\n          : [\n              for (final bundle in state.circuitBundles)\n                if (bundle.cable.routeId == after.id) reboundBundle else bundle,\n            ],\n      sizingEvidenceByRoute: Map.unmodifiable(nextEvidence),\n    );\n    history.execute(\n      _ReplaceEditorStateCommand(\n        before: state,\n        after: nextState,\n        label: 'Edit cable route and engineering identity',\n      ),\n    );\n    notifyListeners();\n    return true;\n"""
replace_once(path, old, new)
# Remove now-unused route-only command.
p = Path(path)
text = p.read_text()
start = text.find('final class _ReplaceCableRouteCommand implements EditorCommand<EditorP2State> {')
end = text.find("\nfinal Expando<EditorP2Session> _p2Sessions", start)
if start == -1 or end == -1:
    raise SystemExit('editor_p2_session.dart: route command block not found')
p.write_text(text[:start] + text[end + 1:])

# F05/F06 — central cancellation signal for Escape/tool/context changes.
path = 'lib/src/features/editor/editor_controller.dart'
replace_once(
    path,
    "  double zoom = 1.0;\n\n",
    "  double zoom = 1.0;\n  final ValueNotifier<int> _editCancellationRevision = ValueNotifier<int>(0);\n\n  ValueListenable<int> get editCancellationListenable =>\n      _editCancellationRevision;\n\n  void requestEditCancellation() {\n    _editCancellationRevision.value++;\n  }\n\n",
)
for anchor, replacement in [
    ("  void setTool(EditorTool value) {\n    tool = value;\n", "  void setTool(EditorTool value) {\n    requestEditCancellation();\n    tool = value;\n"),
    ("  void selectSpace(String? id) {\n    selectedSpaceId = id;\n", "  void selectSpace(String? id) {\n    requestEditCancellation();\n    selectedSpaceId = id;\n"),
    ("  void enterRoomWorld([String? spaceId]) {\n    final id = spaceId ?? selectedSpaceId;\n", "  void enterRoomWorld([String? spaceId]) {\n    final id = spaceId ?? selectedSpaceId;\n"),
    ("    if (id == null || !level.spaces.any((space) => space.id == id)) return;\n    selectedSpaceId = id;\n", "    if (id == null || !level.spaces.any((space) => space.id == id)) return;\n    requestEditCancellation();\n    selectedSpaceId = id;\n"),
    ("  void showRoomWorld() {\n    if (selectedSpace == null) return;\n", "  void showRoomWorld() {\n    if (selectedSpace == null) return;\n    requestEditCancellation();\n"),
    ("  void selectOpening(String? id) {\n    selectedOpeningId = id;\n", "  void selectOpening(String? id) {\n    requestEditCancellation();\n    selectedOpeningId = id;\n"),
    ("  void showPlan() {\n    viewMode = EditorViewMode.plan;\n", "  void showPlan() {\n    requestEditCancellation();\n    viewMode = EditorViewMode.plan;\n"),
    ("  void _switchSurface(RoomSurfaceRef target) {\n    final space = selectedSpace;\n    if (space == null) return;\n\n", "  void _switchSurface(RoomSurfaceRef target) {\n    final space = selectedSpace;\n    if (space == null) return;\n    requestEditCancellation();\n\n"),
]:
    replace_once(path, anchor, replacement)
replace_once(
    path,
    "  void updateSelectedGrid(int minorStepMm) {\n",
    "  @override\n  void dispose() {\n    _editCancellationRevision.dispose();\n    super.dispose();\n  }\n\n  void updateSelectedGrid(int minorStepMm) {\n",
)

path = 'lib/src/features/editor/editor_keyboard_scope.dart'
replace_once(
    path,
    """    } else {\n      controller.setTool(EditorTool.select);\n    }\n  }\n\n  void _commitActiveEdit() {\n""",
    """    } else {\n      controller.setTool(EditorTool.select);\n    }\n    controller.requestEditCancellation();\n  }\n\n  void _commitActiveEdit() {\n""",
)

path = 'lib/src/features/editor/editable_spatial_canvas.dart'
replace_once(
    path,
    "  Offset? _panAnchor;\n",
    "  Offset? _panAnchor;\n  int? _panPointer;\n  int? _primaryDragPointer;\n  final Set<int> _activePointers = <int>{};\n",
)
replace_once(
    path,
    "    controller.viewportCommandListenable.addListener(_onViewportCommand);\n    _rebuildIndex(force: true);\n",
    "    controller.viewportCommandListenable.addListener(_onViewportCommand);\n    controller.editCancellationListenable.addListener(_cancelTransientInteraction);\n    _rebuildIndex(force: true);\n",
)
replace_once(
    path,
    "      oldWidget.controller.viewportCommandListenable.removeListener(\n        _onViewportCommand,\n      );\n",
    "      oldWidget.controller.viewportCommandListenable.removeListener(\n        _onViewportCommand,\n      );\n      oldWidget.controller.editCancellationListenable.removeListener(\n        _cancelTransientInteraction,\n      );\n",
)
replace_once(
    path,
    "      controller.viewportCommandListenable.addListener(_onViewportCommand);\n      _selectedExternalEdgeIndex = null;\n",
    "      controller.viewportCommandListenable.addListener(_onViewportCommand);\n      controller.editCancellationListenable.addListener(_cancelTransientInteraction);\n      _selectedExternalEdgeIndex = null;\n",
)
replace_once(
    path,
    "    controller.viewportCommandListenable.removeListener(_onViewportCommand);\n    super.dispose();\n",
    "    controller.viewportCommandListenable.removeListener(_onViewportCommand);\n    controller.editCancellationListenable.removeListener(_cancelTransientInteraction);\n    super.dispose();\n",
)
replace_once(
    path,
    "  void _onViewportCommand() {\n    if (mounted) {\n      setState(() {});\n    }\n  }\n\n",
    "  void _onViewportCommand() {\n    if (mounted) {\n      setState(() {});\n    }\n  }\n\n  void _cancelTransientInteraction() {\n    if (_dragKind != null) {\n      _finishPrimaryDrag(cancelled: true);\n    }\n    _panAnchor = null;\n    _panPointer = null;\n    _primaryDragPointer = null;\n    _activePointers.clear();\n    _touchStartCamera = null;\n    _touchStartFocal = null;\n  }\n\n",
)
# Assign pointer ownership on every persistent drag start.
for old, new in [
    ("      _dragKind = openingHandle;\n", "      _primaryDragPointer = event.pointer;\n      _dragKind = openingHandle;\n"),
    ("      _dragKind = _PlanDragKind.openingMove;\n", "      _primaryDragPointer = event.pointer;\n      _dragKind = _PlanDragKind.openingMove;\n"),
    ("      _dragKind = _PlanDragKind.vertex;\n", "      _primaryDragPointer = event.pointer;\n      _dragKind = _PlanDragKind.vertex;\n"),
    ("      _dragKind = _PlanDragKind.edge;\n", "      _primaryDragPointer = event.pointer;\n      _dragKind = _PlanDragKind.edge;\n"),
]:
    replace_once(path, old, new)
replace_once(
    path,
    "    final kind = _dragKind;\n    if (kind == null || event.buttons != kPrimaryMouseButton) {\n",
    "    final kind = _dragKind;\n    if (kind == null ||\n        event.pointer != _primaryDragPointer ||\n        event.buttons != kPrimaryMouseButton) {\n",
)
replace_once(
    path,
    "      _dragKind = null;\n      _dragIndex = null;\n",
    "      _dragKind = null;\n      _primaryDragPointer = null;\n      _dragIndex = null;\n",
)
replace_once(
    path,
    """                onPointerDown: (event) {\n                  if (event.buttons == kMiddleMouseButton) {\n                    _panAnchor = event.localPosition;\n                    return;\n                  }\n                  if (event.buttons == kPrimaryMouseButton) {\n                    _beginPrimaryDrag(event);\n                  }\n                },\n""",
    """                onPointerDown: (event) {\n                  _activePointers.add(event.pointer);\n                  if (_activePointers.length > 1) {\n                    if (_dragKind != null) {\n                      _finishPrimaryDrag(cancelled: true);\n                    }\n                    return;\n                  }\n                  if (event.buttons == kMiddleMouseButton) {\n                    _panPointer = event.pointer;\n                    _panAnchor = event.localPosition;\n                    return;\n                  }\n                  if (event.buttons == kPrimaryMouseButton) {\n                    _beginPrimaryDrag(event);\n                  }\n                },\n""",
)
replace_once(
    path,
    """                  final anchor = _panAnchor;\n                  if (anchor != null) {\n""",
    """                  final anchor = _panAnchor;\n                  if (anchor != null && event.pointer == _panPointer) {\n""",
)
replace_once(
    path,
    """                onPointerUp: (_) {\n                  _panAnchor = null;\n                  _finishPrimaryDrag(cancelled: false);\n                },\n                onPointerCancel: (_) {\n                  _panAnchor = null;\n                  _finishPrimaryDrag(cancelled: true);\n                },\n""",
    """                onPointerUp: (event) {\n                  _activePointers.remove(event.pointer);\n                  if (event.pointer == _panPointer) {\n                    _panPointer = null;\n                    _panAnchor = null;\n                  }\n                  if (event.pointer == _primaryDragPointer) {\n                    _finishPrimaryDrag(cancelled: false);\n                  }\n                },\n                onPointerCancel: (event) {\n                  _activePointers.remove(event.pointer);\n                  if (event.pointer == _panPointer) {\n                    _panPointer = null;\n                    _panAnchor = null;\n                  }\n                  if (event.pointer == _primaryDragPointer) {\n                    _finishPrimaryDrag(cancelled: true);\n                  }\n                },\n""",
)

path = 'lib/src/features/editor/surface_canvas.dart'
replace_once(
    path,
    "    controller.viewportCommandListenable.addListener(_onViewportCommand);\n    controller.p2.addListener(_onP2Changed);\n",
    "    controller.viewportCommandListenable.addListener(_onViewportCommand);\n    controller.editCancellationListenable.addListener(_onEditCancellationRequested);\n    controller.p2.addListener(_onP2Changed);\n",
)
replace_once(
    path,
    "      oldWidget.controller.p2.removeListener(_onP2Changed);\n",
    "      oldWidget.controller.editCancellationListenable.removeListener(\n        _onEditCancellationRequested,\n      );\n      oldWidget.controller.p2.removeListener(_onP2Changed);\n",
)
replace_once(
    path,
    "      controller.viewportCommandListenable.addListener(_onViewportCommand);\n      controller.p2.addListener(_onP2Changed);\n",
    "      controller.viewportCommandListenable.addListener(_onViewportCommand);\n      controller.editCancellationListenable.addListener(_onEditCancellationRequested);\n      controller.p2.addListener(_onP2Changed);\n",
)
replace_once(
    path,
    "    controller.p2.removeListener(_onP2Changed);\n",
    "    controller.editCancellationListenable.removeListener(\n      _onEditCancellationRequested,\n    );\n    controller.p2.removeListener(_onP2Changed);\n",
)
replace_once(
    path,
    "  void _onViewportCommand() {\n    if (mounted) setState(() {});\n  }\n\n",
    "  void _onViewportCommand() {\n    if (mounted) setState(() {});\n  }\n\n  void _onEditCancellationRequested() {\n    _cancelActiveInteractions(controller);\n    _panAnchor = null;\n    _marqueeStart = null;\n    _marqueeCurrent = null;\n    if (controller.boundaryEditing.active) {\n      controller.boundaryEditing.exit(force: true);\n    }\n    if (mounted) setState(() {});\n  }\n\n",
)

# F14 — crash-safe recovery publication with backup/temp fallback.
path = 'lib/src/features/editor/editor_project_recovery.dart'
replace_once(
    path,
    """    final target = _target(snapshot.projectId);\n    final temp = File('${target.path}.tmp');\n    if (await temp.exists()) await temp.delete();\n    await temp.writeAsString(encoded, flush: true);\n    if (await target.exists()) await target.delete();\n    await temp.rename(target.path);\n""",
    """    final target = _target(snapshot.projectId);\n    final temp = File('${target.path}.tmp');\n    final backup = File('${target.path}.bak');\n    if (await temp.exists()) await temp.delete();\n    await temp.writeAsString(encoded, flush: true);\n    if (await backup.exists()) await backup.delete();\n    if (await target.exists()) {\n      await target.rename(backup.path);\n    }\n    try {\n      await temp.rename(target.path);\n      if (await backup.exists()) await backup.delete();\n    } catch (_) {\n      if (!await target.exists() && await backup.exists()) {\n        await backup.rename(target.path);\n      }\n      rethrow;\n    }\n""",
)
replace_once(
    path,
    """  Future<EditorProjectRecoverySnapshot?> load(String projectId) async {\n    final target = _target(projectId);\n    if (!await target.exists()) return null;\n    final raw = jsonDecode(await target.readAsString());\n    if (raw is! Map) {\n      throw const FormatException('ElecX recovery root must be an object.');\n    }\n    final snapshot = EditorProjectRecoverySnapshot.fromJson(\n      raw.map((key, value) => MapEntry(key.toString(), value)),\n    );\n    if (snapshot.projectId != projectId) {\n      throw const FormatException('Recovery project id mismatch.');\n    }\n    return snapshot;\n  }\n""",
    """  Future<EditorProjectRecoverySnapshot?> load(String projectId) async {\n    final target = _target(projectId);\n    final candidates = <File>[\n      target,\n      File('${target.path}.bak'),\n      File('${target.path}.tmp'),\n    ];\n    EditorProjectRecoverySnapshot? best;\n    for (final file in candidates) {\n      final snapshot = await _tryRead(file, expectedProjectId: projectId);\n      if (snapshot != null &&\n          (best == null || snapshot.capturedAt.isAfter(best.capturedAt))) {\n        best = snapshot;\n      }\n    }\n    return best;\n  }\n""",
)
replace_once(
    path,
    """      if (entity is! File || !entity.path.endsWith('.elecx.recovery.json')) {\n        continue;\n      }\n      final raw = jsonDecode(await entity.readAsString());\n      if (raw is! Map) continue;\n      result.add(\n        EditorProjectRecoverySnapshot.fromJson(\n          raw.map((key, value) => MapEntry(key.toString(), value)),\n        ),\n      );\n""",
    """      if (entity is! File ||\n          (!entity.path.endsWith('.elecx.recovery.json') &&\n              !entity.path.endsWith('.elecx.recovery.json.bak') &&\n              !entity.path.endsWith('.elecx.recovery.json.tmp'))) {\n        continue;\n      }\n      final snapshot = await _tryRead(entity);\n      if (snapshot == null) continue;\n      final existingIndex =\n          result.indexWhere((item) => item.projectId == snapshot.projectId);\n      if (existingIndex == -1) {\n        result.add(snapshot);\n      } else if (snapshot.capturedAt.isAfter(result[existingIndex].capturedAt)) {\n        result[existingIndex] = snapshot;\n      }\n""",
)
replace_once(
    path,
    """    final target = _target(projectId);\n    final temp = File('${target.path}.tmp');\n    if (await target.exists()) await target.delete();\n    if (await temp.exists()) await temp.delete();\n  }\n\n  File _target(String projectId) {\n""",
    """    final target = _target(projectId);\n    final temp = File('${target.path}.tmp');\n    final backup = File('${target.path}.bak');\n    if (await target.exists()) await target.delete();\n    if (await temp.exists()) await temp.delete();\n    if (await backup.exists()) await backup.delete();\n  }\n\n  Future<EditorProjectRecoverySnapshot?> _tryRead(\n    File file, {\n    String? expectedProjectId,\n  }) async {\n    if (!await file.exists()) return null;\n    try {\n      final raw = jsonDecode(await file.readAsString());\n      if (raw is! Map) return null;\n      final snapshot = EditorProjectRecoverySnapshot.fromJson(\n        raw.map((key, value) => MapEntry(key.toString(), value)),\n      );\n      if (expectedProjectId != null && snapshot.projectId != expectedProjectId) {\n        return null;\n      }\n      return snapshot;\n    } catch (_) {\n      return null;\n    }\n  }\n\n  File _target(String projectId) {\n""",
)

# F03 — structural boundary edits validate existing electrical model before commit.
path = 'lib/src/features/editor/plan_geometry_editor_actions.dart'
replace_once(
    path,
    "import '../../engine/plan_geometry_editing.dart';\nimport 'editor_controller.dart';\n",
    "import '../../engine/normative_route_engine.dart';\nimport '../../engine/plan_geometry_editing.dart';\nimport 'editor_controller.dart';\nimport 'editor_p2_session.dart';\n",
)
replace_once(
    path,
    """    for (final replacement in replacements.values) {\n      if (!_spaceGeometryIsCompatible(replacement)) {\n        return false;\n      }\n    }\n\n""",
    """    for (final replacement in replacements.values) {\n      if (!_spaceGeometryIsCompatible(replacement) ||\n          !_spaceElectricalModelIsCompatible(replacement)) {\n        return false;\n      }\n    }\n\n""",
)
insert_anchor = "  /// Returns true only when this selected-room edge is not shared by another\n"
helper = r'''  bool _spaceElectricalModelIsCompatible(EngineeringSpace candidateSpace) {
    RouteNormativeContext? contextFor(RoomSurfaceRef surface) {
      if (surface.spaceId != candidateSpace.id) return null;
      if (surface.type == SurfacePlaneType.wall) {
        final wallIndex = surface.wallIndex;
        final walls = RoomSurfaceResolver.walls(candidateSpace);
        if (wallIndex == null || wallIndex < 0 || wallIndex >= walls.length) {
          return null;
        }
        final wall = walls[wallIndex];
        return RouteNormativeContext(
          surface: surface,
          widthMm: wall.lengthMm.round(),
          heightMm: wall.heightMm,
          edgeClearanceMm: 0,
          boundary: [
            for (final point in wall.profile.vertices)
              SurfacePointMm(point.xMm, point.yMm),
          ],
          obstacles: [
            for (final opening in openings)
              if (opening.hostWall == surface)
                RouteObstacleMm(
                  id: opening.id,
                  leftMm: opening.offsetFromStartMm,
                  topMm: opening.sillHeightMm,
                  rightMm: opening.endOffsetMm,
                  bottomMm: opening.topMm,
                ),
          ],
        );
      }
      final bounds = candidateSpace.boundary.bounds;
      return RouteNormativeContext(
        surface: surface,
        widthMm: bounds.width,
        heightMm: bounds.height,
        edgeClearanceMm: 0,
        boundary: [
          for (final point in candidateSpace.boundary.vertices)
            SurfacePointMm(point.x - bounds.left, point.y - bounds.bottom),
        ],
      );
    }

    bool containsPoint(SurfacePointMm point, RouteNormativeContext context) {
      if (point.xMm < 0 ||
          point.yMm < 0 ||
          point.xMm > context.widthMm ||
          point.yMm > context.heightMm) {
        return false;
      }
      final polygon = context.boundary;
      if (polygon == null || polygon.isEmpty) return true;
      var inside = false;
      for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
        final a = polygon[j];
        final b = polygon[i];
        final cross = (b.xMm - a.xMm) * (point.yMm - a.yMm) -
            (b.yMm - a.yMm) * (point.xMm - a.xMm);
        if (cross == 0 &&
            point.xMm >= math.min(a.xMm, b.xMm) &&
            point.xMm <= math.max(a.xMm, b.xMm) &&
            point.yMm >= math.min(a.yMm, b.yMm) &&
            point.yMm <= math.max(a.yMm, b.yMm)) {
          return true;
        }
        final crosses = (a.yMm > point.yMm) != (b.yMm > point.yMm);
        if (!crosses) continue;
        final crossingX = (b.xMm - a.xMm) *
                (point.yMm - a.yMm) /
                (b.yMm - a.yMm) +
            a.xMm;
        if (point.xMm < crossingX) inside = !inside;
      }
      return inside;
    }

    for (final component in p2.components) {
      if (component.surface.spaceId != candidateSpace.id) continue;
      final context = contextFor(component.surface);
      if (context == null || !containsPoint(component.position, context)) {
        return false;
      }
    }
    for (final route in p2.routes) {
      for (final segment in route.segments) {
        if (segment.surface.spaceId != candidateSpace.id) continue;
        final context = contextFor(segment.surface);
        if (context == null ||
            !NormativeRouteEngine.validate(
              points: segment.points,
              context: context,
            ).isValid) {
          return false;
        }
      }
    }
    return true;
  }

'''
p = Path(path)
text = p.read_text()
if insert_anchor not in text:
    raise SystemExit('plan_geometry_editor_actions.dart: helper insertion anchor missing')
p.write_text(text.replace(insert_anchor, helper + insert_anchor, 1))

# Regression tests: vertex-touch polygon bug + atomic circuit rebind + recovery fallback.
Path('test/p1_integrity_hardening_test.dart').write_text(r'''import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/editor_project_recovery.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concave boundary rejects segment that exits through polygon vertices', () {
    final context = RouteNormativeContext(
      surface: RoomSurfaceRef.floor('room'),
      widthMm: 10000,
      heightMm: 6000,
      edgeClearanceMm: 0,
      boundary: const [
        SurfacePointMm(0, 0),
        SurfacePointMm(10000, 0),
        SurfacePointMm(10000, 6000),
        SurfacePointMm(7000, 6000),
        SurfacePointMm(7000, 1500),
        SurfacePointMm(3000, 1500),
        SurfacePointMm(3000, 6000),
        SurfacePointMm(0, 6000),
      ],
    );
    final result = NormativeRouteEngine.validate(
      points: const [
        SurfacePointMm(500, 1500),
        SurfacePointMm(9500, 1500),
      ],
      context: context,
    );
    expect(result.isValid, isFalse);
  });

  test('assigned cable route rebind updates engineering identity atomically', () {
    final editor = EditorController.demo();
    addTearDown(() {
      editor.disposeP2State();
      editor.dispose();
    });
    final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
    final board = editor.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(200, 2000),
    );
    final loadA = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1200, 2000),
    );
    final loadB = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1200, 2000),
    );
    final bundle = editor.p2.connectLoadToBoard(
      loadComponentId: loadA.id,
      boardComponentId: board.id,
      space: editor.selectedSpace,
    );
    expect(bundle, isNotNull);
    final before = editor.p2.routes.singleWhere(
      (route) => route.id == bundle!.cable.routeId,
    );
    final after = ElectricalCableRoute(
      id: before.id,
      source: before.source,
      target: ElectricalEndpointRef(
        componentId: loadB.id,
        portId: before.target.portId,
      ),
      segments: before.segments,
      cableType: before.cableType,
      medium: before.medium,
      reservePercent: before.reservePercent,
    );

    expect(editor.p2.replaceCableRoute(before, after), isTrue);
    final rebound = editor.p2.circuitBundleForRoute(before.id)!;
    expect(rebound.cable.endB.componentId, loadB.id);
    expect(rebound.cable.endB.portId, after.target.portId);
    expect(editor.p2.routes.singleWhere((route) => route.id == before.id).target.componentId, loadB.id);

    editor.p2.undo();
    final restored = editor.p2.circuitBundleForRoute(before.id)!;
    expect(restored.cable.endB.componentId, loadA.id);
  });

  test('recovery load falls back to backup after interrupted publication', () async {
    final root = await Directory.systemTemp.createTemp('elecx-recovery-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final metadata = EditorProjectMetadata.create(projectName: 'Recovery test');
    final document = EditorProjectDocument.capture(workspace, metadata: metadata);
    final snapshot = EditorProjectRecoverySnapshot(
      capturedAt: DateTime.utc(2026, 10, 20, 12),
      revision: 7,
      document: document,
    );
    final store = JsonFileEditorProjectRecoveryStore(root);
    await store.save(snapshot);

    final encodedId = base64Url.encode(utf8.encode(metadata.projectId)).replaceAll('=', '');
    final target = File('${root.path}/$encodedId.elecx.recovery.json');
    final backup = File('${target.path}.bak');
    await target.rename(backup.path);
    await File('${target.path}.tmp').writeAsString('{broken', flush: true);

    final recovered = await store.load(metadata.projectId);
    expect(recovered, isNotNull);
    expect(recovered!.revision, 7);
    expect(recovered.projectId, metadata.projectId);
  });
}
''')
