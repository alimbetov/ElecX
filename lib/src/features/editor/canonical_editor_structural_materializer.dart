import '../../application/project/project_navigation_state.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/building_composition.dart';
import '../../domain/geometry.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import '../../domain/site_outdoor_model.dart';
import 'canonical_editor_runtime_cutover.dart';
import 'canonical_editor_workspace_adapter.dart';
import 'canonical_legacy_identity_codec.dart';
import 'editor_building_workspace.dart';

/// Production compatibility projection for canonical structural Zones/Spaces
/// created after the legacy editor document was opened.
///
/// The canonical aggregate remains authoritative. This materializer only adds
/// a deterministic legacy representation for one selected canonical Zone and
/// extends the shared identity binding so the existing canvas can open it.
final class CanonicalEditorStructuralMaterializer
    implements CanonicalEditorRuntimeMaterializer {
  const CanonicalEditorStructuralMaterializer();

  static const ExistingBindingCanonicalEditorMaterializer _existing =
      ExistingBindingCanonicalEditorMaterializer();

  @override
  CanonicalEditorMaterializationResult inspect({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceBinding binding,
  }) {
    final existing = _existing.inspect(
      project: project,
      navigation: navigation,
      binding: binding,
    );
    if (existing.canOpen ||
        existing.status ==
            CanonicalEditorMaterializationStatus.blockedCanonicalMismatch) {
      return existing;
    }

    final buildingId = navigation.activeBuildingId;
    final levelId = navigation.activeLevelId;
    final zoneId = navigation.selectedZoneId;
    if (buildingId == null ||
        levelId == null ||
        zoneId == null ||
        buildingId != binding.buildingId ||
        binding.legacyLevelIds[levelId] == null) {
      return existing;
    }

    final level = project.index.level(levelId);
    final zone = project.index.zone(zoneId);
    if (level == null ||
        level.buildingId != buildingId ||
        zone == null ||
        zone.levelId != levelId) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus.blockedCanonicalMismatch,
        entityId: zoneId,
        message: 'Selected canonical Zone is not coherent with the active '
            'Building/Level path.',
      );
    }

    if (binding.legacyZoneIds.containsKey(zoneId)) {
      // A partially bound structural target is not safe to auto-heal. Existing
      // materializations continue through the conservative binding contract.
      return existing;
    }
    if (_legacyZoneKind(zone.kind) == null || zone.spaceIds.isEmpty) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus
            .blockedMissingRuntimeRepresentation,
        entityId: zoneId,
        message: 'Selected canonical Zone cannot be represented by the legacy '
            'building-zone model.',
      );
    }

    final selectedSpaceId = navigation.selectedSpaceId;
    if (selectedSpaceId != null && !zone.spaceIds.contains(selectedSpaceId)) {
      return CanonicalEditorMaterializationResult(
        status: CanonicalEditorMaterializationStatus.blockedCanonicalMismatch,
        entityId: selectedSpaceId,
        message: 'Selected canonical Space is outside the selected Zone.',
      );
    }

    for (final spaceId in zone.spaceIds) {
      final space = project.index.space(spaceId);
      if (space == null || space.levelId != levelId) {
        return CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus.blockedCanonicalMismatch,
          entityId: spaceId,
          message: 'Selected canonical Zone references a missing or foreign '
              'Space.',
        );
      }
      if (binding.legacySpaceIds.containsKey(spaceId)) {
        return CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus
              .blockedMissingRuntimeRepresentation,
          entityId: spaceId,
          message: 'Automatic structural materialization refuses a partially '
              'bound Zone.',
        );
      }
      if (_legacySpaceType(space.type) == null) {
        return CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus
              .blockedMissingRuntimeRepresentation,
          entityId: spaceId,
          message: 'Canonical Space type ${space.type.name} has no exact '
              'legacy runtime representation.',
        );
      }
      final topology = project.index.boundary(spaceId);
      if (topology == null || !_isValidTopology(topology)) {
        return CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus.blockedMissingGeometry,
          entityId: spaceId,
          message: 'Canonical Space has no valid materializable boundary.',
        );
      }
    }

    return CanonicalEditorMaterializationResult(
      status: CanonicalEditorMaterializationStatus.materializable,
      entityId: zoneId,
      message: 'Canonical Zone can be materialized into the legacy workspace.',
    );
  }

  @override
  CanonicalEditorMaterializationResult materialize({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceAdapter adapter,
  }) {
    final readiness = inspect(
      project: project,
      navigation: navigation,
      binding: adapter.binding,
    );
    if (!readiness.canMaterialize) return readiness;

    final evaluation = _buildPlan(
      project: project,
      navigation: navigation,
      adapter: adapter,
    );
    final plan = evaluation.plan;
    if (plan == null) return evaluation.blocked!;

    // All constructors and binding/collision checks have completed before the
    // live compatibility state is changed. The following operations therefore
    // contain no fallible discovery step and publish one coherent projection.
    adapter.workspace.building = plan.building;
    adapter.workspace.site = plan.site;
    adapter.binding.extendMaterializedChildren(
      legacyZoneIds: plan.zoneBindings,
      legacySpaceIds: plan.spaceBindings,
    );

    // selectLevel() synchronizes the currently active legacy editor before
    // opening the target. If the materialized Level is already active, seed the
    // editor with the new geometry first so that synchronization cannot write
    // the pre-materialization Level back over the new projection.
    if (adapter.workspace.context == EditorWorkspaceContext.buildingLevel &&
        adapter.workspace.activeLevelNumber == plan.levelNumber) {
      adapter.workspace.editor.level = plan.level.level;
    }

    final after = inspect(
      project: project,
      navigation: navigation,
      binding: adapter.binding,
    );
    if (!after.canOpen) {
      throw StateError(
        'Canonical structural materialization did not establish an openable '
        'legacy binding.',
      );
    }
    return after;
  }

  _PlanEvaluation _buildPlan({
    required ProjectAggregateRoot project,
    required ProjectNavigationState navigation,
    required CanonicalEditorWorkspaceAdapter adapter,
  }) {
    final levelId = navigation.activeLevelId!;
    final zoneId = navigation.selectedZoneId!;
    final zone = project.index.zone(zoneId)!;
    final legacyLevelId = adapter.binding.legacyLevelIds[levelId]!;

    if (adapter.workspace.building.building.id !=
        adapter.binding.legacyBuildingId) {
      return _PlanEvaluation.blocked(
        CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus
              .blockedMissingRuntimeRepresentation,
          entityId: adapter.binding.buildingId,
          message: 'Bound legacy Building is not the active editor workspace.',
        ),
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
      return _PlanEvaluation.blocked(
        CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus
              .blockedMissingRuntimeRepresentation,
          entityId: levelId,
          message: 'Bound legacy Level $legacyLevelId does not exist.',
        ),
      );
    }

    final zoneKind = _legacyZoneKind(zone.kind)!;
    final legacyZoneId = CanonicalLegacyIdentityCodec.encodeZoneId(zoneId);
    if (legacyLevel.zones.any((candidate) => candidate.id == legacyZoneId) ||
        adapter.binding.canonicalZoneIdForLegacy(legacyZoneId) != null) {
      return _PlanEvaluation.blocked(
        CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus
              .blockedMissingRuntimeRepresentation,
          entityId: zoneId,
          message: 'Encoded legacy Zone identity collides with existing '
              'runtime state.',
        ),
      );
    }

    final canonicalSpaceIds = zone.spaceIds.toList()
      ..sort((left, right) => left.value.compareTo(right.value));
    final legacySpaces = <EngineeringSpace>[];
    final spaceBindings = <SpaceId, String>{};
    final existingLegacySpaceIds =
        legacyLevel.level.spaces.map((space) => space.id).toSet();

    for (final spaceId in canonicalSpaceIds) {
      final space = project.index.space(spaceId)!;
      final topology = project.index.boundary(spaceId)!;
      final legacySpaceId = CanonicalLegacyIdentityCodec.encodeSpaceId(spaceId);
      if (existingLegacySpaceIds.contains(legacySpaceId) ||
          adapter.binding.canonicalSpaceIdForLegacy(legacySpaceId) != null ||
          spaceBindings.containsValue(legacySpaceId)) {
        return _PlanEvaluation.blocked(
          CanonicalEditorMaterializationResult(
            status: CanonicalEditorMaterializationStatus
                .blockedMissingRuntimeRepresentation,
            entityId: spaceId,
            message: 'Encoded legacy Space identity collides with existing '
                'runtime state.',
          ),
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
      legacySpaces.add(
        EngineeringSpace(
          id: legacySpaceId,
          name: space.name,
          type: _legacySpaceType(space.type)!,
          boundary: boundary,
          referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
        ),
      );
      spaceBindings[spaceId] = legacySpaceId;
    }

    final baseGeometry =
        adapter.workspace.context == EditorWorkspaceContext.buildingLevel &&
                adapter.workspace.activeLevelNumber == legacyLevel.levelNumber
            ? adapter.workspace.editor.level
            : legacyLevel.level;
    if (baseGeometry.id != legacyLevelId) {
      return _PlanEvaluation.blocked(
        CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus
              .blockedMissingRuntimeRepresentation,
          entityId: levelId,
          message: 'Active editor Level diverged from the canonical Level '
              'binding before materialization.',
        ),
      );
    }

    final nextGeometry = baseGeometry.copyWith(
      spaces: <EngineeringSpace>[...baseGeometry.spaces, ...legacySpaces],
    );
    final nextZone = BuildingZone(
      id: legacyZoneId,
      name: zone.name,
      kind: zoneKind,
      apartmentNumber:
          zoneKind == BuildingZoneKind.apartment ? zone.name : null,
      spaceIds: spaceBindings.values,
    );
    final nextLevel = ComposedBuildingLevel(
      level: nextGeometry,
      levelNumber: legacyLevel.levelNumber,
      kind: legacyLevel.kind,
      floorToFloorHeightMm: legacyLevel.floorToFloorHeightMm,
      zones: <BuildingZone>[...legacyLevel.zones, nextZone],
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

    final siteContainsBuilding = adapter.workspace.site.site.buildings
        .any((candidate) => candidate.id == nextBuildingGeometry.id);
    if (!siteContainsBuilding) {
      return _PlanEvaluation.blocked(
        CanonicalEditorMaterializationResult(
          status: CanonicalEditorMaterializationStatus
              .blockedMissingRuntimeRepresentation,
          entityId: adapter.binding.buildingId,
          message: 'Legacy Site does not contain the bound Building.',
        ),
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

    return _PlanEvaluation.plan(
      _StructuralMaterializationPlan(
        building: nextBuilding,
        site: nextSite,
        level: nextLevel,
        levelNumber: nextLevel.levelNumber,
        zoneBindings: <ZoneId, String>{zoneId: legacyZoneId},
        spaceBindings: spaceBindings,
      ),
    );
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

BuildingZoneKind? _legacyZoneKind(ProjectStructuralZoneKind kind) =>
    switch (kind) {
      ProjectStructuralZoneKind.apartment => BuildingZoneKind.apartment,
      ProjectStructuralZoneKind.common => BuildingZoneKind.common,
      ProjectStructuralZoneKind.technical => BuildingZoneKind.technical,
      ProjectStructuralZoneKind.parking => BuildingZoneKind.parking,
      ProjectStructuralZoneKind.storage => BuildingZoneKind.storage,
      ProjectStructuralZoneKind.utility => BuildingZoneKind.utility,
      ProjectStructuralZoneKind.unknown ||
      ProjectStructuralZoneKind.commercial ||
      ProjectStructuralZoneKind.office ||
      ProjectStructuralZoneKind.service =>
        null,
    };

SpaceType? _legacySpaceType(ProjectSpaceType type) => switch (type) {
      ProjectSpaceType.room => SpaceType.room,
      ProjectSpaceType.corridor => SpaceType.corridor,
      ProjectSpaceType.hall => SpaceType.hall,
      ProjectSpaceType.technicalRoom => SpaceType.technicalRoom,
      ProjectSpaceType.stair => SpaceType.stair,
      ProjectSpaceType.shaft => SpaceType.shaft,
      ProjectSpaceType.outdoorArea => SpaceType.outdoorArea,
      ProjectSpaceType.unknown => null,
    };

final class _StructuralMaterializationPlan {
  const _StructuralMaterializationPlan({
    required this.building,
    required this.site,
    required this.level,
    required this.levelNumber,
    required this.zoneBindings,
    required this.spaceBindings,
  });

  final ComposedBuilding building;
  final ComposedProjectSite site;
  final ComposedBuildingLevel level;
  final int levelNumber;
  final Map<ZoneId, String> zoneBindings;
  final Map<SpaceId, String> spaceBindings;
}

final class _PlanEvaluation {
  const _PlanEvaluation._({this.plan, this.blocked});

  factory _PlanEvaluation.plan(_StructuralMaterializationPlan plan) =>
      _PlanEvaluation._(plan: plan);

  factory _PlanEvaluation.blocked(
    CanonicalEditorMaterializationResult result,
  ) =>
      _PlanEvaluation._(blocked: result);

  final _StructuralMaterializationPlan? plan;
  final CanonicalEditorMaterializationResult? blocked;
}
