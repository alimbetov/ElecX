import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/adaptive_grid.dart';
import '../../engine/plan_geometry_editing.dart';
import '../../engine/render_policy.dart';
import '../../engine/spatial_scene_index.dart';
import '../../engine/world_camera.dart';
import 'editor_controller.dart';
import 'editor_viewport_commands.dart';
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

  EditorController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _sceneIndex = SpatialSceneIndex();
    _lastViewportRevision = controller.viewportCommandRevision;
    controller.viewportCommandListenable.addListener(_onViewportCommand);
    _rebuildIndex(force: true);
  }

  @override
  void didUpdateWidget(covariant SpatialCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.viewportCommandListenable
          .removeListener(_onViewportCommand);
      _lastViewportRevision = controller.viewportCommandRevision;
      controller.viewportCommandListenable.addListener(_onViewportCommand);
      _rebuildIndex(force: true);
    }
  }

  @override
  void dispose() {
    controller.viewportCommandListenable.removeListener(_onViewportCommand);
    super.dispose();
  }

  void _onViewportCommand() {
    if (mounted) setState(() {});
  }

  int _fingerprint() => Object.hashAll(
        controller.level.spaces.map((space) {
          final b = space.boundary.bounds;
          return Object.hash(
            space.id,
            b.left,
            b.bottom,
            b.right,
            b.top,
            Object.hashAll(space.boundary.vertices),
          );
        }),
      );

  void _rebuildIndex({bool force = false}) {
    final next = _fingerprint();
    if (!force && next == _sceneFingerprint) return;
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
    if (_size.isEmpty || controller.level.spaces.isEmpty) return _camera;
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

  void _fitLevel() => setState(() => _camera = _fitLevelCamera());

  void _fitSelection() {
    final space = controller.selectedSpace;
    if (space == null || _size.isEmpty) return;
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
    if (_size.isEmpty || revision == _lastViewportRevision) return;
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
    if (details.pointerCount < 2 || _size.isEmpty) return;
    final startCamera = _touchStartCamera;
    final startFocal = _touchStartFocal;
    if (startCamera == null || startFocal == null) return;
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

  int? _vertexHandleAt(Offset local) {
    final space = controller.selectedSpace;
    if (space == null || controller.tool != EditorTool.select) return null;
    for (var i = 0; i < space.boundary.vertices.length; i++) {
      if ((_toScreen(space.boundary.vertices[i]) - local).distance <= 11) {
        return i;
      }
    }
    return null;
  }

  int? _edgeHandleAt(Offset local) {
    final space = controller.selectedSpace;
    if (space == null || controller.tool != EditorTool.select) return null;
    final vertices = space.boundary.vertices;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      final midpoint = MmPoint((a.x + b.x) ~/ 2, (a.y + b.y) ~/ 2);
      if ((_toScreen(midpoint) - local).distance <= 11) return i;
    }
    return null;
  }

  _PlanDragKind? _openingHandleAt(Offset local) {
    final opening = controller.selectedOpening;
    final wall = controller.activeWall;
    if (opening == null || wall == null || controller.tool != EditorTool.select) {
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
    if ((_toScreen(start) - local).distance <= 11) return _PlanDragKind.openingStart;
    if ((_toScreen(end) - local).distance <= 11) return _PlanDragKind.openingEnd;
    if ((_toScreen(center) - local).distance <= 13) return _PlanDragKind.openingMove;
    return null;
  }

  void _beginPrimaryDrag(PointerDownEvent event) {
    if (controller.tool != EditorTool.select) return;

    final openingHandle = _openingHandleAt(event.localPosition);
    if (openingHandle != null) {
      _dragKind = openingHandle;
      _dragBaseOpening = controller.selectedOpening;
      _previewOpening = _dragBaseOpening;
      return;
    }

    final vertex = _vertexHandleAt(event.localPosition);
    if (vertex != null) {
      _dragKind = _PlanDragKind.vertex;
      _dragIndex = vertex;
      _dragBaseBoundary = controller.selectedSpace?.boundary;
      _previewBoundary = _dragBaseBoundary;
      return;
    }

    final edge = _edgeHandleAt(event.localPosition);
    if (edge != null) {
      _dragKind = _PlanDragKind.edge;
      _dragIndex = edge;
      _dragStartWorld = _toWorld(event.localPosition);
      _dragBaseBoundary = controller.selectedSpace?.boundary;
      _previewBoundary = _dragBaseBoundary;
      return;
    }

    final world = _toWorld(event.localPosition);
    final opening = controller.openingAtPlanPoint(world, radiusMm: _hitRadiusMm);
    if (opening != null) {
      controller.selectOpeningForPlan(opening);
      _dragKind = _PlanDragKind.openingMove;
      _dragBaseOpening = opening;
      _previewOpening = opening;
    }
  }

  void _updatePrimaryDrag(PointerMoveEvent event) {
    final kind = _dragKind;
    if (kind == null || event.buttons != kPrimaryMouseButton) return;
    final raw = _toWorld(event.localPosition);

    switch (kind) {
      case _PlanDragKind.vertex:
        final base = _dragBaseBoundary;
        final index = _dragIndex;
        if (base == null || index == null) return;
        final target = controller.snap(
          raw,
          acquisitionRadiusMm: math.max(40, _camera.mmPerPixel * 12),
        );
        final candidate = PlanGeometryEditing.moveVertex(
          boundary: base,
          vertexIndex: index,
          target: target,
        );
        if (candidate != null) setState(() => _previewBoundary = candidate);
      case _PlanDragKind.edge:
        final base = _dragBaseBoundary;
        final index = _dragIndex;
        final start = _dragStartWorld;
        if (base == null || index == null || start == null) return;
        final target = controller.snap(
          raw,
          acquisitionRadiusMm: math.max(40, _camera.mmPerPixel * 12),
        );
        final candidate = PlanGeometryEditing.moveEdge(
          boundary: base,
          edgeIndex: index,
          dragStart: start,
          dragCurrent: target,
        );
        if (candidate != null) setState(() => _previewBoundary = candidate);
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
    if (base == null || wall == null || offset == null) return;

    ArchitecturalOpening? candidate;
    try {
      switch (kind) {
        case _PlanDragKind.openingMove:
          candidate = base.copyWith(
            offsetFromStartMm: offset - base.widthMm ~/ 2,
          );
        case _PlanDragKind.openingStart:
          final end = base.offsetFromStartMm + base.widthMm;
          final width = end - offset;
          if (width < 300) return;
          candidate = base.copyWith(offsetFromStartMm: offset, widthMm: width);
        case _PlanDragKind.openingEnd:
          final width = offset - base.offsetFromStartMm;
          if (width < 300) return;
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
    if (kind == null) return;
    if (!cancelled) {
      if ((kind == _PlanDragKind.vertex || kind == _PlanDragKind.edge) &&
          _previewBoundary != null) {
        controller.commitSelectedBoundary(_previewBoundary!);
        _rebuildIndex(force: true);
      } else if (_previewOpening case final opening?) {
        controller.updateSelectedOpening(
          offsetFromStartMm: opening.offsetFromStartMm,
          widthMm: opening.widthMm,
        );
        controller.viewMode = EditorViewMode.plan;
      }
    }
    setState(() {
      _dragKind = null;
      _dragIndex = null;
      _dragStartWorld = null;
      _dragBaseBoundary = null;
      _previewBoundary = null;
      _dragBaseOpening = null;
      _previewOpening = null;
    });
  }

  void _tap(TapUpDetails details) {
    if (_dragKind != null) return;
    final world = _toWorld(details.localPosition);
    if (controller.tool == EditorTool.select) {
      final opening = controller.openingAtPlanPoint(world, radiusMm: _hitRadiusMm);
      if (opening != null) {
        controller.selectOpeningForPlan(opening);
        return;
      }
    }
    controller.canvasTap(
      world,
      snapRadiusMm: math.max(40, _camera.mmPerPixel * 12),
    );
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

        return Stack(
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
                    scheme: scheme,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _zoomAt(
                      event.localPosition,
                      event.scrollDelta.dy < 0 ? 1.18 : 1 / 1.18,
                    );
                  }
                },
                onPointerDown: (event) {
                  if (event.buttons == kMiddleMouseButton) {
                    _panAnchor = event.localPosition;
                    return;
                  }
                  if (event.buttons == kPrimaryMouseButton) {
                    _beginPrimaryDrag(event);
                  }
                },
                onPointerMove: (event) {
                  final anchor = _panAnchor;
                  if (anchor != null) {
                    final delta = event.localPosition - anchor;
                    _panAnchor = event.localPosition;
                    setState(() {
                      _camera = _camera.panPixels(delta.dx, delta.dy);
                    });
                    return;
                  }
                  _updatePrimaryDrag(event);
                },
                onPointerUp: (_) {
                  _panAnchor = null;
                  _finishPrimaryDrag(cancelled: false);
                },
                onPointerCancel: (_) {
                  _panAnchor = null;
                  _finishPrimaryDrag(cancelled: true);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _tap,
                  onScaleStart: _startTouch,
                  onScaleUpdate: _updateTouch,
                  onScaleEnd: _endTouch,
                ),
              ),
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
            if (controller.tool == EditorTool.select && controller.selectedSpace != null)
              Positioned(
                left: 10,
                bottom: 10,
                child: Chip(
                  avatar: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Select: drag ● vertex / ■ wall / opening handles'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
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
            (space) => Object.hash(space.id, Object.hashAll(space.boundary.vertices)),
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
  final ColorScheme scheme;
  final int openingFingerprint;
  final int sceneFingerprint;

  Offset p(MmPoint point, Size size) {
    final s = camera.worldToScreen(
      viewportWidthPx: size.width,
      viewportHeightPx: size.height,
      point: point,
    );
    return Offset(s.x, s.y);
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
    final startY = (visible.bottom / grid.minorStepMm).floor() * grid.minorStepMm;
    final minor = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 0.6;
    final major = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.7)
      ..strokeWidth = 0.9;
    for (var x = startX; x <= visible.right; x += grid.minorStepMm) {
      final majorLine = x % grid.majorStepMm == 0;
      if (!majorLine && !grid.showMinor) continue;
      canvas.drawLine(
        p(MmPoint(x, visible.bottom), size),
        p(MmPoint(x, visible.top), size),
        majorLine ? major : minor,
      );
    }
    for (var y = startY; y <= visible.top; y += grid.minorStepMm) {
      final majorLine = y % grid.majorStepMm == 0;
      if (!majorLine && !grid.showMinor) continue;
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
      Paint()..color = selected ? scheme.primary.withValues(alpha: 0.08) : scheme.onSurface.withValues(alpha: 0.025),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.2 : 1.25
        ..color = selected ? scheme.primary : scheme.outline,
    );

    _drawOpenings(canvas, size, space, boundary);
    if (RenderPolicy.showRoomLabels(lod)) _drawLabel(canvas, size, space, boundary);
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
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      canvas.drawRect(
        Rect.fromCenter(center: mid, width: 9, height: 9),
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
    final projectedSpace = boundary == space.boundary
        ? space
        : space.copyWith(boundary: boundary);
    final walls = RoomSurfaceResolver.walls(projectedSpace);
    for (final source in openings) {
      if (source.hostWall.spaceId != space.id || source.hostWall.wallIndex == null) {
        continue;
      }
      final index = source.hostWall.wallIndex!;
      if (index < 0 || index >= walls.length) continue;
      final opening = previewOpening?.id == source.id ? previewOpening! : source;
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
    final tp = TextPainter(
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
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawDimensions(Canvas canvas, Size size, MmPolygon boundary) {
    final b = boundary.bounds;
    final bl = p(MmPoint(b.left, b.bottom), size);
    final br = p(MmPoint(b.right, b.bottom), size);
    final tr = p(MmPoint(b.right, b.top), size);
    final paint = Paint()
      ..color = scheme.outline
      ..strokeWidth = 0.8;
    final y = math.max(bl.dy, br.dy) + 22;
    canvas.drawLine(Offset(bl.dx, y), Offset(br.dx, y), paint);
    _text(canvas, '${b.width} mm', Offset((bl.dx + br.dx) / 2, y - 8));
    final x = tr.dx + 24;
    canvas.drawLine(Offset(x, tr.dy), Offset(x, br.dy), paint);
    _text(canvas, '${b.height} mm', Offset(x + 5, (tr.dy + br.dy) / 2));
  }

  void _text(Canvas canvas, String value, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: value, style: TextStyle(fontSize: 10, color: scheme.outline)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
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
      IconButton(onPressed: onZoomOut, icon: const Icon(Icons.zoom_out)),
      IconButton(onPressed: onZoomIn, icon: const Icon(Icons.zoom_in)),
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
