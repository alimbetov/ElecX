import '../../application/project/project_room_rectangle_authoring.dart';
import '../../application/project/project_structure_authoring.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/project_model.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_editor_wizard_runtime_registry.dart';
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
final class CanonicalEditorScreenCutoverBinding {
  CanonicalEditorScreenCutoverBinding({
    required this.coordinator,
    this.onCanonicalNavigationChanged,
    this.onCanonicalMutationReplayed,
    this.onBoundaryTopologyCommitted,
    this.onBlocked,
    this.onError,
  });

  final CanonicalEditorRuntimeCutoverCoordinator coordinator;
  final void Function(ProjectNavigationState navigation)?
      onCanonicalNavigationChanged;
  final CanonicalHistoryReplayOwner? onCanonicalMutationReplayed;
  final CanonicalBoundaryTopologyOwnershipCallback? onBoundaryTopologyCommitted;
  final CanonicalEditorCutoverBlockedCallback? onBlocked;
  final CanonicalEditorCutoverErrorCallback? onError;

  EditorBuildingWorkspace get workspace => coordinator.adapter.workspace;

  bool _started = false;
  bool _disposed = false;
  bool _canonicalizingLegacyRoomRectangle = false;
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
    workspace.editor.documentHistory.attachCanonicalSession(
      coordinator.session,
      onReplayed: onCanonicalMutationReplayed,
    );
    CanonicalRoomSurfaceRuntimeRegistry.attach(
      coordinator,
      onBoundaryTopologyCommitted: onBoundaryTopologyCommitted,
      onCanonicalMutationCommitted: onCanonicalMutationReplayed,
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
  /// compatibility copy in EditorController. Production runtime materializers
  /// may extend that compatibility copy inside the same suppressed projection.
  CanonicalEditorMaterializationResult pushCanonicalToEditor() {
    _requireNotDisposed();
    var readiness = coordinator.inspectCurrentTarget();
    if (!readiness.canOpen && !readiness.canMaterialize) {
      onBlocked?.call(readiness);
      return readiness;
    }

    try {
      workspace.editor.documentHistory.runCanonicalProjection(() {
        if (readiness.canMaterialize) {
          readiness = coordinator.materializeCurrentTarget();
        }
        if (!readiness.canOpen) {
          throw CanonicalEditorCutoverBlockedException(readiness);
        }
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

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _detachListeners();
  }

  void _onLegacyRuntimeChanged() {
    if (_disposed ||
        !_started ||
        _canonicalizingLegacyRoomRectangle ||
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
      if (_canonicalizeLegacyRoomRectangleIfNeeded()) {
        return;
      }
      final navigation = coordinator.pullLegacyToCanonical();
      if (navigation == null) return;
      _lastLegacySelectionFingerprint = fingerprint;
      _lastRejectedLegacySelectionFingerprint = null;
      onCanonicalNavigationChanged?.call(navigation);
    } catch (error, stackTrace) {
      _lastRejectedLegacySelectionFingerprint = _legacySelectionFingerprint();
      onError?.call(error, stackTrace);
    }
  }

  /// Transitional PRE-P12 bridge for the legacy two-click rectangle tool.
  ///
  /// The legacy controller still produces the tentative EngineeringSpace, but
  /// production never accepts it as authoritative state. Its architecture
  /// history entry is synchronously undone, then the exact rectangle is
  /// committed as one canonical Space + BoundaryTopology mutation on the same
  /// shared timeline used by Wizard authoring. Recording the canonical entry
  /// clears the temporary legacy redo entry, leaving one production Undo.
  bool _canonicalizeLegacyRoomRectangleIfNeeded() {
    final editor = workspace.editor;
    final legacySpaceId = editor.selectedSpaceId;
    if (legacySpaceId == null ||
        coordinator.adapter.binding.canonicalSpaceIdForLegacy(legacySpaceId) !=
            null) {
      return false;
    }

    final candidate = editor.selectedSpace;
    if (candidate == null ||
        candidate.type != SpaceType.room ||
        !_isAxisAlignedRectangle(candidate)) {
      return false;
    }

    final history = editor.documentHistory;
    if (history.undoLabel != 'Edit architecture') {
      return false;
    }

    _canonicalizingLegacyRoomRectangle = true;
    var rolledBack = false;
    var canonicalCommitted = false;
    try {
      if (!history.undo()) {
        throw StateError(
          'Production room cutover could not roll back the tentative legacy '
          'architecture mutation.',
        );
      }
      rolledBack = true;
      if (editor.level.spaces.any((space) => space.id == legacySpaceId)) {
        throw StateError(
          'Tentative legacy Room survived production rollback.',
        );
      }

      final session = coordinator.session;
      final levelId = session.navigation.activeLevelId;
      if (levelId == null ||
          coordinator.adapter.binding.legacyLevelIds[levelId] !=
              editor.level.id) {
        throw StateError(
          'Production room rectangle requires the active canonical Level to '
          'match the visible legacy Level.',
        );
      }
      final owner = onCanonicalMutationReplayed;
      if (owner == null) {
        throw StateError(
          'Production room rectangle requires canonical persistence ownership.',
        );
      }
      final mutations = CanonicalEditorWizardRuntimeRegistry.resolve(session);
      if (mutations == null) {
        throw StateError(
          'Production room rectangle requires the shared canonical mutation '
          'port.',
        );
      }

      final canonicalLevel = session.project.index.level(levelId);
      if (canonicalLevel == null) {
        throw StateError(
            'Active canonical Level disappeared before room commit.');
      }
      final bounds = candidate.boundary.bounds;
      final result = RoomRectangleAuthoringService(
        session: session,
        mutations: mutations,
      ).commit(
        RoomRectangleAuthoringIntent(
          levelId: levelId,
          first: BoundaryPointMm(xMm: bounds.left, yMm: bounds.bottom),
          second: BoundaryPointMm(xMm: bounds.right, yMm: bounds.top),
          name: 'Комната ${canonicalLevel.spaceIds.length + 1}',
        ),
      );
      canonicalCommitted = true;

      history.recordCanonicalCommit(
        session: session,
        label: result.commit.mutation.changeSet.commandType,
        rematerialize: pushCanonicalToEditor,
      );
      try {
        owner(result.commit.mutation);
      } catch (_) {
        history.invalidateAfterUnownedCanonicalCommit(session);
        rethrow;
      }

      final readiness = pushCanonicalToEditor();
      if (!readiness.canOpen) {
        history.invalidateAfterCommittedCanonicalDivergence(session);
        throw StateError(
          'Canonical Room committed but production materialization did not '
          'produce an openable editor representation.',
        );
      }
      _lastLegacySelectionFingerprint = _legacySelectionFingerprint();
      _lastRejectedLegacySelectionFingerprint = null;
      onCanonicalNavigationChanged?.call(session.navigation);
      return true;
    } catch (_) {
      if (rolledBack && !canonicalCommitted) {
        history.invalidateAfterCommittedCanonicalDivergence(
          coordinator.session,
        );
        _lastLegacySelectionFingerprint = _legacySelectionFingerprint();
        _lastRejectedLegacySelectionFingerprint = null;
      }
      rethrow;
    } finally {
      _canonicalizingLegacyRoomRectangle = false;
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
    workspace.editor.documentHistory
        .detachCanonicalSession(coordinator.session);
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

bool _isAxisAlignedRectangle(EngineeringSpace space) {
  final vertices = space.boundary.vertices;
  if (vertices.length != 4) return false;
  final bounds = space.boundary.bounds;
  if (bounds.width < 300 || bounds.height < 300) return false;
  final expected = <String>{
    '${bounds.left}:${bounds.bottom}',
    '${bounds.right}:${bounds.bottom}',
    '${bounds.right}:${bounds.top}',
    '${bounds.left}:${bounds.top}',
  };
  final actual = <String>{
    for (final point in vertices) '${point.x}:${point.y}',
  };
  return actual.length == 4 && actual.difference(expected).isEmpty;
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
