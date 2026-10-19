from pathlib import Path

path = Path('lib/src/features/editor/surface_canvas.dart')
text = path.read_text()


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Expected one occurrence, found {count}: {old[:120]!r}')
    text = text.replace(old, new, 1)

replace_once(
    "import '../../domain/electrical_placement.dart';\n",
    "import '../../domain/electrical_placement.dart';\n"
    "import '../../domain/electrical_routing.dart';\n",
)
replace_once(
    "import '../../engine/editor_layers.dart';\n",
    "import '../../engine/editor_layers.dart';\n"
    "import '../../engine/normative_route_engine.dart';\n",
)
replace_once(
    "import 'boundary_edit_session.dart';\n",
    "import 'boundary_edit_session.dart';\n"
    "import 'cable_canvas_hit_testing.dart';\n"
    "import 'cable_edit_access.dart';\n"
    "import 'cable_editor_ui_session.dart';\n"
    "import 'cable_route_controls.dart';\n",
)
replace_once(
    "import 'editor_controller.dart';\n",
    "import 'component_transform_session.dart';\n"
    "import 'editor_controller.dart';\n"
    "import 'editor_edit_session.dart';\n"
    "import 'editor_interaction_policy.dart';\n",
)

replace_once(
    "  String? _dragComponentId;\n"
    "  SurfacePointMm? _dragStartPosition;\n"
    "  Offset? _marqueeStart;\n",
    "  String? _dragComponentId;\n"
    "  SurfacePointMm? _dragStartPosition;\n"
    "  CableCanvasHit? _cableDragHit;\n"
    "  Offset? _cablePointerPreview;\n"
    "  Offset? _marqueeStart;\n",
)

replace_once(
    "    controller.routeSelection.addListener(_onRouteChanged);\n",
    "    controller.routeSelection.addListener(_onRouteChanged);\n"
    "    controller.componentTransform.addListener(_onCableEditChanged);\n"
    "    controller.cableRouteEdit.addListener(_onCableEditChanged);\n"
    "    controller.cableEndpointTransform.addListener(_onCableEditChanged);\n"
    "    controller.cableUi.addListener(_onCableEditChanged);\n",
)

replace_once(
    "      oldWidget.controller.routeSelection.removeListener(_onRouteChanged);\n"
    "      _lastViewportRevision = controller.viewportCommandRevision;\n",
    "      oldWidget.controller.routeSelection.removeListener(_onRouteChanged);\n"
    "      oldWidget.controller.componentTransform.removeListener(\n"
    "        _onCableEditChanged,\n"
    "      );\n"
    "      oldWidget.controller.cableRouteEdit.removeListener(\n"
    "        _onCableEditChanged,\n"
    "      );\n"
    "      oldWidget.controller.cableEndpointTransform.removeListener(\n"
    "        _onCableEditChanged,\n"
    "      );\n"
    "      oldWidget.controller.cableUi.removeListener(_onCableEditChanged);\n"
    "      _lastViewportRevision = controller.viewportCommandRevision;\n",
)
replace_once(
    "      controller.routeSelection.addListener(_onRouteChanged);\n"
    "    }\n",
    "      controller.routeSelection.addListener(_onRouteChanged);\n"
    "      controller.componentTransform.addListener(_onCableEditChanged);\n"
    "      controller.cableRouteEdit.addListener(_onCableEditChanged);\n"
    "      controller.cableEndpointTransform.addListener(_onCableEditChanged);\n"
    "      controller.cableUi.addListener(_onCableEditChanged);\n"
    "    }\n",
)
replace_once(
    "    controller.routeSelection.removeListener(_onRouteChanged);\n"
    "    _routeFlow.dispose();\n",
    "    controller.routeSelection.removeListener(_onRouteChanged);\n"
    "    controller.componentTransform.removeListener(_onCableEditChanged);\n"
    "    controller.cableRouteEdit.removeListener(_onCableEditChanged);\n"
    "    controller.cableEndpointTransform.removeListener(_onCableEditChanged);\n"
    "    controller.cableUi.removeListener(_onCableEditChanged);\n"
    "    _routeFlow.dispose();\n",
)
replace_once(
    "  void _onRouteChanged() {\n"
    "    controller.routeSelection.normalize();\n"
    "    if (mounted) setState(() {});\n"
    "  }\n",
    "  void _onRouteChanged() {\n"
    "    controller.routeSelection.normalize();\n"
    "    if (mounted) setState(() {});\n"
    "  }\n\n"
    "  void _onCableEditChanged() {\n"
    "    if (mounted) setState(() {});\n"
    "  }\n",
)

