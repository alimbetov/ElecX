import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P8 Wizard behavioral qualification matrix', () {
    test('all Basic Building parameter boundaries fail or pass explicitly', () {
      final project = _project('parameter-boundaries');
      final provider = BasicBuildingWizardProvider();
      final target = _target(project);

      const validCases = <BasicBuildingWizardParameters>[
        BasicBuildingWizardParameters(
          buildingName: 'Minimum',
          aboveGroundLevelCount: 1,
          basementLevelCount: 0,
          floorToFloorHeightMm: 1,
          createGroundLevel: false,
        ),
        BasicBuildingWizardParameters(
          buildingName: 'Maximum counts',
          aboveGroundLevelCount: 200,
          basementLevelCount: 30,
          floorToFloorHeightMm: 6000,
          createGroundLevel: true,
        ),
      ];
      for (final parameters in validCases) {
        expect(
          provider.validateTypedParameters(parameters, target).hasBlockers,
          isFalse,
          reason: 'Expected valid boundary: ${parameters.buildingName}',
        );
      }

      const invalidCases = <BasicBuildingWizardParameters>[
        BasicBuildingWizardParameters(
          buildingName: ' ',
          aboveGroundLevelCount: 1,
          basementLevelCount: 0,
          floorToFloorHeightMm: 3000,
        ),
        BasicBuildingWizardParameters(
          buildingName: 'Above low',
          aboveGroundLevelCount: 0,
          basementLevelCount: 0,
          floorToFloorHeightMm: 3000,
        ),
        BasicBuildingWizardParameters(
          buildingName: 'Above high',
          aboveGroundLevelCount: 201,
          basementLevelCount: 0,
          floorToFloorHeightMm: 3000,
        ),
        BasicBuildingWizardParameters(
          buildingName: 'Basement low',
          aboveGroundLevelCount: 1,
          basementLevelCount: -1,
          floorToFloorHeightMm: 3000,
        ),
        BasicBuildingWizardParameters(
          buildingName: 'Basement high',
          aboveGroundLevelCount: 1,
          basementLevelCount: 31,
          floorToFloorHeightMm: 3000,
        ),
        BasicBuildingWizardParameters(
          buildingName: 'Height zero',
          aboveGroundLevelCount: 1,
          basementLevelCount: 0,
          floorToFloorHeightMm: 0,
        ),
        BasicBuildingWizardParameters(
          buildingName: 'Height negative',
          aboveGroundLevelCount: 1,
          basementLevelCount: 0,
          floorToFloorHeightMm: -1,
        ),
      ];
      for (final parameters in invalidCases) {
        expect(
          provider.validateTypedParameters(parameters, target).hasBlockers,
          isTrue,
          reason: 'Expected blocker for: ${parameters.buildingName}',
        );
      }
    });

    test('editing parameters clears obsolete validation blockers immediately',
        () {
      final project = _project('validation-reset');
      final mutations = ProjectMutationSession(project);
      final session = _session(project, mutations, 701);

      expect(session.begin(), isTrue);
      expect(
          session.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
      expect(
        session.updateParameters(
          _parameters('Invalid', aboveGroundLevelCount: 0),
        ),
        isTrue,
      );
      expect(session.generatePreview(), isFalse);
      expect(session.validation.hasBlockers, isTrue);

      expect(session.updateParameters(_parameters('Recovered')), isTrue);
      expect(session.validation.hasBlockers, isFalse);
      expect(session.status, WizardSessionStatus.editingParameters);
      expect(session.preview, isNull);
    });

    test('abandoned previews cannot be committed through a retained reference',
        () {
      for (final action in <String>['parameters', 'back', 'cancel']) {
        final project = _project('discard-$action');
        final mutations = ProjectMutationSession(project);
        final session = _session(project, mutations, 704 + action.length);

        expect(session.begin(), isTrue);
        expect(
          session.selectFamily(BasicBuildingWizardProvider.familyId),
          isTrue,
        );
        expect(
            session.updateParameters(_parameters('Discard $action')), isTrue);
        expect(session.generatePreview(), isTrue);
        final retained = session.preview!;

        switch (action) {
          case 'parameters':
            expect(
              session.updateParameters(_parameters('Replacement $action')),
              isTrue,
            );
          case 'back':
            expect(session.back(), isTrue);
          case 'cancel':
            expect(session.cancel(), isTrue);
        }

        expect(
          () => session.mutations.commitPreview(retained),
          throwsA(isA<DiscardedWizardPreviewException>()),
          reason: 'action=$action',
        );
        expect(mutations.current.version.value, 0);
        expect(mutations.undoDepth, 0);
      }
    });

    test('cancel is side-effect free from every reachable pre-commit stage',
        () {
      for (final stage in <String>['idle', 'family', 'editing', 'preview']) {
        final project = _project('cancel-$stage');
        final mutations = ProjectMutationSession(project);
        final session = _session(project, mutations, 710 + stage.length);

        if (stage != 'idle') {
          expect(session.begin(), isTrue);
        }
        if (stage == 'editing' || stage == 'preview') {
          expect(
            session.selectFamily(BasicBuildingWizardProvider.familyId),
            isTrue,
          );
          expect(
              session.updateParameters(_parameters('Cancel $stage')), isTrue);
        }
        if (stage == 'preview') {
          expect(session.generatePreview(), isTrue);
        }

        final version = mutations.current.version;
        final undoDepth = mutations.undoDepth;
        expect(session.cancel(), isTrue, reason: 'stage=$stage');
        expect(session.status, WizardSessionStatus.cancelled);
        expect(session.preview, isNull);
        expect(mutations.current.version, version);
        expect(mutations.undoDepth, undoDepth);
        expect(session.confirm(), isFalse);
        expect(session.generatePreview(), isFalse);
        expect(session.cancel(), isFalse);
      }
    });

    test('back navigation never mutates canonical state', () {
      final project = _project('back-navigation');
      final mutations = ProjectMutationSession(project);
      final session = _session(project, mutations, 719);
      final originalVersion = mutations.current.version;

      expect(session.begin(), isTrue);
      expect(session.back(), isFalse);
      expect(
          session.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
      expect(session.updateParameters(_parameters('Back')), isTrue);
      expect(session.generatePreview(), isTrue);
      expect(session.back(), isTrue);
      expect(session.status, WizardSessionStatus.editingParameters);
      expect(session.preview, isNull);
      expect(session.back(), isTrue);
      expect(session.status, WizardSessionStatus.selectingFamily);
      expect(session.provider, isNull);
      expect(session.parameters, isNull);
      expect(session.back(), isFalse);
      expect(mutations.current.version, originalVersion);
      expect(mutations.undoDepth, 0);
    });

    test('stale before generation blocks without allocating a live mutation',
        () {
      final project = _project('stale-before-generate');
      final mutations = ProjectMutationSession(project);
      final session = _session(project, mutations, 727);
      final external = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(729)),
      );

      expect(session.begin(), isTrue);
      expect(
          session.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
      expect(session.updateParameters(_parameters('Stale draft')), isTrue);

      final externalPreview = external.preview(
        _command(project, 'External winner'),
      );
      expect(external.commitPreview(externalPreview), isNotNull);
      final winnerVersion = mutations.current.version;
      final winnerUndoDepth = mutations.undoDepth;

      expect(session.generatePreview(), isFalse);
      expect(session.status, WizardSessionStatus.previewBlocked);
      expect(session.blockReason, WizardPreviewBlockReason.staleBaseVersion);
      expect(session.preview, isNull);
      expect(mutations.current.version, winnerVersion);
      expect(mutations.undoDepth, winnerUndoDepth);
    });

    test('two same-version Wizards have one winner and stale loser can rebase',
        () {
      final project = _project('same-version-race');
      final mutations = ProjectMutationSession(project);
      final first = _session(project, mutations, 733);
      final second = _session(project, mutations, 739);

      for (final entry in <(WizardSession, String)>[
        (first, 'Race A'),
        (second, 'Race B'),
      ]) {
        expect(entry.$1.begin(), isTrue);
        expect(
          entry.$1.selectFamily(BasicBuildingWizardProvider.familyId),
          isTrue,
        );
        expect(entry.$1.updateParameters(_parameters(entry.$2)), isTrue);
        expect(entry.$1.generatePreview(), isTrue);
      }

      expect(first.confirm(), isTrue);
      expect(mutations.current.version.value, 1);
      expect(mutations.undoDepth, 1);

      expect(second.confirm(), isFalse);
      expect(second.status, WizardSessionStatus.previewBlocked);
      expect(second.blockReason, WizardPreviewBlockReason.staleBaseVersion);
      expect(mutations.current.version.value, 1);
      expect(mutations.undoDepth, 1);

      expect(second.rebaseToCurrent(), isTrue);
      expect(second.status, WizardSessionStatus.editingParameters);
      expect(second.preview, isNull);
      expect(second.generatePreview(), isTrue);
      expect(second.confirm(), isTrue);
      expect(mutations.current.version.value, 2);
      expect(mutations.undoDepth, 2);
    });

    test('preview failure is recoverable without canonical side effects', () {
      final project = _project('preview-failure');
      final mutations = ProjectMutationSession(project);
      final delegate = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(743)),
      );
      final session = WizardSession(
        target: _target(project),
        registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
        mutations: _ThrowOncePreviewPort(delegate),
      );

      expect(session.begin(), isTrue);
      expect(
          session.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
      expect(session.updateParameters(_parameters('Preview retry')), isTrue);
      expect(session.generatePreview(), isFalse);
      expect(session.status, WizardSessionStatus.failed);
      expect(session.failure, isA<StateError>());
      expect(mutations.current.version.value, 0);
      expect(mutations.undoDepth, 0);

      expect(session.back(), isTrue);
      expect(session.generatePreview(), isTrue);
      expect(session.confirm(), isTrue);
      expect(mutations.current.version.value, 1);
      expect(mutations.undoDepth, 1);
    });

    test('commit failure is recoverable and creates no phantom Undo entry', () {
      final project = _project('commit-failure');
      final mutations = ProjectMutationSession(project);
      final delegate = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(751)),
      );
      final session = WizardSession(
        target: _target(project),
        registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
        mutations: _ThrowOnceCommitPort(delegate),
      );

      expect(session.begin(), isTrue);
      expect(
          session.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
      expect(session.updateParameters(_parameters('Commit retry')), isTrue);
      expect(session.generatePreview(), isTrue);
      expect(session.confirm(), isFalse);
      expect(session.status, WizardSessionStatus.failed);
      expect(session.failure, isA<StateError>());
      expect(mutations.current.version.value, 0);
      expect(mutations.undoDepth, 0);

      expect(session.back(), isTrue);
      expect(session.generatePreview(), isTrue);
      expect(session.confirm(), isTrue);
      expect(mutations.current.version.value, 1);
      expect(mutations.undoDepth, 1);
    });

    test('completed session is terminal and cannot double-apply', () {
      final project = _project('terminal-completed');
      final mutations = ProjectMutationSession(project);
      final session = _session(project, mutations, 757);

      expect(session.begin(), isTrue);
      expect(
          session.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
      expect(session.updateParameters(_parameters('Terminal')), isTrue);
      expect(session.generatePreview(), isTrue);
      expect(session.confirm(), isTrue);
      final committedVersion = mutations.current.version;
      final committedUndoDepth = mutations.undoDepth;

      expect(session.status, WizardSessionStatus.completed);
      expect(session.confirm(), isFalse);
      expect(session.cancel(), isFalse);
      expect(session.back(), isFalse);
      expect(session.generatePreview(), isFalse);
      expect(session.rebaseToCurrent(), isFalse);
      expect(session.updateParameters(_parameters('Too late')), isFalse);
      expect(
        session.selectFamily(BasicBuildingWizardProvider.familyId),
        isFalse,
      );
      expect(session.begin(), isFalse);
      expect(mutations.current.version, committedVersion);
      expect(mutations.undoDepth, committedUndoDepth);
    });

    test('4096 deterministic action transitions preserve mutation invariants',
        () {
      var attemptedTransitions = 0;
      var successfulCommits = 0;

      for (var seed = 0; seed < 64; seed++) {
        final project = _project('model-$seed');
        final mutations = ProjectMutationSession(project);
        final session = _session(project, mutations, 1000 + seed);
        final random = Random(seed);

        expect(session.begin(), isTrue);
        expect(
          session.selectFamily(BasicBuildingWizardProvider.familyId),
          isTrue,
        );
        expect(session.updateParameters(_parameters('Model $seed')), isTrue);

        for (var step = 0; step < 64; step++) {
          attemptedTransitions++;
          final beforeVersion = mutations.current.version;
          final beforeUndo = mutations.undoDepth;
          final action = random.nextInt(7);
          late final bool result;

          switch (action) {
            case 0:
              result = session.updateParameters(
                _parameters('Model $seed/$step'),
              );
            case 1:
              result = session.updateParameters(
                _parameters(
                  'Invalid $seed/$step',
                  aboveGroundLevelCount: 0,
                ),
              );
            case 2:
              result = session.generatePreview();
            case 3:
              result = session.back();
            case 4:
              result = session.selectFamily(
                BasicBuildingWizardProvider.familyId,
              );
            case 5:
              result = session.confirm();
            case 6:
              result = session.rebaseToCurrent();
          }

          if (action == 5 && result) {
            successfulCommits++;
            expect(
              mutations.current.version.value,
              beforeVersion.value + 1,
              reason: 'seed=$seed step=$step',
            );
            expect(
              mutations.undoDepth,
              beforeUndo + 1,
              reason: 'seed=$seed step=$step',
            );
          } else {
            expect(
              mutations.current.version,
              beforeVersion,
              reason:
                  'Non-confirm action mutated project: seed=$seed step=$step',
            );
            expect(
              mutations.undoDepth,
              beforeUndo,
              reason:
                  'Non-confirm action mutated history: seed=$seed step=$step',
            );
          }

          if (session.status == WizardSessionStatus.previewReady) {
            expect(session.preview, isNotNull);
            expect(session.canConfirm, isTrue);
          }
          if (session.status == WizardSessionStatus.completed) {
            expect(session.commitResult, isNotNull);
            expect(session.canConfirm, isFalse);
          }
          if (session.status == WizardSessionStatus.selectingFamily) {
            expect(session.provider, isNull);
            expect(session.parameters, isNull);
          }
        }
      }

      expect(attemptedTransitions, 4096);
      expect(successfulCommits, greaterThan(0));
    });
  });
}

