import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/building/building_common_core_composition.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P10.6B-D common/core composition', () {
    test('pure generator emits typed common, service and technical plan', () {
      final fixture = _P106CompositionFixture();
      final beforeSpaces = fixture.project.stores.spaces;
      final plan = const BuildingCommonCoreCompositionGenerator().generate(
        project: fixture.project,
        target: fixture.target,
        parameters: fixture.parameters,
        servedLevelIds: fixture.levelIds,
        layout: fixture.layout,
      );

      expect(fixture.project.stores.spaces, same(beforeSpaces));
      expect(plan.levelIds, fixture.levelIds);
      expect(
        plan.spaces.map((space) => space.usage),
        containsAll(<SpaceUsage>[
          SpaceUsage.corridor,
          SpaceUsage.commonHall,
          SpaceUsage.elevatorHall,
          SpaceUsage.stairwell,
          SpaceUsage.elevatorShaft,
          SpaceUsage.serviceShaft,
          SpaceUsage.electricalRiser,
          SpaceUsage.telecomRiser,
          SpaceUsage.electricalRoom,
          SpaceUsage.telecomRoom,
          SpaceUsage.fireControlRoom,
          SpaceUsage.utilityRoom,
        ]),
      );
      expect(
        plan.verticalCores.map((core) => core.usage).toSet(),
        {
          VerticalCoreUsage.stairwell,
          VerticalCoreUsage.elevatorShaft,
          VerticalCoreUsage.serviceShaft,
          VerticalCoreUsage.electricalRiser,
          VerticalCoreUsage.telecomRiser,
        },
      );
      expect(plan.verticalAdjacencies, hasLength(5));
    });

    test('one reserved command materializes the complete canonical core graph',
        () {
      final fixture = _P106CompositionFixture();
      final session = ProjectMutationSession(fixture.project);
      final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10660)),
      );
      final command = fixture.command();

      final preview = port.preview(command);
      expect(session.current.stores.spaces, isEmpty);
      expect(session.current.stores.verticalCores, isEmpty);
      port.commitPreview(preview);
      final project = session.current;

      expect(session.undoDepth, 1);
      expect(project.stores.verticalCores, hasLength(5));
      expect(
        project.stores.spaces.values
            .where((space) => space.usage == SpaceUsage.corridor),
        hasLength(2),
      );
      expect(
        project.stores.zones.values.map((zone) => zone.kind).toSet(),
        containsAll({
          ProjectStructuralZoneKind.common,
          ProjectStructuralZoneKind.service,
          ProjectStructuralZoneKind.technical,
        }),
      );
      for (final core in project.stores.verticalCores.values) {
        expect(core.levelIds, fixture.levelIds.toSet());
        expect(core.hostSpaceIdsByLevel.keys.toSet(), fixture.levelIds.toSet());
      }
      expect(
        project.stores.adjacencies.values
            .where((value) => value.kind == SpaceAdjacencyKind.vertical),
        hasLength(5),
      );
      for (final boundary in project.stores.boundaries.values) {
        for (final edgeId in boundary.orderedEdgeIds) {
          expect(
            project.engineeringMetadata.boundaryEdgeIdentityRegistry
                .ownerOf(edgeId),
            boundary.spaceId,
          );
        }
      }

      final committedSpaceIds = project.stores.spaces.keys.toSet();
      final committedCoreIds = project.stores.verticalCores.keys.toSet();
      session.undo(session.current.version);
      expect(session.current.stores.spaces, isEmpty);
      expect(session.current.stores.verticalCores, isEmpty);
      session.redo(session.current.version);
      expect(session.current.stores.spaces.keys.toSet(), committedSpaceIds);
      expect(
        session.current.stores.verticalCores.keys.toSet(),
        committedCoreIds,
      );
    });

    test('legacy v1 input and missing physical continuity fail closed', () {
      final fixture = _P106CompositionFixture();
      const generator = BuildingCommonCoreCompositionGenerator();

      expect(
        () => generator.generate(
          project: fixture.project,
          target: fixture.target,
          parameters: CommonCoreParameters(
            stairCount: 1,
            liftCount: 0,
            serviceShaftCount: 0,
            corridorWidthMm: 1800,
          ),
          servedLevelIds: fixture.levelIds,
          layout: fixture.layout,
        ),
        throwsA(
          isA<BuildingCommonCoreCompositionException>().having(
            (error) => error.code,
            'code',
            'p10.common-core.contract-v2-required',
          ),
        ),
      );

      final withoutSlab = fixture.projectWith(slabs: const {});
      expect(
        () => generator.generate(
          project: withoutSlab,
          target: fixture.target,
          parameters: fixture.parameters,
          servedLevelIds: fixture.levelIds,
          layout: fixture.layout,
        ),
        throwsA(
          isA<BuildingCommonCoreCompositionException>().having(
            (error) => error.code,
            'code',
            'p10.common-core.physical-continuity-missing',
          ),
        ),
      );
    });
  });
}

