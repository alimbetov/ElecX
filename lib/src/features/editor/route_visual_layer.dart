import 'package:flutter/material.dart';

import '../../domain/geometry.dart';
import '../../domain/hosted_routing.dart';
import '../../domain/route_host.dart';
import '../../domain/route_medium.dart';
import '../../engine/route_flow_visualization.dart';
import '../../engine/route_interaction_engine.dart';

/// Maps route-host millimetre coordinates into the active canvas viewport.
/// SurfaceCanvas and SiteMapCanvas provide their own camera/projection adapter,
/// while the route rendering/interaction semantics remain shared.
abstract interface class RouteViewportMapper {
  RouteHostRef get host;
  Offset toViewport(MmPoint point);
}

final class RouteVisualLayer extends StatelessWidget {
  const RouteVisualLayer({
    required this.mapper,
    required this.routes,
    required this.selectedRouteId,
    required this.phase,
    this.mediumResolver,
    this.onTransitionTap,
    super.key,
  });

  final RouteViewportMapper mapper;
  final List<HostedRoutePath> routes;
  final String? selectedRouteId;
  final double phase;
  final RouteMediumProfile Function(String routeId)? mediumResolver;
  final ValueChanged<RouteHostTransition>? onTransitionTap;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: RouteVisualPainter(
            mapper: mapper,
            routes: routes,
            selectedRouteId: selectedRouteId,
            phase: phase,
            mediumResolver: mediumResolver,
            colorScheme: Theme.of(context).colorScheme,
          ),
          size: Size.infinite,
        ),
      );
}

final class RouteVisualPainter extends CustomPainter {
  RouteVisualPainter({
    required this.mapper,
    required this.routes,
    required this.selectedRouteId,
    required this.phase,
    required this.colorScheme,
    this.mediumResolver,
  });

  final RouteViewportMapper mapper;
  final List<HostedRoutePath> routes;
  final String? selectedRouteId;
  final double phase;
  final ColorScheme colorScheme;
  final RouteMediumProfile Function(String routeId)? mediumResolver;

  @override
  void paint(Canvas canvas, Size size) {
    for (final route in routes) {
      final selected = route.routeId == selectedRouteId;
      final medium = mediumResolver?.call(route.routeId) ?? route.medium;
      final frame = RouteFlowVisualizationPolicy.frame(
        medium: medium,
        phase: phase,
      );
      _drawRoute(canvas, route, selected: selected, frame: frame);
      if (selected) {
        _drawFlow(canvas, route, medium);
        _drawTransitions(canvas, route);
      }
    }
  }

  void _drawRoute(
    Canvas canvas,
    HostedRoutePath route, {
    required bool selected,
    required RouteFlowFrame frame,
  }) {
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = selected ? 3.2 : 1.8
      ..color = selected
          ? colorScheme.primary
          : colorScheme.onSurfaceVariant.withValues(alpha: 0.72);

    if (selected) {
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 9
        ..color =
            colorScheme.primary.withValues(alpha: 0.12 + frame.glow * 0.18);
      _drawHostedSegments(canvas, route, halo);
    }
    _drawHostedSegments(canvas, route, base);
  }

  void _drawHostedSegments(Canvas canvas, HostedRoutePath route, Paint paint) {
    for (final segment in route.segments) {
      if (segment.host != mapper.host || segment.points.length < 2) continue;
      var previous = mapper.toViewport(segment.points.first);
      for (final point in segment.points.skip(1)) {
        final current = mapper.toViewport(point);
        canvas.drawLine(previous, current, paint);
        previous = current;
      }
    }
  }

  void _drawFlow(
    Canvas canvas,
    HostedRoutePath route,
    RouteMediumProfile medium,
  ) {
    final samples = RouteInteractionEngine.flowSamples(
      route: route,
      medium: medium,
      phase: phase,
    );
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.primary;
    for (final sample in samples) {
      if (sample.hostId != mapper.host.id) continue;
      final point = mapper.toViewport(
        MmPoint(sample.xMm.round(), sample.yMm.round()),
      );
      canvas.drawCircle(point, sample.reverse ? 3.2 : 4.0, paint);
      if (sample.reverse) {
        canvas.drawCircle(
          point,
          6.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = colorScheme.primary.withValues(alpha: 0.55),
        );
      }
    }
  }

  void _drawTransitions(Canvas canvas, HostedRoutePath route) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.tertiaryContainer;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = colorScheme.tertiary;

    for (final transition in route.transitions) {
      MmPoint? point;
      if (transition.fromHost == mapper.host) {
        point = transition.fromPoint;
      } else if (transition.toHost == mapper.host) {
        point = transition.toPoint;
      }
      if (point == null) continue;
      final center = mapper.toViewport(point);
      canvas.drawCircle(center, 7, fill);
      canvas.drawCircle(center, 7, stroke);
      canvas.drawCircle(center, 2.5, Paint()..color = colorScheme.tertiary);
    }
  }

  @override
  bool shouldRepaint(covariant RouteVisualPainter oldDelegate) =>
      oldDelegate.mapper.host != mapper.host ||
      oldDelegate.routes != routes ||
      oldDelegate.selectedRouteId != selectedRouteId ||
      oldDelegate.phase != phase ||
      oldDelegate.colorScheme != colorScheme;
}
