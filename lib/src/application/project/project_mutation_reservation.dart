import 'dart:convert';

import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'project_mutation.dart';

/// Durable entity identity kinds that may be allocated once for one preview/apply
/// lifecycle. BoundaryPenetrationId is represented separately because its
/// migration-compatible extension type intentionally is not an EntityId.
enum ReservedEntityIdKind {
  project,
  site,
  building,
  level,
  zone,
  space,
  opening,
  spaceAdjacency,
  overlayClassification,
  boundaryEdge,
  slab,
  verticalCore,
  serviceEntry,
  component,
  port,
  circuit,
  route,
  routeAnchor,
  generation,
  template,
  typicalFloorDefinition,
  engineeringConnection,
}

/// Immutable C5 identity allocation plan.
///
/// One instance is created exactly once for a preview. Revalidation and commit
/// reuse these values; commit never allocates replacement identities.
final class MutationIdentityReservation {
  MutationIdentityReservation._({
    required Map<String, EntityId> entityIds,
    required Map<String, BoundaryPenetrationId> penetrationIds,
  })  : _entityIds = Map.unmodifiable(entityIds),
        _penetrationIds = Map.unmodifiable(penetrationIds);

  factory MutationIdentityReservation.allocate({
    required EntityIdFactory factory,
    Map<String, ReservedEntityIdKind> entitySlots = const {},
    Iterable<String> boundaryPenetrationSlots = const [],
  }) {
    final entityIds = <String, EntityId>{};
    final penetrationIds = <String, BoundaryPenetrationId>{};
    final allSlots = <String>{};

    for (final entry in entitySlots.entries) {
      final slot = _validatedSlot(entry.key);
      if (!allSlots.add(slot)) {
        throw ArgumentError.value(
          slot,
          'entitySlots',
          'Duplicate reservation slot.',
        );
      }
      entityIds[slot] = _allocateEntityId(factory, entry.value);
    }
    for (final rawSlot in boundaryPenetrationSlots) {
      final slot = _validatedSlot(rawSlot);
      if (!allSlots.add(slot)) {
        throw ArgumentError.value(
          slot,
          'boundaryPenetrationSlots',
          'Duplicate reservation slot.',
        );
      }
      final id = factory.newBoundaryPenetrationId();
      if (id.trim().isEmpty) {
        throw StateError('EntityIdFactory allocated an empty penetration id.');
      }
      penetrationIds[slot] = id;
    }

    return MutationIdentityReservation._(
      entityIds: entityIds,
      penetrationIds: penetrationIds,
    );
  }

  final Map<String, EntityId> _entityIds;
  final Map<String, BoundaryPenetrationId> _penetrationIds;

  /// Joins child allocations into one immutable parent reservation. It neither
  /// allocates identities nor creates a second preview/commit timeline.
  factory MutationIdentityReservation.combineEntityReservations(
      Map<String, MutationIdentityReservation> children) {
    final ids = <String, EntityId>{};
    final distinct = <EntityId>{};
    for (final child in children.entries) {
      if (child.value._penetrationIds.isNotEmpty) {
        throw ArgumentError(
            'Entity-only composition cannot drop penetrations.');
      }
      for (final entry in child.value._entityIds.entries) {
        if (!distinct.add(entry.value)) {
          throw ArgumentError('Child reservations cannot alias identities.');
        }
        ids[jsonEncode([child.key, entry.key])] = entry.value;
      }
    }
    return MutationIdentityReservation._(entityIds: ids, penetrationIds: {});
  }

  /// Immutable local view of identities already allocated by the parent plan.
  /// Selection never allocates IDs or creates a second reservation timeline.
  MutationIdentityReservation selectEntitySlots(
      Map<String, String> localToParent) {
    if (localToParent.values.toSet().length != localToParent.length) {
      throw ArgumentError(
          'Distinct local slots must select distinct parent slots.');
    }
    final selected = <String, EntityId>{};
    for (final entry in localToParent.entries) {
      if (_validatedSlot(entry.key) != entry.key) {
        throw ArgumentError('Local slots must be normalized.');
      }
      selected[entry.key] = entityId<EntityId>(entry.value);
    }
    return MutationIdentityReservation._(
        entityIds: selected, penetrationIds: {});
  }

