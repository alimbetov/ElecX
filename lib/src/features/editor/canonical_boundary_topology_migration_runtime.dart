import '../../application/project/project_boundary_topology_migration.dart';
import '../../domain/boundary_host_registry.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/boundary_wall_profile_registry.dart';
import '../../domain/project_identity.dart';
import '../../domain/route_anchor_identity_migration.dart';
import '../../domain/surfaces.dart';
import 'canonical_boundary_host_materialization.dart';
import 'canonical_boundary_host_projection.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'canonical_route_anchor_rehydration.dart';
import 'editor_controller.dart';
import 'editor_document_history.dart';
import 'editor_p2_session.dart';

/// Production P7A-5 gateway for canonical hosted-object adoption and
/// identity-changing boundary topology edits.
///
/// Pointer modality is intentionally absent. Mouse/touch/stylus/keyboard/menu
/// actions normalize to these stable-id operations before entering the runtime.
abstract final class CanonicalBoundaryTopologyMigrationRuntime {
  /// One-time migration of the exact currently materialized legacy room hosts
  /// into canonical P7A-5 ownership. Route point identities are allocated
  /// explicitly; no segment/point ordinal becomes durable identity.
  static bool adoptLegacyHosts({
    required EditorController controller,
    EntityIdFactory? idFactory,
  }) {
    final context = _context(controller);
    if (context == null) return false;
    final project = context.coordinator.session.project;
    final topology = project.index.boundary(context.spaceId);
    final legacySpace = controller.selectedSpace;
    if (topology == null || legacySpace == null) return false;

    if (context.coordinator.session.boundaryHostAdoption
        .hasCanonicalHosts(context.spaceId)) {
      _requireExactCanonicalHostAdoption(
        controller: controller,
        context: context,
        sourceTopology: topology,
      );
      return true;
    }

    final ids = idFactory ?? SecureRandomEntityIdFactory();
    final migratedRoutes = [
      for (final route in controller.p2.state.routes)
        if (route.segments.any(
          (segment) =>
              segment.surface.spaceId == legacySpace.id &&
              segment.surface.type == SurfacePlaneType.wall,
        ))
          RouteAnchorIdentityMigration.migrate(route, ids)
        else
          route,
    ];
    final p2Candidate = controller.p2.state.copyWith(
      routes: List.unmodifiable(migratedRoutes),
    );
    final hosts = CanonicalBoundaryHostProjection.capture(
      canonicalSpaceId: context.spaceId,
      legacySpace: legacySpace,
      orderedEdgeIds: topology.orderedEdgeIds,
      openings: controller.openings,
      p2State: p2Candidate,
    );
    final profiles = CanonicalBoundaryHostProjection.captureWallProfiles(
      canonicalSpaceId: context.spaceId,
      legacySpace: legacySpace,
      orderedEdgeIds: topology.orderedEdgeIds,
    );

    final result = context.coordinator.session.boundaryHostAdoption.adopt(
      spaceId: context.spaceId,
      expectedVersion: project.version,
      hostedObjects: hosts,
      wallProfiles: profiles,
    );
    if (result == null) return true;

    void rematerializeCurrentCanonicalState() {
      _materialize(
        controller: controller,
        context: context,
        sourceP2: p2Candidate,
      );
    }

    controller.documentHistory.recordCanonicalCommit(
      session: context.coordinator.session,
      label: 'Adopt stable boundary hosts',
      rematerialize: rematerializeCurrentCanonicalState,
    );
    try {
      context.owner(result);
    } finally {
      rematerializeCurrentCanonicalState();
    }
    return true;
  }

