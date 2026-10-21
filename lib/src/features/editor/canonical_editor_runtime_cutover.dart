import '../../application/project/project_navigation_state.dart';
import '../../application/project/project_structure_authoring.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'canonical_editor_workspace_adapter.dart';

enum CanonicalEditorCutoverPhase { idle, applyingCanonical, pullingLegacy }

enum CanonicalEditorMaterializationStatus {
  alreadyMaterialized,
  materializable,
  blockedMissingGeometry,
  blockedMissingRuntimeRepresentation,
}

final class CanonicalEditorMaterializationResult {
  const CanonicalEditorMaterializationResult({
    required this.status,
    this.entityId,
    this.message,
  });

  final CanonicalEditorMaterializationStatus status;
  final EntityId? entityId;
  final String? message;

  bool get canOpen =>
      status == CanonicalEditorMaterializationStatus.alreadyMaterialized ||
      status == CanonicalEditorMaterializationStatus.materializable;
}

abstract interface class CanonicalEditorMaterializer {
  CanonicalEditorMaterializationResult inspect({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceBinding binding,
  });
}

/// Conservative materializer for the transitional workspace. It never invents
/// geometry. Existing explicit bindings are treated as materialized; a new
/// canonical Space without an EngineeringSpace binding is blocked until a
/// later geometry-owning stage can materialize it correctly.
final class ExistingBindingCanonicalEditorMaterializer
    implements CanonicalEditorMaterializer {
  const ExistingBindingCanonicalEditorMaterializer();

  @override
  CanonicalEditorMaterializationResult inspect({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceBinding binding,
  }) {
    final buildingId = navigation.activeBuildingId;
    if (buildingId == null || buildingId != binding.buildingId) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: buildingId,
        message: 'Active canonical Building has no bound legacy workspace.',
      );
    }

    final levelId = navigation.activeLevelId;
    if (levelId == null || binding.legacyLevelIds[levelId] == null) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: levelId,
        message: 'Active canonical Level has no legacy runtime representation.',
      );
    }

    final zoneId = navigation.selectedZoneId;
    if (zoneId != null && binding.legacyZoneIds[zoneId] == null) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: zoneId,
        message: 'Selected canonical Zone has no legacy runtime representation.',
      );
    }

    final spaceId = navigation.selectedSpaceId;
    if (spaceId != null && binding.legacySpaceIds[spaceId] == null) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus.blockedMissingGeometry,
        entityId: spaceId,
        message: 'Selected canonical Space has no materialized geometry.',
      );
    }

    return const CanonicalEditorMaterializationResult(
      status: CanonicalEditorMaterializationStatus.alreadyMaterialized,
    );
  }
}

final class CanonicalEditorCutoverBlockedException implements Exception {
  const CanonicalEditorCutoverBlockedException(this.result);

  final CanonicalEditorMaterializationResult result;

  @override
  String toString() =>
      'canonicalEditorCutoverBlocked: ${result.status.name}: ${result.message}';
}

/// Single orchestration boundary between canonical navigation and the
/// transitional editor workspace. The phase guard prevents listener feedback
/// loops while one side is being projected onto the other.
final class CanonicalEditorRuntimeCutoverCoordinator {
  CanonicalEditorRuntimeCutoverCoordinator({
    required this.session,
    required this.adapter,
    CanonicalEditorMaterializer materializer =
        const ExistingBindingCanonicalEditorMaterializer(),
  }) : _materializer = materializer;

  final ProjectStructureAuthoringSession session;
  final CanonicalEditorWorkspaceAdapter adapter;
  final CanonicalEditorMaterializer _materializer;

  CanonicalEditorCutoverPhase _phase = CanonicalEditorCutoverPhase.idle;
  CanonicalEditorCutoverPhase get phase => _phase;
  bool get isSynchronizing => _phase != CanonicalEditorCutoverPhase.idle;

  CanonicalEditorMaterializationResult inspectCurrentTarget() =>
      _materializer.inspect(
        project: session.project,
        navigation: session.navigation,
        binding: adapter.binding,
      );

  void pushCanonicalToEditor() {
    if (_phase != CanonicalEditorCutoverPhase.idle) return;
    final readiness = inspectCurrentTarget();
    if (!readiness.canOpen) {
      throw CanonicalEditorCutoverBlockedException(readiness);
    }

    _phase = CanonicalEditorCutoverPhase.applyingCanonical;
    try {
      adapter.applyCanonicalNavigation(
        project: session.project,
        navigation: session.navigation,
      );
    } finally {
      _phase = CanonicalEditorCutoverPhase.idle;
    }
  }

  /// Pulls legacy selection only when no canonical projection is in progress.
  /// The application session is updated through its typed navigation API, so
  /// this coordinator never reaches into private navigation state.
  ProjectNavigationState? pullLegacyToCanonical() {
    if (_phase != CanonicalEditorCutoverPhase.idle) return null;

    _phase = CanonicalEditorCutoverPhase.pullingLegacy;
    try {
      final next = adapter.pullLegacySelection(
        project: session.project,
        navigation: session.navigation,
      );
      _applyNavigation(next);
      return session.navigation;
    } finally {
      _phase = CanonicalEditorCutoverPhase.idle;
    }
  }

  void _applyNavigation(ProjectNavigationState next) {
    final buildingId = next.activeBuildingId;
    if (buildingId == null) return;
    session.activateBuilding(buildingId);

    final levelId = next.activeLevelId;
    if (levelId != null) {
      session.activateLevel(levelId);
    }

    final spaceId = next.selectedSpaceId;
    if (spaceId != null) {
      session.selectRoom(spaceId);
      return;
    }

    final zoneId = next.selectedZoneId;
    if (zoneId != null) {
      session.selectZone(zoneId);
      return;
    }

    session.clearSelection();
  }
}
