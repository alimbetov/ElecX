import '../../application/project/project_navigation_state.dart';
import '../../application/project/project_slab_route_handoff.dart';
import '../../domain/canonical_slab_route_handoff.dart';
import '../../domain/canonical_slab_vertical_evidence.dart';
import '../../domain/project_identity.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_slab_route_draft_externalization.dart';
import 'physical_manual_cable_draft_persistence.dart';

enum CanonicalSlabRouteHandoffRuntimeIssueCode {
  sourceSpaceRequired,
  verticalEvidenceRejected,
  targetNotMaterialized,
  cutoverBusy,
  transientRouteDraftNotExternalized,
  cutoverFailed,
  rollbackFailed,
}

final class CanonicalSlabRouteHandoffRuntimeException implements Exception {
  const CanonicalSlabRouteHandoffRuntimeException({
    required this.code,
    required this.message,
    this.entityId,
  });

  final CanonicalSlabRouteHandoffRuntimeIssueCode code;
  final String message;
  final EntityId? entityId;

  @override
  String toString() => '${code.name}: $message';
}

final class CanonicalSlabRouteHandoffPrepared {
  const CanonicalSlabRouteHandoffPrepared({
    required this.intent,
    required this.verticalEvidence,
  });

  final ProjectSlabRouteHandoffIntent intent;
  final CanonicalSlabVerticalEvidence verticalEvidence;
}

/// Fail-closed bridge between canonical slab handoff admission and the legacy
/// editor level cutover.
///
/// A live route draft must be externalized into an exact
/// [CanonicalSlabRouteDraftExternalization] before the level switch. The token
/// preserves route identity, SlabId, P2 revision and source geometry while the
/// legacy workspace resets transient canvas state. On success the draft is
/// restored on the target floor/ceiling. On failure both canonical navigation
/// and the legacy workspace are rolled back before the source draft is restored.
final class CanonicalSlabRouteHandoffRuntime {
  CanonicalSlabRouteHandoffRuntime({required this.coordinator})
      : _handoff = ProjectSlabRouteHandoffSession(coordinator.session);

  final CanonicalEditorRuntimeCutoverCoordinator coordinator;
  final ProjectSlabRouteHandoffSession _handoff;
  CanonicalSlabRouteHandoffPrepared? _prepared;

  CanonicalSlabRouteHandoffPrepared? get prepared => _prepared;

  CanonicalSlabRouteHandoffPrepared prepare({
    required String routeId,
    required SpaceId toSpaceId,
    required int fromLevelElevationMm,
    required int toLevelElevationMm,
    required int fromRoomHeightMm,
    required int toRoomHeightMm,
    int verticalToleranceMm = 2,
  }) {
    final fromSpaceId = coordinator.session.navigation.selectedSpaceId;
    if (fromSpaceId == null) {
      throw const CanonicalSlabRouteHandoffRuntimeException(
        code: CanonicalSlabRouteHandoffRuntimeIssueCode.sourceSpaceRequired,
        message:
            'Cross-level route handoff requires a selected source SpaceId.',
      );
    }

    final intent = _handoff.prepare(
      routeId: routeId,
      fromSpaceId: fromSpaceId,
      toSpaceId: toSpaceId,
    );
    final evidence = CanonicalSlabVerticalEvidenceResolver.resolve(
      project: coordinator.session.project,
      plan: intent.plan,
      fromLevelElevationMm: fromLevelElevationMm,
      toLevelElevationMm: toLevelElevationMm,
      fromRoomHeightMm: fromRoomHeightMm,
      toRoomHeightMm: toRoomHeightMm,
      verticalToleranceMm: verticalToleranceMm,
    );
    if (evidence == null) {
      _handoff.cancel();
      throw CanonicalSlabRouteHandoffRuntimeException(
        code:
            CanonicalSlabRouteHandoffRuntimeIssueCode.verticalEvidenceRejected,
        entityId: intent.slabId,
        message: 'Materialized vertical geometry does not prove the canonical '
            'slab crossing.',
      );
    }

    final targetNavigation = intent.sourceNavigation.selectSpace(
      coordinator.session.project,
      toSpaceId,
    );
    final materialization =
        const ExistingBindingCanonicalEditorMaterializer().inspect(
      project: coordinator.session.project,
      navigation: targetNavigation,
      binding: coordinator.adapter.binding,
    );
    if (!materialization.canOpen) {
      _handoff.cancel();
      throw CanonicalSlabRouteHandoffRuntimeException(
        code: CanonicalSlabRouteHandoffRuntimeIssueCode.targetNotMaterialized,
        entityId: materialization.entityId,
        message: materialization.message ??
            'Target cross-level editor representation is unavailable.',
      );
    }

    final result = CanonicalSlabRouteHandoffPrepared(
      intent: intent,
      verticalEvidence: evidence,
    );
    _prepared = result;
    return result;
  }

