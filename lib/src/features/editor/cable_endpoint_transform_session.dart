import 'package:flutter/foundation.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/geometry.dart';
import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import '../../engine/port_snap_resolver.dart';
import '../../engine/snap_engine.dart';
import 'cable_route_constraints.dart';
import 'editor_edit_session.dart';

final class CableEndpointTransformPreview {
  const CableEndpointTransformPreview({
    required this.route,
    required this.snap,
    required this.validation,
  });

  final ElectricalCableRoute route;
  final SnapCandidate snap;
  final RouteConstraintResult validation;
}

/// Edits one cable endpoint as an atomic semantic operation:
/// drag/nudge -> magnetic port snap -> normative autoroute -> commit/cancel.
///
/// Persistent route constraints are enforced inside the session, not only by
/// widget policy. Locked endpoint segments cannot be changed. Mandatory
/// waypoints remain physical anchors and endpoint rerouting is solved through
/// them in segment order before the complete replacement polyline is validated.
final class CableEndpointTransformSession extends ChangeNotifier
    implements EditorEditSession<CableEndpointTransformPreview> {
  CableEndpointTransformSession({required this.onCommit});

  final bool Function(ElectricalCableRoute before, ElectricalCableRoute after)
      onCommit;

  final SnapHysteresis _hysteresis = SnapHysteresis();
  ElectricalCableRoute? _origin;
  List<ElectricalComponentPlacement> _components = const [];
  RouteNormativeContext? _context;
  CableEndpointRole? _role;
  CableRouteConstraints _constraints = CableRouteConstraints.empty;
  CableEndpointTransformPreview? _preview;
  EditorEditSessionPhase _phase = EditorEditSessionPhase.idle;

  @override
  EditorEditSessionPhase get phase => _phase;

  @override
  bool get active =>
      _phase == EditorEditSessionPhase.previewing ||
      _phase == EditorEditSessionPhase.invalid;

  @override
  CableEndpointTransformPreview? get previewState => _preview;

  bool start({
    required ElectricalCableRoute route,
    required CableEndpointRole role,
    required Iterable<ElectricalComponentPlacement> components,
    required RouteNormativeContext context,
    CableRouteConstraints? constraints,
  }) {
    if (route.segments.isEmpty) return false;
    final segmentIndex =
        role == CableEndpointRole.source ? 0 : route.segments.length - 1;
    final segment = route.segments[segmentIndex];
    final routeConstraints = constraints ?? CableRouteConstraints.empty;
    if (segment.surface != context.surface ||
        segment.points.length < 2 ||
        routeConstraints.isSegmentLocked(segmentIndex) ||
        !_waypointsBelongToSegment(
          constraints: routeConstraints,
          segmentIndex: segmentIndex,
          points: segment.points,
        )) {
      return false;
    }
    _origin = route;
    _components = List.unmodifiable(components);
    _context = context;
    _role = role;
    _constraints = routeConstraints;
    _preview = null;
    _hysteresis.clear();
    _phase = EditorEditSessionPhase.previewing;
    notifyListeners();
    return true;
  }

  @override
  bool begin() => _origin != null;

  bool preview({
    required MmPoint rawPoint,
    required double acquisitionRadiusMm,
    required double releaseRadiusMm,
    required int gridStepMm,
  }) {
    final origin = _origin;
    final context = _context;
    final role = _role;
    if (origin == null || context == null || role == null || !active) {
      return false;
    }

    final fixedEndpoint =
        role == CableEndpointRole.target ? origin.source : origin.target;
    final fixedComponentId = fixedEndpoint.componentId;
    final counterpartKind = _portKindForEndpoint(fixedEndpoint);
    if (counterpartKind == null) {
      _invalidate();
      return false;
    }
    final anchors = PortSnapResolver.anchorsFor(
      components: _components,
      surface: context.surface,
      role: role,
      excludeComponentId: fixedComponentId,
      counterpartKind: counterpartKind,
    );
    final resolved = SnapEngine.resolve(
      SnapRequest(
        rawPoint: rawPoint,
        acquisitionRadiusMm: acquisitionRadiusMm,
        gridStepMm: gridStepMm,
        semanticAnchors: anchors,
      ),
    );
    final semantic = resolved != null &&
            (resolved.kind == SnapKind.port ||
                resolved.kind == SnapKind.componentAnchor)
        ? resolved
        : null;
    final snap = _hysteresis.resolve(
      rawPoint: rawPoint,
      candidate: semantic,
      releaseRadiusMm: releaseRadiusMm,
    );
    if (snap == null || snap.kind != SnapKind.port || snap.sourceId == null) {
      _invalidate();
      return false;
    }

    final endpoint = _endpointForSourceId(snap.sourceId!);
    if (endpoint == null) {
      _invalidate();
      return false;
    }

    final segmentIndex =
        role == CableEndpointRole.source ? 0 : origin.segments.length - 1;
    final segment = origin.segments[segmentIndex];
    final fixedPoint = role == CableEndpointRole.target
        ? segment.points.first
        : segment.points.last;
    final movedPoint = SurfacePointMm(snap.point.x, snap.point.y);
    final sourcePoint =
        role == CableEndpointRole.source ? movedPoint : fixedPoint;
    final targetPoint =
        role == CableEndpointRole.target ? movedPoint : fixedPoint;
    final routed = _routeThroughMandatoryWaypoints(
      source: sourcePoint,
      target: targetPoint,
      segmentIndex: segmentIndex,
      context: context,
    );
    if (routed == null) {
      _invalidate();
      return false;
    }

    final route = ElectricalCableRoute(
      id: origin.id,
      source: role == CableEndpointRole.source ? endpoint : origin.source,
      target: role == CableEndpointRole.target ? endpoint : origin.target,
      segments: [
        for (var i = 0; i < origin.segments.length; i++)
          if (i == segmentIndex)
            ElectricalRouteSegment(
              surface: segment.surface,
              points: routed.points,
            )
          else
            origin.segments[i],
      ],
      cableType: origin.cableType,
      medium: origin.medium,
      reservePercent: origin.reservePercent,
    );
    _preview = CableEndpointTransformPreview(
      route: route,
      snap: snap,
      validation: routed.validation,
    );
    _phase = routed.validation.isValid
        ? EditorEditSessionPhase.previewing
        : EditorEditSessionPhase.invalid;
    notifyListeners();
    return routed.validation.isValid;
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

  ({List<SurfacePointMm> points, RouteConstraintResult validation})?
      _routeThroughMandatoryWaypoints({
    required SurfacePointMm source,
    required SurfacePointMm target,
    required int segmentIndex,
    required RouteNormativeContext context,
  }) {
    final waypoints = _constraints.mandatoryWaypoints
        .where((item) => item.segmentIndex == segmentIndex)
        .toList(growable: false)
      ..sort((a, b) => a.pointIndex.compareTo(b.pointIndex));
    final anchors = <SurfacePointMm>[
      source,
      for (final waypoint in waypoints) waypoint.point,
      target,
    ];
    final combined = <SurfacePointMm>[];
    for (var i = 1; i < anchors.length; i++) {
      final from = anchors[i - 1];
      final to = anchors[i];
      if (_samePoint(from, to)) {
        if (combined.isEmpty || !_samePoint(combined.last, to)) {
          combined.add(to);
        }
        continue;
      }
      final best = _firstValid(
        NormativeRouteEngine.buildCandidates(
          source: from,
          target: to,
          context: context,
        ),
      );
      if (best == null) return null;
      for (final point in best.points) {
        if (combined.isEmpty || !_samePoint(combined.last, point)) {
          combined.add(point);
        }
      }
    }
    if (combined.length < 2) return null;
    for (final waypoint in waypoints) {
      if (!combined.any((point) => _samePoint(point, waypoint.point))) {
        return null;
      }
    }
    final validation = NormativeRouteEngine.validate(
      points: combined,
      context: context,
    );
    return (points: List.unmodifiable(combined), validation: validation);
  }

  ElectricalPortKind? _portKindForEndpoint(ElectricalEndpointRef endpoint) {
    return ElectricalPortCompatibility.portForEndpoint(
      endpoint: endpoint,
      components: _components,
    )?.kind;
  }

  ElectricalEndpointRef? _endpointForSourceId(String sourceId) {
    for (final component in _components) {
      for (final port in component.ports) {
        if ('${component.id}:${port.id}' == sourceId) {
          return ElectricalEndpointRef(
            componentId: component.id,
            portId: port.id,
          );
        }
      }
    }
    return null;
  }

  void _invalidate() {
    _preview = null;
    _phase = EditorEditSessionPhase.invalid;
    notifyListeners();
  }

  static bool _waypointsBelongToSegment({
    required CableRouteConstraints constraints,
    required int segmentIndex,
    required List<SurfacePointMm> points,
  }) {
    for (final waypoint in constraints.mandatoryWaypoints) {
      if (waypoint.segmentIndex != segmentIndex) continue;
      if (!points.any((point) => _samePoint(point, waypoint.point))) {
        return false;
      }
    }
    return true;
  }

  static RouteCandidate? _firstValid(Iterable<RouteCandidate> candidates) {
    for (final candidate in candidates) {
      if (candidate.validation.isValid) return candidate;
    }
    return null;
  }

  static bool _samePoint(SurfacePointMm a, SurfacePointMm b) =>
      a.xMm == b.xMm && a.yMm == b.yMm;

  void _clear(EditorEditSessionPhase terminal) {
    _origin = null;
    _components = const [];
    _context = null;
    _role = null;
    _constraints = CableRouteConstraints.empty;
    _preview = null;
    _hysteresis.clear();
    _phase = terminal;
    notifyListeners();
  }
}
