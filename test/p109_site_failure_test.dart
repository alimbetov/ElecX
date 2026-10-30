import 'dart:math';

import 'package:elecx/src/application/project/project_authoring_error.dart';
import 'package:elecx/src/application/project/project_destructive_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/project_site_layout_commands.dart';
import 'package:elecx/src/application/project/wizard/building/site_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_site_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p109_site_fixture.dart';

void main() {
  final fixture = P109SiteFixture();
  Matcher code(String expected) =>
      isA<SiteLayoutException>().having((e) => e.code, 'code', expected);
  test(
      'overlapping rotated footprints, duplicate slots and unresolved anchor targets fail before Preview',
      () {
    expect(
        () => fixture.command(slots: [
              fixture.cottageSlot(),
              fixture.cottageSlot(key: 'cottage.other')
            ], anchors: []),
        throwsA(code('p10.site.overlapping-footprints')));
    expect(
        () => fixture.command(
            slots: [fixture.cottageSlot(), fixture.cottageSlot()], anchors: []),
        throwsA(code('p10.site.invalid-slots')));
    expect(
        () => fixture.command(anchors: [
              SharedSiteAnchorRequest(
                  key: 'bad',
                  name: 'Missing target',
                  kind: ProjectSiteAnchorKind.sharedServiceArea,
                  point: const BoundaryPointMm(xMm: 0, yMm: 0),
                  buildingKeys: const ['tower.a', 'missing'])
            ]),
        throwsA(code('p10.site.anchor-target-missing')));
    expect(
        () => fixture.command(anchors: [
              SharedSiteAnchorRequest(
                  key: 'inside',
                  name: 'Inside building',
                  kind: ProjectSiteAnchorKind.sharedServiceArea,
                  point: const BoundaryPointMm(xMm: 110000, yMm: 110000),
                  buildingKeys: const ['tower.a', 'cottage.b'])
            ]),
        throwsA(code('p10.site.anchor-inside-building')));
  });
  test('unsupported angles and noncanonical coordinate ranges fail closed', () {
    for (final angle in [45.0, 0.001]) {
      expect(
          () => fixture.command(slots: [
                fixture.cottageSlot(angle: angle),
                fixture.cottageSlot(key: 'other', x: -100000)
              ], anchors: []),
          throwsArgumentError);
    }
    expect(
        () => ProjectBuildingSitePlacement(
            xMm: 1000000000,
            yMm: 0,
            orientation: ProjectEngineeringNorth.fromDegrees(0),
            widthMm: 10000,
            depthMm: 10000),
        throwsArgumentError);
  });
  test(
      'shared references block Building deletion and explicit anchor removal is Undo-safe',
      () {
    final session = fixture.compose();
    final before = session.current.engineeringMetadata.siteLayout;
    final id = session.current.stores.buildings.keys.first;
    expect(
        () => session.commit(ProjectMutationRequest(
            expectedVersion: session.current.version,
            command: RemoveBuildingCommand(buildingId: id))),
        throwsA(isA<ProjectAuthoringException>().having((e) => e.code, 'code',
            ProjectAuthoringIssueCode.buildingHasSiteDependencies)));
    final anchor = before.sharedAnchors.keys.first;
    session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: RemoveSharedSiteAnchorCommand(anchor)));
    expect(
        session.current.engineeringMetadata.siteLayout.sharedAnchors
            .containsKey(anchor),
        isFalse);
    session.undo(session.current.version);
    expect(
        session.current.engineeringMetadata.siteLayout.sameAs(before), isTrue);
  });
  test(
      'moving a building into another footprint or over a shared anchor is rejected atomically',
      () {
    final session = fixture.compose();
    final before = session.current;
    final placements =
        before.engineeringMetadata.siteLayout.placements.entries.toList();
    final a = placements.first;
    final b = placements.last;
    expect(
        () => session.commit(ProjectMutationRequest(
            expectedVersion: before.version,
            command: UpdateBuildingSitePlacementCommand(
                buildingId: b.key,
                placement: ProjectBuildingSitePlacement(
                    xMm: a.value.xMm,
                    yMm: a.value.yMm,
                    orientation: a.value.orientation,
                    widthMm: b.value.widthMm,
                    depthMm: b.value.depthMm)))),
        throwsA(isA<SiteLayoutException>()));
    expect(session.current, same(before));
    final anchor =
        before.engineeringMetadata.siteLayout.sharedAnchors.values.first.point;
    final small = placements.first;
    expect(
        () => session.commit(ProjectMutationRequest(
            expectedVersion: before.version,
            command: UpdateBuildingSitePlacementCommand(
                buildingId: small.key,
                placement: ProjectBuildingSitePlacement(
                    xMm: anchor.xMm - 1000,
                    yMm: anchor.yMm - 1000,
                    orientation: ProjectEngineeringNorth.fromDegrees(0),
                    widthMm: small.value.widthMm,
                    depthMm: small.value.depthMm)))),
        throwsA(code('p10.site-layout.anchor-inside-building')));
    expect(session.current, same(before));
    expect(session.undoDepth, 1);
  });
  test(
      'unplaced legacy buildings require explicit placement instead of an inferred location',
      () {
    final buildingId = BuildingId('unplaced');
    final basis = ProjectAggregateRoot(
        id: fixture.projectId,
        siteId: fixture.siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(sites: {
          fixture.siteId: ProjectSiteEntity(
              id: fixture.siteId, name: 'Legacy', buildingIds: [buildingId]),
        }, buildings: {
          buildingId: ProjectBuildingEntity(
              id: buildingId,
              siteId: fixture.siteId,
              name: 'Unplaced',
              levelIds: const [])
        }));
    expect(
        () => fixture.command(
            project: basis, slots: [fixture.cottageSlot()], anchors: []),
        throwsA(code('p10.site.existing-placement-missing')));
  });
  test(
      'discarded or stale Site previews cannot publish partial hierarchy or metadata',
      () {
    final basis = fixture.project;
    final session = ProjectMutationSession(basis);
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10951)));
    final command = fixture.command(project: basis);
    final cancelled = port.preview(command);
    port.discardPreview(cancelled);
    expect(() => port.commitPreview(cancelled),
        throwsA(isA<DiscardedWizardPreviewException>()));
    expect(session.current, same(basis));
    final stale = port.preview(command);
    port.commitPreview(port.preview(command));
    final committed = session.current;
    expect(() => port.commitPreview(stale),
        throwsA(isA<StaleProjectMutationException>()));
    expect(session.current, same(committed));
    expect(session.undoDepth, 1);
  });
  test(
      'failure after materializing all child candidates leaves live state and history unchanged',
      () {
    final basis = fixture.project;
    final session = ProjectMutationSession(basis);
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10952)));
    expect(() => port.preview(_FailAfterBuild(fixture.command(project: basis))),
        throwsStateError);
    expect(session.current, same(basis));
    expect(session.undoDepth, 0);
    expect(session.current.engineeringMetadata.siteLayout.isEmpty, isTrue);
    expect(session.current.stores.buildings, isEmpty);
  });
  test(
      'deleting an empty Building removes its Site placement and Undo restores the exact binding',
      () {
    final generated = fixture.compose().current;
    final basis = ProjectAggregateRoot(
        id: generated.id,
        siteId: generated.siteId,
        version: generated.version,
        stores: ProjectEntityStores(sites: generated.stores.sites, buildings: {
          for (final b in generated.stores.buildings.values)
            b.id: ProjectBuildingEntity(
                id: b.id, siteId: b.siteId, name: b.name, levelIds: const [])
        }),
        engineeringMetadata: ProjectEngineeringMetadata(
            siteLayout: ProjectSiteLayout(
                placements:
                    generated.engineeringMetadata.siteLayout.placements)));
    final session = ProjectMutationSession(basis);
    final id = basis.stores.buildings.keys.first;
    session.commit(ProjectMutationRequest(
        expectedVersion: basis.version,
        command: RemoveBuildingCommand(buildingId: id)));
    expect(
        session.current.engineeringMetadata.siteLayout.placements
            .containsKey(id),
        isFalse);
    expect(session.current.stores.buildings.containsKey(id), isFalse);
    session.undo(session.current.version);
    expect(
        session.current.engineeringMetadata.siteLayout
            .sameAs(basis.engineeringMetadata.siteLayout),
        isTrue);
  });
  test('boundary contact is legal while positive-area overlap is rejected', () {
    final session = ProjectMutationSession(fixture.project);
    final command = fixture.command(slots: [
      fixture.cottageSlot(key: 'left', x: 0, y: 0, angle: 0),
      fixture.cottageSlot(key: 'right', x: 12000, y: 0, angle: 0)
    ], anchors: []);
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10954)));
    port.commitPreview(port.preview(command));
    expect(session.current.stores.buildings, hasLength(2));
  });
  test('foreign Site ownership is rejected without rebinding building requests',
      () {
    final siteId = SiteId('foreign-site');
    final basis = ProjectAggregateRoot(
        id: fixture.projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(sites: {
          siteId: ProjectSiteEntity(
              id: siteId, name: 'Foreign', buildingIds: const [])
        }));
    expect(() => fixture.command(project: basis),
        throwsA(code('p10.site.foreign-site')));
  });
  test('combined reservations reject aliases and extra scopes', () {
    final basis = fixture.project;
    final command = fixture.command(project: basis);
    final reservation = command
        .reserveIdentities(SecureRandomEntityIdFactory(random: Random(10953)));
    expect(
        () => MutationIdentityReservation.combineEntityReservations(
            {'a': reservation, 'b': reservation}),
        throwsArgumentError);
    final invalid = MutationIdentityReservation.combineEntityReservations(
        {'wrong': reservation});
    expect(
        () => command.validateReservation(current: basis, reservation: invalid),
        throwsException);
  });
}

final class _FailAfterBuild implements ReservedProjectCommand {
  const _FailAfterBuild(this.inner);
  final SiteCompositionCommand inner;
  @override
  String get commandType => inner.commandType;
  @override
  String get normalizedIntentKey => inner.normalizedIntentKey;
  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      inner.reserveIdentities(factory);
  @override
  void validateReservation(
          {required ProjectAggregateRoot current,
          required MutationIdentityReservation reservation}) =>
      inner.validateReservation(current: current, reservation: reservation);
  @override
  ProjectCommandCandidate buildCandidate(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    final state = inner
        .buildCandidate(current: current, reservation: reservation)
        .resolveState(current);
    expect(state.stores.buildings, hasLength(3));
    throw StateError('Injected failure after complete child materialization');
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations(
          {required ProjectAggregateRoot before,
          required ProjectAggregateRoot candidate,
          required MutationIdentityReservation reservation}) =>
      inner.semanticOperations(
          before: before, candidate: candidate, reservation: reservation);
}
