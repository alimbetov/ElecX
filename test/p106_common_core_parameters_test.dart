import 'dart:convert';

import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p10_building_fixture.dart';

void main() {
  group('P10.6A common-core contract versioning', () {
    test('legacy v1 canonical JSON remains byte-compatible', () {
      final legacy = p10Core();

      expect(
        legacy.contractVersion,
        CommonCoreParameters.legacyContractVersion,
      );
      expect(legacy.isCurrentContract, isFalse);
      expect(
        jsonEncode(legacy.toCanonicalJson()),
        '{"stairCount":1,"liftCount":1,"serviceShaftCount":1,'
        '"corridorWidthMm":1800,"includeTechnicalRoom":false}',
      );
      expect(legacy.toCanonicalJson(), isNot(contains('contractVersion')));
      expect(legacy.toCanonicalJson(), isNot(contains('electricalRiserCount')));
      expect(legacy.toCanonicalJson(), isNot(contains('telecomRiserCount')));
    });

    test('v2 fingerprints electrical, telecom and candidate-space policy', () {
      final current = CommonCoreParameters.v2(
        stairCount: 1,
        liftCount: 1,
        serviceShaftCount: 1,
        electricalRiserCount: 1,
        telecomRiserCount: 1,
        corridorWidthMm: 1800,
        includeTechnicalRoom: true,
        serviceSpacePolicy: const CommonServiceSpacePolicy(
          includeCommonHall: true,
          includeElevatorHall: true,
          includeElectricalRoomCandidate: true,
          includeTelecomRoomCandidate: true,
          includeFireControlRoomCandidate: true,
          includeUtilityRoomCandidate: true,
        ),
      );

      expect(
        current.contractVersion,
        CommonCoreParameters.currentContractVersion,
      );
      expect(current.isCurrentContract, isTrue);
      expect(
        current.toCanonicalJson(),
        containsPair('contractVersion', 2),
      );
      expect(
        current.toCanonicalJson(),
        containsPair('electricalRiserCount', 1),
      );
      expect(
        current.toCanonicalJson(),
        containsPair('telecomRiserCount', 1),
      );
      expect(
        current.toCanonicalJson()['serviceSpacePolicy'],
        equals({
          'includeCommonHall': true,
          'includeElevatorHall': true,
          'includeElectricalRoomCandidate': true,
          'includeTelecomRoomCandidate': true,
          'includeFireControlRoomCandidate': true,
          'includeUtilityRoomCandidate': true,
        }),
      );
    });

    test('new v2 semantics participate in the building request fingerprint',
        () {
      CommonCoreParameters core({
        int electrical = 1,
        int telecom = 1,
        bool fire = false,
      }) =>
          CommonCoreParameters.v2(
            stairCount: 1,
            liftCount: 1,
            serviceShaftCount: 1,
            electricalRiserCount: electrical,
            telecomRiserCount: telecom,
            corridorWidthMm: 1800,
            serviceSpacePolicy: CommonServiceSpacePolicy(
              includeFireControlRoomCandidate: fire,
            ),
          );

      final baseline = p10Request(core: core()).requestFingerprint;
      expect(
        p10Request(core: core(electrical: 2)).requestFingerprint,
        isNot(baseline),
      );
      expect(
        p10Request(core: core(telecom: 2)).requestFingerprint,
        isNot(baseline),
      );
      expect(
        p10Request(core: core(fire: true)).requestFingerprint,
        isNot(baseline),
      );
      expect(p10Request().requestFingerprint, isNot(baseline));
    });

    test('invalid v2 riser counts fail before generation', () {
      CommonCoreParameters build({
        int electrical = 1,
        int telecom = 1,
      }) =>
          CommonCoreParameters.v2(
            stairCount: 1,
            liftCount: 1,
            serviceShaftCount: 1,
            electricalRiserCount: electrical,
            telecomRiserCount: telecom,
            corridorWidthMm: 1800,
          );

      expect(() => build(electrical: -1), throwsArgumentError);
      expect(() => build(telecom: -1), throwsArgumentError);
      expect(() => build(electrical: 33), throwsArgumentError);
      expect(() => build(telecom: 33), throwsArgumentError);
    });
  });
}
