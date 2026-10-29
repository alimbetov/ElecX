import 'dart:convert';

import '../../../../domain/boundary_topology.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_entity_stores_copy.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/project_space_semantics.dart';
import '../../../../domain/semantic_sha256.dart';
import '../../../../domain/slab_topology.dart';
import '../../../../domain/vertical_core.dart';
import '../../project_mutation.dart';
import '../../project_mutation_reservation.dart';
import '../wizard_contracts.dart';
import 'building_common_core_composition.dart';
import 'building_generation_parameters.dart';
import 'common_core_opening_hosts.dart';
import 'building_level_stack_generator.dart';

final class CottageCompositionException implements Exception {
  const CottageCompositionException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// Building-local physical envelope used by the P10.7 detached-house generator.
///
/// The Site placement translation comes from [BuildingGenerationParameters].
/// Rotation is deliberately left to P10.9 site composition; P10.7 fails closed
/// for a non-zero placement orientation instead of materializing incorrect
/// axis-aligned geometry.
final class CottageCompositionLayout {
  CottageCompositionLayout({
    required this.footprintWidthMm,
    required this.footprintDepthMm,
    required this.commonCore,
    this.slabThicknessMm = 200,
    String slabMaterialId = 'concrete',
  }) : slabMaterialId = slabMaterialId.trim() {
    if (footprintWidthMm <= 0 || footprintWidthMm > 1000000) {
      throw RangeError.range(
        footprintWidthMm,
        1,
        1000000,
        'footprintWidthMm',
      );
    }
    if (footprintDepthMm <= 0 || footprintDepthMm > 1000000) {
      throw RangeError.range(
        footprintDepthMm,
        1,
        1000000,
        'footprintDepthMm',
      );
    }
    if (slabThicknessMm <= 0 || slabThicknessMm > 1000000) {
      throw RangeError.range(
        slabThicknessMm,
        1,
        1000000,
        'slabThicknessMm',
      );
    }
    if (this.slabMaterialId.isEmpty) {
      throw ArgumentError.value(
        slabMaterialId,
        'slabMaterialId',
        'Slab material id must be non-empty.',
      );
    }
  }

  final int footprintWidthMm;
  final int footprintDepthMm;
  final int slabThicknessMm;
  final String slabMaterialId;
  final CommonCoreLayoutParameters commonCore;

  Map<String, Object?> toCanonicalJson() => {
        'footprintWidthMm': footprintWidthMm,
        'footprintDepthMm': footprintDepthMm,
        'slabThicknessMm': slabThicknessMm,
        'slabMaterialId': slabMaterialId,
        'commonCore': commonCore.toCanonicalJson(),
      };

  List<BoundaryPointMm> footprint(BuildingSitePlacement placement) {
    final x = placement.xMm;
    final y = placement.yMm;
    return List.unmodifiable([
      BoundaryPointMm(xMm: x, yMm: y),
      BoundaryPointMm(xMm: x + footprintWidthMm, yMm: y),
      BoundaryPointMm(
        xMm: x + footprintWidthMm,
        yMm: y + footprintDepthMm,
      ),
      BoundaryPointMm(xMm: x, yMm: y + footprintDepthMm),
    ]);
  }
}

final class CottageSlabProposal {
  const CottageSlabProposal({
    required this.semanticKey,
    required this.belowLevelGenerationKey,
    required this.aboveLevelGenerationKey,
  });

  final String semanticKey;
  final String belowLevelGenerationKey;
  final String aboveLevelGenerationKey;

  Map<String, Object?> toCanonicalJson() => {
        'semanticKey': semanticKey,
        'belowLevelGenerationKey': belowLevelGenerationKey,
        'aboveLevelGenerationKey': aboveLevelGenerationKey,
      };
}

/// ID-free P10.7 candidate. Persistent identities are allocated only when the
/// corresponding reserved command enters Preview.
final class CottageCompositionPlan {
  CottageCompositionPlan._({
    required this.compositionKey,
    required this.parameters,
    required this.layout,
    required this.levelStack,
    required Iterable<String> commonCoreLevelGenerationKeys,
    required Iterable<CottageSlabProposal> slabs,
  })  : commonCoreLevelGenerationKeys =
            List.unmodifiable(commonCoreLevelGenerationKeys),
        slabs = List.unmodifiable(slabs);

