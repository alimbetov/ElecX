import 'dart:math' as math;

import '../../domain/boundary_topology.dart';
import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';
import 'editor_document_history.dart';
import 'editor_p2_session.dart';

typedef LegacyBoundaryMaterializer = bool Function(MmPolygon candidate);

/// P7A-4.5 runtime gateway used by the transitional plan editor.
///
/// Existing pointer/keyboard interactions may still produce an MmPolygon
/// candidate, but canonical runtime never commits that polygon directly. The
/// gateway recognizes a single vertex or parallel-edge edit, resolves the
/// affected stable BoundaryEdgeId against the current version-aware projection,
/// commits through ProjectMutationSession, then materializes the committed
/// canonical geometry back into the legacy canvas.
abstract final class CanonicalBoundaryTopologyEditingRuntime {
  static bool hasCanonicalRuntime(EditorController controller) =>
      CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(controller) != null;

  static bool commitCandidate(
    EditorController controller,
    MmPolygon candidate, {
    required LegacyBoundaryMaterializer materializeLegacy,
  }) {
    final coordinator =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(controller);
    final canonicalSpaceId = coordinator?.session.navigation.selectedSpaceId;
    final ownership =
        CanonicalRoomSurfaceRuntimeRegistry.topologyOwnershipFor(controller);
    if (coordinator == null || canonicalSpaceId == null || ownership == null) {
      return false;
    }

    final legacySpace = controller.selectedSpace;
    final legacySpaceId =
        coordinator.adapter.binding.legacySpaceIds[canonicalSpaceId];
    if (legacySpace == null ||
        legacySpaceId == null ||
        legacySpace.id != legacySpaceId ||
        candidate.vertices.length != legacySpace.boundary.vertices.length) {
      return false;
    }

    final projection = CanonicalRoomSurfaceRuntimeRegistry.resolve(
      controller,
      canonicalSpaceId,
    );
    if (projection == null) return false;

    final changed = <int>[];
    for (var index = 0; index < candidate.vertices.length; index++) {
      if (candidate.vertices[index] != legacySpace.boundary.vertices[index]) {
        changed.add(index);
      }
    }
    if (changed.isEmpty) return true;

    final appSession = coordinator.session.boundaryTopologyEditing.begin(
      spaceId: canonicalSpaceId,
      expectedVersion: coordinator.session.project.version,
    );

    if (changed.length == 1) {
      final vertexIndex = changed.single;
      final outgoingEdgeId = projection.projection.edgeIdAtOrdinal(vertexIndex);
      if (!_vertexEditAllowed(controller, legacySpace, vertexIndex)) {
        return false;
      }
      final target = candidate.vertices[vertexIndex];
      appSession.previewMoveVertex(
        outgoingEdgeId: outgoingEdgeId,
        target: BoundaryPointMm(xMm: target.x, yMm: target.y),
      );
    } else if (changed.length == 2) {
      final edgeIndex = _parallelEdgeIndex(
        legacySpace.boundary,
        candidate,
        changed,
      );
      if (edgeIndex == null ||
          !_edgeEditAllowed(controller, legacySpace, edgeIndex)) {
        return false;
      }
      final edgeId = projection.projection.edgeIdAtOrdinal(edgeIndex);
      final distanceMm = _signedNormalDistance(
        appSession.previewTopology.edges[edgeId]!,
        legacySpace.boundary.vertices[edgeIndex],
        candidate.vertices[edgeIndex],
      );
      appSession.previewMoveEdgeNormal(edgeId: edgeId, distanceMm: distanceMm);
    } else {
      return false;
    }

    if (!_samePolygon(_toPolygon(appSession.previewTopology), candidate)) {
      return false;
    }

    final committed = appSession.commit();
    if (committed == null) return true;

    final history = controller.documentHistory;
    void rematerializeCurrentCanonicalState() {
      final topology =
          coordinator.session.project.index.boundary(canonicalSpaceId);
      if (topology == null) {
        throw StateError(
          'Canonical Space $canonicalSpaceId lost boundary topology during '
          'production history replay.',
        );
      }
      final materialized = history.runCanonicalProjection(
        () => materializeLegacy(_toPolygon(topology)),
      );
      if (!materialized) {
        throw StateError(
          'Canonical boundary state could not be materialized into the legacy '
          'editor. The P7A projection contract has been violated.',
        );
      }
    }

    history.recordCanonicalCommit(
      session: coordinator.session,
      label: 'Edit boundary topology',
      rematerialize: rematerializeCurrentCanonicalState,
    );

    try {
      ownership(
        coordinator.session.boundaryTopologyEditing,
        committed.mutation,
      );
    } finally {
      // Even a persistence-owner acknowledgement failure must not leave the
      // canonical aggregate and the visible legacy canvas divergent.
      rematerializeCurrentCanonicalState();
    }
    return true;
  }