old_nudge = '''  void _nudgeSelectedComponent(
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
'''
new_nudge = '''  void _nudgeSelectedComponent(
    int dxSteps,
    int dySteps,
    _SurfaceProjection projection,
  ) {
    final component = controller.p2.selectedComponent;
    if (component == null || component.surface != controller.activeSurface) {
      return;
    }
    final transform = controller.componentTransform;
    if (!transform.begin()) return;
    final moved = transform.nudge(
      dxMm: dxSteps * _componentNudgeStepMm,
      dyMm: dySteps * _componentNudgeStepMm,
      validator: (_, point) => _pointIsUsable(point, projection),
    );
    if (moved) {
      transform.commit();
    } else {
      transform.cancel();
    }
  }
'''
replace_once(old_nudge, new_nudge)

marker = '''  SurfacePointMm _applyDragConstraint(SurfacePointMm point) {
'''
insert = '''  EditorInputMode _inputModeFor(PointerDeviceKind kind) => switch (kind) {
    PointerDeviceKind.touch => EditorInputMode.touch,
    PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus =>
      EditorInputMode.stylus,
    _ => EditorInputMode.mouseKeyboard,
  };

  EditorInteractionPolicy _interactionPolicyFor(PointerDeviceKind kind) =>
      EditorInteractionPolicy.forMode(_inputModeFor(kind));

  RouteNormativeContext _routeNormativeContext(
    _SurfaceProjection projection,
  ) {
    final surface = controller.activeSurface!;
    final obstacles = <RouteObstacleMm>[];
    if (surface.type == SurfacePlaneType.wall) {
      for (final opening in controller.activeWallOpenings) {
        obstacles.add(
          RouteObstacleMm(
            id: opening.id,
            leftMm: opening.offsetFromStartMm,
            topMm: opening.sillHeightMm,
            rightMm: opening.endOffsetMm,
            bottomMm: opening.topMm,
          ),
        );
      }
    }
    return RouteNormativeContext(
      surface: surface,
      widthMm: projection.extent.widthMm,
      heightMm: projection.extent.heightMm,
      edgeClearanceMm: 0,
      obstacles: obstacles,
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
    final policy = _interactionPolicyFor(kind);
    return CableCanvasHitTesting.hitTest(
      route: route,
      surface: surface,
      point: point,
      radiusMm: policy.hitTargetPx * projection.camera.mmPerPixel,
    );
  }

  bool _beginCableDrag(
    CableCanvasHit hit,
    _SurfaceProjection projection,
  ) {
    final ui = controller.cableUi;
    switch (hit) {
      case CableEndpointHit endpoint:
        ui.focusGeometry(
          routeId: endpoint.route.id,
          segmentIndex: endpoint.segmentIndex,
          pointIndex: endpoint.role == CableEndpointRole.source
              ? 0
              : endpoint.route.segments.single.points.length - 1,
        );
        if (ui.routeHasLockedSegments(endpoint.route.id)) return false;
        final started = controller.cableEndpointTransform.start(
          route: endpoint.route,
          role: endpoint.role,
          components: controller.p2.components,
          context: _routeNormativeContext(projection),
        );
        if (!started) return false;
      case CableVertexHit vertex:
        ui.focusGeometry(
          routeId: vertex.route.id,
          segmentIndex: vertex.segmentIndex,
          pointIndex: vertex.pointIndex,
        );
        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(vertex.route.id, vertex.segmentIndex)) {
          return false;
        }
        final started = controller.cableRouteEdit.start(
          route: vertex.route,
          segmentIndex: vertex.segmentIndex,
          context: _routeNormativeContext(projection),
          mode: ui.mode,
        );
        if (!started) return false;
      case CableSegmentHit segment:
        ui.focusGeometry(
          routeId: segment.route.id,
          segmentIndex: segment.segmentIndex,
        );
        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(segment.route.id, segment.segmentIndex)) {
          return false;
        }
        final started = controller.cableRouteEdit.start(
          route: segment.route,
          segmentIndex: segment.segmentIndex,
          context: _routeNormativeContext(projection),
          mode: ui.mode,
        );
        if (!started) return false;
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
    _cablePointerPreview = event.localPosition;
    switch (hit) {
      case CableEndpointHit _:
        final policy = _interactionPolicyFor(event.kind);
        final acquisition = math.max(
          20.0,
          policy.snapRadiusPx * projection.camera.mmPerPixel,
        );
        controller.cableEndpointTransform.preview(
          rawPoint: MmPoint(raw.xMm, raw.yMm),
          acquisitionRadiusMm: acquisition,
          releaseRadiusMm: acquisition * 1.65,
          gridStepMm: controller.selectedSpace?.grid.minorStepMm ?? 100,
        );
        controller.p2.updateSnap(
          controller.cableEndpointTransform.previewState?.snap,
        );
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
    if (mounted) setState(() {});
  }

  Color _cablePreviewColor(ColorScheme scheme) {
    final validation =
        controller.cableEndpointTransform.previewState?.validation ??
        controller.cableRouteEdit.previewState?.validation;
    if (validation == null || !validation.isValid) return scheme.error;
    if (validation.hasWarnings) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  void _toggleActiveWaypoint() {
    final ui = controller.cableUi;
    final route = controller.routeSelection.selectedRoute;
    final segmentIndex = ui.activeSegmentIndex;
    final pointIndex = ui.activePointIndex;
    if (route == null ||
        segmentIndex == null ||
        pointIndex == null ||
        segmentIndex >= route.segments.length ||
        pointIndex >= route.segments[segmentIndex].points.length) {
      return;
    }
    ui.toggleWaypoint(point: route.segments[segmentIndex].points[pointIndex]);
  }

'''
replace_once(marker, insert + marker)

