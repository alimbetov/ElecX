import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/adaptive_grid.dart';
import '../../engine/render_policy.dart';
import '../../engine/spatial_scene_index.dart';
import '../../engine/world_camera.dart';
import 'editor_controller.dart';

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
  int _sceneFingerprint = -1;
  Size _lastSize = Size.zero;
  Offset? _panAnchor;
  WorldCamera? _touchStartCamera;
  Offset? _touchStartFocal;

  EditorController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _sceneIndex = SpatialSceneIndex();
    _rebuildIndex(force: true);
  }

  @override
  void didUpdateWidget(covariant SpatialCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _rebuildIndex(force: true);
    }
  }

  int _computeSceneFingerprint() => Object.hashAll(
        controller.level.spaces.map((space) {
          final bounds = space.boundary.bounds;
          return Object.hash(
            space.id,
            bounds.left,
            bounds.bottom,
            bounds.right,
            bounds.top,
            space.boundary.vertices.length,
          );
        }),
      );

  void _rebuildIndex({bool force = false}) {
    final fingerprint = _computeSceneFingerprint();
    if (!force && fingerprint == _sceneFingerprint) {
      return;
    }
    _sceneIndex.rebuildSpaces(controller.level.spaces);
    _sceneFingerprint = fingerprint;
  }

  void _fitLevel() {
    if (_lastSize.isEmpty || controller.level.spaces.isEmpty) {
      return;
    }
    var bounds = controller.level.spaces.first.boundary.bounds;
    for (final space in controller.level.spaces.skip(1)) {
      bounds = bounds.union(space.boundary.bounds);
    }
    setState(() {
      _camera = _camera.fitBounds(
        bounds: bounds,
        viewportWidthPx: _lastSize.width,
        viewportHeightPx: _lastSize.height,
      );
    });
  }

  void _fitSelection() {
    final space = controller.selectedSpace;
    if (space == null || _lastSize.isEmpty) {
      return;
    }
    setState(() {
      _camera = _camera.fitBounds(
        bounds: space.boundary.bounds,
        viewportWidthPx: _lastSize.width,
        viewportHeightPx: _lastSize.height,
      );
    });
  }

  void _zoomAt(Offset cursor, double factor) {
    if (_lastSize.isEmpty) {
      return;
    }
    setState(() {
      _camera = _camera.zoomAt(
        factor: factor,
        viewportWidthPx: _lastSize.width,
        viewportHeightPx: _lastSize.height,
        cursorXpx: cursor.dx,
        cursorYpx: cursor.dy,
      );
    });
  }

  void _startTouchGesture(ScaleStartDetails details) {
    _touchStartCamera = _camera;
    _touchStartFocal = details.localFocalPoint;
  }

  void _updateTouchGesture(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || _lastSize.isEmpty) {
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
      viewportWidthPx: _lastSize.width,
      viewportHeightPx: _lastSize.height,
      cursorXpx: details.localFocalPoint.dx,
      cursorYpx: details.localFocalPoint.dy,
    );
    setState(() => _camera = next);
  }

  void _endTouchGesture(ScaleEndDetails details) {
    _touchStartCamera = null;
    _touchStartFocal = null;
  }

  MmPoint _toWorld(Offset local) => _camera.screenToWorld(
        viewportWidthPx: _lastSize.width,
        viewportHeightPx: _lastSize.height,
        xPx: local.dx,
        yPx: local.dy,
      );

  @override
  Widget build(BuildContext context) {
    _rebuildIndex();
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
        final visibleBounds = _camera.visibleWorldBounds(
          viewportWidthPx: _lastSize.width,
          viewportHeightPx: _lastSize.height,
        );
        final visibleSpaces = _sceneIndex.visibleSpaces(visibleBounds);
        final lod = RenderPolicy.lodForWorldUnitsPerPixel(_camera.mmPerPixel);
        final compactControls = MediaQuery.sizeOf(context).width < 700;

        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _GridPainter(camera: _camera, lod: lod),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ArchitecturePainter(
                    controller: controller,
                    camera: _camera,
                    visibleSpaces: visibleSpaces,
                    lod: lod,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Listener(
                onPointerSignal: (event) {
                  if (event is! PointerScrollEvent) {
                    return;
                  }
                  _zoomAt(
                    event.localPosition,
                    event.scrollDelta.dy < 0 ? 1.18 : 1 / 1.18,
                  );
                },
                onPointerDown: (event) {
                  if (event.buttons == kMiddleMouseButton) {
                    _panAnchor = event.localPosition;
                  }
                },
                onPointerMove: (event) {
                  final anchor = _panAnchor;
                  if (anchor == null) {
                    return;
                  }
                  final delta = event.localPosition - anchor;
                  _panAnchor = event.localPosition;
                  setState(
                    () => _camera = _camera.panPixels(delta.dx, delta.dy),
                  );
                },
                onPointerUp: (_) => _panAnchor = null,
                onPointerCancel: (_) => _panAnchor = null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) =>
                      controller.canvasTap(_toWorld(details.localPosition)),
                  onScaleStart: _startTouchGesture,
                  onScaleUpdate: _updateTouchGesture,
                  onScaleEnd: _endTouchGesture,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _InteractionPainter(
                        controller: controller,
                        camera: _camera,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: compactControls ? 8 : 12,
              top: compactControls ? 8 : 12,
              child: _ViewportControls(
                compact: compactControls,
                lod: lod,
                mmPerPixel: _camera.mmPerPixel,
                onFitLevel: _fitLevel,
                onFitSelection: _fitSelection,
                onZoomIn: () =>
                    _zoomAt(_lastSize.center(Offset.zero), 1.25),
                onZoomOut: () =>
                    _zoomAt(_lastSize.center(Offset.zero), 0.8),
              ),
            ),
          ],
        );
      },
    );
  }
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
      Tooltip(
        message: 'Вписать этаж',
        child: IconButton(
          onPressed: onFitLevel,
          icon: const Icon(Icons.fit_screen),
        ),
      ),
      Tooltip(
        message: 'Вписать выбранное помещение',
        child: IconButton(
          onPressed: onFitSelection,
          icon: const Icon(Icons.center_focus_strong),
        ),
      ),
      IconButton(onPressed: onZoomOut, icon: const Icon(Icons.zoom_out)),
      IconButton(onPressed: onZoomIn, icon: const Icon(Icons.zoom_in)),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: compact
            ? Column(mainAxisSize: MainAxisSize.min, children: buttons)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...buttons,
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 8),
                    child: Text(
                      '${lod.name} · ${mmPerPixel.toStringAsFixed(1)} mm/px',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

abstract class _CameraPainter extends CustomPainter {
  _CameraPainter(this.camera);

  final WorldCamera camera;

  Offset p(MmPoint point, Size size) {
    final screen = camera.worldToScreen(
      viewportWidthPx: size.width,
      viewportHeightPx: size.height,
      point: point,
    );
    return Offset(screen.x, screen.y);
  }
}

class _GridPainter extends _CameraPainter {
  _GridPainter({required WorldCamera camera, required this.lod}) : super(camera);

  final RenderLod lod;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F8FA),
    );
    final visible = camera.visibleWorldBounds(
      viewportWidthPx: size.width,
      viewportHeightPx: size.height,
      overscanPx: 0,
    );
    final grid = AdaptiveGridPolicy.forScale(camera.mmPerPixel);
    final startX =
        (visible.left / grid.minorStepMm).floor() * grid.minorStepMm;
    final startY =
        (visible.bottom / grid.minorStepMm).floor() * grid.minorStepMm;
    final minor = Paint()
      ..color = const Color(0xFFE7E9ED)
      ..strokeWidth = 0.65;
    final major = Paint()
      ..color = const Color(0xFFCCD2DA)
      ..strokeWidth = 0.9;

    for (var x = startX; x <= visible.right; x += grid.minorStepMm) {
      final isMajor = x % grid.majorStepMm == 0;
      if (!isMajor &&
          (!grid.showMinor || lod.index < RenderLod.room.index)) {
        continue;
      }
      canvas.drawLine(
        p(MmPoint(x, visible.bottom), size),
        p(MmPoint(x, visible.top), size),
        isMajor ? major : minor,
      );
    }
    for (var y = startY; y <= visible.top; y += grid.minorStepMm) {
      final isMajor = y % grid.majorStepMm == 0;
      if (!isMajor &&
          (!grid.showMinor || lod.index < RenderLod.room.index)) {
        continue;
      }
      canvas.drawLine(
        p(MmPoint(visible.left, y), size),
        p(MmPoint(visible.right, y), size),
        isMajor ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.camera != camera || oldDelegate.lod != lod;
}

class _ArchitecturePainter extends _CameraPainter {
  _ArchitecturePainter({
    required EditorController controller,
    required WorldCamera camera,
    required this.visibleSpaces,
    required this.lod,
  })  : selectedSpaceId = controller.selectedSpaceId,
        dimensionsVisible = controller.dimensionsVisible,
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
        super(camera);

  final List<EngineeringSpace> visibleSpaces;
  final RenderLod lod;
  final String? selectedSpaceId;
  final bool dimensionsVisible;
  final List<ArchitecturalOpening> openings;
  final int openingFingerprint;

  @override
  void paint(Canvas canvas, Size size) {
    for (final space in visibleSpaces) {
      _drawSpace(
        canvas,
        size,
        space,
        selected: space.id == selectedSpaceId,
      );
    }
  }

  void _drawSpace(
    Canvas canvas,
    Size size,
    EngineeringSpace space, {
    required bool selected,
  }) {
    final path = Path();
    final first = p(space.boundary.vertices.first, size);
    path.moveTo(first.dx, first.dy);
    for (final vertex in space.boundary.vertices.skip(1)) {
      final point = p(vertex, size);
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? const Color(0x1F246DB3)
            : const Color(0x0D263238),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.4 : 1.3
        ..color = selected
            ? const Color(0xFF246DB3)
            : const Color(0xFF53606D),
    );

    if (RenderPolicy.showOpenings(lod)) {
      _drawOpenings(canvas, size, space);
    }
    if (RenderPolicy.showRoomLabels(lod)) {
      _drawLabel(canvas, size, space);
    }
    if (selected &&
        RenderPolicy.showFineDimensions(lod) &&
        dimensionsVisible) {
      _drawDimensions(canvas, size, space);
    }
  }

  void _drawOpenings(Canvas canvas, Size size, EngineeringSpace space) {
    final walls = RoomSurfaceResolver.walls(space);
    for (final opening in openings) {
      if (opening.hostWall.spaceId != space.id ||
          opening.hostWall.wallIndex == null) {
        continue;
      }
      final index = opening.hostWall.wallIndex!;
      if (index < 0 || index >= walls.length) {
        continue;
      }
      final wall = walls[index];
      final a = p(
        RoomSurfaceResolver.wallLocalToPlan(
          wall,
          opening.offsetFromStartMm,
        ),
        size,
      );
      final b = p(
        RoomSurfaceResolver.wallLocalToPlan(
          wall,
          opening.offsetFromStartMm + opening.widthMm,
        ),
        size,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFF4C89A8)
          ..strokeWidth = 2.0,
      );
    }
  }

  void _drawLabel(Canvas canvas, Size size, EngineeringSpace space) {
    final center = p(space.boundary.bounds.center, size);
    final painter = TextPainter(
      text: TextSpan(
        text: space.name,
        style: const TextStyle(
          color: Color(0xFF263238),
          fontSize: 12,
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

  void _drawDimensions(Canvas canvas, Size size, EngineeringSpace space) {
    final bounds = space.boundary.bounds;
    final a = p(MmPoint(bounds.left, bounds.bottom), size);
    final b = p(MmPoint(bounds.right, bounds.bottom), size);
    final c = p(MmPoint(bounds.right, bounds.top), size);
    final paint = Paint()
      ..color = const Color(0xFF4B5563)
      ..strokeWidth = 0.9;
    final y = math.max(a.dy, b.dy) + 24;
    canvas.drawLine(Offset(a.dx, y), Offset(b.dx, y), paint);
    _text(
      canvas,
      '${bounds.width} mm',
      Offset((a.dx + b.dx) / 2, y - 8),
    );
    final x = c.dx + 26;
    canvas.drawLine(Offset(x, c.dy), Offset(x, b.dy), paint);
    _text(
      canvas,
      '${bounds.height} mm',
      Offset(x + 6, (c.dy + b.dy) / 2),
      centered: false,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    bool centered = true,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centered ? at - Offset(painter.width / 2, painter.height / 2) : at,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchitecturePainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.lod != lod ||
      oldDelegate.visibleSpaces != visibleSpaces ||
      oldDelegate.selectedSpaceId != selectedSpaceId ||
      oldDelegate.dimensionsVisible != dimensionsVisible ||
      oldDelegate.openingFingerprint != openingFingerprint;
}

class _InteractionPainter extends _CameraPainter {
  _InteractionPainter({
    required EditorController controller,
    required WorldCamera camera,
  })  : draftStart = controller.draftStart,
        super(camera);

  final MmPoint? draftStart;

  @override
  void paint(Canvas canvas, Size size) {
    final draft = draftStart;
    if (draft == null) {
      return;
    }
    canvas.drawCircle(
      p(draft, size),
      5,
      Paint()..color = const Color(0xFFD66B2C),
    );
  }

  @override
  bool shouldRepaint(covariant _InteractionPainter oldDelegate) =>
      oldDelegate.camera != camera || oldDelegate.draftStart != draftStart;
}
