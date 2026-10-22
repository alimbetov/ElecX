import '../../application/project/project_boundary_topology_migration.dart';
import '../../domain/boundary_host_migration.dart';
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
  /// Resolves a transient legacy wall ordinal through a fresh version-aware
  /// canonical projection. The returned BoundaryEdgeId is the only identity
  /// accepted by the mutation methods below.
  static BoundaryEdgeId? edgeIdAtLegacyWallOrdinal(
    EditorController controller,
    int wallOrdinal,
  ) {
    final context = _context(controller);
    if (context == null) return null;
    final adapter = CanonicalRoomSurfaceRuntimeRegistry.resolve(
      controller,
      context.spaceId,
    );
    if (adapter == null || !adapter.isMaterializationCurrent) return null;
    if (wallOrdinal < 0 || wallOrdinal >= adapter.projection.wallCount) {
      return null;
    }
    return adapter.projection.edgeIdAtOrdinal(wallOrdinal);
  }

  /// True only when the currently materialized legacy hosts exactly match the
  /// canonical P7A-5 registries for this wall's room. UI may expose split/merge
  /// only after this condition is proven.
  static bool canChangeLegacyWallIdentity(
    EditorController controller,
    int wallOrdinal,
  ) {
    final context = _context(controller);
    final edgeId = edgeIdAtLegacyWallOrdinal(controller, wallOrdinal);
    if (context == null || edgeId == null) return false;
    final topology = context.coordinator.session.project.index.boundary(
      context.spaceId,
    );
    if (topology == null || topology.edges[edgeId] == null) return false;
    try {
      _requireExactCanonicalHostAdoption(
        controller: controller,
        context: context,
        sourceTopology: topology,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns an exact integer-mm split point nearest the geometric midpoint.
  ///
  /// Canonical boundary coordinates are integer millimetres. A diagonal edge
  /// whose delta components are coprime has no interior lattice point at all;
  /// such an edge cannot be split losslessly without introducing sub-mm
  /// coordinates, so this helper deliberately returns null instead of rounding
  /// a point off the segment.
  static BoundaryPointMm? representableInteriorSplitPoint(
    ProjectBoundaryEdge edge,
  ) {
    final dx = edge.end.xMm - edge.start.xMm;
    final dy = edge.end.yMm - edge.start.yMm;
    final latticeSteps = _gcd(dx.abs(), dy.abs());
    if (latticeSteps <= 1) return null;

    final stepX = dx ~/ latticeSteps;
    final stepY = dy ~/ latticeSteps;
    final midpointStep = latticeSteps ~/ 2;
    return BoundaryPointMm(
      xMm: edge.start.xMm + stepX * midpointStep,
      yMm: edge.start.yMm + stepY * midpointStep,
    );
  }

  /// Split readiness includes both canonical-host adoption and exact geometric
  /// representability in the integer-mm topology model.
  static bool canSplitLegacyWall(
    EditorController controller,
    int wallOrdinal,
  ) {
    if (!canChangeLegacyWallIdentity(controller, wallOrdinal)) return false;
    final context = _context(controller);
    final edgeId = edgeIdAtLegacyWallOrdinal(controller, wallOrdinal);
    if (context == null || edgeId == null) return false;
    final edge = context.coordinator.session.project.index.boundaryEdge(edgeId);
    return edge != null && representableInteriorSplitPoint(edge) != null;
  }

  /// UI convenience that resolves transient ordinal -> BoundaryEdgeId first,
  /// then delegates to the exact same stable-id split path used by all inputs.
  /// The chosen point is the nearest exact integer-mm lattice point to midpoint.
  static bool splitLegacyWallAtMidpoint({
    required EditorController controller,
    required int wallOrdinal,
    EntityIdFactory? idFactory,
  }) {
    final context = _context(controller);
    final edgeId = edgeIdAtLegacyWallOrdinal(controller, wallOrdinal);
    if (context == null || edgeId == null) return false;
    final edge = context.coordinator.session.project.index.boundaryEdge(edgeId);
    if (edge == null) return false;
    final splitPoint = representableInteriorSplitPoint(edge);
    if (splitPoint == null) return false;
    try {
      return splitEdge(
        controller: controller,
        edgeId: edgeId,
        splitPoint: splitPoint,
        idFactory: idFactory,
      );
    } on BoundaryTopologyMigrationException {
      return false;
    } on BoundaryHostMigrationException {
      return false;
    } on StateError {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  /// UI convenience that resolves transient ordinal -> BoundaryEdgeId first,
  /// then delegates to the canonical stable-id merge path.
  static bool mergeLegacyWallWithNext({
    required EditorController controller,
    required int wallOrdinal,
    EntityIdFactory? idFactory,
  }) {
    final edgeId = edgeIdAtLegacyWallOrdinal(controller, wallOrdinal);
    if (edgeId == null) return false;
    try {
      return mergeEdgeWithNext(
        controller: controller,
        edgeId: edgeId,
        idFactory: idFactory,
      );
    } on BoundaryTopologyMigrationException {
      return false;
    } on BoundaryHostMigrationException {
      return false;
    } on StateError {
      return false;
    } on ArgumentError {
      return false;
    }
  }

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
        showPlanAfter: false,
      );
    }

    try {
      context.owner(result);
      controller.documentHistory.recordCanonicalCommit(
        session: context.coordinator.session,
        label: 'Adopt stable boundary hosts',
        rematerialize: rematerializeCurrentCanonicalState,
      );
    } catch (_) {
      controller.documentHistory.invalidateAfterUnownedCanonicalCommit(
        context.coordinator.session,
      );
      rethrow;
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
    final next =
        topology.orderedEdgeIds[(index + 1) % topology.orderedEdgeIds.length];
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
        showPlanAfter: true,
      );
    }

    try {
      context.owner(committed.mutation);
      controller.documentHistory.recordCanonicalCommit(
        session: context.coordinator.session,
        label: label,
        rematerialize: rematerializeCurrentCanonicalState,
      );
    } catch (_) {
      controller.documentHistory.invalidateAfterUnownedCanonicalCommit(
        context.coordinator.session,
      );
      rethrow;
    } finally {
      rematerializeCurrentCanonicalState();
    }
    return true;
  }

  static void _materialize({
    required EditorController controller,
    required _MigrationContext context,
    required EditorP2State sourceP2,
    required bool showPlanAfter,
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
    if (showPlanAfter) controller.showPlan();
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
    final capturedProfiles =
        CanonicalBoundaryHostProjection.captureWallProfiles(
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
      for (final entry in project
          .engineeringMetadata.boundaryWallProfileRegistry.profiles.entries)
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
    if (legacySpaceId == null ||
        controller.selectedSpace?.id != legacySpaceId) {
      return null;
    }
    return _MigrationContext(
      coordinator: coordinator,
      spaceId: spaceId,
      owner: owner,
    );
  }
}

int _gcd(int a, int b) {
  var left = a;
  var right = b;
  while (right != 0) {
    final remainder = left % right;
    left = right;
    right = remainder;
  }
  return left;
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
