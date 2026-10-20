import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/boundary_editing.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/geometry.dart';
import '../../domain/hosted_routing.dart';
import '../../domain/measurement_overlay.dart';
import '../../domain/route_host.dart';
import '../../domain/route_medium.dart';
import '../../domain/surface_navigation.dart';
import '../../domain/surfaces.dart';
import '../../engine/adaptive_grid.dart';
import '../../engine/constraint_engine.dart';
import '../../engine/direct_manipulation.dart';
import '../../engine/editor_layers.dart';
import '../../engine/normative_route_engine.dart';
import '../../engine/port_snap_resolver.dart';
import '../../engine/render_policy.dart';
import '../../engine/route_flow_visualization.dart';
import '../../engine/route_interaction_engine.dart';
import '../../engine/selection_engine.dart';
import '../../engine/snap_engine.dart';
import '../../engine/world_camera.dart';
import 'boundary_bottom_editor.dart';
import 'boundary_edit_panel.dart';
import 'boundary_edit_session.dart';
import 'cable_canvas_hit_testing.dart';
import 'cable_edit_access.dart';
import 'cable_editor_ui_session.dart';
import 'cable_route_controls.dart';
import 'cad_visual_tokens.dart';
import 'canvas_component_controls.dart';
import 'canvas_viewport_navigator.dart';
import 'component_transform_session.dart';
import 'editor_controller.dart';
import 'editor_interaction_policy.dart';
import 'editor_p2_session.dart';
import 'editor_viewport_commands.dart';
import 'hosted_route_session.dart';
import 'route_selection_session.dart';
import 'viewport_zoom_policy.dart';

class SurfaceCanvas extends StatefulWidget {
  const SurfaceCanvas({
    required this.controller,
    this.onOutdoorTransition,
    super.key,
  });

  final EditorController controller;

  /// Called when a selected hosted route crosses from an indoor surface to an
  /// outdoor/site host. The workspace can use it to switch to SiteMapCanvas
  /// without SurfaceCanvas knowing about navigation shell details.
  final ValueChanged<RouteHostTransition>? onOutdoorTransition;

  @override
  State<SurfaceCanvas> createState() => _SurfaceCanvasState();
}