  static bool splitEdge({
    required EditorController controller,
    required BoundaryEdgeId edgeId,
    required BoundaryPointMm splitPoint,
    EntityIdFactory? idFactory,
  }) {
    final context = _context(controller);
    if (context == null) return false;
    final ids = idFactory ?? SecureRandomEntityIdFactory();
    final edit = context.coordinator.session.boundaryTopologyMigration.begin(
      spaceId: context.spaceId,
      expectedVersion: context.coordinator.session.project.version,
    );
    edit.previewSplitEdge(
      sourceEdgeId: edgeId,
      splitPoint: splitPoint,
      firstResultEdgeId: ids.newBoundaryEdgeId(),
      secondResultEdgeId: ids.newBoundaryEdgeId(),
    );
    return _commit(
      controller: controller,
      context: context,
      edit: edit,
      label: 'Split boundary edge',
    );
  }

  static bool mergeEdgeWithNext({
    required EditorController controller,
    required BoundaryEdgeId edgeId,
    EntityIdFactory? idFactory,
  }) {
    final context = _context(controller);
    if (context == null) return false;
    final topology = context.coordinator.session.project.index.boundary(
      context.spaceId,
    );
    if (topology == null) return false;
    final index = topology.orderedEdgeIds.indexOf(edgeId);
    if (index < 0) return false;
    final next = topology
        .orderedEdgeIds[(index + 1) % topology.orderedEdgeIds.length];
    final ids = idFactory ?? SecureRandomEntityIdFactory();
    final edit = context.coordinator.session.boundaryTopologyMigration.begin(
      spaceId: context.spaceId,
      expectedVersion: context.coordinator.session.project.version,
    );
    edit.previewMergeAdjacentEdges(
      firstSourceEdgeId: edgeId,
      secondSourceEdgeId: next,
      resultEdgeId: ids.newBoundaryEdgeId(),
    );
    return _commit(
      controller: controller,
      context: context,
      edit: edit,
      label: 'Merge boundary edges',
    );
  }

  /// Production path for create/remove-capable topology tools. The caller must
  /// provide complete lineage; this runtime performs the same adoption,
  /// ownership, history and rematerialization checks as split/merge.
  static bool replaceTopology({
    required EditorController controller,
    required SpaceBoundaryTopology topology,
    required BoundaryTopologyChangeSet lineage,
    BoundaryWallProfileRegistry? wallProfiles,
    String label = 'Edit boundary topology',
  }) {
    final context = _context(controller);
    if (context == null) return false;
    final edit = context.coordinator.session.boundaryTopologyMigration.begin(
      spaceId: context.spaceId,
      expectedVersion: context.coordinator.session.project.version,
    );
    edit.previewReplaceTopology(
      topology: topology,
      lineage: lineage,
      wallProfiles: wallProfiles,
    );
    return _commit(
      controller: controller,
      context: context,
      edit: edit,
      label: label,
    );
  }

  static bool _commit({
    required EditorController controller,
    required _MigrationContext context,
    required CanonicalBoundaryTopologyMigrationSession edit,
    required String label,
  }) {
    final sourceTopology = context.coordinator.session.project.index.boundary(
      context.spaceId,
    );
    if (sourceTopology == null) return false;
    final sourceP2 = _requireExactCanonicalHostAdoption(
      controller: controller,
      context: context,
      sourceTopology: sourceTopology,
    );

    final committed = edit.commit();
    if (committed == null) return true;

    void rematerializeCurrentCanonicalState() {
      _materialize(
        controller: controller,
        context: context,
        sourceP2: sourceP2,
      );
    }

    controller.documentHistory.recordCanonicalCommit(
      session: context.coordinator.session,
      label: label,
      rematerialize: rematerializeCurrentCanonicalState,
    );
    try {
      context.owner(committed.mutation);
    } finally {
      rematerializeCurrentCanonicalState();
    }
    return true;
  }

