import 'package:flutter/foundation.dart';

import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import 'editor_controller.dart';

final class CableMandatoryWaypoint {
  const CableMandatoryWaypoint({
    required this.segmentIndex,
    required this.pointIndex,
    required this.point,
  });

  final int segmentIndex;
  final int pointIndex;
  final SurfacePointMm point;
}

/// Ephemeral editor state for cable manipulation. Geometry itself remains in
/// EditorP2Session/history; this class only owns interaction mode and editing
/// constraints that are not yet persisted in the project schema.
final class CableEditorUiSession extends ChangeNotifier {
  CableRoutingMode _mode = CableRoutingMode.auto;
  final Map<String, Set<int>> _lockedSegments = {};
  final Map<String, List<CableMandatoryWaypoint>> _waypoints = {};
  String? _activeRouteId;
  int? _activeSegmentIndex;
  int? _activePointIndex;

  CableRoutingMode get mode => _mode;
  String? get activeRouteId => _activeRouteId;
  int? get activeSegmentIndex => _activeSegmentIndex;
  int? get activePointIndex => _activePointIndex;

  void setMode(CableRoutingMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  void focusGeometry({
    required String routeId,
    int? segmentIndex,
    int? pointIndex,
  }) {
    if (_activeRouteId == routeId &&
        _activeSegmentIndex == segmentIndex &&
        _activePointIndex == pointIndex) {
      return;
    }
    _activeRouteId = routeId;
    _activeSegmentIndex = segmentIndex;
    _activePointIndex = pointIndex;
    notifyListeners();
  }

  void clearFocus() {
    if (_activeRouteId == null &&
        _activeSegmentIndex == null &&
        _activePointIndex == null) {
      return;
    }
    _activeRouteId = null;
    _activeSegmentIndex = null;
    _activePointIndex = null;
    notifyListeners();
  }

  bool isSegmentLocked(String routeId, int segmentIndex) =>
      _lockedSegments[routeId]?.contains(segmentIndex) ?? false;

  bool get activeSegmentLocked {
    final routeId = _activeRouteId;
    final segmentIndex = _activeSegmentIndex;
    return routeId != null &&
        segmentIndex != null &&
        isSegmentLocked(routeId, segmentIndex);
  }

  void toggleActiveSegmentLock() {
    final routeId = _activeRouteId;
    final segmentIndex = _activeSegmentIndex;
    if (routeId == null || segmentIndex == null) return;
    final set = _lockedSegments.putIfAbsent(routeId, () => <int>{});
    if (!set.add(segmentIndex)) set.remove(segmentIndex);
    if (set.isEmpty) _lockedSegments.remove(routeId);
    notifyListeners();
  }

  bool routeHasLockedSegments(String routeId) =>
      _lockedSegments[routeId]?.isNotEmpty ?? false;

  bool segmentHasWaypoints(String routeId, int segmentIndex) =>
      (_waypoints[routeId] ?? const <CableMandatoryWaypoint>[]).any(
        (item) => item.segmentIndex == segmentIndex,
      );

  List<CableMandatoryWaypoint> waypointsFor(String routeId) =>
      List.unmodifiable(
          _waypoints[routeId] ?? const <CableMandatoryWaypoint>[]);

  bool isWaypoint(String routeId, int segmentIndex, int pointIndex) =>
      (_waypoints[routeId] ?? const <CableMandatoryWaypoint>[]).any(
        (item) =>
            item.segmentIndex == segmentIndex && item.pointIndex == pointIndex,
      );

  bool get activePointIsWaypoint {
    final routeId = _activeRouteId;
    final segmentIndex = _activeSegmentIndex;
    final pointIndex = _activePointIndex;
    if (routeId == null || segmentIndex == null || pointIndex == null) {
      return false;
    }
    return isWaypoint(routeId, segmentIndex, pointIndex);
  }

  void toggleWaypoint({required SurfacePointMm point}) {
    final routeId = _activeRouteId;
    final segmentIndex = _activeSegmentIndex;
    final pointIndex = _activePointIndex;
    if (routeId == null || segmentIndex == null || pointIndex == null) return;
    final list = _waypoints.putIfAbsent(
      routeId,
      () => <CableMandatoryWaypoint>[],
    );
    final existing = list.indexWhere(
      (item) =>
          item.segmentIndex == segmentIndex && item.pointIndex == pointIndex,
    );
    if (existing >= 0) {
      list.removeAt(existing);
    } else {
      list.add(
        CableMandatoryWaypoint(
          segmentIndex: segmentIndex,
          pointIndex: pointIndex,
          point: point,
        ),
      );
    }
    if (list.isEmpty) _waypoints.remove(routeId);
    notifyListeners();
  }

  /// Rebinds waypoint coordinates after an accepted route edit. A waypoint is
  /// retained only while its referenced point still exists.
  void reconcileRoutePoints(
    String routeId,
    List<List<SurfacePointMm>> segmentPoints,
  ) {
    final existing = _waypoints[routeId];
    if (existing == null || existing.isEmpty) return;
    final next = <CableMandatoryWaypoint>[];
    for (final waypoint in existing) {
      if (waypoint.segmentIndex >= segmentPoints.length) continue;
      final points = segmentPoints[waypoint.segmentIndex];
      if (waypoint.pointIndex >= points.length) continue;
      next.add(
        CableMandatoryWaypoint(
          segmentIndex: waypoint.segmentIndex,
          pointIndex: waypoint.pointIndex,
          point: points[waypoint.pointIndex],
        ),
      );
    }
    if (next.isEmpty) {
      _waypoints.remove(routeId);
    } else {
      _waypoints[routeId] = next;
    }
    notifyListeners();
  }
}

final Expando<CableEditorUiSession> _cableUiSessions =
    Expando<CableEditorUiSession>('ElecX cable editor UI session');

extension CableEditorUiSessionAccess on EditorController {
  CableEditorUiSession get cableUi =>
      _cableUiSessions[this] ??= CableEditorUiSession();
}