  final String compositionKey;
  final BuildingGenerationParameters parameters;
  final CottageCompositionLayout layout;
  final BuildingLevelStackDraft levelStack;
  final List<String> commonCoreLevelGenerationKeys;
  final List<CottageSlabProposal> slabs;

  Set<BuildingServiceAnchorKind> get pendingServiceAnchorKinds =>
      parameters.serviceAnchors.kinds;

  bool get hasDeferredServiceAnchors => pendingServiceAnchorKinds.isNotEmpty;

  int get servedLevelCount => commonCoreLevelGenerationKeys.length;

  int get coreCount =>
      parameters.commonCore.stairCount +
      parameters.commonCore.liftCount +
      parameters.commonCore.serviceShaftCount +
      parameters.commonCore.electricalRiserCount +
      parameters.commonCore.telecomRiserCount;

  int get candidateRoomCountPerLevel {
    final policy = parameters.commonCore.serviceSpacePolicy;
    return (parameters.commonCore.includeTechnicalRoom ? 1 : 0) +
        (policy.includeElectricalRoomCandidate ? 1 : 0) +
        (policy.includeTelecomRoomCandidate ? 1 : 0) +
        (policy.includeFireControlRoomCandidate ? 1 : 0) +
        (policy.includeUtilityRoomCandidate ? 1 : 0);
  }

  int get topSpaceCountPerLevel {
    final policy = parameters.commonCore.serviceSpacePolicy;
    return (policy.includeCommonHall ? 1 : 0) +
        (policy.includeElevatorHall && parameters.commonCore.liftCount > 0
            ? 1
            : 0) +
        coreCount;
  }

  int get spacesPerServedLevel =>
      1 + topSpaceCountPerLevel + candidateRoomCountPerLevel;

  int get openingCount => servedLevelCount * (spacesPerServedLevel - 1);

  int get verticalAdjacencyCount =>
      coreCount * (servedLevelCount > 0 ? servedLevelCount - 1 : 0);

  int get adjacencyCount => openingCount + verticalAdjacencyCount;

  int get zoneCountPerServedLevel {
    var count = 1;
    final hasService = parameters.commonCore.serviceShaftCount > 0 ||
        parameters.commonCore.electricalRiserCount > 0 ||
        parameters.commonCore.telecomRiserCount > 0;
    if (hasService) count++;
    if (candidateRoomCountPerLevel > 0) count++;
    return count;
  }

  int get zoneCount => servedLevelCount * zoneCountPerServedLevel;
  int get spaceCount => servedLevelCount * spacesPerServedLevel;
  int get boundaryEdgeCount => spaceCount * 4;

  String get semanticFingerprint => semanticSha256Hex(
        jsonEncode({
          'schema': 'p10.cottage.v1',
          'compositionKey': compositionKey,
          'requestFingerprint': parameters.requestFingerprint,
          'levelStackFingerprint': levelStack.semanticFingerprint,
          'layout': layout.toCanonicalJson(),
          'commonCoreLevelGenerationKeys': commonCoreLevelGenerationKeys,
          'slabs': slabs.map((value) => value.toCanonicalJson()).toList(),
          'pendingServiceAnchors':
              pendingServiceAnchorKinds.map((kind) => kind.name).toList()
                ..sort(),
        }),
      );
}

final class CottageCompositionGenerator {
  const CottageCompositionGenerator();

  CottageCompositionPlan generate({
    required String compositionKey,
    required BuildingGenerationParameters parameters,
    required CottageCompositionLayout layout,
  }) {
    final key = compositionKey.trim();
    if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(key)) {
      throw ArgumentError.value(
        compositionKey,
        'compositionKey',
        'Expected a stable semantic key.',
      );
    }
    if (parameters.kind != BuildingCompositionKind.detachedHouse) {
      throw const CottageCompositionException('p10.cottage.kind-not-detached');
    }
    if (!parameters.commonCore.isCurrentContract) {
      throw const CottageCompositionException(
        'p10.cottage.common-core-v2-required',
      );
    }
    if (parameters.typicalFloor != null) {
      throw const CottageCompositionException(
        'p10.cottage.typical-floor-not-supported',
      );
    }
    if (parameters.placement.orientation.milliDegreesClockwiseFromPositiveY !=
        0) {
      throw const CottageCompositionException(
        'p10.cottage.rotated-site-placement-deferred',
      );
    }

