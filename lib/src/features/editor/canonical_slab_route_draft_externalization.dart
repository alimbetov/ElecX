import '../../application/project/project_slab_route_handoff.dart';
import '../../domain/project_identity.dart';
import '../../domain/surface_routing.dart';
import '../../domain/surface_transition_graph.dart';
import '../../domain/surfaces.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'physical_manual_cable_draft_persistence.dart';

enum CanonicalSlabRouteDraftExternalizationIssueCode {
  routeDraftRequired,
  routeIdentityMismatch,
  transitionMismatch,
  canonicalRuntimeRequired,
  p2RevisionChanged,
  draftAlreadyRestored,
  draftStateConflict,
  targetSurfaceMismatch,
}

final class CanonicalSlabRouteDraftExternalizationException
    implements Exception {
  const CanonicalSlabRouteDraftExternalizationException({
    required this.code,
    required this.message,
    this.entityId,
  });

  final CanonicalSlabRouteDraftExternalizationIssueCode code;
  final String message;
  final EntityId? entityId;

  @override
  String toString() => '${code.name}: $message';
}

/// Lossless transient route buffer used while the legacy workspace switches
/// between canonical levels.
///
/// The token is bound to one controller instance, one exact electrical P2
/// revision, one route identity and one physical SlabId. It owns no persistent
/// mutation and therefore creates no undo/redo entry by itself.
final class CanonicalSlabRouteDraftExternalization {
  CanonicalSlabRouteDraftExternalization._({
    required this.editorIdentity,
    required this.routeId,
    required this.slabId,
    required this.p2MutationRevision,
    required this.hadPhysicalContinuation,
    required this.sourceSegments,
    required this.transition,
  });

  final Object editorIdentity;
  final String routeId;
  final SlabId slabId;
  final int p2MutationRevision;
  final bool hadPhysicalContinuation;
  final List<SurfaceRouteSegmentDraft> sourceSegments;
  final SurfaceTransitionCandidate transition;
  bool _restored = false;

  bool get isRestored => _restored;

  static CanonicalSlabRouteDraftExternalization externalize({
    required EditorController editor,
    required ProjectSlabRouteHandoffIntent intent,
    required SurfaceTransitionCandidate transition,
  }) {
    if (editor.routeSegments.isEmpty) {
      throw const CanonicalSlabRouteDraftExternalizationException(
        code:
            CanonicalSlabRouteDraftExternalizationIssueCode.routeDraftRequired,
        message: 'A live route draft is required before slab cutover.',
      );
    }

    final continuationId = editor.physicalRouteContinuationId;
    if (continuationId != null && continuationId != intent.routeId) {
      throw CanonicalSlabRouteDraftExternalizationException(
        code: CanonicalSlabRouteDraftExternalizationIssueCode
            .routeIdentityMismatch,
        message: 'Physical continuation route $continuationId does not match '
            'handoff route ${intent.routeId}.',
      );
    }

    final routingContext =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(editor);
    if (routingContext == null) {
      throw const CanonicalSlabRouteDraftExternalizationException(
        code: CanonicalSlabRouteDraftExternalizationIssueCode
            .canonicalRuntimeRequired,
        message: 'Canonical routing context is required for slab cutover.',
      );
    }

    final last = editor.routeSegments.last;
    final requirement = transition.penetrationRequirement;
    final canonicalFrom = routingContext
        .canonicalSpaceIdForSurfaceSpaceId(transition.fromSurface.spaceId);
    final canonicalTo = routingContext
        .canonicalSpaceIdForSurfaceSpaceId(transition.toSurface.spaceId);
    if (transition.kind != SurfaceTransitionKind.levelPenetration ||
        requirement?.slabId != intent.slabId ||
        canonicalFrom != intent.plan.fromSpaceId ||
        canonicalTo != intent.plan.toSpaceId ||
        transition.fromSurface != last.surface ||
        last.points.isEmpty ||
        transition.fromPoint != last.points.last ||
        transition.fromSurface.type != intent.plan.fromSurface.type ||
        transition.toSurface.type != intent.plan.toSurface.type) {
      throw CanonicalSlabRouteDraftExternalizationException(
        code:
            CanonicalSlabRouteDraftExternalizationIssueCode.transitionMismatch,
        entityId: requirement?.slabId,
        message: 'The concrete level penetration does not match the prepared '
            'SlabId handoff and live route endpoint.',
      );
    }

    final segments = List<SurfaceRouteSegmentDraft>.unmodifiable(
      editor.routeSegments.map(
        (segment) => SurfaceRouteSegmentDraft(
          surface: segment.surface,
          points: List<SurfacePointMm>.unmodifiable(segment.points),
        ),
      ),
    );
    final result = CanonicalSlabRouteDraftExternalization._(
      editorIdentity: editor,
      routeId: intent.routeId,
      slabId: intent.slabId,
      p2MutationRevision: editor.p2.history.mutationRevision,
      hadPhysicalContinuation: editor.hasPhysicalRouteContinuation,
      sourceSegments: segments,
      transition: transition,
    );

    // Only transient draft geometry is externalized. The private physical-route
    // continuation intent intentionally remains attached to the controller so
    // the exact committed route identity/session affinity survives the cutover.
    editor.clearRouteDraft();
    return result;
  }

