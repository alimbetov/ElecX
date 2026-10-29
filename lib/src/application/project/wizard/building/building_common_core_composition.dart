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
import 'building_generation_parameters.dart';

final class BuildingCommonCoreCompositionException implements Exception {
  const BuildingCommonCoreCompositionException(this.code);

  final String code;

  @override
  String toString() => code;
}

enum CommonCoreZoneRole { common, service, technical }

final class CommonCoreLayoutParameters {
  CommonCoreLayoutParameters({
    required this.originXmm,
    required this.originYmm,
    required this.corridorLengthMm,
    this.coreModuleWidthMm = 1800,
    this.coreDepthMm = 2400,
    this.candidateRoomWidthMm = 2400,
    this.candidateRoomDepthMm = 3000,
    this.openingWidthMm = 1000,
  }) {
    for (final entry in <String, int>{
      'corridorLengthMm': corridorLengthMm,
      'coreModuleWidthMm': coreModuleWidthMm,
      'coreDepthMm': coreDepthMm,
      'candidateRoomWidthMm': candidateRoomWidthMm,
      'candidateRoomDepthMm': candidateRoomDepthMm,
      'openingWidthMm': openingWidthMm,
    }.entries) {
      if (entry.value <= 0 || entry.value > 1000000) {
        throw RangeError.range(entry.value, 1, 1000000, entry.key);
      }
    }
    if (openingWidthMm > coreModuleWidthMm ||
        openingWidthMm > candidateRoomWidthMm) {
      throw ArgumentError(
        'Common/core opening width must fit every generated module.',
      );
    }
  }

  final int originXmm;
  final int originYmm;
  final int corridorLengthMm;
  final int coreModuleWidthMm;
  final int coreDepthMm;
  final int candidateRoomWidthMm;
  final int candidateRoomDepthMm;
  final int openingWidthMm;

  Map<String, Object?> toCanonicalJson() => {
        'originXmm': originXmm,
        'originYmm': originYmm,
        'corridorLengthMm': corridorLengthMm,
        'coreModuleWidthMm': coreModuleWidthMm,
        'coreDepthMm': coreDepthMm,
        'candidateRoomWidthMm': candidateRoomWidthMm,
        'candidateRoomDepthMm': candidateRoomDepthMm,
        'openingWidthMm': openingWidthMm,
      };
}

final class CommonCoreRectMm {
  CommonCoreRectMm({
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.heightMm,
  }) {
    if (widthMm <= 0 || heightMm <= 0) {
      throw ArgumentError('Common/core rectangles require positive dimensions.');
    }
  }

  final int xMm;
  final int yMm;
  final int widthMm;
  final int heightMm;

  int get rightMm => xMm + widthMm;
  int get topMm => yMm + heightMm;

  List<BoundaryPointMm> get points => List.unmodifiable([
        BoundaryPointMm(xMm: xMm, yMm: yMm),
        BoundaryPointMm(xMm: rightMm, yMm: yMm),
        BoundaryPointMm(xMm: rightMm, yMm: topMm),
        BoundaryPointMm(xMm: xMm, yMm: topMm),
      ]);

  Map<String, Object?> toCanonicalJson() => {
        'xMm': xMm,
        'yMm': yMm,
        'widthMm': widthMm,
        'heightMm': heightMm,
      };
}

final class CommonCoreSpaceProposal {
  const CommonCoreSpaceProposal({
    required this.semanticKey,
    required this.levelId,
    required this.zoneRole,
    required this.name,
    required this.type,
    required this.usage,
    required this.rect,
  });

  final String semanticKey;
  final LevelId levelId;
  final CommonCoreZoneRole zoneRole;
  final String name;
  final ProjectSpaceType type;
  final SpaceUsage usage;
  final CommonCoreRectMm rect;

  Map<String, Object?> toCanonicalJson() => {
        'semanticKey': semanticKey,
        'levelId': levelId.value,
        'zoneRole': zoneRole.name,
        'name': name,
        'type': type.name,
        'usage': usage.name,
        'rect': rect.toCanonicalJson(),
      };
}

final class CommonCoreOpeningProposal {
  const CommonCoreOpeningProposal({
    required this.semanticKey,
    required this.levelId,
    required this.spaceAKey,
    required this.spaceBKey,
    required this.kind,
  });

