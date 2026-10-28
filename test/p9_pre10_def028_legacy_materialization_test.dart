import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/boundary_edge_identity_registry.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/building_composition.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:elecx/src/features/editor/canonical_editor_legacy_bootstrap.dart';
import 'package:elecx/src/features/editor/canonical_editor_runtime_cutover.dart';
import 'package:elecx/src/features/editor/canonical_editor_screen_cutover_binding.dart';
import 'package:elecx/src/features/editor/canonical_editor_structural_materializer.dart';
import 'package:elecx/src/features/editor/canonical_editor_workspace_adapter.dart';
import 'package:elecx/src/features/editor/canonical_legacy_identity_codec.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE10-CQ28 canonical structural materialization/rebind', () {
    test(
      'new canonical apartment materializes, rebinds and round-trips',
      () {
        final fixture = _fixture();
        fixture.session.selectZone(_zoneId);
        final binding = CanonicalEditorScreenCutoverBinding(
          coordinator: fixture.coordinator,
        )..start(pushInitialCanonicalState: false);
        addTearDown(binding.dispose);

        final first = binding.pushCanonicalToEditor();

        expect(first.canOpen, isTrue);
        expect(
          fixture.binding.legacyZoneIds[_zoneId],
          CanonicalLegacyIdentityCodec.encodeZoneId(_zoneId),
        );
        expect(
          fixture.binding.legacySpaceIds[_livingId],
          CanonicalLegacyIdentityCodec.encodeSpaceId(_livingId),
        );
        expect(
          fixture.binding.legacySpaceIds[_corridorId],
          CanonicalLegacyIdentityCodec.encodeSpaceId(_corridorId),
        );
        expect(fixture.workspace.activeLevel!.level.spaces, hasLength(3));
        expect(fixture.workspace.activeLevel!.zones, hasLength(1));
        expect(
          fixture.workspace.selectedZoneId,
          CanonicalLegacyIdentityCodec.encodeZoneId(_zoneId),
        );
        expect(
          fixture.workspace.editor.selectedSpaceId,
          isNull,
          reason: 'P9 Apply selects the new Zone, not an arbitrary first room.',
        );

        final beforeSpaceCount = fixture.workspace.activeLevel!.level.spaces.length;
        final beforeZoneCount = fixture.workspace.activeLevel!.zones.length;
        final second = binding.pushCanonicalToEditor();
        expect(second.canOpen, isTrue);
        expect(
          fixture.workspace.activeLevel!.level.spaces,
          hasLength(beforeSpaceCount),
        );
        expect(fixture.workspace.activeLevel!.zones, hasLength(beforeZoneCount));

        fixture.session.selectRoom(_livingId);
        binding.pushCanonicalToEditor();
        final livingLegacyId =
            CanonicalLegacyIdentityCodec.encodeSpaceId(_livingId);
        expect(fixture.workspace.editor.selectedSpaceId, livingLegacyId);

        // Detach the screen listener so the explicit pull below is the only
        // legacy -> canonical transition under test.
        binding.dispose();
        final corridorLegacyId =
            CanonicalLegacyIdentityCodec.encodeSpaceId(_corridorId);
        fixture.workspace.editor.selectSpace(corridorLegacyId);
        final pulled = fixture.coordinator.pullLegacyToCanonical();
        expect(pulled, isNotNull);
        expect(fixture.session.navigation.selectedZoneId, _zoneId);
        expect(fixture.session.navigation.selectedSpaceId, _corridorId);

        final document = EditorProjectDocument.capture(
          fixture.workspace,
          metadata: EditorProjectMetadata.create(
            projectId: 'pre10-def028-project',
            projectName: 'PRE10 DEF028',
            now: DateTime.utc(2026, 10, 28),
          ),
        );
        final reopened = CanonicalEditorLegacyBootstrap.create(document);
        expect(
          reopened.binding.legacyZoneIds[_zoneId],
          CanonicalLegacyIdentityCodec.encodeZoneId(_zoneId),
        );
        expect(
          reopened.binding.legacySpaceIds[_livingId],
          livingLegacyId,
        );
        expect(
          reopened.binding.legacySpaceIds[_corridorId],
          corridorLegacyId,
        );
      },
    );

    test('missing canonical boundary fails closed without partial rebind', () {
      final fixture = _fixture(includeCorridorBoundary: false);
      fixture.session.selectZone(_zoneId);
      final binding = CanonicalEditorScreenCutoverBinding(
        coordinator: fixture.coordinator,
      )..start(pushInitialCanonicalState: false);
      addTearDown(binding.dispose);
      final beforeSpaceIds = fixture.workspace.activeLevel!.level.spaces
          .map((space) => space.id)
          .toList(growable: false);

      final result = binding.pushCanonicalToEditor();

      expect(
        result.status,
        CanonicalEditorMaterializationStatus.blockedMissingGeometry,
      );
      expect(fixture.binding.legacyZoneIds.containsKey(_zoneId), isFalse);
      expect(fixture.binding.legacySpaceIds.containsKey(_livingId), isFalse);
      expect(fixture.binding.legacySpaceIds.containsKey(_corridorId), isFalse);
      expect(
        fixture.workspace.activeLevel!.level.spaces
            .map((space) => space.id)
            .toList(growable: false),
        beforeSpaceIds,
      );
      expect(fixture.workspace.activeLevel!.zones, isEmpty);
    });
  });
}

