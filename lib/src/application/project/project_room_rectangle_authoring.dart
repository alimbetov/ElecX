import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_mutation.dart';
import 'project_mutation_reservation.dart';
import 'project_space_boundary_commands.dart';
import 'project_structure_authoring.dart';
import 'wizard/project_wizard_mutation_port.dart';

const String _spaceSlot = 'room';
const List<String> _edgeSlots = <String>[
  'edge-0',
  'edge-1',
  'edge-2',
  'edge-3',
];

/// Frozen user intent for one axis-aligned room rectangle in canonical mm.
final class RoomRectangleAuthoringIntent {
  const RoomRectangleAuthoringIntent({
    required this.levelId,
    required this.first,
    required this.second,
    required this.name,
  });

  final LevelId levelId;
  final BoundaryPointMm first;
  final BoundaryPointMm second;
  final String name;

  List<BoundaryPointMm> normalizedBoundary() {
    final left = first.xMm < second.xMm ? first.xMm : second.xMm;
    final right = first.xMm > second.xMm ? first.xMm : second.xMm;
    final bottom = first.yMm < second.yMm ? first.yMm : second.yMm;
    final top = first.yMm > second.yMm ? first.yMm : second.yMm;
    if (right - left < 300 || top - bottom < 300) {
      throw ArgumentError(
        'Production room rectangle must be at least 300 mm in both axes.',
      );
    }
    return <BoundaryPointMm>[
      BoundaryPointMm(xMm: left, yMm: bottom),
      BoundaryPointMm(xMm: right, yMm: bottom),
      BoundaryPointMm(xMm: right, yMm: top),
      BoundaryPointMm(xMm: left, yMm: top),
    ];
  }
}

/// Reserved form of [CreateSpaceWithBoundaryCommand]. Preview and commit reuse
/// exactly the same Space/BoundaryEdge identities on the shared mutation port.
final class ReservedCreateRoomRectangleCommand implements ReservedProjectCommand {
  ReservedCreateRoomRectangleCommand(this.intent)
      : _boundary = intent.normalizedBoundary() {
    if (intent.name.trim().isEmpty) {
      throw ArgumentError.value(intent.name, 'name', 'Room name is required.');
    }
  }

  final RoomRectangleAuthoringIntent intent;
  final List<BoundaryPointMm> _boundary;

  @override
  String get commandType => 'project.space.create-room-rectangle';

  @override
  String get normalizedIntentKey => <Object>[
        commandType,
        intent.levelId.value,
        intent.name.trim(),
        for (final point in _boundary) '${point.xMm},${point.yMm}',
      ].join('|');

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(
        factory: factory,
        entitySlots: <String, ReservedEntityIdKind>{
          _spaceSlot: ReservedEntityIdKind.space,
          for (final slot in _edgeSlots) slot: ReservedEntityIdKind.boundaryEdge,
        },
      );

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) =>
      CreateSpaceWithBoundaryCommand(
        spaceId: reservation.entityId<SpaceId>(_spaceSlot),
        levelId: intent.levelId,
        name: intent.name.trim(),
        boundaryPoints: _boundary,
        boundaryEdgeIds: <BoundaryEdgeId>[
          for (final slot in _edgeSlots)
            reservation.entityId<BoundaryEdgeId>(slot),
        ],
      ).buildCandidate(current);

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    final roomId = reservation.entityId<SpaceId>(_spaceSlot);
    if (current.index.space(roomId) != null) {
      throw StateError('Reserved room identity already exists: $roomId.');
    }
    final edgeIds = <BoundaryEdgeId>{
      for (final slot in _edgeSlots)
        reservation.entityId<BoundaryEdgeId>(slot),
    };
    if (edgeIds.length != _edgeSlots.length) {
      throw StateError('Reserved boundary edge identities must be distinct.');
    }
    for (final topology in current.stores.boundaries.values) {
      for (final edgeId in edgeIds) {
        if (topology.edges.containsKey(edgeId)) {
          throw StateError('Reserved boundary identity already exists: $edgeId.');
        }
      }
    }
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) sync* {
    final roomId = reservation.entityId<SpaceId>(_spaceSlot);
    yield CreateEntityOperation(entityId: roomId, ownerId: intent.levelId);
    for (final slot in _edgeSlots) {
      yield CreateEntityOperation(
        entityId: reservation.entityId<BoundaryEdgeId>(slot),
        ownerId: roomId,
      );
    }
  }
}

final class RoomRectangleAuthoringResult {
  const RoomRectangleAuthoringResult({
    required this.spaceId,
    required this.commit,
  });

  final SpaceId spaceId;
  final ReservedProjectMutationCommitResult commit;
}

/// Production application service for manual rectangle authoring.
///
/// It never owns a mutation session or ID factory. Both are inherited from the
/// already-composed [ProjectWizardMutationPort], so manual rooms cannot fork
/// versioning, Undo/Redo, or durable identity allocation from the production
/// project timeline.
final class RoomRectangleAuthoringService {
  RoomRectangleAuthoringService({
    required this.session,
    required this.mutations,
  });

  final ProjectStructureAuthoringSession session;
  final ProjectWizardMutationPort mutations;

  RoomRectangleAuthoringResult commit(RoomRectangleAuthoringIntent intent) {
    _requireSharedTimeline();
    if (session.navigation.activeLevelId != intent.levelId) {
      throw StateError(
        'Room rectangle target must be the active canonical Level.',
      );
    }

    final preview = mutations.preview(ReservedCreateRoomRectangleCommand(intent));
    final result = mutations.commitPreview(preview);
    if (result == null) {
      mutations.discardPreview(preview);
      throw StateError('Room rectangle produced no canonical mutation.');
    }
    _requireSharedTimeline();

    final spaceId = result.reservation.entityId<SpaceId>(_spaceSlot);
    session.selectRoom(spaceId);
    return RoomRectangleAuthoringResult(spaceId: spaceId, commit: result);
  }

  void _requireSharedTimeline() {
    if (mutations.project.id != session.project.id ||
        mutations.version != session.project.version ||
        !identical(mutations.project, session.project)) {
      throw StateError(
        'Room rectangle authoring requires the shared production mutation '
        'timeline.',
      );
    }
  }
}
