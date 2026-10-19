import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../domain/hosted_routing.dart';
import '../../domain/route_host.dart';
import '../../domain/route_medium.dart';
import '../../engine/route_flow_visualization.dart';
import '../../engine/route_interaction_engine.dart';
import '../../engine/world_camera.dart';
import 'cad_visual_tokens.dart';
import 'editor_controller.dart';
import 'hosted_route_session.dart';
import 'route_selection_session.dart';
import 'site_map_interaction.dart';

class SiteMapCanvas extends StatefulWidget {
  const SiteMapCanvas({
    required this.entities,
    required this.interaction,
    required this.onEntityOpen,
    this.initialCamera,
    this.onCameraChanged,
    this.routeController,
    this.mediumResolver,
    this.onRouteTransitionTap,
    super.key,
  });

  final List<SiteMapEntity> entities;
  final SiteMapInteractionController interaction;
  final ValueChanged<SiteMapEntity> onEntityOpen;
  final WorldCamera? initialCamera;
  final ValueChanged<WorldCamera>? onCameraChanged;
  final EditorController? routeController;
  final RouteMediumProfile Function(String routeId)? mediumResolver;
  final ValueChanged<RouteHostTransition>? onRouteTransitionTap;

  @override
  State<SiteMapCanvas> createState() => _SiteMapCanvasState();
}

