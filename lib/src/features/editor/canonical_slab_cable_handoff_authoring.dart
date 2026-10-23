import '../../domain/canonical_slab_transition_resolver.dart';
import '../../domain/project_identity.dart';
import '../../domain/surface_transition_graph.dart';
import '../../domain/surfaces.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'canonical_slab_route_draft_externalization.dart';
import 'canonical_slab_route_handoff_runtime.dart';

enum CanonicalSlabCableHandoffIssueCode {
  canonicalRuntimeRequired,
  sourceDraftRequired,
  sourceBindingMismatch,
  targetBindingMissing,
  targetGeometryMissing,
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
  });

  final SurfaceTransitionCandidate transition;
  final SlabId slabId;
  final String routeId;
}

/// Production authoring boundary for one live ceiling↔floor route handoff.
///
/// This service resolves all canonical/legacy bindings before mutating
/// navigation, proves the concrete slab transition at the live draft endpoint,
/// externalizes transient draft geometry, performs the rollback-safe level
/// cutover and restores the draft on the target horizontal surface.
final class CanonicalSlabCableHandoffAuthoring {
  const CanonicalSlabCableHandoffAuthoring({required this.runtime});

  final CanonicalSlabRouteHandoffRuntime runtime;

  CanonicalSlabCableHandoffResult continueAcrossSlab({
    required String routeId,
    required SpaceId toSpaceId,
    required int fromRoomHeightMm,
    required int toRoomHeightMm,
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
        message: 'Selected legacy source room is not the bound canonical Space.',
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

    CanonicalSlabRouteDraftExternalization externalized;
    try {
      externalized = CanonicalSlabRouteDraftExternalization.externalize(
        editor: editor,
        intent: prepared.intent,
        transition: transition,
      );
    } on Object {
      runtime.cancel();
      rethrow;
    }

    final plan = runtime.applyNavigation(externalizedDraft: externalized);
    return CanonicalSlabCableHandoffResult(
      transition: transition,
      slabId: plan.slabId,
      routeId: prepared.intent.routeId,
    );
  }
}