  final String semanticKey;
  final LevelId levelId;
  final String spaceAKey;
  final String spaceBKey;
  final OpeningKind kind;

  Map<String, Object?> toCanonicalJson() => {
        'semanticKey': semanticKey,
        'levelId': levelId.value,
        'spaceAKey': spaceAKey,
        'spaceBKey': spaceBKey,
        'kind': kind.name,
      };
}

final class CommonCoreVerticalAdjacencyProposal {
  const CommonCoreVerticalAdjacencyProposal({
    required this.semanticKey,
    required this.lowerSpaceKey,
    required this.upperSpaceKey,
  });

  final String semanticKey;
  final String lowerSpaceKey;
  final String upperSpaceKey;

  Map<String, Object?> toCanonicalJson() => {
        'semanticKey': semanticKey,
        'lowerSpaceKey': lowerSpaceKey,
        'upperSpaceKey': upperSpaceKey,
      };
}

final class CommonCoreVerticalCoreProposal {
  CommonCoreVerticalCoreProposal({
    required this.semanticKey,
    required this.name,
    required this.kind,
    required this.usage,
    required Iterable<LevelId> levelIds,
    required Map<LevelId, String> hostSpaceKeysByLevel,
    required Iterable<BoundaryPointMm> footprint,
  })  : levelIds = Set.unmodifiable(levelIds),
        hostSpaceKeysByLevel = Map.unmodifiable(hostSpaceKeysByLevel),
        footprint = List.unmodifiable(footprint);

  final String semanticKey;
  final String name;
  final VerticalCoreKind kind;
  final VerticalCoreUsage usage;
  final Set<LevelId> levelIds;
  final Map<LevelId, String> hostSpaceKeysByLevel;
  final List<BoundaryPointMm> footprint;

  Map<String, Object?> toCanonicalJson() {
    final sortedLevels = levelIds.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return {
      'semanticKey': semanticKey,
      'name': name,
      'kind': kind.name,
      'usage': usage.name,
      'levelIds': sortedLevels.map((id) => id.value).toList(),
      'hostSpaceKeysByLevel': {
        for (final levelId in sortedLevels)
          levelId.value: hostSpaceKeysByLevel[levelId]!,
      },
      'footprint': [
        for (final point in footprint) {'xMm': point.xMm, 'yMm': point.yMm},
      ],
    };
  }
}

final class BuildingCommonCoreCompositionPlan {
  BuildingCommonCoreCompositionPlan({
    required Iterable<LevelId> levelIds,
    required Iterable<CommonCoreSpaceProposal> spaces,
    required Iterable<CommonCoreOpeningProposal> openings,
    required Iterable<CommonCoreVerticalAdjacencyProposal> verticalAdjacencies,
    required Iterable<CommonCoreVerticalCoreProposal> verticalCores,
  })  : levelIds = List.unmodifiable(levelIds),
        spaces = List.unmodifiable(spaces),
        openings = List.unmodifiable(openings),
        verticalAdjacencies = List.unmodifiable(verticalAdjacencies),
        verticalCores = List.unmodifiable(verticalCores);

  final List<LevelId> levelIds;
  final List<CommonCoreSpaceProposal> spaces;
  final List<CommonCoreOpeningProposal> openings;
  final List<CommonCoreVerticalAdjacencyProposal> verticalAdjacencies;
  final List<CommonCoreVerticalCoreProposal> verticalCores;

  String corridorKey(LevelId levelId) => 'level:${levelId.value}:corridor';

  String get fingerprint => semanticSha256Hex(
        jsonEncode({
          'levelIds': levelIds.map((id) => id.value).toList(),
          'spaces': spaces.map((value) => value.toCanonicalJson()).toList(),
          'openings': openings.map((value) => value.toCanonicalJson()).toList(),
          'verticalAdjacencies': verticalAdjacencies
              .map((value) => value.toCanonicalJson())
              .toList(),
          'verticalCores':
              verticalCores.map((value) => value.toCanonicalJson()).toList(),
        }),
      );
}

/// Side-effect free P10.6 planner. It reads canonical topology but allocates no
/// persistent identity and never mutates the supplied project.
final class BuildingCommonCoreCompositionGenerator {
  const BuildingCommonCoreCompositionGenerator();