  static bool _vertexEditAllowed(
    EditorController controller,
    EngineeringSpace space,
    int vertexIndex,
  ) {
    final count = space.boundary.vertices.length;
    final incoming = (vertexIndex - 1 + count) % count;
    return _isExternalWall(controller, space, incoming) &&
        _isExternalWall(controller, space, vertexIndex) &&
        !_hasUnsupportedHosts(controller, space, <int>{incoming, vertexIndex});
  }

  static bool _edgeEditAllowed(
    EditorController controller,
    EngineeringSpace space,
    int edgeIndex,
  ) =>
      _isExternalWall(controller, space, edgeIndex) &&
      !_hasUnsupportedHosts(controller, space, <int>{edgeIndex});

  static bool _isExternalWall(
    EditorController controller,
    EngineeringSpace space,
    int wallOrdinal,
  ) {
    final vertices = space.boundary.vertices;
    if (wallOrdinal < 0 || wallOrdinal >= vertices.length) return false;
    final a = vertices[wallOrdinal];
    final b = vertices[(wallOrdinal + 1) % vertices.length];

    for (final neighbor in controller.level.spaces) {
      if (neighbor.id == space.id) continue;
      final other = neighbor.boundary.vertices;
      for (var index = 0; index < other.length; index++) {
        final c = other[index];
        final d = other[(index + 1) % other.length];
        if (_collinearOverlap(a, b, c, d)) return false;
      }
    }
    return true;
  }

  /// Until P7A-5 migrates host ownership, any object whose correctness depends
  /// on the edited wall (or room floor/ceiling extent) blocks the canonical edit.
  static bool _hasUnsupportedHosts(
    EditorController controller,
    EngineeringSpace space,
    Set<int> affectedWallOrdinals,
  ) {
    if (space.wallProfiles.keys.any(affectedWallOrdinals.contains)) return true;
    for (final opening in controller.openings) {
      if (opening.hostWall.spaceId == space.id &&
          affectedWallOrdinals.contains(opening.hostWall.wallIndex)) {
        return true;
      }
    }
    for (final component in controller.p2.components) {
      if (component.surface.spaceId != space.id) continue;
      if (component.surface.type != SurfacePlaneType.wall ||
          affectedWallOrdinals.contains(component.surface.wallIndex)) {
        return true;
      }
    }
    for (final route in controller.p2.routes) {
      for (final segment in route.segments) {
        if (segment.surface.spaceId != space.id) continue;
        if (segment.surface.type != SurfacePlaneType.wall ||
            affectedWallOrdinals.contains(segment.surface.wallIndex)) {
          return true;
        }
      }
    }
    return false;
  }

  static int? _parallelEdgeIndex(
    MmPolygon before,
    MmPolygon after,
    List<int> changed,
  ) {
    final count = before.vertices.length;
    for (final index in changed) {
      final next = (index + 1) % count;
      if (!changed.contains(next)) continue;
      final beforeA = before.vertices[index];
      final afterA = after.vertices[index];
      final beforeB = before.vertices[next];
      final afterB = after.vertices[next];
      final deltaAx = afterA.x - beforeA.x;
      final deltaAy = afterA.y - beforeA.y;
      final deltaBx = afterB.x - beforeB.x;
      final deltaBy = afterB.y - beforeB.y;
      if (deltaAx == deltaBx && deltaAy == deltaBy) return index;
    }
    return null;
  }

  static int _signedNormalDistance(
    ProjectBoundaryEdge edge,
    MmPoint legacyStart,
    MmPoint candidateStart,
  ) {
    final dx = (edge.end.xMm - edge.start.xMm).toDouble();
    final dy = (edge.end.yMm - edge.start.yMm).toDouble();
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return 0;
    final moveX = (candidateStart.x - legacyStart.x).toDouble();
    final moveY = (candidateStart.y - legacyStart.y).toDouble();
    return (moveX * (-dy / length) + moveY * (dx / length)).round();
  }

  static MmPolygon _toPolygon(SpaceBoundaryTopology topology) => MmPolygon(
        <MmPoint>[
          for (final edgeId in topology.orderedEdgeIds)
            MmPoint(
              topology.edges[edgeId]!.start.xMm,
              topology.edges[edgeId]!.start.yMm,
            ),
        ],
      );

  static bool _samePolygon(MmPolygon left, MmPolygon right) {
    if (left.vertices.length != right.vertices.length) return false;
    for (var index = 0; index < left.vertices.length; index++) {
      if (left.vertices[index] != right.vertices[index]) return false;
    }
    return true;
  }

  static bool _collinearOverlap(MmPoint a, MmPoint b, MmPoint c, MmPoint d) {
    int cross(MmPoint p, MmPoint q, MmPoint r) =>
        (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    if (cross(a, b, c) != 0 || cross(a, b, d) != 0) return false;
    final useX = (b.x - a.x).abs() >= (b.y - a.y).abs();
    int axis(MmPoint point) => useX ? point.x : point.y;
    final aMin = math.min(axis(a), axis(b));
    final aMax = math.max(axis(a), axis(b));
    final bMin = math.min(axis(c), axis(d));
    final bMax = math.max(axis(c), axis(d));
    return math.min(aMax, bMax) > math.max(aMin, bMin);
  }
}