old_finish = '''    if (_dragComponentId != null) {
      if (cancelled) {
        controller.p2.cancelMoveSelectedComponent();
      } else {
        controller.p2.commitMoveSelectedComponent();
      }
    }
    _dragComponentId = null;
    _dragStartPosition = null;
    controller.p2.updateSnap(null);
'''
new_finish = '''    final cableHit = _cableDragHit;
    if (cableHit != null) {
      if (cableHit is CableEndpointHit) {
        if (cancelled) {
          controller.cableEndpointTransform.cancel();
        } else {
          controller.cableEndpointTransform.commit();
        }
      } else {
        if (cancelled) {
          controller.cableRouteEdit.cancel();
        } else {
          final committed = controller.cableRouteEdit.commit();
          if (committed) {
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
    }
    _cableDragHit = null;
    _cablePointerPreview = null;
    if (_dragComponentId != null) {
      if (cancelled) {
        controller.componentTransform.cancel();
      } else if (!controller.componentTransform.commit()) {
        controller.componentTransform.cancel();
      }
    }
    _dragComponentId = null;
    _dragStartPosition = null;
    controller.p2.updateSnap(null);
'''
replace_once(old_finish, new_finish)

old_pointer_down = '''                  final raw = projection.viewportToSurface(event.localPosition);
                  if (raw == null) return;
                  final handleOwner = _componentForHandle(raw, projection);
'''
new_pointer_down = '''                  final raw = projection.viewportToSurface(event.localPosition);
                  if (raw == null) return;
                  final cableHit = _cableHitAt(raw, projection, event.kind);
                  if (cableHit != null) {
                    _beginCableDrag(cableHit, projection);
                    return;
                  }
                  final handleOwner = _componentForHandle(raw, projection);
'''
replace_once(old_pointer_down, new_pointer_down)
replace_once(
    "                    controller.p2.beginMoveSelectedComponent();\n",
    "                    controller.componentTransform.begin();\n",
)

old_move = '''                  if (_dragComponentId != null &&
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
'''
new_move = '''                  if (_cableDragHit != null &&
                      event.buttons == kPrimaryMouseButton) {
                    final raw = projection.viewportToSurface(
                      event.localPosition,
                    );
                    if (raw == null) return;
                    _previewCableDrag(event, raw, projection);
                    return;
                  }
                  if (_dragComponentId != null &&
                      event.buttons == kPrimaryMouseButton) {
                    final raw = projection.viewportToSurface(
                      event.localPosition,
                    );
                    if (raw == null) return;
                    var point = _snapSurfacePoint(raw, projection);
                    point = _applyDragConstraint(point);
                    controller.componentTransform.preview(
                      point,
                      isValid: _pointIsUsable(point, projection),
                    );
                  }
'''
replace_once(old_move, new_move)

old_route_chip = '''            if (controller.routeSelection.selectedRouteId case final routeId?)
              Positioned(
                left: 12,
                bottom: bottomEditorVisible ? 188 : 52,
                child: Chip(
                  avatar: const Icon(Icons.alt_route, size: 18),
                  label: Text('Трасса: $routeId · переходы активны'),
                ),
              ),
'''
new_route_controls = '''            if (controller.routeSelection.selectedRoute case final route?)
              Positioned(
                left: compact ? 8 : 12,
                bottom: bottomEditorVisible ? 188 : 52,
                child: CableRouteControls(
                  mode: controller.cableUi.mode,
                  onModeChanged: controller.cableUi.setMode,
                  segmentFocused:
                      controller.cableUi.activeRouteId == route.id &&
                      controller.cableUi.activeSegmentIndex != null,
                  segmentLocked: controller.cableUi.activeSegmentLocked,
                  onToggleSegmentLock:
                      controller.cableUi.toggleActiveSegmentLock,
                  pointFocused:
                      controller.cableUi.activeRouteId == route.id &&
                      controller.cableUi.activePointIndex != null,
                  pointIsWaypoint: controller.cableUi.activePointIsWaypoint,
                  onToggleWaypoint: _toggleActiveWaypoint,
                ),
              ),
            if (_cablePointerPreview case final pointer?)
              Positioned(
                left: pointer.dx - 12,
                top: pointer.dy - 12,
                child: IgnorePointer(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _cablePreviewColor(scheme).withValues(alpha: 0.14),
                      border: Border.all(
                        color: _cablePreviewColor(scheme),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
'''
replace_once(old_route_chip, new_route_controls)

