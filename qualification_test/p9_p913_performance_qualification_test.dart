import 'dart:io';
import 'dart:math';

import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_canonical_materializer.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_topology_vector_renderer.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = _fixture();
  const service = ApartmentCandidateSetService();
  const renderer = ApartmentTopologyVectorRenderer();
  const materializer = ApartmentCanonicalMaterializer();
  final request = _request();

  group('P9.13 hard performance qualification', () {
    test('NFR-001 candidate pipeline p95 <=500ms and p99 <=900ms', () {
      for (var warmup = 0; warmup < 10; warmup++) {
        final result = service.generate(
          input: request,
          target: fixture.target,
          project: fixture.project,
        );
        expect(result.accepted, isTrue);
      }

      final samplesUs = <int>[];
      for (var sample = 0; sample < 100; sample++) {
        final stopwatch = Stopwatch()..start();
        final result = service.generate(
          input: request,
          target: fixture.target,
          project: fixture.project,
        );
        stopwatch.stop();
        expect(result.accepted, isTrue);
        samplesUs.add(stopwatch.elapsedMicroseconds);
      }

      _expectPercentiles(
        label: 'candidate pipeline',
        samplesUs: samplesUs,
        p95LimitUs: 500000,
        p99LimitUs: 900000,
      );
    });

    test('NFR-002 vector cards p95 <=100ms and p99 <=200ms', () {
      final generated = service.generate(
        input: request,
        target: fixture.target,
        project: fixture.project,
      );
      expect(generated.accepted, isTrue);
      final set = generated.candidateSet!;

      for (var warmup = 0; warmup < 20; warmup++) {
        for (final card in set.candidates) {
          expect(
            renderer
                .render(
                  rankedCandidate: card.rankedCandidate,
                  template: card.template,
                )
                .accepted,
            isTrue,
          );
        }
      }

      final samplesUs = <int>[];
      for (var sample = 0; sample < 100; sample++) {
        final stopwatch = Stopwatch()..start();
        for (final card in set.candidates) {
          final rendered = renderer.render(
            rankedCandidate: card.rankedCandidate,
            template: card.template,
          );
          expect(rendered.accepted, isTrue);
        }
        stopwatch.stop();
        samplesUs.add(stopwatch.elapsedMicroseconds);
      }

      _expectPercentiles(
        label: 'vector cards',
        samplesUs: samplesUs,
        p95LimitUs: 100000,
        p99LimitUs: 200000,
      );
    });

    test('NFR-003/004 preview materialization p95 <=300/500ms p99 <=600/900ms',
        () {
      final generated = service.generate(
        input: request,
        target: fixture.target,
        project: fixture.project,
      );
      expect(generated.accepted, isTrue);
      final card = generated.candidateSet!.recommendedCandidate;
      final previewSamplesUs = <int>[];
      final materializationSamplesUs = <int>[];

      for (var sample = 0; sample < 100; sample++) {
        final idFactory = SecureRandomEntityIdFactory(
          random: Random(913000 + sample),
        );
        final reservation = materializer.reserveIdentities(
          factory: idFactory,
          candidate: card.rankedCandidate.candidate,
        );
        final stopwatch = Stopwatch()..start();
        final candidate = materializer.buildCandidate(
          current: fixture.project,
          target: fixture.target,
          candidate: card.rankedCandidate.candidate,
          template: card.template,
          reservation: reservation,
        );
        stopwatch.stop();
        expect(candidate.candidate.version, fixture.project.version);
        materializationSamplesUs.add(stopwatch.elapsedMicroseconds);

        final previewStopwatch = Stopwatch()..start();
        candidate.changeSet;
        candidate.affectedEntityIds;
        previewStopwatch.stop();
        previewSamplesUs.add(
          stopwatch.elapsedMicroseconds + previewStopwatch.elapsedMicroseconds,
        );
      }

      _expectPercentiles(
        label: 'preview candidate',
        samplesUs: previewSamplesUs,
        p95LimitUs: 300000,
        p99LimitUs: 600000,
      );
      _expectPercentiles(
        label: 'reserved materialization',
        samplesUs: materializationSamplesUs,
        p95LimitUs: 500000,
        p99LimitUs: 900000,
      );
    });

    test('NFR-005 generate-render-preview incremental RSS <=128MiB', () {
      for (var warmup = 0; warmup < 5; warmup++) {
        _runAcceptanceCycle(
          service: service,
          renderer: renderer,
          materializer: materializer,
          fixture: fixture,
          request: request,
          seed: 912000 + warmup,
        );
      }

      final baselineRss = ProcessInfo.currentRss;
      var peakRss = baselineRss;
      for (var cycle = 0; cycle < 20; cycle++) {
        _runAcceptanceCycle(
          service: service,
          renderer: renderer,
          materializer: materializer,
          fixture: fixture,
          request: request,
          seed: 913500 + cycle,
        );
        peakRss = max(peakRss, ProcessInfo.currentRss);
      }
      final incrementalBytes = max(0, peakRss - baselineRss);
      const limitBytes = 128 * 1024 * 1024;

      expect(
        incrementalBytes,
        lessThanOrEqualTo(limitBytes),
        reason:
            'incremental RSS=${(incrementalBytes / 1024 / 1024).toStringAsFixed(1)}MiB '
            'baseline=${(baselineRss / 1024 / 1024).toStringAsFixed(1)}MiB '
            'peak=${(peakRss / 1024 / 1024).toStringAsFixed(1)}MiB',
      );
    });
  });
}

