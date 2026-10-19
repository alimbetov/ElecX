from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 occurrence, found {count}: {old[:120]!r}')
    path.write_text(text.replace(old, new, 1))

# 1) SurfacePointMm is a value object.
surfaces = Path('lib/src/domain/surfaces.dart')
replace_once(
    surfaces,
    "final class SurfacePointMm {\n  const SurfacePointMm(this.xMm, this.yMm);\n\n  final int xMm;\n  final int yMm;\n}\n",
    "final class SurfacePointMm {\n  const SurfacePointMm(this.xMm, this.yMm);\n\n  final int xMm;\n  final int yMm;\n\n  @override\n  bool operator ==(Object other) =>\n      other is SurfacePointMm && other.xMm == xMm && other.yMm == yMm;\n\n  @override\n  int get hashCode => Object.hash(xMm, yMm);\n}\n",
)

# 2) Move undoable cable replacement inside EditorP2Session.
p2 = Path('lib/src/features/editor/editor_p2_session.dart')
replace_once(
    p2,
    "  bool moveSelectedComponent(SurfacePointMm point) {\n",
    "  bool replaceCableRoute(\n    ElectricalCableRoute before,\n    ElectricalCableRoute after,\n  ) {\n    if (before.id != after.id || layers.isLocked(EditorLayerId.cableRoutes)) {\n      return false;\n    }\n    if (!routes.any((route) => route.id == before.id)) return false;\n    if (!ElectricalConnectivityValidator.routeIsConnected(\n      route: after,\n      components: components,\n    )) {\n      return false;\n    }\n    history.execute(_ReplaceCableRouteCommand(before: before, after: after));\n    notifyListeners();\n    return true;\n  }\n\n  bool moveSelectedComponent(SurfacePointMm point) {\n",
)
replace_once(
    p2,
    "final Expando<EditorP2Session> _p2Sessions = Expando<EditorP2Session>(\n",
    "final class _ReplaceCableRouteCommand implements EditorCommand<EditorP2State> {\n  const _ReplaceCableRouteCommand({required this.before, required this.after});\n\n  final ElectricalCableRoute before;\n  final ElectricalCableRoute after;\n\n  @override\n  String get label => 'Edit cable route';\n\n  @override\n  EditorP2State execute(EditorP2State state) => _replace(state, before.id, after);\n\n  @override\n  EditorP2State undo(EditorP2State state) => _replace(state, after.id, before);\n\n  static EditorP2State _replace(\n    EditorP2State state,\n    String routeId,\n    ElectricalCableRoute replacement,\n  ) => state.copyWith(\n    routes: [\n      for (final route in state.routes)\n        if (route.id == routeId) replacement else route,\n    ],\n  );\n}\n\nfinal Expando<EditorP2Session> _p2Sessions = Expando<EditorP2Session>(\n",
)

access = Path('lib/src/features/editor/cable_edit_access.dart')
access.write_text("""import 'cable_endpoint_transform_session.dart';
import 'cable_route_edit_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

final Expando<CableRouteEditSession> _routeEditSessions =
    Expando<CableRouteEditSession>('ElecX cable route edit session');
final Expando<CableEndpointTransformSession> _endpointTransformSessions =
    Expando<CableEndpointTransformSession>(
      'ElecX cable endpoint transform session',
    );

extension CableEditSessionAccess on EditorController {
  CableRouteEditSession get cableRouteEdit =>
      _routeEditSessions[this] ??= CableRouteEditSession(
        onCommit: p2.replaceCableRoute,
      );

  CableEndpointTransformSession get cableEndpointTransform =>
      _endpointTransformSessions[this] ??= CableEndpointTransformSession(
        onCommit: p2.replaceCableRoute,
      );
}
""")

# 3) Component no-op commit must close transaction.
component = Path('lib/src/features/editor/component_transform_session.dart')
replace_once(
    component,
    "    final current = _preview;\n    if (current == null || !current.isValid || !current.dirty) return false;\n    final committed = controller.p2.commitMoveSelectedComponent();\n",
    "    final current = _preview;\n    if (current == null || !current.isValid) return false;\n    if (!current.dirty) {\n      controller.p2.cancelMoveSelectedComponent();\n      _preview = null;\n      _phase = EditorEditSessionPhase.cancelled;\n      notifyListeners();\n      return false;\n    }\n    final committed = controller.p2.commitMoveSelectedComponent();\n",
)

