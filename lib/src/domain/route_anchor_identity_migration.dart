import 'electrical_routing.dart';
import 'project_identity.dart';

/// Assigns stable identities to legacy route points without deriving identity
/// from segment or point ordinals.
///
/// This is an explicit migration boundary: existing stable ids are preserved;
/// only a segment with no ids receives freshly allocated UUID-backed ids from
/// [EntityIdFactory]. Partially populated segments are rejected by the segment
/// model and are never repaired heuristically.
abstract final class RouteAnchorIdentityMigration {
  static ElectricalCableRoute migrate(
    ElectricalCableRoute route,
    EntityIdFactory ids,
  ) {
    var changed = false;
    final segments = <ElectricalRouteSegment>[];
    for (final segment in route.segments) {
      if (segment.hasStableAnchorIdentity && segment.anchorIds.isNotEmpty) {
        segments.add(segment);
        continue;
      }
      if (segment.points.isEmpty) {
        segments.add(segment);
        continue;
      }
      changed = true;
      segments.add(
        ElectricalRouteSegment(
          surface: segment.surface,
          points: segment.points,
          anchorIds: [
            for (var index = 0; index < segment.points.length; index++)
              ids.newRouteAnchorId(),
          ],
        ),
      );
    }
    if (!changed) return route;
    return ElectricalCableRoute(
      id: route.id,
      source: route.source,
      target: route.target,
      segments: List.unmodifiable(segments),
      cableType: route.cableType,
      medium: route.medium,
      reservePercent: route.reservePercent,
    );
  }
}