    final levels = parameters.levelStack.levels;
    final basementCount =
        levels.where((level) => level.kind == ProjectLevelKind.basement).length;
    final technicalCount = levels
        .where((level) => level.kind == ProjectLevelKind.technical)
        .length;
    final occupiableCount = levels
        .where(
          (level) =>
              level.kind == ProjectLevelKind.ground ||
              level.kind == ProjectLevelKind.residential,
        )
        .length;
    if (basementCount > 1) {
      throw const CottageCompositionException(
        'p10.cottage.multiple-basements-not-supported',
      );
    }
    if (technicalCount > 1) {
      throw const CottageCompositionException(
        'p10.cottage.multiple-technical-levels-not-supported',
      );
    }
    if (occupiableCount < 1 || occupiableCount > 4) {
      throw const CottageCompositionException(
        'p10.cottage.occupiable-level-count-out-of-range',
      );
    }

    final servedLevels =
        levels.where((level) => level.kind != ProjectLevelKind.roof).toList();
    if (servedLevels.length > 1 && parameters.commonCore.stairCount < 1) {
      throw const CottageCompositionException(
        'p10.cottage.internal-stair-required',
      );
    }
    final coreCount = parameters.commonCore.stairCount +
        parameters.commonCore.liftCount +
        parameters.commonCore.serviceShaftCount +
        parameters.commonCore.electricalRiserCount +
        parameters.commonCore.telecomRiserCount;
    if (servedLevels.length < 2 && coreCount > 0) {
      throw const CottageCompositionException(
        'p10.cottage.single-level-core-not-supported',
      );
    }

    _validateLayout(parameters: parameters, layout: layout);
    final levelStack = const BuildingLevelStackGenerator().generate(
      buildingGenerationKey: key,
      parameters: parameters.levelStack,
    );
    final slabs = <CottageSlabProposal>[];
    for (var index = 0; index < levels.length - 1; index++) {
      final below = levels[index];
      final above = levels[index + 1];
      slabs.add(
        CottageSlabProposal(
          semanticKey: 'slab:${below.generationKey}:${above.generationKey}',
          belowLevelGenerationKey: below.generationKey,
          aboveLevelGenerationKey: above.generationKey,
        ),
      );
    }
    return CottageCompositionPlan._(
      compositionKey: key,
      parameters: parameters,
      layout: layout,
      levelStack: levelStack,
      commonCoreLevelGenerationKeys:
          servedLevels.map((level) => level.generationKey),
      slabs: slabs,
    );
  }

  void _validateLayout({
    required BuildingGenerationParameters parameters,
    required CottageCompositionLayout layout,
  }) {
    final placement = parameters.placement;
    final left = placement.xMm;
    final right = left + layout.footprintWidthMm;
    final bottom = placement.yMm;
    final top = bottom + layout.footprintDepthMm;
    final core = layout.commonCore;
    if (core.originXmm < left ||
        core.originXmm + core.corridorLengthMm > right ||
        core.originYmm < bottom ||
        core.originYmm + parameters.commonCore.corridorWidthMm > top) {
      throw const CottageCompositionException(
        'p10.cottage.common-core-outside-footprint',
      );
    }
    final topSpaceCount =
        (parameters.commonCore.serviceSpacePolicy.includeCommonHall ? 1 : 0) +
            (parameters.commonCore.serviceSpacePolicy.includeElevatorHall &&
                    parameters.commonCore.liftCount > 0
                ? 1
                : 0) +
            parameters.commonCore.stairCount +
            parameters.commonCore.liftCount +
            parameters.commonCore.serviceShaftCount +
            parameters.commonCore.electricalRiserCount +
            parameters.commonCore.telecomRiserCount;
    final bottomSpaceCount = (parameters.commonCore.includeTechnicalRoom
            ? 1
            : 0) +
        (parameters.commonCore.serviceSpacePolicy.includeElectricalRoomCandidate
            ? 1
            : 0) +
        (parameters.commonCore.serviceSpacePolicy.includeTelecomRoomCandidate
            ? 1
            : 0) +
        (parameters
                .commonCore.serviceSpacePolicy.includeFireControlRoomCandidate
            ? 1
            : 0) +
        (parameters.commonCore.serviceSpacePolicy.includeUtilityRoomCandidate
            ? 1
            : 0);
    if (topSpaceCount * core.coreModuleWidthMm > core.corridorLengthMm ||
        bottomSpaceCount * core.candidateRoomWidthMm > core.corridorLengthMm) {
      throw const CottageCompositionException(
        'p10.cottage.common-core-layout-overflow',
      );
    }
    if (topSpaceCount > 0 &&
        core.originYmm +
                parameters.commonCore.corridorWidthMm +
                core.coreDepthMm >
            top) {
      throw const CottageCompositionException(
        'p10.cottage.common-core-outside-footprint',
      );
    }
    if (bottomSpaceCount > 0 &&
        core.originYmm - core.candidateRoomDepthMm < bottom) {
      throw const CottageCompositionException(
        'p10.cottage.common-core-outside-footprint',
      );
    }
  }
}

