import 'dart:math';

import 'package:elecx/src/application/project/project_level_commands.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/building/building_common_core_composition.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:elecx/src/serialization/project/common_core_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'P10-Q08 generated core survives save reopen renumber undo and redo',
    () {
      final fixture = _P106LifecycleFixture();
      final session = ProjectMutationSession(fixture.project);
      final port = SharedProjectWizardMutationPort(
        mutations: session,
        idFactory: SecureRandomEntityIdFactory(random: Random(10680)),
      );
      final command = BuildingCommonCoreCompositionCommand.create(
        project: session.current,
        target: fixture.target(session.current.version),
        compositionKey: 'q08.core',
        parameters: fixture.parameters,
        layout: fixture.layout,
        servedLevelIds: fixture.levelIds,
      );
      port.commitPreview(port.preview(command));

      final generated = session.current.stores.verticalCores.values.singleWhere(
        (core) => core.usage == VerticalCoreUsage.electricalRiser,
      );
      final coreId = generated.id;
      final hosts = Map<LevelId, SpaceId>.of(generated.hostSpaceIdsByLevel);
      final servedLevels = generated.levelIds.toSet();

      const codec = CommonCoreAwareCanonicalProjectDocumentCodec();
      final timestamp = DateTime.utc(2026, 10, 29, 10);
      final document = codec.encode(
        ProjectSnapshot(
          aggregate: session.current,
          name: 'P10 Q08',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
      expect(
        document.schemaVersion,
        CommonCoreAwareCanonicalProjectDocumentCodec.schemaVersion,
      );
      final reopened = codec.decode(document);
      final reopenedCore = reopened.aggregate.stores.verticalCores[coreId]!;
      expect(reopenedCore.levelIds, servedLevels);
      expect(reopenedCore.hostSpaceIdsByLevel, hosts);
      expect(reopenedCore.usage, VerticalCoreUsage.electricalRiser);

      final reopenedSession = ProjectMutationSession(reopened.aggregate);
      final originalNumber =
          reopenedSession.current.stores.levels[fixture.level1Id]!.levelNumber;
      final renumber = reopenedSession.commit(
        ProjectMutationRequest(
          expectedVersion: reopenedSession.current.version,
          command: RenumberLevelCommand(
            levelId: fixture.level1Id,
            levelNumber: 101,
          ),
        ),
      );
      expect(renumber, isNotNull);
      expect(
        reopenedSession.current.stores.levels[fixture.level1Id]!.levelNumber,
        101,
      );
      _expectCoreIdentity(
        reopenedSession.current,
        coreId: coreId,
        hosts: hosts,
        servedLevels: servedLevels,
      );

      final undo = reopenedSession.undo(reopenedSession.current.version);
      expect(undo, isNotNull);
      expect(
        reopenedSession.current.stores.levels[fixture.level1Id]!.levelNumber,
        originalNumber,
      );
      _expectCoreIdentity(
        reopenedSession.current,
        coreId: coreId,
        hosts: hosts,
        servedLevels: servedLevels,
      );

      final redo = reopenedSession.redo(reopenedSession.current.version);
      expect(redo, isNotNull);
      expect(
        reopenedSession.current.stores.levels[fixture.level1Id]!.levelNumber,
        101,
      );
      _expectCoreIdentity(
        reopenedSession.current,
        coreId: coreId,
        hosts: hosts,
        servedLevels: servedLevels,
      );
    },
  );
}

void _expectCoreIdentity(
  ProjectAggregateRoot project, {
  required VerticalCoreId coreId,
  required Map<LevelId, SpaceId> hosts,
  required Set<LevelId> servedLevels,
}) {
  final core = project.stores.verticalCores[coreId];
  expect(core, isNotNull);
  expect(core!.id, coreId);
  expect(core.levelIds, servedLevels);
  expect(core.hostSpaceIdsByLevel, hosts);
  expect(core.usage, VerticalCoreUsage.electricalRiser);
}

final class _P106LifecycleFixture {
  final ProjectId projectId = ProjectId('project-p106-q08');
  final SiteId siteId = SiteId('site-p106-q08');
  final BuildingId buildingId = BuildingId('building-p106-q08');
  final LevelId level1Id = LevelId('level-p106-q08-01');
  final LevelId level2Id = LevelId('level-p106-q08-02');
  final SlabId slabId = SlabId('slab-p106-q08-01');

  List<LevelId> get levelIds => [level1Id, level2Id];

  CommonCoreParameters get parameters => CommonCoreParameters.v2(
        stairCount: 0,
        liftCount: 0,
        serviceShaftCount: 0,
        electricalRiserCount: 1,
        telecomRiserCount: 0,
        corridorWidthMm: 1800,
        serviceSpacePolicy: const CommonServiceSpacePolicy.none(),
      );

  CommonCoreLayoutParameters get layout => CommonCoreLayoutParameters(
        originXmm: 10000,
        originYmm: 20000,
        corridorLengthMm: 12000,
      );

  BuildingWizardTarget target(LocalProjectVersion version) =>
      BuildingWizardTarget(
        projectId: projectId,
        siteId: siteId,
        buildingId: buildingId,
        baseVersion: version,
      );

  ProjectAggregateRoot get project => ProjectAggregateRoot(
        id: projectId,
        siteId: siteId,
        version: LocalProjectVersion(0),
        stores: ProjectEntityStores(
          sites: {
            siteId: ProjectSiteEntity(
              id: siteId,
              name: 'Q08 Site',
              buildingIds: [buildingId],
            ),
          },
          buildings: {
            buildingId: ProjectBuildingEntity(
              id: buildingId,
              siteId: siteId,
              name: 'Q08 Building',
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
          slabs: {
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
          },
        ),
      );
}
