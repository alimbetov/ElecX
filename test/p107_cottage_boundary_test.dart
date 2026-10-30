import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/building/building_common_core_composition.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/building_level_stack_generator.dart';
import 'package:elecx/src/application/project/wizard/building/cottage_composition.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P10.7 cottage level boundaries', () {
    test('single above-ground level needs no vertical core or slab', () {
      final fixture = _BoundaryFixture('single');
      final parameters = fixture.parameters(
        levelStack: const BuildingLevelStackGenerator().residentialParameters(
          includeRoof: false,
        ),
        commonCore: CommonCoreParameters.v2(
          stairCount: 0,
          liftCount: 0,
          serviceShaftCount: 0,
          electricalRiserCount: 0,
          telecomRiserCount: 0,
          corridorWidthMm: 1600,
          serviceSpacePolicy: const CommonServiceSpacePolicy(
            includeCommonHall: true,
            includeElevatorHall: false,
            includeElectricalRoomCandidate: true,
            includeTelecomRoomCandidate: false,
            includeFireControlRoomCandidate: false,
            includeUtilityRoomCandidate: false,
          ),
        ),
      );
      final command = CottageCompositionCommand.create(
        project: fixture.project,
        compositionKey: 'cottage.single',
        parameters: parameters,
        layout: fixture.layout,
      );
      final session = ProjectMutationSession(fixture.project);
      final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10710)),
      );

      final preview = port.preview(command);
      expect(preview.preview.candidate.stores.buildings, hasLength(1));
      expect(preview.preview.candidate.stores.levels, hasLength(1));
      expect(preview.preview.candidate.stores.slabs, isEmpty);
      expect(preview.preview.candidate.stores.verticalCores, isEmpty);
      expect(preview.preview.candidate.stores.spaces, isNotEmpty);
      expect(session.current.stores.buildings, isEmpty);

      port.commitPreview(preview);
      final level = session.current.stores.levels.values.single;
      expect(level.kind, ProjectLevelKind.ground);
      expect(session.current.stores.slabs, isEmpty);
      expect(session.current.stores.verticalCores, isEmpty);
      expect(level.spaceIds, isNotEmpty);
    });

    test('optional technical and roof roles preserve physical core continuity',
        () {
      final fixture = _BoundaryFixture('technical');
      final parameters = fixture.parameters(
        levelStack: const BuildingLevelStackGenerator().residentialParameters(
          technicalLevels: 1,
          includeRoof: true,
          technicalHeightMm: 2800,
          roofHeightMm: 2600,
        ),
        commonCore: CommonCoreParameters.v2(
          stairCount: 1,
          liftCount: 0,
          serviceShaftCount: 0,
          electricalRiserCount: 0,
          telecomRiserCount: 0,
          corridorWidthMm: 1600,
          serviceSpacePolicy: const CommonServiceSpacePolicy(
            includeCommonHall: true,
            includeElevatorHall: false,
            includeElectricalRoomCandidate: false,
            includeTelecomRoomCandidate: false,
            includeFireControlRoomCandidate: false,
            includeUtilityRoomCandidate: false,
          ),
        ),
      );
      final session = ProjectMutationSession(fixture.project);
      final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10711)),
      );
      final command = CottageCompositionCommand.create(
        project: session.current,
        compositionKey: 'cottage.technical',
        parameters: parameters,
        layout: fixture.layout,
      );

      port.commitPreview(port.preview(command));
      expect(session.current.stores.levels, hasLength(3));
      expect(session.current.stores.slabs, hasLength(2));
      expect(session.current.stores.verticalCores, hasLength(1));

      final technical = session.current.stores.levels.values.singleWhere(
        (level) => level.kind == ProjectLevelKind.technical,
      );
      final roof = session.current.stores.levels.values.singleWhere(
        (level) => level.kind == ProjectLevelKind.roof,
      );
      final stair = session.current.stores.verticalCores.values.single;

      expect(technical.spaceIds, isNotEmpty);
      expect(roof.spaceIds, isEmpty);
      expect(stair.usage, VerticalCoreUsage.stairwell);
      expect(stair.levelIds, hasLength(2));
      expect(stair.hostSpaceIdsByLevel.containsKey(technical.id), isTrue);
      expect(stair.levelIds.contains(roof.id), isFalse);
    });
  });
}

final class _BoundaryFixture {
  _BoundaryFixture(String suffix)
      : projectId = ProjectId('project-p107-$suffix'),
        siteId = SiteId('site-p107-$suffix');

  final ProjectId projectId;
  final SiteId siteId;

  BuildingGenerationParameters parameters({
    required LevelStackParameters levelStack,
    required CommonCoreParameters commonCore,
  }) =>
      BuildingGenerationParameters(
        kind: BuildingCompositionKind.detachedHouse,
        siteId: siteId,
        displayName: 'Boundary Cottage',
        placement: BuildingSitePlacement(
          xMm: 0,
          yMm: 0,
          orientation: ProjectEngineeringNorth.fromDegrees(0),
        ),
        levelStack: levelStack,
        commonCore: commonCore,
        serviceAnchors: ServiceAnchorParameters(),
      );

  CottageCompositionLayout get layout => CottageCompositionLayout(
        footprintWidthMm: 10000,
        footprintDepthMm: 8000,
        commonCore: CommonCoreLayoutParameters(
          originXmm: 500,
          originYmm: 3000,
          corridorLengthMm: 8000,
        ),
      );

  ProjectAggregateRoot get project => ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(
          sites: {
            siteId: ProjectSiteEntity(
              id: siteId,
              name: 'Boundary Site',
              buildingIds: const [],
            ),
          },
        ),
      );
}