final _siteId = SiteId('pre10-def028-site');
final _buildingId = BuildingId('pre10-def028-building');
final _levelId = LevelId('pre10-def028-level');
final _existingId = SpaceId('pre10-def028-existing');
final _zoneId = ZoneId('pre10-def028-apartment');
final _livingId = SpaceId('pre10-def028-living');
final _corridorId = SpaceId('pre10-def028-corridor');

final class _Fixture {
  const _Fixture({
    required this.session,
    required this.workspace,
    required this.binding,
    required this.coordinator,
  });

  final ProjectStructureAuthoringSession session;
  final EditorBuildingWorkspace workspace;
  final CanonicalEditorWorkspaceBinding binding;
  final CanonicalEditorRuntimeCutoverCoordinator coordinator;
}

_Fixture _fixture({bool includeCorridorBoundary = true}) {
  final project = _project(includeCorridorBoundary: includeCorridorBoundary);
  final session = ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(28028)),
  );
  final workspace = _workspace();
  final binding = CanonicalEditorWorkspaceBinding(
    buildingId: _buildingId,
    legacyBuildingId: 'legacy-building',
    legacyLevelIds: <LevelId, String>{_levelId: 'legacy-level'},
    legacySpaceIds: <SpaceId, String>{_existingId: 'legacy-existing'},
  );
  final coordinator = CanonicalEditorRuntimeCutoverCoordinator(
    session: session,
    adapter: CanonicalEditorWorkspaceAdapter(
      workspace: workspace,
      binding: binding,
    ),
    materializer: const CanonicalEditorStructuralMaterializer(),
  );
  return _Fixture(
    session: session,
    workspace: workspace,
    binding: binding,
    coordinator: coordinator,
  );
}

