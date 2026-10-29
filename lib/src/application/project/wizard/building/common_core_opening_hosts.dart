import 'dart:math' as math;

import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/boundary_host_migration.dart';
import '../../../../domain/boundary_host_registry.dart';
import '../../../../domain/boundary_topology.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/project_space_semantics.dart';

/// Joins semantic common-space openings to the same physical interval on both
/// independent canonical boundaries. Shared by cottage and common/core Apply.
BoundaryHostedObjectRegistry bindCommonCoreOpeningHosts({
  required BoundaryHostedObjectRegistry registry,
  required Iterable<ProjectOpeningEntity> openings,
  required Map<SpaceId, SpaceBoundaryTopology> boundaries,
}) {
  var result = registry;
  for (final opening in openings) {
    final ids = opening.connectedSpaceIds.toList();
    if (ids.length != 2) {
      throw StateError('A common opening requires two spaces.');
    }
    final a = boundaries[ids[0]]!;
    final b = boundaries[ids[1]]!;
    final contacts =
        <(ProjectBoundaryEdge, ProjectBoundaryEdge, GeometrySegmentMm)>[];
    for (final first in a.edges.values) {
      for (final second in b.edges.values) {
        final shared = intersectCollinearSegments(
            GeometrySegmentMm(start: first.start, end: first.end),
            GeometrySegmentMm(start: second.start, end: second.end));
        if (shared != null && shared.lengthMm >= opening.widthMm) {
          contacts.add((first, second, shared));
        }
      }
    }
    if (contacts.length != 1) {
      throw StateError('Common opening has no unique shared host.');
    }
    final (first, second, segment) = contacts.single;
    final inset = (segment.lengthMm - opening.widthMm) ~/ 2;
    final x = math.min(segment.start.xMm, segment.end.xMm);
    final y = math.min(segment.start.yMm, segment.end.yMm);
    final start = BoundaryPointMm(
        xMm: x + (segment.vertical ? 0 : inset),
        yMm: y + (segment.vertical ? inset : 0));
    final end = BoundaryPointMm(
        xMm: start.xMm + (segment.vertical ? 0 : opening.widthMm),
        yMm: start.yMm + (segment.vertical ? opening.widthMm : 0));
    for (final edge in [first, second]) {
      int offset(BoundaryPointMm point) =>
          (point.xMm - edge.start.xMm).abs() +
          (point.yMm - edge.start.yMm).abs();
      result = result.putOpening(
          openingId: opening.id,
          host: BoundaryEdgeHostRef(spaceId: edge.spaceId, edgeId: edge.id),
          startOffsetMm: math.min(offset(start), offset(end)),
          endOffsetMm: math.max(offset(start), offset(end)));
    }
  }
  return result;
}