# 4) Waypoints become real guards.
ui = Path('lib/src/features/editor/cable_editor_ui_session.dart')
replace_once(
    ui,
    "  bool routeHasLockedSegments(String routeId) =>\n      _lockedSegments[routeId]?.isNotEmpty ?? false;\n\n",
    "  bool routeHasLockedSegments(String routeId) =>\n      _lockedSegments[routeId]?.isNotEmpty ?? false;\n\n  bool segmentHasWaypoints(String routeId, int segmentIndex) =>\n      (_waypoints[routeId] ?? const <CableMandatoryWaypoint>[]).any(\n        (item) => item.segmentIndex == segmentIndex,\n      );\n\n",
)

# 5) Multi-surface endpoint hit-test.
hit = Path('lib/src/features/editor/cable_canvas_hit_testing.dart')
replace_once(
    hit,
    "    if (route.segments.length != 1) return null;\n    final segment = route.segments.single;\n    if (segment.surface != surface || segment.points.length < 2) return null;\n\n    final source = segment.points.first;\n    if (_distance(point, source) <= radiusMm) {\n      return CableEndpointHit(\n        route: route,\n        segmentIndex: 0,\n        role: CableEndpointRole.source,\n        point: source,\n      );\n    }\n    final target = segment.points.last;\n    if (_distance(point, target) <= radiusMm) {\n      return CableEndpointHit(\n        route: route,\n        segmentIndex: 0,\n        role: CableEndpointRole.target,\n        point: target,\n      );\n    }\n",
    "    if (route.segments.isEmpty) return null;\n    final first = route.segments.first;\n    if (first.surface == surface && first.points.length >= 2) {\n      final source = first.points.first;\n      if (_distance(point, source) <= radiusMm) {\n        return CableEndpointHit(\n          route: route,\n          segmentIndex: 0,\n          role: CableEndpointRole.source,\n          point: source,\n        );\n      }\n    }\n    final lastIndex = route.segments.length - 1;\n    final last = route.segments[lastIndex];\n    if (last.surface == surface && last.points.length >= 2) {\n      final target = last.points.last;\n      if (_distance(point, target) <= radiusMm) {\n        return CableEndpointHit(\n          route: route,\n          segmentIndex: lastIndex,\n          role: CableEndpointRole.target,\n          point: target,\n        );\n      }\n    }\n",
)

# 6) Multi-surface endpoint transform: rebuild only first/last segment.
endpoint = Path('lib/src/features/editor/cable_endpoint_transform_session.dart')
replace_once(
    endpoint,
    "    if (route.segments.length != 1 ||\n        route.segments.single.surface != context.surface ||\n        route.segments.single.points.length < 2) {\n      return false;\n    }\n",
    "    if (route.segments.isEmpty) return false;\n    final segment = role == CableEndpointRole.source\n        ? route.segments.first\n        : route.segments.last;\n    if (segment.surface != context.surface || segment.points.length < 2) {\n      return false;\n    }\n",
)
replace_once(
    endpoint,
    "    final segment = origin.segments.single;\n    final fixedPoint = role == CableEndpointRole.target\n        ? segment.points.first\n        : segment.points.last;\n",
    "    final segmentIndex = role == CableEndpointRole.source\n        ? 0\n        : origin.segments.length - 1;\n    final segment = origin.segments[segmentIndex];\n    final fixedPoint = role == CableEndpointRole.target\n        ? segment.points.first\n        : segment.points.last;\n",
)
replace_once(
    endpoint,
    "      segments: [\n        ElectricalRouteSegment(surface: segment.surface, points: best.points),\n      ],\n",
    "      segments: [\n        for (var i = 0; i < origin.segments.length; i++)\n          if (i == segmentIndex)\n            ElectricalRouteSegment(surface: segment.surface, points: best.points)\n          else\n            origin.segments[i],\n      ],\n",
)

# 7) Wire P1-P10 into SurfaceCanvas.
canvas = Path('lib/src/features/editor/surface_canvas.dart')
text = canvas.read_text()

def c(old, new):
    global text
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'surface_canvas expected 1, found {n}: {old[:100]!r}')
    text = text.replace(old, new, 1)