  static void _materialize({
    required EditorController controller,
    required _MigrationContext context,
    required EditorP2State sourceP2,
  }) {
    final project = context.coordinator.session.project;
    final topology = project.index.boundary(context.spaceId);
    final legacySpace = controller.selectedSpace;
    if (topology == null || legacySpace == null) {
      throw StateError(
        'P7A-5 history replay lost selected room/topology affinity.',
      );
    }
    final materialization = CanonicalBoundaryHostProjection.materializeTopology(
      canonicalSpaceId: context.spaceId,
      legacySpace: legacySpace,
      topology: topology,
      registry: project.engineeringMetadata.boundaryHostedObjectRegistry,
      wallProfiles: project.engineeringMetadata.boundaryWallProfileRegistry,
      openings: controller.openings,
      p2State: sourceP2,
    );
    CanonicalBoundaryHostMaterializer.apply(
      controller,
      controller.p2,
      materialization,
    );
  }

  static EditorP2State _requireExactCanonicalHostAdoption({
    required EditorController controller,
    required _MigrationContext context,
    required SpaceBoundaryTopology sourceTopology,
  }) {
    final legacySpace = controller.selectedSpace;
    if (legacySpace == null) {
      throw StateError('P7A-5 migration requires a selected legacy room.');
    }
    final project = context.coordinator.session.project;
    final canonicalRegistry =
        project.engineeringMetadata.boundaryHostedObjectRegistry;
    final p2 = CanonicalRouteAnchorRehydration.rehydrate(
      p2State: controller.p2.state,
      legacySpace: legacySpace,
      canonicalSpaceId: context.spaceId,
      orderedEdgeIds: sourceTopology.orderedEdgeIds,
      registry: canonicalRegistry,
    );
    final capturedHosts = CanonicalBoundaryHostProjection.capture(
      canonicalSpaceId: context.spaceId,
      legacySpace: legacySpace,
      orderedEdgeIds: sourceTopology.orderedEdgeIds,
      openings: controller.openings,
      p2State: p2,
    );
    final capturedProfiles = CanonicalBoundaryHostProjection.captureWallProfiles(
      canonicalSpaceId: context.spaceId,
      legacySpace: legacySpace,
      orderedEdgeIds: sourceTopology.orderedEdgeIds,
    );

    final canonicalHosts = BoundaryHostedObjectRegistry({
      for (final reference in canonicalRegistry.forSpace(context.spaceId))
        reference.objectKey: reference,
    });
    final projectedHosts = BoundaryHostedObjectRegistry({
      for (final reference in capturedHosts.forSpace(context.spaceId))
        reference.objectKey: reference,
    });
    final canonicalProfiles = BoundaryWallProfileRegistry({
      for (final entry in project.engineeringMetadata.boundaryWallProfileRegistry
          .profiles.entries)
        if (entry.key.spaceId == context.spaceId) entry.key: entry.value,
    });
    final projectedProfiles = BoundaryWallProfileRegistry({
      for (final entry in capturedProfiles.profiles.entries)
        if (entry.key.spaceId == context.spaceId) entry.key: entry.value,
    });
    if (!canonicalHosts.sameAs(projectedHosts) ||
        !canonicalProfiles.sameAs(projectedProfiles)) {
      throw StateError(
        'Legacy hosted objects for ${context.spaceId} have not been adopted '
        'exactly into canonical P7A-5 ownership.',
      );
    }
    return p2;
  }

  static _MigrationContext? _context(EditorController controller) {
    final coordinator =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(controller);
    final owner = CanonicalRoomSurfaceRuntimeRegistry.canonicalOwnershipFor(
      controller,
    );
    final spaceId = coordinator?.session.navigation.selectedSpaceId;
    if (coordinator == null || owner == null || spaceId == null) return null;
    final legacySpaceId = coordinator.adapter.binding.legacySpaceIds[spaceId];
    if (legacySpaceId == null || controller.selectedSpace?.id != legacySpaceId) {
      return null;
    }
    return _MigrationContext(
      coordinator: coordinator,
      spaceId: spaceId,
      owner: owner,
    );
  }
}

final class _MigrationContext {
  const _MigrationContext({
    required this.coordinator,
    required this.spaceId,
    required this.owner,
  });

  final CanonicalEditorRuntimeCutoverCoordinator coordinator;
  final SpaceId spaceId;
  final CanonicalMutationOwnershipCallback owner;
}
