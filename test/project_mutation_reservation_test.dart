import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7 C5 reserved mutation lifecycle', () {
    test('preview reserves once and commit keeps exact preview identity', () {
      final session = ProjectMutationSession(_project());
      final coordinator = ReservedProjectMutationCoordinator(session);
      final planned =
          coordinator.preview(const _CreateBuildingReservedCommand());
      final reservedId = planned.reservation.entityId<BuildingId>('building');

      expect(planned.candidate.stores.buildings.keys, {reservedId});
      expect(session.current.stores.buildings, isEmpty);
      expect(session.undoDepth, 0);
      expect(
        planned.semanticChangeSet.operations
            .whereType<CreateEntityOperation>()
            .single
            .entityId,
        reservedId,
      );

      final committed = coordinator.commitPreview(planned)!;

      expect(committed.mutation.project.stores.buildings.keys, {reservedId});
      expect(
        committed.reservation.entityId<BuildingId>('building'),
        same(reservedId),
      );
      expect(
        committed.semanticChangeSet.sameAs(planned.semanticChangeSet),
        isTrue,
      );
      expect(session.current.stores.buildings.keys, {reservedId});
      expect(session.undoDepth, 1);
    });

    test('old preview fails closed after canonical version changes', () {
      final session = ProjectMutationSession(_project());
      final coordinator = ReservedProjectMutationCoordinator(session);
      final planned =
          coordinator.preview(const _CreateBuildingReservedCommand());

      session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: const _RenameSiteCommand('Changed elsewhere'),
        ),
      );

      expect(
        () => coordinator.commitPreview(planned),
        throwsA(isA<StaleProjectMutationException>()),
      );
      expect(session.current.stores.buildings, isEmpty);
    });

    test('preview is bound to exact coordinator/session identity', () {
      final session = ProjectMutationSession(_project());
      final owner = ReservedProjectMutationCoordinator(session);
      final foreign = ReservedProjectMutationCoordinator(session);
      final planned = owner.preview(const _CreateBuildingReservedCommand());

      expect(
        () => foreign.commitPreview(planned),
        throwsA(isA<ForeignMutationPreviewException>()),
      );
      expect(session.current.stores.buildings, isEmpty);
    });

    test('a committed reservation cannot be consumed twice', () {
      final session = ProjectMutationSession(_project());
      final coordinator = ReservedProjectMutationCoordinator(session);
      final planned =
          coordinator.preview(const _CreateBuildingReservedCommand());

      expect(coordinator.commitPreview(planned), isNotNull);
      expect(
        () => coordinator.commitPreview(planned),
        throwsA(isA<ConsumedMutationReservationException>()),
      );
    });

    test('semantic operation ordering is canonical and independent of input',
        () {
      final siteId = SiteId('site');
      final buildingId = BuildingId('building');
      final first = ProjectSemanticChangeSet([
        UpdateEntityOperation(entityId: siteId),
        CreateEntityOperation(entityId: buildingId, ownerId: siteId),
      ]);
      final second = ProjectSemanticChangeSet([
        CreateEntityOperation(entityId: buildingId, ownerId: siteId),
        UpdateEntityOperation(entityId: siteId),
      ]);

      expect(first.sameAs(second), isTrue);
      expect(
        first.operations.map((operation) => operation.semanticKey),
        orderedEquals(
          [...first.operations.map((operation) => operation.semanticKey)]
            ..sort(),
        ),
      );
    });

    test('reservation rejects duplicate cross-kind slot names', () {
      expect(
        () => MutationIdentityReservation.allocate(
          factory: SecureRandomEntityIdFactory(),
          entitySlots: const {'crossing': ReservedEntityIdKind.routeAnchor},
          boundaryPenetrationSlots: const ['crossing'],
        ),
        throwsArgumentError,
      );
    });
  });
}

ProjectAggregateRoot _project() {
  final siteId = SiteId('site');
  return ProjectAggregateRoot(
    id: ProjectId('project'),
    siteId: siteId,
    version: LocalProjectVersion(7),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: const [],
        ),
      },
    ),
  );
}

final class _CreateBuildingReservedCommand implements ReservedProjectCommand {
  const _CreateBuildingReservedCommand();

  @override
  String get commandType => 'test.reserved-building.create';

  @override
  String get normalizedIntentKey => 'create-building|site|Building';

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(
        factory: factory,
        entitySlots: const {'building': ReservedEntityIdKind.building},
      );

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    final buildingId = reservation.entityId<BuildingId>('building');
    if (current.stores.buildings.containsKey(buildingId)) {
      throw StateError('Reserved BuildingId already exists.');
    }
  }

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    final site = current.stores.sites[current.siteId]!;
    final buildingId = reservation.entityId<BuildingId>('building');
    final sites = Map<SiteId, ProjectSiteEntity>.from(current.stores.sites)
      ..[site.id] = ProjectSiteEntity(
        id: site.id,
        name: site.name,
        buildingIds: {...site.buildingIds, buildingId},
      );
    final buildings = Map<BuildingId, ProjectBuildingEntity>.from(
      current.stores.buildings,
    )..[buildingId] = ProjectBuildingEntity(
        id: buildingId,
        siteId: site.id,
        name: 'Building',
        levelIds: const [],
      );

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          sites: sites,
          buildings: buildings,
        ),
      ),
      affectedEntityIds: {site.id, buildingId},
    );
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) sync* {
    final buildingId = reservation.entityId<BuildingId>('building');
    yield CreateEntityOperation(
      entityId: buildingId,
      ownerId: before.siteId,
    );
    yield UpdateEntityOperation(entityId: before.siteId);
  }
}

final class _RenameSiteCommand implements ProjectCommand {
  const _RenameSiteCommand(this.name);

  final String name;

  @override
  String get commandType => 'test.site.rename';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final site = current.stores.sites[current.siteId]!;
    final sites = Map<SiteId, ProjectSiteEntity>.from(current.stores.sites)
      ..[site.id] = ProjectSiteEntity(
        id: site.id,
        name: name,
        buildingIds: site.buildingIds,
      );
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(sites: sites),
      ),
      affectedEntityIds: {site.id},
    );
  }
}