  BuildingCommonCoreCompositionPlan generate({
    required ProjectAggregateRoot project,
    required BuildingWizardTarget target,
    required CommonCoreParameters parameters,
    required Iterable<LevelId> servedLevelIds,
    required CommonCoreLayoutParameters layout,
  }) {
    _requireTarget(project, target);
    if (!parameters.isCurrentContract) {
      throw const BuildingCommonCoreCompositionException(
        'p10.common-core.contract-v2-required',
      );
    }
    final building = project.stores.buildings[target.buildingId]!;
    final requested = servedLevelIds.toSet();
    if (requested.isEmpty) {
      throw const BuildingCommonCoreCompositionException(
        'p10.common-core.levels-empty',
      );
    }
    if (!building.levelIds.containsAll(requested)) {
      throw const BuildingCommonCoreCompositionException(
        'p10.common-core.foreign-level',
      );
    }
    final buildingLevels = [
      for (final id in building.levelIds) project.stores.levels[id]!,
    ]..sort((a, b) {
        final elevation = a.elevationMm.compareTo(b.elevationMm);
        return elevation != 0 ? elevation : a.id.value.compareTo(b.id.value);
      });
    for (var index = 1; index < buildingLevels.length; index++) {
      if (buildingLevels[index - 1].elevationMm ==
          buildingLevels[index].elevationMm) {
        throw const BuildingCommonCoreCompositionException(
          'p10.common-core.ambiguous-level-order',
        );
      }
    }
    final levels = buildingLevels.where((level) => requested.contains(level.id)).toList();
    final selectedIndices = [
      for (var index = 0; index < buildingLevels.length; index++)
        if (requested.contains(buildingLevels[index].id)) index,
    ];
    if (selectedIndices.last - selectedIndices.first + 1 !=
        selectedIndices.length) {
      throw const BuildingCommonCoreCompositionException(
        'p10.common-core.non-contiguous-level-range',
      );
    }
    final coreCount = parameters.stairCount +
        parameters.liftCount +
        parameters.serviceShaftCount +
        parameters.electricalRiserCount +
        parameters.telecomRiserCount;
    if (coreCount > 0 && levels.length < 2) {
      throw const BuildingCommonCoreCompositionException(
        'p10.common-core.core-needs-two-levels',
      );
    }
    if (coreCount > 0) {
      for (var index = 0; index < levels.length - 1; index++) {
        if (!_hasInterLevelSlab(project, levels[index].id, levels[index + 1].id)) {
          throw const BuildingCommonCoreCompositionException(
            'p10.common-core.physical-continuity-missing',
          );
        }
      }
    }
    for (final level in levels) {
      if (level.zoneIds.any((id) {
        final kind = project.stores.zones[id]?.kind;
        return kind == ProjectStructuralZoneKind.common ||
            kind == ProjectStructuralZoneKind.service ||
            kind == ProjectStructuralZoneKind.technical;
      })) {
        throw const BuildingCommonCoreCompositionException(
          'p10.common-core.already-composed',
        );
      }
    }

    final spaces = <CommonCoreSpaceProposal>[];
    final openings = <CommonCoreOpeningProposal>[];
    final cores = <CommonCoreVerticalCoreProposal>[];
    final vertical = <CommonCoreVerticalAdjacencyProposal>[];
    final coreHosts = <String, Map<LevelId, String>>{};
    final coreRects = <String, CommonCoreRectMm>{};
    final coreDescriptors = <String, ({String name, VerticalCoreKind kind, VerticalCoreUsage usage})>{};

    for (final level in levels) {
      final corridorKey = 'level:${level.id.value}:corridor';
      spaces.add(CommonCoreSpaceProposal(
        semanticKey: corridorKey,
        levelId: level.id,
        zoneRole: CommonCoreZoneRole.common,
        name: 'Common corridor',
        type: ProjectSpaceType.corridor,
        usage: SpaceUsage.corridor,
        rect: CommonCoreRectMm(
          xMm: layout.originXmm,
          yMm: layout.originYmm,
          widthMm: layout.corridorLengthMm,
          heightMm: parameters.corridorWidthMm,
        ),
      ));

      var topX = layout.originXmm;
      var bottomX = layout.originXmm;

      void addTop({
        required String localKey,
        required String name,
        required ProjectSpaceType type,
        required SpaceUsage usage,
        required CommonCoreZoneRole zoneRole,
        required OpeningKind openingKind,
        String? coreKey,
        VerticalCoreKind? coreKind,
        VerticalCoreUsage? coreUsage,
      }) {
        final rect = CommonCoreRectMm(
          xMm: topX,
          yMm: layout.originYmm + parameters.corridorWidthMm,
          widthMm: layout.coreModuleWidthMm,
          heightMm: layout.coreDepthMm,
        );
        topX = rect.rightMm;
        if (topX > layout.originXmm + layout.corridorLengthMm) {
          throw const BuildingCommonCoreCompositionException(
            'p10.common-core.layout-overflow',
          );
        }
        final key = 'level:${level.id.value}:$localKey';
        spaces.add(CommonCoreSpaceProposal(
          semanticKey: key,
          levelId: level.id,
          zoneRole: zoneRole,
          name: name,
          type: type,
          usage: usage,
          rect: rect,
        ));
        openings.add(CommonCoreOpeningProposal(
          semanticKey: 'opening:$corridorKey:$key',
          levelId: level.id,
          spaceAKey: corridorKey,
          spaceBKey: key,
          kind: openingKind,
        ));
        if (coreKey != null) {
          (coreHosts[coreKey] ??= <LevelId, String>{})[level.id] = key;
          coreRects.putIfAbsent(coreKey, () => rect);
          coreDescriptors.putIfAbsent(
            coreKey,
            () => (
              name: name,
              kind: coreKind!,
              usage: coreUsage!,
            ),
          );
        }
      }

      void addBottom({
        required String localKey,
        required String name,
        required SpaceUsage usage,
      }) {
        final rect = CommonCoreRectMm(
          xMm: bottomX,
          yMm: layout.originYmm - layout.candidateRoomDepthMm,
          widthMm: layout.candidateRoomWidthMm,
          heightMm: layout.candidateRoomDepthMm,
        );
        bottomX = rect.rightMm;
        if (bottomX > layout.originXmm + layout.corridorLengthMm) {
          throw const BuildingCommonCoreCompositionException(
            'p10.common-core.layout-overflow',
          );
        }
        final key = 'level:${level.id.value}:$localKey';
        spaces.add(CommonCoreSpaceProposal(
          semanticKey: key,
          levelId: level.id,
          zoneRole: CommonCoreZoneRole.technical,
          name: name,
          type: ProjectSpaceType.technicalRoom,
          usage: usage,
          rect: rect,
        ));
        openings.add(CommonCoreOpeningProposal(
          semanticKey: 'opening:$corridorKey:$key',
          levelId: level.id,
          spaceAKey: corridorKey,
          spaceBKey: key,
          kind: OpeningKind.door,
        ));
      }

      final policy = parameters.serviceSpacePolicy;
      if (policy.includeCommonHall) {
        addTop(
          localKey: 'common-hall',
          name: 'Common hall',
          type: ProjectSpaceType.hall,
          usage: SpaceUsage.commonHall,
          zoneRole: CommonCoreZoneRole.common,
          openingKind: OpeningKind.openPassage,
        );
      }
      if (policy.includeElevatorHall && parameters.liftCount > 0) {
        addTop(
          localKey: 'elevator-hall',
          name: 'Elevator hall',
          type: ProjectSpaceType.hall,
          usage: SpaceUsage.elevatorHall,
          zoneRole: CommonCoreZoneRole.common,
          openingKind: OpeningKind.openPassage,
        );
      }
      for (var index = 0; index < parameters.stairCount; index++) {
        addTop(
          localKey: 'stair-${index + 1}',
          name: 'Stair ${index + 1}',
          type: ProjectSpaceType.stair,
          usage: SpaceUsage.stairwell,
          zoneRole: CommonCoreZoneRole.common,
          openingKind: OpeningKind.door,
          coreKey: 'stair-${index + 1}',
          coreKind: VerticalCoreKind.shaft,
          coreUsage: VerticalCoreUsage.stairwell,
        );
      }
      for (var index = 0; index < parameters.liftCount; index++) {
        addTop(
          localKey: 'elevator-${index + 1}',
          name: 'Elevator shaft ${index + 1}',
          type: ProjectSpaceType.shaft,
          usage: SpaceUsage.elevatorShaft,
          zoneRole: CommonCoreZoneRole.common,
          openingKind: OpeningKind.serviceOpening,
          coreKey: 'elevator-${index + 1}',
          coreKind: VerticalCoreKind.shaft,
          coreUsage: VerticalCoreUsage.elevatorShaft,
        );
      }
      for (var index = 0; index < parameters.serviceShaftCount; index++) {
        addTop(
          localKey: 'service-shaft-${index + 1}',
          name: 'Service shaft ${index + 1}',
          type: ProjectSpaceType.shaft,
          usage: SpaceUsage.serviceShaft,
          zoneRole: CommonCoreZoneRole.service,
          openingKind: OpeningKind.serviceOpening,
          coreKey: 'service-shaft-${index + 1}',
          coreKind: VerticalCoreKind.serviceShaft,
          coreUsage: VerticalCoreUsage.serviceShaft,
        );
      }
      for (var index = 0; index < parameters.electricalRiserCount; index++) {
        addTop(
          localKey: 'electrical-riser-${index + 1}',
          name: 'Electrical riser ${index + 1}',
          type: ProjectSpaceType.shaft,
          usage: SpaceUsage.electricalRiser,
          zoneRole: CommonCoreZoneRole.service,
          openingKind: OpeningKind.serviceOpening,
          coreKey: 'electrical-riser-${index + 1}',
          coreKind: VerticalCoreKind.riser,
          coreUsage: VerticalCoreUsage.electricalRiser,
        );
      }
      for (var index = 0; index < parameters.telecomRiserCount; index++) {
        addTop(
          localKey: 'telecom-riser-${index + 1}',
          name: 'Telecom riser ${index + 1}',
          type: ProjectSpaceType.shaft,
          usage: SpaceUsage.telecomRiser,
          zoneRole: CommonCoreZoneRole.service,
          openingKind: OpeningKind.serviceOpening,
          coreKey: 'telecom-riser-${index + 1}',
          coreKind: VerticalCoreKind.riser,
          coreUsage: VerticalCoreUsage.telecomRiser,
        );
      }
      if (parameters.includeTechnicalRoom) {
        addBottom(
          localKey: 'technical-room',
          name: 'Technical room candidate',
          usage: SpaceUsage.mechanicalRoom,
        );
      }
      if (policy.includeElectricalRoomCandidate) {
        addBottom(
          localKey: 'electrical-room',
          name: 'Electrical room candidate',
          usage: SpaceUsage.electricalRoom,
        );
      }
      if (policy.includeTelecomRoomCandidate) {
        addBottom(
          localKey: 'telecom-room',
          name: 'Telecom room candidate',
          usage: SpaceUsage.telecomRoom,
        );
      }
      if (policy.includeFireControlRoomCandidate) {
        addBottom(
          localKey: 'fire-control-room',
          name: 'Fire control room candidate',
          usage: SpaceUsage.fireControlRoom,
        );
      }
      if (policy.includeUtilityRoomCandidate) {
        addBottom(
          localKey: 'utility-room',
          name: 'Utility room candidate',
          usage: SpaceUsage.utilityRoom,
        );
      }
    }

    for (final entry in coreHosts.entries) {
      final descriptor = coreDescriptors[entry.key]!;
      cores.add(CommonCoreVerticalCoreProposal(
        semanticKey: entry.key,
        name: descriptor.name,
        kind: descriptor.kind,
        usage: descriptor.usage,
        levelIds: levels.map((level) => level.id),
        hostSpaceKeysByLevel: entry.value,
        footprint: coreRects[entry.key]!.points,
      ));
      for (var index = 0; index < levels.length - 1; index++) {
        final lower = entry.value[levels[index].id]!;
        final upper = entry.value[levels[index + 1].id]!;
        vertical.add(CommonCoreVerticalAdjacencyProposal(
          semanticKey: 'vertical:${entry.key}:${levels[index].id.value}:'
              '${levels[index + 1].id.value}',
          lowerSpaceKey: lower,
          upperSpaceKey: upper,
        ));
      }
    }

    spaces.sort((a, b) => a.semanticKey.compareTo(b.semanticKey));
    openings.sort((a, b) => a.semanticKey.compareTo(b.semanticKey));
    cores.sort((a, b) => a.semanticKey.compareTo(b.semanticKey));
    vertical.sort((a, b) => a.semanticKey.compareTo(b.semanticKey));
    return BuildingCommonCoreCompositionPlan(
      levelIds: levels.map((level) => level.id),
      spaces: spaces,
      openings: openings,
      verticalAdjacencies: vertical,
      verticalCores: cores,
    );
  }
}