c("import '../../domain/electrical_placement.dart';\n", "import '../../domain/electrical_placement.dart';\nimport '../../domain/electrical_routing.dart';\n")
c("import '../../engine/editor_layers.dart';\n", "import '../../engine/editor_layers.dart';\nimport '../../engine/normative_route_engine.dart';\n")
c("import 'boundary_edit_session.dart';\n", "import 'boundary_edit_session.dart';\nimport 'cable_canvas_hit_testing.dart';\nimport 'cable_edit_access.dart';\nimport 'cable_editor_ui_session.dart';\nimport 'cable_route_controls.dart';\n")
c("import 'editor_controller.dart';\n", "import 'component_transform_session.dart';\nimport 'editor_controller.dart';\nimport 'editor_interaction_policy.dart';\n")
c("  String? _dragComponentId;\n  SurfacePointMm? _dragStartPosition;\n", "  String? _dragComponentId;\n  SurfacePointMm? _dragStartPosition;\n  CableCanvasHit? _cableDragHit;\n  final Set<int> _activePointers = <int>{};\n")

c("    controller.routeSelection.addListener(_onRouteChanged);\n", "    controller.routeSelection.addListener(_onRouteChanged);\n    controller.componentTransform.addListener(_onInteractionChanged);\n    controller.cableRouteEdit.addListener(_onInteractionChanged);\n    controller.cableEndpointTransform.addListener(_onInteractionChanged);\n    controller.cableUi.addListener(_onInteractionChanged);\n")
c("      oldWidget.controller.routeSelection.removeListener(_onRouteChanged);\n", "      oldWidget.controller.routeSelection.removeListener(_onRouteChanged);\n      oldWidget.controller.componentTransform.removeListener(_onInteractionChanged);\n      oldWidget.controller.cableRouteEdit.removeListener(_onInteractionChanged);\n      oldWidget.controller.cableEndpointTransform.removeListener(_onInteractionChanged);\n      oldWidget.controller.cableUi.removeListener(_onInteractionChanged);\n")
c("      controller.routeSelection.addListener(_onRouteChanged);\n", "      controller.routeSelection.addListener(_onRouteChanged);\n      controller.componentTransform.addListener(_onInteractionChanged);\n      controller.cableRouteEdit.addListener(_onInteractionChanged);\n      controller.cableEndpointTransform.addListener(_onInteractionChanged);\n      controller.cableUi.addListener(_onInteractionChanged);\n")
c("    controller.routeSelection.removeListener(_onRouteChanged);\n", "    controller.routeSelection.removeListener(_onRouteChanged);\n    controller.componentTransform.removeListener(_onInteractionChanged);\n    controller.cableRouteEdit.removeListener(_onInteractionChanged);\n    controller.cableEndpointTransform.removeListener(_onInteractionChanged);\n    controller.cableUi.removeListener(_onInteractionChanged);\n")
c("  void _onRouteChanged() {\n    controller.routeSelection.normalize();\n    if (mounted) setState(() {});\n  }\n", "  void _onRouteChanged() {\n    controller.routeSelection.normalize();\n    if (mounted) setState(() {});\n  }\n\n  void _onInteractionChanged() {\n    if (mounted) setState(() {});\n  }\n")

old_nudge = """  void _nudgeSelectedComponent(
    int dxSteps,
    int dySteps,
    _SurfaceProjection projection,
  ) {
    final component = controller.p2.selectedComponent;
    if (component == null || component.surface != controller.activeSurface) {
      return;
    }
    final next = SurfacePointMm(
      component.position.xMm + dxSteps * _componentNudgeStepMm,
      component.position.yMm + dySteps * _componentNudgeStepMm,
    );
    if (!_pointIsUsable(next, projection)) {
      return;
    }
    controller.p2.moveSelectedComponent(next);
  }
"""
new_nudge = """  void _nudgeSelectedComponent(
    int dxSteps,
    int dySteps,
    _SurfaceProjection projection,
  ) {
    final component = controller.p2.selectedComponent;
    if (component == null || component.surface != controller.activeSurface) return;
    final session = controller.componentTransform;
    if (!session.begin()) return;
    final moved = session.nudge(
      dxMm: dxSteps * _componentNudgeStepMm,
      dyMm: dySteps * _componentNudgeStepMm,
      validator: (_, point) => _pointIsUsable(point, projection),
    );
    if (!moved || !session.commit()) session.cancel();
  }
"""
c(old_nudge, new_nudge)