class _SurfaceCanvasState extends State<SurfaceCanvas>
    with SingleTickerProviderStateMixin {
  WorldCamera? _camera;
  String? _surfaceId;
  Offset? _panAnchor;
  WorldCamera? _touchStartCamera;
  Offset? _touchStartFocal;
  String? _dragComponentId;
  SurfacePointMm? _dragStartPosition;
  CableCanvasHit? _cableDragHit;
  final Set<int> _activePointers = <int>{};
  Offset? _marqueeStart;
  Offset? _marqueeCurrent;
  int _lastViewportRevision = 0;
  Size _size = Size.zero;
  int _componentNudgeStepMm = 100;
  late final AnimationController _routeFlow;

  EditorController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _routeFlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _lastViewportRevision = controller.viewportCommandRevision;
    controller.viewportCommandListenable.addListener(_onViewportCommand);
    controller.p2.addListener(_onP2Changed);
    controller.boundaryEditing.addListener(_onBoundaryEditChanged);
    controller.hostedRoutes.addListener(_onRouteChanged);
    controller.routeSelection.addListener(_onRouteChanged);
    controller.componentTransform.addListener(_onInteractionChanged);
    controller.cableRouteEdit.addListener(_onInteractionChanged);
    controller.cableEndpointTransform.addListener(_onInteractionChanged);
    controller.cableUi.addListener(_onInteractionChanged);
    _syncRouteFlowAnimation();
  }

  @override
  void didUpdateWidget(covariant SurfaceCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.viewportCommandListenable.removeListener(
        _onViewportCommand,
      );
      oldWidget.controller.p2.removeListener(_onP2Changed);
      oldWidget.controller.boundaryEditing.removeListener(
        _onBoundaryEditChanged,
      );
      oldWidget.controller.hostedRoutes.removeListener(_onRouteChanged);
      oldWidget.controller.routeSelection.removeListener(_onRouteChanged);
      oldWidget.controller.componentTransform
          .removeListener(_onInteractionChanged);
      oldWidget.controller.cableRouteEdit.removeListener(_onInteractionChanged);
      oldWidget.controller.cableEndpointTransform
          .removeListener(_onInteractionChanged);
      oldWidget.controller.cableUi.removeListener(_onInteractionChanged);
      _lastViewportRevision = controller.viewportCommandRevision;
      controller.viewportCommandListenable.addListener(_onViewportCommand);
      controller.p2.addListener(_onP2Changed);
      controller.boundaryEditing.addListener(_onBoundaryEditChanged);
      controller.hostedRoutes.addListener(_onRouteChanged);
      controller.routeSelection.addListener(_onRouteChanged);
      controller.componentTransform.addListener(_onInteractionChanged);
      controller.cableRouteEdit.addListener(_onInteractionChanged);
      controller.cableEndpointTransform.addListener(_onInteractionChanged);
      controller.cableUi.addListener(_onInteractionChanged);
      _syncRouteFlowAnimation();
    }
  }

  @override
  void dispose() {
    controller.viewportCommandListenable.removeListener(_onViewportCommand);
    controller.p2.removeListener(_onP2Changed);
    controller.boundaryEditing.removeListener(_onBoundaryEditChanged);
    controller.hostedRoutes.removeListener(_onRouteChanged);
    controller.routeSelection.removeListener(_onRouteChanged);
    controller.componentTransform.removeListener(_onInteractionChanged);
    controller.cableRouteEdit.removeListener(_onInteractionChanged);
    controller.cableEndpointTransform.removeListener(_onInteractionChanged);
    controller.cableUi.removeListener(_onInteractionChanged);
    _routeFlow.dispose();
    super.dispose();
  }

  void _syncRouteFlowAnimation() {
    final shouldAnimate = controller.routeSelection.selectedRouteId != null;
    if (shouldAnimate) {
      if (!_routeFlow.isAnimating) _routeFlow.repeat();
      return;
    }
    if (_routeFlow.isAnimating) _routeFlow.stop();
    if (_routeFlow.value != 0) _routeFlow.value = 0;
  }

  void _onViewportCommand() {
    if (mounted) setState(() {});
  }

  void _onP2Changed() {
    controller.routeSelection.normalize();
    _syncRouteFlowAnimation();
    if (mounted) setState(() {});
  }

  void _onBoundaryEditChanged() {
    if (mounted) setState(() {});
  }

  void _onRouteChanged() {
    controller.routeSelection.normalize();
    _syncRouteFlowAnimation();
    if (mounted) setState(() {});
  }

  void _onInteractionChanged() {
    if (mounted) setState(() {});
  }

  WorldCamera _fittedCamera(_SurfaceExtent extent) {
    final base =
        _camera ?? const WorldCamera(centerMm: MmPoint(0, 0), mmPerPixel: 10);
    if (_size.isEmpty) return base;
    return base.fitBounds(
      bounds: MmBounds(
        left: 0,
        bottom: 0,
        right: math.max(1, extent.widthMm),
        top: math.max(1, extent.heightMm),
      ),
      viewportWidthPx: _size.width,
      viewportHeightPx: _size.height,
      paddingPx: 88,
    );
  }

  void _ensureCamera(_SurfaceExtent extent) {
    final id = controller.activeSurface?.id;
    if (_camera != null && _surfaceId == id) return;
    _surfaceId = id;
    _camera = _fittedCamera(extent);
  }

  double _fitScale(_SurfaceExtent extent) {
    if (_size.isEmpty) return 10;
    final usableWidth = math.max(1.0, _size.width - 176);
    final usableHeight = math.max(1.0, _size.height - 176);
    final scaleX = math.max(1, extent.widthMm) / usableWidth;
    final scaleY = math.max(1, extent.heightMm) / usableHeight;
    return math.max(scaleX, scaleY);
  }

  WorldCamera _zoomedCamera(
    Offset cursor,
    double factor,
    _SurfaceExtent extent,
  ) {
    final camera = _camera;
    if (camera == null || _size.isEmpty) {
      return camera ??
          const WorldCamera(centerMm: MmPoint(0, 0), mmPerPixel: 10);
    }
    final fitScale = _fitScale(extent);
    return camera.zoomAt(
      factor: factor,
      viewportWidthPx: _size.width,
      viewportHeightPx: _size.height,
      cursorXpx: cursor.dx,
      cursorYpx: cursor.dy,
      minMmPerPixel: ViewportZoomPolicy.minMmPerPixel(fitScale),
      maxMmPerPixel: ViewportZoomPolicy.maxMmPerPixel(fitScale),
    );
  }

  void _zoomAt(Offset cursor, double factor, _SurfaceExtent extent) {
    setState(() => _camera = _zoomedCamera(cursor, factor, extent));
  }

  void _panViewport(int dxSteps, int dySteps) {
    if (_camera == null || _size.isEmpty) return;
    setState(() {
      _camera = _camera!.panPixels(
        -dxSteps * _size.width * 0.22,
        dySteps * _size.height * 0.22,
      );
    });
  }

  void _nudgeSelectedComponent(
    int dxSteps,
    int dySteps,
    _SurfaceProjection projection,
  ) {
    final component = controller.p2.selectedComponent;
    if (component == null || component.surface != controller.activeSurface) {
      return;
    }
    final session = controller.componentTransform;
    if (!session.begin()) return;
    final moved = session.nudge(
      dxMm: dxSteps * _componentNudgeStepMm,
      dyMm: dySteps * _componentNudgeStepMm,
      validator: (_, point) => _pointIsUsable(point, projection),
    );
    if (!moved || !session.commit()) session.cancel();
  }

  void _consumeViewportCommand(_SurfaceExtent extent) {
    final revision = controller.viewportCommandRevision;
    if (revision == _lastViewportRevision || _size.isEmpty || _camera == null) {
      return;
    }
    _lastViewportRevision = revision;
    final center = _size.center(Offset.zero);
    switch (controller.viewportCommand) {
      case EditorViewportCommand.zoomIn:
        _camera = _zoomedCamera(center, 1.25, extent);
      case EditorViewportCommand.zoomOut:
        _camera = _zoomedCamera(center, 0.8, extent);
      case EditorViewportCommand.reset:
        _camera = _fittedCamera(extent);
      case null:
        break;
    }
  }

  void _startTouchGesture(ScaleStartDetails details) {
    _touchStartCamera = _camera;
    _touchStartFocal = details.localFocalPoint;
  }

  void _updateTouchGesture(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || _size.isEmpty) return;
    final startCamera = _touchStartCamera;
    final startFocal = _touchStartFocal;
    if (startCamera == null || startFocal == null) return;
    final delta = details.localFocalPoint - startFocal;
    var next = startCamera.panPixels(delta.dx, delta.dy);
    final extent = _SurfaceExtent.fromController(controller);
    final fitScale = _fitScale(extent);
    next = next.zoomAt(
      factor: details.scale,
      viewportWidthPx: _size.width,
      viewportHeightPx: _size.height,
      cursorXpx: details.localFocalPoint.dx,
      cursorYpx: details.localFocalPoint.dy,
      minMmPerPixel: ViewportZoomPolicy.minMmPerPixel(fitScale),
      maxMmPerPixel: ViewportZoomPolicy.maxMmPerPixel(fitScale),
    );
    setState(() => _camera = next);
  }

  void _endTouchGesture(ScaleEndDetails details) {
    _touchStartCamera = null;
    _touchStartFocal = null;
  }

  SurfacePointMm _snapSurfacePoint(
    SurfacePointMm raw,
    _SurfaceProjection projection,
  ) {
    if (!controller.snapEnabled) {
      controller.p2.updateSnap(null);
      return raw;
    }
    final request = SnapRequest(
      rawPoint: MmPoint(raw.xMm, raw.yMm),
      acquisitionRadiusMm: math.max(20.0, projection.camera.mmPerPixel * 14),
      gridStepMm: controller.selectedSpace?.grid.minorStepMm ?? 100,
      segments: _snapSegments(projection),
    );
    final candidate = SnapEngine.resolve(request);
    controller.p2.updateSnap(candidate);
    final point = candidate?.point ?? request.rawPoint;
    return SurfacePointMm(point.x, point.y);
  }

  List<SnapSegment> _snapSegments(_SurfaceProjection projection) {
    final surface = controller.activeSurface!;
    if (surface.type == SurfacePlaneType.wall) {
      final profile = controller.activeWall!.profile;
      return [
        for (var i = 0; i < profile.vertices.length; i++)
          SnapSegment(
            id: 'profile-$i',
            a: MmPoint(profile.vertices[i].xMm, profile.vertices[i].yMm),
            b: MmPoint(
              profile.vertices[(i + 1) % profile.vertices.length].xMm,
              profile.vertices[(i + 1) % profile.vertices.length].yMm,
            ),
          ),
      ];
    }
    final vertices = controller.selectedSpace!.boundary.vertices;
    return [
      for (var i = 0; i < vertices.length; i++)
        SnapSegment(
          id: 'boundary-$i',
          a: MmPoint(
            vertices[i].x - projection.extent.floorLeftMm,
            vertices[i].y - projection.extent.floorBottomMm,
          ),
          b: MmPoint(
            vertices[(i + 1) % vertices.length].x -
                projection.extent.floorLeftMm,
            vertices[(i + 1) % vertices.length].y -
                projection.extent.floorBottomMm,
          ),
        ),
    ];
  }

  bool _pointIsUsable(SurfacePointMm point, _SurfaceProjection projection) {
    final surface = controller.activeSurface!;
    if (surface.type == SurfacePlaneType.wall) {
      return controller.activeWall!.profile.containsPoint(point.xMm, point.yMm);
    }
    final planPoint = MmPoint(
      point.xMm + projection.extent.floorLeftMm,
      point.yMm + projection.extent.floorBottomMm,
    );
    return controller.selectedSpace!.boundary.contains(planPoint);
  }

  ArchitecturalOpening? _openingAt(SurfacePointMm point) {
    for (final opening in controller.activeWallOpenings.reversed) {
      if (point.xMm >= opening.offsetFromStartMm &&
          point.xMm <= opening.endOffsetMm &&
          point.yMm >= opening.sillHeightMm &&
          point.yMm <= opening.topMm) {
        return opening;
      }
    }
    return null;
  }

  void _updateBoundaryHover(
    Offset viewportPoint,
    _SurfaceProjection projection,
  ) {
    final session = controller.boundaryEditing;
    if (!session.active || session.profile != BoundaryEditProfile.openings) {
      session.hoverOpening(null);
      return;
    }
    final point = projection.viewportToSurface(viewportPoint);
    final opening = point == null ? null : _openingAt(point);
    session.hoverOpening(opening?.id);
  }

  ElectricalComponentPlacement? _componentAt(
    SurfacePointMm point,
    _SurfaceProjection projection,
  ) {
    if (!controller.p2.layers.isVisible(EditorLayerId.electrical)) return null;
    final surface = controller.activeSurface;
    if (surface == null) return null;
    final radiusMm = math.max(80.0, projection.camera.mmPerPixel * 18);
    ElectricalComponentPlacement? best;
    var bestDistance = double.infinity;
    for (final component in controller.p2.components.reversed) {
      if (component.surface != surface) continue;
      final dx = (component.position.xMm - point.xMm).toDouble();
      final dy = (component.position.yMm - point.yMm).toDouble();
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance <= radiusMm && distance < bestDistance) {
        best = component;
        bestDistance = distance;
      }
    }
    return best;
  }

  ElectricalComponentPlacement? _componentForHandle(
    SurfacePointMm point,
    _SurfaceProjection projection,
  ) {
    final radiusMm = math.max(80.0, projection.camera.mmPerPixel * 18);
    final handle = DirectManipulationEngine.hitTest(
      handles: controller.p2.handlesForSelection(),
      point: MmPoint(point.xMm, point.yMm),
      radiusMm: radiusMm,
    );
    if (handle == null) return null;
    for (final component in controller.p2.components) {
      if (component.id == handle.ownerId) return component;
    }
    return null;
  }

  List<HostedRoutePath> _allHostedRoutes() {
    final byId = <String, HostedRoutePath>{
      for (final route in controller.hostedRoutes.paths) route.routeId: route,
    };
    for (final route in controller.p2.routes) {
      byId.putIfAbsent(route.id, () => HostedRouteAdapter.fromIndoor(route));
    }
    return List.unmodifiable(byId.values);
  }

  RouteHostTransition? _explicitTransitionAt(
    SurfacePointMm point,
    _SurfaceProjection projection,
  ) {
    final selected = controller.routeSelection.selectedHostedRoute;
    final surface = controller.activeSurface;
    if (selected == null || surface == null) return null;
    final host = RouteHostRef.indoor(surface);
    final radius = math.max(80.0, projection.camera.mmPerPixel * 16);
    RouteHostTransition? best;
    var bestDistance = double.infinity;
    for (final transition in RouteInteractionEngine.transitionsOnHost(
      route: selected,
      host: host,
    )) {
      final anchor = transition.fromHost == host
          ? transition.fromPoint
          : transition.toPoint;
      final dx = point.xMm - anchor.x;
      final dy = point.yMm - anchor.y;
      final distance = math.sqrt((dx * dx + dy * dy).toDouble());
      if (distance <= radius && distance < bestDistance) {
        best = transition;
        bestDistance = distance;
      }
    }
    return best;
  }

  RoomSurfaceRef? _legacyTransitionTargetAt(
    SurfacePointMm point,
    _SurfaceProjection projection,
  ) {
    final selected = controller.routeSelection.selectedRoute;
    final surface = controller.activeSurface;
    if (selected == null || surface == null) return null;
    final radius = math.max(80.0, projection.camera.mmPerPixel * 16);
    for (var i = 0; i < selected.segments.length; i++) {
      final segment = selected.segments[i];
      if (segment.surface != surface || segment.points.isEmpty) continue;
      final first = segment.points.first;
      final last = segment.points.last;
      double distance(SurfacePointMm a, SurfacePointMm b) {
        final dx = a.xMm - b.xMm;
        final dy = a.yMm - b.yMm;
        return math.sqrt((dx * dx + dy * dy).toDouble());
      }

      if (i > 0 && distance(point, first) <= radius) {
        return selected.segments[i - 1].surface;
      }
      if (i + 1 < selected.segments.length && distance(point, last) <= radius) {
        return selected.segments[i + 1].surface;
      }
    }
    return null;
  }

  void _navigateToSurface(RoomSurfaceRef target) {
    if (controller.selectedSpaceId != target.spaceId) {
      controller.selectSpace(target.spaceId);
    }
    switch (target.type) {
      case SurfacePlaneType.wall:
        controller.showWall(target.wallIndex!);
      case SurfacePlaneType.floor:
        controller.showFloor();
      case SurfacePlaneType.ceiling:
        controller.showCeiling();
    }
  }

  void _followTransition(
    RouteHostTransition transition,
    RoomSurfaceRef currentSurface,
  ) {
    final currentHost = RouteHostRef.indoor(currentSurface);
    final target = transition.fromHost == currentHost
        ? transition.toHost
        : transition.fromHost;
    if (target.kind == RouteHostKind.outdoorZone) {
      widget.onOutdoorTransition?.call(transition);
      return;
    }
    final surface = target.surface;
    if (surface != null) _navigateToSurface(surface);
  }

  SelectionMode _selectionModeForKeyboard() {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      return SelectionMode.toggle;
    }
    if (keyboard.isShiftPressed) return SelectionMode.add;
    return SelectionMode.replace;
  }

  EditorInteractionPolicy _policy(PointerDeviceKind kind) =>
      EditorInteractionPolicy.forMode(switch (kind) {
        PointerDeviceKind.touch => EditorInputMode.touch,
        PointerDeviceKind.stylus ||
        PointerDeviceKind.invertedStylus =>
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
      case final CableEndpointHit endpoint:
        ui.focusGeometry(
          routeId: endpoint.route.id,
          segmentIndex: endpoint.segmentIndex,
          pointIndex: endpoint.role == CableEndpointRole.source
              ? 0
              : endpoint.route.segments[endpoint.segmentIndex].points.length -
                  1,
        );
        if (ui.isSegmentLocked(endpoint.route.id, endpoint.segmentIndex)) {
          return false;
        }
        if (!controller.cableEndpointTransform.start(
          route: endpoint.route,
          role: endpoint.role,
          components: controller.p2.components,
          context: _routeContext(projection),
          constraints: controller.p2.routeConstraintsFor(endpoint.route.id),
        )) {
          return false;
        }
      case final CableVertexHit vertex:
        ui.focusGeometry(
          routeId: vertex.route.id,
          segmentIndex: vertex.segmentIndex,
          pointIndex: vertex.pointIndex,
        );
        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(vertex.route.id, vertex.segmentIndex) ||
            ui.isWaypoint(
              vertex.route.id,
              vertex.segmentIndex,
              vertex.pointIndex,
            )) {
          return false;
        }
        if (!controller.cableRouteEdit.start(
          route: vertex.route,
          segmentIndex: vertex.segmentIndex,
          context: _routeContext(projection),
          mode: ui.mode,
          constraints: controller.p2.routeConstraintsFor(vertex.route.id),
        )) {
          return false;
        }
      case final CableSegmentHit segment:
        ui.focusGeometry(
            routeId: segment.route.id, segmentIndex: segment.segmentIndex);
        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(segment.route.id, segment.segmentIndex)) {
          return false;
        }
        if (!controller.cableRouteEdit.start(
          route: segment.route,
          segmentIndex: segment.segmentIndex,
          context: _routeContext(projection),
          mode: ui.mode,
          constraints: controller.p2.routeConstraintsFor(segment.route.id),
        )) {
          return false;
        }
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
        controller.p2
            .updateSnap(controller.cableEndpointTransform.previewState?.snap);
      case final CableVertexHit vertex:
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
      case final CableSegmentHit segment:
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
    if (route == null ||
        s == null ||
        p == null ||
        s >= route.segments.length ||
        p >= route.segments[s].points.length) {
      return;
    }
    ui.toggleWaypoint(point: route.segments[s].points[p]);
  }

  SurfacePointMm _applyDragConstraint(SurfacePointMm point) {
    final start = _dragStartPosition;
    if (start == null || !HardwareKeyboard.instance.isShiftPressed) {
      return point;
    }
    final fixed = MmPoint(start.xMm, start.yMm);
    final moving = MmPoint(point.xMm, point.yMm);
    final dx = (moving.x - fixed.x).abs();
    final dy = (moving.y - fixed.y).abs();
    final result = dx >= dy
        ? ConstraintEngine.horizontal(fixed, moving)
        : ConstraintEngine.vertical(fixed, moving);
    return SurfacePointMm(result.b.x, result.b.y);
  }

  void _handleTap(
    TapUpDetails details,
    _SurfaceProjection projection,
    RoomSurfaceRef surface,
  ) {
    final raw = projection.viewportToSurface(details.localPosition);
    if (raw == null) return;
    final point = _snapSurfacePoint(raw, projection);
    if (!_pointIsUsable(point, projection)) return;

    final boundarySession = controller.boundaryEditing;
    if (boundarySession.active) {
      if (boundarySession.profile == BoundaryEditProfile.openings) {
        final next = _openingAt(point);
        if (boundarySession.draftDirty &&
            next?.id != controller.selectedOpeningId) {
          return;
        }
        controller.selectOpening(next?.id);
        if (next != null) boundarySession.beginOpeningDraft(next);
      } else {
        controller.selectOpening(null);
      }
      return;
    }

    final placementType = controller.p2.placementType;
    if (placementType != null) {
      controller.p2.placeComponent(
        type: placementType,
        surface: surface,
        position: point,
      );
      return;
    }

    if (controller.tool == EditorTool.select) {
      final component = _componentAt(raw, projection);
      if (component != null) {
        controller.routeSelection.clear();
        if (!controller.p2.selection.contains(component.id)) {
          controller.p2.select(component.id);
        }
        return;
      }

      final explicitTransition = _explicitTransitionAt(raw, projection);
      if (explicitTransition != null) {
        _followTransition(explicitTransition, surface);
        return;
      }
      final legacyTarget = _legacyTransitionTargetAt(raw, projection);
      if (legacyTarget != null) {
        _navigateToSurface(legacyTarget);
        return;
      }

      final hit = RouteInteractionEngine.hitTestHosted(
        routes: _allHostedRoutes(),
        host: RouteHostRef.indoor(surface),
        xMm: raw.xMm.toDouble(),
        yMm: raw.yMm.toDouble(),
        radiusMm: math.max(70.0, projection.camera.mmPerPixel * 12),
      );
      if (hit != null) {
        controller.routeSelection.select(hit.routeId);
        return;
      }

      controller.routeSelection.clear();
      if (_marqueeStart == null) controller.p2.clearSelection();
    }

    controller.surfaceTap(point);
  }

  Future<void> _handleDoubleTap(
    TapDownDetails details,
    _SurfaceProjection projection,
    RoomSurfaceRef surface,
    List<MmPoint> roomVertices,
  ) async {
    if (controller.boundaryEditing.active) {
      await requestBoundaryEditorExit(context, controller);
      return;
    }
    if (controller.p2.placementType != null) return;
    if (surface.type == SurfacePlaneType.wall) {
      final hit = projection.wallEdgeHit(
        details.localPosition,
        thresholdPx: 20,
      );
      if (hit != null) {
        controller.navigateWallEdge(hit.edge, hit.point);
      }
      return;
    }
    final hit = projection.horizontalBoundaryHit(
      roomVertices,
      details.localPosition,
      thresholdPx: 20,
    );
    if (hit != null) {
      controller.navigateHorizontalBoundary(hit.edgeIndex, hit.point);
    }
  }

  Rect? get _marqueeRect {
    final start = _marqueeStart;
    final current = _marqueeCurrent;
    if (start == null || current == null) return null;
    return Rect.fromPoints(start, current);
  }

  void _commitMarquee(_SurfaceProjection projection) {
    final rect = _marqueeRect;
    if (rect == null || rect.width < 3 || rect.height < 3) return;
    final a = projection.viewportToSurface(rect.topLeft);
    final b = projection.viewportToSurface(rect.bottomRight);
    if (a == null || b == null) return;
    final box = MmBounds.fromPoints(
      MmPoint(a.xMm, a.yMm),
      MmPoint(b.xMm, b.yMm),
    );
    final surface = controller.activeSurface;
    final objects = <SelectableBounds>[
      for (final component in controller.p2.components)
        if (component.surface == surface)
          SelectableBounds(
            id: component.id,
            kind: SelectionKind.electricalComponent,
            bounds: MmBounds(
              left: component.position.xMm - 1,
              bottom: component.position.yMm - 1,
              right: component.position.xMm + 1,
              top: component.position.yMm + 1,
            ),
          ),
    ];
    final next = SelectionEngine.boxSelect(
      objects: objects,
      box: box,
      current: controller.p2.selection,
      mode: _selectionModeForKeyboard(),
      allowedKinds: const {SelectionKind.electricalComponent},
    );
    controller.p2.clearSelection();
    var first = true;
    for (final id in next.ids) {
      controller.p2.select(
        id,
        mode: first ? SelectionMode.replace : SelectionMode.add,
      );
      first = false;
    }
  }

  void _finishPointer(
    _SurfaceProjection projection, {
    required bool cancelled,
  }) {
    _panAnchor = null;
    if (_marqueeStart != null) {
      if (!cancelled) _commitMarquee(projection);
      setState(() {
        _marqueeStart = null;
        _marqueeCurrent = null;
      });
    }
    final cableHit = _cableDragHit;
    if (cableHit != null) {
      if (cableHit is CableEndpointHit) {
        if (cancelled || !controller.cableEndpointTransform.commit()) {
          controller.cableEndpointTransform.cancel();
        }
      } else {
        if (cancelled || !controller.cableRouteEdit.commit()) {
          controller.cableRouteEdit.cancel();
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
  }

  @override
  Widget build(BuildContext context) {
    final surface = controller.activeSurface;
    final space = controller.selectedSpace;
    if (surface == null || space == null) {
      return const Center(child: Text('Выберите поверхность помещения'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final extent = _SurfaceExtent.fromController(controller);
        _ensureCamera(extent);
        _consumeViewportCommand(extent);
        final camera = _camera!;
        final projection = _SurfaceProjection(
          controller: controller,
          viewportSize: _size,
          camera: camera,
          extent: extent,
        );
        final lod = RenderPolicy.lodForWorldUnitsPerPixel(camera.mmPerPixel);
        final compact = MediaQuery.sizeOf(context).width < 700;
        final scheme = Theme.of(context).colorScheme;
        final bottomEditorVisible = surface.type == SurfacePlaneType.wall &&
            controller.boundaryEditing.active &&
            controller.boundaryEditing.profile != BoundaryEditProfile.wall;

        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SurfacePainter(
                    controller,
                    projection,
                    lod,
                    scheme,
                    flowAnimation: _routeFlow,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerHover: (event) =>
                    _updateBoundaryHover(event.localPosition, projection),
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _zoomAt(
                      event.localPosition,
                      event.scrollDelta.dy < 0 ? 1.18 : 1 / 1.18,
                      extent,
                    );
                  }
                },
                onPointerDown: (event) {
                  _activePointers.add(event.pointer);
                  if (_activePointers.length > 1) {
                    _finishPointer(projection, cancelled: true);
                    return;
                  }
                  if (event.buttons == kMiddleMouseButton) {
                    _panAnchor = event.localPosition;
                    return;
                  }
                  if (event.buttons != kPrimaryMouseButton ||
                      controller.tool != EditorTool.select ||
                      controller.p2.placementType != null ||
                      controller.boundaryEditing.active) {
                    return;
                  }
                  final raw = projection.viewportToSurface(event.localPosition);
                  if (raw == null) return;
                  final cableHit = _cableHitAt(raw, projection, event.kind);
                  if (cableHit != null &&
                      _beginCableDrag(cableHit, projection)) {
                    return;
                  }
                  final handleOwner = _componentForHandle(raw, projection);
                  final component =
                      handleOwner ?? _componentAt(raw, projection);
                  if (component != null) {
                    controller.routeSelection.clear();
                    controller.p2.select(
                      component.id,
                      mode: handleOwner != null
                          ? SelectionMode.replace
                          : _selectionModeForKeyboard(),
                    );
                    if (!controller.p2.selection.contains(component.id)) return;
                    if (!controller.componentTransform.begin()) return;
                    _dragComponentId = component.id;
                    _dragStartPosition = component.position;
                  } else {
                    _marqueeStart = event.localPosition;
                    _marqueeCurrent = event.localPosition;
                  }
                },
                onPointerMove: (event) {
                  if (controller.boundaryEditing.active) {
                    _updateBoundaryHover(event.localPosition, projection);
                  }
                  final anchor = _panAnchor;
                  if (anchor != null) {
                    final delta = event.localPosition - anchor;
                    _panAnchor = event.localPosition;
                    setState(() {
                      _camera = _camera!.panPixels(delta.dx, delta.dy);
                    });
                    return;
                  }
                  if (_marqueeStart != null &&
                      event.buttons == kPrimaryMouseButton) {
                    setState(() => _marqueeCurrent = event.localPosition);
                    return;
                  }
                  final previewPosition = event.kind == PointerDeviceKind.touch
                      ? event.localPosition -
                          Offset(0, _policy(event.kind).pointerPreviewOffsetPx)
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
                },
                onPointerUp: (event) {
                  _activePointers.remove(event.pointer);
                  _finishPointer(projection, cancelled: false);
                },
                onPointerCancel: (event) {
                  _activePointers.remove(event.pointer);
                  _finishPointer(projection, cancelled: true);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) =>
                      _handleTap(details, projection, surface),
                  onDoubleTapDown: (details) => _handleDoubleTap(
                    details,
                    projection,
                    surface,
                    space.boundary.vertices,
                  ),
                  onScaleStart: _startTouchGesture,
                  onScaleUpdate: _updateTouchGesture,
                  onScaleEnd: _endTouchGesture,
                ),
              ),
            ),
            if (_marqueeRect case final rect?)
              Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CadVisualTokens.selectedFill(scheme),
                      border: Border.all(
                        color: CadVisualTokens.selectedGeometry(scheme),
                      ),
                    ),
                  ),
                ),
              ),
            if (surface.type == SurfacePlaneType.wall)
              Positioned(
                left: compact ? 8 : 12,
                top: compact ? 8 : 12,
                child: BoundaryEditPanel(
                  controller: controller,
                  compact: compact,
                ),
              ),
            Positioned(
              right: compact ? 8 : 12,
              top: compact ? 8 : 12,
              child: _ViewportBadge(lod: lod, mmPerPixel: camera.mmPerPixel),
            ),
            Positioned(
              right: compact ? 8 : 12,
              top: compact ? 48 : 52,
              child: CanvasViewportNavigator(
                onPan: _panViewport,
                onZoomIn: () =>
                    _zoomAt(_size.center(Offset.zero), 1.25, extent),
                onZoomOut: () =>
                    _zoomAt(_size.center(Offset.zero), 0.8, extent),
                onFit: () => setState(() => _camera = _fittedCamera(extent)),
              ),
            ),
            Positioned(
              right: compact ? 8 : 12,
              bottom: bottomEditorVisible ? 148 : (compact ? 8 : 12),
              child: _EdgeNavigationHint(surface: surface),
            ),
            if (controller.p2.selectedComponent case final component?)
              Positioned(
                left: compact ? 8 : 12,
                bottom: bottomEditorVisible ? 148 : (compact ? 8 : 12),
                child: CanvasComponentControls(
                  label: component.label,
                  stepMm: _componentNudgeStepMm,
                  onStepChanged: (value) =>
                      setState(() => _componentNudgeStepMm = value),
                  onMove: (dx, dy) =>
                      _nudgeSelectedComponent(dx, dy, projection),
                  onDelete: controller.p2.deleteSelection,
                ),
              ),
            if (controller.p2.placementType case final type?)
              Positioned(
                left: 12,
                bottom: bottomEditorVisible ? 148 : 12,
                child: Chip(
                  avatar: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: Text(
                    'Размещение: ${ElectricalComponentDefaults.defaultLabel(type)}',
                  ),
                ),
              ),
            if (controller.routeSelection.selectedRouteId case final routeId?)
              Positioned(
                left: 12,
                bottom: bottomEditorVisible ? 188 : 52,
                child: Chip(
                  avatar: const Icon(Icons.alt_route, size: 18),
                  label: Text('Трасса: $routeId · переходы активны'),
                ),
              ),
            if (controller.routeSelection.selectedRouteId != null)
              Positioned(
                left: compact ? 8 : 12,
                top: compact ? 56 : 60,
                child: CableRouteControls(
                  mode: controller.cableUi.mode,
                  onModeChanged: controller.cableUi.setMode,
                  segmentFocused: controller.cableUi.activeSegmentIndex != null,
                  segmentLocked: controller.cableUi.activeSegmentLocked,
                  onToggleSegmentLock:
                      controller.cableUi.toggleActiveSegmentLock,
                  pointFocused: controller.cableUi.activePointIndex != null,
                  pointIsWaypoint: controller.cableUi.activePointIsWaypoint,
                  onToggleWaypoint: _toggleActiveWaypoint,
                  validation: controller
                          .cableEndpointTransform.previewState?.validation ??
                      controller.cableRouteEdit.previewState?.validation,
                  previewInvalid: controller.cableEndpointTransform.active &&
                      controller.cableEndpointTransform.previewState == null,
                ),
              ),
            if (surface.type == SurfacePlaneType.wall)
              Positioned(
                left: compact ? 8 : 12,
                right: compact ? 8 : 12,
                bottom: 0,
                child: BoundaryBottomEditor(
                  controller: controller,
                  compact: compact,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ViewportBadge extends StatelessWidget {
  const _ViewportBadge({required this.lod, required this.mmPerPixel});

  final RenderLod lod;
  final double mmPerPixel;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(7),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Text(
            '${lod.name} · ${mmPerPixel.toStringAsFixed(1)} mm/px',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      );
}

class _EdgeNavigationHint extends StatelessWidget {
  const _EdgeNavigationHint({required this.surface});

  final RoomSurfaceRef surface;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHigh
              .withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(7),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app_outlined, size: 14),
              const SizedBox(width: 4),
              Text(
                surface.type == SurfacePlaneType.wall
                    ? 'Double-click кромки → соседняя плоскость'
                    : 'Double-click границы → стена',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      );
}

final class _SurfaceExtent {
  const _SurfaceExtent({
    required this.widthMm,
    required this.heightMm,
    required this.floorLeftMm,
    required this.floorBottomMm,
  });

  factory _SurfaceExtent.fromController(EditorController controller) {
    final surface = controller.activeSurface!;
    final space = controller.selectedSpace!;
    if (surface.type == SurfacePlaneType.wall) {
      final wall = controller.activeWall!;
      return _SurfaceExtent(
        widthMm: wall.lengthMm.round(),
        heightMm: wall.heightMm,
        floorLeftMm: 0,
        floorBottomMm: 0,
      );
    }
    final bounds = space.boundary.bounds;
    return _SurfaceExtent(
      widthMm: bounds.width,
      heightMm: bounds.height,
      floorLeftMm: bounds.left,
      floorBottomMm: bounds.bottom,
    );
  }

  final int widthMm;
  final int heightMm;
  final int floorLeftMm;
  final int floorBottomMm;
}

final class _WallEdgeHit {
  const _WallEdgeHit(this.edge, this.point);
  final WallNavigationEdge edge;
  final SurfacePointMm point;
}

final class _HorizontalBoundaryHit {
  const _HorizontalBoundaryHit(this.edgeIndex, this.point);
  final int edgeIndex;
  final SurfacePointMm point;
}

final class _SurfaceProjection {
  const _SurfaceProjection({
    required this.controller,
    required this.viewportSize,
    required this.camera,
    required this.extent,
  });

  final EditorController controller;
  final Size viewportSize;
  final WorldCamera camera;
  final _SurfaceExtent extent;

  double get widthMm => extent.widthMm.toDouble();
  double get heightMm => extent.heightMm.toDouble();

  Offset surfaceToViewport(SurfacePointMm point) {
    final screen = camera.worldToScreen(
      viewportWidthPx: viewportSize.width,
      viewportHeightPx: viewportSize.height,
      point: MmPoint(point.xMm, point.yMm),
    );
    return Offset(screen.x, screen.y);
  }

  SurfacePointMm? viewportToSurface(Offset point) {
    final world = camera.screenToWorld(
      viewportWidthPx: viewportSize.width,
      viewportHeightPx: viewportSize.height,
      xPx: point.dx,
      yPx: point.dy,
    );
    if (world.x < 0 ||
        world.y < 0 ||
        world.x > extent.widthMm ||
        world.y > extent.heightMm) {
      return null;
    }
    return SurfacePointMm(world.x, world.y);
  }

  Rect get surfaceRect => Rect.fromPoints(
        surfaceToViewport(SurfacePointMm(0, extent.heightMm)),
        surfaceToViewport(SurfacePointMm(extent.widthMm, 0)),
      );

  _WallEdgeHit? wallEdgeHit(
    Offset viewportPoint, {
    required double thresholdPx,
  }) {
    final local = viewportToSurface(viewportPoint);
    if (local == null) return null;
    final thresholdMm = thresholdPx * camera.mmPerPixel;
    final distances = <WallNavigationEdge, double>{
      WallNavigationEdge.start: local.xMm.toDouble(),
      WallNavigationEdge.end: widthMm - local.xMm,
      WallNavigationEdge.floor: local.yMm.toDouble(),
      WallNavigationEdge.ceiling: heightMm - local.yMm,
    };
    final entry = distances.entries.reduce(
      (a, b) => a.value <= b.value ? a : b,
    );
    if (entry.value > thresholdMm) return null;
    final point = switch (entry.key) {
      WallNavigationEdge.start => SurfacePointMm(0, local.yMm),
      WallNavigationEdge.end => SurfacePointMm(extent.widthMm, local.yMm),
      WallNavigationEdge.floor => SurfacePointMm(local.xMm, 0),
      WallNavigationEdge.ceiling => SurfacePointMm(local.xMm, extent.heightMm),
    };
    return _WallEdgeHit(entry.key, point);
  }

  _HorizontalBoundaryHit? horizontalBoundaryHit(
    List<MmPoint> vertices,
    Offset viewportPoint, {
    required double thresholdPx,
  }) {
    var nearestDistance = double.infinity;
    int? nearestIndex;
    Offset? nearestPoint;
    for (var i = 0; i < vertices.length; i++) {
      final a = floorPointToViewport(vertices[i]);
      final b = floorPointToViewport(vertices[(i + 1) % vertices.length]);
      final candidate = _closestPointOnSegment(viewportPoint, a, b);
      final distance = (viewportPoint - candidate).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
        nearestPoint = candidate;
      }
    }
    if (nearestIndex == null ||
        nearestPoint == null ||
        nearestDistance > thresholdPx) {
      return null;
    }
    final local = viewportToSurface(nearestPoint);
    return local == null ? null : _HorizontalBoundaryHit(nearestIndex, local);
  }

  Offset floorPointToViewport(MmPoint point) => surfaceToViewport(
        SurfacePointMm(
          point.x - extent.floorLeftMm,
          point.y - extent.floorBottomMm,
        ),
      );

  Offset _closestPointOnSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return a;
    final ap = point - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return a + ab * t;
  }
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter(
    this.controller,
    this.projection,
    this.lod,
    this.scheme, {
    required Animation<double> flowAnimation,
  })  : flowAnimation = flowAnimation,
        activeSurfaceId = controller.activeSurface?.id,
        selectedSpaceId = controller.selectedSpaceId,
        dimensionsVisible = controller.dimensionsVisible &&
            controller.p2.layers.isVisible(EditorLayerId.dimensions),
        openingsVisible =
            controller.p2.layers.isVisible(EditorLayerId.openings),
        electricalVisible = controller.p2.layers.isVisible(
          EditorLayerId.electrical,
        ),
        cableRoutesVisible = controller.p2.layers.isVisible(
          EditorLayerId.cableRoutes,
        ),
        boundaryProfile = controller.boundaryEditing.profile,
        hoveredOpeningId = controller.boundaryEditing.hoveredOpeningId,
        selectedOpeningId = controller.selectedOpeningId,
        selectedRouteId = controller.routeSelection.selectedRouteId,
        draftFingerprint = Object.hash(
          controller.boundaryEditing.openingDraft?.openingId,
          controller.boundaryEditing.openingDraft?.type,
          controller.boundaryEditing.openingDraft?.offsetFromStartMm,
          controller.boundaryEditing.openingDraft?.widthMm,
          controller.boundaryEditing.openingDraft?.heightMm,
          controller.boundaryEditing.openingDraft?.sillHeightMm,
          controller.boundaryEditing.beamDraft?.startMm,
          controller.boundaryEditing.beamDraft?.widthMm,
          controller.boundaryEditing.beamDraft?.depthMm,
        ),
        openingsFingerprint = Object.hashAll(
          controller.activeWallOpenings.map(
            (opening) => Object.hash(
              opening.id,
              opening.type,
              opening.offsetFromStartMm,
              opening.widthMm,
              opening.heightMm,
              opening.sillHeightMm,
            ),
          ),
        ),
        routeFingerprint = Object.hashAll([
          ...controller.routeSegments.expand(
            (segment) => <Object?>[
              segment.surface.id,
              ...segment.points.expand(
                (point) => <Object?>[point.xMm, point.yMm],
              ),
            ],
          ),
          ...controller.p2.routes.expand(
            (route) => <Object?>[
              route.id,
              route.medium.id,
              ...route.segments.expand(
                (segment) => <Object?>[
                  segment.surface.id,
                  ...segment.points.expand(
                    (point) => <Object?>[point.xMm, point.yMm],
                  ),
                ],
              ),
            ],
          ),
          ...controller.hostedRoutes.paths.expand(
            (route) => <Object?>[
              route.routeId,
              ...route.segments.expand(
                (segment) => <Object?>[
                  segment.host.id,
                  ...segment.points.expand(
                    (point) => <Object?>[point.x, point.y],
                  ),
                ],
              ),
              ...route.transitions.expand(
                (transition) => <Object?>[
                  transition.id,
                  transition.fromHost.id,
                  transition.toHost.id,
                ],
              ),
            ],
          ),
        ]),
        componentsFingerprint = Object.hashAll(
          controller.p2.components.expand(
            (component) => <Object?>[
              component.id,
              component.type,
              component.surface.id,
              component.position.xMm,
              component.position.yMm,
              component.rotationDegrees,
            ],
          ),
        ),
        selectionFingerprint = Object.hashAll(controller.p2.selection.ids),
        snapFingerprint = controller.p2.activeSnap == null
            ? 0
            : Object.hash(
                controller.p2.activeSnap!.kind,
                controller.p2.activeSnap!.point.x,
                controller.p2.activeSnap!.point.y,
              ),
        profileFingerprint = Object.hashAll(
          controller.selectedSpace?.wallProfiles.entries.expand(
                (entry) => <Object?>[
                  entry.key,
                  ...entry.value.vertices.expand(
                    (point) => <Object?>[point.xMm, point.yMm],
                  ),
                ],
              ) ??
              const <Object?>[],
        ),
        super(repaint: flowAnimation);

  final EditorController controller;
  final _SurfaceProjection projection;
  final RenderLod lod;
  final ColorScheme scheme;
  final Animation<double> flowAnimation;
  final String? activeSurfaceId;
  final String? selectedSpaceId;
  final bool dimensionsVisible;
  final bool openingsVisible;
  final bool electricalVisible;
  final bool cableRoutesVisible;
  final BoundaryEditProfile? boundaryProfile;
  final String? hoveredOpeningId;
  final String? selectedOpeningId;
  final String? selectedRouteId;
  final int draftFingerprint;
  final int openingsFingerprint;
  final int routeFingerprint;
  final int componentsFingerprint;
  final int selectionFingerprint;
  final int snapFingerprint;
  final int profileFingerprint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);
    final surface = controller.activeSurface!;
    if (surface.type == SurfacePlaneType.wall) {
      _drawWall(canvas);
    } else {
      _drawHorizontalSurface(canvas, surface.type);
    }
  }

  Path _wallPath() {
    final wall = controller.activeWall!;
    final wallIndex = wall.ref.wallIndex ?? 0;
    final profile = controller.selectedSpace!.wallProfiles[wallIndex];
    if (profile == null) return Path()..addRect(projection.surfaceRect);
    final path = Path();
    final first = profile.vertices.first;
    final firstPoint = projection.surfaceToViewport(
      SurfacePointMm(first.xMm, first.yMm),
    );
    path.moveTo(firstPoint.dx, firstPoint.dy);
    for (final vertex in profile.vertices.skip(1)) {
      final point = projection.surfaceToViewport(
        SurfacePointMm(vertex.xMm, vertex.yMm),
      );
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  void _drawWall(Canvas canvas) {
    final wall = controller.activeWall!;
    final rect = projection.surfaceRect;
    final wallPath = _wallPath();
    final customProfile = controller.selectedSpace!.wallProfiles.containsKey(
      wall.ref.wallIndex ?? 0,
    );
    canvas.drawPath(wallPath, Paint()..color = scheme.surfaceContainerLowest);
    canvas.save();
    canvas.clipPath(wallPath);
    _drawAdaptiveGrid(canvas, rect);
    if (openingsVisible && RenderPolicy.showOpenings(lod)) {
      for (final opening in controller.activeWallOpenings) {
        _drawOpening(canvas, opening);
      }
    }
    _drawRoutes(canvas);
    _drawElectricalComponents(canvas);
    canvas.restore();
    canvas.drawPath(
      wallPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = boundaryProfile == BoundaryEditProfile.wall
            ? 4.0
            : customProfile
                ? CadVisualTokens.profileStroke
                : CadVisualTokens.geometryStroke
        ..strokeJoin = StrokeJoin.miter
        ..color = boundaryProfile == BoundaryEditProfile.wall
            ? CadVisualTokens.selectedGeometry(scheme)
            : customProfile
                ? CadVisualTokens.profile(scheme)
                : CadVisualTokens.geometry(scheme),
    );
    if (boundaryProfile == BoundaryEditProfile.structuralProfile) {
      _drawStructuralProfile(canvas, wall);
      _drawBeamPreviewAndMeasurements(canvas, wall);
    }
    if (boundaryProfile == BoundaryEditProfile.openings) {
      _drawOpeningPreviewAndMeasurements(canvas, wall);
    }
    _drawNavigationEdges(canvas, rect);
    if (dimensionsVisible && RenderPolicy.showFineDimensions(lod)) {
      _horizontalDimension(
        canvas,
        rect.left,
        rect.right,
        rect.bottom + 30,
        '${wall.lengthMm.round()} mm',
      );
      _verticalDimension(
        canvas,
        rect.right + 34,
        rect.top,
        rect.bottom,
        '${wall.heightMm} mm',
      );
    }
    _label(
      canvas,
      'Стена ${(wall.ref.wallIndex ?? 0) + 1} · '
      '${wall.lengthMm.round()} × ${wall.heightMm} mm',
      Offset(rect.center.dx, rect.top - 34),
      centered: true,
      bold: true,
    );
  }

  void _drawStructuralProfile(Canvas canvas, RoomWallSurface wall) {
    final segments = BoundaryEditingResolver.structuralSegments(
      profile: wall.profile,
      wallHeightMm: wall.heightMm,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = CadVisualTokens.selectedGeometry(scheme);
    for (final segment in segments) {
      final a = projection.surfaceToViewport(
        SurfacePointMm(segment.a.xMm, segment.a.yMm),
      );
      final b = projection.surfaceToViewport(
        SurfacePointMm(segment.b.xMm, segment.b.yMm),
      );
      canvas.drawLine(a, b, paint);
      canvas.drawCircle(a, 4, Paint()..color = paint.color);
      canvas.drawCircle(b, 4, Paint()..color = paint.color);
    }
  }

  void _drawOpeningPreviewAndMeasurements(Canvas canvas, RoomWallSurface wall) {
    final selected = controller.selectedOpening;
    if (selected == null) return;
    final draft = controller.boundaryEditing.openingDraft;
    ArchitecturalOpening candidate = selected;
    var valid = true;
    if (draft != null && draft.openingId == selected.id) {
      try {
        candidate = draft.toOpening(selected);
        valid = RoomSurfaceResolver.openingFitsWall(
          opening: candidate,
          wall: wall,
        );
      } on ArgumentError {
        valid = false;
      }
    }

    final active = draft != null && draft.openingId == selected.id;
    if (active &&
        draft.widthMm > 0 &&
        draft.heightMm > 0 &&
        draft.offsetFromStartMm >= 0 &&
        draft.sillHeightMm >= 0) {
      final top = draft.sillHeightMm + draft.heightMm;
      final end = draft.offsetFromStartMm + draft.widthMm;
      final a = projection.surfaceToViewport(
        SurfacePointMm(draft.offsetFromStartMm, top),
      );
      final b = projection.surfaceToViewport(
        SurfacePointMm(end, draft.sillHeightMm),
      );
      final rect = Rect.fromPoints(a, b);
      final color =
          valid ? CadVisualTokens.selectedGeometry(scheme) : scheme.error;
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.10));
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color,
      );
    }

    if (valid) {
      _drawMeasurementSet(
        canvas,
        WallMeasurementResolver.forOpening(opening: candidate, wall: wall),
      );
    }
  }

  void _drawBeamPreviewAndMeasurements(Canvas canvas, RoomWallSurface wall) {
    final draft = controller.boundaryEditing.beamDraft;
    if (draft == null) return;
    final end = draft.startMm + draft.widthMm;
    final bottom = wall.heightMm - draft.depthMm;
    var valid = draft.startMm >= 0 &&
        draft.widthMm > 0 &&
        draft.depthMm > 0 &&
        end <= wall.lengthMm.round() &&
        draft.depthMm < wall.heightMm;
    if (valid) {
      for (final opening in controller.activeWallOpenings) {
        final overlapsX = opening.offsetFromStartMm < end &&
            opening.endOffsetMm > draft.startMm;
        if (overlapsX && opening.topMm > bottom) {
          valid = false;
          break;
        }
      }
    }

    final color =
        valid ? CadVisualTokens.selectedGeometry(scheme) : scheme.error;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final topLeft = projection.surfaceToViewport(
      SurfacePointMm(draft.startMm, wall.heightMm),
    );
    final bottomLeft = projection.surfaceToViewport(
      SurfacePointMm(draft.startMm, bottom),
    );
    final bottomRight = projection.surfaceToViewport(
      SurfacePointMm(end, bottom),
    );
    final topRight = projection.surfaceToViewport(
      SurfacePointMm(end, wall.heightMm),
    );
    canvas.drawLine(topLeft, bottomLeft, paint);
    canvas.drawLine(bottomLeft, bottomRight, paint);
    canvas.drawLine(bottomRight, topRight, paint);
    canvas.drawPath(
      Path()
        ..moveTo(topLeft.dx, topLeft.dy)
        ..lineTo(bottomLeft.dx, bottomLeft.dy)
        ..lineTo(bottomRight.dx, bottomRight.dy)
        ..lineTo(topRight.dx, topRight.dy),
      paint,
    );

    if (valid) {
      _drawMeasurementSet(
        canvas,
        WallMeasurementResolver.forTopNotch(
          startMm: draft.startMm,
          widthMm: draft.widthMm,
          depthMm: draft.depthMm,
          wall: wall,
        ),
      );
    }
  }

  void _drawMeasurementSet(Canvas canvas, WallMeasurementSet set) {
    for (final span in set.spans) {
      final start = projection.surfaceToViewport(span.start);
      final end = projection.surfaceToViewport(span.end);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color =
            CadVisualTokens.selectedGeometry(scheme).withValues(alpha: 0.82);
      canvas.drawLine(start, end, paint);
      if (span.axis == MeasurementAxis.horizontal) {
        canvas.drawLine(
          start + const Offset(0, -4),
          start + const Offset(0, 4),
          paint,
        );
        canvas.drawLine(
          end + const Offset(0, -4),
          end + const Offset(0, 4),
          paint,
        );
      } else {
        canvas.drawLine(
          start + const Offset(-4, 0),
          start + const Offset(4, 0),
          paint,
        );
        canvas.drawLine(
          end + const Offset(-4, 0),
          end + const Offset(4, 0),
          paint,
        );
      }
      final midpoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      _dimensionLabel(canvas, '${span.valueMm} mm', midpoint);
    }
  }

  void _dimensionLabel(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: painter.width + 8,
      height: painter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = scheme.surface.withValues(alpha: 0.92),
    );
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _drawHorizontalSurface(Canvas canvas, SurfacePlaneType type) {
    final space = controller.selectedSpace!;
    final path = Path();
    final first = projection.floorPointToViewport(
      space.boundary.vertices.first,
    );
    path.moveTo(first.dx, first.dy);
    for (final vertex in space.boundary.vertices.skip(1)) {
      final point = projection.floorPointToViewport(vertex);
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = scheme.surfaceContainerLowest);
    canvas.save();
    canvas.clipPath(path);
    _drawAdaptiveGrid(canvas, projection.surfaceRect);
    _drawRoutes(canvas);
    _drawElectricalComponents(canvas);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = CadVisualTokens.geometryStroke
        ..color = CadVisualTokens.geometry(scheme),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = scheme.primary.withValues(alpha: 0.12),
    );
    _label(
      canvas,
      type == SurfacePlaneType.floor
          ? 'ПОЛ · ${space.name}'
          : 'ПОТОЛОК · ${space.name}',
      Offset(projection.surfaceRect.center.dx, projection.surfaceRect.top - 34),
      centered: true,
      bold: true,
    );
  }

  void _drawAdaptiveGrid(Canvas canvas, Rect rect) {
    final spec = AdaptiveGridPolicy.forScale(projection.camera.mmPerPixel);
    final minor = Paint()
      ..color = CadVisualTokens.gridMinor(scheme)
      ..strokeWidth = 0.7;
    final major = Paint()
      ..color = CadVisualTokens.gridMajor(scheme)
      ..strokeWidth = 1.0;
    for (var x = 0; x <= projection.extent.widthMm; x += spec.minorStepMm) {
      final isMajor = x % spec.majorStepMm == 0;
      if (!isMajor && (!spec.showMinor || lod.index < RenderLod.room.index)) {
        continue;
      }
      final point = projection.surfaceToViewport(SurfacePointMm(x, 0));
      canvas.drawLine(
        Offset(point.dx, rect.top),
        Offset(point.dx, rect.bottom),
        isMajor ? major : minor,
      );
    }
    for (var y = 0; y <= projection.extent.heightMm; y += spec.minorStepMm) {
      final isMajor = y % spec.majorStepMm == 0;
      if (!isMajor && (!spec.showMinor || lod.index < RenderLod.room.index)) {
        continue;
      }
      final point = projection.surfaceToViewport(SurfacePointMm(0, y));
      canvas.drawLine(
        Offset(rect.left, point.dy),
        Offset(rect.right, point.dy),
        isMajor ? major : minor,
      );
    }
  }

  void _drawOpening(Canvas canvas, ArchitecturalOpening opening) {
    final a = projection.surfaceToViewport(
      SurfacePointMm(opening.offsetFromStartMm, opening.topMm),
    );
    final b = projection.surfaceToViewport(
      SurfacePointMm(
        opening.offsetFromStartMm + opening.widthMm,
        opening.sillHeightMm,
      ),
    );
    final rect = Rect.fromPoints(a, b);
    final selected = selectedOpeningId == opening.id;
    final hovered = hoveredOpeningId == opening.id &&
        boundaryProfile == BoundaryEditProfile.openings;
    final fill = selected || hovered
        ? CadVisualTokens.selectedFill(scheme)
        : opening.type == ArchitecturalOpeningType.door
            ? scheme.tertiaryContainer.withValues(alpha: 0.42)
            : scheme.secondaryContainer.withValues(alpha: 0.42);
    canvas.drawRect(rect, Paint()..color = fill);
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected
            ? 4
            : hovered
                ? 3
                : CadVisualTokens.openingStroke
        ..color = selected || hovered
            ? CadVisualTokens.selectedGeometry(scheme)
            : CadVisualTokens.opening(scheme),
    );
  }

  List<HostedRoutePath> _allHostedRoutes() {
    final byId = <String, HostedRoutePath>{
      for (final route in controller.hostedRoutes.paths) route.routeId: route,
    };
    for (final route in controller.p2.routes) {
      byId.putIfAbsent(route.id, () => HostedRouteAdapter.fromIndoor(route));
    }
    return List.unmodifiable(byId.values);
  }

  void _drawRoutes(Canvas canvas) {
    if (!cableRoutesVisible) return;
    final baseDraft = Paint()
      ..color = CadVisualTokens.route(scheme)
      ..strokeWidth = CadVisualTokens.routeStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final draft = controller.activeRouteSegment;
    if (draft != null) _drawRoutePoints(canvas, draft.points, baseDraft);

    final activeSurface = controller.activeSurface;
    if (activeSurface == null) return;
    final activeHost = RouteHostRef.indoor(activeSurface);
    for (final route in _allHostedRoutes()) {
      final selected = route.routeId == selectedRouteId;
      final medium = route.medium;
      final frame = RouteFlowVisualizationPolicy.frame(
        medium: medium,
        phase: flowAnimation.value,
      );
      if (selected) {
        final halo = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = scheme.primary.withValues(alpha: 0.12 + frame.glow * 0.18);
        _drawHostedSegmentsOnHost(canvas, route, activeHost, halo);
      }
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3.2 : CadVisualTokens.routeStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = selected ? scheme.primary : CadVisualTokens.route(scheme);
      _drawHostedSegmentsOnHost(canvas, route, activeHost, line);
      if (selected) {
        _drawFlow(canvas, route, activeHost, medium);
        _drawTransitionMarkers(canvas, route, activeHost);
        _drawLegacyTransitionMarkers(canvas, route.routeId, activeSurface);
      }
    }
    _drawCableEditOverlay(canvas, activeSurface);
  }

  void _drawCableEditOverlay(Canvas canvas, RoomSurfaceRef activeSurface) {
    final selected = controller.routeSelection.selectedRoute;
    if (selected == null) return;
    final endpointPreview = controller.cableEndpointTransform.previewState;
    final routePreview = controller.cableRouteEdit.previewState;
    final preview = endpointPreview?.route ?? routePreview?.route;
    final validation = endpointPreview?.validation ?? routePreview?.validation;
    if (preview != null) {
      final color = validation == null || !validation.isValid
          ? scheme.error
          : validation.hasWarnings
              ? Colors.amber.shade700
              : Colors.green.shade600;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;
      for (final segment in preview.segments) {
        if (segment.surface == activeSurface) {
          _drawRoutePoints(canvas, segment.points, paint);
        }
      }
    }

    for (var s = 0; s < selected.segments.length; s++) {
      final segment = selected.segments[s];
      if (segment.surface != activeSurface || segment.points.length < 2) {
        continue;
      }
      for (var p = 0; p < segment.points.length; p++) {
        final isEndpoint = (s == 0 && p == 0) ||
            (s == selected.segments.length - 1 &&
                p == segment.points.length - 1);
        final isWaypoint = controller.cableUi.isWaypoint(selected.id, s, p);
        final center = projection.surfaceToViewport(segment.points[p]);
        canvas.drawCircle(
          center,
          isEndpoint ? 7 : 5,
          Paint()
            ..style = PaintingStyle.fill
            ..color = isWaypoint ? scheme.tertiary : scheme.surface,
        );
        canvas.drawCircle(
          center,
          isEndpoint ? 7 : 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = controller.cableUi.isSegmentLocked(selected.id, s)
                ? scheme.outline
                : scheme.primary,
        );
      }
      for (var edge = 0; edge < segment.points.length - 1; edge++) {
        final a = projection.surfaceToViewport(segment.points[edge]);
        final b = projection.surfaceToViewport(segment.points[edge + 1]);
        final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        canvas.drawRect(
          Rect.fromCenter(center: midpoint, width: 9, height: 9),
          Paint()
            ..style = PaintingStyle.fill
            ..color = controller.cableUi.isSegmentLocked(selected.id, s)
                ? scheme.outline
                : scheme.tertiary,
        );
      }
    }
  }

  void _drawHostedSegmentsOnHost(
    Canvas canvas,
    HostedRoutePath route,
    RouteHostRef host,
    Paint paint,
  ) {
    for (final segment in route.segments) {
      if (segment.host != host || segment.points.length < 2) continue;
      Offset? previous;
      for (final point in segment.points) {
        final current = projection.surfaceToViewport(
          SurfacePointMm(point.x, point.y),
        );
        if (previous != null) canvas.drawLine(previous, current, paint);
        previous = current;
      }
    }
  }

  void _drawFlow(
    Canvas canvas,
    HostedRoutePath route,
    RouteHostRef host,
    RouteMediumProfile medium,
  ) {
    final samples = RouteInteractionEngine.flowSamples(
      route: route,
      medium: medium,
      phase: flowAnimation.value,
    );
    for (final sample in samples) {
      if (sample.hostId != host.id) continue;
      final center = projection.surfaceToViewport(
        SurfacePointMm(sample.xMm.round(), sample.yMm.round()),
      );
      canvas.drawCircle(
        center,
        sample.reverse ? 3.2 : 4.2,
        Paint()..color = scheme.primary,
      );
      if (sample.reverse) {
        canvas.drawCircle(
          center,
          6.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = scheme.primary.withValues(alpha: 0.5),
        );
      }
    }
  }

  void _drawTransitionMarkers(
    Canvas canvas,
    HostedRoutePath route,
    RouteHostRef host,
  ) {
    for (final transition in RouteInteractionEngine.transitionsOnHost(
      route: route,
      host: host,
    )) {
      final point = transition.fromHost == host
          ? transition.fromPoint
          : transition.toPoint;
      _drawTransitionMarker(
        canvas,
        SurfacePointMm(point.x, point.y),
        outdoor: transition.fromHost.kind != transition.toHost.kind,
      );
    }
  }

  void _drawLegacyTransitionMarkers(
    Canvas canvas,
    String routeId,
    RoomSurfaceRef activeSurface,
  ) {
    final selected = controller.routeSelection.selectedRoute;
    if (selected == null || selected.id != routeId) return;
    for (var i = 0; i < selected.segments.length; i++) {
      final segment = selected.segments[i];
      if (segment.surface != activeSurface || segment.points.isEmpty) continue;
      if (i > 0 && selected.segments[i - 1].surface != activeSurface) {
        _drawTransitionMarker(canvas, segment.points.first);
      }
      if (i + 1 < selected.segments.length &&
          selected.segments[i + 1].surface != activeSurface) {
        _drawTransitionMarker(canvas, segment.points.last);
      }
    }
  }

  void _drawTransitionMarker(
    Canvas canvas,
    SurfacePointMm point, {
    bool outdoor = false,
  }) {
    final center = projection.surfaceToViewport(point);
    final color = outdoor ? scheme.secondary : scheme.tertiary;
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.20),
    );
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    canvas.drawCircle(center, 2.5, Paint()..color = color);
  }

  void _drawRoutePoints(
    Canvas canvas,
    List<SurfacePointMm> points,
    Paint paint,
  ) {
    Offset? previous;
    for (final point in points) {
      final current = projection.surfaceToViewport(point);
      if (previous != null) canvas.drawLine(previous, current, paint);
      canvas.drawCircle(current, CadVisualTokens.transitionNodeRadius, paint);
      previous = current;
    }
  }

  void _drawElectricalComponents(Canvas canvas) {
    if (!electricalVisible) return;
    final surface = controller.activeSurface;
    for (final component in controller.p2.components) {
      if (component.surface != surface) continue;
      final center = projection.surfaceToViewport(component.position);
      final selected = controller.p2.selection.contains(component.id);
      _drawComponentSymbol(canvas, component.type, center, selected);
    }
    final snap = controller.p2.activeSnap;
    if (snap != null) {
      final center = projection.surfaceToViewport(
        SurfacePointMm(snap.point.x, snap.point.y),
      );
      canvas.drawCircle(
        center,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = CadVisualTokens.selectedGeometry(scheme),
      );
      _label(
        canvas,
        snap.kind.name.toUpperCase(),
        center + const Offset(9, -16),
        small: true,
      );
    }
  }

  void _drawComponentSymbol(
    Canvas canvas,
    ElectricalComponentType type,
    Offset center,
    bool selected,
  ) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.6 : 1.8
      ..color = selected
          ? CadVisualTokens.selectedGeometry(scheme)
          : scheme.onSurface;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = selected
          ? CadVisualTokens.selectedFill(scheme)
          : scheme.surfaceContainerLowest;
    canvas.drawCircle(center, selected ? 11 : 9, fill);
    switch (type) {
      case ElectricalComponentType.socketOutlet:
        canvas.drawCircle(center, 8, stroke);
        canvas.drawLine(
          center + const Offset(-4, 0),
          center + const Offset(4, 0),
          stroke,
        );
        canvas.drawLine(
          center + const Offset(-2, -3),
          center + const Offset(-2, 3),
          stroke,
        );
        canvas.drawLine(
          center + const Offset(2, -3),
          center + const Offset(2, 3),
          stroke,
        );
      case ElectricalComponentType.switchControl:
        canvas.drawCircle(center, 8, stroke);
        canvas.drawLine(
          center + const Offset(-4, 4),
          center + const Offset(4, -4),
          stroke,
        );
      case ElectricalComponentType.lightingPoint:
        canvas.drawCircle(center, 8, stroke);
        canvas.drawLine(
          center + const Offset(-5, -5),
          center + const Offset(5, 5),
          stroke,
        );
        canvas.drawLine(
          center + const Offset(5, -5),
          center + const Offset(-5, 5),
          stroke,
        );
      case ElectricalComponentType.curtainMotor:
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 16, height: 11),
          stroke,
        );
        _label(canvas, 'M', center, centered: true, small: true);
      case ElectricalComponentType.junctionBox:
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 15, height: 15),
          stroke,
        );
        canvas.drawCircle(center, 2, stroke);
      case ElectricalComponentType.powerSource:
        canvas.drawCircle(center, 8, stroke);
        canvas.drawLine(
          center + const Offset(0, -5),
          center + const Offset(0, 5),
          stroke,
        );
      case ElectricalComponentType.distributionBoard:
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 15, height: 18),
          stroke,
        );
        canvas.drawLine(
          center + const Offset(-4, -3),
          center + const Offset(4, -3),
          stroke,
        );
        canvas.drawLine(
          center + const Offset(-4, 2),
          center + const Offset(4, 2),
          stroke,
        );
      case ElectricalComponentType.custom:
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 15, height: 15),
          stroke,
        );
    }
    if (selected) {
      canvas.drawCircle(
        center,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = CadVisualTokens.selectedGeometry(scheme),
      );
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 5, height: 5),
        Paint()..color = CadVisualTokens.selectedGeometry(scheme),
      );
    }
  }

  void _drawNavigationEdges(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = scheme.primary.withValues(alpha: 0.12)
      ..strokeWidth = 5;
    canvas.drawLine(rect.topLeft, rect.topRight, paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.topLeft, rect.bottomLeft, paint);
    canvas.drawLine(rect.topRight, rect.bottomRight, paint);
  }

  void _horizontalDimension(
    Canvas canvas,
    double left,
    double right,
    double y,
    String text,
  ) {
    final paint = Paint()
      ..color = scheme.outline
      ..strokeWidth = 0.9;
    canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    _label(
      canvas,
      text,
      Offset((left + right) / 2, y - 10),
      centered: true,
      small: true,
    );
  }

  void _verticalDimension(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    String text,
  ) {
    final paint = Paint()
      ..color = scheme.outline
      ..strokeWidth = 0.9;
    canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    _label(canvas, text, Offset(x + 8, (top + bottom) / 2), small: true);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset point, {
    bool centered = false,
    bool bold = false,
    bool small = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: small ? 10 : 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centered ? point - Offset(painter.width / 2, painter.height / 2) : point,
    );
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter oldDelegate) =>
      oldDelegate.projection.camera != projection.camera ||
      oldDelegate.lod != lod ||
      oldDelegate.scheme != scheme ||
      oldDelegate.activeSurfaceId != activeSurfaceId ||
      oldDelegate.selectedSpaceId != selectedSpaceId ||
      oldDelegate.dimensionsVisible != dimensionsVisible ||
      oldDelegate.openingsVisible != openingsVisible ||
      oldDelegate.electricalVisible != electricalVisible ||
      oldDelegate.cableRoutesVisible != cableRoutesVisible ||
      oldDelegate.boundaryProfile != boundaryProfile ||
      oldDelegate.hoveredOpeningId != hoveredOpeningId ||
      oldDelegate.selectedOpeningId != selectedOpeningId ||
      oldDelegate.selectedRouteId != selectedRouteId ||
      oldDelegate.draftFingerprint != draftFingerprint ||
      oldDelegate.openingsFingerprint != openingsFingerprint ||
      oldDelegate.routeFingerprint != routeFingerprint ||
      oldDelegate.componentsFingerprint != componentsFingerprint ||
      oldDelegate.selectionFingerprint != selectionFingerprint ||
      oldDelegate.snapFingerprint != snapFingerprint ||
      oldDelegate.profileFingerprint != profileFingerprint;
}
