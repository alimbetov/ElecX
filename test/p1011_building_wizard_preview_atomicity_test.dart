import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_preview.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P10.11 Wizard preview / atomic apply', () {
    test('P10-Q13 preview then cancel is side-effect free', () {
      final runtime = _p10Runtime(seed: 101101);
      final before = runtime.mutations.current;
      final beforeVersion = before.version;

      expect(runtime.wizard.generatePreview(), isTrue);
      final preview = runtime.wizard.preview!;
      final projection = const BuildingCompositionWizardPreviewProjector()
          .project(before: before, preview: preview);

      expect(identical(runtime.mutations.current, before), isTrue);
      expect(runtime.mutations.current.version, beforeVersion);
      expect(runtime.mutations.undoDepth, 0);
      expect(projection.addedBuildings, 1);
      expect(projection.addedLevels, greaterThanOrEqualTo(2));
      expect(projection.addedSpaces, greaterThan(0));
      expect(projection.addedVerticalCores, greaterThan(0));
      expect(projection.diff.isEmpty, isFalse);
      expect(runtime.port.activePreviewCount, 1);

      expect(runtime.wizard.cancel(), isTrue);
      expect(identical(runtime.mutations.current, before), isTrue);
      expect(runtime.mutations.current.version, beforeVersion);
      expect(runtime.mutations.undoDepth, 0);
      expect(runtime.mutations.current.stores.buildings, isEmpty);
      expect(runtime.port.activePreviewCount, 0);
    });

    test('P10-Q14 stale candidate fails closed without partial hierarchy', () {
      final runtime = _p10Runtime(seed: 101102);
      expect(runtime.wizard.generatePreview(), isTrue);

      final mutation = runtime.mutations.commit(
        ProjectMutationRequest(
          expectedVersion: runtime.mutations.current.version,
          command: const _RenameSiteCommand('Changed while preview is open'),
        ),
      );
      expect(mutation, isNotNull);
      final versionAfterConcurrentEdit = runtime.mutations.current.version;
      expect(runtime.mutations.undoDepth, 1);

      expect(runtime.wizard.confirm(), isFalse);
      expect(
        runtime.wizard.blockReason,
        WizardPreviewBlockReason.staleBaseVersion,
      );
      expect(runtime.mutations.current.version, versionAfterConcurrentEdit);
      expect(runtime.mutations.undoDepth, 1);
      expect(runtime.mutations.current.stores.buildings, isEmpty);
      expect(
        runtime.mutations.current.stores.sites[runtime.siteId]!.name,
        'Changed while preview is open',
      );
    });

    test('additional pre-Preview materialization failure is atomic', () {
      final project = _emptyProject();
      final mutations = ProjectMutationSession(project);
      final port = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(101103)),
      );
      final provider = const _FailingProvider();
      final wizard = WizardSession(
        target: SiteWizardTarget(
          projectId: project.id,
          siteId: project.siteId,
          baseVersion: project.version,
        ),
        registry: WizardProviderRegistry([provider]),
        mutations: port,
      );
      expect(wizard.begin(), isTrue);
      expect(wizard.selectFamily(_FailingProvider.familyId), isTrue);
      final before = mutations.current;

      expect(wizard.generatePreview(), isFalse);
      expect(wizard.status, WizardSessionStatus.failed);
      expect(wizard.failure, isA<StateError>());
      expect(identical(mutations.current, before), isTrue);
      expect(mutations.current.version, LocalProjectVersion(0));
      expect(mutations.undoDepth, 0);
      expect(mutations.current.stores.buildings, isEmpty);
      expect(port.activePreviewCount, 0);
    });

    test('P10-Q16 accepted generation is exactly one Undo/Redo boundary', () {
      final runtime = _p10Runtime(seed: 101104);
      expect(runtime.wizard.generatePreview(), isTrue);
      expect(runtime.wizard.confirm(), isTrue);
      expect(runtime.wizard.status, WizardSessionStatus.completed);
      expect(runtime.mutations.undoDepth, 1);
      expect(runtime.port.activePreviewCount, 0);

      final committedBuildingIds =
          runtime.mutations.current.stores.buildings.keys.toSet();
      final committedLevelIds =
          runtime.mutations.current.stores.levels.keys.toSet();
      final committedSpaceIds =
          runtime.mutations.current.stores.spaces.keys.toSet();
      final committedCoreIds =
          runtime.mutations.current.stores.verticalCores.keys.toSet();
      expect(committedBuildingIds, hasLength(1));

      final undo = runtime.mutations.undo(runtime.mutations.current.version);
      expect(undo, isNotNull);
      expect(runtime.mutations.current.stores.buildings, isEmpty);
      expect(runtime.mutations.current.stores.levels, isEmpty);
      expect(runtime.mutations.current.stores.spaces, isEmpty);
      expect(runtime.mutations.current.stores.verticalCores, isEmpty);

      final redo = runtime.mutations.redo(runtime.mutations.current.version);
      expect(redo, isNotNull);
      expect(
        runtime.mutations.current.stores.buildings.keys.toSet(),
        committedBuildingIds,
      );
      expect(runtime.mutations.current.stores.levels.keys.toSet(),
          committedLevelIds);
      expect(runtime.mutations.current.stores.spaces.keys.toSet(),
          committedSpaceIds);
      expect(
        runtime.mutations.current.stores.verticalCores.keys.toSet(),
        committedCoreIds,
      );
    });
  });
}