marker = "  SurfacePointMm _applyDragConstraint(SurfacePointMm point) {\n"
insert = """  EditorInteractionPolicy _policy(PointerDeviceKind kind) =>
      EditorInteractionPolicy.forMode(switch (kind) {
        PointerDeviceKind.touch => EditorInputMode.touch,
        PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus =>
          EditorInputMode.stylus,
        _ => EditorInputMode.mouseKeyboard,
      });

  RouteNormativeContext _routeContext(_SurfaceProjection projection) {
    final surface = controller.activeSurface!;
    return RouteNormativeContext(
      surface: surface,
      widthMm: projection.extent.widthMm,
      heightMm: projection.extent.heightMm,
      edgeClearanceMm: 0,
      obstacles: surface.type == SurfacePlaneType.wall
          ? [
              for (final opening in controller.activeWallOpenings)
                RouteObstacleMm(
                  id: opening.id,
                  leftMm: opening.offsetFromStartMm,
                  topMm: opening.sillHeightMm,
                  rightMm: opening.endOffsetMm,
                  bottomMm: opening.topMm,
                ),
            ]
          : const [],
    );
  }

  CableCanvasHit? _cableHitAt(
    SurfacePointMm point,
    _SurfaceProjection projection,
    PointerDeviceKind kind,
  ) {
    final route = controller.routeSelection.selectedRoute;
    final surface = controller.activeSurface;
    if (route == null || surface == null) return null;
    return CableCanvasHitTesting.hitTest(
      route: route,
      surface: surface,
      point: point,
      radiusMm: _policy(kind).hitTargetPx * projection.camera.mmPerPixel,
    );
  }

  bool _beginCableDrag(CableCanvasHit hit, _SurfaceProjection projection) {
    final ui = controller.cableUi;
    switch (hit) {
      case CableEndpointHit endpoint:
        ui.focusGeometry(
          routeId: endpoint.route.id,
          segmentIndex: endpoint.segmentIndex,
          pointIndex: endpoint.role == CableEndpointRole.source
              ? 0
              : endpoint.route.segments[endpoint.segmentIndex].points.length - 1,
        );
        if (ui.isSegmentLocked(endpoint.route.id, endpoint.segmentIndex) ||
            ui.segmentHasWaypoints(endpoint.route.id, endpoint.segmentIndex)) {
          return false;
        }
        if (!controller.cableEndpointTransform.start(
          route: endpoint.route,
          role: endpoint.role,
          components: controller.p2.components,
          context: _routeContext(projection),
        )) return false;
      case CableVertexHit vertex:
        ui.focusGeometry(
          routeId: vertex.route.id,
          segmentIndex: vertex.segmentIndex,
          pointIndex: vertex.pointIndex,
        );
        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(vertex.route.id, vertex.segmentIndex) ||
            ui.isWaypoint(vertex.route.id, vertex.segmentIndex, vertex.pointIndex)) {
          return false;
        }
        if (!controller.cableRouteEdit.start(
          route: vertex.route,
          segmentIndex: vertex.segmentIndex,
          context: _routeContext(projection),
          mode: ui.mode,
        )) return false;
      case CableSegmentHit segment:
        ui.focusGeometry(routeId: segment.route.id, segmentIndex: segment.segmentIndex);
        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(segment.route.id, segment.segmentIndex) ||
            ui.segmentHasWaypoints(segment.route.id, segment.segmentIndex)) {
          return false;
        }
        if (!controller.cableRouteEdit.start(
          route: segment.route,
          segmentIndex: segment.segmentIndex,
          context: _routeContext(projection),
          mode: ui.mode,
        )) return false;
    }
    _cableDragHit = hit;
    return true;
  }

  void _previewCableDrag(
    PointerMoveEvent event,
    SurfacePointMm raw,
    _SurfaceProjection projection,
  ) {
    final hit = _cableDragHit;
    if (hit == null) return;
    switch (hit) {
      case CableEndpointHit _:
        final acquisition = math.max(
          20.0,
          _policy(event.kind).snapRadiusPx * projection.camera.mmPerPixel,
        );
        controller.cableEndpointTransform.preview(
          rawPoint: MmPoint(raw.xMm, raw.yMm),
          acquisitionRadiusMm: acquisition,
          releaseRadiusMm: acquisition * 1.65,
          gridStepMm: controller.selectedSpace?.grid.minorStepMm ?? 100,
        );
        controller.p2.updateSnap(controller.cableEndpointTransform.previewState?.snap);
      case CableVertexHit vertex:
        final segment = vertex.route.segments[vertex.segmentIndex];
        final target = controller.cableUi.mode == CableRoutingMode.assisted
            ? _snapSurfacePoint(raw, projection)
            : raw;
        controller.cableRouteEdit.preview(
          CableCanvasHitTesting.moveVertex(
            points: segment.points,
            pointIndex: vertex.pointIndex,
            target: target,
          ),
        );
      case CableSegmentHit segment:
        final routeSegment = segment.route.segments[segment.segmentIndex];
        final target = controller.cableUi.mode == CableRoutingMode.assisted
            ? _snapSurfacePoint(raw, projection)
            : raw;
        controller.cableRouteEdit.preview(
          CableCanvasHitTesting.moveSegment(
            points: routeSegment.points,
            edgeIndex: segment.edgeIndex,
            target: target,
          ),
        );
    }
  }

  void _toggleActiveWaypoint() {
    final ui = controller.cableUi;
    final route = controller.routeSelection.selectedRoute;
    final s = ui.activeSegmentIndex;
    final p = ui.activePointIndex;
    if (route == null || s == null || p == null || s >= route.segments.length || p >= route.segments[s].points.length) return;
    ui.toggleWaypoint(point: route.segments[s].points[p]);
  }

"""
c(marker, insert + marker)

