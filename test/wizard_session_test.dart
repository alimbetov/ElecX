import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_entity_stores_copy.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry exposes providers only for their declared target scope', () {
    final project = _project();
    final provider = _TestBuildingProvider();
    final registry = WizardProviderRegistry([provider]);

    final siteTarget = SiteWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    );
    final levelTarget = LevelWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
      buildingId: BuildingId('missing-building'),
      levelId: LevelId('missing-level'),
    );

    expect(registry.availableFor(siteTarget), hasLength(1));
    expect(registry.availableFor(levelTarget), isEmpty);
  });

  test('preview is side-effect free and confirm creates one canonical undo',
      () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final port = SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(7)),
    );
    final provider = _TestBuildingProvider();
    final session = WizardSession(
      target: SiteWizardTarget(
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
      ),
      registry: WizardProviderRegistry([provider]),
      mutations: port,
    );

    expect(session.begin(), isTrue);
    expect(session.status, WizardSessionStatus.selectingFamily);
    expect(session.selectFamily(provider.descriptor.familyId), isTrue);
    expect(session.status, WizardSessionStatus.editingParameters);
    expect(
      session.updateParameters(const _TestBuildingParameters('Building A')),
      isTrue,
    );

    final versionBefore = mutations.current.version;
    final undoBefore = mutations.undoDepth;
    expect(session.generatePreview(), isTrue);
    expect(session.status, WizardSessionStatus.previewReady);
    expect(session.canConfirm, isTrue);
    expect(mutations.current.version, versionBefore);
    expect(mutations.undoDepth, undoBefore);
    expect(mutations.current.stores.buildings, isEmpty);

    final frozenBuildingId =
        session.preview!.reservation.entityId<BuildingId>('building');
    expect(session.confirm(), isTrue);
    expect(session.status, WizardSessionStatus.completed);
    expect(mutations.current.version.value, versionBefore.value + 1);
    expect(mutations.undoDepth, undoBefore + 1);
    expect(mutations.current.stores.buildings.keys, contains(frozenBuildingId));

    mutations.undo(mutations.current.version);
    expect(mutations.current.stores.buildings, isEmpty);
  });

  test('parameter blocker prevents candidate generation', () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final provider = _TestBuildingProvider();
    final session = WizardSession(
      target: SiteWizardTarget(
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
      ),
      registry: WizardProviderRegistry([provider]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(11)),
      ),
    );

    session.begin();
    session.selectFamily(provider.descriptor.familyId);
    session.updateParameters(const _TestBuildingParameters('   '));

    expect(session.generatePreview(), isFalse);
    expect(session.status, WizardSessionStatus.editingParameters);
    expect(session.validation.hasBlockers, isTrue);
    expect(mutations.current.version, project.version);
    expect(mutations.undoDepth, 0);
  });

  test('stale frozen preview fails closed and can be explicitly rebased', () {
    final project = _project();
    final mutations = ProjectMutationSession(project);
    final ids = SecureRandomEntityIdFactory(random: Random(17));
    final port = SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: ids,
    );
    final provider = _TestBuildingProvider();
    final session = WizardSession(
      target: SiteWizardTarget(
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
      ),
      registry: WizardProviderRegistry([provider]),
      mutations: port,
    );

    session.begin();
    session.selectFamily(provider.descriptor.familyId);
    session.updateParameters(const _TestBuildingParameters('Wizard Building'));
    expect(session.generatePreview(), isTrue);
    final frozenId =
        session.preview!.reservation.entityId<BuildingId>('building');

    final external = ReservedProjectMutationCoordinator(
      mutations,
      entityIdFactory: ids,
    );
    final externalPreview = external.preview(
      const _AddBuildingCommand('External Building'),
    );
    expect(external.commitPreview(externalPreview), isNotNull);

    expect(session.confirm(), isFalse);
    expect(session.status, WizardSessionStatus.previewBlocked);
    expect(session.blockReason, WizardPreviewBlockReason.staleBaseVersion);
    expect(mutations.current.stores.buildings.containsKey(frozenId), isFalse);

    expect(session.rebaseToCurrent(), isTrue);
    expect(session.status, WizardSessionStatus.editingParameters);
    expect(session.generatePreview(), isTrue);
    final rebasedId =
        session.preview!.reservation.entityId<BuildingId>('building');
    expect(rebasedId, isNot(frozenId));
    expect(session.confirm(), isTrue);
    expect(mutations.current.stores.buildings.containsKey(rebasedId), isTrue);
  });
}

final class _TestBuildingParameters extends WizardParameters {
  const _TestBuildingParameters(this.name);

  final String name;
}

final class _TestBuildingProvider
    extends TypedWizardProvider<_TestBuildingParameters> {
  _TestBuildingProvider();

  @override
  final WizardProviderDescriptor descriptor = WizardProviderDescriptor(
    templateId: TemplateId('test-building-template'),
    templateVersion: 1,
    generatorVersion: '1',
    familyId: WizardFamilyId('test-building'),
    displayName: 'Test building',
    supportedScopes: const {WizardTargetScope.site},
  );

  @override
  _TestBuildingParameters typedDefaultsFor(WizardTargetContext target) =>
      const _TestBuildingParameters('Building');

  @override
  WizardParameterValidation validateTypedParameters(
    _TestBuildingParameters parameters,
    WizardTargetContext target,
  ) {
    if (parameters.name.trim().isEmpty) {
      return WizardParameterValidation([
        const WizardValidationIssue(
          code: 'building.name.empty',
          message: 'Building name is required.',
          severity: WizardIssueSeverity.blocker,
        ),
      ]);
    }
    return const WizardParameterValidation.valid();
  }

  @override
  ReservedProjectCommand generateTyped(
    _TestBuildingParameters parameters,
    WizardGenerationContext context,
  ) =>
      _AddBuildingCommand(parameters.name.trim());
}

final class _AddBuildingCommand implements ReservedProjectCommand {
  const _AddBuildingCommand(this.name);

  final String name;

  @override
  String get commandType => 'test.add-building';

  @override
  String get normalizedIntentKey => 'test.add-building|${name.trim()}';

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
    final id = reservation.entityId<BuildingId>('building');
    if (current.stores.buildings.containsKey(id)) {
      throw StateError('Reserved building already exists.');
    }
  }

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    final buildingId = reservation.entityId<BuildingId>('building');
    final site = current.stores.sites[current.siteId]!;
    final building = ProjectBuildingEntity(
      id: buildingId,
      siteId: current.siteId,
      name: name.trim(),
      levelIds: const <LevelId>{},
    );
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: current.engineeringMetadata,
        stores: current.stores.copyWith(
          sites: {
            ...current.stores.sites,
            current.siteId: ProjectSiteEntity(
              id: site.id,
              name: site.name,
              buildingIds: {...site.buildingIds, buildingId},
            ),
          },
          buildings: {...current.stores.buildings, buildingId: building},
        ),
      ),
      affectedEntityIds: [current.siteId, buildingId],
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

ProjectAggregateRoot _project() {
  final projectId = ProjectId('project-1');
  final siteId = SiteId('site-1');
  return ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: const <BuildingId>{},
        ),
      },
    ),
  );
}
