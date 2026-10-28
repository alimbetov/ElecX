import '../../application/project/project_structure_authoring.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'canonical_editor_workspace_adapter.dart';

enum CanonicalEditorCutoverPhase { idle, applyingCanonical, pullingLegacy }

enum CanonicalEditorMaterializationStatus {
  alreadyMaterialized,
  materializable,
  blockedCanonicalMismatch,
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
      status == CanonicalEditorMaterializationStatus.alreadyMaterialized;

  bool get canMaterialize =>
      status == CanonicalEditorMaterializationStatus.materializable;
}

abstract interface class CanonicalEditorMaterializer {
  /// Pure readiness inspection. Implementations must not mutate canonical or
  /// legacy runtime state from this method.
  CanonicalEditorMaterializationResult inspect({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceBinding binding,
  });
}

/// Opt-in runtime extension for production owners that can project canonical
/// geometry into the transitional legacy workspace.
///
/// [materialize] is invoked only after a pure [inspect] result reports
/// `materializable`. The canonical aggregate remains authoritative and must not
/// be mutated by this compatibility projection.
abstract interface class CanonicalEditorRuntimeMaterializer
    implements CanonicalEditorMaterializer {
  CanonicalEditorMaterializationResult materialize({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceAdapter adapter,
  });
}

/// Conservative materializer for the transitional workspace. It never invents
/// geometry. Existing explicit bindings are treated as materialized; a new
/// canonical Space without an EngineeringSpace binding is blocked until a
/// geometry-owning production materializer projects it correctly.
final class ExistingBindingCanonicalEditorMaterializer
    implements CanonicalEditorMaterializer {
  const ExistingBindingCanonicalEditorMaterializer();

  @override
  CanonicalEditorMaterializationResult inspect({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceBinding binding,
  }) {
    if (navigation.siteId != project.siteId) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus.blockedCanonicalMismatch,
        entityId: navigation.siteId,
        message: 'Navigation and canonical project belong to different Sites.',
      );
    }

    final buildingId = navigation.activeBuildingId;
    final building =
        buildingId == null ? null : project.index.building(buildingId);
    if (buildingId == null ||
        building == null ||
        building.siteId != project.siteId ||
        buildingId != binding.buildingId) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: buildingId,
        message: 'Active canonical Building has no coherent bound legacy '
            'workspace.',
      );
    }

    final levelId = navigation.activeLevelId;
    final level = levelId == null ? null : project.index.level(levelId);
    if (levelId == null || level == null || level.buildingId != buildingId) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus.blockedCanonicalMismatch,
        entityId: levelId,
        message: 'Active canonical Level is missing or does not belong to the '
            'active Building.',
      );
    }
    if (binding.legacyLevelIds[levelId] == null) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: levelId,
        message: 'Active canonical Level has no legacy runtime representation.',
      );
    }

    final zoneId = navigation.selectedZoneId;
    if (zoneId != null) {
      final zone = project.index.zone(zoneId);
      if (zone == null || zone.levelId != levelId) {
        return CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus.blockedCanonicalMismatch,
          entityId: zoneId,
          message: 'Selected canonical Zone is missing or does not belong to '
              'the active Level.',
        );
      }
      if (binding.legacyZoneIds[zoneId] == null) {
        return CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus
              .blockedMissingRuntimeRepresentation,
          entityId: zoneId,
          message:
              'Selected canonical Zone has no legacy runtime representation.',
        );
      }
    }

    final spaceId = navigation.selectedSpaceId;
    if (spaceId != null) {
      final space = project.index.space(spaceId);
      if (space == null || space.levelId != levelId) {
        return CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus.blockedCanonicalMismatch,
          entityId: spaceId,
          message: 'Selected canonical Space is missing or does not belong to '
              'the active Level.',
        );
      }

      final owningZoneId = project.index.structuralZoneBySpace[spaceId];
      if (owningZoneId != zoneId) {
        return CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus.blockedCanonicalMismatch,
          entityId: spaceId,
          message: 'Selected canonical Space/Zone path is incoherent with the '
              'canonical structural-zone membership.',
        );
      }

      if (binding.legacySpaceIds[spaceId] == null) {
        return CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus.blockedMissingGeometry,
          entityId: spaceId,
          message: 'Selected canonical Space has no materialized geometry.',
        );
      }
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

  /// Materializes the current canonical target only when the configured owner
  /// explicitly implements [CanonicalEditorRuntimeMaterializer]. Inspect-only
  /// materializers retain the historical fail-closed behavior.
  CanonicalEditorMaterializationResult materializeCurrentTarget() {
    if (_phase != CanonicalEditorCutoverPhase.idle) {
      throw StateError('Canonical editor cutover is already synchronizing.');
    }
    final readiness = inspectCurrentTarget();
    if (!readiness.canMaterialize) return readiness;

    final materializer = _materializer;
    if (materializer is! CanonicalEditorRuntimeMaterializer) {
      return readiness;
    }

    _phase = CanonicalEditorCutoverPhase.applyingCanonical;
    try {
      return materializer.materialize(
        project: session.project,
        navigation: session.navigation,
        adapter: adapter,
      );
    } finally {
      _phase = CanonicalEditorCutoverPhase.idle;
    }
  }

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
  /// The complete adapter-produced location is adopted atomically by the
  /// application session, so a rejected pull cannot leave a partially changed
  /// Building/Level/Space navigation path.
  ProjectNavigationState? pullLegacyToCanonical() {
    if (_phase != CanonicalEditorCutoverPhase.idle) return null;

    _phase = CanonicalEditorCutoverPhase.pullingLegacy;
    try {
      final next = adapter.pullLegacySelection(
        project: session.project,
        navigation: session.navigation,
      );
      session.adoptNavigation(next);
      return session.navigation;
    } finally {
      _phase = CanonicalEditorCutoverPhase.idle;
    }
  }
}
