import '../../domain/boundary_penetration.dart';
import '../../domain/cable_penetration_authoring.dart';
import '../../domain/canonical_slab_transition_resolver.dart';
import '../../domain/project_identity.dart';
import '../../domain/surface_transition_graph.dart';
import '../../domain/surfaces.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'canonical_slab_route_draft_externalization.dart';
import 'canonical_slab_route_handoff_runtime.dart';
import 'editor_controller.dart';

enum CanonicalSlabCableHandoffIssueCode {
  canonicalRuntimeRequired,
  sourceDraftRequired,
  sourceBindingMismatch,
  targetBindingMissing,
  targetGeometryMissing,
  verticalCoreMismatch,
  physicalTransitionRejected,
}

final class CanonicalSlabCableHandoffException implements Exception {
  const CanonicalSlabCableHandoffException({
    required this.code,
    required this.message,
    this.entityId,
  });

  final CanonicalSlabCableHandoffIssueCode code;
  final String message;
  final EntityId? entityId;

  @override
  String toString() => '${code.name}: $message';
}

final class CanonicalSlabCableHandoffResult {
  const CanonicalSlabCableHandoffResult({
    required this.transition,
    required this.slabId,
    required this.routeId,
    this.verticalCoreId,
  });

  final SurfaceTransitionCandidate transition;
  final SlabId slabId;
  final String routeId;
  final VerticalCoreId? verticalCoreId;

  RouteTransitionResolver resolverFor(EditorController editor) {
    return (fromSurface, fromPoint, toSurface, toPoint) {
      final context =
          CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(editor);
      if (context == null ||
          fromPoint != transition.fromPoint ||
          toPoint != transition.toPoint ||
          fromSurface.type != transition.fromSurface.type ||
          toSurface.type != transition.toSurface.type) {
        return null;
      }

      final storedFrom = context.canonicalSpaceIdForSurfaceSpaceId(
        transition.fromSurface.spaceId,
      );
      final storedTo = context.canonicalSpaceIdForSurfaceSpaceId(
        transition.toSurface.spaceId,
      );
      final requestedFrom = context.canonicalSpaceIdForSurfaceSpaceId(
        fromSurface.spaceId,
      );
      final requestedTo = context.canonicalSpaceIdForSurfaceSpaceId(
        toSurface.spaceId,
      );
      if (storedFrom == null ||
          storedTo == null ||
          requestedFrom != storedFrom ||
          requestedTo != storedTo ||
          transition.penetrationRequirement?.slabId != slabId ||
          transition.penetrationRequirement?.verticalCoreId != verticalCoreId) {
        return null;
      }

      return SurfaceTransitionCandidate(
        id: transition.id,
        kind: transition.kind,
        fromSurface: fromSurface,
        fromPoint: fromPoint,
        toSurface: toSurface,
        toPoint: toPoint,
        penetrationRequirement: transition.penetrationRequirement,
      );
    };
  }
}

final class CanonicalSlabCableHandoffAuthoring {
  const CanonicalSlabCableHandoffAuthoring({required this.runtime});

  final CanonicalSlabRouteHandoffRuntime runtime;

  /// Restores the source editor context after a post-cutover continuation
  /// failure. The runtime owns the exact navigation/draft transaction.
  void rollbackLastNavigation() => runtime.rollbackLastCommittedNavigation();

