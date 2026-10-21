import '../../application/project/project_structure_authoring.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'editor_building_workspace.dart';

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
    this.onBlocked,
    this.onError,
  });

  final CanonicalEditorRuntimeCutoverCoordinator coordinator;
  final void Function(ProjectNavigationState navigation)?
      onCanonicalNavigationChanged;
  final CanonicalEditorCutoverBlockedCallback? onBlocked;
  final CanonicalEditorCutoverErrorCallback? onError;

  EditorBuildingWorkspace get workspace => coordinator.adapter.workspace;

  bool _started = false;
  bool _disposed = false;
  String? _lastLegacySelectionFingerprint;

  bool get isStarted => _started;

  /// Attaches the legacy listeners and optionally projects the current
  /// canonical location into the canvas. Calling start twice is a no-op.
  void start({bool pushInitialCanonicalState = true}) {
    _requireNotDisposed();
    if (_started) return;
    _started = true;
    workspace.addListener(_onLegacyRuntimeChanged);
    workspace.editor.addListener(_onLegacyRuntimeChanged);
    _lastLegacySelectionFingerprint = _legacySelectionFingerprint();

    if (pushInitialCanonicalState) {
      pushCanonicalToEditor();
    }
  }

  /// Entry point for Project Navigator / breadcrumb transitions.
  ///
  /// A blocked materialization is reported as controlled state and does not
  /// mutate the canvas. Unexpected adapter/runtime failures are reported
  /// separately and are not reclassified as materialization blockers.
  CanonicalEditorMaterializationResult pushCanonicalToEditor() {
    _requireNotDisposed();
    final readiness = coordinator.inspectCurrentTarget();
    if (!readiness.canOpen) {
      onBlocked?.call(readiness);
      return readiness;
    }

    try {
      coordinator.pushCanonicalToEditor();
      _lastLegacySelectionFingerprint = _legacySelectionFingerprint();
      return readiness;
    } on CanonicalEditorCutoverBlockedException catch (error) {
      onBlocked?.call(error.result);
      return error.result;
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      rethrow;
    }
  }

  /// Detaches all listeners. The coordinator/session are externally owned and
  /// are deliberately not disposed by this transitional binding.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      workspace.removeListener(_onLegacyRuntimeChanged);
      workspace.editor.removeListener(_onLegacyRuntimeChanged);
    }
    _started = false;
  }

  void _onLegacyRuntimeChanged() {
    if (_disposed ||
        !_started ||
        coordinator.isSynchronizing ||
        workspace.context != EditorWorkspaceContext.buildingLevel) {
      return;
    }

    final fingerprint = _legacySelectionFingerprint();
    if (fingerprint == _lastLegacySelectionFingerprint) return;

    try {
      final navigation = coordinator.pullLegacyToCanonical();
      if (navigation == null) return;
      _lastLegacySelectionFingerprint = fingerprint;
      onCanonicalNavigationChanged?.call(navigation);
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }

  String _legacySelectionFingerprint() {
    final levelId = workspace.activeLevel?.level.id ?? '';
    final zoneId = workspace.selectedZoneId ?? '';
    final spaceId = workspace.editor.selectedSpaceId ?? '';
    return '${workspace.context.name}|$levelId|$zoneId|$spaceId';
  }

  void _requireNotDisposed() {
    if (_disposed) {
      throw StateError('Canonical editor screen cutover binding is disposed.');
    }
  }
}