  /// Returns whether this token still owns the exact transient/P2 state needed
  /// by one handoff attempt. No mutation is performed by this check.
  bool owns({
    required EditorController editor,
    required ProjectSlabRouteHandoffIntent intent,
  }) =>
      !_restored &&
      identical(editorIdentity, editor) &&
      routeId == intent.routeId &&
      slabId == intent.slabId &&
      editor.routeSegments.isEmpty &&
      editor.p2.history.mutationRevision == p2MutationRevision &&
      (!hadPhysicalContinuation ||
          editor.physicalRouteContinuationId == routeId);

  /// Restores the exact source draft plus one target-level seed point after the
  /// canonical workspace has switched to the target SpaceId.
  void restoreTarget(EditorController editor) {
    _requireRestorable(editor);
    final targetSurface = _materializeExpectedHorizontalSurface(
      editor: editor,
      expectedCanonicalSpaceIdResolver: (context) => context
          .canonicalSpaceIdForSurfaceSpaceId(transition.toSurface.spaceId),
      expectedType: transition.toSurface.type,
    );

    editor.routeSegments.addAll(sourceSegments);
    editor.routeSegments.add(
      SurfaceRouteSegmentDraft(
        surface: targetSurface,
        points: <SurfacePointMm>[transition.toPoint],
      ),
    );
    _restored = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    editor.notifyListeners();
  }

  /// Rollback path used when target cutover succeeds but draft restoration fails.
  /// The legacy workspace must first be returned to the original source SpaceId.
  void restoreSource(EditorController editor) {
    _requireRestorable(editor);
    _materializeExpectedHorizontalSurface(
      editor: editor,
      expectedCanonicalSpaceIdResolver: (context) => context
          .canonicalSpaceIdForSurfaceSpaceId(transition.fromSurface.spaceId),
      expectedType: transition.fromSurface.type,
    );

    editor.routeSegments.addAll(sourceSegments);
    _restored = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    editor.notifyListeners();
  }

  void _requireRestorable(EditorController editor) {
    if (_restored) {
      throw const CanonicalSlabRouteDraftExternalizationException(
        code: CanonicalSlabRouteDraftExternalizationIssueCode
            .draftAlreadyRestored,
        message: 'The slab route draft has already been restored.',
      );
    }
    if (!identical(editorIdentity, editor) || editor.routeSegments.isNotEmpty) {
      throw const CanonicalSlabRouteDraftExternalizationException(
        code:
            CanonicalSlabRouteDraftExternalizationIssueCode.draftStateConflict,
        message: 'The target editor is not in the empty state owned by this '
            'externalized route draft.',
      );
    }
    if (editor.p2.history.mutationRevision != p2MutationRevision) {
      throw const CanonicalSlabRouteDraftExternalizationException(
        code: CanonicalSlabRouteDraftExternalizationIssueCode.p2RevisionChanged,
        message: 'Electrical P2 state changed while the route draft was '
            'externalized.',
      );
    }
    if (hadPhysicalContinuation &&
        editor.physicalRouteContinuationId != routeId) {
      throw const CanonicalSlabRouteDraftExternalizationException(
        code: CanonicalSlabRouteDraftExternalizationIssueCode
            .routeIdentityMismatch,
        message: 'Physical route continuation identity changed during cutover.',
      );
    }
  }

  RoomSurfaceRef _materializeExpectedHorizontalSurface({
    required EditorController editor,
    required SpaceId? Function(CanonicalPhysicalRoutingContext context)
        expectedCanonicalSpaceIdResolver,
    required SurfacePlaneType expectedType,
  }) {
    if (expectedType == SurfacePlaneType.wall) {
      throw const CanonicalSlabRouteDraftExternalizationException(
        code: CanonicalSlabRouteDraftExternalizationIssueCode
            .targetSurfaceMismatch,
        message: 'A slab handoff endpoint must be floor or ceiling.',
      );
    }

    final routingContext =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(editor);
    final selectedLegacySpaceId = editor.selectedSpaceId;
    final selectedCanonicalSpaceId =
        selectedLegacySpaceId == null || routingContext == null
            ? null
            : routingContext
                .canonicalSpaceIdForSurfaceSpaceId(selectedLegacySpaceId);
    final expectedCanonicalSpaceId = routingContext == null
        ? null
        : expectedCanonicalSpaceIdResolver(routingContext);
    if (selectedCanonicalSpaceId == null ||
        selectedCanonicalSpaceId != expectedCanonicalSpaceId) {
      throw const CanonicalSlabRouteDraftExternalizationException(
        code: CanonicalSlabRouteDraftExternalizationIssueCode
            .targetSurfaceMismatch,
        message: 'The materialized editor is not on the expected canonical '
            'SpaceId for this slab route draft.',
      );
    }

    editor.setTool(EditorTool.cableRoute);
    switch (expectedType) {
      case SurfacePlaneType.floor:
        editor.showFloor();
      case SurfacePlaneType.ceiling:
        editor.showCeiling();
      case SurfacePlaneType.wall:
        throw StateError('Handled above.');
    }
    final surface = editor.activeSurface;
    if (surface == null ||
        surface.type != expectedType ||
        surface.spaceId != selectedLegacySpaceId) {
      throw const CanonicalSlabRouteDraftExternalizationException(
        code: CanonicalSlabRouteDraftExternalizationIssueCode
            .targetSurfaceMismatch,
        message: 'Expected floor/ceiling surface could not be materialized.',
      );
    }
    return surface;
  }
}
