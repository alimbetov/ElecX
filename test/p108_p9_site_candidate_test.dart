import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/component_placement.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p105_composition_fixture.dart';
import 'support/p108_tower_fixture.dart';

void main() {
  test(
      'site exploration retains exact P9 geometry identity without a fabricated LevelId',
      () {
    final fixture = P108TowerFixture();
    final project = fixture.project;
    final result = const ApartmentCandidateSetService().generateForSite(
        input: ApartmentRequestInput.productionDefaults,
        project: project,
        target: SiteWizardTarget(
            projectId: project.id,
            siteId: project.siteId,
            baseVersion: project.version));
    expect(result.accepted, isTrue);
    final onLevel = P105CompositionFixture.create().candidateSet;
    expect(result.candidateSet!.recommendedCandidate.candidateFingerprint,
        onLevel.recommendedCandidate.candidateFingerprint);
    expect(
        result.candidateSet!.recommendedCandidate.rankedCandidate.candidate
            .geometryFingerprint,
        onLevel.recommendedCandidate.rankedCandidate.candidate
            .geometryFingerprint);
    for (final candidate in result.candidateSet!.candidates) {
      expect(
          candidate.engineeringProjection.placements.every((p) =>
              p.host is SiteComponentHost &&
              (p.host as SiteComponentHost).siteId == fixture.siteId),
          isTrue);
    }
    expect(project.stores.levels, isEmpty);
    expect(project.stores.buildings, isEmpty);
  });
  test('site exploration validates ownership and the observed version', () {
    final fixture = P108TowerFixture();
    final project = fixture.project;
    for (final target in [
      SiteWizardTarget(
          projectId: project.id,
          siteId: SiteId('foreign'),
          baseVersion: project.version),
      SiteWizardTarget(
          projectId: project.id,
          siteId: project.siteId,
          baseVersion: LocalProjectVersion(1)),
    ]) {
      expect(
          const ApartmentCandidateSetService()
              .generateForSite(
                  input: ApartmentRequestInput.productionDefaults,
                  project: project,
                  target: target)
              .accepted,
          isFalse);
    }
  });
}