replace_once(
    "       super(repaint: flowAnimation);\n",
    "       super(\n"
    "         repaint: Listenable.merge([\n"
    "           flowAnimation,\n"
    "           controller.cableRouteEdit,\n"
    "           controller.cableEndpointTransform,\n"
    "           controller.cableUi,\n"
    "         ]),\n"
    "       );\n",
)

route_draw_marker = '''    for (final route in _allHostedRoutes()) {
'''
preview_draw = '''    final endpointPreview = controller.cableEndpointTransform.previewState;
    final routeEditPreview = controller.cableRouteEdit.previewState;
    final previewRoute = endpointPreview?.route ?? routeEditPreview?.route;
    final previewValidation =
        endpointPreview?.validation ?? routeEditPreview?.validation;
    if (previewRoute != null && previewValidation != null) {
      final color = !previewValidation.isValid
          ? Colors.red.shade600
          : previewValidation.hasWarnings
          ? Colors.amber.shade700
          : Colors.green.shade600;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;
      for (final segment in previewRoute.segments) {
        if (segment.surface == activeSurface) {
          _drawRoutePoints(canvas, segment.points, paint);
        }
      }
    }

'''
replace_once(route_draw_marker, preview_draw + route_draw_marker)

old_selected_block = '''      if (selected) {
        _drawFlow(canvas, route, activeHost, medium);
        _drawTransitionMarkers(canvas, route, activeHost);
        _drawLegacyTransitionMarkers(canvas, route.routeId, activeSurface);
      }
'''
new_selected_block = '''      if (selected) {
        _drawFlow(canvas, route, activeHost, medium);
        _drawTransitionMarkers(canvas, route, activeHost);
        _drawLegacyTransitionMarkers(canvas, route.routeId, activeSurface);
        _drawCableEditHandles(canvas, route.routeId, activeSurface);
      }
'''
replace_once(old_selected_block, new_selected_block)

handle_marker = '''  void _drawHostedSegmentsOnHost(
'''
handle_methods = '''  void _drawCableEditHandles(
    Canvas canvas,
    String routeId,
    RoomSurfaceRef activeSurface,
  ) {
    final route = controller.routeSelection.selectedRoute;
    if (route == null || route.id != routeId) return;
    final ui = controller.cableUi;
    final endpointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.green.shade600;
    final vertexPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = scheme.primary;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = scheme.surface;

    for (var s = 0; s < route.segments.length; s++) {
      final segment = route.segments[s];
      if (segment.surface != activeSurface || segment.points.length < 2) {
        continue;
      }
      if (route.segments.length == 1) {
        for (final point in [segment.points.first, segment.points.last]) {
          final center = projection.surfaceToViewport(point);
          canvas.drawCircle(center, 8, endpointPaint);
          canvas.drawCircle(center, 8, outline);
        }
      }
      for (var p = 1; p < segment.points.length - 1; p++) {
        final center = projection.surfaceToViewport(segment.points[p]);
        final isWaypoint = ui.isWaypoint(route.id, s, p);
        if (isWaypoint) {
          final diamond = Path()
            ..moveTo(center.dx, center.dy - 8)
            ..lineTo(center.dx + 8, center.dy)
            ..lineTo(center.dx, center.dy + 8)
            ..lineTo(center.dx - 8, center.dy)
            ..close();
          canvas.drawPath(diamond, Paint()..color = Colors.amber.shade700);
          canvas.drawPath(diamond, outline);
        } else {
          canvas.drawCircle(center, 6, vertexPaint);
          canvas.drawCircle(center, 6, outline);
        }
      }
      if (ui.isSegmentLocked(route.id, s)) {
        final points = segment.points;
        final midpoint = points[points.length ~/ 2];
        final center = projection.surfaceToViewport(midpoint);
        canvas.drawCircle(
          center,
          10,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.amber.shade800,
        );
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 7, height: 6),
          Paint()..color = Colors.amber.shade800,
        );
      }
    }
  }

'''
replace_once(handle_marker, handle_methods + handle_marker)

path.write_text(text)
print('surface_canvas.dart patched')