final class _P106CompositionFixture {
  final ProjectId projectId = ProjectId('project-p106-composition');
  final SiteId siteId = SiteId('site-p106-composition');
  final BuildingId buildingId = BuildingId('building-p106-composition');
  final LevelId level1Id = LevelId('level-p106-composition-01');
  final LevelId level2Id = LevelId('level-p106-composition-02');
  final SlabId slabId = SlabId('slab-p106-composition-01');

  List<LevelId> get levelIds => [level1Id, level2Id];

  CommonCoreParameters get parameters => CommonCoreParameters.v2(
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

  CommonCoreLayoutParameters get layout => CommonCoreLayoutParameters(
        originXmm: 10000,
        originYmm: 20000,
        corridorLengthMm: 24000,
      );

  BuildingWizardTarget get target => BuildingWizardTarget(
        projectId: projectId,
        siteId: siteId,
        buildingId: buildingId,
        baseVersion: LocalProjectVersion(0),
      );

  ProjectAggregateRoot get project => projectWith(slabs: {
        slabId: ProjectSlab(
          id: slabId,
          buildingId: buildingId,
          kind: SlabKind.interLevel,
          belowLevelId: level1Id,
          aboveLevelId: level2Id,
          bottomElevationMm: 3000,
          thicknessMm: 200,
          materialId: 'concrete',
          footprint: const [
            BoundaryPointMm(xMm: 0, yMm: 0),
            BoundaryPointMm(xMm: 30000, yMm: 0),
            BoundaryPointMm(xMm: 30000, yMm: 30000),
            BoundaryPointMm(xMm: 0, yMm: 30000),
          ],
        ),
      });

  ProjectAggregateRoot projectWith({required Map<SlabId, ProjectSlab> slabs}) =>
      ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(
          sites: {
            siteId: ProjectSiteEntity(
              id: siteId,
              name: 'P10.6 Site',
              buildingIds: [buildingId],
            ),
          },
          buildings: {
            buildingId: ProjectBuildingEntity(
              id: buildingId,
              siteId: siteId,
              name: 'P10.6 Building',
              levelIds: levelIds,
            ),
          },
          levels: {
            level1Id: ProjectLevelEntity(
              id: level1Id,
              buildingId: buildingId,
              name: 'Level 1',
              levelNumber: 1,
              elevationMm: 0,
              kind: ProjectLevelKind.residential,
              floorToFloorHeightMm: 3200,
            ),
            level2Id: ProjectLevelEntity(
              id: level2Id,
              buildingId: buildingId,
              name: 'Level 2',
              levelNumber: 2,
              elevationMm: 3200,
              kind: ProjectLevelKind.residential,
              floorToFloorHeightMm: 3200,
            ),
          },
          slabs: slabs,
        ),
      );

  BuildingCommonCoreCompositionCommand command() =>
      BuildingCommonCoreCompositionCommand.create(
        project: project,
        target: target,
        compositionKey: 'residential.core',
        parameters: parameters,
        layout: layout,
        servedLevelIds: levelIds,
      );
}