final class BuildingCommonCoreCompositionCommand
    implements ReservedProjectCommand {
  BuildingCommonCoreCompositionCommand._({
    required this.target,
    required this.compositionKey,
    required this.parameters,
    required this.layout,
    required this.servedLevelIds,
    required this.plan,
  });

  factory BuildingCommonCoreCompositionCommand.create({
    required ProjectAggregateRoot project,
    required BuildingWizardTarget target,
    required String compositionKey,
    required CommonCoreParameters parameters,
    required CommonCoreLayoutParameters layout,
    required Iterable<LevelId> servedLevelIds,
    BuildingCommonCoreCompositionGenerator generator =
        const BuildingCommonCoreCompositionGenerator(),
  }) {
    final key = compositionKey.trim();
    if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(key)) {
      throw ArgumentError.value(
        compositionKey,
        'compositionKey',
        'Expected a stable semantic key.',
      );
    }
    final frozenLevels = Set<LevelId>.unmodifiable(servedLevelIds);
    final plan = generator.generate(
      project: project,
      target: target,
      parameters: parameters,
      servedLevelIds: frozenLevels,
      layout: layout,
    );
    return BuildingCommonCoreCompositionCommand._(
      target: target,
      compositionKey: key,
      parameters: parameters,
      layout: layout,
      servedLevelIds: frozenLevels,
      plan: plan,
    );
  }

  final BuildingWizardTarget target;
  final String compositionKey;
  final CommonCoreParameters parameters;
  final CommonCoreLayoutParameters layout;
  final Set<LevelId> servedLevelIds;
  final BuildingCommonCoreCompositionPlan plan;

  static const _generator = BuildingCommonCoreCompositionGenerator();

  @override
  String get commandType => 'p10.building.compose-common-core';

  @override
  String get normalizedIntentKey => jsonEncode({
        'schema': 'p10.common-core.v2',
        'projectId': target.projectId.value,
        'siteId': target.siteId.value,
        'buildingId': target.buildingId.value,
        'baseVersion': target.baseVersion.value,
        'compositionKey': compositionKey,
        'parameters': parameters.toCanonicalJson(),
        'layout': layout.toCanonicalJson(),
        'levelIds': plan.levelIds.map((id) => id.value).toList(),
        'planFingerprint': plan.fingerprint,
      });

  String _zoneSlot(LevelId levelId, CommonCoreZoneRole role) =>
      'p10:$compositionKey:zone:${levelId.value}:${role.name}';
  String _spaceSlot(String key) => 'p10:$compositionKey:space:$key';
  String _edgeSlot(String key, int index) =>
      'p10:$compositionKey:boundary:$key:$index';
  String _openingSlot(String key) => 'p10:$compositionKey:$key';
  String _horizontalAdjacencySlot(String key) =>
      'p10:$compositionKey:adjacency:$key';
  String _verticalAdjacencySlot(String key) =>
      'p10:$compositionKey:adjacency:$key';
  String _coreSlot(String key) => 'p10:$compositionKey:core:$key';

  Map<String, ReservedEntityIdKind> get _slots {
    final zonePairs = <String, ReservedEntityIdKind>{};
    for (final space in plan.spaces) {
      zonePairs[_zoneSlot(space.levelId, space.zoneRole)] =
          ReservedEntityIdKind.zone;
    }
    return {
      ...zonePairs,
      for (final space in plan.spaces)
        _spaceSlot(space.semanticKey): ReservedEntityIdKind.space,
      for (final space in plan.spaces)
        for (var index = 0; index < 4; index++)
          _edgeSlot(space.semanticKey, index): ReservedEntityIdKind.boundaryEdge,
      for (final opening in plan.openings)
        _openingSlot(opening.semanticKey): ReservedEntityIdKind.opening,
      for (final opening in plan.openings)
        _horizontalAdjacencySlot(opening.semanticKey):
            ReservedEntityIdKind.spaceAdjacency,
      for (final adjacency in plan.verticalAdjacencies)
        _verticalAdjacencySlot(adjacency.semanticKey):
            ReservedEntityIdKind.spaceAdjacency,
      for (final core in plan.verticalCores)
        _coreSlot(core.semanticKey): ReservedEntityIdKind.verticalCore,
    };
  }

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(factory: factory, entitySlots: _slots);

  @override
  void validateReservation({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    _requireTarget(current, target);
    final regenerated = _generator.generate(
      project: current,
      target: target,
      parameters: parameters,
      servedLevelIds: servedLevelIds,
      layout: layout,
    );
    if (regenerated.fingerprint != plan.fingerprint) {
      throw const BuildingCommonCoreCompositionException(
        'p10.common-core.plan-stale',
      );
    }
    if (reservation.slots.length != _slots.length ||
        reservation.entityIds.length != _slots.length ||
        !reservation.slots.containsAll(_slots.keys)) {
      throw const BuildingCommonCoreCompositionException(
        'p10.common-core.invalid-reservation',
      );
    }
    for (final id in reservation.entityIds) {
      final collision = switch (id) {
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
        throw const BuildingCommonCoreCompositionException(
          'p10.common-core.reservation-collision',
        );
      }
    }
  }

  @override
  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required MutationIdentityReservation reservation,
  }) {
    validateReservation(current: current, reservation: reservation);
    final levels = {...current.stores.levels};
    final zones = {...current.stores.zones};
    final spaces = {...current.stores.spaces};
    final boundaries = {...current.stores.boundaries};
    final openings = {...current.stores.openings};
    final adjacencies = {...current.stores.adjacencies};
    final verticalCores = {...current.stores.verticalCores};
    final spaceIdsByKey = <String, SpaceId>{};
    final spacesByZone = <String, Set<SpaceId>>{};

    for (final proposal in plan.spaces) {
      final id = reservation.entityId<SpaceId>(_spaceSlot(proposal.semanticKey));
      spaceIdsByKey[proposal.semanticKey] = id;
      spaces[id] = ProjectSpaceEntity(
        id: id,
        levelId: proposal.levelId,
        name: proposal.name,
        type: proposal.type,
        usage: proposal.usage,
      );
      final zoneSlot = _zoneSlot(proposal.levelId, proposal.zoneRole);
      (spacesByZone[zoneSlot] ??= <SpaceId>{}).add(id);
      final edgeIds = [
        for (var index = 0; index < 4; index++)
          reservation.entityId<BoundaryEdgeId>(
            _edgeSlot(proposal.semanticKey, index),
          ),
      ];
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

    for (final levelId in plan.levelIds) {
      final currentLevel = levels[levelId]!;
      final addedZoneIds = <ZoneId>{};
      final addedSpaceIds = <SpaceId>{};
      for (final role in CommonCoreZoneRole.values) {
        final slot = _zoneSlot(levelId, role);
        final memberIds = spacesByZone[slot];
        if (memberIds == null || memberIds.isEmpty) continue;
        final zoneId = reservation.entityId<ZoneId>(slot);
        addedZoneIds.add(zoneId);
        addedSpaceIds.addAll(memberIds);
        zones[zoneId] = ProjectStructuralZoneEntity(
          id: zoneId,
          levelId: levelId,
          name: switch (role) {
            CommonCoreZoneRole.common => 'Common area',
            CommonCoreZoneRole.service => 'Service core',
            CommonCoreZoneRole.technical => 'Technical candidates',
          },
          kind: switch (role) {
            CommonCoreZoneRole.common => ProjectStructuralZoneKind.common,
            CommonCoreZoneRole.service => ProjectStructuralZoneKind.service,
            CommonCoreZoneRole.technical => ProjectStructuralZoneKind.technical,
          },
          spaceIds: memberIds,
        );
      }
      levels[levelId] = ProjectLevelEntity(
        id: currentLevel.id,
        buildingId: currentLevel.buildingId,
        name: currentLevel.name,
        levelNumber: currentLevel.levelNumber,
        elevationMm: currentLevel.elevationMm,
        kind: currentLevel.kind,
        floorToFloorHeightMm: currentLevel.floorToFloorHeightMm,
        displayOrder: currentLevel.displayOrder,
        zoneIds: {...currentLevel.zoneIds, ...addedZoneIds},
        spaceIds: {...currentLevel.spaceIds, ...addedSpaceIds},
      );
    }

    for (final proposal in plan.openings) {
      final a = spaceIdsByKey[proposal.spaceAKey]!;
      final b = spaceIdsByKey[proposal.spaceBKey]!;
      final openingId = reservation.entityId<OpeningId>(
        _openingSlot(proposal.semanticKey),
      );
      openings[openingId] = ProjectOpeningEntity(
        id: openingId,
        levelId: proposal.levelId,
        kind: proposal.kind,
        connectedSpaceIds: {a, b},
        widthMm: layout.openingWidthMm,
        heightMm: 2100,
        baseElevationMm: 0,
      );
      final adjacencyId = reservation.entityId<SpaceAdjacencyId>(
        _horizontalAdjacencySlot(proposal.semanticKey),
      );
      adjacencies[adjacencyId] = ProjectSpaceAdjacencyEntity(
        id: adjacencyId,
        spaceAId: a,
        spaceBId: b,
        kind: SpaceAdjacencyKind.opening,
        openingId: openingId,
      );
    }

    for (final proposal in plan.verticalAdjacencies) {
      final adjacencyId = reservation.entityId<SpaceAdjacencyId>(
        _verticalAdjacencySlot(proposal.semanticKey),
      );
      adjacencies[adjacencyId] = ProjectSpaceAdjacencyEntity(
        id: adjacencyId,
        spaceAId: spaceIdsByKey[proposal.lowerSpaceKey]!,
        spaceBId: spaceIdsByKey[proposal.upperSpaceKey]!,
        kind: SpaceAdjacencyKind.vertical,
      );
    }

    for (final proposal in plan.verticalCores) {
      final coreId = reservation.entityId<VerticalCoreId>(
        _coreSlot(proposal.semanticKey),
      );
      verticalCores[coreId] = ProjectVerticalCore(
        id: coreId,
        buildingId: target.buildingId,
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

    final stores = current.stores.copyWith(
      levels: levels,
      zones: zones,
      spaces: spaces,
      boundaries: boundaries,
      openings: openings,
      adjacencies: adjacencies,
      verticalCores: verticalCores,
    );
    final edgeRegistry = current
        .engineeringMetadata.boundaryEdgeIdentityRegistry
        .registerActiveBoundaries(boundaries);
    final proposed = ProjectAggregateRoot(
      id: current.id,
      siteId: current.siteId,
      version: current.version,
      engineeringMetadata: current.engineeringMetadata
          .withBoundaryEdgeIdentityRegistry(edgeRegistry),
      stores: stores,
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
      final EntityId owner = switch (id) {
        ZoneId() => candidate.stores.zones[id]!.levelId,
        SpaceId() =>
          candidate.index.structuralZoneBySpace[id] ?? target.buildingId,
        BoundaryEdgeId() => candidate.index.boundaryEdges[id]!.spaceId,
        VerticalCoreId() => target.buildingId,
        _ => target.buildingId,
      };
      yield CreateEntityOperation(entityId: id, ownerId: owner);
    }
    for (final id in diff.updatedEntityIds) {
      yield UpdateEntityOperation(entityId: id);
    }
  }
}

bool _hasInterLevelSlab(
  ProjectAggregateRoot project,
  LevelId lower,
  LevelId upper,
) =>
    project.stores.slabs.values.any(
      (slab) =>
          slab.kind == SlabKind.interLevel &&
          slab.belowLevelId == lower &&
          slab.aboveLevelId == upper,
    );

void _requireTarget(
  ProjectAggregateRoot project,
  BuildingWizardTarget target,
) {
  final building = project.stores.buildings[target.buildingId];
  if (project.id != target.projectId ||
      project.siteId != target.siteId ||
      building == null ||
      building.siteId != target.siteId) {
    throw const BuildingCommonCoreCompositionException(
      'p10.common-core.foreign-target',
    );
  }
  if (project.version != target.baseVersion) {
    throw StaleProjectMutationException(
      expectedVersion: target.baseVersion,
      currentVersion: project.version,
    );
  }
}
