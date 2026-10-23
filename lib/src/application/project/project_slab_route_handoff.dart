import '../../domain/canonical_slab_route_handoff.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_navigation_state.dart';
import 'project_structure_authoring.dart';

enum ProjectSlabRouteHandoffIssueCode {
  routeIdRequired,
  handoffAlreadyPending,
  handoffNotPending,
  sourceSpaceNotSelected,
  physicalSlabNotResolved,
  projectChanged,
  navigationChanged,
  physicalHostChanged,
}

final class ProjectSlabRouteHandoffException implements Exception {
  const ProjectSlabRouteHandoffException({
    required this.code,
    required this.message,
    this.entityId,
    this.relatedEntityId,
  });

  final ProjectSlabRouteHandoffIssueCode code;
  final String message;
  final EntityId? entityId;
  final EntityId? relatedEntityId;

  @override
  String toString() => '${code.name}: $message';
}

/// Immutable admission receipt for one cross-level route continuation.
///
/// It captures the exact canonical project version and navigation context before
/// any editor level switch is allowed. [routeId] is deliberately opaque here:
/// the electrical layer remains the owner of route persistence, while this
/// application contract guarantees that the same route identity is carried
/// across the vertical navigation handoff.
final class ProjectSlabRouteHandoffIntent {
  const ProjectSlabRouteHandoffIntent({
    required this.routeId,
    required this.projectId,
    required this.expectedVersion,
    required this.sourceNavigation,
    required this.plan,
  });

  final String routeId;
  final ProjectId projectId;
  final LocalProjectVersion expectedVersion;
  final ProjectNavigationState sourceNavigation;
  final CanonicalSlabRouteHandoffPlan plan;

  SlabId get slabId => plan.slabId;
}

/// Canonical navigation transaction for ceiling↔floor authoring.
///
/// This session does not mutate the project aggregate and does not touch the
/// legacy editor draft. Its responsibility is narrower: prove and pin one
/// physical [SlabId] host, preserve the opaque electrical route identity, and
/// move canonical navigation to the target space only when the captured project
/// version and source navigation are still exact.
final class ProjectSlabRouteHandoffSession {
  ProjectSlabRouteHandoffSession(this._structure);

  final ProjectStructureAuthoringSession _structure;
  ProjectSlabRouteHandoffIntent? _pending;

  ProjectSlabRouteHandoffIntent? get pending => _pending;
  bool get hasPending => _pending != null;

  ProjectSlabRouteHandoffIntent prepare({
    required String routeId,
    required SpaceId fromSpaceId,
    required SpaceId toSpaceId,
  }) {
    if (_pending != null) {
      throw const ProjectSlabRouteHandoffException(
        code: ProjectSlabRouteHandoffIssueCode.handoffAlreadyPending,
        message: 'A slab route handoff is already pending.',
      );
    }

    final normalizedRouteId = routeId.trim();
    if (normalizedRouteId.isEmpty) {
      throw const ProjectSlabRouteHandoffException(
        code: ProjectSlabRouteHandoffIssueCode.routeIdRequired,
        message: 'Cross-level route handoff requires a stable route id.',
      );
    }

    final navigation = _structure.navigation;
    if (navigation.selectedSpaceId != fromSpaceId) {
      throw ProjectSlabRouteHandoffException(
        code: ProjectSlabRouteHandoffIssueCode.sourceSpaceNotSelected,
        entityId: navigation.selectedSpaceId,
        relatedEntityId: fromSpaceId,
        message: 'Cross-level authoring must start from the currently selected '
            'canonical SpaceId.',
      );
    }

    final project = _structure.project;
    final plan = CanonicalSlabRouteHandoffPlanner.resolve(
      project: project,
      fromSpaceId: fromSpaceId,
      toSpaceId: toSpaceId,
    );
    if (plan == null) {
      throw ProjectSlabRouteHandoffException(
        code: ProjectSlabRouteHandoffIssueCode.physicalSlabNotResolved,
        entityId: fromSpaceId,
        relatedEntityId: toSpaceId,
        message: 'No unique canonical inter-level slab owns the requested '
            'SpaceId transition.',
      );
    }

    final intent = ProjectSlabRouteHandoffIntent(
      routeId: normalizedRouteId,
      projectId: project.id,
      expectedVersion: project.version,
      sourceNavigation: navigation,
      plan: plan,
    );
    _pending = intent;
    return intent;
  }

  CanonicalSlabRouteHandoffPlan commitNavigation() {
    final intent = _pending;
    if (intent == null) {
      throw const ProjectSlabRouteHandoffException(
        code: ProjectSlabRouteHandoffIssueCode.handoffNotPending,
        message: 'No slab route handoff is pending.',
      );
    }

    final project = _structure.project;
    if (project.id != intent.projectId ||
        project.version != intent.expectedVersion) {
      throw ProjectSlabRouteHandoffException(
        code: ProjectSlabRouteHandoffIssueCode.projectChanged,
        entityId: project.id,
        relatedEntityId: intent.projectId,
        message: 'Canonical project identity/version changed after the slab '
            'handoff was prepared.',
      );
    }
    if (_structure.navigation != intent.sourceNavigation) {
      throw ProjectSlabRouteHandoffException(
        code: ProjectSlabRouteHandoffIssueCode.navigationChanged,
        entityId: _structure.navigation.selectedSpaceId,
        relatedEntityId: intent.plan.fromSpaceId,
        message: 'Canonical navigation changed after the slab handoff was '
            'prepared.',
      );
    }

    final currentPlan = CanonicalSlabRouteHandoffPlanner.resolve(
      project: project,
      fromSpaceId: intent.plan.fromSpaceId,
      toSpaceId: intent.plan.toSpaceId,
    );
    if (currentPlan == null ||
        currentPlan.slabId != intent.plan.slabId ||
        currentPlan.entryFace != intent.plan.entryFace ||
        currentPlan.exitFace != intent.plan.exitFace) {
      throw ProjectSlabRouteHandoffException(
        code: ProjectSlabRouteHandoffIssueCode.physicalHostChanged,
        entityId: currentPlan?.slabId,
        relatedEntityId: intent.plan.slabId,
        message: 'The physical slab host changed after handoff preparation.',
      );
    }

    _structure.selectRoom(intent.plan.toSpaceId);
    _pending = null;
    return intent.plan;
  }

  void cancel() {
    _pending = null;
  }
}
