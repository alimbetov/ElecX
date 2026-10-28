import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE10-CQ21 bounded preview/reservation lifecycle', () {
    test('1000 cancel/apply cycles leave no strongly retained active preview', () {
      final projectId = ProjectId('project-cq21');
      final siteId = SiteId('site-cq21');
      final project = ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(
          sites: {
            siteId: ProjectSiteEntity(
              id: siteId,
              name: 'Site 0',
              buildingIds: const [],
            ),
          },
        ),
      );
      final mutations = ProjectMutationSession(project);
      final port = SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(),
      );

      for (var cycle = 1; cycle <= 1000; cycle++) {
        final preview = port.preview(_RenameSiteCommand('Site $cycle'));
        expect(
          port.activePreviewCount,
          1,
          reason: 'cycle $cycle must retain only its live preview',
        );

        if (cycle.isEven) {
          port.discardPreview(preview);
          expect(
            () => port.commitPreview(preview),
            throwsA(isA<DiscardedWizardPreviewException>()),
          );
        } else {
          final result = port.commitPreview(preview);
          expect(result, isNotNull);
          expect(
            () => port.commitPreview(preview),
            throwsA(isA<ConsumedMutationReservationException>()),
          );
        }

        expect(
          port.activePreviewCount,
          0,
          reason: 'terminal cycle $cycle must release its coordinator/preview',
        );
      }

      expect(mutations.current.stores.sites[siteId]!.name, 'Site 999');
      expect(mutations.current.version.value, 500);
    });
  });
}

final class _RenameSiteCommand implements ReservedProjectCommand {
  const _RenameSiteCommand(this.name);

  final String name;

  @override
  String get commandType => 'cq21.renameSite';

  @override
  String get normalizedIntentKey => 'cq21.renameSite|$name';

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(factory: factory);

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    final currentSite = current.stores.sites[current.siteId]!;
    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: {
          current.siteId: ProjectSiteEntity(
            id: currentSite.id,
            name: name,
            buildingIds: currentSite.buildingIds,
          ),
        },
      ),
      affectedEntityIds: {current.siteId},
    );
  }

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {}

  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) =>
      [UpdateEntityOperation(entityId: before.siteId)];
}