final class _ThrowOncePreviewPort implements ProjectWizardMutationPort {
  _ThrowOncePreviewPort(this.delegate);

  final ProjectWizardMutationPort delegate;
  bool _shouldThrow = true;

  @override
  ProjectAggregateRoot get project => delegate.project;

  @override
  LocalProjectVersion get version => delegate.version;

  @override
  ReservedProjectMutationPreview preview(ReservedProjectCommand command) {
    if (_shouldThrow) {
      _shouldThrow = false;
      throw StateError('Injected preview failure.');
    }
    return delegate.preview(command);
  }

  @override
  void discardPreview(ReservedProjectMutationPreview preview) =>
      delegate.discardPreview(preview);

  @override
  ReservedProjectMutationCommitResult? commitPreview(
    ReservedProjectMutationPreview preview,
  ) =>
      delegate.commitPreview(preview);
}

final class _ThrowOnceCommitPort implements ProjectWizardMutationPort {
  _ThrowOnceCommitPort(this.delegate);

  final ProjectWizardMutationPort delegate;
  bool _shouldThrow = true;

  @override
  ProjectAggregateRoot get project => delegate.project;

  @override
  LocalProjectVersion get version => delegate.version;

  @override
  ReservedProjectMutationPreview preview(ReservedProjectCommand command) =>
      delegate.preview(command);

