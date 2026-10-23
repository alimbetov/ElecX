import 'dart:math' as math;

import '../../application/project/project_mutation.dart';
import '../../domain/boundary_construction_registry.dart';
import '../../domain/boundary_host_migration.dart';
import '../../domain/boundary_penetration.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/project_identity.dart';
import '../../domain/surfaces.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';
import 'editor_document_history.dart';
import 'editor_p2_session.dart';

final class CanonicalWallConstructionView {
  const CanonicalWallConstructionView({
    required this.spaceId,
    required this.edgeId,
    required this.profile,
  });

  final SpaceId spaceId;
  final BoundaryEdgeId edgeId;
  final BoundaryConstructionProfile? profile;
}

final class CanonicalWallConstructionEditException implements Exception {
  const CanonicalWallConstructionEditException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Production authoring gateway for physical wall thickness/material.
///
/// One user edit is one canonical mutation. Existing wall penetrations that
/// explicitly prove the opposite face of the same physical wall are updated in
/// the same logical document operation, and any sizing evidence for affected
/// routes is invalidated. Geometry alone is never used to guess shared-wall
/// ownership.
abstract final class CanonicalWallConstructionRuntime {
  static CanonicalWallConstructionView? activeWall(
    EditorController controller,
  ) {
    final context = _context(controller);
    if (context == null) return null;
    final host = _hostForSurface(context, controller.activeSurface);
    if (host == null || host.spaceId != context.spaceId) return null;
    final edge = context.coordinator.session.project.index.boundaryEdge(
      host.edgeId,
    );
    if (edge == null || edge.spaceId != host.spaceId) return null;
    return CanonicalWallConstructionView(
      spaceId: host.spaceId,
      edgeId: host.edgeId,
      profile: context.coordinator.session.project.engineeringMetadata
          .boundaryConstructionRegistry[host],
    );
  }

  static bool setActiveWallConstruction({
    required EditorController controller,
    required int thicknessMm,
    required String materialId,
    String? fireRatingId,
  }) {
    final context = _context(controller);
    final current = activeWall(controller);
    if (context == null || current == null) return false;

    final profile = BoundaryConstructionProfile(
      kind: BoundaryConstructionKind.wall,
      thicknessMm: thicknessMm,
      materialId: materialId.trim(),
      fireRatingId: _normalizeOptional(fireRatingId),
    );
    final target = BoundaryEdgeHostRef(
      spaceId: current.spaceId,
      edgeId: current.edgeId,
    );
    final linkedHosts = _linkedPhysicalWallHosts(
      controller: controller,
      context: context,
      target: target,
    );
    final beforeProject = context.coordinator.session.project;
    final beforeRegistry =
        beforeProject.engineeringMetadata.boundaryConstructionRegistry;
    var prospectiveRegistry = beforeRegistry;
    for (final host in linkedHosts) {
      prospectiveRegistry = prospectiveRegistry.put(host, profile);
    }

    final beforeP2 = controller.p2.state;
    final afterP2 = _revalidatedP2State(
      context: context,
      source: beforeP2,
      registry: prospectiveRegistry,
      changedHosts: linkedHosts,
    );

    final result = context.coordinator.session.boundaryConstructionEditing
        .setWallConstructions(
      profiles: {for (final host in linkedHosts) host: profile},
      expectedVersion: beforeProject.version,
    );
    if (result == null) return true;

    void projectP2ForCurrentCanonicalState() {
      final currentRegistry = context.coordinator.session.project
          .engineeringMetadata.boundaryConstructionRegistry;
      final useAfter = _profilesEqual(
        currentRegistry,
        prospectiveRegistry,
        linkedHosts,
      );
      final useBefore = _profilesEqual(
        currentRegistry,
        beforeRegistry,
        linkedHosts,
      );
      if (!useAfter && !useBefore) {
        throw StateError(
          'Wall construction history cannot identify the expected P2 projection.',
        );
      }
      _applyCanonicalP2Projection(
        controller,
        useAfter ? afterP2 : beforeP2,
      );
    }

    _finishCommittedTransition(
      controller: controller,
      context: context,
      result: result,
      rematerialize: projectP2ForCurrentCanonicalState,
    );
    return true;
  }