  Set<String> get slots =>
      Set.unmodifiable({..._entityIds.keys, ..._penetrationIds.keys});

  Set<EntityId> get entityIds => Set.unmodifiable(_entityIds.values);

  Set<BoundaryPenetrationId> get penetrationIds =>
      Set.unmodifiable(_penetrationIds.values);

  T entityId<T extends EntityId>(String slot) {
    final value = _entityIds[slot];
    if (value == null) {
      throw StateError('Reservation has no entity-id slot "$slot".');
    }
    if (value is! T) {
      throw StateError(
        'Reservation slot "$slot" contains ${value.runtimeType}, not $T.',
      );
    }
    return value;
  }

  BoundaryPenetrationId penetrationId(String slot) {
    final value = _penetrationIds[slot];
    if (value == null) {
      throw StateError('Reservation has no penetration-id slot "$slot".');
    }
    return value;
  }
}

String _validatedSlot(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    throw ArgumentError.value(
      raw,
      'slot',
      'Reservation slot must be non-empty.',
    );
  }
  return value;
}

EntityId _allocateEntityId(
  EntityIdFactory factory,
  ReservedEntityIdKind kind,
) =>
    switch (kind) {
      ReservedEntityIdKind.project => factory.newProjectId(),
      ReservedEntityIdKind.site => factory.newSiteId(),
      ReservedEntityIdKind.building => factory.newBuildingId(),
      ReservedEntityIdKind.level => factory.newLevelId(),
      ReservedEntityIdKind.zone => factory.newZoneId(),
      ReservedEntityIdKind.space => factory.newSpaceId(),
      ReservedEntityIdKind.opening => factory.newOpeningId(),
      ReservedEntityIdKind.spaceAdjacency => factory.newSpaceAdjacencyId(),
      ReservedEntityIdKind.overlayClassification =>
        factory.newOverlayClassificationId(),
      ReservedEntityIdKind.boundaryEdge => factory.newBoundaryEdgeId(),
      ReservedEntityIdKind.slab => factory.newSlabId(),
      ReservedEntityIdKind.verticalCore => factory.newVerticalCoreId(),
      ReservedEntityIdKind.serviceEntry => factory.newServiceEntryId(),
      ReservedEntityIdKind.component => factory.newComponentId(),
      ReservedEntityIdKind.port => factory.newPortId(),
      ReservedEntityIdKind.circuit => factory.newCircuitId(),
      ReservedEntityIdKind.route => factory.newRouteId(),
      ReservedEntityIdKind.routeAnchor => factory.newRouteAnchorId(),
      ReservedEntityIdKind.generation => factory.newGenerationId(),
      ReservedEntityIdKind.template => factory.newTemplateId(),
      ReservedEntityIdKind.typicalFloorDefinition =>
        factory.newTypicalFloorDefinitionId(),
      ReservedEntityIdKind.engineeringConnection =>
        factory.newEngineeringConnectionId(),
    };

/// C5 commands are pure planners over current canonical state plus one immutable
/// reservation. They do not allocate identities from buildCandidate.
abstract interface class ReservedProjectCommand {
  String get commandType;

  /// Stable canonical representation of user intent, excluding newly allocated
  /// identity values.
  String get normalizedIntentKey;

  MutationIdentityReservation reserveIdentities(EntityIdFactory factory);

  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  });

  /// Command-specific collision/ownership checks for reserved identities.
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  });

  /// Typed domain effects. Raw JSON/property diffs are not accepted here.
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  });
}

sealed class ProjectSemanticOperation {
  const ProjectSemanticOperation();

