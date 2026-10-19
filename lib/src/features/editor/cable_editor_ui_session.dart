import 'package:flutter/foundation.dart';

import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import 'cable_route_constraints.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

/// Transient interaction focus/mode for cable editing.
///
/// Persistent lock and mandatory-waypoint state lives in EditorP2State. This
/// session deliberately owns only interaction state that may disappear when a
/// widget/controller is recreated.
final class CableEditorUiSession extends ChangeNotifier {
  CableEditorUiSession(this._controller);

  final EditorController _controller;
  CableRoutingMode _mode = CableRoutingMode.auto;
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

  CableRouteConstraints _constraints(String routeId) =>
      _controller.p2.routeConstraintsFor(routeId);

  bool isSegmentLocked(String routeId, int segmentIndex) =>
      _constraints(routeId).isSegmentLocked(segmentIndex);

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
    if (_controller.p2.toggleRouteSegmentLock(routeId, segmentIndex)) {
      notifyListeners();
    }
  }

  bool routeHasLockedSegments(String routeId) =>
      _constraints(routeId).lockedSegments.isNotEmpty;

  bool segmentHasWaypoints(String routeId, int segmentIndex) =>
      _constraints(routeId).segmentHasWaypoints(segmentIndex);

  List<CableMandatoryWaypoint> waypointsFor(String routeId) =>
      _constraints(routeId).mandatoryWaypoints;

  bool isWaypoint(String routeId, int segmentIndex, int pointIndex) =>
      _constraints(routeId).isWaypoint(segmentIndex, pointIndex);

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
    if (_controller.p2.toggleRouteWaypoint(
      routeId: routeId,
      segmentIndex: segmentIndex,
      pointIndex: pointIndex,
      point: point,
    )) {
      notifyListeners();
    }
  }
}

final Expando<CableEditorUiSession> _cableUiSessions =
    Expando<CableEditorUiSession>('ElecX cable editor UI session');

extension CableEditorUiSessionAccess on EditorController {
  CableEditorUiSession get cableUi =>
      _cableUiSessions[this] ??= CableEditorUiSession(this);
}