  CanonicalSlabRouteHandoffPlan applyNavigation({
    CanonicalSlabRouteDraftExternalization? externalizedDraft,
  }) {
    final prepared = _prepared;
    if (prepared == null) {
      throw const ProjectSlabRouteHandoffException(
        code: ProjectSlabRouteHandoffIssueCode.handoffNotPending,
        message: 'No slab route handoff is prepared.',
      );
    }
    if (coordinator.phase != CanonicalEditorCutoverPhase.idle) {
      throw const CanonicalSlabRouteHandoffRuntimeException(
        code: CanonicalSlabRouteHandoffRuntimeIssueCode.cutoverBusy,
        message: 'Canonical editor cutover is already synchronizing.',
      );
    }

    final editor = coordinator.adapter.workspace.editor;
    if (editor.routeSegments.isNotEmpty ||
        (editor.hasPhysicalRouteContinuation && externalizedDraft == null) ||
        (externalizedDraft != null &&
            !externalizedDraft.owns(
              editor: editor,
              intent: prepared.intent,
            ))) {
      throw const CanonicalSlabRouteHandoffRuntimeException(
        code: CanonicalSlabRouteHandoffRuntimeIssueCode
            .transientRouteDraftNotExternalized,
        message: 'Cross-level navigation requires an exact externalized route '
            'draft token before the legacy level can be switched.',
      );
    }

    final sourceNavigation = prepared.intent.sourceNavigation;
    CanonicalSlabRouteHandoffPlan plan;
    try {
      plan = _handoff.commitNavigation();
      coordinator.pushCanonicalToEditor();
      externalizedDraft?.restoreTarget(editor);
    } on ProjectSlabRouteHandoffException {
      _restoreExternalizedSourceIfPossible(
        externalizedDraft,
        sourceNavigation: sourceNavigation,
      );
      _handoff.cancel();
      _prepared = null;
      rethrow;
    } catch (_) {
      final rolledBack = _rollbackToSource(
        sourceNavigation: sourceNavigation,
        externalizedDraft: externalizedDraft,
      );
      if (!rolledBack) {
        _handoff.cancel();
        _prepared = null;
        throw CanonicalSlabRouteHandoffRuntimeException(
          code: CanonicalSlabRouteHandoffRuntimeIssueCode.rollbackFailed,
          entityId: prepared.intent.plan.fromSpaceId,
          message: 'Cross-level cutover failed and the source editor context '
              'could not be restored atomically.',
        );
      }
      _restorePending(prepared);
      throw CanonicalSlabRouteHandoffRuntimeException(
        code: CanonicalSlabRouteHandoffRuntimeIssueCode.cutoverFailed,
        entityId: prepared.intent.plan.toSpaceId,
        message: 'Cross-level cutover failed; canonical navigation, legacy '
            'workspace and route draft were restored to the source context.',
      );
    }

    _prepared = null;
    return plan;
  }

  void cancel() {
    _handoff.cancel();
    _prepared = null;
  }

  bool _rollbackToSource({
    required ProjectNavigationState sourceNavigation,
    required CanonicalSlabRouteDraftExternalization? externalizedDraft,
  }) {
    try {
      if (coordinator.session.navigation != sourceNavigation) {
        coordinator.session.adoptNavigation(sourceNavigation);
      }
      coordinator.pushCanonicalToEditor();
      if (externalizedDraft != null && !externalizedDraft.isRestored) {
        externalizedDraft.restoreSource(coordinator.adapter.workspace.editor);
      }
      return true;
    } on Object {
      return false;
    }
  }

  void _restoreExternalizedSourceIfPossible(
    CanonicalSlabRouteDraftExternalization? externalizedDraft, {
    required ProjectNavigationState sourceNavigation,
  }) {
    if (externalizedDraft == null || externalizedDraft.isRestored) return;
    try {
      if (coordinator.session.navigation != sourceNavigation) {
        coordinator.session.adoptNavigation(sourceNavigation);
      }
      coordinator.pushCanonicalToEditor();
      externalizedDraft.restoreSource(coordinator.adapter.workspace.editor);
    } on Object {
      // The primary typed ProjectSlabRouteHandoffException is more actionable.
      // A later retry is impossible because this runtime is cancelled below.
    }
  }

  void _restorePending(CanonicalSlabRouteHandoffPrepared prepared) {
    _handoff.cancel();
    try {
      _handoff.prepare(
        routeId: prepared.intent.routeId,
        fromSpaceId: prepared.intent.plan.fromSpaceId,
        toSpaceId: prepared.intent.plan.toSpaceId,
      );
      _prepared = prepared;
    } on Object {
      _handoff.cancel();
      _prepared = null;
    }
  }
}