  String get semanticKey;
}

final class CreateEntityOperation extends ProjectSemanticOperation {
  const CreateEntityOperation({required this.entityId, this.ownerId});

  final EntityId entityId;
  final EntityId? ownerId;

  @override
  String get semanticKey =>
      'createEntity|${entityId.runtimeType}|${entityId.value}|${ownerId?.runtimeType}|${ownerId?.value}';
}

final class UpdateEntityOperation extends ProjectSemanticOperation {
  const UpdateEntityOperation({required this.entityId});

  final EntityId entityId;

  @override
  String get semanticKey =>
      'updateEntity|${entityId.runtimeType}|${entityId.value}';
}

final class RemoveEntityOperation extends ProjectSemanticOperation {
  const RemoveEntityOperation({required this.entityId, this.ownerId});

  final EntityId entityId;
  final EntityId? ownerId;

  @override
  String get semanticKey =>
      'removeEntity|${entityId.runtimeType}|${entityId.value}|${ownerId?.runtimeType}|${ownerId?.value}';
}

final class CreatePenetrationOperation extends ProjectSemanticOperation {
  const CreatePenetrationOperation({required this.penetrationId});

  final BoundaryPenetrationId penetrationId;

  @override
  String get semanticKey => 'createPenetration|$penetrationId';
}

final class AttachPenetrationToSlabOperation extends ProjectSemanticOperation {
  const AttachPenetrationToSlabOperation({
    required this.penetrationId,
    required this.slabId,
  });

  final BoundaryPenetrationId penetrationId;
  final SlabId slabId;

  @override
  String get semanticKey =>
      'attachPenetrationToSlab|$penetrationId|${slabId.value}';
}

final class BindPenetrationToVerticalCoreOperation
    extends ProjectSemanticOperation {
  const BindPenetrationToVerticalCoreOperation({
    required this.penetrationId,
    required this.verticalCoreId,
  });

  final BoundaryPenetrationId penetrationId;
  final VerticalCoreId verticalCoreId;

  @override
  String get semanticKey =>
      'bindPenetrationToVerticalCore|$penetrationId|${verticalCoreId.value}';
}

final class AddRouteAnchorOperation extends ProjectSemanticOperation {
  const AddRouteAnchorOperation({
    required this.routeAnchorId,
    required this.routeId,
  });

  final RouteAnchorId routeAnchorId;
  final RouteId routeId;

  @override
  String get semanticKey =>
      'addRouteAnchor|${routeId.value}|${routeAnchorId.value}';
}

final class AddHiddenVerticalRouteLegOperation
    extends ProjectSemanticOperation {
  const AddHiddenVerticalRouteLegOperation({
    required this.routeId,
    required this.verticalCoreId,
    required this.lengthMm,
  });

  final RouteId routeId;
  final VerticalCoreId verticalCoreId;
  final int lengthMm;

  @override
  String get semanticKey =>
      'addHiddenVerticalRouteLeg|${routeId.value}|${verticalCoreId.value}|$lengthMm';
}

final class UpdateEngineeringEvidenceOperation
    extends ProjectSemanticOperation {
  const UpdateEngineeringEvidenceOperation({
    required this.entityId,
    required this.lengthDeltaMm,
  });

  final EntityId entityId;
  final double lengthDeltaMm;

  @override
  String get semanticKey =>
      'updateEngineeringEvidence|${entityId.runtimeType}|${entityId.value}|$lengthDeltaMm';
}

final class RemovePhysicalDependencyOperation extends ProjectSemanticOperation {
  const RemovePhysicalDependencyOperation({
    required this.entityId,
    required this.ownerId,
  });

  final EntityId entityId;
  final EntityId ownerId;

  @override
  String get semanticKey =>
      'removePhysicalDependency|${entityId.runtimeType}|${entityId.value}|${ownerId.runtimeType}|${ownerId.value}';
}