  static Set<BoundaryEdgeHostRef> _linkedPhysicalWallHosts({
    required EditorController controller,
    required _ConstructionContext context,
    required BoundaryEdgeHostRef target,
  }) {
    final result = <BoundaryEdgeHostRef>{target};
    for (final route in controller.p2.routes) {
      for (final penetration in route.penetrations) {
        if (penetration.hostKind != BoundaryPenetrationHostKind.wall) continue;
        final entry = _hostForSurface(context, penetration.entryAnchor.surface);
        final exit = _hostForSurface(context, penetration.exitAnchor.surface);
        if (entry != target && exit != target) continue;
        if (entry != null) result.add(entry);
        if (exit != null) result.add(exit);
      }
    }
    return Set.unmodifiable(result);
  }

  static EditorP2State _revalidatedP2State({
    required _ConstructionContext context,
    required EditorP2State source,
    required BoundaryConstructionRegistry registry,
    required Set<BoundaryEdgeHostRef> changedHosts,
  }) {
    final affectedRouteIds = <String>{};
    final routes = <ElectricalCableRoute>[];

    for (final route in source.routes) {
      var routeChanged = false;
      final penetrations = <BoundaryPenetration>[];
      for (final penetration in route.penetrations) {
        final entryHost = _hostForSurface(
          context,
          penetration.entryAnchor.surface,
        );
        final exitHost = _hostForSurface(
          context,
          penetration.exitAnchor.surface,
        );
        final touched =
            (entryHost != null && changedHosts.contains(entryHost)) ||
                (exitHost != null && changedHosts.contains(exitHost));
        if (!touched) {
          penetrations.add(penetration);
          continue;
        }
        if (penetration.hostKind != BoundaryPenetrationHostKind.wall) {
          throw const CanonicalWallConstructionEditException(
            'Wall construction change cannot rewrite a non-wall penetration.',
          );
        }

        final entryProfile = entryHost == null ? null : registry[entryHost];
        final exitProfile = exitHost == null ? null : registry[exitHost];
        if (entryProfile != null &&
            exitProfile != null &&
            entryProfile != exitProfile) {
          throw CanonicalWallConstructionEditException(
            'Opposite penetration faces ${entryHost!.edgeId} and '
            '${exitHost!.edgeId} have different physical construction.',
          );
        }
        final profile = entryProfile ?? exitProfile;
        if (profile == null || profile.kind != BoundaryConstructionKind.wall) {
          throw CanonicalWallConstructionEditException(
            'Physical construction is missing for penetration '
            '${penetration.id}.',
          );
        }

        final angleFactor =
            penetration.pathLengthMm / penetration.hostThicknessMm;
        final nextPathLength = math.max(
          profile.thicknessMm.toDouble(),
          profile.thicknessMm * angleFactor,
        );
        penetrations.add(
          BoundaryPenetration(
            id: penetration.id,
            hostKind: penetration.hostKind,
            entryAnchor: penetration.entryAnchor,
            exitAnchor: penetration.exitAnchor,
            hostThicknessMm: profile.thicknessMm,
            pathLengthMm: nextPathLength,
            materialId: profile.materialId,
          ),
        );
        routeChanged = true;
      }

      if (routeChanged) {
        affectedRouteIds.add(route.id);
        routes
            .add(route.copyWith(penetrations: List.unmodifiable(penetrations)));
      } else {
        routes.add(route);
      }
    }

    if (affectedRouteIds.isEmpty) return source;
    final sizingEvidence = Map.of(source.sizingEvidenceByRoute)
      ..removeWhere((routeId, _) => affectedRouteIds.contains(routeId));
    return source.copyWith(
      routes: List.unmodifiable(routes),
      sizingEvidenceByRoute: Map.unmodifiable(sizingEvidence),
    );
  }

  static void _applyCanonicalP2Projection(
    EditorController controller,
    EditorP2State state,
  ) {
    controller.documentHistory.runCanonicalProjection(() {
      controller.p2.history.replaceState(
        state,
        clearHistory: false,
        countAsProjection: true,
      );
      // The projection revision makes dirty/autosave listeners observe the new
      // route payload without manufacturing a second P2 undo command.
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      controller.p2.notifyListeners();
    });
  }

  static bool _profilesEqual(
    BoundaryConstructionRegistry left,
    BoundaryConstructionRegistry right,
    Iterable<BoundaryEdgeHostRef> hosts,
  ) {
    for (final host in hosts) {
      if (left[host] != right[host]) return false;
    }
    return true;
  }

