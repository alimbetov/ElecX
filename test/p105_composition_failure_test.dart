import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_semantics_commands.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/apartment_placement.dart';
import 'package:elecx/src/application/project/wizard/building/level_apartment_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/level_apartment_composition.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p105_composition_fixture.dart';

void main() {
  late P105CompositionFixture fixture;
  setUpAll(() => fixture = P105CompositionFixture.create());

  test('default P9 exploration still rejects a nonempty level', () {
    final result = const ApartmentCandidateSetService().generate(
        input: ApartmentRequestInput.productionDefaults,
        target: fixture.target,
        project: fixture.project);
    expect(result.accepted, isFalse);
    expect(result.failures.map((failure) => failure.code),
        contains('p9.provider.target-not-empty'));
  });

  test(
      'invalid common opening adoption fails before any apartment is committed',
      () {
    final session = ProjectMutationSession(fixture.project);
    final opening = ProjectOpeningEntity(
        id: OpeningId('legacy-common-window'),
        levelId: fixture.target.levelId,
        kind: OpeningKind.window,
        connectedSpaceIds: [fixture.accessSpaceId],
        widthMm: 900,
        heightMm: 1000);
    session.commit(ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: CreateOpeningCommand(opening: opening)));
    final before = session.current;
    final target = LevelWizardTarget(
        projectId: before.id,
        siteId: before.siteId,
        buildingId: fixture.target.buildingId,
        levelId: fixture.target.levelId,
        baseVersion: before.version);
    final command = LevelApartmentCompositionCommand(
        project: before,
        target: target,
        compositionKey: 'with-legacy-opening',
        slots: fixture.slots);
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10511)));
    expect(() => port.preview(command),
        throwsA(isA<ApartmentCompositionException>()));
    expect(session.current, same(before));
    expect(session.current.stores.spaces, hasLength(1));
    expect(
        session
            .current.engineeringMetadata.generationProvenanceRegistry.manifests,
        isEmpty);
  });
  test('P10.5 generator calls P9 on a level with existing common geometry', () {
    final command = const LevelApartmentCompositionGenerator().generate(
        project: fixture.project,
        target: fixture.target,
        compositionKey: 'generated',
        requests: [
          for (final slot in fixture.slots)
            LevelApartmentSlotRequest(
                key: slot.key,
                displayName: slot.displayName,
                request: ApartmentRequestInput.productionDefaults,
                transform: slot.transform,
                accessSpaceId: slot.accessSpaceId)
        ]);
    final session = ProjectMutationSession(fixture.project);
    final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10599)));
    port.commitPreview(port.preview(command));
    expect(
        session
            .current.engineeringMetadata.generationProvenanceRegistry.manifests,
        hasLength(2));
  });

  test(
      'missing common access and moving an entry away from its host fail closed',
      () {
    final original = fixture.slots.first;
    ApartmentPlacementSlot slot(
            {SpaceId? access, ApartmentPlacementTransform? transform}) =>
        ApartmentPlacementSlot.fromCandidateSet(
            key: 'bad',
            displayName: 'Bad',
            candidateSet: fixture.candidateSet,
            selection: fixture.candidateSet
                .selectionFor(fixture.candidateSet.recommendedCandidate),
            transform: transform ?? original.transform,
            accessSpaceId: access ?? fixture.accessSpaceId);
    expect(() => fixture.command(slots: [slot(access: SpaceId('foreign'))]),
        throwsA(isA<ApartmentCompositionException>()));
    expect(
        () => fixture.command(slots: [
              slot(
                  transform: ApartmentPlacementTransform(
                      xMm: original.transform.xMm + 100,
                      yMm: original.transform.yMm + 100,
                      clockwiseQuarterTurns:
                          original.transform.clockwiseQuarterTurns))
            ]),
        throwsA(isA<ApartmentCompositionException>()));
    expect(fixture.project.stores.spaces, hasLength(1));
  });

  test('selection from a different candidate set cannot enter composition', () {
    final selected = fixture.candidateSet.recommendedCandidate;
    expect(
        () => ApartmentPlacementSlot.fromCandidateSet(
            key: 'a',
            displayName: 'A',
            candidateSet: fixture.candidateSet,
            selection:
                selected.identity.toSelection(candidateSetFingerprint: 'stale'),
            transform: fixture.slots.first.transform,
            accessSpaceId: fixture.accessSpaceId),
        throwsA(isA<ApartmentCompositionException>()));
  });

  test(
      'unsupported fractional-grid translations and coordinates fail before generation',
      () {
    expect(
        () => ApartmentPlacementTransform(xMm: 1, yMm: 0), throwsArgumentError);
    expect(() => ApartmentPlacementTransform(xMm: 10000010, yMm: 0),
        throwsArgumentError);
    final a =
        ApartmentPlacementTransform(xMm: 0, yMm: 0, clockwiseQuarterTurns: 1);
    final b =
        ApartmentPlacementTransform(xMm: 0, yMm: 0, clockwiseQuarterTurns: 5);
    expect(a.toCanonicalJson(), b.toCanonicalJson());
  });
}
