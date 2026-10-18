import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/geometry.dart';
import '../../domain/surface_navigation.dart';
import '../../domain/surfaces.dart';
import '../../engine/adaptive_grid.dart';
import '../../engine/editor_layers.dart';
import '../../engine/render_policy.dart';
import '../../engine/selection_engine.dart';
import '../../engine/snap_engine.dart';
import '../../engine/world_camera.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'editor_viewport_commands.dart';
import 'wall_profile_editor_actions.dart';

class SurfaceCanvas extends StatefulWidget {
  const SurfaceCanvas({required this.controller, super.key});

  final EditorController controller;

  @override
  State<SurfaceCanvas> createState() => _SurfaceCanvasState();
}

class _SurfaceCanvasState extends State<SurfaceCanvas> {
  WorldCamera? _camera;
  String? _surfaceId;
  Offset? _panAnchor;
  WorldCamera? _touchStartCamera;
  Offset? _touchStartFocal;
  String? _dragComponentId;
  int _lastViewportRevision = 0;
  Size _size = Size.zero;

  EditorController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _lastViewportRevision = controller.viewportCommandRevision;
    controller.viewportCommandListenable.addListener(_onViewportCommand);
    controller.p2.addListener(_onP2Changed);
  }

  @override
  void didUpdateWidget(covariant SurfaceCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.viewportCommandListenable
          .removeListener(_onViewportCommand);
      oldWidget.controller.p2.removeListener(_onP2Changed);
      _lastViewportRevision = controller.viewportCommandRevision;
      controller.viewportCommandListenable.addListener(_onViewportCommand);
      controller.p2.addListener(_onP2Changed);
    }
  }

  @override
  void dispose() {
    controller.viewportCommandListenable.removeListener(_onViewportCommand);
    controller.p2.removeListener(_onP2Changed);
    super.dispose();
  }

  void _onViewportCommand() {
    if (mounted) setState(() {});
  }

  void _onP2Changed() {
    if (mounted) setState(() {});
  }

  WorldCamera _fittedCamera(_SurfaceExtent extent) {
    final base = _camera ??
        const WorldCamera(centerMm: MmPoint(0, 0), mmPerPixel: 10);
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
    controller.p2.updateSnap(null);
  }

  WorldCamera _zoomedCamera(Offset cursor, double factor) {
    final camera = _camera;
    if (camera == null || _size.isEmpty) {
      return camera ??
          const WorldCamera(centerMm: MmPoint(0, 0), mmPerPixel: 10);
    }
    return camera.zoomAt(
      factor: factor,
      viewportWidthPx: _size.width,
      viewportHeightPx: _size.height,
      cursorXpx: cursor.dx,
      cursorYpx: cursor.dy,
    );
  }

  void _zoomAt(Offset cursor, double factor) {
    setState(() => _camera = _zoomedCamera(cursor, factor));
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
        _camera = _zoomedCamera(center, 1.25);
      case EditorViewportCommand.zoomOut:
        _camera = _zoomedCamera(center, 0.8);
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
    next = next.zoomAt(
      factor: details.scale,
      viewportWidthPx: _size.width,
      viewportHeightPx: _size.height,
      cursorXpx: details.localFocalPoint.dx,
      cursorYpx: details.localFocalPoint.dy,
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
      acquisitionRadiusMm: math.max(20, projection.camera.mmPerPixel * 14),
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
            a: MmPoint(
              profile.vertices[i].xMm,
              profile.vertices[i].yMm,
            ),
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

  ElectricalComponentPlacement? _componentAt(
    SurfacePointMm point,
    _SurfaceProjection projection,
  ) {
    if (!controller.p2.layers.isVisible(EditorLayerId.electrical)) return null;
    final surface = controller.activeSurface;
    if (surface == null) return null;
    final radiusMm = math.max(80, projection.camera.mmPerPixel * 18);
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

  void _handleTap(
    TapUpDetails details,
    _SurfaceProjection projection,
    RoomSurfaceRef surface,
    List<MmPoint> roomVertices,
  ) {
    final raw = projection.viewportToSurface(details.localPosition);
    if (raw == null) return;
    final point = _snapSurfacePoint(raw, projection);
    if (!_pointIsUsable(point, projection)) return;

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
      final component = _componentAt(point, projection);
      if (component != null) {
        controller.p2.select(component.id);
        return;
      }
      controller.p2.clearSelection();
    }

    if (surface.type == SurfacePlaneType.wall) {
      final hit = projection.wallEdgeHit(
        details.localPosition,
        thresholdPx: 20,
      );
      if (hit != null) {
        controller.navigateWallEdge(hit.edge, hit.point);
        return;
      }
    } else {
      final hit = projection.horizontalBoundaryHit(
        roomVertices,
        details.localPosition,
        thresholdPx: 20,
      );
      if (hit != null) {
        controller.navigateHorizontalBoundary(hit.edgeIndex, hit.point);
        return;
      }
    }
    controller.surfaceTap(point);
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

        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SurfacePainter(controller, projection, lod),
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
                  if (event.buttons == kPrimaryMouseButton &&
                      controller.tool == EditorTool.select &&
                      controller.p2.placementType == null) {
                    final raw = projection.viewportToSurface(event.localPosition);
                    if (raw == null) return;
                    final component = _componentAt(raw, projection);
                    if (component != null) {
                      controller.p2.select(component.id);
                      _dragComponentId = component.id;
                    }
                  }
                },
                onPointerMove: (event) {
                  final anchor = _panAnchor;
                  if (anchor != null) {
                    final delta = event.localPosition - anchor;
                    _panAnchor = event.localPosition;
                    setState(() {
                      _camera = _camera!.panPixels(delta.dx, delta.dy);
                    });
                    return;
                  }
                  if (_dragComponentId != null &&
                      event.buttons == kPrimaryMouseButton) {
                    final raw = projection.viewportToSurface(event.localPosition);
                    if (raw == null) return;
                    final point = _snapSurfacePoint(raw, projection);
                    if (_pointIsUsable(point, projection)) {
                      controller.p2.moveSelectedComponent(point);
                    }
                  }
                },
                onPointerUp: (_) {
                  _panAnchor = null;
                  _dragComponentId = null;
                  controller.p2.updateSnap(null);
                },
                onPointerCancel: (_) {
                  _panAnchor = null;
                  _dragComponentId = null;
                  controller.p2.updateSnap(null);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleTap(
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
            if (surface.type == SurfacePlaneType.wall)
              Positioned(
                left: compact ? 8 : 12,
                top: compact ? 8 : 12,
                child: _WallProfileQuickEditor(
                  controller: controller,
                  compact: compact,
                ),
              ),
            Positioned(
              right: compact ? 8 : 12,
              top: compact ? 8 : 12,
              child: _ViewportBadge(lod: lod, mmPerPixel: camera.mmPerPixel),
            ),
            if (controller.p2.placementType case final type?)
              Positioned(
                left: 12,
                bottom: 12,
                child: Chip(
                  avatar: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: Text(
                    'Размещение: ${ElectricalComponentDefaults.defaultLabel(type)}',
                  ),
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
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text('${lod.name} · ${mmPerPixel.toStringAsFixed(1)} mm/px'),
        ),
      );
}

class _WallProfileQuickEditor extends StatelessWidget {
  const _WallProfileQuickEditor({
    required this.controller,
    required this.compact,
  });

  final EditorController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Добавить балку / верхнюю выемку',
              child: compact
                  ? IconButton(
                      onPressed: () => _showNotchDialog(context),
                      icon: const Icon(Icons.architecture_outlined),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () => _showNotchDialog(context),
                      icon: const Icon(Icons.architecture_outlined, size: 18),
                      label: const Text('Балка / выемка'),
                    ),
            ),
            if (controller.activeWallHasCustomProfile)
              IconButton(
                onPressed: controller.resetActiveWallProfile,
                tooltip: 'Сбросить профиль стены',
                icon: const Icon(Icons.restart_alt),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotchDialog(BuildContext context) async {
    final wall = controller.activeWall;
    if (wall == null) return;
    final wallLength = wall.lengthMm.round();
    final wallHeight = wall.heightMm;
    var widthMm = math.min(600, math.max(100, wallLength ~/ 3));
    var startMm = math.max(0, (wallLength - widthMm) ~/ 2);
    var depthMm = math.min(300, math.max(50, wallHeight ~/ 6));
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Балка / верхняя выемка'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Стена: $wallLength × $wallHeight mm',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _ProfileIntField(
                    label: 'X от начала стены',
                    value: startMm,
                    onChanged: (value) => startMm = value,
                  ),
                  const SizedBox(height: 10),
                  _ProfileIntField(
                    label: 'Ширина балки / выемки',
                    value: widthMm,
                    onChanged: (value) => widthMm = value,
                  ),
                  const SizedBox(height: 10),
                  _ProfileIntField(
                    label: 'Глубина вниз от потолка',
                    value: depthMm,
                    onChanged: (value) => depthMm = value,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final applied = controller.addActiveWallTopNotch(
                  startMm: startMm,
                  widthMm: widthMm,
                  depthMm: depthMm,
                );
                if (applied) {
                  Navigator.pop(dialogContext);
                } else {
                  setDialogState(() {
                    error = 'Параметры конфликтуют со стеной или проёмами.';
                  });
                }
              },
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileIntField extends StatelessWidget {
  const _ProfileIntField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'mm',
          border: const OutlineInputBorder(),
        ),
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null) onChanged(parsed);
        },
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
    final entry =
        distances.entries.reduce((a, b) => a.value <= b.value ? a : b);
    if (entry.value > thresholdMm) return null;
    final point = switch (entry.key) {
      WallNavigationEdge.start => SurfacePointMm(0, local.yMm),
      WallNavigationEdge.end => SurfacePointMm(extent.widthMm, local.yMm),
      WallNavigationEdge.floor => SurfacePointMm(local.xMm, 0),
      WallNavigationEdge.ceiling =>
        SurfacePointMm(local.xMm, extent.heightMm),
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
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared)
        .clamp(0.0, 1.0);
    return a + ab * t;
  }
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter(this.controller, this.projection, this.lod)
      : activeSurfaceId = controller.activeSurface?.id,
        selectedSpaceId = controller.selectedSpaceId,
        dimensionsVisible = controller.dimensionsVisible &&
            controller.p2.layers.isVisible(EditorLayerId.dimensions),
        openingsVisible = controller.p2.layers.isVisible(EditorLayerId.openings),
        electricalVisible =
            controller.p2.layers.isVisible(EditorLayerId.electrical),
        cableRoutesVisible =
            controller.p2.layers.isVisible(EditorLayerId.cableRoutes),
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
            (route) => route.segments.expand(
              (segment) => <Object?>[
                segment.surface.id,
                ...segment.points.expand(
                  (point) => <Object?>[point.xMm, point.yMm],
                ),
              ],
            ),
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
        );

  final EditorController controller;
  final _SurfaceProjection projection;
  final RenderLod lod;
  final String? activeSurfaceId;
  final String? selectedSpaceId;
  final bool dimensionsVisible;
  final bool openingsVisible;
  final bool electricalVisible;
  final bool cableRoutesVisible;
  final int openingsFingerprint;
  final int routeFingerprint;
  final int componentsFingerprint;
  final int selectionFingerprint;
  final int snapFingerprint;
  final int profileFingerprint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F8FA),
    );
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
    canvas.drawPath(wallPath, Paint()..color = Colors.white);
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
        ..strokeWidth = 2
        ..color = const Color(0xFF263238),
    );
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

  void _drawHorizontalSurface(Canvas canvas, SurfacePlaneType type) {
    final space = controller.selectedSpace!;
    final path = Path();
    final first = projection.floorPointToViewport(space.boundary.vertices.first);
    path.moveTo(first.dx, first.dy);
    for (final vertex in space.boundary.vertices.skip(1)) {
      final point = projection.floorPointToViewport(vertex);
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
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
        ..strokeWidth = 2
        ..color = const Color(0xFF263238),
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
      ..color = const Color(0xFFE8EBEF)
      ..strokeWidth = 0.7;
    final major = Paint()
      ..color = const Color(0xFFCDD3DB)
      ..strokeWidth = 1.0;
    for (var x = 0;
        x <= projection.extent.widthMm;
        x += spec.minorStepMm) {
      final isMajor = x % spec.majorStepMm == 0;
      if (!isMajor &&
          (!spec.showMinor || lod.index < RenderLod.room.index)) {
        continue;
      }
      final point = projection.surfaceToViewport(SurfacePointMm(x, 0));
      canvas.drawLine(
        Offset(point.dx, rect.top),
        Offset(point.dx, rect.bottom),
        isMajor ? major : minor,
      );
    }
    for (var y = 0;
        y <= projection.extent.heightMm;
        y += spec.minorStepMm) {
      final isMajor = y % spec.majorStepMm == 0;
      if (!isMajor &&
          (!spec.showMinor || lod.index < RenderLod.room.index)) {
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
    final fill = opening.type == ArchitecturalOpeningType.door
        ? const Color(0xFFEDE4D3)
        : const Color(0xFFDDEFF7);
    canvas.drawRect(rect, Paint()..color = fill);
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF54606B),
    );
  }

  void _drawRoutes(Canvas canvas) {
    if (!cableRoutesVisible) return;
    final paint = Paint()
      ..color = const Color(0xFFD66B2C)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final draft = controller.activeRouteSegment;
    if (draft != null) _drawRoutePoints(canvas, draft.points, paint);
    final activeSurface = controller.activeSurface;
    for (final route in controller.p2.routes) {
      for (final segment in route.segments) {
        if (segment.surface == activeSurface) {
          _drawRoutePoints(canvas, segment.points, paint);
        }
      }
    }
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
      canvas.drawCircle(current, 4.2, paint);
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
          ..color = const Color(0xFF1565C0),
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
      ..color = selected ? const Color(0xFF1565C0) : const Color(0xFF263238);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = selected ? const Color(0x221565C0) : Colors.white;
    canvas.drawCircle(center, selected ? 11 : 9, fill);
    switch (type) {
      case ElectricalComponentType.socketOutlet:
        canvas.drawCircle(center, 8, stroke);
        canvas.drawLine(center + const Offset(-4, 0), center + const Offset(4, 0), stroke);
        canvas.drawLine(center + const Offset(-2, -3), center + const Offset(-2, 3), stroke);
        canvas.drawLine(center + const Offset(2, -3), center + const Offset(2, 3), stroke);
      case ElectricalComponentType.switchControl:
        canvas.drawCircle(center, 8, stroke);
        canvas.drawLine(center + const Offset(-4, 4), center + const Offset(4, -4), stroke);
      case ElectricalComponentType.lightingPoint:
        canvas.drawCircle(center, 8, stroke);
        canvas.drawLine(center + const Offset(-5, -5), center + const Offset(5, 5), stroke);
        canvas.drawLine(center + const Offset(5, -5), center + const Offset(-5, 5), stroke);
      case ElectricalComponentType.curtainMotor:
        canvas.drawRect(Rect.fromCenter(center: center, width: 16, height: 11), stroke);
        _label(canvas, 'M', center, centered: true, small: true);
      case ElectricalComponentType.junctionBox:
        canvas.drawRect(Rect.fromCenter(center: center, width: 15, height: 15), stroke);
        canvas.drawCircle(center, 2, stroke);
      case ElectricalComponentType.powerSource:
        canvas.drawCircle(center, 8, stroke);
        canvas.drawLine(center + const Offset(0, -5), center + const Offset(0, 5), stroke);
      case ElectricalComponentType.distributionBoard:
        canvas.drawRect(Rect.fromCenter(center: center, width: 15, height: 18), stroke);
        canvas.drawLine(center + const Offset(-4, -3), center + const Offset(4, -3), stroke);
        canvas.drawLine(center + const Offset(-4, 2), center + const Offset(4, 2), stroke);
      case ElectricalComponentType.custom:
        canvas.drawRect(Rect.fromCenter(center: center, width: 15, height: 15), stroke);
    }
    if (selected) {
      canvas.drawCircle(center, 13, stroke..strokeWidth = 1.2);
    }
  }

  void _drawNavigationEdges(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = const Color(0x33246DB3)
      ..strokeWidth = 7;
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
      ..color = const Color(0xFF4B5563)
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
      ..color = const Color(0xFF4B5563)
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
          color: const Color(0xFF374151),
          fontSize: small ? 10 : 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centered
          ? point - Offset(painter.width / 2, painter.height / 2)
          : point,
    );
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter oldDelegate) =>
      oldDelegate.projection.camera != projection.camera ||
      oldDelegate.lod != lod ||
      oldDelegate.activeSurfaceId != activeSurfaceId ||
      oldDelegate.selectedSpaceId != selectedSpaceId ||
      oldDelegate.dimensionsVisible != dimensionsVisible ||
      oldDelegate.openingsVisible != openingsVisible ||
      oldDelegate.electricalVisible != electricalVisible ||
      oldDelegate.cableRoutesVisible != cableRoutesVisible ||
      oldDelegate.openingsFingerprint != openingsFingerprint ||
      oldDelegate.routeFingerprint != routeFingerprint ||
      oldDelegate.componentsFingerprint != componentsFingerprint ||
      oldDelegate.selectionFingerprint != selectionFingerprint ||
      oldDelegate.snapFingerprint != snapFingerprint ||
      oldDelegate.profileFingerprint != profileFingerprint;
}
