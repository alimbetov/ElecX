import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/p9_sha256.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9 SHA-256 fingerprint primitive', () {
    test('matches standard empty and abc vectors', () {
      expect(
        p9Sha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb924'
        '27ae41e4649b934ca495991b7852b855',
      );
      expect(
        p9Sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223'
        'b00361a396177a9cb410ff61f20015ad',
      );
    });
  });

  group('P9.1 ApartmentRequestNormalizer', () {
    const normalizer = ApartmentRequestNormalizer();

    test('P9.1-AT-001 minimum request normalizes', () {
      final result = normalizer.normalize(
        _request(
          habitableRoomCount: 1,
          approximateAreaDm2: 1500,
          bathroomCount: 1,
          separateWcCount: 0,
          balconyCount: 0,
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.request!.habitableRoomCount, 1);
      expect(result.request!.interiorAreaDm2, 1500);
      expect(result.request!.balconyKind, ApartmentBalconyKind.none);
    });

    test('P9.1-AT-002 maximum sanity request normalizes', () {
      final result = normalizer.normalize(
        _request(
          habitableRoomCount: 10,
          approximateAreaDm2: 50000,
          bathroomCount: 6,
          separateWcCount: 4,
          balconyCount: 6,
          balconyKind: ApartmentBalconyKind.loggia,
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.request!.habitableRoomCount, 10);
      expect(result.request!.interiorAreaDm2, 50000);
      expect(result.request!.balconyCount, 6);
    });

    test('P9.1-AT-003 reports all independent sanity range blockers', () {
      final result = normalizer.normalize(
        _request(
          habitableRoomCount: 11,
          approximateAreaDm2: 1499,
          bathroomCount: 7,
          separateWcCount: 5,
          balconyCount: 7,
        ),
      );

      expect(result.request, isNull);
      expect(
        result.failures.map((failure) => failure.code).toSet(),
        containsAll({
          'p9.parameters.room-count-out-of-range',
          'p9.parameters.area-out-of-range',
          'p9.parameters.bathroom-count-out-of-range',
          'p9.parameters.wc-count-out-of-range',
          'p9.parameters.balcony-count-out-of-range',
        }),
      );
    });

    test('P9.1-AT-005 zero balcony normalizes balcony kind to none', () {
      final either = normalizer.normalize(
        _request(balconyCount: 0, balconyKind: ApartmentBalconyKind.either),
      );
      final balcony = normalizer.normalize(
        _request(balconyCount: 0, balconyKind: ApartmentBalconyKind.balcony),
      );

      expect(either.request!.balconyKind, ApartmentBalconyKind.none);
      expect(
        either.request!.intentFingerprint,
        balcony.request!.intentFingerprint,
      );
    });

    test('non-zero balcony cannot request none kind', () {
      final result = normalizer.normalize(
        _request(balconyCount: 1, balconyKind: ApartmentBalconyKind.none),
      );

      expect(result.isValid, isFalse);
      expect(
        result.failures.map((failure) => failure.code),
        contains('p9.parameters.invalid-balcony-kind'),
      );
    });

    test('P9.1-AT-006 kitchen modes remain fingerprint-distinct', () {
      final separate = normalizer.normalize(
        _request(kitchenMode: ApartmentKitchenMode.separate),
      );
      final kitchenLiving = normalizer.normalize(
        _request(kitchenMode: ApartmentKitchenMode.kitchenLiving),
      );
      final openPlan = normalizer.normalize(
        _request(kitchenMode: ApartmentKitchenMode.openPlan),
      );

      expect(
        {
          separate.request!.intentFingerprint,
          kitchenLiving.request!.intentFingerprint,
          openPlan.request!.intentFingerprint,
        },
        hasLength(3),
      );
    });

    test('P9.1-AT-010 same request yields stable fingerprint 10000 times', () {
      final input = _request(
        preferredFamily: ApartmentTopologyFamily.splitDayNight,
        preferDayNightSeparation: true,
      );
      final expected = normalizer.normalize(input).request!.intentFingerprint;

      for (var i = 0; i < 10000; i++) {
        expect(
            normalizer.normalize(input).request!.intentFingerprint, expected);
      }
    });

    test('P9.1-AT-011 only Level target is accepted', () {
      final projectId = ProjectId('p9-project');
      final siteId = SiteId('p9-site');
      final version = LocalProjectVersion(4);
      final levelTarget = LevelWizardTarget(
        projectId: projectId,
        siteId: siteId,
        baseVersion: version,
        buildingId: BuildingId('p9-building'),
        levelId: LevelId('p9-level'),
      );
      final siteTarget = SiteWizardTarget(
        projectId: projectId,
        siteId: siteId,
        baseVersion: version,
      );

      expect(normalizer.validateTarget(levelTarget), isEmpty);
      expect(
        normalizer.validateTarget(siteTarget).single.code,
        'p9.parameters.unsupported-target',
      );
    });

    test('P9.1-AT-012 changing semantic field changes fingerprint', () {
      final first = normalizer.normalize(_request()).request!;
      final second = normalizer
          .normalize(
            _request(approximateAreaDm2: 6100),
          )
          .request!;

      expect(second.intentFingerprint, isNot(first.intentFingerprint));
    });

    test('P9.1-AT-013 target identity never enters request fingerprint', () {
      final normalized = normalizer.normalize(_request()).request!;

      expect(normalized.canonicalSerialization, isNot(contains('project-')));
      expect(normalized.canonicalSerialization, isNot(contains('level-')));
    });

    test('P9.1-AT-014 selection never changes intent fingerprint', () {
      final request = _request();
      final before = normalizer.normalize(request).request!.intentFingerprint;
      final parameters = ApartmentWizardParameters(
        request: request,
        selection: _selection('candidate-a'),
      );
      final after =
          normalizer.normalize(parameters.request).request!.intentFingerprint;

      expect(after, before);
    });

    test('P9.1-AT-015 semantic edit clears candidate selection', () {
      final parameters = ApartmentWizardParameters(
        request: _request(),
        selection: _selection('candidate-a'),
      );

      final changed = parameters.withRequest(
        _request(approximateAreaDm2: 6200),
      );

      expect(changed.selection, isNull);
    });

    test('P9.1-AT-016 neutral normalization preserves candidate selection', () {
      final selection = _selection('candidate-a');
      final parameters = ApartmentWizardParameters(
        request: _request(
          balconyCount: 0,
          balconyKind: ApartmentBalconyKind.either,
        ),
        selection: selection,
      );

      final changed = parameters.withRequest(
        _request(
          balconyCount: 0,
          balconyKind: ApartmentBalconyKind.loggia,
        ),
      );

      expect(changed.selection, same(selection));
    });

    test('canonical serialization uses stable codes and explicit units', () {
      final normalized = normalizer
          .normalize(
            _request(
              approximateAreaDm2: 7850,
              kitchenMode: ApartmentKitchenMode.openPlan,
              exteriorExposurePreference:
                  ApartmentExteriorExposurePreference.corner,
              preferredFamily: ApartmentTopologyFamily.corner,
            ),
          )
          .request!;

      expect(normalized.canonicalSerialization,
          contains('approximateAreaDm2=7850'));
      expect(
          normalized.canonicalSerialization, contains('kitchenMode=openPlan'));
      expect(
        normalized.canonicalSerialization,
        contains('exteriorExposurePreference=corner'),
      );
      expect(normalized.canonicalSerialization,
          contains('preferredFamily=corner'));
      expect(normalized.intentFingerprint, hasLength(64));
    });
  });

  group('ApartmentCandidateSelection', () {
    test('requires stable non-empty diagnostic identity', () {
      expect(
        () => ApartmentCandidateSelection(
          candidateFingerprint: '',
          templateIdValue: 'template',
          templateVersion: 1,
          variantSeedId: 'seed',
        ),
        throwsArgumentError,
      );
      expect(
        () => ApartmentCandidateSelection(
          candidateFingerprint: 'candidate',
          templateIdValue: 'template',
          templateVersion: 0,
          variantSeedId: 'seed',
        ),
        throwsArgumentError,
      );
    });
  });
}

ApartmentCandidateSelection _selection(String fingerprint) =>
    ApartmentCandidateSelection(
      candidateFingerprint: fingerprint,
      templateIdValue: 'apt-compact-2r',
      templateVersion: 1,
      variantSeedId: 'seed-1',
    );

ApartmentRequestInput _request({
  int habitableRoomCount = 2,
  int approximateAreaDm2 = 6000,
  int bathroomCount = 1,
  int separateWcCount = 0,
  int balconyCount = 0,
  ApartmentBalconyKind balconyKind = ApartmentBalconyKind.either,
  ApartmentKitchenMode kitchenMode = ApartmentKitchenMode.separate,
  ApartmentCorridorMode corridorMode = ApartmentCorridorMode.auto,
  ApartmentExteriorExposurePreference exteriorExposurePreference =
      ApartmentExteriorExposurePreference.any,
  ApartmentTopologyFamily? preferredFamily,
  bool preferDayNightSeparation = false,
}) =>
    ApartmentRequestInput(
      habitableRoomCount: habitableRoomCount,
      approximateAreaDm2: approximateAreaDm2,
      bathroomCount: bathroomCount,
      separateWcCount: separateWcCount,
      balconyCount: balconyCount,
      balconyKind: balconyKind,
      kitchenMode: kitchenMode,
      corridorMode: corridorMode,
      exteriorExposurePreference: exteriorExposurePreference,
      preferredFamily: preferredFamily,
      preferDayNightSeparation: preferDayNightSeparation,
    );