  static BoundaryEdgeHostRef? _hostForSurface(
    _ConstructionContext context,
    RoomSurfaceRef? surface,
  ) {
    if (surface == null || surface.type != SurfacePlaneType.wall) return null;
    final canonicalSpaceId =
        context.physical.canonicalSpaceIdForLegacy(surface.spaceId) ??
            (context.coordinator.session.project.index.space(
                      SpaceId(surface.spaceId),
                    ) !=
                    null
                ? SpaceId(surface.spaceId)
                : null);
    if (canonicalSpaceId == null) return null;
    final direct = surface.boundaryEdgeId;
    if (direct != null) {
      final edge =
          context.coordinator.session.project.index.boundaryEdge(direct);
      if (edge == null || edge.spaceId != canonicalSpaceId) return null;
      return BoundaryEdgeHostRef(spaceId: canonicalSpaceId, edgeId: direct);
    }
    final ordinal = surface.wallIndex;
    final ordered = context.physical.edgeOrderForLegacySpace(surface.spaceId);
    if (ordinal == null ||
        ordered == null ||
        ordinal < 0 ||
        ordinal >= ordered.length) {
      return null;
    }
    return BoundaryEdgeHostRef(
      spaceId: canonicalSpaceId,
      edgeId: ordered[ordinal],
    );
  }

  static _ConstructionContext? _context(EditorController controller) {
    final coordinator =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(controller);
    final owner = CanonicalRoomSurfaceRuntimeRegistry.canonicalOwnershipFor(
      controller,
    );
    final physical =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(
            controller);
    final spaceId = coordinator?.session.navigation.selectedSpaceId;
    if (coordinator == null ||
        owner == null ||
        physical == null ||
        spaceId == null) {
      return null;
    }
    final legacySpaceId = coordinator.adapter.binding.legacySpaceIds[spaceId];
    if (legacySpaceId == null ||
        controller.selectedSpace?.id != legacySpaceId) {
      return null;
    }
    return _ConstructionContext(
      coordinator: coordinator,
      owner: owner,
      physical: physical,
      spaceId: spaceId,
    );
  }

  static void _finishCommittedTransition({
    required EditorController controller,
    required _ConstructionContext context,
    required ProjectMutationResult result,
    required void Function() rematerialize,
  }) {
    final session = context.coordinator.session;
    try {
      context.owner(result);
    } catch (error) {
      controller.documentHistory.invalidateAfterUnownedCanonicalCommit(session);
      throw CanonicalWallConstructionEditException(
        'Wall construction committed but persistence ownership failed: $error',
      );
    }
    if (session.project.version != result.project.version) {
      controller.documentHistory.invalidateAfterCommittedCanonicalDivergence(
        session,
      );
      throw const CanonicalWallConstructionEditException(
        'Wall construction changed re-entrantly after persistence ownership.',
      );
    }

    try {
      controller.documentHistory.recordCanonicalCommit(
        session: session,
        label: 'Edit wall construction',
        rematerialize: rematerialize,
      );
    } catch (error) {
      controller.documentHistory.invalidateAfterCommittedCanonicalDivergence(
        session,
      );
      throw CanonicalWallConstructionEditException(
        'Wall construction committed but unified history registration failed: '
        '$error',
      );
    }

    try {
      rematerialize();
    } catch (error) {
      controller.documentHistory.invalidateAfterCommittedCanonicalDivergence(
        session,
      );
      throw CanonicalWallConstructionEditException(
        'Wall construction committed but penetration projection failed: $error',
      );
    }
    if (session.project.version != result.project.version) {
      controller.documentHistory.invalidateAfterCommittedCanonicalDivergence(
        session,
      );
      throw const CanonicalWallConstructionEditException(
        'Wall construction changed re-entrantly during penetration projection.',
      );
    }
  }

  static String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

final class _ConstructionContext {
  const _ConstructionContext({
    required this.coordinator,
    required this.owner,
    required this.physical,
    required this.spaceId,
  });

  final CanonicalEditorRuntimeCutoverCoordinator coordinator;
  final CanonicalMutationOwnershipCallback owner;
  final CanonicalPhysicalRoutingContext physical;
  final SpaceId spaceId;
}
