import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregate rejects hosted metadata without owning boundary topology', () {
    final siteId = SiteId('site-root');
    final buildingId = BuildingId('building-a');
    final levelId = LevelId('level-1');
    final spaceId = SpaceId('space-1');
    final edgeId = BoundaryEdgeId('retired-edge');
    final objectKey = BoundaryHostedObjectRegistry.componentObjectKey('cmp-1');

    expect(
      () => ProjectAggregateRoot(
        id: ProjectId('project-1'),
        siteId: siteId,
        version: LocalProjectVersion(0),
        engineeringMetadata: ProjectEngineeringMetadata(
          boundaryHostedObjectRegistry: BoundaryHostedObjectRegistry({
            objectKey: BoundaryHostedReference.point(
              objectKey: objectKey,
              objectKind: BoundaryHostedObjectKind.component,
              host: BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId),
              offsetMm: 100,
            ),
          }),
        ),
        stores: ProjectEntityStores(
          sites: {
            siteId: ProjectSiteEntity(
              id: siteId,
              name: 'Site',
              buildingIds: [buildingId],
            ),
          },
          buildings: {
            buildingId: ProjectBuildingEntity(
              id: buildingId,
              siteId: siteId,
              name: 'Building',
              levelIds: [levelId],
            ),
          },
          levels: {
            levelId: ProjectLevelEntity(
              id: levelId,
              buildingId: buildingId,
              name: 'Floor 1',
              levelNumber: 1,
              elevationMm: 0,
              spaceIds: [spaceId],
            ),
          },
          spaces: {
            spaceId: ProjectSpaceEntity(
              id: spaceId,
              levelId: levelId,
              name: 'Room',
            ),
          },
        ),
      ),
      throwsA(
        isA<BoundaryHostedRegistryException>().having(
          (error) => error.code,
          'code',
          BoundaryHostedRegistryIssueCode.missingSpaceTopology,
        ),
      ),
    );
  });
}