final class ProjectSemanticChangeSet {
  ProjectSemanticChangeSet(Iterable<ProjectSemanticOperation> operations)
      : operations = List.unmodifiable(
          List<ProjectSemanticOperation>.of(operations)
            ..sort((a, b) {
              final categoryComparison = _semanticOperationCategory(a)
                  .compareTo(_semanticOperationCategory(b));
              if (categoryComparison != 0) return categoryComparison;
              return a.semanticKey.compareTo(b.semanticKey);
            }),
        ) {
    final keys = <String>{};
    for (final operation in this.operations) {
      if (!keys.add(operation.semanticKey)) {
        throw ArgumentError(
          'Semantic change set contains duplicate operation ${operation.semanticKey}.',
        );
      }
    }
  }

  final List<ProjectSemanticOperation> operations;

  bool get isEmpty => operations.isEmpty;
  bool get isNotEmpty => operations.isNotEmpty;

  bool sameAs(ProjectSemanticChangeSet other) {
    if (operations.length != other.operations.length) return false;
    for (var index = 0; index < operations.length; index++) {
      if (operations[index].semanticKey !=
          other.operations[index].semanticKey) {
        return false;
      }
    }
    return true;
  }
}

/// Stable execution order for typed mutation effects.
///
/// A semantic key remains the deterministic tie-breaker within one phase, but
/// dependency phases are explicit: entities are created before their bindings,
/// route effects follow those bindings, engineering evidence follows the route,
/// and removals are applied last.
int _semanticOperationCategory(ProjectSemanticOperation operation) =>
    switch (operation) {
      CreateEntityOperation() || CreatePenetrationOperation() => 0,
      AttachPenetrationToSlabOperation() ||
      BindPenetrationToVerticalCoreOperation() =>
        1,
      AddRouteAnchorOperation() || AddHiddenVerticalRouteLegOperation() => 2,
      UpdateEntityOperation() || UpdateEngineeringEvidenceOperation() => 3,
      RemovePhysicalDependencyOperation() || RemoveEntityOperation() => 4,
    };

final class ReservedProjectMutationPreview {
  ReservedProjectMutationPreview._({
    required Object sessionIdentity,
    required this.observedVersion,
    required this.normalizedIntentKey,
    required this.reservation,
    required this.preview,
    required this.semanticChangeSet,
    required ReservedProjectCommand command,
  })  : _sessionIdentity = sessionIdentity,
        _command = command;

  final Object _sessionIdentity;
  final ReservedProjectCommand _command;
  final LocalProjectVersion observedVersion;
  final String normalizedIntentKey;
  final MutationIdentityReservation reservation;
  final ProjectMutationPreview preview;
  final ProjectSemanticChangeSet semanticChangeSet;

  ProjectAggregateRoot get candidate => preview.candidate;
  bool get hasChanges => preview.hasChanges;
}

final class ReservedProjectMutationCommitResult {
  const ReservedProjectMutationCommitResult({
    required this.mutation,
    required this.reservation,
    required this.semanticChangeSet,
  });

  final ProjectMutationResult mutation;
  final MutationIdentityReservation reservation;
  final ProjectSemanticChangeSet semanticChangeSet;
}

final class ForeignMutationPreviewException implements Exception {
  const ForeignMutationPreviewException();

  @override
  String toString() =>
      'Mutation preview belongs to a different canonical mutation session.';
}

final class ConsumedMutationReservationException implements Exception {
  const ConsumedMutationReservationException();

  @override
  String toString() =>
      'Mutation identity reservation has already been consumed.';
}

/// C5 preview/apply coordinator layered on the existing ProjectMutationSession.
///
/// It deliberately reuses the canonical session's validation, versioning,
/// history and undo/redo protocol. Commit applies the frozen preview candidate,
/// so no command planner or random allocator runs a second time after user
/// confirmation.
final class ReservedProjectMutationCoordinator {
  ReservedProjectMutationCoordinator(
    this.session, {
    EntityIdFactory? entityIdFactory,
  }) : entityIdFactory = entityIdFactory ?? SecureRandomEntityIdFactory();

