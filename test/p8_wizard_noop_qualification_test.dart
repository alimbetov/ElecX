import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic no-op candidate is blocked and cannot create history', () {
    final projectId = ProjectId('p8-noop-project');
    final siteId = SiteId('p8-noop-site');
    final project = ProjectAggregateRoot(
      id: projectId,
      siteId: siteId,
      version: LocalProjectVersion(0),
      stores: ProjectEntityStores(
        sites: {
          siteId: ProjectSiteEntity(
            id: siteId,
            name: 'No-op Site',
            buildingIds: const <BuildingId>{},
          ),
        },
      ),
    );
    final mutations = ProjectMutationSession(project);
    final session = WizardSession(
      target: SiteWizardTarget(
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
      ),
      registry: WizardProviderRegistry([const _NoOpProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(9101)),
      ),
    );

    expect(session.begin(), isTrue);
    expect(session.selectFamily(_NoOpProvider.familyId), isTrue);
    expect(session.generatePreview(), isFalse);
    expect(session.status, WizardSessionStatus.previewBlocked);
    expect(session.blockReason, WizardPreviewBlockReason.noChanges);
    expect(session.preview, isNotNull);
    expect(session.preview!.hasChanges, isFalse);
    expect(session.canConfirm, isFalse);
    expect(session.confirm(), isFalse);
    expect(mutations.current.version.value, 0);
    expect(mutations.undoDepth, 0);
    expect(mutations.redoDepth, 0);

    final retained = session.preview!;
    expect(session.back(), isTrue);
    expect(session.preview, isNull);
    expect(
      () => session.mutations.commitPreview(retained),
      throwsA(isA<DiscardedWizardPreviewException>()),
    );
    expect(mutations.current.version.value, 0);
    expect(mutations.undoDepth, 0);
  });
}

final class _NoOpParameters extends WizardParameters {
  const _NoOpParameters();
}

final class _NoOpProvider extends TypedWizardProvider<_NoOpParameters> {
  const _NoOpProvider();

  static final familyId = WizardFamilyId('p8.test.noop');

  @override
  WizardProviderDescriptor get descriptor => WizardProviderDescriptor(
        templateId: TemplateId('p8.test.noop.template'),
        templateVersion: 1,
        generatorVersion: '1',
        familyId: familyId,
        displayName: 'No-op qualification provider',
        supportedScopes: const {WizardTargetScope.site},
      );

  @override
  _NoOpParameters typedDefaultsFor(WizardTargetContext target) =>
      const _NoOpParameters();

  @override
  WizardParameterValidation validateTypedParameters(
    _NoOpParameters parameters,
    WizardTargetContext target,
  ) =>
      const WizardParameterValidation.valid();

  @override
  ReservedProjectCommand generateTyped(
    _NoOpParameters parameters,
    WizardGenerationContext context,
  ) =>
      const _NoOpCommand();
}

final class _NoOpCommand implements ReservedProjectCommand {
  const _NoOpCommand();

  @override
  String get commandType => 'p8.test.noop';

  @override
  String get normalizedIntentKey => 'p8.test.noop';

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
  }) =>
      ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
          engineeringMetadata: current.engineeringMetadata,
          stores: current.stores,
        ),
        affectedEntityIds: const <EntityId>{},
      );

  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) =>
      const <ProjectSemanticOperation>[];
}