void _runAcceptanceCycle({
  required ApartmentCandidateSetService service,
  required ApartmentTopologyVectorRenderer renderer,
  required ApartmentCanonicalMaterializer materializer,
  required _Fixture fixture,
  required ApartmentRequestInput request,
  required int seed,
}) {
  final generated = service.generate(
    input: request,
    target: fixture.target,
    project: fixture.project,
  );
  expect(generated.accepted, isTrue);
  final set = generated.candidateSet!;
  for (final card in set.candidates) {
    expect(
      renderer
          .render(
            rankedCandidate: card.rankedCandidate,
            template: card.template,
          )
          .accepted,
      isTrue,
    );
  }
  final card = set.recommendedCandidate;
  final reservation = materializer.reserveIdentities(
    factory: SecureRandomEntityIdFactory(random: Random(seed)),
    candidate: card.rankedCandidate.candidate,
  );
  materializer.buildCandidate(
    current: fixture.project,
    target: fixture.target,
    candidate: card.rankedCandidate.candidate,
    template: card.template,
    reservation: reservation,
  );
}

void _expectPercentiles({
  required String label,
  required List<int> samplesUs,
  required int p95LimitUs,
  required int p99LimitUs,
}) {
  final sorted = List<int>.from(samplesUs)..sort();
  final p95 = _percentile(sorted, 0.95);
  final p99 = _percentile(sorted, 0.99);
  expect(
    p95,
    lessThanOrEqualTo(p95LimitUs),
    reason: '$label p95=${p95}us limit=${p95LimitUs}us',
  );
  expect(
    p99,
    lessThanOrEqualTo(p99LimitUs),
    reason: '$label p99=${p99}us limit=${p99LimitUs}us',
  );
}

int _percentile(List<int> sorted, double percentile) {
  final index = ((sorted.length * percentile).ceil() - 1)
      .clamp(0, sorted.length - 1);
  return sorted[index];
}

ApartmentRequestInput _request() => const ApartmentRequestInput(
      habitableRoomCount: 3,
      approximateAreaDm2: 7850,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 1,
      balconyKind: ApartmentBalconyKind.loggia,
      kitchenMode: ApartmentKitchenMode.kitchenLiving,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );

final class _Fixture {
  const _Fixture({required this.project, required this.target});

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_Fixture _fixture() {
  final projectId = ProjectId('p9-p913-nfr-project');
  final siteId = SiteId('p9-p913-nfr-site');
  final buildingId = BuildingId('p9-p913-nfr-building');
  final levelId = LevelId('p9-p913-nfr-level');
  final version = LocalProjectVersion(13);
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'P9.13 Site',
          buildingIds: {buildingId},
        ),
      },
      buildings: {
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'P9.13 Building',
          levelIds: {levelId},
        ),
      },
      levels: {
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Level 1',
          levelNumber: 1,
          elevationMm: 3000,
          kind: ProjectLevelKind.residential,
          spaceIds: const {},
        ),
      },
    ),
  );
  return _Fixture(
    project: project,
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}