  final ProjectMutationSession session;
  final EntityIdFactory entityIdFactory;
  final Object _sessionIdentity = Object();
  final Set<MutationIdentityReservation> _consumedReservations =
      <MutationIdentityReservation>{};

  ReservedProjectMutationPreview preview(ReservedProjectCommand command) {
    final normalizedIntentKey = command.normalizedIntentKey.trim();
    if (normalizedIntentKey.isEmpty) {
      throw ArgumentError.value(
        command.normalizedIntentKey,
        'normalizedIntentKey',
        'Normalized mutation intent must be non-empty.',
      );
    }

    final observedVersion = session.current.version;
    final reservation = command.reserveIdentities(entityIdFactory);
    command.validateReservation(
      current: session.current,
      reservation: reservation,
    );
    final boundCommand = _ReservationBoundCommand(
      command: command,
      reservation: reservation,
    );
    final corePreview = session.preview(
      ProjectMutationRequest(
        expectedVersion: observedVersion,
        command: boundCommand,
      ),
    );
    final semanticChangeSet = ProjectSemanticChangeSet(
      command.semanticOperations(
        before: session.current,
        candidate: corePreview.candidate,
        reservation: reservation,
      ),
    );
    if (corePreview.hasChanges != semanticChangeSet.isNotEmpty) {
      throw StateError(
        'Reserved mutation must provide typed semantic operations exactly when '
        'the canonical candidate changes.',
      );
    }

    return ReservedProjectMutationPreview._(
      sessionIdentity: _sessionIdentity,
      observedVersion: observedVersion,
      normalizedIntentKey: normalizedIntentKey,
      reservation: reservation,
      preview: corePreview,
      semanticChangeSet: semanticChangeSet,
      command: command,
    );
  }

  ReservedProjectMutationCommitResult? commitPreview(
    ReservedProjectMutationPreview planned,
  ) {
    if (!identical(planned._sessionIdentity, _sessionIdentity)) {
      throw const ForeignMutationPreviewException();
    }
    if (_consumedReservations.contains(planned.reservation)) {
      throw const ConsumedMutationReservationException();
    }
    if (session.current.version != planned.observedVersion) {
      throw StaleProjectMutationException(
        expectedVersion: planned.observedVersion,
        currentVersion: session.current.version,
      );
    }

    planned._command.validateReservation(
      current: session.current,
      reservation: planned.reservation,
    );

    final result = session.commit(
      ProjectMutationRequest(
        expectedVersion: planned.observedVersion,
        command: _FrozenPreviewCommand(planned),
      ),
    );
    if (result == null) return null;

    _consumedReservations.add(planned.reservation);
    return ReservedProjectMutationCommitResult(
      mutation: result,
      reservation: planned.reservation,
      semanticChangeSet: planned.semanticChangeSet,
    );
  }
}

final class _ReservationBoundCommand implements ProjectCommand {
  const _ReservationBoundCommand({
    required this.command,
    required this.reservation,
  });

  final ReservedProjectCommand command;
  final MutationIdentityReservation reservation;

  @override
  String get commandType => command.commandType;

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) =>
      command.buildCandidate(current: current, reservation: reservation);
}

final class _FrozenPreviewCommand implements ProjectCommand {
  const _FrozenPreviewCommand(this.planned);

  final ReservedProjectMutationPreview planned;

  @override
  String get commandType => planned.preview.commandType;

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    if (current.version != planned.observedVersion) {
      throw StaleProjectMutationException(
        expectedVersion: planned.observedVersion,
        currentVersion: current.version,
      );
    }
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: planned.candidate.engineeringMetadata,
        stores: planned.candidate.stores,
      ),
      affectedEntityIds: planned.preview.declaredAffectedEntityIds,
    );
  }
}
