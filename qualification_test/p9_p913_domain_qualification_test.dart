import 'dart:math';

import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

const _supportedCorpusVersion = 'p9.13-supported-v1';
const _invalidCorpusVersion = 'p9.13-invalid-v1';
const _fuzzSeed = 91313;
const _supportedCorpusSize = 250;
const _invalidCorpusSize = 100;
const _fuzzCaseCount = 1500;
const _determinismRepetitions = 10;

void main() {
  final fixture = _fixture();
  const service = ApartmentCandidateSetService();

  group('P9.13 A — Domain qualification', () {
    test('A1 supported corpus >=250 reaches qualified canonical candidates',
        () {
      final corpus = _supportedCorpusV1();
      expect(corpus, hasLength(_supportedCorpusSize));

      for (var index = 0; index < corpus.length; index++) {
        final result = service.generate(
          input: corpus[index],
          target: fixture.target,
          project: fixture.project,
        );
        expect(
          result.accepted,
          isTrue,
          reason:
              '$_supportedCorpusVersion[$index] rejected: ${_failureCodes(result)}',
        );
        _expectQualifiedSet(result.candidateSet!);
      }
    });

    test('A2 invalid corpus >=100 fails closed with typed blockers', () {
      final corpus = _invalidCorpusV1();
      expect(corpus, hasLength(_invalidCorpusSize));
      final versionBefore = fixture.project.version;
      final storesBefore = fixture.project.stores;

      for (var index = 0; index < corpus.length; index++) {
        final result = service.generate(
          input: corpus[index],
          target: fixture.target,
          project: fixture.project,
        );
        expect(
          result.accepted,
          isFalse,
          reason: '$_invalidCorpusVersion[$index] must fail closed',
        );
        expect(result.candidateSet, isNull);
        expect(
          result.failures.any((failure) => failure.isBlocker),
          isTrue,
          reason: '$_invalidCorpusVersion[$index] must expose a blocker',
        );
        expect(
          result.failures.every((failure) => failure.code.isNotEmpty),
          isTrue,
        );
      }

      expect(fixture.project.version, versionBefore);
      expect(fixture.project.stores, same(storesBefore));
    });

    test('A3 property/fuzz >=1500 never crashes and accepted geometry is valid',
        () {
      final random = Random(_fuzzSeed);
      var accepted = 0;
      var rejected = 0;

      for (var index = 0; index < _fuzzCaseCount; index++) {
        final roomCount = 1 + random.nextInt(10);
        final request = ApartmentRequestInput(
          habitableRoomCount: roomCount,
          approximateAreaDm2:
              _representativeArea(roomCount) + random.nextInt(241) - 120,
          bathroomCount: 1 + random.nextInt(3),
          separateWcCount: random.nextInt(2),
          balconyCount: random.nextInt(3),
          balconyKind: switch (random.nextInt(3)) {
            0 => ApartmentBalconyKind.balcony,
            1 => ApartmentBalconyKind.loggia,
            _ => ApartmentBalconyKind.either,
          },
          kitchenMode: ApartmentKitchenMode
              .values[random.nextInt(ApartmentKitchenMode.values.length)],
          corridorMode: ApartmentCorridorMode
              .values[random.nextInt(ApartmentCorridorMode.values.length)],
          exteriorExposurePreference:
              ApartmentExteriorExposurePreference.values[random
                  .nextInt(ApartmentExteriorExposurePreference.values.length)],
          preferDayNightSeparation: random.nextBool(),
        );
        final normalizedRequest = request.balconyCount == 0
            ? ApartmentRequestInput(
                habitableRoomCount: request.habitableRoomCount,
                approximateAreaDm2: request.approximateAreaDm2,
                bathroomCount: request.bathroomCount,
                separateWcCount: request.separateWcCount,
                balconyCount: 0,
                balconyKind: ApartmentBalconyKind.none,
                kitchenMode: request.kitchenMode,
                corridorMode: request.corridorMode,
                exteriorExposurePreference: request.exteriorExposurePreference,
                preferDayNightSeparation: request.preferDayNightSeparation,
              )
            : request;

        final result = service.generate(
          input: normalizedRequest,
          target: fixture.target,
          project: fixture.project,
        );
        if (result.accepted) {
          accepted++;
          _expectQualifiedSet(result.candidateSet!);
        } else {
          rejected++;
          expect(result.candidateSet, isNull);
          expect(
            result.failures.any((failure) => failure.isBlocker),
            isTrue,
            reason: 'fuzz[$index] rejection must be typed and blocking',
          );
        }
      }

      expect(accepted + rejected, _fuzzCaseCount);
      expect(
        accepted,
        greaterThan(0),
        reason: 'fuzz corpus must exercise accepted production geometry',
      );
    });

    test('A4 every supported corpus request is deterministic across 10 runs',
        () {
      final corpus = _supportedCorpusV1();

      for (var index = 0; index < corpus.length; index++) {
        final baseline = service.generate(
          input: corpus[index],
          target: fixture.target,
          project: fixture.project,
        );
        expect(baseline.accepted, isTrue);
        final expected = _semanticSignature(baseline.candidateSet!);

        for (var repetition = 1;
            repetition < _determinismRepetitions;
            repetition++) {
          final repeated = service.generate(
            input: corpus[index],
            target: fixture.target,
            project: fixture.project,
          );
          expect(
            repeated.accepted,
            isTrue,
            reason: '$_supportedCorpusVersion[$index] repetition=$repetition',
          );
          expect(
            _semanticSignature(repeated.candidateSet!),
            expected,
            reason:
                '$_supportedCorpusVersion[$index] repetition=$repetition diverged',
          );
        }
      }
    });
  });
}

