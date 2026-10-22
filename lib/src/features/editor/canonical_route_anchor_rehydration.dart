import '../../domain/boundary_host_migration.dart';
import '../../domain/boundary_host_registry.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import 'editor_p2_session.dart';

/// Restores stable route point identities from the canonical P7A-5 registry
/// after a legacy editor document round-trip that does not yet persist
/// `ElectricalRouteSegment.anchorIds` itself.
///
/// Matching is fail-closed and uses exact `(routeId, SpaceId, BoundaryEdgeId,
/// offsetMm)` affinity. It never derives an id from segment or point ordinals.
abstract final class CanonicalRouteAnchorRehydration {
  static EditorP2State rehydrate({
    required EditorP2State p2State,
    required EngineeringSpace legacySpace,
    required SpaceId canonicalSpaceId,
    required List<BoundaryEdgeId> orderedEdgeIds,
    required BoundaryHostedObjectRegistry registry,
  }) {
    final routes = <ElectricalCableRoute>[];
    for (final route in p2State.routes) {
      final segments = <ElectricalRouteSegment>[];
      for (var segmentIndex = 0;
          segmentIndex < route.segments.length;
          segmentIndex++) {
        final segment = route.segments[segmentIndex];
        if (segment.anchorIds.isNotEmpty ||
            segment.surface.spaceId != legacySpace.id ||
            segment.surface.type != SurfacePlaneType.wall ||
            segment.points.isEmpty) {
          segments.add(segment);
          continue;
        }
        final edgeId = _edgeForSurface(segment.surface, orderedEdgeIds);
        final ids = <RouteAnchorId>[];
        for (var pointIndex = 0;
            pointIndex < segment.points.length;
            pointIndex++) {
          final isSource = segmentIndex == 0 && pointIndex == 0;
          final isTarget = segmentIndex == route.segments.length - 1 &&
              pointIndex == segment.points.length - 1;
          if (isSource) {
            ids.add(_endpointAnchorId(route, source: true));
            continue;
          }
          if (isTarget) {
            ids.add(_endpointAnchorId(route, source: false));
            continue;
          }
          final prefix = 'route:${route.id}:anchor:';
          final candidates = registry.references.entries.where((entry) {
            final reference = entry.value;
            return entry.key.startsWith(prefix) &&
                reference.objectKind == BoundaryHostedObjectKind.routeAnchor &&
                reference.geometryKind == BoundaryHostGeometryKind.point &&
                reference.host.spaceId == canonicalSpaceId &&
                reference.host.edgeId == edgeId &&
                reference.startOffsetMm == segment.points[pointIndex].xMm;
          }).toList(growable: false);
          if (candidates.length != 1) {
            throw StateError(
              'Route ${route.id} point $segmentIndex:$pointIndex resolves to '
              '${candidates.length} canonical RouteAnchorId candidates.',
            );
          }
          ids.add(RouteAnchorId(candidates.single.key.substring(prefix.length)));
        }
        segments.add(
          ElectricalRouteSegment(
            surface: segment.surface,
            points: segment.points,
            anchorIds: List.unmodifiable(ids),
          ),
        );
      }
      routes.add(
        ElectricalCableRoute(
          id: route.id,
          source: route.source,
          target: route.target,
          segments: List.unmodifiable(segments),
          cableType: route.cableType,
          medium: route.medium,
          reservePercent: route.reservePercent,
        ),
      );
    }
    return p2State.copyWith(routes: List.unmodifiable(routes));
  }

  static BoundaryEdgeId _edgeForSurface(
    RoomSurfaceRef surface,
    List<BoundaryEdgeId> orderedEdgeIds,
  ) {
    final stable = surface.boundaryEdgeId;
    if (stable != null) {
      if (!orderedEdgeIds.contains(stable)) {
        throw StateError('Route surface references inactive edge $stable.');
      }
      return stable;
    }
    final ordinal = surface.wallIndex;
    if (ordinal == null || ordinal < 0 || ordinal >= orderedEdgeIds.length) {
      throw StateError('Route wall surface has no valid canonical projection.');
    }
    return orderedEdgeIds[ordinal];
  }

  static RouteAnchorId _endpointAnchorId(
    ElectricalCableRoute route, {
    required bool source,
  }) =>
      RouteAnchorId(
        source
            ? 'p7a-endpoint:${route.id}:source:${route.source.componentId}:${route.source.portId}'
            : 'p7a-endpoint:${route.id}:target:${route.target.componentId}:${route.target.portId}',
      );
}