class _SiteMapCanvasState extends State<SiteMapCanvas>
    with SingleTickerProviderStateMixin {
  late WorldCamera _camera;
  late final AnimationController _flow;
  Size _size = Size.zero;
  bool _fitted = false;
  Offset? _panStart;
  WorldCamera? _panCamera;

  EditorController? get routeController => widget.routeController;

  @override
  void initState() {
    super.initState();
    _camera = widget.initialCamera ??
        const WorldCamera(centerMm: MmPoint(0, 0), mmPerPixel: 100);
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    widget.interaction.addListener(_refresh);
    _attachRouteListeners(routeController);
  }

  @override
  void didUpdateWidget(covariant SiteMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interaction != widget.interaction) {
      oldWidget.interaction.removeListener(_refresh);
      widget.interaction.addListener(_refresh);
    }
    if (oldWidget.routeController != widget.routeController) {
      _detachRouteListeners(oldWidget.routeController);
      _attachRouteListeners(widget.routeController);
    }
    if (oldWidget.entities != widget.entities) {
      _fitted = false;
    }
  }

  @override
  void dispose() {
    widget.interaction.removeListener(_refresh);
    _detachRouteListeners(routeController);
    _flow.dispose();
    super.dispose();
  }

  void _attachRouteListeners(EditorController? controller) {
    if (controller == null) return;
    controller.hostedRoutes.addListener(_refresh);
    controller.routeSelection.addListener(_refresh);
  }

  void _detachRouteListeners(EditorController? controller) {
    if (controller == null) return;
    controller.hostedRoutes.removeListener(_refresh);
    controller.routeSelection.removeListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_fitted && _size.width > 0 && _size.height > 0) {
          final bounds = _allBounds();
          if (bounds != null) {
            _camera = _camera.fitBounds(
              bounds: bounds,
              viewportWidthPx: _size.width,
              viewportHeightPx: _size.height,
              paddingPx: 72,
            );
          }
          _fitted = true;
        }
        final scheme = Theme.of(context).colorScheme;
        return Listener(
          onPointerSignal: _onPointerSignal,
          child: MouseRegion(
            cursor: widget.interaction.hoveredNodeId == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onHover: (event) => _updateHover(event.localPosition),
            onExit: (_) => widget.interaction.hover(null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _selectAt(details.localPosition),
              onDoubleTapDown: (details) => _openAt(details.localPosition),
              onPanStart: (details) {
                _panStart = details.localPosition;
                _panCamera = _camera;
              },
              onPanUpdate: (details) {
                final start = _panStart;
                final camera = _panCamera;
                if (start == null || camera == null) return;
                final delta = details.localPosition - start;
                _setCamera(camera.panPixels(delta.dx, delta.dy));
              },
              onPanEnd: (_) {
                _panStart = null;
                _panCamera = null;
              },
              child: AnimatedBuilder(
                animation: _flow,
                builder: (context, _) => CustomPaint(
                  painter: _SiteMapPainter(
                    camera: _camera,
                    entities: widget.entities,
                    hoveredNodeId: widget.interaction.hoveredNodeId,
                    selectedNodeId: widget.interaction.selectedNodeId,
                    scheme: scheme,
                    routeController: routeController,
                    phase: _flow.value,
                    mediumResolver: widget.mediumResolver,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _size.isEmpty) return;
    final factor = event.scrollDelta.dy < 0 ? 1.18 : 1 / 1.18;
    _setCamera(
      _camera.zoomAt(
        factor: factor,
        viewportWidthPx: _size.width,
        viewportHeightPx: _size.height,
        cursorXpx: event.localPosition.dx,
        cursorYpx: event.localPosition.dy,
        minMmPerPixel: 5,
        maxMmPerPixel: 5000,
      ),
    );
  }

  void _setCamera(WorldCamera camera) {
    setState(() => _camera = camera);
    widget.onCameraChanged?.call(camera);
  }

  MmPoint _worldAt(Offset local) => _camera.screenToWorld(
        viewportWidthPx: _size.width,
        viewportHeightPx: _size.height,
        xPx: local.dx,
        yPx: local.dy,
      );

  void _updateHover(Offset local) {
    final entity = _hit(local);
    widget.interaction.hover(entity?.navigatorNodeId);
  }

  void _selectAt(Offset local) {
    final controller = routeController;
    if (controller != null) {
      final world = _worldAt(local);
      final transition = _routeTransitionAt(controller, world);
      if (transition != null) {
        widget.onRouteTransitionTap?.call(transition);
        return;
      }
      final zoneId = _outdoorZoneAt(world);
      if (zoneId != null) {
        final hit = RouteInteractionEngine.hitTestHosted(
          routes: controller.hostedRoutes.paths,
          host: RouteHostRef.outdoor(zoneId),
          xMm: world.x.toDouble(),
          yMm: world.y.toDouble(),
          radiusMm: math.max(100.0, _camera.mmPerPixel * 12),
        );
        if (hit != null) {
          controller.routeSelection.select(hit.routeId);
          widget.interaction.select(null);
          return;
        }
      }
      controller.routeSelection.clear();
    }

    final entity = _hit(local);
    widget.interaction.select(entity?.navigatorNodeId);
  }

  void _openAt(Offset local) {
    final entity = _hit(local);
    if (entity == null) return;
    widget.interaction.select(entity.navigatorNodeId);
    widget.onEntityOpen(entity);
  }

  SiteMapEntity? _hit(Offset local) {
    if (_size.isEmpty) return null;
    final point = _worldAt(local);
    for (final entity in widget.entities.reversed) {
      if (entity.contains(point)) return entity;
    }
    return null;
  }

  String? _outdoorZoneAt(MmPoint point) {
    for (final entity in widget.entities.reversed) {
      if (entity.kind != SiteMapEntityKind.outdoorZone ||
          entity.targetId == null) {
        continue;
      }
      if (entity.contains(point)) return entity.targetId;
    }
    return null;
  }

  RouteHostTransition? _routeTransitionAt(
    EditorController controller,
    MmPoint point,
  ) {
    final selected = controller.routeSelection.selectedHostedRoute;
    if (selected == null) return null;
    final radius = math.max(120.0, _camera.mmPerPixel * 16);
    RouteHostTransition? best;
    var bestDistance = double.infinity;
    for (final transition in selected.transitions) {
      final candidates = <({RouteHostRef host, MmPoint point})>[
        (host: transition.fromHost, point: transition.fromPoint),
        (host: transition.toHost, point: transition.toPoint),
      ];
      for (final candidate in candidates) {
        if (candidate.host.kind != RouteHostKind.outdoorZone) continue;
        final distance = candidate.point.distanceTo(point);
        if (distance <= radius && distance < bestDistance) {
          best = transition;
          bestDistance = distance;
        }
      }
    }
    return best;
  }

  MmBounds? _allBounds() {
    MmBounds? result;
    for (final entity in widget.entities) {
      result = result == null
          ? entity.boundary.bounds
          : result.union(entity.boundary.bounds);
    }
    return result;
  }
}

class _SiteMapPainter extends CustomPainter {
  _SiteMapPainter({
    required this.camera,
    required this.entities,
    required this.hoveredNodeId,
    required this.selectedNodeId,
    required this.scheme,
    required this.routeController,
    required this.phase,
    required this.mediumResolver,
  });

  final WorldCamera camera;
  final List<SiteMapEntity> entities;
  final String? hoveredNodeId;
  final String? selectedNodeId;
  final ColorScheme scheme;
  final EditorController? routeController;
  final double phase;
  final RouteMediumProfile Function(String routeId)? mediumResolver;

  Offset _screen(Size size, MmPoint point) {
    final screen = camera.worldToScreen(
      viewportWidthPx: size.width,
      viewportHeightPx: size.height,
      point: point,
    );
    return Offset(screen.x, screen.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);
    for (final entity in entities) {
      final selected = entity.navigatorNodeId == selectedNodeId;
      final hovered = entity.navigatorNodeId == hoveredNodeId;
      final path = Path();
      final screenPoints = <Offset>[];
      for (var i = 0; i < entity.boundary.vertices.length; i++) {
        final point = _screen(size, entity.boundary.vertices[i]);
        screenPoints.add(point);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = selected
            ? CadVisualTokens.selectedFill(scheme)
            : hovered
                ? CadVisualTokens.hoverFill(scheme)
                : CadVisualTokens.ghostFill(scheme);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected
            ? CadVisualTokens.selectedGeometryStroke
            : hovered
                ? 1.8
                : CadVisualTokens.geometryStroke
        ..color = selected
            ? CadVisualTokens.selectedGeometry(scheme)
            : CadVisualTokens.geometry(scheme);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);

      if (!_labelFits(screenPoints)) continue;
      final center = _screen(size, entity.boundary.bounds.center);
      final painter = TextPainter(
        text: TextSpan(
          text: entity.label,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: selected || hovered ? 12 : 11,
            fontWeight: selected || hovered ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 180);
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
    }
    _drawRoutes(canvas, size);
  }

  void _drawRoutes(Canvas canvas, Size size) {
    final controller = routeController;
    if (controller == null) return;
    final selectedId = controller.routeSelection.selectedRouteId;
    for (final route in controller.hostedRoutes.paths) {
      final selected = route.routeId == selectedId;
      final medium = mediumResolver?.call(route.routeId) ?? route.medium;
      final frame = RouteFlowVisualizationPolicy.frame(
        medium: medium,
        phase: phase,
      );
      if (selected) {
        final halo = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = scheme.primary.withValues(alpha: 0.12 + frame.glow * 0.18);
        _drawOutdoorRouteSegments(canvas, size, route, halo);
      }
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3.2 : 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = selected
            ? scheme.primary
            : scheme.onSurfaceVariant.withValues(alpha: 0.75);
      _drawOutdoorRouteSegments(canvas, size, route, line);
      if (selected) {
        _drawFlow(canvas, size, route, medium);
        _drawTransitions(canvas, size, route);
      }
    }
  }

  void _drawOutdoorRouteSegments(
    Canvas canvas,
    Size size,
    HostedRoutePath route,
    Paint paint,
  ) {
    for (final segment in route.segments) {
      if (segment.host.kind != RouteHostKind.outdoorZone ||
          segment.points.length < 2) {
        continue;
      }
      var previous = _screen(size, segment.points.first);
      for (final point in segment.points.skip(1)) {
        final current = _screen(size, point);
        canvas.drawLine(previous, current, paint);
        previous = current;
      }
    }
  }

  void _drawFlow(
    Canvas canvas,
    Size size,
    HostedRoutePath route,
    RouteMediumProfile medium,
  ) {
    final samples = RouteInteractionEngine.flowSamples(
      route: route,
      medium: medium,
      phase: phase,
    );
    for (final sample in samples) {
      if (!sample.hostId.startsWith('outdoor:')) continue;
      final center = _screen(
        size,
        MmPoint(sample.xMm.round(), sample.yMm.round()),
      );
      canvas.drawCircle(
        center,
        sample.reverse ? 3.2 : 4.2,
        Paint()..color = scheme.primary,
      );
    }
  }

  void _drawTransitions(
    Canvas canvas,
    Size size,
    HostedRoutePath route,
  ) {
    for (final transition in route.transitions) {
      MmPoint? point;
      if (transition.fromHost.kind == RouteHostKind.outdoorZone) {
        point = transition.fromPoint;
      } else if (transition.toHost.kind == RouteHostKind.outdoorZone) {
        point = transition.toPoint;
      }
      if (point == null) continue;
      final center = _screen(size, point);
      canvas.drawCircle(
        center,
        8,
        Paint()..color = scheme.tertiaryContainer,
      );
      canvas.drawCircle(
        center,
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = scheme.tertiary,
      );
      canvas.drawCircle(center, 2.5, Paint()..color = scheme.tertiary);
    }
  }

  bool _labelFits(List<Offset> points) {
    if (points.isEmpty) return false;
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (final point in points.skip(1)) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    return maxX - minX >= 62 && maxY - minY >= 24;
  }

  @override
  bool shouldRepaint(covariant _SiteMapPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.hoveredNodeId != hoveredNodeId ||
      oldDelegate.selectedNodeId != selectedNodeId ||
      oldDelegate.entities != entities ||
      oldDelegate.scheme != scheme ||
      oldDelegate.routeController != routeController ||
      oldDelegate.phase != phase;
}
