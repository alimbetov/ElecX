import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';

/// Emits the P9.13 semantic parity artifact consumed by native-platform CI.
///
/// The artifact intentionally contains only canonical generator semantics. It
/// excludes OS names, filesystem paths, timestamps, row IDs and presentation
/// state so byte equality is a meaningful cross-platform acceptance gate.
void main(List<String> arguments) {
  final outputPath = arguments.isEmpty
      ? 'build/p9-final-acceptance/p9-semantic-parity.json'
      : arguments.single;
  final fixture = _fixture();
  const service = ApartmentCandidateSetService();
  final cases = <Map<String, Object?>>[];

  for (final entry in _qualificationRequests().entries) {
    final generated = service.generate(
      input: entry.value,
      target: fixture.target,
      project: fixture.project,
    );
    if (!generated.accepted) {
      final codes = generated.failures.map((failure) => failure.code).join(',');
      throw StateError('P9 parity fixture ${entry.key} rejected: $codes');
    }

    final set = generated.candidateSet!;
    final selected = set.recommendedCandidate;
    final geometry = selected.rankedCandidate.candidate;
    cases.add(<String, Object?>{
      'case': entry.key,
      'intentFingerprint': set.request.intentFingerprint,
      'catalogVersion': set.catalogVersion,
      'generatorVersion': set.generatorVersion,
      'candidateSetFingerprint': set.candidateSetFingerprint,
      'orderedCandidateFingerprints': <String>[
        for (final candidate in set.candidates) candidate.candidateFingerprint,
      ],
      'selectedCandidateFingerprint': selected.candidateFingerprint,
      'selectedGeometryFingerprint': geometry.geometryFingerprint,
      'openingIntents': <String>[
        for (final opening in geometry.openingIntents)
          _openingSerialization(opening),
      ],
      'vectorSceneFingerprint': selected.scene.sceneFingerprint,
      'vectorSourceGeometryFingerprint':
          selected.scene.sourceGeometryFingerprint,
    });
  }

  final artifact = <String, Object?>{
    'schema': 'p9.13-semantic-parity-v1',
    'cases': cases,
  };
  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(artifact));
  stdout.writeln('P9.13 semantic parity: ${cases.length} cases -> $outputPath');
}

String _openingSerialization(OpeningIntent opening) => <String>[
      opening.kind.name,
      opening.fromSpaceKey ?? '-',
      opening.toSpaceKey ?? '-',
      opening.hostSegment.stableKey,
    ].join('|');

Map<String, ApartmentRequestInput> _qualificationRequests() {
  final requests = <String, ApartmentRequestInput>{
    'golden-journey-3r-78.5m2': const ApartmentRequestInput(
      habitableRoomCount: 3,
      approximateAreaDm2: 7850,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 1,
      balconyKind: ApartmentBalconyKind.loggia,
      kitchenMode: ApartmentKitchenMode.kitchenLiving,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    ),
  };

  for (var roomCount = 1; roomCount <= 10; roomCount++) {
    requests['representative-$roomCount-room'] = ApartmentRequestInput(
      habitableRoomCount: roomCount,
      approximateAreaDm2: _representativeArea(roomCount),
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 0,
      balconyKind: ApartmentBalconyKind.none,
      kitchenMode: ApartmentKitchenMode.separate,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );
  }
  return requests;
}

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
  final projectId = ProjectId('p9-p913-parity-project');
  final siteId = SiteId('p9-p913-parity-site');
  final buildingId = BuildingId('p9-p913-parity-building');
  final levelId = LevelId('p9-p913-parity-level');
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