ProjectAggregateRoot _project({required bool includeCorridorBoundary}) {
  final boundaries = <SpaceId, SpaceBoundaryTopology>{
    _existingId: _rectangleTopology(_existingId, 0, 0, 2000, 2000),
    _livingId: _rectangleTopology(_livingId, 2500, 0, 6500, 4000),
    if (includeCorridorBoundary)
      _corridorId: _rectangleTopology(_corridorId, 2500, 4000, 6500, 5200),
  };
  final identity = const BoundaryEdgeIdentityRegistry.empty()
      .registerActiveBoundaries(boundaries);
  return ProjectAggregateRoot(
    id: ProjectId('pre10-def028-project'),
    siteId: _siteId,
    version: LocalProjectVersion(0),
    engineeringMetadata: ProjectEngineeringMetadata(
      boundaryEdgeIdentityRegistry: identity,
    ),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        _siteId: ProjectSiteEntity(
          id: _siteId,
          name: 'Site',
          buildingIds: <BuildingId>[_buildingId],
        ),
      },
      buildings: <BuildingId, ProjectBuildingEntity>{
        _buildingId: ProjectBuildingEntity(
          id: _buildingId,
          siteId: _siteId,
          name: 'Building',
          levelIds: <LevelId>[_levelId],
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        _levelId: ProjectLevelEntity(
          id: _levelId,
          buildingId: _buildingId,
          name: 'Level 1',
          levelNumber: 1,
          elevationMm: 0,
          kind: ProjectLevelKind.residential,
          zoneIds: <ZoneId>[_zoneId],
          spaceIds: <SpaceId>[_existingId, _livingId, _corridorId],
        ),
      },
      zones: <ZoneId, ProjectStructuralZoneEntity>{
        _zoneId: ProjectStructuralZoneEntity(
          id: _zoneId,
          levelId: _levelId,
          name: 'Apartment 28',
          kind: ProjectStructuralZoneKind.apartment,
          spaceIds: <SpaceId>[_livingId, _corridorId],
        ),
      },
      spaces: <SpaceId, ProjectSpaceEntity>{
        _existingId: ProjectSpaceEntity(
          id: _existingId,
          levelId: _levelId,
          name: 'Existing room',
          type: ProjectSpaceType.room,
        ),
        _livingId: ProjectSpaceEntity(
          id: _livingId,
          levelId: _levelId,
          name: 'Living room',
          type: ProjectSpaceType.room,
        ),
        _corridorId: ProjectSpaceEntity(
          id: _corridorId,
          levelId: _levelId,
          name: 'Corridor',
          type: ProjectSpaceType.corridor,
        ),
      },
      boundaries: boundaries,
    ),
  );
}

EditorBuildingWorkspace _workspace() {
  final existingBoundary = MmPolygon.rectangle(
    const MmPoint(0, 0),
    const MmPoint(2000, 2000),
  );
  final existing = EngineeringSpace(
    id: 'legacy-existing',
    name: 'Existing room',
    type: SpaceType.room,
    boundary: existingBoundary,
    referenceFrame: RoomReferenceFrame(origin: existingBoundary.bounds.center),
  );
  final geometry = BuildingLevel(
    id: 'legacy-level',
    name: 'Level 1',
    elevationMm: 0,
    spaces: <EngineeringSpace>[existing],
  );
  final composedLevel = ComposedBuildingLevel(
    level: geometry,
    levelNumber: 1,
    kind: BuildingLevelKind.residential,
  );
  final buildingGeometry = Building(
    id: 'legacy-building',
    name: 'Building',
    levels: <BuildingLevel>[geometry],
  );
  final building = ComposedBuilding(
    building: buildingGeometry,
    levels: <ComposedBuildingLevel>[composedLevel],
  );
  final editor = EditorController.restored(level: geometry, openings: const []);
  return EditorBuildingWorkspace(
    editor: editor,
    building: building,
    site: ComposedProjectSite(
      site: ProjectSite(
        id: 'legacy-site',
        name: 'Site',
        buildings: <Building>[buildingGeometry],
      ),
    ),
    initialLevelNumber: 1,
  );
}

SpaceBoundaryTopology _rectangleTopology(
  SpaceId spaceId,
  int left,
  int bottom,
  int right,
  int top,
) {
  final points = <BoundaryPointMm>[
    BoundaryPointMm(xMm: left, yMm: bottom),
    BoundaryPointMm(xMm: right, yMm: bottom),
    BoundaryPointMm(xMm: right, yMm: top),
    BoundaryPointMm(xMm: left, yMm: top),
  ];
  final edgeIds = <BoundaryEdgeId>[
    for (var index = 0; index < points.length; index++)
      BoundaryEdgeId('${spaceId.value}-edge-$index'),
  ];
  final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{
    for (var index = 0; index < edgeIds.length; index++)
      edgeIds[index]: ProjectBoundaryEdge(
        id: edgeIds[index],
        spaceId: spaceId,
        start: points[index],
        end: points[(index + 1) % points.length],
      ),
  };
  final topology = SpaceBoundaryTopology(
    spaceId: spaceId,
    orderedEdgeIds: edgeIds,
    edges: edges,
  );
  topology.validateOrThrow();
  return topology;
}
