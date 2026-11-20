import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../domain/project_identity.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/adaptive_grid.dart';
import '../../engine/editor_layers.dart';
import '../../engine/plan_geometry_editing.dart';
import '../../engine/plan_pull_measure.dart';
import '../../engine/plan_cable_route_projector.dart';
import '../../engine/render_policy.dart';
import '../../engine/spatial_scene_index.dart';
import '../../engine/world_camera.dart';
import 'electrical_host_geometry_guard.dart';
import 'cable_editor_ui_session.dart';
import 'component_transform_session.dart';
import 'plan_component_move_projection.dart';
import 'plan_port_pair_session.dart';
import 'dynamic_wall_dimensions_overlay.dart';
import 'wall_distance_guide_calculator.dart';
import 'cable_trajectory_panel.dart';
import 'route_selection_session.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'canonical_room_boundary_projection.dart';
import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'catalog_component_placement.dart';
import 'horizontal_equipment_palette.dart';
import 'editor_viewport_commands.dart';
import 'viewport_zoom_policy.dart';
import 'plan_geometry_editor_actions.dart';

enum _PlanDragKind { vertex, edge, openingMove, openingStart, openingEnd }

class SpatialCanvas extends StatefulWidget {
  const SpatialCanvas({required this.controller, super.key});

  final EditorController controller;

  @override
  State<SpatialCanvas> createState() => _SpatialCanvasState();
}

class _SpatialCanvasState extends State<SpatialCanvas> {
  late final SpatialSceneIndex _sceneIndex;
  WorldCamera _camera = const WorldCamera(
    centerMm: MmPoint(5000, 3500),
    mmPerPixel: 12,
  );

  Size _size = Size.zero;
  Offset? _panAnchor;
  int? _panPointer;
  int? _primaryDragPointer;
  final Set<int> _activePointers = <int>{};
  WorldCamera? _touchStartCamera;
  Offset? _touchStartFocal;
  int _sceneFingerprint = -1;
  int _lastViewportRevision = 0;

  _PlanDragKind? _dragKind;
  int? _dragIndex;
  MmPoint? _dragStartWorld;
  MmPolygon? _dragBaseBoundary;
  MmPolygon? _previewBoundary;
  ArchitecturalOpening? _dragBaseOpening;
  ArchitecturalOpening? _previewOpening;
  int? _selectedExternalEdgeIndex;
  String? _selectedExternalSpaceId;
  int _selectedExternalPullSign = 1;
  String? _planMovingComponentId;
  MmPoint? _planMoveStart;
  Offset _planMoveDelta = Offset.zero;