({
  WizardSession wizard,
  ProjectMutationSession mutations,
  SharedProjectWizardMutationPort port,
  SiteId siteId,
}) _p10Runtime({required int seed}) {
  final project = _emptyProject();
  final mutations = ProjectMutationSession(project);
  final port = SharedProjectWizardMutationPort(
    mutations: mutations,
    idFactory: SecureRandomEntityIdFactory(random: Random(seed)),
  );
  final wizard = WizardSession(
    target: SiteWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    ),
    registry: WizardProviderRegistry(
      const [BuildingCompositionWizardProvider()],
    ),
    mutations: port,
  );
  expect(wizard.begin(), isTrue);
  expect(
    wizard.selectFamily(BuildingCompositionWizardProvider.familyId),
    isTrue,
  );
  return (
    wizard: wizard,
    mutations: mutations,
    port: port,
    siteId: project.siteId,
  );
}

ProjectAggregateRoot _emptyProject() {
  final projectId = ProjectId('project-p1011');
  final siteId = SiteId('site-p1011');
  return ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'P10.11 Site',
          buildingIds: const [],
        ),
      },
    ),
  );
}

final class _RenameSiteCommand implements ProjectCommand {
  const _RenameSiteCommand(this.name);

  final String name;

  @override
  String get commandType => 'test.p1011.rename-site';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final site = current.stores.sites[current.siteId]!;
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          sites: {
            ...current.stores.sites,
            current.siteId: ProjectSiteEntity(
              id: site.id,
              name: name,
              buildingIds: site.buildingIds,
            ),
          },
        ),
      ),
      affectedEntityIds: {current.siteId},
    );
  }
}

final class _FailureParameters extends WizardParameters {
  const _FailureParameters();
}

final class _FailingProvider extends TypedWizardProvider<_FailureParameters> {
  const _FailingProvider();

  static final WizardFamilyId familyId = WizardFamilyId('p10-failure-fixture');

  @override
  WizardProviderDescriptor get descriptor => WizardProviderDescriptor(
        templateId: TemplateId('p10-failure-fixture'),
        templateVersion: 1,
        generatorVersion: '1',
        familyId: familyId,
        displayName: 'P10 failure fixture',
        supportedScopes: const {WizardTargetScope.site},
      );

  @override
  _FailureParameters typedDefaultsFor(WizardTargetContext target) =>
      const _FailureParameters();

  @override
  WizardParameterValidation validateTypedParameters(
    _FailureParameters parameters,
    WizardTargetContext target,
  ) =>
      const WizardParameterValidation.valid();

  @override
  ReservedProjectCommand generateTyped(
    _FailureParameters parameters,
    WizardGenerationContext context,
  ) =>
      const _FailingReservedCommand();
}

final class _FailingReservedCommand implements ReservedProjectCommand {
  const _FailingReservedCommand();

  @override
  String get commandType => 'test.p1011.fail-materialization';

  @override
  String get normalizedIntentKey => commandType;

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(factory: factory);

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {}

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    throw StateError('Injected P10.11 materialization failure.');
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) =>
      const <ProjectSemanticOperation>[];
}
