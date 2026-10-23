import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/serialization/project/structural_semantics_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/vertical_core_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = StructuralSemanticsAwareCanonicalProjectDocumentCodec();

  test('schema v11 round-trip preserves P4 structural semantics', () {
    final snapshot = _snapshot(
      levelKind: ProjectLevelKind.technical,
      floorToFloorHeightMm: 4200,
      zoneKind: ProjectStructuralZoneKind.technical,
      spaceType: ProjectSpaceType.technicalRoom,
      usage: SpaceUsage.electricalRoom,
    );

    final document = codec.encode(snapshot);
    final restored = codec.decode(document);

    expect(document.schemaVersion, 11);
    final level = restored.aggregate.index.level(LevelId('level-1'))!;
    final zone = restored.aggregate.index.zone(ZoneId('zone-1'))!;
    final space = restored.aggregate.index.space(SpaceId('space-1'))!;

    expect(level.kind, ProjectLevelKind.technical);
    expect(level.floorToFloorHeightMm, 4200);
    expect(zone.kind, ProjectStructuralZoneKind.technical);
    expect(space.type, ProjectSpaceType.technicalRoom);
    expect(space.usage, SpaceUsage.electricalRoom);
  });

  test('v10 migration preserves level semantics without inventing zone/type', () {
    const v10 = VerticalCoreAwareCanonicalProjectDocumentCodec();
    final source = _snapshot(
      levelKind: ProjectLevelKind.roof,
      floorToFloorHeightMm: 3600,
      zoneKind: ProjectStructuralZoneKind.service,
      spaceType: ProjectSpaceType.shaft,
      usage: SpaceUsage.serviceShaft,
    );
    final legacyDocument = v10.encode(source);

    final restored = codec.decode(legacyDocument);
    final level = restored.aggregate.index.level(LevelId('level-1'))!;
    final zone = restored.aggregate.index.zone(ZoneId('zone-1'))!;
    final space = restored.aggregate.index.space(SpaceId('space-1'))!;

    expect(legacyDocument.schemaVersion, 10);
    expect(level.kind, ProjectLevelKind.roof);
    expect(level.floorToFloorHeightMm, 3600);
    expect(zone.kind, ProjectStructuralZoneKind.unknown);
    expect(space.type, ProjectSpaceType.unknown);
    expect(space.usage, SpaceUsage.serviceShaft);
  });
}

ProjectSnapshot _snapshot({
  required ProjectLevelKind levelKind,
  required int floorToFloorHeightMm,
  required ProjectStructuralZoneKind zoneKind,
  required ProjectSpaceType spaceType,
  required SpaceUsage usage,
}) {
  final projectId = ProjectId('project');
  final siteId = SiteId('site');
  final buildingId = BuildingId('building');
  final levelId = LevelId('level-1');
  final zoneId = ZoneId('zone-1');
  final spaceId = SpaceId('space-1');

  final aggregate = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(7),
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
          name: 'Technical level',
          levelNumber: 1,
          elevationMm: 0,
          kind: levelKind,
          floorToFloorHeightMm: floorToFloorHeightMm,
          zoneIds: [zoneId],
          spaceIds: [spaceId],
        ),
      },
      zones: {
        zoneId: ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: levelId,
          name: 'Engineering zone',
          kind: zoneKind,
          spaceIds: [spaceId],
        ),
      },
      spaces: {
        spaceId: ProjectSpaceEntity(
          id: spaceId,
          levelId: levelId,
          name: 'Electrical room',
          type: spaceType,
          usage: usage,
        ),
      },
    ),
  );
  final now = DateTime.utc(2026, 10, 23);
  return ProjectSnapshot(
    aggregate: aggregate,
    name: 'P4 structural semantics',
    createdAt: now,
    updatedAt: now,
  );
}
