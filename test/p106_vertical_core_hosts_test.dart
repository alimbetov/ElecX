import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:elecx/src/domain/vertical_core_project_validation.dart';
import 'package:elecx/src/serialization/project/common_core_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P10.6 vertical-core host semantics', () {
    test('architectural core requires one canonical host per served LevelId', () {
      final fixture = _Fixture();

      expect(
        () => fixture.core(
          usage: VerticalCoreUsage.electricalRiser,
          hosts: {fixture.level1Id: fixture.host1Id},
        ),
        throwsArgumentError,
      );
    });

    test('host validation rejects a SpaceId owned by another level', () {
      final fixture = _Fixture();
      final core = fixture.core(
        usage: VerticalCoreUsage.telecomRiser,
        hosts: {
          fixture.level1Id: fixture.host1Id,
          fixture.level2Id: fixture.host2Id,
        },
      );

      final issues = VerticalCoreProjectValidator.validate(
        verticalCores: {core.id: core},
        buildingExists: (_) => true,
        levelBuildingResolver: (_) => fixture.buildingId,
        spaceLevelResolver: (spaceId) =>
            spaceId == fixture.host1Id ? fixture.level2Id : fixture.level2Id,
      );

      expect(
        issues.map((issue) => issue.code),
        contains(VerticalCoreProjectIssueCode.hostSpaceLevelMismatch),
      );
    });

    test('schema v16 preserves typed usage and LevelId to SpaceId hosts', () {
      final fixture = _Fixture();
      final snapshot = fixture.snapshot();
      const codec = CommonCoreAwareCanonicalProjectDocumentCodec();

      final document = codec.encode(snapshot);
      final reopened = codec.decode(document);
      final core = reopened.aggregate.stores.verticalCores[fixture.coreId]!;

      expect(document.schemaVersion, 16);
      expect(core.usage, VerticalCoreUsage.electricalRiser);
      expect(core.hostSpaceIdsByLevel, {
        fixture.level1Id: fixture.host1Id,
        fixture.level2Id: fixture.host2Id,
      });
    });
  });
}

final class _Fixture {
  final ProjectId projectId = ProjectId('project-p106');
  final SiteId siteId = SiteId('site-p106');
  final BuildingId buildingId = BuildingId('building-p106');
  final LevelId level1Id = LevelId('level-p106-01');
  final LevelId level2Id = LevelId('level-p106-02');
  final SpaceId host1Id = SpaceId('space-riser-01');
  final SpaceId host2Id = SpaceId('space-riser-02');
  final VerticalCoreId coreId = VerticalCoreId('core-p106');

  ProjectVerticalCore core({
    VerticalCoreUsage usage = VerticalCoreUsage.unspecified,
    Map<LevelId, SpaceId> hosts = const {},
  }) =>
      ProjectVerticalCore(
        id: coreId,
        buildingId: buildingId,
        kind: VerticalCoreKind.riser,
        usage: usage,
        hostSpaceIdsByLevel: hosts,
        levelIds: [level1Id, level2Id],
        footprint: const [
          BoundaryPointMm(xMm: 1000, yMm: 1000),
          BoundaryPointMm(xMm: 1400, yMm: 1000),
          BoundaryPointMm(xMm: 1400, yMm: 1400),
          BoundaryPointMm(xMm: 1000, yMm: 1400),
        ],
        name: 'Electrical riser',
      );

  ProjectSnapshot snapshot() {
    final coreValue = core(
      usage: VerticalCoreUsage.electricalRiser,
      hosts: {
        level1Id: host1Id,
        level2Id: host2Id,
      },
    );
    final aggregate = ProjectAggregateRoot(
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
            levelIds: [level1Id, level2Id],
          ),
        },
        levels: {
          level1Id: ProjectLevelEntity(
            id: level1Id,
            buildingId: buildingId,
            name: 'Level 1',
            levelNumber: 1,
            elevationMm: 0,
            spaceIds: [host1Id],
          ),
          level2Id: ProjectLevelEntity(
            id: level2Id,
            buildingId: buildingId,
            name: 'Level 2',
            levelNumber: 2,
            elevationMm: 3200,
            spaceIds: [host2Id],
          ),
        },
        spaces: {
          host1Id: ProjectSpaceEntity(
            id: host1Id,
            levelId: level1Id,
            name: 'Electrical riser L1',
            type: ProjectSpaceType.shaft,
            usage: SpaceUsage.commonArea,
          ),
          host2Id: ProjectSpaceEntity(
            id: host2Id,
            levelId: level2Id,
            name: 'Electrical riser L2',
            type: ProjectSpaceType.shaft,
            usage: SpaceUsage.commonArea,
          ),
        },
        verticalCores: {coreId: coreValue},
      ),
    );
    final instant = DateTime.utc(2026, 10, 29, 8);
    return ProjectSnapshot(
      aggregate: aggregate,
      name: 'P10.6 qualification',
      createdAt: instant,
      updatedAt: instant,
    );
  }
}
