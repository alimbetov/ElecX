import 'package:flutter/foundation.dart';

import '../../domain/electrical_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import 'cable_route_constraints.dart';
import 'editor_edit_session.dart';

final class CableRouteEditPreview {
  const CableRouteEditPreview({
    required this.route,
    required this.validation,
    required this.mode,
  });

  final ElectricalCableRoute route;
  final RouteConstraintResult validation;
  final CableRoutingMode mode;
}

/// Transactional route editor shared by pointer, touch, stylus and keyboard
/// adapters. Preview never calls [onCommit]; persistence/history is touched only
/// by [commit].
final class CableRouteEditSession extends ChangeNotifier
    implements EditorEditSession<CableRouteEditPreview> {
  CableRouteEditSession({required this.onCommit});

  final bool Function(ElectricalCableRoute before, ElectricalCableRoute after)
      onCommit;

  ElectricalCableRoute? _origin;
  CableRouteEditPreview? _preview;
  RouteNormativeContext? _context;
  int? _segmentIndex;
  List<CableMandatoryWaypoint> _mandatoryWaypoints = const [];
  CableRoutingMode _mode = CableRoutingMode.auto;
  EditorEditSessionPhase _phase = EditorEditSessionPhase.idle;

  @override
  EditorEditSessionPhase get phase => _phase;

  @override
  bool get active =>
      _phase == EditorEditSessionPhase.previewing ||
      _phase == EditorEditSessionPhase.invalid;

  @override
  CableRouteEditPreview? get previewState => _preview;

  CableRoutingMode get mode => _mode;

  void setMode(CableRoutingMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    final current = _preview;
    if (current != null) {
      _preview = CableRouteEditPreview(
        route: current.route,
        validation: current.validation,
        mode: mode,
      );
    }
    notifyListeners();
  }

  bool start({
    required ElectricalCableRoute route,
    required int segmentIndex,
    required RouteNormativeContext context,
    CableRoutingMode mode = CableRoutingMode.auto,
    CableRouteConstraints? constraints,
  }) {
    if (segmentIndex < 0 || segmentIndex >= route.segments.length) return false;
    final segment = route.segments[segmentIndex];
    if (segment.surface != context.surface || segment.points.length < 2) {
      return false;
    }
    final waypoints = constraints?.mandatoryWaypoints
            .where((item) => item.segmentIndex == segmentIndex)
            .toList(growable: false) ??
        const <CableMandatoryWaypoint>[];
    _origin = route;
    _segmentIndex = segmentIndex;
    _context = context;
    _mandatoryWaypoints = waypoints;
    _mode = mode;
    _phase = EditorEditSessionPhase.previewing;
    _preview = CableRouteEditPreview(
      route: route,
      validation: _validatePoints(segment.points, context),
      mode: mode,
    );
    notifyListeners();
    return true;
  }

  @override
  bool begin() => _origin != null;

  /// Rebuilds the edited segment automatically while preserving mandatory
  /// waypoints. Each mandatory point becomes a hard intermediate routing node.
  bool autoRoute() {
    final origin = _origin;
    final index = _segmentIndex;
    final context = _context;
    if (origin == null || index == null || context == null) return false;
    final segment = origin.segments[index];
    final orderedWaypoints = _mandatoryWaypoints.toList()
      ..sort((a, b) => a.pointIndex.compareTo(b.pointIndex));
    final anchors = <SurfacePointMm>[
      segment.points.first,
      for (final waypoint in orderedWaypoints) waypoint.point,
      segment.points.last,
    ];
    final rebuilt = <SurfacePointMm>[];
    for (var i = 1; i < anchors.length; i++) {
      final candidates = NormativeRouteEngine.buildCandidates(
        source: anchors[i - 1],
        target: anchors[i],
        context: context,
      );
      final best = candidates.where((item) => item.validation.isValid).firstOrNull;
      if (best == null) {
        _phase = EditorEditSessionPhase.invalid;
        notifyListeners();
        return false;
      }
      if (rebuilt.isEmpty) {
        rebuilt.addAll(best.points);
      } else {
        rebuilt.addAll(best.points.skip(1));
      }
    }
    return preview(_removeConsecutiveDuplicates(rebuilt));
  }

  /// Applies an engineer-authored route preview. In AUTO/ASSISTED mode invalid
  /// geometry is exposed visually but cannot be committed. MANUAL+GUARDRAILS
  /// uses the same rule by default; a future explicit normative override is a
  /// separate audited command rather than an implicit bypass here.
  bool preview(List<SurfacePointMm> points) {
    final origin = _origin;
    final index = _segmentIndex;
    final context = _context;
    if (origin == null || index == null || context == null) return false;

    final validation = _validatePoints(points, context);
    final replacement = ElectricalRouteSegment(
      surface: origin.segments[index].surface,
      points: List.unmodifiable(points),
    );
    final route = _replaceSegment(origin, index, replacement);
    _preview = CableRouteEditPreview(
      route: route,
      validation: validation,
      mode: _mode,
    );
    _phase = validation.isValid
        ? EditorEditSessionPhase.previewing
        : EditorEditSessionPhase.invalid;
    notifyListeners();
    return validation.isValid;
  }

  RouteConstraintResult _validatePoints(
    List<SurfacePointMm> points,
    RouteNormativeContext context,
  ) {
    final normative = NormativeRouteEngine.validate(
      points: points,
      context: context,
    );
    final issues = <RouteConstraintIssue>[...normative.issues];
    for (final waypoint in _mandatoryWaypoints) {
      final preserved = points.any(
        (point) =>
            point.xMm == waypoint.point.xMm && point.yMm == waypoint.point.yMm,
      );
      if (!preserved) {
        issues.add(
          RouteConstraintIssue(
            code: 'route.mandatory-waypoint-missing',
            message:
                'Маршрут должен проходить через обязательную точку ${waypoint.point.xMm}, ${waypoint.point.yMm} мм.',
            severity: RouteConstraintSeverity.error,
          ),
        );
      }
    }
    return RouteConstraintResult(List.unmodifiable(issues));
  }

  @override
  bool validate() => _preview?.validation.isValid ?? false;

  @override
  bool commit() {
    final origin = _origin;
    final preview = _preview;
    if (origin == null || preview == null || !preview.validation.isValid) {
      return false;
    }
    if (!_changed(origin, preview.route)) {
      _clear(EditorEditSessionPhase.cancelled);
      return false;
    }
    final committed = onCommit(origin, preview.route);
    if (!committed) return false;
    _clear(EditorEditSessionPhase.committed);
    return true;
  }

  @override
  void cancel() {
    if (_origin == null) return;
    _clear(EditorEditSessionPhase.cancelled);
  }

  void _clear(EditorEditSessionPhase terminal) {
    _origin = null;
    _preview = null;
    _context = null;
    _segmentIndex = null;
    _mandatoryWaypoints = const [];
    _phase = terminal;
    notifyListeners();
  }

  static ElectricalCableRoute _replaceSegment(
    ElectricalCableRoute route,
    int index,
    ElectricalRouteSegment replacement,
  ) =>
      ElectricalCableRoute(
        id: route.id,
        source: route.source,
        target: route.target,
        segments: [
          for (var i = 0; i < route.segments.length; i++)
            if (i == index) replacement else route.segments[i],
        ],
        cableType: route.cableType,
        medium: route.medium,
        reservePercent: route.reservePercent,
      );

  static List<SurfacePointMm> _removeConsecutiveDuplicates(
    List<SurfacePointMm> points,
  ) {
    final result = <SurfacePointMm>[];
    for (final point in points) {
      if (result.isNotEmpty &&
          result.last.xMm == point.xMm &&
          result.last.yMm == point.yMm) {
        continue;
      }
      result.add(point);
    }
    return List.unmodifiable(result);
  }

  static bool _changed(
    ElectricalCableRoute before,
    ElectricalCableRoute after,
  ) {
    if (before.segments.length != after.segments.length) return true;
    for (var i = 0; i < before.segments.length; i++) {
      final a = before.segments[i];
      final b = after.segments[i];
      if (a.points.length != b.points.length) return true;
      for (var p = 0; p < a.points.length; p++) {
        if (a.points[p].xMm != b.points[p].xMm ||
            a.points[p].yMm != b.points[p].yMm) {
          return true;
        }
      }
    }
    return false;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
