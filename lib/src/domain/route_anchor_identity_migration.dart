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
    _requireUniqueExistingAnchorIds(route);

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

    // Anchor migration is identity-only. Keep the rest of the route aggregate,
    // especially physical wall/slab penetrations, unchanged.
    final migrated = route.copyWith(segments: List.unmodifiable(segments));
    _requireUniqueExistingAnchorIds(migrated);
    return migrated;
  }

  static void _requireUniqueExistingAnchorIds(ElectricalCableRoute route) {
    final seen = <RouteAnchorId>{};
    for (final segment in route.segments) {
      for (final anchorId in segment.anchorIds) {
        if (anchorId.value.startsWith('p7a-transition:')) {
          throw StateError(
            'Route ${route.id} uses reserved projection-only RouteAnchorId '
            '${anchorId.value}.',
          );
        }
        if (!seen.add(anchorId)) {
          throw StateError(
            'Route ${route.id} contains duplicate durable RouteAnchorId '
            '${anchorId.value}.',
          );
        }
      }
    }
  }
}
