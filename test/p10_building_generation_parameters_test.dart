import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p10_building_fixture.dart';

void main() {
  group('P10-Q01 request normalization', () {
    test(
      'equivalent ordering, whitespace and wrapped angles normalize equally',
      () {
        BuildingGenerationParameters request(bool reverse) => p10Request(
              name: reverse ? ' Tower A ' : 'Tower A',
              stack: LevelStackParameters(
                levels: reverse ? p10Levels().reversed : p10Levels(),
              ),
              placement: BuildingSitePlacement(
                xMm: 100,
                yMm: -200,
                orientation: ProjectEngineeringNorth.fromDegrees(
                  reverse ? 450 : 90,
                ),
              ),
              typicalFloor: TypicalFloorSelection(
                definitionKey:
                    reverse ? ' residential.standard ' : 'residential.standard',
                levelGenerationKeys: reverse
                    ? ['residential.1', 'ground']
                    : ['ground', 'residential.1'],
              ),
              anchors: ServiceAnchorParameters(
                kinds: reverse
                    ? [
                        BuildingServiceAnchorKind.telecomEntry,
                        BuildingServiceAnchorKind.electricalEntry,
                      ]
                    : [
                        BuildingServiceAnchorKind.electricalEntry,
                        BuildingServiceAnchorKind.telecomEntry,
                      ],
              ),
            );

        expect(
          request(true).canonicalSerialization,
          request(false).canonicalSerialization,
        );
        expect(
          request(true).requestFingerprint,
          request(false).requestFingerprint,
        );
        expect(
          request(false).requestFingerprint,
          matches(RegExp(r'^[0-9a-f]{64}$')),
        );
      },
    );

    test('semantic changes invalidate the fingerprint', () {
      final baseline = p10Request().requestFingerprint;
      final changed = [
        p10Request(name: 'Tower B'),
        p10Request(site: 'site-b'),
        p10Request(kind: BuildingCompositionKind.detachedHouse),
        p10Request(
          stack: LevelStackParameters(
            levels: p10Levels(),
            groundElevationMm: 1,
          ),
        ),
        p10Request(
          placement: BuildingSitePlacement(
            xMm: 1,
            yMm: 0,
            orientation: ProjectEngineeringNorth.fromDegrees(0),
          ),
        ),
        p10Request(
          placement: BuildingSitePlacement(
            xMm: 0,
            yMm: 1,
            orientation: ProjectEngineeringNorth.fromDegrees(0),
          ),
        ),
        p10Request(
          placement: BuildingSitePlacement(
            xMm: 0,
            yMm: 0,
            orientation: ProjectEngineeringNorth.fromDegrees(1),
          ),
        ),
        p10Request(core: p10Core(lifts: 2)),
        p10Request(
          anchors: ServiceAnchorParameters(
            kinds: [BuildingServiceAnchorKind.generatorArea],
          ),
        ),
        p10Request(
          typicalFloor: TypicalFloorSelection(
            definitionKey: 'residential.standard',
            levelGenerationKeys: ['residential.1'],
          ),
        ),
        p10Request(template: p10TemplateRef()),
      ];
      expect(
        changed.map((request) => request.requestFingerprint),
        everyElement(isNot(baseline)),
      );
      expect(
        changed.map((request) => request.requestFingerprint).toSet(),
        hasLength(changed.length),
      );
    });

    test('collections are defensively copied and unmodifiable', () {
      final inputLevels = p10Levels();
      final inputKeys = ['residential.1'];
      final inputAnchors = [BuildingServiceAnchorKind.telecomEntry];
      final stack = LevelStackParameters(levels: inputLevels);
      final typical = TypicalFloorSelection(
        definitionKey: 'standard',
        levelGenerationKeys: inputKeys,
      );
      final anchors = ServiceAnchorParameters(kinds: inputAnchors);
      final request = p10Request(
        stack: stack,
        typicalFloor: typical,
        anchors: anchors,
      );
      final fingerprint = request.requestFingerprint;
      inputLevels.clear();
      inputKeys.clear();
      inputAnchors.clear();
      expect(request.requestFingerprint, fingerprint);
      expect(() => stack.levels.clear(), throwsUnsupportedError);
      expect(() => typical.levelGenerationKeys.clear(), throwsUnsupportedError);
      expect(() => anchors.kinds.clear(), throwsUnsupportedError);
    });

    test(
      'unsupported versions and missing typical-floor targets fail closed',
      () {
        expect(() => p10Request(schemaVersion: 2), throwsArgumentError);
        expect(
          () => p10Request(generatorVersion: 'p10.future'),
          throwsArgumentError,
        );
        expect(() => p10Request(name: '  '), throwsArgumentError);
        expect(() => p10TemplateRef(templateVersion: 0), throwsArgumentError);
        expect(
          () => p10Request(
            typicalFloor: TypicalFloorSelection(
              definitionKey: 'standard',
              levelGenerationKeys: ['missing'],
            ),
          ),
          throwsArgumentError,
        );
      },
    );

    test('display strings cannot inject additional serialized fields', () {
      final request = p10Request(name: 'Tower\n"kind":"detachedHouse"');
      expect(request.kind, BuildingCompositionKind.residentialTower);
      expect(
        request.canonicalSerialization,
        contains(r'Tower\n\"kind\":\"detachedHouse\"'),
      );
      expect(
        request.requestFingerprint,
        isNot(p10Request(name: 'Tower').requestFingerprint),
      );
    });
  });

  group('P10 level parameter validation', () {
    test(
        'duplicate identities, numbers, codes and ordinals fail before generation',
        () {
      for (final duplicate in [
        p10Level(
          key: 'ground',
          ordinal: 1,
          number: 1,
          code: '01',
          kind: ProjectLevelKind.residential,
        ),
        p10Level(
          key: 'upper',
          ordinal: 1,
          number: 0,
          code: '01',
          kind: ProjectLevelKind.residential,
        ),
        p10Level(
          key: 'upper',
          ordinal: 1,
          number: 1,
          code: 'G',
          kind: ProjectLevelKind.residential,
        ),
        p10Level(
          key: 'upper',
          ordinal: 0,
          number: 1,
          code: '01',
          kind: ProjectLevelKind.residential,
        ),
        p10Level(
          key: 'upper',
          ordinal: 2,
          number: 1,
          code: '01',
          kind: ProjectLevelKind.residential,
        ),
      ]) {
        expect(
          () => LevelStackParameters(levels: [p10Level(), duplicate]),
          throwsArgumentError,
        );
      }
    });

    test(
      'unknown roles, invalid heights, dimensions and counts fail closed',
      () {
        expect(
          () => p10Level(kind: ProjectLevelKind.unknown),
          throwsArgumentError,
        );
        expect(() => p10Level(height: 0), throwsArgumentError);
        expect(() => p10Level(number: 201), throwsArgumentError);
        expect(() => p10Level(key: 'localized key'), throwsArgumentError);
        expect(() => p10Core(stairs: -1), throwsArgumentError);
        expect(
          () => BuildingSitePlacement(
            xMm: 1000000001,
            yMm: 0,
            orientation: ProjectEngineeringNorth.fromDegrees(0),
          ),
          throwsArgumentError,
        );
        expect(() => LevelStackParameters(levels: []), throwsArgumentError);
      },
    );

    test('ambiguous ground/basement/roof ordering is rejected', () {
      expect(
        () => LevelStackParameters(
          levels: [p10Level(kind: ProjectLevelKind.basement)],
        ),
        throwsArgumentError,
      );
      expect(
        () => LevelStackParameters(
          levels: [
            p10Level(),
            p10Level(key: 'g2', ordinal: 1, number: 1, code: 'G2'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => LevelStackParameters(
          levels: [
            p10Level(),
            p10Level(
              key: 'basement',
              ordinal: 1,
              number: -1,
              code: 'B1',
              kind: ProjectLevelKind.basement,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => LevelStackParameters(
          levels: [
            p10Level(),
            p10Level(
              key: 'roof',
              ordinal: 1,
              number: 1,
              code: 'RF',
              kind: ProjectLevelKind.roof,
            ),
            p10Level(
              key: 'upper',
              ordinal: 2,
              number: 2,
              code: '02',
              kind: ProjectLevelKind.residential,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