old_finish = """    if (_dragComponentId != null) {
      if (cancelled) {
        controller.p2.cancelMoveSelectedComponent();
      } else {
        controller.p2.commitMoveSelectedComponent();
      }
    }
    _dragComponentId = null;
    _dragStartPosition = null;
    controller.p2.updateSnap(null);
"""
new_finish = """    final cableHit = _cableDragHit;
    if (cableHit != null) {
      if (cableHit is CableEndpointHit) {
        if (cancelled || !controller.cableEndpointTransform.commit()) {
          controller.cableEndpointTransform.cancel();
        }
      } else {
        if (cancelled || !controller.cableRouteEdit.commit()) {
          controller.cableRouteEdit.cancel();
        } else {
          final route = controller.routeSelection.selectedRoute;
          if (route != null) {
            controller.cableUi.reconcileRoutePoints(
              route.id,
              [for (final segment in route.segments) segment.points],
            );
          }
        }
      }
    }
    _cableDragHit = null;
    if (_dragComponentId != null) {
      if (cancelled || !controller.componentTransform.commit()) {
        controller.componentTransform.cancel();
      }
    }
    _dragComponentId = null;
    _dragStartPosition = null;
    controller.p2.updateSnap(null);
"""
c(old_finish, new_finish)

c("                onPointerDown: (event) {\n", "                onPointerDown: (event) {\n                  _activePointers.add(event.pointer);\n                  if (_activePointers.length > 1) {\n                    _finishPointer(projection, cancelled: true);\n                    return;\n                  }\n")
c("                  final raw = projection.viewportToSurface(event.localPosition);\n                  if (raw == null) return;\n                  final handleOwner = _componentForHandle(raw, projection);\n", "                  final raw = projection.viewportToSurface(event.localPosition);\n                  if (raw == null) return;\n                  final cableHit = _cableHitAt(raw, projection, event.kind);\n                  if (cableHit != null && _beginCableDrag(cableHit, projection)) return;\n                  final handleOwner = _componentForHandle(raw, projection);\n")
c("                    controller.p2.beginMoveSelectedComponent();\n", "                    controller.componentTransform.begin();\n")
old_move = """                  if (_dragComponentId != null &&
                      event.buttons == kPrimaryMouseButton) {
                    final raw = projection.viewportToSurface(
                      event.localPosition,
                    );
                    if (raw == null) return;
                    var point = _snapSurfacePoint(raw, projection);
                    point = _applyDragConstraint(point);
                    if (_pointIsUsable(point, projection)) {
                      controller.p2.previewMoveSelectedComponent(point);
                    }
                  }
"""
new_move = """                  final previewPosition = event.kind == PointerDeviceKind.touch
                      ? event.localPosition - Offset(0, _policy(event.kind).pointerPreviewOffsetPx)
                      : event.localPosition;
                  if (_cableDragHit != null && event.buttons != 0) {
                    final raw = projection.viewportToSurface(previewPosition);
                    if (raw == null) return;
                    _previewCableDrag(event, raw, projection);
                    return;
                  }
                  if (_dragComponentId != null && event.buttons != 0) {
                    final raw = projection.viewportToSurface(previewPosition);
                    if (raw == null) return;
                    var point = _snapSurfacePoint(raw, projection);
                    point = _applyDragConstraint(point);
                    controller.componentTransform.preview(
                      point,
                      isValid: _pointIsUsable(point, projection),
                    );
                  }
"""
c(old_move, new_move)
c("                onPointerUp: (_) =>\n                    _finishPointer(projection, cancelled: false),\n                onPointerCancel: (_) =>\n                    _finishPointer(projection, cancelled: true),\n", "                onPointerUp: (event) {\n                  _activePointers.remove(event.pointer);\n                  _finishPointer(projection, cancelled: false);\n                },\n                onPointerCancel: (event) {\n                  _activePointers.remove(event.pointer);\n                  _finishPointer(projection, cancelled: true);\n                },\n")

