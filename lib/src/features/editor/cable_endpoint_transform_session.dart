import 'package:flutter/foundation.dart';

import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/geometry.dart';
import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import '../../engine/port_snap_resolver.dart';
import '../../engine/snap_engine.dart';
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
  }) {
    if (route.segments.isEmpty) return false;
    final segment = role == CableEndpointRole.source
        ? route.segments.first
        : route.segments.last;
    if (segment.surface != context.surface || segment.points.length < 2) {
      return false;
    }
    _origin = route;
    _components = List.unmodifiable(components);
    _context = context;
    _role = role;
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

    final fixedComponentId = role == CableEndpointRole.target
        ? origin.source.componentId
        : origin.target.componentId;
    final anchors = PortSnapResolver.anchorsFor(
      components: _components,
      surface: context.surface,
      role: role,
      excludeComponentId: fixedComponentId,
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
      _preview = null;
      _phase = EditorEditSessionPhase.invalid;
      notifyListeners();
      return false;
    }

    final endpoint = _endpointForSourceId(snap.sourceId!);
    if (endpoint == null) {
      _preview = null;
      _phase = EditorEditSessionPhase.invalid;
      notifyListeners();
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
    final candidates = NormativeRouteEngine.buildCandidates(
      source: sourcePoint,
      target: targetPoint,
      context: context,
    );
    final best = _firstValid(candidates);
    if (best == null) {
      _preview = null;
      _phase = EditorEditSessionPhase.invalid;
      notifyListeners();
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
                surface: segment.surface, points: best.points)
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
      validation: best.validation,
    );
    _phase = EditorEditSessionPhase.previewing;
    notifyListeners();
    return true;
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

  static RouteCandidate? _firstValid(Iterable<RouteCandidate> candidates) {
    for (final candidate in candidates) {
      if (candidate.validation.isValid) return candidate;
    }
    return null;
  }

  void _clear(EditorEditSessionPhase terminal) {
    _origin = null;
    _components = const [];
    _context = null;
    _role = null;
    _preview = null;
    _hysteresis.clear();
    _phase = terminal;
    notifyListeners();
  }
}