void _expectQualifiedSet(ApartmentCandidateSet set) {
  expect(set.candidates, isNotEmpty);
  expect(
    set.candidates.length,
    lessThanOrEqualTo(set.scoringProfile.maximumCandidateCount),
  );
  expect(
    set.candidates.map((candidate) => candidate.candidateFingerprint).toSet(),
    hasLength(set.candidates.length),
  );

  for (final card in set.candidates) {
    final geometry = card.rankedCandidate.candidate;
    expect(geometry.validation.accepted, isTrue);
    expect(card.scene.sourceGeometryFingerprint, geometry.geometryFingerprint);
    expect(
      geometry.interiorSpaces.fold<int>(
        0,
        (sum, space) => sum + space.fittedAreaDm2,
      ),
      set.request.interiorAreaDm2,
    );
    expect(
      geometry.openingIntents
          .where((opening) => opening.kind == GeometryOpeningKind.primaryEntry),
      hasLength(1),
    );

    for (final space in <GeneratedSpaceGeometry>[
      ...geometry.interiorSpaces,
      ...geometry.exteriorAppendages,
    ]) {
      for (final point in space.polygon.vertices) {
        expect(point.xMm % p9GeometryGridMm, 0);
        expect(point.yMm % p9GeometryGridMm, 0);
      }
    }
  }
}

String _semanticSignature(ApartmentCandidateSet set) => <String>[
      set.request.intentFingerprint,
      set.catalogVersion.toString(),
      set.generatorVersion,
      set.candidateSetFingerprint,
      for (final card in set.candidates) ...<String>[
        card.candidateFingerprint,
        card.rankedCandidate.candidate.geometryFingerprint,
        card.scene.sceneFingerprint,
        for (final opening in card.rankedCandidate.candidate.openingIntents)
          <String>[
            opening.kind.name,
            opening.fromSpaceKey ?? '-',
            opening.toSpaceKey ?? '-',
            opening.hostSegment.stableKey,
          ].join('|'),
      ],
    ].join('\n');

String _failureCodes(ApartmentCandidateSetGenerationResult result) =>
    result.failures.map((failure) => failure.code).join(',');

List<ApartmentRequestInput> _supportedCorpusV1() => <ApartmentRequestInput>[
      for (var roomCount = 1; roomCount <= 10; roomCount++)
        for (var areaVariant = -12; areaVariant <= 12; areaVariant++)
          ApartmentRequestInput(
            habitableRoomCount: roomCount,
            approximateAreaDm2:
                _representativeArea(roomCount) + (areaVariant * 10),
            bathroomCount: 1,
            separateWcCount: 0,
            balconyCount: 0,
            balconyKind: ApartmentBalconyKind.none,
            kitchenMode: ApartmentKitchenMode.separate,
            corridorMode: ApartmentCorridorMode.auto,
            exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
          ),
    ];

List<ApartmentRequestInput> _invalidCorpusV1() => <ApartmentRequestInput>[
      for (var index = 0; index < _invalidCorpusSize; index++)
        switch (index % 5) {
          0 => _validInput(
              roomCount: -(index ~/ 5),
              areaDm2: 5500 + index,
            ),
          1 => _validInput(
              roomCount: 2,
              areaDm2: 1499 - index,
            ),
          2 => ApartmentRequestInput(
              habitableRoomCount: 2,
              approximateAreaDm2: 5500 + index,
              bathroomCount: 0,
              separateWcCount: 0,
              balconyCount: 0,
              balconyKind: ApartmentBalconyKind.none,
              kitchenMode: ApartmentKitchenMode.separate,
              corridorMode: ApartmentCorridorMode.auto,
              exteriorExposurePreference:
                  ApartmentExteriorExposurePreference.any,
            ),
          3 => ApartmentRequestInput(
              habitableRoomCount: 2,
              approximateAreaDm2: 5500 + index,
              bathroomCount: 1,
              separateWcCount: 0,
              balconyCount: 1,
              balconyKind: ApartmentBalconyKind.none,
              kitchenMode: ApartmentKitchenMode.separate,
              corridorMode: ApartmentCorridorMode.auto,
              exteriorExposurePreference:
                  ApartmentExteriorExposurePreference.any,
            ),
          _ => ApartmentRequestInput(
              habitableRoomCount: 2,
              approximateAreaDm2: 5500 + index,
              bathroomCount: 1,
              separateWcCount: 5 + (index ~/ 5),
              balconyCount: 0,
              balconyKind: ApartmentBalconyKind.none,
              kitchenMode: ApartmentKitchenMode.separate,
              corridorMode: ApartmentCorridorMode.auto,
              exteriorExposurePreference:
                  ApartmentExteriorExposurePreference.any,
            ),
        },
    ];

ApartmentRequestInput _validInput(
        {required int roomCount, required int areaDm2}) =>
    ApartmentRequestInput(
      habitableRoomCount: roomCount,
      approximateAreaDm2: areaDm2,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 0,
      balconyKind: ApartmentBalconyKind.none,
      kitchenMode: ApartmentKitchenMode.separate,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );

int _representativeArea(int roomCount) => switch (roomCount) {
      1 => 4000,
      2 => 5500,
      3 => 7800,
      4 => 10000,
      5 => 13000,
      6 => 16000,
      7 => 19000,
      8 => 22000,
      9 => 25000,
      10 => 28000,
      _ => throw RangeError.range(roomCount, 1, 10),
    };

final class _Fixture {
  const _Fixture({required this.project, required this.target});

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_Fixture _fixture() {
  final projectId = ProjectId('p9-p913-domain-project');
  final siteId = SiteId('p9-p913-domain-site');
  final buildingId = BuildingId('p9-p913-domain-building');
  final levelId = LevelId('p9-p913-domain-level');
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