chip = """            if (controller.routeSelection.selectedRouteId case final routeId?)
              Positioned(
                left: 12,
                bottom: bottomEditorVisible ? 188 : 52,
                child: Chip(
                  avatar: const Icon(Icons.alt_route, size: 18),
                  label: Text('Трасса: $routeId · переходы активны'),
                ),
              ),
"""
controls = chip + """            if (controller.routeSelection.selectedRouteId != null)
              Positioned(
                left: compact ? 8 : 12,
                top: compact ? 56 : 60,
                child: CableRouteControls(
                  mode: controller.cableUi.mode,
                  onModeChanged: controller.cableUi.setMode,
                  segmentFocused: controller.cableUi.activeSegmentIndex != null,
                  segmentLocked: controller.cableUi.activeSegmentLocked,
                  onToggleSegmentLock: controller.cableUi.toggleActiveSegmentLock,
                  pointFocused: controller.cableUi.activePointIndex != null,
                  pointIsWaypoint: controller.cableUi.activePointIsWaypoint,
                  onToggleWaypoint: _toggleActiveWaypoint,
                ),
              ),
"""
c(chip, controls)

# Paint live preview + handles.
c("    for (final route in _allHostedRoutes()) {\n", "    for (final route in _allHostedRoutes()) {\n")
c("      }\n    }\n  }\n\n  void _drawHostedSegmentsOnHost(\n", "      }\n    }\n    _drawCableEditOverlay(canvas, activeSurface);\n  }\n\n  void _drawCableEditOverlay(Canvas canvas, RoomSurfaceRef activeSurface) {\n    final selected = controller.routeSelection.selectedRoute;\n    if (selected == null) return;\n    final endpointPreview = controller.cableEndpointTransform.previewState;\n    final routePreview = controller.cableRouteEdit.previewState;\n    final preview = endpointPreview?.route ?? routePreview?.route;\n    final validation = endpointPreview?.validation ?? routePreview?.validation;\n    if (preview != null) {\n      final color = validation == null || !validation.isValid\n          ? scheme.error\n          : validation.hasWarnings\n              ? Colors.amber.shade700\n              : Colors.green.shade600;\n      final paint = Paint()\n        ..style = PaintingStyle.stroke\n        ..strokeWidth = 4\n        ..strokeCap = StrokeCap.round\n        ..strokeJoin = StrokeJoin.round\n        ..color = color;\n      for (final segment in preview.segments) {\n        if (segment.surface == activeSurface) _drawRoutePoints(canvas, segment.points, paint);\n      }\n    }\n\n    for (var s = 0; s < selected.segments.length; s++) {\n      final segment = selected.segments[s];\n      if (segment.surface != activeSurface || segment.points.length < 2) continue;\n      for (var p = 0; p < segment.points.length; p++) {\n        final isEndpoint = (s == 0 && p == 0) ||\n            (s == selected.segments.length - 1 && p == segment.points.length - 1);\n        final isWaypoint = controller.cableUi.isWaypoint(selected.id, s, p);\n        final center = projection.surfaceToViewport(segment.points[p]);\n        canvas.drawCircle(\n          center,\n          isEndpoint ? 7 : 5,\n          Paint()\n            ..style = PaintingStyle.fill\n            ..color = isWaypoint ? scheme.tertiary : scheme.surface,\n        );\n        canvas.drawCircle(\n          center,\n          isEndpoint ? 7 : 5,\n          Paint()\n            ..style = PaintingStyle.stroke\n            ..strokeWidth = 2\n            ..color = controller.cableUi.isSegmentLocked(selected.id, s)\n                ? scheme.outline\n                : scheme.primary,\n        );\n      }\n    }\n  }\n\n  void _drawHostedSegmentsOnHost(\n")
canvas.write_text(text)

