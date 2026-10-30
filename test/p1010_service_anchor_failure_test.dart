import 'dart:math';

import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/project_service_anchor_commands.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/service_anchor_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_service_anchor.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1010_boundary_fixture.dart';

void main() {
  Matcher code(String value) => isA<ServiceAnchorException>()
      .having((e) => e.code, 'code', 'p10.service-anchor.$value');
  ServiceAnchorRequest area(ServiceAnchorTarget target,
          {String key = 'area'}) =>
      ServiceAnchorRequest(
          key: key,
          name: 'Generator area',
          kind: ProjectServiceAnchorKind.generatorArea,
          target: target);
  ServiceAnchorCompositionCommand command(ProjectAggregateRoot project,
          Iterable<ServiceAnchorRequest> requests) =>
      ServiceAnchorCompositionCommand.create(
          project: project, compositionKey: 'services', requests: requests);
  ProjectAggregateRoot copy(ProjectAggregateRoot project,
          {ProjectEngineeringMetadata? metadata,
          ProjectEntityStores? stores}) =>
      ProjectAggregateRoot(
          id: project.id,
          siteId: project.siteId,
          version: project.version,
          stores: stores ?? project.stores,
          engineeringMetadata: metadata ?? project.engineeringMetadata);
  test(
      'entries require durable wall targets and areas require explicit Site or Space targets',
      () {
    final fixture = P1010BoundaryFixture();
    expect(
        () => ServiceAnchorRequest(
            key: 'bad',
            name: 'Electrical',
            kind: ProjectServiceAnchorKind.electricalEntry,
            target: SiteServiceAnchorTarget(
                point: const BoundaryPointMm(xMm: 0, yMm: 0))),
        throwsArgumentError);
    expect(() => area(fixture.request().target), throwsArgumentError);
    expect(
        () => SiteServiceAnchorTarget(
            point: const BoundaryPointMm(xMm: 1, yMm: 0)),
        throwsArgumentError);
    expect(() => ServiceAnchorBoundaryBinding(host: fixture.host, offsetMm: -1),
        throwsArgumentError);
  });
  test(
      'missing owner chains, off-room positions, impossible heights and edge offsets fail before preview',
      () {
    final fixture = P1010BoundaryFixture();
    final project = fixture.project;
    SpaceServiceAnchorTarget room(
            {BuildingId? building,
            LevelId? level,
            SpaceId? space,
            int x = 2000,
            int height = 0}) =>
        SpaceServiceAnchorTarget(
            buildingId: building ?? fixture.buildingId,
            levelId: level ?? fixture.levelId,
            spaceId: space ?? fixture.spaceId,
            point: BoundaryPointMm(xMm: x, yMm: 1000),
            heightMm: height);
    for (final target in [
      room(building: BuildingId('foreign')),
      room(level: LevelId('foreign')),
      room(space: SpaceId('foreign'))
    ]) {
      expect(() => command(project, [area(target)]),
          throwsA(code('invalid-host-owner')));
    }
    expect(() => command(project, [area(room(x: 5000))]),
        throwsA(code('point-outside-space')));
    expect(() => command(project, [area(room(height: 5000))]),
        throwsA(code('height-outside-level')));
    expect(() => command(project, [fixture.request(offset: 4001)]),
        throwsA(code('offset-outside-edge')));
    final request = fixture.request();
    expect(
        () => command(project, [
              ServiceAnchorRequest(
                  key: request.key,
                  name: request.name,
                  kind: request.kind,
                  target: BoundaryServiceAnchorTarget(
                      buildingId: fixture.buildingId,
                      levelId: fixture.levelId,
                      spaceId: fixture.spaceId,
                      binding: ServiceAnchorBoundaryBinding(
                          host: BoundaryEdgeHostRef(
                              spaceId: fixture.spaceId,
                              edgeId: BoundaryEdgeId('missing')),
                          offsetMm: 100)))
            ]),
        throwsA(code('host-edge-missing')));
  });
  test(
      'outdoor anchors reject unresolved served buildings and points inside placed footprints',
      () {
    final fixture = P1010BoundaryFixture();
    expect(
        () => command(fixture.project, [
              area(SiteServiceAnchorTarget(
                  point: const BoundaryPointMm(xMm: 11000, yMm: 11000),
                  servedBuildingIds: [fixture.buildingId]))
            ]),
        throwsA(code('site-anchor-inside-building')));
    expect(
        () => command(fixture.project, [
              area(SiteServiceAnchorTarget(
                  point: const BoundaryPointMm(xMm: 0, yMm: 0),
                  servedBuildingIds: [BuildingId('foreign')]))
            ]),
        throwsA(code('unresolved-served-building')));
  });
  test('building intent rejects missing or incompatible location coverage', () {
    final fixture = P1010BoundaryFixture();
    ServiceAnchorCompositionPlan plan(
            Map<BuildingServiceAnchorKind, ServiceAnchorTarget> locations) =>
        const ServiceAnchorCompositionGenerator().forBuilding(
            project: fixture.project,
            buildingId: fixture.buildingId,
            compositionKey: 'services',
            parameters: ServiceAnchorParameters(
                kinds: [BuildingServiceAnchorKind.generatorArea]),
            locations: locations);
    expect(() => plan({}), throwsA(code('building-locations-incomplete')));
    expect(
        () => plan({
              BuildingServiceAnchorKind.generatorArea: SiteServiceAnchorTarget(
                  point: const BoundaryPointMm(xMm: 0, yMm: 0))
            }),
        throwsA(code('building-target-mismatch')));
    expect(
        () => command(fixture.project, [fixture.request(), fixture.request()]),
        throwsA(code('invalid-request')));
    final first = area(
        SiteServiceAnchorTarget(point: const BoundaryPointMm(xMm: 0, yMm: 0)));
    expect(
        () => command(
            fixture.project, [first, area(first.target, key: 'second')]),
        throwsA(code('duplicate-request')));
  });
  test(
      'wall profile and opening voids reject unsupported physical input positions',
      () {
    final fixture = P1010BoundaryFixture();
    final shortWall = copy(fixture.project,
        metadata: fixture.project.engineeringMetadata.copyWith(
            boundaryWallProfileRegistry: BoundaryWallProfileRegistry({
          fixture.host: WallProfile.rectangle(widthMm: 4000, heightMm: 800)
        })));
    expect(() => command(shortWall, [fixture.request()]),
        throwsA(code('wall-profile-rejects-anchor')));
    final openingId = fixture.ids.newOpeningId();
    final door = copy(fixture.project,
        stores: fixture.project.stores.copyWith(openings: {
          openingId: ProjectOpeningEntity(
              id: openingId,
              levelId: fixture.levelId,
              kind: OpeningKind.door,
              connectedSpaceIds: [fixture.spaceId],
              widthMm: 1000,
              heightMm: 2100)
        }),
        metadata: fixture.project.engineeringMetadata.copyWith(
            boundaryHostedObjectRegistry: fixture
                .project.engineeringMetadata.boundaryHostedObjectRegistry
                .putOpening(
                    openingId: openingId,
                    host: fixture.host,
                    startOffsetMm: 2000,
                    endOffsetMm: 3000)));
    expect(() => command(door, [fixture.request()]),
        throwsA(code('opening-conflict')));
    // The same XY above the opening remains physical wall material.
    expect(
        () => command(door, [fixture.request(height: 2300)]), returnsNormally);
  });
  test(
      'existing anchors cannot be duplicated by a fresh reservation and failed preview is atomic',
      () {
    final fixture = P1010BoundaryFixture();
    final session = fixture.compose();
    final before = session.current;
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(101051)));
    expect(() => port.preview(command(before, [fixture.request()])),
        throwsA(code('duplicate-physical-anchor')));
    expect(session.current, same(before));
    expect(session.undoDepth, 1);
    final commandWithTwo = command(fixture.project, [
      fixture.request(),
      ServiceAnchorRequest(
          key: 'telecom',
          name: 'Telecom',
          kind: ProjectServiceAnchorKind.telecomEntry,
          target: fixture.request().target)
    ]);
    final reservation = commandWithTwo
        .reserveIdentities(SecureRandomEntityIdFactory(random: Random(101052)));
    final slots = reservation.slots.toList();
    expect(
        () => reservation
            .selectEntitySlots({slots[0]: slots[0], slots[1]: slots[0]}),
        throwsArgumentError);
    final wrongScope = MutationIdentityReservation.combineEntityReservations(
        {'wrong': reservation});
    expect(
        () => commandWithTwo.validateReservation(
            current: fixture.project, reservation: wrongScope),
        throwsA(code('invalid-reservation')));
  });
  test(
      'discarded or stale previews never publish partial anchors or wall bindings',
      () {
    final fixture = P1010BoundaryFixture();
    final session = ProjectMutationSession(fixture.project);
    final port = SharedProjectWizardMutationPort(
        mutations: session, idFactory: fixture.ids);
    final cmd = command(fixture.project, [fixture.request()]);
    final cancelled = port.preview(cmd);
    port.discardPreview(cancelled);
    expect(() => port.commitPreview(cancelled),
        throwsA(isA<DiscardedWizardPreviewException>()));
    expect(session.current, same(fixture.project));
    final stale = port.preview(cmd);
    port.commitPreview(port.preview(cmd));
    final before = session.current;
    expect(() => port.commitPreview(stale),
        throwsA(isA<StaleProjectMutationException>()));
    expect(session.current, same(before));
    expect(session.undoDepth, 1);
  });
  test(
      'Space area dependencies expose the stable anchor ID and explicit removal enables deletion',
      () {
    final fixture = P1010BoundaryFixture();
    final session = ProjectMutationSession(fixture.project);
    final port = SharedProjectWizardMutationPort(
        mutations: session, idFactory: fixture.ids);
    port.commitPreview(port.preview(command(fixture.project, [
      area(SpaceServiceAnchorTarget(
          buildingId: fixture.buildingId,
          levelId: fixture.levelId,
          spaceId: fixture.spaceId,
          point: const BoundaryPointMm(xMm: 1000, yMm: 1000)))
    ])));
    final anchor = session
        .current.engineeringMetadata.siteLayout.serviceAnchors.keys.single;
    expect(
        () => session.commit(ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: RemoveSpaceCommand(spaceId: fixture.spaceId))),
        throwsA(isA<ProjectAuthoringException>()
            .having((e) => e.code, 'code',
                ProjectAuthoringIssueCode.spaceHasSemanticDependencies)
            .having((e) => e.blockingEntityIds, 'blockers', contains(anchor))));
    session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: RemoveServiceAnchorCommand(anchor)));
    session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: RemoveSpaceCommand(spaceId: fixture.spaceId)));
    expect(session.current.stores.spaces, isEmpty);
  });
  test('canonical root rejects orphan wall bindings and missing anchor hosts',
      () {
    final fixture = P1010BoundaryFixture();
    final orphan = fixture.project.engineeringMetadata.copyWith(
        boundaryHostedObjectRegistry: fixture
            .project.engineeringMetadata.boundaryHostedObjectRegistry
            .putServiceEntry(
                id: fixture.ids.newServiceEntryId(),
                host: fixture.host,
                offsetMm: 100));
    expect(() => copy(fixture.project, metadata: orphan),
        throwsA(code('orphan-wall-binding')));
    final project = fixture.compose().current;
    final entry =
        project.engineeringMetadata.siteLayout.serviceAnchors.values.single;
    expect(
        () => copy(project,
            metadata: project.engineeringMetadata.copyWith(
                boundaryHostedObjectRegistry: fixture
                    .project.engineeringMetadata.boundaryHostedObjectRegistry)),
        throwsA(code('wall-binding-missing')));
    expect(entry, isA<ProjectBoundaryServiceAnchor>());
  });
}