final class CottageCompositionCommand implements ReservedProjectCommand {
  CottageCompositionCommand._({
    required this.projectId,
    required this.siteId,
    required this.baseVersion,
    required this.plan,
  });

  factory CottageCompositionCommand.create({
    required ProjectAggregateRoot project,
    required String compositionKey,
    required BuildingGenerationParameters parameters,
    required CottageCompositionLayout layout,
    CottageCompositionGenerator generator = const CottageCompositionGenerator(),
  }) {
    _requireCottageSite(project, parameters.siteId);
    final plan = generator.generate(
      compositionKey: compositionKey,
      parameters: parameters,
      layout: layout,
    );
    return CottageCompositionCommand._(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
      plan: plan,
    );
  }

  final ProjectId projectId;
  final SiteId siteId;
  final LocalProjectVersion baseVersion;
  final CottageCompositionPlan plan;

  static const _generator = CottageCompositionGenerator();
  static const _coreGenerator = BuildingCommonCoreCompositionGenerator();

  @override
  String get commandType => 'p10.cottage.compose';

  @override
  String get normalizedIntentKey => jsonEncode({
        'schema': 'p10.cottage.v1',
        'projectId': projectId.value,
        'siteId': siteId.value,
        'baseVersion': baseVersion.value,
        'planFingerprint': plan.semanticFingerprint,
      });

  String get _buildingSlot => 'p10:${plan.compositionKey}:building';
  String _slabSlot(int index) => 'p10:${plan.compositionKey}:slab:$index';
  String _zoneSlot(int index) => 'p10:${plan.compositionKey}:zone:$index';
  String _spaceSlot(int index) => 'p10:${plan.compositionKey}:space:$index';
  String _edgeSlot(int index) => 'p10:${plan.compositionKey}:edge:$index';
  String _openingSlot(int index) => 'p10:${plan.compositionKey}:opening:$index';
  String _adjacencySlot(int index) =>
      'p10:${plan.compositionKey}:adjacency:$index';
  String _coreSlot(int index) => 'p10:${plan.compositionKey}:core:$index';