  CanonicalSlabCableHandoffResult continueAcrossSlab({
    required String routeId,
    required SpaceId toSpaceId,
    required int fromRoomHeightMm,
    required int toRoomHeightMm,
    VerticalCoreId? verticalCoreId,
    SlabId? expectedSlabId,
    int verticalToleranceMm = 2,
  }) {
    final coordinator = runtime.coordinator;
    final workspace = coordinator.adapter.workspace;
    final editor = workspace.editor;
    final project = coordinator.session.project;
    final navigation = coordinator.session.navigation;
    final fromSpaceId = navigation.selectedSpaceId;
    final fromLevelId = navigation.activeLevelId;
    if (fromSpaceId == null || fromLevelId == null) {
      throw const CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.sourceBindingMismatch,
        message: 'Cross-level cable authoring requires a selected canonical '
            'source SpaceId and LevelId.',
      );
    }
    if (editor.routeSegments.isEmpty || editor.activeSurface == null) {
      throw const CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.sourceDraftRequired,
        message: 'A live route draft on floor/ceiling is required.',
      );
    }

    final routingContext =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(editor);
    if (routingContext == null) {
      throw const CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.canonicalRuntimeRequired,
        message: 'Canonical routing context is required for slab authoring.',
      );
    }

    final targetSpace = project.index.space(toSpaceId);
    final targetLevel =
        targetSpace == null ? null : project.index.level(targetSpace.levelId);
    if (targetSpace == null || targetLevel == null) {
      throw CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.targetBindingMissing,
        entityId: toSpaceId,
        message: 'Target canonical SpaceId has no valid owning LevelId.',
      );
    }

    if (verticalCoreId != null) {
      final core = project.index.verticalCore(verticalCoreId);
      if (core == null ||
          !core.servesLevel(fromLevelId) ||
          !core.servesLevel(targetLevel.id)) {
        throw CanonicalSlabCableHandoffException(
          code: CanonicalSlabCableHandoffIssueCode.verticalCoreMismatch,
          entityId: verticalCoreId,
          message: 'VerticalCore $verticalCoreId does not own both canonical '
              'levels $fromLevelId and ${targetLevel.id}.',
        );
      }
    }

    final sourceLegacyLevelId =
        coordinator.adapter.binding.legacyLevelIds[fromLevelId];
    final targetLegacyLevelId =
        coordinator.adapter.binding.legacyLevelIds[targetLevel.id];
    final sourceLegacySpaceId =
        coordinator.adapter.binding.legacySpaceIds[fromSpaceId];
    final targetLegacySpaceId =
        coordinator.adapter.binding.legacySpaceIds[toSpaceId];
    if (sourceLegacyLevelId == null ||
        targetLegacyLevelId == null ||
        sourceLegacySpaceId == null ||
        targetLegacySpaceId == null) {
      throw CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.targetBindingMissing,
        entityId: toSpaceId,
        message: 'Canonical source/target LevelId and SpaceId must have exact '
            'legacy editor bindings before cross-level authoring.',
      );
    }

    final sourceComposedLevel = workspace.activeLevel;
    final targetComposedLevel = workspace.building.levels
        .where((candidate) => candidate.level.id == targetLegacyLevelId)
        .firstOrNull;
    if (sourceComposedLevel == null ||
        sourceComposedLevel.level.id != sourceLegacyLevelId ||
        editor.level.id != sourceLegacyLevelId ||
        editor.selectedSpaceId != sourceLegacySpaceId) {
      throw CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.sourceBindingMismatch,
        entityId: fromSpaceId,
        message: 'Legacy editor source context does not match canonical '
            'navigation.',
      );
    }
    if (targetComposedLevel == null) {
      throw CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.targetGeometryMissing,
        entityId: targetLevel.id,
        message: 'Target legacy BuildingLevel geometry is not materialized.',
      );
    }

    final fromSpace = editor.selectedSpace;
    final toSpace = targetComposedLevel.level.spaces
        .where((candidate) => candidate.id == targetLegacySpaceId)
        .firstOrNull;
    if (fromSpace == null || fromSpace.id != sourceLegacySpaceId) {
      throw CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.sourceBindingMismatch,
        entityId: fromSpaceId,
        message:
            'Selected legacy source room is not the bound canonical Space.',
      );
    }
    if (toSpace == null) {
      throw CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.targetGeometryMissing,
        entityId: toSpaceId,
        message: 'Target legacy EngineeringSpace geometry is not materialized.',
      );
    }

    final lastDraft = editor.routeSegments.last;
    final fromSurface = editor.activeSurface!;
    if (lastDraft.surface != fromSurface || lastDraft.points.isEmpty) {
      throw const CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.sourceDraftRequired,
        message: 'Active surface must own the live route draft endpoint.',
      );
    }
    if (fromSurface.type == SurfacePlaneType.wall) {
      throw const CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.sourceDraftRequired,
        message: 'A slab route handoff must start on ceiling or floor.',
      );
    }

    final prepared = runtime.prepare(
      routeId: routeId,
      toSpaceId: toSpaceId,
      fromLevelElevationMm: sourceComposedLevel.level.elevationMm,
      toLevelElevationMm: targetComposedLevel.level.elevationMm,
      fromRoomHeightMm: fromRoomHeightMm,
      toRoomHeightMm: toRoomHeightMm,
      verticalToleranceMm: verticalToleranceMm,
    );
    if (expectedSlabId != null && prepared.intent.slabId != expectedSlabId) {
      runtime.cancel();
      throw CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.physicalTransitionRejected,
        entityId: expectedSlabId,
        message: 'Prepared slab ${prepared.intent.slabId} does not match '
            'planned VerticalCore slab $expectedSlabId.',
      );
    }

    final transition = CanonicalSlabTransitionResolver.resolve(
      project: project,
      buildingLevels: workspace.building.levels.map((level) => level.level),
      fromLevel: sourceComposedLevel.level,
      fromSpace: fromSpace,
      fromSurface: fromSurface,
      point: lastDraft.points.last,
      fromRoomHeightMm: fromRoomHeightMm,
      toLevel: targetComposedLevel.level,
      toSpace: toSpace,
      toRoomHeightMm: toRoomHeightMm,
      canonicalSpaceIdResolver:
          routingContext.canonicalSpaceIdForSurfaceSpaceId,
      verticalToleranceMm: verticalToleranceMm,
    );
    if (transition == null ||
        transition.penetrationRequirement?.slabId != prepared.intent.slabId) {
      runtime.cancel();
      throw CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.physicalTransitionRejected,
        entityId: prepared.intent.slabId,
        message: 'Live route endpoint does not prove a physical transition '
            'through the prepared canonical SlabId.',
      );
    }

    final effectiveTransition = verticalCoreId == null
        ? transition
        : _withVerticalCoreIdentity(
            transition: transition,
            verticalCoreId: verticalCoreId,
          );

    CanonicalSlabRouteDraftExternalization externalized;
    try {
      externalized = CanonicalSlabRouteDraftExternalization.externalize(
        editor: editor,
        intent: prepared.intent,
        transition: effectiveTransition,
      );
    } on Object {
      runtime.cancel();
      rethrow;
    }

    final plan = runtime.applyNavigation(externalizedDraft: externalized);
    return CanonicalSlabCableHandoffResult(
      transition: effectiveTransition,
      slabId: plan.slabId,
      routeId: prepared.intent.routeId,
      verticalCoreId: verticalCoreId,
    );
  }

  static SurfaceTransitionCandidate _withVerticalCoreIdentity({
    required SurfaceTransitionCandidate transition,
    required VerticalCoreId verticalCoreId,
  }) {
    final requirement = transition.penetrationRequirement;
    if (requirement == null ||
        transition.kind != SurfaceTransitionKind.levelPenetration ||
        requirement.hostKind != BoundaryPenetrationHostKind.slab ||
        requirement.slabId == null) {
      throw CanonicalSlabCableHandoffException(
        code: CanonicalSlabCableHandoffIssueCode.physicalTransitionRejected,
        entityId: verticalCoreId,
        message: 'VerticalCore route ownership requires a proven canonical '
            'slab penetration transition.',
      );
    }
    return SurfaceTransitionCandidate(
      id: transition.id,
      kind: transition.kind,
      fromSurface: transition.fromSurface,
      fromPoint: transition.fromPoint,
      toSurface: transition.toSurface,
      toPoint: transition.toPoint,
      penetrationRequirement: BoundaryPenetrationRequirement(
        hostKind: requirement.hostKind,
        hostThicknessMm: requirement.hostThicknessMm,
        materialId: requirement.materialId,
        slabId: requirement.slabId,
        verticalCoreId: verticalCoreId,
      ),
    );
  }
}
