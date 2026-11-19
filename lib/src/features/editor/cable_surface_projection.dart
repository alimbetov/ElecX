import '../../domain/surfaces.dart';
import 'canonical_room_boundary_projection.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';

/// Resolves a durable route host to its verified local canvas plane.
abstract final class CableSurfaceProjection {
  static RoomSurfaceRef? local(
      EditorController controller, RoomSurfaceRef host) {
    final physical =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(
            controller);
    if (physical == null) return host.isCanonicalWall ? null : host;
    final canonical = physical.canonicalSpaceIdForSurfaceSpaceId(host.spaceId);
    if (canonical == null) return null;
    final legacy = physical.legacySpaceIdForCanonical(canonical);
    if (legacy == null) return null;
    if (host.type == SurfacePlaneType.ceiling) {
      return RoomSurfaceRef.ceiling(legacy);
    }
    if (host.type == SurfacePlaneType.floor) {
      return RoomSurfaceRef.floor(legacy);
    }
    if (host.boundaryEdgeId == null) {
      return RoomSurfaceRef.wall(legacy, host.wallIndex!);
    }
    final topology = physical.project.index.boundary(canonical);
    final spaces = controller.level.spaces.where((s) => s.id == legacy);
    if (topology == null || spaces.length != 1) return null;
    try {
      final projection = CanonicalRoomBoundaryProjection.build(
        canonicalSpaceId: canonical,
        legacySpaceId: legacy,
        canonicalTopology: topology,
        legacySpace: spaces.single,
      );
      final index = projection.orderedEdgeIds.indexOf(host.boundaryEdgeId!);
      return index < 0 ? null : RoomSurfaceRef.wall(legacy, index);
    } on CanonicalRoomBoundaryProjectionException {
      return null;
    }
  }

  static bool same(
          EditorController controller, RoomSurfaceRef a, RoomSurfaceRef b) =>
      a == b ||
      (local(controller, a) != null &&
          local(controller, a) == local(controller, b));
}