  EditorController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _sceneIndex = SpatialSceneIndex();
    _lastViewportRevision = controller.viewportCommandRevision;
    controller.viewportCommandListenable.addListener(_onViewportCommand);
    controller.editCancellationListenable.addListener(
      _cancelTransientInteraction,
    );
    controller.p2.addListener(_onP2RoutesChanged);
    controller.routeSelection.addListener(_onP2RoutesChanged);
    controller.planPortPair.addListener(_onP2RoutesChanged);
    _rebuildIndex(force: true);
  }

  @override
  void didUpdateWidget(covariant SpatialCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.viewportCommandListenable.removeListener(
        _onViewportCommand,
      );
      oldWidget.controller.editCancellationListenable.removeListener(
        _cancelTransientInteraction,
      );
      oldWidget.controller.p2.removeListener(_onP2RoutesChanged);
      oldWidget.controller.routeSelection.removeListener(_onP2RoutesChanged);
      oldWidget.controller.planPortPair.removeListener(_onP2RoutesChanged);
      _lastViewportRevision = controller.viewportCommandRevision;
      controller.viewportCommandListenable.addListener(_onViewportCommand);
      controller.editCancellationListenable.addListener(
        _cancelTransientInteraction,
      );
      controller.p2.addListener(_onP2RoutesChanged);
      controller.routeSelection.addListener(_onP2RoutesChanged);
      controller.planPortPair.addListener(_onP2RoutesChanged);
      _selectedExternalEdgeIndex = null;
      _selectedExternalSpaceId = null;
      _selectedExternalPullSign = 1;
      _rebuildIndex(force: true);
    }
  }

  @override
  void dispose() {
    controller.viewportCommandListenable.removeListener(_onViewportCommand);
    controller.editCancellationListenable.removeListener(
      _cancelTransientInteraction,
    );
    controller.p2.removeListener(_onP2RoutesChanged);
    controller.routeSelection.removeListener(_onP2RoutesChanged);
    controller.planPortPair.removeListener(_onP2RoutesChanged);
    _endPlanComponentMove(cancel: true);
    super.dispose();
  }

  void _onP2RoutesChanged() {
    if (mounted) setState(() {});
  }

  void _pickPlanTarget(ElectricalComponentPlacement target) {
    final pair = controller.planPortPair;
    final ports = pair.compatiblePortsFor(target);
    if (ports.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Прямой кабель недоступен: нет совместимого порта на той же '
            'физической поверхности. Для другого помещения нужна проходка.',
          ),
        ),
      );
      return;
    }
    void choose(String portId) {
      if (pair.chooseTarget(componentId: target.id, portId: portId)) {
        controller.p2.select(target.id);
      }
    }

    if (ports.length == 1) {
      choose(ports.single.id);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Порт устройства · ${target.label}'),
        children: [
          for (final port in ports)
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                choose(port.id);
              },
              child: Text(port.id),
            ),
        ],
      ),
    );
  }

  Widget? _planPortPairOverlay(ColorScheme scheme) {
    final pair = controller.planPortPair;
    if (!pair.active) return null;
    final source = pair.sourceComponent;
    final target = pair.targetComponent;
    if (source == null) return null;

    void apply() {
      if (!pair.applyStraightRoute()) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Прямая трасса отклонена физической проверкой. '
              'Выполните ручную прокладку через допустимые поверхности.',
            ),
          ),
        );
      }
    }

    return Positioned(
      key: const ValueKey('plan-port-pair-overlay'),
      left: 12,
      top: 12,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        color: scheme.surfaceContainerHigh,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Соединение портов · предпросмотр'),
                const SizedBox(height: 5),
                Text('От: ${source.label} · ${pair.sourcePortId}'),
                Text(
                  target == null
                      ? 'Щёлкните по устройству-приёмнику на плане'
                      : 'К: ${target.label} · ${pair.targetPortId}',
                ),
                if (pair.straightLengthMm case final length?)
                  Text('Прямой участок: ${length.toStringAsFixed(0)} мм'),
                if (pair.straightRouteBlockReason case final reason?)
                  Text(
                    'Маршрут недопустим: $reason',
                    key: const ValueKey('plan-port-physical-blocked'),
                    style: TextStyle(color: scheme.error),
                  ),
                const Text(
                  'Кандидат геометрии; нормативное соответствие не '
                  'подтверждено.',
                  style: TextStyle(fontSize: 11),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton(
                      key: const ValueKey('plan-port-apply-on-plan'),
                      onPressed: pair.ready ? apply : null,
                      child: const Text('Проверить и проложить'),
                    ),
                    TextButton(
                      key: const ValueKey('plan-port-cancel-on-plan'),
                      onPressed: pair.reset,
                      child: const Text('Отмена'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startPlanComponentMove(
    ElectricalComponentPlacement component,
    EngineeringSpace space,
    List<BoundaryEdgeId>? edgeOrder,
  ) {
    if (controller.tool != EditorTool.select ||
        controller.planPortPair.active ||
        controller.cableUi.trajectoryEditing ||
        controller.p2.placementType != null ||
        controller.routeSegments.isNotEmpty ||
        controller.p2.layers.isLocked(EditorLayerId.electrical) ||
        !controller.p2.layers.isVisible(EditorLayerId.electrical)) {
      return;
    }
    final start = PlanComponentMoveProjection.planPointFor(
      space: space,
      component: component,
      orderedEdgeIds: edgeOrder,
    );
    if (start == null) return;
    controller.p2.select(component.id);
    if (!controller.componentTransform.begin()) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Перемещение недоступно: проверьте слои и блокировки '
            'подключённой трассы.',
          ),
        ),
      );
      return;
    }
    _planMovingComponentId = component.id;
    _planMoveStart = start;
    _planMoveDelta = Offset.zero;
  }

  void _updatePlanComponentMove(
    String componentId,
    DragUpdateDetails details,
    List<BoundaryEdgeId>? edgeOrder,
  ) {
    if (_planMovingComponentId != componentId) return;
    final start = _planMoveStart;
    final preview = controller.componentTransform.previewState;
    if (start == null || preview == null) return;
    final component = controller.p2.selectedComponent;
    final space = controller.level.spaces
        .where((item) => item.id == component?.surface.spaceId)
        .firstOrNull;
    if (component == null || component.id != componentId || space == null) {
      controller.componentTransform.cancel();
      _clearPlanMove();
      return;
    }
    _planMoveDelta += details.delta;
    final worldPoint = PlanComponentMoveProjection.draggedPlanPoint(
      initialPoint: start,
      dxPx: _planMoveDelta.dx,
      dyPx: _planMoveDelta.dy,
      mmPerPixel: _camera.mmPerPixel,
    );
    final candidate = PlanComponentMoveProjection.fromPlan(
      space: space,
      component: component,
      planPoint: worldPoint,
      orderedEdgeIds: edgeOrder,
    );
    final step = space.grid.minorStepMm;
    final snapped = candidate == null || !controller.snapEnabled
        ? candidate
        : SurfacePointMm(
            (candidate.xMm / step).round() * step,
            component.surface.type == SurfacePlaneType.wall
                ? candidate.yMm
                : (candidate.yMm / step).round() * step,
          );
    controller.componentTransform.preview(
      snapped ?? preview.position,
      isValid: snapped != null &&
          PlanComponentMoveProjection.allowedOnHost(
            space: space,
            component: component,
            position: snapped,
            orderedEdgeIds: edgeOrder,
            openings: controller.openings,
          ),
    );
  }

  void _endPlanComponentMove({required bool cancel}) {
    if (_planMovingComponentId == null) return;
    final invalid = !cancel && !controller.componentTransform.validate();
    if (cancel || invalid) {
      controller.componentTransform.cancel();
    } else if (!controller.componentTransform.commit()) {
      controller.componentTransform.cancel();
    }
    _clearPlanMove();
    if (invalid && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Недопустимое положение устройства. Исходная точка и '
            'электрические соединения сохранены.',
          ),
        ),
      );
    }
  }

  void _clearPlanMove() {
    _planMovingComponentId = null;
    _planMoveStart = null;
    _planMoveDelta = Offset.zero;
  }

  void _onViewportCommand() {
    if (mounted) {
      setState(() {});
    }
  }

  void _cancelTransientInteraction() {
    _endPlanComponentMove(cancel: true);
    if (_dragKind != null) {
      _finishPrimaryDrag(cancelled: true);
    }
    _panAnchor = null;
    _panPointer = null;
    _primaryDragPointer = null;
    _activePointers.clear();
    _touchStartCamera = null;
    _touchStartFocal = null;
  }

  int _fingerprint() => Object.hashAll(
        controller.level.spaces.map((space) {
          final bounds = space.boundary.bounds;
          return Object.hash(
            space.id,
            bounds.left,
            bounds.bottom,
            bounds.right,
            bounds.top,
            Object.hashAll(space.boundary.vertices),
          );
        }),
      );

  void _rebuildIndex({bool force = false}) {
    final next = _fingerprint();
    if (!force && next == _sceneFingerprint) {
      return;
    }
    _sceneIndex.rebuildSpaces(controller.level.spaces);
    _sceneFingerprint = next;
  }

  MmPoint _toWorld(Offset local) => _camera.screenToWorld(
        viewportWidthPx: _size.width,
        viewportHeightPx: _size.height,
        xPx: local.dx,
        yPx: local.dy,
      );

  Offset _toScreen(MmPoint point) {
    final screen = _camera.worldToScreen(
      viewportWidthPx: _size.width,
      viewportHeightPx: _size.height,
      point: point,
    );
    return Offset(screen.x, screen.y);
  }

  double get _hitRadiusMm => math.max(60, _camera.mmPerPixel * 11);

  WorldCamera _zoomed(Offset cursor, double factor) => _camera.zoomAt(
        factor: factor,
        viewportWidthPx: _size.width,
        viewportHeightPx: _size.height,
        cursorXpx: cursor.dx,
        cursorYpx: cursor.dy,
      );

  void _zoomAt(Offset cursor, double factor) {
    setState(() => _camera = _zoomed(cursor, factor));
  }

  WorldCamera _fitLevelCamera() {
    if (_size.isEmpty || controller.level.spaces.isEmpty) {
      return _camera;
    }
    var bounds = controller.level.spaces.first.boundary.bounds;
    for (final space in controller.level.spaces.skip(1)) {
      bounds = bounds.union(space.boundary.bounds);
    }
    return _camera.fitBounds(
      bounds: bounds,
      viewportWidthPx: _size.width,
      viewportHeightPx: _size.height,
    );
  }

  void _fitLevel() {
    setState(() => _camera = _fitLevelCamera());
  }

  void _fitSelection() {
    final space = controller.selectedSpace;
    if (space == null || _size.isEmpty) {
      return;
    }
    setState(() {
      _camera = _camera.fitBounds(
        bounds: space.boundary.bounds,
        viewportWidthPx: _size.width,
        viewportHeightPx: _size.height,
      );
    });
  }

  void _consumeViewportCommand() {
    final revision = controller.viewportCommandRevision;
    if (_size.isEmpty || revision == _lastViewportRevision) {
      return;
    }
    _lastViewportRevision = revision;
    final center = _size.center(Offset.zero);
    switch (controller.viewportCommand) {
      case EditorViewportCommand.zoomIn:
        _camera = _zoomed(center, 1.25);
      case EditorViewportCommand.zoomOut:
        _camera = _zoomed(center, 0.8);
      case EditorViewportCommand.reset:
        _camera = _fitLevelCamera();
      case null:
        break;
    }
  }

  void _startTouch(ScaleStartDetails details) {
    _touchStartCamera = _camera;
    _touchStartFocal = details.localFocalPoint;
  }

  void _updateTouch(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || _size.isEmpty) {
      return;
    }
    final startCamera = _touchStartCamera;
    final startFocal = _touchStartFocal;
    if (startCamera == null || startFocal == null) {
      return;
    }
    final delta = details.localFocalPoint - startFocal;
    var next = startCamera.panPixels(delta.dx, delta.dy);
    next = next.zoomAt(
      factor: details.scale,
      viewportWidthPx: _size.width,
      viewportHeightPx: _size.height,
      cursorXpx: details.localFocalPoint.dx,
      cursorYpx: details.localFocalPoint.dy,
    );
    setState(() => _camera = next);
  }

  void _endTouch(ScaleEndDetails details) {
    _touchStartCamera = null;
    _touchStartFocal = null;
  }

  MmPoint _snapEditingPoint(MmPoint raw) {
    if (!controller.snapEnabled) {
      return raw;
    }
    final step = controller.selectedSpace?.grid.minorStepMm ?? 100;
    int round(int value) => (value / step).round() * step;
    return MmPoint(round(raw.x), round(raw.y));
  }

  int? _vertexHandleAt(Offset local) {
    final space = controller.selectedSpace;
    if (space == null || controller.tool != EditorTool.select) {
      return null;
    }
    for (var i = 0; i < space.boundary.vertices.length; i++) {
      if ((_toScreen(space.boundary.vertices[i]) - local).distance <= 11) {
        return i;
      }
    }
    return null;
  }

  int? _edgeHandleAt(Offset local) {
    final space = controller.selectedSpace;
    if (space == null || controller.tool != EditorTool.select) {
      return null;
    }
    final vertices = space.boundary.vertices;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      final midpoint = MmPoint((a.x + b.x) ~/ 2, (a.y + b.y) ~/ 2);
      if ((_toScreen(midpoint) - local).distance <= 11) {
        return i;
      }
    }
    return null;
  }

  _PlanDragKind? _openingHandleAt(Offset local) {
    final opening = controller.selectedOpening;
    final wall = controller.activeWall;
    if (opening == null ||
        wall == null ||
        controller.tool != EditorTool.select) {
      return null;
    }
    final start = RoomSurfaceResolver.wallLocalToPlan(
      wall,
      opening.offsetFromStartMm,
    );
    final end = RoomSurfaceResolver.wallLocalToPlan(
      wall,
      opening.offsetFromStartMm + opening.widthMm,
    );
    final center = MmPoint((start.x + end.x) ~/ 2, (start.y + end.y) ~/ 2);
    if ((_toScreen(start) - local).distance <= 11) {
      return _PlanDragKind.openingStart;
    }
    if ((_toScreen(end) - local).distance <= 11) {
      return _PlanDragKind.openingEnd;
    }
    if ((_toScreen(center) - local).distance <= 13) {
      return _PlanDragKind.openingMove;
    }
    return null;
  }

  void _clearExternalWallSelection() {
    _selectedExternalEdgeIndex = null;
    _selectedExternalSpaceId = null;
    _selectedExternalPullSign = 1;
  }

  int _pullSignForCursor(int edgeIndex, Offset cursor) {
    final space = controller.selectedSpace;
    if (space == null ||
        edgeIndex < 0 ||
        edgeIndex >= space.boundary.vertices.length) {
      return 1;
    }
    final vertices = space.boundary.vertices;
    final a = _toScreen(vertices[edgeIndex]);
    final b = _toScreen(vertices[(edgeIndex + 1) % vertices.length]);
    final tangent = b - a;
    final length = tangent.distance;
    if (length < 1) return 1;
    final normal = Offset(-tangent.dy / length, tangent.dx / length);
    final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final delta = cursor - midpoint;
    return delta.dx * normal.dx + delta.dy * normal.dy >= 0 ? 1 : -1;
  }

  void _updatePullSideFromPointer(Offset local) {
    final index = _selectedExternalEdgeIndex;
    final space = controller.selectedSpace;
    if (index == null ||
        space == null ||
        _selectedExternalSpaceId != space.id ||
        !controller.isSelectedWallExternal(index)) {
      return;
    }
    final sign = _pullSignForCursor(index, local);
    if (sign != _selectedExternalPullSign) {
      setState(() => _selectedExternalPullSign = sign);
    }
  }

  void _beginPrimaryDrag(PointerDownEvent event) {
    if (controller.cableUi.trajectoryEditing) return;
    if (controller.tool != EditorTool.select) {
      return;
    }

    final openingHandle = _openingHandleAt(event.localPosition);
    if (openingHandle != null) {
      _clearExternalWallSelection();
      _primaryDragPointer = event.pointer;
      _dragKind = openingHandle;
      _dragBaseOpening = controller.selectedOpening;
      _previewOpening = _dragBaseOpening;
      return;
    }

    final world = _toWorld(event.localPosition);
    final opening = controller.openingAtPlanPoint(
      world,
      radiusMm: _hitRadiusMm,
    );
    if (opening != null) {
      _clearExternalWallSelection();
      controller.selectOpeningForPlan(opening);
      _primaryDragPointer = event.pointer;
      _dragKind = _PlanDragKind.openingMove;
      _dragBaseOpening = opening;
      _previewOpening = opening;
      return;
    }

    final vertex = _vertexHandleAt(event.localPosition);
    if (vertex != null) {
      _clearExternalWallSelection();
      _primaryDragPointer = event.pointer;
      _dragKind = _PlanDragKind.vertex;
      _dragIndex = vertex;
      _dragBaseBoundary = controller.selectedSpace?.boundary;
      _previewBoundary = _dragBaseBoundary;
      return;
    }

    final edge = _edgeHandleAt(event.localPosition);
    if (edge != null) {
      _primaryDragPointer = event.pointer;
      _dragKind = _PlanDragKind.edge;
      _dragIndex = edge;
      _dragStartWorld = world;
      _dragBaseBoundary = controller.selectedSpace?.boundary;
      _previewBoundary = _dragBaseBoundary;
    }
  }

  void _updatePrimaryDrag(PointerMoveEvent event) {
    final kind = _dragKind;
    if (kind == null ||
        event.pointer != _primaryDragPointer ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final raw = _toWorld(event.localPosition);

    switch (kind) {
      case _PlanDragKind.vertex:
        final base = _dragBaseBoundary;
        final index = _dragIndex;
        if (base == null || index == null) {
          return;
        }
        final candidate = PlanGeometryEditing.moveVertex(
          boundary: base,
          vertexIndex: index,
          target: _snapEditingPoint(raw),
        );
        if (candidate != null) {
          setState(() => _previewBoundary = candidate);
        }
      case _PlanDragKind.edge:
        final base = _dragBaseBoundary;
        final index = _dragIndex;
        final start = _dragStartWorld;
        if (base == null || index == null || start == null) {
          return;
        }
        final candidate = PlanGeometryEditing.moveEdge(
          boundary: base,
          edgeIndex: index,
          dragStart: start,
          dragCurrent: _snapEditingPoint(raw),
        );
        if (candidate != null) {
          setState(() => _previewBoundary = candidate);
        }
      case _PlanDragKind.openingMove:
      case _PlanDragKind.openingStart:
      case _PlanDragKind.openingEnd:
        _previewOpeningDrag(kind, raw);
    }
  }

  void _previewOpeningDrag(_PlanDragKind kind, MmPoint raw) {
    final base = _dragBaseOpening;
    final wall = controller.activeWall;
    final offset = controller.planPointToActiveWallOffset(raw);
    if (base == null || wall == null || offset == null) {
      return;
    }

    ArchitecturalOpening candidate;
    try {
      switch (kind) {
        case _PlanDragKind.openingMove:
          candidate = base.copyWith(
            offsetFromStartMm: offset - base.widthMm ~/ 2,
          );
        case _PlanDragKind.openingStart:
          final end = base.offsetFromStartMm + base.widthMm;
          final width = end - offset;
          if (width < 300) {
            return;
          }
          candidate = base.copyWith(offsetFromStartMm: offset, widthMm: width);
        case _PlanDragKind.openingEnd:
          final width = offset - base.offsetFromStartMm;
          if (width < 300) {
            return;
          }
          candidate = base.copyWith(widthMm: width);
        case _PlanDragKind.vertex:
        case _PlanDragKind.edge:
          return;
      }
    } on ArgumentError {
      return;
    }

    if (RoomSurfaceResolver.openingFitsWall(opening: candidate, wall: wall)) {
      setState(() => _previewOpening = candidate);
    }
  }

  void _finishPrimaryDrag({required bool cancelled}) {
    final kind = _dragKind;
    if (kind == null) {
      return;
    }

    if (!cancelled) {
      if ((kind == _PlanDragKind.vertex || kind == _PlanDragKind.edge) &&
          _previewBoundary != null) {
        controller.commitSelectedBoundary(_previewBoundary!);
        _rebuildIndex(force: true);
      } else if (_previewOpening case final opening?) {
        controller.updateSelectedOpeningGuarded(
          offsetFromStartMm: opening.offsetFromStartMm,
          widthMm: opening.widthMm,
          canCommit: (candidate) =>
              ElectricalHostGeometryGuard.openingCandidateAllowed(
            controller,
            candidate,
          ),
        );
        controller.viewMode = EditorViewMode.plan;
      }
    }

    setState(() {
      _dragKind = null;
      _primaryDragPointer = null;
      _dragIndex = null;
      _dragStartWorld = null;
      _dragBaseBoundary = null;
      _previewBoundary = null;
      _dragBaseOpening = null;
      _previewOpening = null;
    });
  }

  bool _canAcceptEquipment(EquipmentPaletteDragData data) {
    final entry = controller.componentCatalog.byId(data.catalogId);
    return entry != null &&
        controller.level.spaces.isNotEmpty &&
        controller.p2.layers.isVisible(EditorLayerId.electrical) &&
        !controller.p2.layers.isLocked(EditorLayerId.electrical) &&
        !controller.cableUi.trajectoryEditing &&
        _dragKind == null;
  }

  void _dropEquipmentOnPlan(
    EquipmentPaletteDragData data,
    Offset globalPosition,
    BuildContext canvasContext,
    Map<String, List<BoundaryEdgeId>> edgeOrder,
  ) {
    if (!_canAcceptEquipment(data)) return;
    final render = canvasContext.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final world = _toWorld(render.globalToLocal(globalPosition));
    final entry = controller.componentCatalog.byId(data.catalogId);
    if (entry == null) return;

    final candidateSpaces = [
      if (controller.selectedSpace case final selected?) selected,
      ...controller.level.spaces.where(
        (space) => space.id != controller.selectedSpaceId,
      ),
    ];
    for (final space in candidateSpaces) {
      final inside = space.boundary.contains(world);
      if (entry.mounting.allowedSurfaces.contains(SurfacePlaneType.wall)) {
        final canonicalContext =
            CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(
                controller);
        final ordered = edgeOrder[space.id];
        if (canonicalContext == null || ordered != null) {
          final walls = ordered == null
              ? RoomSurfaceResolver.walls(space)
              : RoomSurfaceResolver.wallsByBoundaryEdges(space, ordered);
          for (final wall in walls) {
            final dx = (wall.end.x - wall.start.x).toDouble();
            final dy = (wall.end.y - wall.start.y).toDouble();
            final length = wall.lengthMm.toDouble();
            if (length == 0) continue;
            final deltaX = (world.x - wall.start.x).toDouble();
            final deltaY = (world.y - wall.start.y).toDouble();
            final along = (deltaX * dx + deltaY * dy) / length;
            final distance = (deltaX * dy - deltaY * dx).abs() / length;
            if (distance > math.max(150, _camera.mmPerPixel * 20) ||
                along < 0 ||
                along > length) {
              continue;
            }
            final height =
                entry.mounting.preferredHeightMm ?? wall.heightMm ~/ 2;
            final position = SurfacePointMm(along.round(), height);
            if (!wall.profile.containsPoint(position.xMm, position.yMm)) {
              continue;
            }
            final blockedByOpening = controller.openings.any((opening) {
              if (opening.hostWall != wall.ref) return false;
              return position.xMm > opening.offsetFromStartMm &&
                  position.xMm < opening.endOffsetMm &&
                  position.yMm > opening.sillHeightMm &&
                  position.yMm < opening.topMm;
            });
            if (blockedByOpening || !entry.canPlaceOn(wall.ref)) continue;
            if (controller.selectedSpaceId != space.id) {
              controller.selectSpace(space.id);
            }
            controller.p2.placeCatalogComponent(
              entry: entry,
              surface: wall.ref,
              position: position,
            );
            return;
          }
        }
      }
      if (!inside) continue;
      final targetType =
          entry.mounting.allowedSurfaces.contains(SurfacePlaneType.floor)
              ? SurfacePlaneType.floor
              : entry.mounting.allowedSurfaces.contains(
                    SurfacePlaneType.ceiling,
                  )
                  ? SurfacePlaneType.ceiling
                  : null;
      if (targetType == null) continue;
      final target = targetType == SurfacePlaneType.floor
          ? RoomSurfaceRef.floor(space.id)
          : RoomSurfaceRef.ceiling(space.id);
      if (!entry.canPlaceOn(target)) continue;
      final bounds = space.boundary.bounds;
      if (controller.selectedSpaceId != space.id) {
        controller.selectSpace(space.id);
      }
      controller.p2.placeCatalogComponent(
        entry: entry,
        surface: target,
        position: SurfacePointMm(
          world.x - bounds.left,
          world.y - bounds.bottom,
        ),
      );
      return;
    }
  }

  void _tap(TapUpDetails details, PlanCableProjection projection) {
    if (controller.cableUi.trajectoryEditing) {
      String? nearest;
      var distance = 14.0;
      for (final segment in projection.segments) {
        for (var i = 1; i < segment.points.length; i++) {
          final a = _toScreen(segment.points[i - 1]);
          final b = _toScreen(segment.points[i]);
          final delta = b - a;
          final length = delta.distanceSquared;
          final offset = details.localPosition - a;
          final t = length == 0
              ? 0.0
              : ((offset.dx * delta.dx + offset.dy * delta.dy) / length)
                  .clamp(0.0, 1.0);
          final d = (details.localPosition - (a + delta * t)).distance;
          if (d < distance) {
            nearest = segment.routeId;
            distance = d;
          }
        }
      }
      if (nearest != null) controller.routeSelection.select(nearest);
      return;
    }
    if (_dragKind != null) {
      return;
    }
    final world = _toWorld(details.localPosition);
    if (controller.tool == EditorTool.select) {
      final opening = controller.openingAtPlanPoint(
        world,
        radiusMm: _hitRadiusMm,
      );
      if (opening != null) {
        setState(_clearExternalWallSelection);
        controller.selectOpeningForPlan(opening);
        return;
      }

      final wallIndex = controller.selectedWallIndexAtPlanPoint(
        world,
        radiusMm: _hitRadiusMm,
      );
      if (wallIndex != null) {
        final external = controller.isSelectedWallExternal(wallIndex);
        setState(() {
          if (external) {
            _selectedExternalEdgeIndex = wallIndex;
            _selectedExternalSpaceId = controller.selectedSpaceId;
            _selectedExternalPullSign = _pullSignForCursor(
              wallIndex,
              details.localPosition,
            );
          } else {
            _clearExternalWallSelection();
          }
        });
        return;
      }
    }

    setState(_clearExternalWallSelection);
    controller.canvasTap(
      world,
      snapRadiusMm: math.max(40, _camera.mmPerPixel * 12),
    );
  }

  Widget? _buildExternalWallGizmo(ColorScheme scheme) {
    final space = controller.selectedSpace;
    final index = _selectedExternalEdgeIndex;
    if (controller.tool != EditorTool.select ||
        space == null ||
        index == null ||
        _selectedExternalSpaceId != space.id ||
        index < 0 ||
        index >= space.boundary.vertices.length ||
        !controller.isSelectedWallExternal(index)) {
      return null;
    }

    final vertices = space.boundary.vertices;
    final a = _toScreen(vertices[index]);
    final b = _toScreen(vertices[(index + 1) % vertices.length]);
    final tangent = b - a;
    final length = tangent.distance;
    if (length < 1) return null;

    final normal = Offset(-tangent.dy / length, tangent.dx / length);
    final direction = normal * _selectedExternalPullSign.toDouble();
    final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    var center = midpoint + direction * 34;
    center = Offset(
      center.dx.clamp(24.0, math.max(24.0, _size.width - 24.0)),
      center.dy.clamp(24.0, math.max(24.0, _size.height - 24.0)),
    );
    final angle = math.atan2(direction.dy, direction.dx);
    final stepMm = space.grid.minorStepMm;

    void nudge() {
      final distanceMm = _selectedExternalPullSign * stepMm;
      if (controller.nudgeSelectedBoundaryEdgeNormal(index, distanceMm)) {
        _rebuildIndex(force: true);
        setState(() {});
      }
    }

    return Positioned(
      left: center.dx - 20,
      top: center.dy - 20,
      child: Material(
        elevation: 3,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.97),
        shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
        child: SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            tooltip: 'Потянуть границу на $stepMm mm',
            padding: EdgeInsets.zero,
            onPressed: nudge,
            icon: Transform.rotate(
              angle: angle,
              child: const Icon(Icons.arrow_forward, size: 19),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildPullMeasureOverlay(ColorScheme scheme) {
    final space = controller.selectedSpace;
    final index = _selectedExternalEdgeIndex;
    if (space == null ||
        index == null ||
        _selectedExternalSpaceId != space.id ||
        !controller.isSelectedWallExternal(index)) {
      return null;
    }
    final measure = PlanPullMeasureResolver.nearestParallelBoundary(
      space: space,
      edgeIndex: index,
    );
    if (measure == null) return null;

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _PullMeasurePainter(
            from: _toScreen(measure.sourceMidpoint),
            to: _toScreen(measure.targetPoint),
            distanceMm: measure.distanceMm,
            scheme: scheme,
          ),
        ),
      ),
    );
  }

  MmPoint? _planPairWorldPoint(
    ElectricalComponentPlacement? component,
    Map<String, List<BoundaryEdgeId>> edgeOrder,
  ) {
    if (component == null) return null;
    final space = controller.level.spaces
        .where((item) => item.id == component.surface.spaceId)
        .firstOrNull;
    if (space == null) return null;
    return PlanComponentMoveProjection.planPointFor(
      space: space,
      component: component,
      orderedEdgeIds: edgeOrder[space.id],
    );
  }

  List<WallDistanceGuide> _dynamicWallGuides(
    Map<String, List<BoundaryEdgeId>> edgeOrder,
  ) {
    if (controller.viewMode != EditorViewMode.plan ||
        controller.tool != EditorTool.select ||
        !controller.p2.layers.isVisible(EditorLayerId.electrical)) {
      return const [];
    }
    final component = controller.p2.selectedComponent;
    if (component == null) return const [];
    final space = controller.level.spaces
        .where((item) => item.id == component.surface.spaceId)
        .firstOrNull;
    if (space == null) return const [];
    final preview = controller.componentTransform.previewState;
    if (preview != null &&
        preview.componentId == component.id &&
        !preview.isValid) {
      return const [];
    }
    final effective = preview != null && preview.componentId == component.id
        ? component.copyWith(position: preview.position)
        : component;
    final anchor = PlanComponentMoveProjection.planPointFor(
      space: space,
      component: effective,
      orderedEdgeIds: edgeOrder[space.id],
    );
    if (anchor == null) return const [];
    return WallDistanceGuideCalculator.fromAnchor(
      room: space.boundary,
      anchor: anchor,
      acceptWallHit: (edgeIndex, fraction) {
        final vertices = space.boundary.vertices;
        final length = vertices[edgeIndex]
            .distanceTo(vertices[(edgeIndex + 1) % vertices.length]);
        final hitOffset = length * fraction;
        for (final opening in controller.openings) {
          if (opening.hostWall.spaceId != space.id) continue;
          final canonicalEdge = opening.hostWall.boundaryEdgeId;
          final wallIndex = canonicalEdge == null
              ? opening.hostWall.wallIndex
              : edgeOrder[space.id]?.indexOf(canonicalEdge);
          if (wallIndex == null || wallIndex < 0) return false;
          if (wallIndex == edgeIndex &&
              hitOffset >= opening.offsetFromStartMm &&
              hitOffset <= opening.endOffsetMm) {
            return false;
          }
        }
        return true;
      },
    );
  }

  List<Widget> _equipmentMarkers(Map<String, List<BoundaryEdgeId>> edgeOrder) {
    final spaces = {
      for (final space in controller.level.spaces) space.id: space
    };
    final result = <Widget>[];
    for (final component in controller.p2.components) {
      final space = spaces[component.surface.spaceId];
      if (space == null) continue;
      final point = PlanCableRouteProjector.projectPoint(
        space: space,
        surface: component.surface,
        point: component.position,
        orderedEdgeIds: edgeOrder[space.id],
      );
      if (point == null) continue;
      final position = _toScreen(point);
      if (position.dx < 0 ||
          position.dy < 0 ||
          position.dx > _size.width ||
          position.dy > _size.height) {
        continue;
      }
      final icon = switch (component.type) {
        ElectricalComponentType.distributionBoard => Icons.electrical_services,
        ElectricalComponentType.socketOutlet => Icons.power,
        ElectricalComponentType.switchControl => Icons.toggle_on_outlined,
        ElectricalComponentType.lightingPoint => Icons.lightbulb_outline,
        _ => Icons.sensors,
      };
      final selected = controller.p2.selection.contains(component.id);
      final isPairSource =
          controller.planPortPair.sourceComponentId == component.id;
      final isPairTarget =
          controller.planPortPair.targetComponentId == component.id;
      final highlighted = selected || isPairSource || isPairTarget;
      final scheme = Theme.of(context).colorScheme;
      result.add(Positioned(
        left: position.dx - 16,
        top: position.dy - 16,
        width: 32,
        height: 32,
        child: Tooltip(
          message: isPairSource
              ? '${component.label} · начальный порт'
              : isPairTarget
                  ? '${component.label} · конечный порт'
                  : component.label,
          child: Material(
            color: isPairSource
                ? scheme.tertiaryContainer
                : highlighted
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
            shape: CircleBorder(
              side: highlighted
                  ? BorderSide(
                      color: isPairSource ? scheme.tertiary : scheme.primary,
                      width: 2,
                    )
                  : BorderSide.none,
            ),
            child: GestureDetector(
              onPanStart: (_) => _startPlanComponentMove(
                component,
                space,
                edgeOrder[space.id],
              ),
              onPanUpdate: (details) => _updatePlanComponentMove(
                component.id,
                details,
                edgeOrder[space.id],
              ),
              onPanEnd: (_) => _endPlanComponentMove(cancel: false),
              onPanCancel: () => _endPlanComponentMove(cancel: true),
              child: InkWell(
                key: ValueKey('plan-component-${component.id}'),
                customBorder: const CircleBorder(),
                onTap: controller.tool != EditorTool.select
                    ? null
                    : () {
                        if (controller.planPortPair.choosingTarget) {
                          _pickPlanTarget(component);
                        } else {
                          controller.p2.select(component.id);
                        }
                      },
                child: Icon(
                  icon,
                  size: 19,
                  semanticLabel: component.label,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ),
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    _rebuildIndex();
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        _consumeViewportCommand();
        final visibleBounds = _camera.visibleWorldBounds(
          viewportWidthPx: _size.width,
          viewportHeightPx: _size.height,
        );
        final visibleSpaces = _sceneIndex.visibleSpaces(visibleBounds);
        final lod = RenderPolicy.lodForWorldUnitsPerPixel(_camera.mmPerPixel);
        final compact = MediaQuery.sizeOf(context).width < 700;
        final scheme = Theme.of(context).colorScheme;
        final pullMeasureOverlay = _buildPullMeasureOverlay(scheme);
        final externalWallGizmo = _buildExternalWallGizmo(scheme);
        final boundaryEdgeOrder = <String, List<BoundaryEdgeId>>{};
        final routingContext =
            CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(
                controller);
        if (routingContext != null) {
          for (final space in controller.level.spaces) {
            final canonicalId =
                routingContext.canonicalSpaceIdForLegacy(space.id);
            if (canonicalId == null) continue;
            final canonicalSpace =
                routingContext.project.index.space(canonicalId);
            final topology = routingContext.project.index.boundary(canonicalId);
            if (canonicalSpace == null ||
                topology == null ||
                routingContext.binding.legacyLevelIds[canonicalSpace.levelId] !=
                    controller.level.id) {
              continue;
            }
            try {
              final projection = CanonicalRoomBoundaryProjection.build(
                canonicalSpaceId: canonicalId,
                legacySpaceId: space.id,
                canonicalTopology: topology,
                legacySpace: space,
              );
              boundaryEdgeOrder[space.id] = projection.orderedEdgeIds;
            } on CanonicalRoomBoundaryProjectionException {
              // A stale/missing host is omitted, never guessed from selection.
            }
          }
        }
        final cableProjection = PlanCableRouteProjector.project(
          level: controller.level,
          boundaryEdgeOrderBySpace: boundaryEdgeOrder,
          routes: controller.p2.layers.isVisible(EditorLayerId.cableRoutes)
              ? controller.p2.routes
              : const [],
        );

        return DragTarget<EquipmentPaletteDragData>(
          onWillAcceptWithDetails: (details) =>
              _canAcceptEquipment(details.data),
          onAcceptWithDetails: (details) => _dropEquipmentOnPlan(
            details.data,
            details.offset,
            context,
            boundaryEdgeOrder,
          ),
          builder: (context, candidates, rejects) => Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PlanPainter(
                      controller: controller,
                      camera: _camera,
                      visibleSpaces: visibleSpaces,
                      lod: lod,
                      previewBoundary: _previewBoundary,
                      previewOpening: _previewOpening,
                      cableProjection: cableProjection,
                      scheme: scheme,
                    ),
                  ),
                ),
              ),
              if (pullMeasureOverlay != null) pullMeasureOverlay,
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerHover: (event) {
                    _updatePullSideFromPointer(event.localPosition);
                  },
                  onPointerSignal: (event) {
                    if (event is! PointerScrollEvent) return;
                    final factor = ViewportZoomPolicy.factorForScrollDelta(
                      dx: event.scrollDelta.dx,
                      dy: event.scrollDelta.dy,
                    );
                    if (factor == null) return;
                    GestureBinding.instance.pointerSignalResolver.register(
                      event,
                      (_) => _zoomAt(event.localPosition, factor),
                    );
                  },
                  onPointerDown: (event) {
                    _activePointers.add(event.pointer);
                    if (_activePointers.length > 1) {
                      if (_dragKind != null) {
                        _finishPrimaryDrag(cancelled: true);
                      }
                      return;
                    }
                    if (event.buttons == kMiddleMouseButton) {
                      _panPointer = event.pointer;
                      _panAnchor = event.localPosition;
                      return;
                    }
                    if (event.buttons == kPrimaryMouseButton) {
                      _beginPrimaryDrag(event);
                    }
                  },
                  onPointerMove: (event) {
                    final anchor = _panAnchor;
                    if (anchor != null && event.pointer == _panPointer) {
                      final delta = event.localPosition - anchor;
                      _panAnchor = event.localPosition;
                      setState(() {
                        _camera = _camera.panPixels(delta.dx, delta.dy);
                      });
                      return;
                    }
                    if (event.buttons == 0) {
                      _updatePullSideFromPointer(event.localPosition);
                    }
                    _updatePrimaryDrag(event);
                  },
                  onPointerUp: (event) {
                    _activePointers.remove(event.pointer);
                    if (event.pointer == _panPointer) {
                      _panPointer = null;
                      _panAnchor = null;
                    }
                    if (event.pointer == _primaryDragPointer) {
                      _finishPrimaryDrag(cancelled: false);
                    }
                  },
                  onPointerCancel: (event) {
                    _activePointers.remove(event.pointer);
                    if (event.pointer == _panPointer) {
                      _panPointer = null;
                      _panAnchor = null;
                    }
                    if (event.pointer == _primaryDragPointer) {
                      _finishPrimaryDrag(cancelled: true);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _tap(details, cableProjection),
                    onScaleStart: _startTouch,
                    onScaleUpdate: _updateTouch,
                    onScaleEnd: _endTouch,
                  ),
                ),
              ),
              if (controller.planPortPair.ready)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _PlanPortPairPainter(
                        source: _planPairWorldPoint(
                          controller.planPortPair.sourceComponent,
                          boundaryEdgeOrder,
                        ),
                        target: _planPairWorldPoint(
                          controller.planPortPair.targetComponent,
                          boundaryEdgeOrder,
                        ),
                        camera: _camera,
                        scheme: scheme,
                        viewport: _size,
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: DynamicWallDimensionsOverlay(
                  selectionId: controller.tool == EditorTool.select
                      ? controller.p2.selectedComponent?.id
                      : null,
                  sceneId:
                      '${identityHashCode(controller)}:${controller.level.id}:'
                      '${controller.selectedSpaceId}',
                  guides: _dynamicWallGuides(boundaryEdgeOrder),
                  camera: _camera,
                  viewport: _size,
                  held: controller.distanceGuideHeld,
                ),
              ),
              if (controller.p2.layers.isVisible(EditorLayerId.electrical))
                ..._equipmentMarkers(boundaryEdgeOrder),
              if (_planPortPairOverlay(scheme) case final overlay?) overlay,
              if (cableProjection.segments.isNotEmpty ||
                  cableProjection.hasIncompleteProjection)
                Positioned(
                  left: 10,
                  top: 58,
                  child: IgnorePointer(
                    child: Chip(
                      key: const ValueKey('plan-p2-cable-overlay-status'),
                      avatar: const Icon(Icons.cable, size: 16),
                      label: Text(
                        'P2 трассы (не P11) · '
                        '${cableProjection.segments.length} сегм.'
                        '${cableProjection.hasIncompleteProjection ? " · неподтверждённые поверхности: ${cableProjection.skippedSurfaceSegments}" : ""}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              if (externalWallGizmo != null) externalWallGizmo,
              Positioned(
                left: 10,
                top: 100,
                child: CableTrajectoryPanel(controller: controller),
              ),
              Positioned(
                right: compact ? 8 : 12,
                top: compact ? 8 : 12,
                child: _ViewportControls(
                  compact: compact,
                  lod: lod,
                  mmPerPixel: _camera.mmPerPixel,
                  onFitLevel: _fitLevel,
                  onFitSelection: _fitSelection,
                  onZoomIn: () => _zoomAt(_size.center(Offset.zero), 1.25),
                  onZoomOut: () => _zoomAt(_size.center(Offset.zero), 0.8),
                ),
              ),
              if (controller.tool == EditorTool.select &&
                  controller.selectedSpace != null)
                const Positioned(
                  left: 10,
                  bottom: 10,
                  child: Chip(
                    avatar: Icon(Icons.edit_outlined, size: 16),
                    label: Text('Select: ● вершина · ■ стена · проём'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlanPainter extends CustomPainter {
  _PlanPainter({
    required EditorController controller,
    required this.camera,
    required this.visibleSpaces,
    required this.lod,
    required this.previewBoundary,
    required this.previewOpening,
    required this.cableProjection,
    required this.scheme,
  })  : selectedSpaceId = controller.selectedSpaceId,
        selectedOpeningId = controller.selectedOpeningId,
        dimensionsVisible = controller.dimensionsVisible,
        tool = controller.tool,
        openings = List.unmodifiable(controller.openings),
        openingFingerprint = Object.hashAll(
          controller.openings.map(
            (opening) => Object.hash(
              opening.id,
              opening.hostWall.id,
              opening.offsetFromStartMm,
              opening.widthMm,
              opening.heightMm,
              opening.sillHeightMm,
              opening.type,
            ),
          ),
        ),
        sceneFingerprint = Object.hashAll(
          visibleSpaces.map(
            (space) =>
                Object.hash(space.id, Object.hashAll(space.boundary.vertices)),
          ),
        );

  final WorldCamera camera;
  final List<EngineeringSpace> visibleSpaces;
  final RenderLod lod;
  final String? selectedSpaceId;
  final String? selectedOpeningId;
  final bool dimensionsVisible;
  final EditorTool tool;
  final List<ArchitecturalOpening> openings;
  final MmPolygon? previewBoundary;
  final ArchitecturalOpening? previewOpening;
  final PlanCableProjection cableProjection;
  final ColorScheme scheme;
  final int openingFingerprint;
  final int sceneFingerprint;

  int get routeFingerprint => Object.hashAll([
        cableProjection.skippedSurfaceSegments,
        for (final segment in cableProjection.segments)
          Object.hash(
            segment.routeId,
            segment.surfaceType,
            Object.hashAll(segment.points),
          ),
      ]);

  Offset p(MmPoint point, Size size) {
    final screen = camera.worldToScreen(
      viewportWidthPx: size.width,
      viewportHeightPx: size.height,
      point: point,
    );
    return Offset(screen.x, screen.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    for (final space in visibleSpaces) {
      final boundary = space.id == selectedSpaceId && previewBoundary != null
          ? previewBoundary!
          : space.boundary;
      _drawSpace(canvas, size, space, boundary);
    }
    _drawCableRoutes(canvas, size);
  }

  /// Physical P2 route projection only. No inferred connection across rooms.
  void _drawCableRoutes(Canvas canvas, Size size) {
    for (final segment in cableProjection.segments) {
      final color = switch (segment.surfaceType) {
        SurfacePlaneType.floor => scheme.tertiary,
        SurfacePlaneType.wall => scheme.primary,
        SurfacePlaneType.ceiling => scheme.secondary,
      };
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.9);
      if (segment.isVerticalPlanMarker) {
        final center = p(segment.points.first, size);
        canvas.drawCircle(center, 5, paint);
        canvas.drawCircle(
          center,
          2,
          Paint()..color = color.withValues(alpha: 0.9),
        );
        continue;
      }
      final path = Path();
      final first = p(segment.points.first, size);
      path.moveTo(first.dx, first.dy);
      for (final point in segment.points.skip(1)) {
        final position = p(point, size);
        path.lineTo(position.dx, position.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);
    final visible = camera.visibleWorldBounds(
      viewportWidthPx: size.width,
      viewportHeightPx: size.height,
      overscanPx: 0,
    );
    final grid = AdaptiveGridPolicy.forScale(camera.mmPerPixel);
    final startX = (visible.left / grid.minorStepMm).floor() * grid.minorStepMm;
    final startY =
        (visible.bottom / grid.minorStepMm).floor() * grid.minorStepMm;
    final minor = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 0.6;
    final major = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.7)
      ..strokeWidth = 0.9;

    for (var x = startX; x <= visible.right; x += grid.minorStepMm) {
      final majorLine = x % grid.majorStepMm == 0;
      if (!majorLine && !grid.showMinor) {
        continue;
      }
      canvas.drawLine(
        p(MmPoint(x, visible.bottom), size),
        p(MmPoint(x, visible.top), size),
        majorLine ? major : minor,
      );
    }
    for (var y = startY; y <= visible.top; y += grid.minorStepMm) {
      final majorLine = y % grid.majorStepMm == 0;
      if (!majorLine && !grid.showMinor) {
        continue;
      }
      canvas.drawLine(
        p(MmPoint(visible.left, y), size),
        p(MmPoint(visible.right, y), size),
        majorLine ? major : minor,
      );
    }
  }

  void _drawSpace(
    Canvas canvas,
    Size size,
    EngineeringSpace space,
    MmPolygon boundary,
  ) {
    final selected = space.id == selectedSpaceId;
    final path = Path();
    final first = p(boundary.vertices.first, size);
    path.moveTo(first.dx, first.dy);
    for (final vertex in boundary.vertices.skip(1)) {
      final at = p(vertex, size);
      path.lineTo(at.dx, at.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.onSurface.withValues(alpha: 0.025),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.2 : 1.25
        ..color = selected ? scheme.primary : scheme.outline,
    );

    _drawOpenings(canvas, size, space, boundary);
    if (RenderPolicy.showRoomLabels(lod)) {
      _drawLabel(canvas, size, space, boundary);
    }
    if (selected && dimensionsVisible && RenderPolicy.showFineDimensions(lod)) {
      _drawDimensions(canvas, size, boundary);
    }
    if (selected && tool == EditorTool.select) {
      _drawBoundaryHandles(canvas, size, boundary);
    }
  }

  void _drawBoundaryHandles(Canvas canvas, Size size, MmPolygon boundary) {
    final vertices = boundary.vertices;
    for (var i = 0; i < vertices.length; i++) {
      final a = p(vertices[i], size);
      final b = p(vertices[(i + 1) % vertices.length], size);
      final midpoint = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      canvas.drawRect(
        Rect.fromCenter(center: midpoint, width: 9, height: 9),
        Paint()..color = scheme.tertiary,
      );
      canvas.drawCircle(a, 6.5, Paint()..color = scheme.primary);
      canvas.drawCircle(
        a,
        6.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = scheme.onPrimary,
      );
    }
  }

  void _drawOpenings(
    Canvas canvas,
    Size size,
    EngineeringSpace space,
    MmPolygon boundary,
  ) {
    final projectedSpace =
        boundary == space.boundary ? space : space.copyWith(boundary: boundary);
    final walls = RoomSurfaceResolver.walls(projectedSpace);

    for (final source in openings) {
      if (source.hostWall.spaceId != space.id ||
          source.hostWall.wallIndex == null) {
        continue;
      }
      final index = source.hostWall.wallIndex!;
      if (index < 0 || index >= walls.length) {
        continue;
      }
      final opening =
          previewOpening?.id == source.id ? previewOpening! : source;
      final wall = walls[index];
      final startWorld = RoomSurfaceResolver.wallLocalToPlan(
        wall,
        opening.offsetFromStartMm,
      );
      final endWorld = RoomSurfaceResolver.wallLocalToPlan(
        wall,
        opening.offsetFromStartMm + opening.widthMm,
      );
      final a = p(startWorld, size);
      final b = p(endWorld, size);
      final selected = opening.id == selectedOpeningId;

      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = selected ? scheme.secondary : scheme.tertiary
          ..strokeWidth = selected ? 4 : 2.4,
      );

      if (selected && tool == EditorTool.select) {
        final center = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        canvas.drawCircle(a, 6, Paint()..color = scheme.secondary);
        canvas.drawCircle(b, 6, Paint()..color = scheme.secondary);
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 11, height: 11),
          Paint()..color = scheme.secondary,
        );
      }
    }
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    EngineeringSpace space,
    MmPolygon boundary,
  ) {
    final center = p(boundary.bounds.center, size);
    final painter = TextPainter(
      text: TextSpan(
        text: space.name,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _drawDimensions(Canvas canvas, Size size, MmPolygon boundary) {
    final bounds = boundary.bounds;
    final bottomLeft = p(MmPoint(bounds.left, bounds.bottom), size);
    final bottomRight = p(MmPoint(bounds.right, bounds.bottom), size);
    final topRight = p(MmPoint(bounds.right, bounds.top), size);
    final paint = Paint()
      ..color = scheme.outline
      ..strokeWidth = 0.8;

    final y = math.max(bottomLeft.dy, bottomRight.dy) + 22;
    canvas.drawLine(Offset(bottomLeft.dx, y), Offset(bottomRight.dx, y), paint);
    _text(
      canvas,
      '${bounds.width} mm',
      Offset((bottomLeft.dx + bottomRight.dx) / 2, y - 8),
    );

    final x = topRight.dx + 24;
    canvas.drawLine(Offset(x, topRight.dy), Offset(x, bottomRight.dy), paint);
    _text(
      canvas,
      '${bounds.height} mm',
      Offset(x + 5, (topRight.dy + bottomRight.dy) / 2),
    );
  }

  void _text(Canvas canvas, String value, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(fontSize: 10, color: scheme.outline),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PlanPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.sceneFingerprint != sceneFingerprint ||
      oldDelegate.selectedSpaceId != selectedSpaceId ||
      oldDelegate.selectedOpeningId != selectedOpeningId ||
      oldDelegate.dimensionsVisible != dimensionsVisible ||
      oldDelegate.tool != tool ||
      oldDelegate.openingFingerprint != openingFingerprint ||
      oldDelegate.previewBoundary != previewBoundary ||
      oldDelegate.previewOpening != previewOpening ||
      oldDelegate.cableProjection.segments.length !=
          cableProjection.segments.length ||
      oldDelegate.routeFingerprint != routeFingerprint ||
      oldDelegate.scheme != scheme;
}

class _PullMeasurePainter extends CustomPainter {
  const _PullMeasurePainter({
    required this.from,
    required this.to,
    required this.distanceMm,
    required this.scheme,
  });

  final Offset from;
  final Offset to;
  final int distanceMm;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final delta = to - from;
    final length = delta.distance;
    if (length < 1) return;
    final direction = delta / length;
    final normal = Offset(-direction.dy, direction.dx);
    final paint = Paint()
      ..color = scheme.primary.withValues(alpha: 0.82)
      ..strokeWidth = 1.15;

    const dash = 7.0;
    const gap = 4.0;
    for (var d = 0.0; d < length; d += dash + gap) {
      final end = math.min(d + dash, length);
      canvas.drawLine(from + direction * d, from + direction * end, paint);
    }
    canvas.drawLine(from - normal * 6, from + normal * 6, paint);
    canvas.drawLine(to - normal * 6, to + normal * 6, paint);

    final midpoint = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final text = TextPainter(
      text: TextSpan(
        text: '$distanceMm mm',
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          backgroundColor: scheme.surface.withValues(alpha: 0.88),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelAt = midpoint + normal * 12;
    text.paint(canvas, labelAt - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PullMeasurePainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.distanceMm != distanceMm ||
      oldDelegate.scheme != scheme;
}

class _ViewportControls extends StatelessWidget {
  const _ViewportControls({
    required this.compact,
    required this.lod,
    required this.mmPerPixel,
    required this.onFitLevel,
    required this.onFitSelection,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool compact;
  final RenderLod lod;
  final double mmPerPixel;
  final VoidCallback onFitLevel;
  final VoidCallback onFitSelection;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      IconButton(
        tooltip: 'Вписать этаж',
        onPressed: onFitLevel,
        icon: const Icon(Icons.fit_screen),
      ),
      IconButton(
        tooltip: 'Вписать выбранное',
        onPressed: onFitSelection,
        icon: const Icon(Icons.center_focus_strong),
      ),
      IconButton(
        tooltip: 'Уменьшить',
        onPressed: onZoomOut,
        icon: const Icon(Icons.zoom_out),
      ),
      IconButton(
        tooltip: 'Увеличить',
        onPressed: onZoomIn,
        icon: const Icon(Icons.zoom_in),
      ),
    ];

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: compact
            ? Column(mainAxisSize: MainAxisSize.min, children: buttons)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...buttons,
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 7),
                    child: Text(
                      '${lod.name} · ${mmPerPixel.toStringAsFixed(1)} mm/px',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The dashed preview is never a committed cable or normative clearance.
class _PlanPortPairPainter extends CustomPainter {
  const _PlanPortPairPainter({
    required this.source,
    required this.target,
    required this.camera,
    required this.scheme,
    required this.viewport,
  });

  final MmPoint? source;
  final MmPoint? target;
  final WorldCamera camera;
  final ColorScheme scheme;
  final Size viewport;

  @override
  void paint(Canvas canvas, Size size) {
    if (source == null || target == null) return;
    final a = camera.worldToScreen(
      viewportWidthPx: viewport.width,
      viewportHeightPx: viewport.height,
      point: source!,
    );
    final b = camera.worldToScreen(
      viewportWidthPx: viewport.width,
      viewportHeightPx: viewport.height,
      point: target!,
    );
    final start = Offset(a.x, a.y);
    final end = Offset(b.x, b.y);
    final delta = end - start;
    final length = delta.distance;
    if (length < 1) return;
    final paint = Paint()
      ..color = scheme.tertiary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dash = 9.0;
    const gap = 6.0;
    for (var d = 0.0; d < length; d += dash + gap) {
      canvas.drawLine(
        start + delta * (d / length),
        start + delta * (math.min(length, d + dash) / length),
        paint,
      );
    }
    canvas.drawCircle(start, 5, paint);
    canvas.drawCircle(end, 5, paint);
  }

  @override
  bool shouldRepaint(_PlanPortPairPainter old) =>
      source != old.source ||
      target != old.target ||
      camera != old.camera ||
      viewport != old.viewport ||
      scheme != old.scheme;
}
