import '../../application/project/project_navigation_state.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/building_composition.dart';
import '../../domain/geometry.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import '../../domain/project_space_semantics.dart';
import '../../domain/site_outdoor_model.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_editor_structural_materializer.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'canonical_legacy_identity_codec.dart';
import 'editor_building_workspace.dart';

/// Production materializer that extends the established P9/P10 structural
/// projection with standalone canonical room support.
///
/// Structural Zones keep using [CanonicalEditorStructuralMaterializer]
/// unchanged. A selected Space without structural-zone membership is projected
/// only when it owns a valid canonical boundary and has an exact legacy room
/// representation. No geometry is inferred from legacy editor state.
final class CanonicalEditorProductionMaterializer
    implements CanonicalEditorRuntimeMaterializer {
  const CanonicalEditorProductionMaterializer();

  static const CanonicalEditorStructuralMaterializer _structural =
      CanonicalEditorStructuralMaterializer();
  static const ExistingBindingCanonicalEditorMaterializer _existing =
      ExistingBindingCanonicalEditorMaterializer();

  @override
  CanonicalEditorMaterializationResult inspect({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceBinding binding,
  }) {
    if (navigation.selectedZoneId != null ||
        navigation.selectedSpaceId == null) {
      return _structural.inspect(
        project: project,
        navigation: navigation,
        binding: binding,
      );
    }

    final existing = _existing.inspect(
      project: project,
      navigation: navigation,
      binding: binding,
    );
    if (existing.canOpen ||
        existing.status ==
            CanonicalEditorMaterializationStatus.blockedCanonicalMismatch ||
        existing.status !=
            CanonicalEditorMaterializationStatus.blockedMissingGeometry) {
      return existing;
    }

    final buildingId = navigation.activeBuildingId;
    final levelId = navigation.activeLevelId;
    final spaceId = navigation.selectedSpaceId!;
    if (buildingId == null ||
        levelId == null ||
        buildingId != binding.buildingId ||
        binding.legacyLevelIds[levelId] == null) {
      return existing;
    }

    final space = project.index.space(spaceId);
    if (space == null || space.levelId != levelId) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus.blockedCanonicalMismatch,
        entityId: spaceId,
        message: 'Selected standalone Space is outside the active Level.',
      );
    }
    if (project.index.structuralZoneBySpace[spaceId] != null) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus.blockedCanonicalMismatch,
        entityId: spaceId,
        message: 'A zoned Space must be materialized through its structural '
            'Zone path.',
      );
    }
    if (space.type != ProjectSpaceType.room) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: spaceId,
        message: 'Standalone production materialization currently supports '
            'canonical room Spaces only.',
      );
    }

    final topology = project.index.boundary(spaceId);
    if (topology == null || !_isValidTopology(topology)) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus.blockedMissingGeometry,
        entityId: spaceId,
        message: 'Standalone canonical Room has no valid boundary topology.',
      );
    }

    return CanonicalEditorMaterializationResult(
      status: CanonicalEditorMaterializationStatus.materializable,
      entityId: spaceId,
      message: 'Standalone canonical Room can be materialized into the legacy '
          'workspace.',
    );
  }

  @override
  CanonicalEditorMaterializationResult materialize({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceAdapter adapter,
  }) {
    if (navigation.selectedZoneId != null ||
        navigation.selectedSpaceId == null) {
      return _structural.materialize(
        project: project,
        navigation: navigation,
        adapter: adapter,
      );
    }

    final readiness = inspect(
      project: project,
      navigation: navigation,
      binding: adapter.binding,
    );
    if (!readiness.canMaterialize) return readiness;

    final levelId = navigation.activeLevelId!;
    final spaceId = navigation.selectedSpaceId!;
    final space = project.index.space(spaceId)!;
    final topology = project.index.boundary(spaceId)!;
    final legacyLevelId = adapter.binding.legacyLevelIds[levelId]!;

    if (adapter.workspace.building.building.id !=
        adapter.binding.legacyBuildingId) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: adapter.binding.buildingId,
        message: 'Bound legacy Building is not the active editor workspace.',
      );
    }

    ComposedBuildingLevel? legacyLevel;
    for (final candidate in adapter.workspace.building.levels) {
      if (candidate.level.id == legacyLevelId) {
        legacyLevel = candidate;
        break;
      }
    }
    if (legacyLevel == null) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: levelId,
        message: 'Bound legacy Level $legacyLevelId does not exist.',
      );
    }

    final legacySpaceId = CanonicalLegacyIdentityCodec.encodeSpaceId(spaceId);
    final collision = legacyLevel.level.spaces
            .any((candidate) => candidate.id == legacySpaceId) ||
        adapter.binding.canonicalSpaceIdForLegacy(legacySpaceId) != null;
    if (collision) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: spaceId,
        message: 'Encoded legacy Space identity collides with existing runtime '
            'state.',
      );
    }

    final vertices = <MmPoint>[
      for (final edgeId in topology.orderedEdgeIds)
        MmPoint(
          topology.edges[edgeId]!.start.xMm,
          topology.edges[edgeId]!.start.yMm,
        ),
    ];
    final boundary = MmPolygon(vertices);
    final legacySpace = EngineeringSpace(
      id: legacySpaceId,
      name: space.name,
      type: SpaceType.room,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
    );

    final baseGeometry =
        adapter.workspace.context == EditorWorkspaceContext.buildingLevel &&
                adapter.workspace.activeLevelNumber == legacyLevel.levelNumber
            ? adapter.workspace.editor.level
            : legacyLevel.level;
    if (baseGeometry.id != legacyLevelId) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: levelId,
        message: 'Active editor Level diverged from the canonical Level binding '
            'before standalone Room materialization.',
      );
    }

    final nextGeometry = baseGeometry.copyWith(
      spaces: <EngineeringSpace>[...baseGeometry.spaces, legacySpace],
    );
    final nextLevel = ComposedBuildingLevel(
      level: nextGeometry,
      levelNumber: legacyLevel.levelNumber,
      kind: legacyLevel.kind,
      floorToFloorHeightMm: legacyLevel.floorToFloorHeightMm,
      zones: legacyLevel.zones,
    );
    final nextLevels = <ComposedBuildingLevel>[
      for (final candidate in adapter.workspace.building.levels)
        if (candidate.level.id == legacyLevelId) nextLevel else candidate,
    ];
    final nextBuildingGeometry = Building(
      id: adapter.workspace.building.building.id,
      name: adapter.workspace.building.building.name,
      levels: <BuildingLevel>[for (final item in nextLevels) item.level],
    );
    final nextBuilding = ComposedBuilding(
      building: nextBuildingGeometry,
      levels: nextLevels,
      verticalCores: adapter.workspace.building.verticalCores,
    );

    if (!adapter.workspace.site.site.buildings
        .any((candidate) => candidate.id == nextBuildingGeometry.id)) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: adapter.binding.buildingId,
        message: 'Legacy Site does not contain the bound Building.',
      );
    }
    final nextSite = adapter.workspace.site.copyWith(
      site: adapter.workspace.site.site.copyWith(
        buildings: <Building>[
          for (final candidate in adapter.workspace.site.site.buildings)
            if (candidate.id == nextBuildingGeometry.id)
              nextBuildingGeometry
            else
              candidate,
        ],
      ),
    );

    adapter.workspace.building = nextBuilding;
    adapter.workspace.site = nextSite;
    adapter.binding.extendMaterializedChildren(
      legacySpaceIds: <SpaceId, String>{spaceId: legacySpaceId},
    );
    if (adapter.workspace.context == EditorWorkspaceContext.buildingLevel &&
        adapter.workspace.activeLevelNumber == nextLevel.levelNumber) {
      adapter.workspace.editor.level = nextGeometry;
    }

    final after = inspect(
      project: project,
      navigation: navigation,
      binding: adapter.binding,
    );
    if (!after.canOpen) {
      throw StateError(
        'Standalone canonical Room materialization did not establish an '
        'openable legacy binding.',
      );
    }
    return after;
  }
}

bool _isValidTopology(SpaceBoundaryTopology topology) {
  try {
    topology.validateOrThrow();
    return topology.orderedEdgeIds.length >= 3;
  } catch (_) {
    return false;
  }
}