  Map<String, ReservedEntityIdKind> get _reservationSlots => {
        _buildingSlot: ReservedEntityIdKind.building,
        ...plan.levelStack.reservationSlots,
        for (var index = 0; index < plan.slabs.length; index++)
          _slabSlot(index): ReservedEntityIdKind.slab,
        for (var index = 0; index < plan.zoneCount; index++)
          _zoneSlot(index): ReservedEntityIdKind.zone,
        for (var index = 0; index < plan.spaceCount; index++)
          _spaceSlot(index): ReservedEntityIdKind.space,
        for (var index = 0; index < plan.boundaryEdgeCount; index++)
          _edgeSlot(index): ReservedEntityIdKind.boundaryEdge,
        for (var index = 0; index < plan.openingCount; index++)
          _openingSlot(index): ReservedEntityIdKind.opening,
        for (var index = 0; index < plan.adjacencyCount; index++)
          _adjacencySlot(index): ReservedEntityIdKind.spaceAdjacency,
        for (var index = 0; index < plan.coreCount; index++)
          _coreSlot(index): ReservedEntityIdKind.verticalCore,
      };

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(
        factory: factory,
        entitySlots: _reservationSlots,
      );

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    _requireCurrent(current);
    final regenerated = _generator.generate(
      compositionKey: plan.compositionKey,
      parameters: plan.parameters,
      layout: plan.layout,
    );
    if (regenerated.semanticFingerprint != plan.semanticFingerprint) {
      throw const CottageCompositionException('p10.cottage.plan-stale');
    }
    final expectedSlots = _reservationSlots;
    if (reservation.slots.length != expectedSlots.length ||
        reservation.entityIds.length != expectedSlots.length ||
        !reservation.slots.containsAll(expectedSlots.keys)) {
      throw const CottageCompositionException(
        'p10.cottage.invalid-reservation',
      );
    }
    for (final id in reservation.entityIds) {
      final collision = switch (id) {
        BuildingId() => current.stores.buildings.containsKey(id),
        LevelId() => current.stores.levels.containsKey(id),
        SlabId() => current.stores.slabs.containsKey(id),
        ZoneId() => current.stores.zones.containsKey(id),
        SpaceId() => current.stores.spaces.containsKey(id),
        BoundaryEdgeId() =>
          current.engineeringMetadata.boundaryEdgeIdentityRegistry.contains(id),
        OpeningId() => current.stores.openings.containsKey(id),
        SpaceAdjacencyId() => current.stores.adjacencies.containsKey(id),
        VerticalCoreId() => current.stores.verticalCores.containsKey(id),
        _ => true,
      };
      if (collision) {
        throw const CottageCompositionException(
          'p10.cottage.reservation-collision',
        );
      }
    }
    final structural = _buildStructuralStage(current, reservation);
    final corePlan = _generateCommonCorePlan(structural.project, structural);
    _validateCoreGeometry(corePlan);
  }

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    validateReservation(current: current, reservation: reservation);
    final structural = _buildStructuralStage(current, reservation);
    final corePlan = _generateCommonCorePlan(structural.project, structural);
    final proposed = _materializeCore(
      project: structural.project,
      structural: structural,
      corePlan: corePlan,
      reservation: reservation,
    );
    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState.fromProject(proposed),
      affectedEntityIds:
          ProjectEntityDiff.between(current.stores, proposed.stores)
              .affectedEntityIds,
    );
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations({
    required ProjectAggregateRoot before,
    required ProjectAggregateRoot candidate,
    required MutationIdentityReservation reservation,
  }) sync* {
    final diff = ProjectEntityDiff.between(before.stores, candidate.stores);
    for (final id in diff.addedEntityIds) {
      final EntityId? owner = switch (id) {
        BuildingId() => siteId,
        LevelId() => candidate.stores.levels[id]!.buildingId,
        SlabId() => candidate.stores.slabs[id]!.buildingId,
        ZoneId() => candidate.stores.zones[id]!.levelId,
        SpaceId() => candidate.index.structuralZoneBySpace[id] ??
            candidate.stores.spaces[id]!.levelId,
        BoundaryEdgeId() => candidate.index.boundaryEdges[id]!.spaceId,
        VerticalCoreId() => candidate.stores.verticalCores[id]!.buildingId,
        OpeningId() || SpaceAdjacencyId() => reservation.entityId<BuildingId>(
            _buildingSlot,
          ),
        _ => null,
      };
      yield CreateEntityOperation(entityId: id, ownerId: owner);
    }
    for (final id in diff.updatedEntityIds) {
      yield UpdateEntityOperation(entityId: id);
    }
  }

  void _requireCurrent(ProjectAggregateRoot current) {
    if (current.id != projectId ||
        current.siteId != siteId ||
        current.version != baseVersion) {
      if (current.id == projectId &&
          current.siteId == siteId &&
          current.version != baseVersion) {
        throw StaleProjectMutationException(
          expectedVersion: baseVersion,
          currentVersion: current.version,
        );
      }
      throw const CottageCompositionException('p10.cottage.foreign-target');
    }
    _requireCottageSite(current, plan.parameters.siteId);
  }

  _CottageStructuralStage _buildStructuralStage(
    ProjectAggregateRoot current,
    MutationIdentityReservation reservation,
  ) {
    final buildingId = reservation.entityId<BuildingId>(_buildingSlot);
    final levels = plan.levelStack.materialize(
      buildingId: buildingId,
      reservation: reservation,
    );
    final currentSite = current.stores.sites[siteId]!;
    final sites = {...current.stores.sites};
    final buildings = {...current.stores.buildings};
    final levelStore = {...current.stores.levels};
    final slabStore = {...current.stores.slabs};

    sites[siteId] = ProjectSiteEntity(
      id: currentSite.id,
      name: currentSite.name,
      buildingIds: {...currentSite.buildingIds, buildingId},
    );
    buildings[buildingId] = ProjectBuildingEntity(
      id: buildingId,
      siteId: siteId,
      name: plan.parameters.displayName,
      levelIds: levels.levels.map((level) => level.id),
    );
    for (final level in levels.levels) {
      levelStore[level.id] = level;
    }

    final footprint = plan.layout.footprint(plan.parameters.placement);
    for (var index = 0; index < plan.slabs.length; index++) {
      final proposal = plan.slabs[index];
      final belowId =
          levels.idsByGenerationKey[proposal.belowLevelGenerationKey]!;
      final aboveId =
          levels.idsByGenerationKey[proposal.aboveLevelGenerationKey]!;
      final above = levelStore[aboveId]!;
      final slabId = reservation.entityId<SlabId>(_slabSlot(index));
      slabStore[slabId] = ProjectSlab(
        id: slabId,
        buildingId: buildingId,
        kind: SlabKind.interLevel,
        belowLevelId: belowId,
        aboveLevelId: aboveId,
        bottomElevationMm: above.elevationMm - plan.layout.slabThicknessMm,
        thicknessMm: plan.layout.slabThicknessMm,
        materialId: plan.layout.slabMaterialId,
        footprint: footprint,
      );
    }

    final stores = current.stores.copyWith(
      sites: sites,
      buildings: buildings,
      levels: levelStore,
      slabs: slabStore,
    );
    final staged = ProjectAggregateRoot(
      id: current.id,
      siteId: current.siteId,
      version: current.version,
      engineeringMetadata: current.engineeringMetadata,
      stores: stores,
    );
    return _CottageStructuralStage(
      project: staged,
      buildingId: buildingId,
      levels: levels,
    );
  }

  BuildingCommonCoreCompositionPlan _generateCommonCorePlan(
    ProjectAggregateRoot project,
    _CottageStructuralStage structural,
  ) {
    final served = [
      for (final key in plan.commonCoreLevelGenerationKeys)
        structural.levels.idsByGenerationKey[key]!,
    ];
    return _coreGenerator.generate(
      project: project,
      target: BuildingWizardTarget(
        projectId: projectId,
        siteId: siteId,
        buildingId: structural.buildingId,
        baseVersion: baseVersion,
      ),
      parameters: plan.parameters.commonCore,
      servedLevelIds: served,
      layout: plan.layout.commonCore,
    );
  }

  void _validateCoreGeometry(BuildingCommonCoreCompositionPlan corePlan) {
    final xMin = plan.parameters.placement.xMm;
    final yMin = plan.parameters.placement.yMm;
    final xMax = xMin + plan.layout.footprintWidthMm;
    final yMax = yMin + plan.layout.footprintDepthMm;
    for (final space in corePlan.spaces) {
      final rect = space.rect;
      if (rect.xMm < xMin ||
          rect.yMm < yMin ||
          rect.rightMm > xMax ||
          rect.topMm > yMax) {
        throw const CottageCompositionException(
          'p10.cottage.generated-space-outside-footprint',
        );
      }
    }
  }

  ProjectAggregateRoot _materializeCore({
    required ProjectAggregateRoot project,
    required _CottageStructuralStage structural,
    required BuildingCommonCoreCompositionPlan corePlan,
    required MutationIdentityReservation reservation,
  }) {
    final levels = {...project.stores.levels};
    final zones = {...project.stores.zones};
    final spaces = {...project.stores.spaces};
    final boundaries = {...project.stores.boundaries};
    final openings = {...project.stores.openings};
    final adjacencies = {...project.stores.adjacencies};
    final verticalCores = {...project.stores.verticalCores};

    final spaceIdsByKey = <String, SpaceId>{};
    final spacesByZone =
        <({LevelId levelId, CommonCoreZoneRole role}), Set<SpaceId>>{};
    var edgeCursor = 0;
    for (var spaceIndex = 0;
        spaceIndex < corePlan.spaces.length;
        spaceIndex++) {
      final proposal = corePlan.spaces[spaceIndex];
      final id = reservation.entityId<SpaceId>(_spaceSlot(spaceIndex));
      spaceIdsByKey[proposal.semanticKey] = id;
      spaces[id] = ProjectSpaceEntity(
        id: id,
        levelId: proposal.levelId,
        name: proposal.name,
        type: proposal.type,
        usage: proposal.usage,
      );
      final zoneKey = (levelId: proposal.levelId, role: proposal.zoneRole);
      (spacesByZone[zoneKey] ??= <SpaceId>{}).add(id);

      final edgeIds = <BoundaryEdgeId>[];
      for (var index = 0; index < 4; index++) {
        edgeIds.add(
          reservation.entityId<BoundaryEdgeId>(_edgeSlot(edgeCursor++)),
        );
      }
      final points = proposal.rect.points;
      final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
      for (var index = 0; index < edgeIds.length; index++) {
        final edgeId = edgeIds[index];
        edges[edgeId] = ProjectBoundaryEdge(
          id: edgeId,
          spaceId: id,
          start: points[index],
          end: points[(index + 1) % points.length],
        );
      }
      boundaries[id] = SpaceBoundaryTopology(
        spaceId: id,
        orderedEdgeIds: edgeIds,
        edges: edges,
      );
    }

    final levelOrder = <LevelId, int>{
      for (var index = 0; index < structural.levels.levels.length; index++)
        structural.levels.levels[index].id: index,
    };
    final zoneEntries = spacesByZone.entries.toList()
      ..sort((a, b) {
        final levelCompare =
            levelOrder[a.key.levelId]!.compareTo(levelOrder[b.key.levelId]!);
        if (levelCompare != 0) return levelCompare;
        return a.key.role.name.compareTo(b.key.role.name);
      });
    if (zoneEntries.length != plan.zoneCount) {
      throw const CottageCompositionException(
        'p10.cottage.zone-plan-count-drift',
      );
    }
    final addedZonesByLevel = <LevelId, Set<ZoneId>>{};
    final addedSpacesByLevel = <LevelId, Set<SpaceId>>{};
    for (var index = 0; index < zoneEntries.length; index++) {
      final entry = zoneEntries[index];
      final zoneId = reservation.entityId<ZoneId>(_zoneSlot(index));
      (addedZonesByLevel[entry.key.levelId] ??= <ZoneId>{}).add(zoneId);
      (addedSpacesByLevel[entry.key.levelId] ??= <SpaceId>{})
          .addAll(entry.value);
      zones[zoneId] = ProjectStructuralZoneEntity(
        id: zoneId,
        levelId: entry.key.levelId,
        name: switch (entry.key.role) {
          CommonCoreZoneRole.common => 'Common area',
          CommonCoreZoneRole.service => 'Service core',
          CommonCoreZoneRole.technical => 'Technical candidates',
        },
        kind: switch (entry.key.role) {
          CommonCoreZoneRole.common => ProjectStructuralZoneKind.common,
          CommonCoreZoneRole.service => ProjectStructuralZoneKind.service,
          CommonCoreZoneRole.technical => ProjectStructuralZoneKind.technical,
        },
        spaceIds: entry.value,
      );
    }
    for (final levelId in corePlan.levelIds) {
      final currentLevel = levels[levelId]!;
      levels[levelId] = ProjectLevelEntity(
        id: currentLevel.id,
        buildingId: currentLevel.buildingId,
        name: currentLevel.name,
        levelNumber: currentLevel.levelNumber,
        elevationMm: currentLevel.elevationMm,
        kind: currentLevel.kind,
        floorToFloorHeightMm: currentLevel.floorToFloorHeightMm,
        displayOrder: currentLevel.displayOrder,
        zoneIds: {
          ...currentLevel.zoneIds,
          ...?addedZonesByLevel[levelId],
        },
        spaceIds: {
          ...currentLevel.spaceIds,
          ...?addedSpacesByLevel[levelId],
        },
      );
    }

    var adjacencyCursor = 0;
    for (var index = 0; index < corePlan.openings.length; index++) {
      final proposal = corePlan.openings[index];
      final a = spaceIdsByKey[proposal.spaceAKey]!;
      final b = spaceIdsByKey[proposal.spaceBKey]!;
      final openingId = reservation.entityId<OpeningId>(_openingSlot(index));
      openings[openingId] = ProjectOpeningEntity(
        id: openingId,
        levelId: proposal.levelId,
        kind: proposal.kind,
        connectedSpaceIds: {a, b},
        widthMm: plan.layout.commonCore.openingWidthMm,
        heightMm: 2100,
        baseElevationMm: 0,
      );
      final adjacencyId = reservation.entityId<SpaceAdjacencyId>(
        _adjacencySlot(adjacencyCursor++),
      );
      adjacencies[adjacencyId] = ProjectSpaceAdjacencyEntity(
        id: adjacencyId,
        spaceAId: a,
        spaceBId: b,
        kind: SpaceAdjacencyKind.opening,
        openingId: openingId,
      );
    }
    for (final proposal in corePlan.verticalAdjacencies) {
      final adjacencyId = reservation.entityId<SpaceAdjacencyId>(
        _adjacencySlot(adjacencyCursor++),
      );
      adjacencies[adjacencyId] = ProjectSpaceAdjacencyEntity(
        id: adjacencyId,
        spaceAId: spaceIdsByKey[proposal.lowerSpaceKey]!,
        spaceBId: spaceIdsByKey[proposal.upperSpaceKey]!,
        kind: SpaceAdjacencyKind.vertical,
      );
    }
    if (adjacencyCursor != plan.adjacencyCount) {
      throw const CottageCompositionException(
        'p10.cottage.adjacency-plan-count-drift',
      );
    }

    for (var index = 0; index < corePlan.verticalCores.length; index++) {
      final proposal = corePlan.verticalCores[index];
      final coreId = reservation.entityId<VerticalCoreId>(_coreSlot(index));
      verticalCores[coreId] = ProjectVerticalCore(
        id: coreId,
        buildingId: structural.buildingId,
        kind: proposal.kind,
        levelIds: proposal.levelIds,
        footprint: proposal.footprint,
        name: proposal.name,
        usage: proposal.usage,
        hostSpaceIdsByLevel: {
          for (final entry in proposal.hostSpaceKeysByLevel.entries)
            entry.key: spaceIdsByKey[entry.value]!,
        },
      );
    }

    final stores = project.stores.copyWith(
      levels: levels,
      zones: zones,
      spaces: spaces,
      boundaries: boundaries,
      openings: openings,
      adjacencies: adjacencies,
      verticalCores: verticalCores,
    );
    final edgeRegistry = project
        .engineeringMetadata.boundaryEdgeIdentityRegistry
        .registerActiveBoundaries(boundaries);
    return ProjectAggregateRoot(
      id: project.id,
      siteId: project.siteId,
      version: project.version,
      engineeringMetadata: project.engineeringMetadata
          .withBoundaryEdgeIdentityRegistry(edgeRegistry)
          .withBoundaryHostedObjectRegistry(bindCommonCoreOpeningHosts(
            registry: project.engineeringMetadata.boundaryHostedObjectRegistry,
            openings: openings.values.where(
                (opening) => !project.stores.openings.containsKey(opening.id)),
            boundaries: boundaries,
          )),
      stores: stores,
    );
  }
}

final class _CottageStructuralStage {
  const _CottageStructuralStage({
    required this.project,
    required this.buildingId,
    required this.levels,
  });

  final ProjectAggregateRoot project;
  final BuildingId buildingId;
  final BuildingLevelMaterialization levels;
}

void _requireCottageSite(ProjectAggregateRoot project, SiteId requestedSiteId) {
  if (project.siteId != requestedSiteId) {
    throw const CottageCompositionException('p10.cottage.foreign-site');
  }
  final site = project.stores.sites[requestedSiteId];
  if (site == null) {
    throw const CottageCompositionException('p10.cottage.site-missing');
  }
  if (site.buildingIds.isNotEmpty) {
    throw const CottageCompositionException('p10.cottage.site-not-empty');
  }
}