  @override
  void discardPreview(ReservedProjectMutationPreview preview) =>
      delegate.discardPreview(preview);

  @override
  ReservedProjectMutationCommitResult? commitPreview(
    ReservedProjectMutationPreview preview,
  ) {
    if (_shouldThrow) {
      _shouldThrow = false;
      throw StateError('Injected commit failure.');
    }
    return delegate.commitPreview(preview);
  }
}

WizardSession _session(
  ProjectAggregateRoot project,
  ProjectMutationSession mutations,
  int randomSeed,
) =>
    WizardSession(
      target: _target(project),
      registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(randomSeed)),
      ),
    );

SiteWizardTarget _target(ProjectAggregateRoot project) => SiteWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    );

BasicBuildingWizardParameters _parameters(
  String name, {
  int aboveGroundLevelCount = 2,
  int basementLevelCount = 1,
  int floorToFloorHeightMm = 3000,
  bool createGroundLevel = true,
}) =>
    BasicBuildingWizardParameters(
      buildingName: name,
      aboveGroundLevelCount: aboveGroundLevelCount,
      basementLevelCount: basementLevelCount,
      floorToFloorHeightMm: floorToFloorHeightMm,
      createGroundLevel: createGroundLevel,
    );

ReservedProjectCommand _command(ProjectAggregateRoot project, String name) {
  final provider = BasicBuildingWizardProvider();
  final target = _target(project);
  return provider.generateTyped(
    _parameters(name),
    WizardGenerationContext(target: target, project: project),
  );
}

ProjectAggregateRoot _project(String suffix) {
  final projectId = ProjectId('p8-matrix-project-$suffix');
  final siteId = SiteId('p8-matrix-site-$suffix');
  return ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site $suffix',
          buildingIds: const <BuildingId>{},
        ),
      },
    ),
  );
}
