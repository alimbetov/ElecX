import '../../application/project/project_structure_authoring.dart';
import '../../domain/boundary_construction_registry.dart';
import '../../domain/boundary_host_migration.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'canonical_wall_construction_runtime.dart';
import 'editor_controller.dart';

final class CanonicalWallConstructionEditConflictException
    implements Exception {
  const CanonicalWallConstructionEditConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Immutable optimistic-concurrency baseline for one wall-construction draft.
///
/// A draft is owned by an exact canonical authoring session and stable
/// [BoundaryEdgeId], not by the currently visible legacy wall ordinal. Any
/// canonical version advance invalidates the captured expectedVersion and must
/// be resolved explicitly before the draft can be saved.
final class CanonicalWallConstructionEditBaseline {
  const CanonicalWallConstructionEditBaseline._({
    required this.session,
    required this.expectedVersion,
    required this.spaceId,
    required this.edgeId,
    required this.profile,
  });

  final ProjectStructureAuthoringSession session;
  final LocalProjectVersion expectedVersion;
  final SpaceId spaceId;
  final BoundaryEdgeId edgeId;
  final BoundaryConstructionProfile? profile;

  BoundaryEdgeHostRef get host =>
      BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId);

  bool sameTarget(CanonicalWallConstructionEditBaseline other) =>
      identical(session, other.session) &&
      spaceId == other.spaceId &&
      edgeId == other.edgeId;
}

/// Shared edit contract used by every wall-construction presentation.
///
/// The UI may be inline, modal or any future presentation, but saving always
/// goes through the same captured host/version/session preconditions. This
/// prevents a dirty draft from following selection or session changes and
/// prevents a stale form from silently overwriting a newer canonical profile.
abstract final class CanonicalWallConstructionEditContract {
  static CanonicalWallConstructionEditBaseline? capture(
    EditorController controller,
  ) {
    final coordinator =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(controller);
    final wall = CanonicalWallConstructionRuntime.activeWall(controller);
    if (coordinator == null || wall == null) return null;

    final session = coordinator.session;
    if (session.navigation.selectedSpaceId != wall.spaceId) return null;
    final edge = session.project.index.boundaryEdge(wall.edgeId);
    if (edge == null || edge.spaceId != wall.spaceId) return null;

    return CanonicalWallConstructionEditBaseline._(
      session: session,
      expectedVersion: session.project.version,
      spaceId: wall.spaceId,
      edgeId: wall.edgeId,
      profile: wall.profile,
    );
  }

  static bool isCurrent({
    required EditorController controller,
    required CanonicalWallConstructionEditBaseline baseline,
  }) {
    try {
      _requireCurrent(controller: controller, baseline: baseline);
      return true;
    } on CanonicalWallConstructionEditConflictException {
      return false;
    }
  }

  static CanonicalWallConstructionEditBaseline save({
    required EditorController controller,
    required CanonicalWallConstructionEditBaseline baseline,
    required BoundaryConstructionProfile profile,
  }) {
    _requireCurrent(controller: controller, baseline: baseline);

    final saved = CanonicalWallConstructionRuntime.setActiveWallConstruction(
      controller: controller,
      thicknessMm: profile.thicknessMm,
      materialId: profile.materialId,
      fireRatingId: profile.fireRatingId,
    );
    if (!saved) {
      throw const CanonicalWallConstructionEditConflictException(
        'Wall construction target is no longer available for this edit.',
      );
    }

    final refreshed = capture(controller);
    if (refreshed == null ||
        !identical(refreshed.session, baseline.session) ||
        refreshed.spaceId != baseline.spaceId ||
        refreshed.edgeId != baseline.edgeId) {
      throw const CanonicalWallConstructionEditConflictException(
        'Wall construction changed target while the edit was being saved.',
      );
    }
    return refreshed;
  }

  static void _requireCurrent({
    required EditorController controller,
    required CanonicalWallConstructionEditBaseline baseline,
  }) {
    final coordinator =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(controller);
    if (coordinator == null) {
      throw const CanonicalWallConstructionEditConflictException(
        'Canonical wall editing is no longer available.',
      );
    }

    final session = coordinator.session;
    if (!identical(session, baseline.session)) {
      throw const CanonicalWallConstructionEditConflictException(
        'The project editing session changed while this wall form was open.',
      );
    }
    if (session.project.version != baseline.expectedVersion) {
      throw CanonicalWallConstructionEditConflictException(
        'The canonical project advanced from version '
        '${baseline.expectedVersion} to ${session.project.version}.',
      );
    }
    if (session.navigation.selectedSpaceId != baseline.spaceId) {
      throw const CanonicalWallConstructionEditConflictException(
        'The selected canonical space changed while this wall form was open.',
      );
    }

    final edge = session.project.index.boundaryEdge(baseline.edgeId);
    if (edge == null || edge.spaceId != baseline.spaceId) {
      throw const CanonicalWallConstructionEditConflictException(
        'The edited BoundaryEdgeId is no longer active on the captured space.',
      );
    }

    final active = CanonicalWallConstructionRuntime.activeWall(controller);
    if (active == null ||
        active.spaceId != baseline.spaceId ||
        active.edgeId != baseline.edgeId) {
      throw const CanonicalWallConstructionEditConflictException(
        'The active wall changed while this wall form was open.',
      );
    }

    final currentProfile = session.project.engineeringMetadata
        .boundaryConstructionRegistry[baseline.host];
    if (currentProfile != baseline.profile) {
      throw const CanonicalWallConstructionEditConflictException(
        'The wall construction changed outside this form.',
      );
    }
  }
}
