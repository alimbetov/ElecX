import '../../application/project/project_structure_authoring.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_building_workspace.dart';
import 'editor_document_history.dart';

typedef CanonicalEditorCutoverBlockedCallback = void Function(
  CanonicalEditorMaterializationResult result,
);

typedef CanonicalEditorCutoverErrorCallback = void Function(
  Object error,
  StackTrace stackTrace,
);

/// Lifecycle bridge used by [UnifiedWorkspaceEditorScreen] during the P5C
/// production cutover.
///
/// The bridge owns listener wiring only. Canonical navigation remains owned by
/// [ProjectStructureAuthoringSession], while all canonical <-> legacy state
/// transfer still goes through [CanonicalEditorRuntimeCutoverCoordinator].
///
/// Site/outdoor navigation is intentionally ignored here because P5C only owns
/// Site/Building/Level/Zone/Space structural navigation. Outdoor runtime state
/// remains transitional until its canonical model is introduced.
final class CanonicalEditorScreenCutoverBinding {
  CanonicalEditorScreenCutoverBinding({
    required this.coordinator,
    this.onCanonicalNavigationChanged,
    this.onBoundaryTopologyCommitted,
    this.onBlocked,
    this.onError,
  });

  final CanonicalEditorRuntimeCutoverCoordinator coordinator;
  final void Function(ProjectNavigationState navigation)?
      onCanonicalNavigationChanged;
  final CanonicalBoundaryTopologyOwnershipCallback? onBoundaryTopologyCommitted;
  final CanonicalEditorCutoverBlockedCallback? onBlocked;
  final CanonicalEditorCutoverErrorCallback? onError;

  EditorBuildingWorkspace get workspace => coordinator.adapter.workspace;

  bool _started = false;
  bool _disposed = false;
  _LegacyNavigationFingerprint? _lastLegacySelectionFingerprint;
  _LegacyNavigationFingerprint? _lastRejectedLegacySelectionFingerprint;

  bool get isStarted => _started;

  bool isBoundTo(EditorBuildingWorkspace candidate) =>
      identical(workspace, candidate);

  /// Attaches legacy listeners, unified document history and the runtime-only
  /// stable-surface bridge, then optionally projects the current canonical
  /// location into the canvas. Calling start twice is a no-op.
  void start({bool pushInitialCanonicalState = true}) {
    _requireNotDisposed();
    if (_started) return;
    _started = true;
    final topologyOwner = onBoundaryTopologyCommitted;
    workspace.editor.documentHistory.attachCanonicalSession(
      coordinator.session,
      onReplayed: topologyOwner == null
          ? null
          : (result) => topologyOwner(
                coordinator.session.boundaryTopologyEditing,
                result,
              ),
    );
    CanonicalRoomSurfaceRuntimeRegistry.attach(
      coordinator,
      onBoundaryTopologyCommitted: topologyOwner,
    );
    workspace.addListener(_onLegacyRuntimeChanged);
    workspace.editor.addListener(_onLegacyRuntimeChanged);
    _lastLegacySelectionFingerprint = _legacySelectionFingerprint();

    if (!pushInitialCanonicalState) return;

    try {
      pushCanonicalToEditor();
    } catch (_) {
      _detachListeners();
      rethrow;
    }
  }

  /// Entry point for Project Navigator / breadcrumb transitions.
  ///
  /// Canonical projection is suppressed from the legacy architecture journal:
  /// the authoritative P3 mutation is the history entry, not the materialized
  /// compatibility copy in EditorController.
  CanonicalEditorMaterializationResult pushCanonicalToEditor() {
    _requireNotDisposed();
    final readiness = coordinator.inspectCurrentTarget();
    if (!readiness.canOpen) {
      onBlocked?.call(readiness);
      return readiness;
    }

    try {
      workspace.editor.documentHistory.runCanonicalProjection(() {
        coordinator.pushCanonicalToEditor();
        _lastLegacySelectionFingerprint = _legacySelectionFingerprint();
        _lastRejectedLegacySelectionFingerprint = null;
        CanonicalRoomSurfaceRuntimeRegistry.applyStagedResume(workspace.editor);
      });
      return readiness;
    } on CanonicalEditorCutoverBlockedException catch (error) {
      onBlocked?.call(error.result);
      return error.result;
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      rethrow;
    }
  }

  /// Detaches all listeners and runtime-only ownership. The canonical session
  /// remains externally owned, but its history entries are invalid after this
  /// exact production binding disappears, so the unified journal fails closed.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _detachListeners();
  }

  void _onLegacyRuntimeChanged() {
    if (_disposed ||
        !_started ||
        coordinator.isSynchronizing ||
        workspace.context != EditorWorkspaceContext.buildingLevel) {
      return;
    }

    final fingerprint = _legacySelectionFingerprint();
    if (fingerprint == _lastLegacySelectionFingerprint ||
        fingerprint == _lastRejectedLegacySelectionFingerprint) {
      return;
    }

    try {
      final navigation = coordinator.pullLegacyToCanonical();
      if (navigation == null) return;
      _lastLegacySelectionFingerprint = fingerprint;
      _lastRejectedLegacySelectionFingerprint = null;
      onCanonicalNavigationChanged?.call(navigation);
    } catch (error, stackTrace) {
      _lastRejectedLegacySelectionFingerprint = fingerprint;
      onError?.call(error, stackTrace);
    }
  }

  _LegacyNavigationFingerprint _legacySelectionFingerprint() =>
      _LegacyNavigationFingerprint(
        context: workspace.context,
        levelId: workspace.activeLevel?.level.id,
        zoneId: workspace.selectedZoneId,
        spaceId: workspace.editor.selectedSpaceId,
      );

  void _detachListeners() {
    CanonicalRoomSurfaceRuntimeRegistry.detach(coordinator);
    workspace.editor.documentHistory.detachCanonicalSession(coordinator.session);
    if (!_started) return;
    workspace.removeListener(_onLegacyRuntimeChanged);
    workspace.editor.removeListener(_onLegacyRuntimeChanged);
    _started = false;
  }

  void _requireNotDisposed() {
    if (_disposed) {
      throw StateError('Canonical editor screen cutover binding is disposed.');
    }
  }
}

final class _LegacyNavigationFingerprint {
  const _LegacyNavigationFingerprint({
    required this.context,
    required this.levelId,
    required this.zoneId,
    required this.spaceId,
  });

  final EditorWorkspaceContext context;
  final String? levelId;
  final String? zoneId;
  final String? spaceId;

  @override
  bool operator ==(Object other) =>
      other is _LegacyNavigationFingerprint &&
      other.context == context &&
      other.levelId == levelId &&
      other.zoneId == zoneId &&
      other.spaceId == spaceId;

  @override
  int get hashCode => Object.hash(context, levelId, zoneId, spaceId);
}