# 8) Regression tests for multi-surface endpoint and no-op transform lifecycle.
Path('test/interaction_hardening_regression_test.dart').write_text("""import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/normative_route_engine.dart';
import 'package:elecx/src/engine/port_snap_resolver.dart';
import 'package:elecx/src/features/editor/cable_canvas_hit_testing.dart';
import 'package:elecx/src/features/editor/cable_endpoint_transform_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('multi-surface route exposes source and target endpoint handles', () {
    final wallA = RoomSurfaceRef.wall('room', 0);
    final ceiling = RoomSurfaceRef.ceiling('room');
    final wallB = RoomSurfaceRef.wall('room', 2);
    final route = ElectricalCableRoute(
      id: 'r',
      source: const ElectricalEndpointRef(componentId: 'a', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 'b', portId: 'in'),
      segments: [
        ElectricalRouteSegment(surface: wallA, points: const [SurfacePointMm(10, 10), SurfacePointMm(10, 100)]),
        ElectricalRouteSegment(surface: ceiling, points: const [SurfacePointMm(10, 100), SurfacePointMm(900, 100)]),
        ElectricalRouteSegment(surface: wallB, points: const [SurfacePointMm(900, 100), SurfacePointMm(900, 10)]),
      ],
    );
    expect(CableCanvasHitTesting.hitTest(route: route, surface: wallA, point: const SurfacePointMm(10, 10), radiusMm: 5), isA<CableEndpointHit>());
    final target = CableCanvasHitTesting.hitTest(route: route, surface: wallB, point: const SurfacePointMm(900, 10), radiusMm: 5);
    expect(target, isA<CableEndpointHit>());
    expect((target! as CableEndpointHit).segmentIndex, 2);
  });

  test('multi-surface endpoint transform preserves unrelated segments', () {
    final wallA = RoomSurfaceRef.wall('room', 0);
    final ceiling = RoomSurfaceRef.ceiling('room');
    final route = ElectricalCableRoute(
      id: 'r',
      source: const ElectricalEndpointRef(componentId: 'a', portId: 'power-out'),
      target: const ElectricalEndpointRef(componentId: 'old', portId: 'power-in'),
      segments: [
        ElectricalRouteSegment(surface: wallA, points: const [SurfacePointMm(10, 10), SurfacePointMm(10, 100)]),
        ElectricalRouteSegment(surface: ceiling, points: const [SurfacePointMm(10, 100), SurfacePointMm(900, 100)]),
      ],
    );
    final components = [
      ElectricalComponentPlacement(id: 'a', type: ElectricalComponentType.powerSource, surface: wallA, position: const SurfacePointMm(10, 10), label: 'A', ports: ElectricalComponentDefaults.portsFor(ElectricalComponentType.powerSource)),
      ElectricalComponentPlacement(id: 'old', type: ElectricalComponentType.socketOutlet, surface: ceiling, position: const SurfacePointMm(900, 100), label: 'Old', ports: ElectricalComponentDefaults.portsFor(ElectricalComponentType.socketOutlet)),
      ElectricalComponentPlacement(id: 'new', type: ElectricalComponentType.socketOutlet, surface: ceiling, position: const SurfacePointMm(700, 300), label: 'New', ports: ElectricalComponentDefaults.portsFor(ElectricalComponentType.socketOutlet)),
    ];
    ElectricalCableRoute? committed;
    final session = CableEndpointTransformSession(onCommit: (_, after) { committed = after; return true; });
    expect(session.start(route: route, role: CableEndpointRole.target, components: components, context: RouteNormativeContext(surface: ceiling, widthMm: 1000, heightMm: 1000)), isTrue);
    expect(session.preview(rawPoint: const MmPoint(700, 300), acquisitionRadiusMm: 50, releaseRadiusMm: 80, gridStepMm: 100), isTrue);
    expect(session.commit(), isTrue);
    expect(committed!.segments.first.points, route.segments.first.points);
    expect(committed!.segments.length, 2);
    expect(committed!.target.componentId, 'new');
  });
}
""")
