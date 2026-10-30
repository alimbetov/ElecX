import '../../composition_provenance_command.dart';
import 'p10_generation_evidence.dart';
import 'dart:convert';
import 'dart:math' as math;

import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/level_apartment_composition.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/project_space_semantics.dart';
import '../../../../domain/semantic_sha256.dart';
import '../../../../domain/typical_floor.dart';
import '../../project_mutation.dart';
import '../../project_mutation_reservation.dart';
import '../../typical_floor_commands.dart';
import '../apartment/apartment_candidate_set_service.dart';
import '../apartment/apartment_wizard_parameters.dart';
import '../wizard_contracts.dart';
import 'apartment_placement.dart';
import 'building_generation_parameters.dart';
import 'building_level_stack_generator.dart';
import 'building_shell_composition.dart';
import 'building_template_catalog.dart';
import 'level_apartment_composition.dart';

final class TowerCompositionException implements Exception {
  const TowerCompositionException(this.code);
  final String code;
  @override
  String toString() => code;
}

final class TowerApartmentRequest {
  TowerApartmentRequest(
      {required this.key, required String displayName, required this.input})
      : displayName = displayName.trim() {
    if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(key) ||
        this.displayName.isEmpty) {
      throw ArgumentError(
          'A tower apartment requires a stable key and display name.');
    }
  }
  final String key;
  final String displayName;
  final ApartmentRequestInput input;
}

final class TowerApartmentPlacement {
  const TowerApartmentPlacement(
      {required this.request,
      required this.candidateSet,
      required this.transform});
  final TowerApartmentRequest request;
  final ApartmentCandidateSet candidateSet;
  final ApartmentPlacementTransform transform;
}

/// An ID-free tower plan. P9 owns every accepted apartment; P10 supplies its
/// rigid placement and the enclosing architectural shell.
final class ResidentialTowerCompositionPlan {
  ResidentialTowerCompositionPlan._(
      {required this.shell,
      required this.templateBinding,
      required Iterable<TowerApartmentPlacement> apartments})
      : apartments = List.unmodifiable(apartments);
  final BuildingShellCompositionPlan shell;
  final BuildingTemplateBinding templateBinding;
  final List<TowerApartmentPlacement> apartments;
  Iterable<String> get residentialLevelKeys => shell.levelStack.levels
      .where((l) => l.parameters.kind == ProjectLevelKind.residential)
      .map((l) => l.parameters.generationKey);
  String get semanticFingerprint => semanticSha256Hex(jsonEncode({
        'schema': 'p10.tower.v1',
        'shell': shell.semanticFingerprint,
        'catalogFingerprint': templateBinding.catalogFingerprint,
        'templateFingerprint': templateBinding.definition.fingerprint,
        'apartments': [
          for (final slot in apartments)
            {
              'key': slot.request.key,
              'displayName': slot.request.displayName,
              'candidateSetFingerprint':
                  slot.candidateSet.candidateSetFingerprint,
              'candidateFingerprint':
                  slot.candidateSet.recommendedCandidate.candidateFingerprint,
              'transform': slot.transform.toCanonicalJson(),
            }
        ],
      }));
}

final class ResidentialTowerCompositionGenerator {
  const ResidentialTowerCompositionGenerator(
      {this.apartments = const ApartmentCandidateSetService()});
  final ApartmentCandidateSetService apartments;

  ResidentialTowerCompositionPlan generate(
      {required ProjectAggregateRoot project,
      required String compositionKey,
      required BuildingGenerationParameters parameters,
      required BuildingCompositionLayout layout,
      required Iterable<TowerApartmentRequest> requests,
      bool allowExistingBuildings = false}) {
    void require(bool value, String code) {
      if (!value) throw TowerCompositionException('p10.tower.$code');
    }

    require(RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(compositionKey),
        'invalid-key');
    require(parameters.kind == BuildingCompositionKind.residentialTower,
        'wrong-kind');
    require(
        project.siteId == parameters.siteId &&
            project.stores.sites.containsKey(parameters.siteId) &&
            (allowExistingBuildings ||
                project.stores.sites[parameters.siteId]!.buildingIds.isEmpty),
        'empty-site-required');
    require(
        parameters.placement.orientation.milliDegreesClockwiseFromPositiveY ==
            0,
        'rotated-site-placement-deferred');
    require(parameters.commonCore.isCurrentContract, 'common-core-v2-required');
    final binding = BuildingTemplateCatalog.residentialV1().bind(parameters);
    final levels = parameters.levelStack.levels;
    final residential =
        levels.where((l) => l.kind == ProjectLevelKind.residential).toList();
    require(residential.length >= 2, 'repeated-residential-levels-required');
    require(levels.last.kind == ProjectLevelKind.roof, 'roof-required');
    require(
        levels.where((l) => l.kind == ProjectLevelKind.technical).length <= 1,
        'technical-level-count');
    var previousRole = -1;
    for (final level in levels) {
      final role = switch (level.kind) {
        ProjectLevelKind.basement => 0,
        ProjectLevelKind.ground => 1,
        ProjectLevelKind.residential => 2,
        ProjectLevelKind.technical => 3,
        ProjectLevelKind.roof => 4,
        ProjectLevelKind.unknown => -1,
      };
      require(role >= previousRole && role >= 0, 'invalid-level-order');
      previousRole = role;
      require(level.floorToFloorHeightMm >= 2100 + layout.slabThicknessMm,
          'storey-too-short');
    }
    final core = parameters.commonCore;
    require(
        core.stairCount > 0 &&
            core.liftCount > 0 &&
            core.electricalRiserCount > 0 &&
            core.telecomRiserCount > 0,
        'mandatory-cores-required');
    final selected = parameters.typicalFloor;
    require(
        selected == null ||
            (selected.levelGenerationKeys.length == residential.length &&
                selected.levelGenerationKeys
                    .containsAll(residential.map((l) => l.generationKey))),
        'typical-floor-selection-mismatch');
    final ordered = requests.toList()..sort((a, b) => a.key.compareTo(b.key));
    require(
        ordered.length >= 2 &&
            ordered.length <= 32 &&
            ordered.map((r) => r.key).toSet().length == ordered.length,
        'invalid-apartment-slots');
    final shell = BuildingShellCompositionPlan(
        compositionKey: compositionKey,
        generatorVersion: 'p10.tower-shell.v1',
        parameters: parameters,
        layout: layout,
        levelStack: const BuildingLevelStackGenerator().generate(
            buildingGenerationKey: compositionKey,
            parameters: parameters.levelStack),
        commonCoreLevelGenerationKeys: levels
            .where((l) => l.kind != ProjectLevelKind.roof)
            .map((l) => l.generationKey),
        slabs: [
          for (var i = 0; i < levels.length - 1; i++)
            BuildingSlabProposal(
                semanticKey: jsonEncode([
                  'slab',
                  levels[i].generationKey,
                  levels[i + 1].generationKey
                ]),
                belowLevelGenerationKey: levels[i].generationKey,
                aboveLevelGenerationKey: levels[i + 1].generationKey),
        ]);
    final common = layout.commonCore;
    final left = parameters.placement.xMm;
    final bottom = parameters.placement.yMm;
    final right = left + layout.footprintWidthMm;
    final top = bottom + layout.footprintDepthMm;
    require(
        common.originXmm >= left &&
            common.originYmm >= bottom &&
            common.originXmm + common.corridorLengthMm <= right &&
            common.originYmm + core.corridorWidthMm + common.coreDepthMm <=
                top &&
            common.originYmm -
                    (shell.candidateRoomCountPerLevel > 0
                        ? common.candidateRoomDepthMm
                        : 0) >=
                bottom &&
            shell.topSpaceCountPerLevel * common.coreModuleWidthMm <=
                common.corridorLengthMm,
        'common-layout-outside-footprint');
    for (final dimension in [
      left,
      bottom,
      layout.footprintWidthMm,
      layout.footprintDepthMm,
      common.originXmm,
      common.originYmm,
      common.corridorLengthMm,
      core.corridorWidthMm,
      common.coreModuleWidthMm,
      common.coreDepthMm,
      common.candidateRoomWidthMm,
      common.candidateRoomDepthMm
    ]) {
      require(dimension % 10 == 0, 'off-grid-layout');
    }
    var cursor = common.originXmm +
        shell.candidateRoomCountPerLevel * common.candidateRoomWidthMm +
        1000;
    final placements = <TowerApartmentPlacement>[];
    for (final request in ordered) {
      final result = apartments.generateForSite(
          input: request.input,
          project: project,
          target: SiteWizardTarget(
              projectId: project.id,
              siteId: project.siteId,
              baseVersion: project.version));
      require(result.accepted && result.candidateSet != null, 'p9-rejected');
      final set = result.candidateSet!;
      final geometry = set.recommendedCandidate.rankedCandidate.candidate;
      final points = [
        for (final space in [
          ...geometry.interiorSpaces,
          ...geometry.exteriorAppendages
        ])
          ...space.polygon.vertices
      ];
      final entry = geometry.openingIntents
          .singleWhere((i) => i.kind == GeometryOpeningKind.primaryEntry);
      ApartmentPlacementTransform? transform;
      for (var turns = 0; turns < 4; turns++) {
        final rotation = ApartmentPlacementTransform(
            xMm: 0, yMm: 0, clockwiseQuarterTurns: turns);
        final rotated = points.map(rotation.apply).toList();
        final minX = rotated.map((p) => p.xMm).reduce(math.min);
        final maxX = rotated.map((p) => p.xMm).reduce(math.max);
        final minY = rotated.map((p) => p.yMm).reduce(math.min);
        final maxY = rotated.map((p) => p.yMm).reduce(math.max);
        final a = rotation.apply(entry.hostSegment.start);
        final b = rotation.apply(entry.hostSegment.end);
        if (a.yMm != maxY || b.yMm != maxY) continue;
        require(
            cursor + maxX - minX <=
                    common.originXmm + common.corridorLengthMm &&
                cursor + maxX - minX <= right &&
                common.originYmm - (maxY - minY) >= bottom,
            'apartment-layout-overflow');
        transform = ApartmentPlacementTransform(
            xMm: cursor - minX,
            yMm: common.originYmm - maxY,
            clockwiseQuarterTurns: turns);
        cursor += maxX - minX + 1000;
        break;
      }
      require(transform != null, 'primary-entry-placement-unavailable');
      placements.add(TowerApartmentPlacement(
          request: request, candidateSet: set, transform: transform!));
    }
    return ResidentialTowerCompositionPlan._(
        shell: shell, templateBinding: binding, apartments: placements);
  }
}

/// One parent reservation and one canonical Apply. Structural staging and child
/// candidates are immutable views; neither is committed to a separate session.
final class ResidentialTowerCompositionCommand
    implements CompositionProvenanceSource {
  @override
  CompositionGenerationEvidence get generationEvidence => p10GenerationEvidence(
      'p10.tower.v1',
      plan.semanticFingerprint,
      {plan.shell.compositionKey: plan.shell.parameters});

  ResidentialTowerCompositionCommand._(this._basis, this.plan,
      {bool allowExistingBuildings = false})
      : _shell = BuildingShellCompositionCommand(
            projectId: _basis.id,
            siteId: _basis.siteId,
            baseVersion: _basis.version,
            plan: plan.shell,
            revalidatePlan: () => plan.shell.semanticFingerprint,
            commandType: 'p10.tower.shell',
            allowExistingBuildings: allowExistingBuildings);
  factory ResidentialTowerCompositionCommand.create(
          {required ProjectAggregateRoot project,
          required String compositionKey,
          required BuildingGenerationParameters parameters,
          required BuildingCompositionLayout layout,
          required Iterable<TowerApartmentRequest> requests,
          bool allowExistingBuildings = false,
          ResidentialTowerCompositionGenerator generator =
              const ResidentialTowerCompositionGenerator()}) =>
      ResidentialTowerCompositionCommand._(
          project,
          generator.generate(
              project: project,
              compositionKey: compositionKey,
              parameters: parameters,
              layout: layout,
              requests: requests,
              allowExistingBuildings: allowExistingBuildings),
          allowExistingBuildings: allowExistingBuildings);
  String get buildingSlot => jsonEncode(['shell', _shell.buildingSlot]);
  final ProjectAggregateRoot _basis;
  final ResidentialTowerCompositionPlan plan;
  final BuildingShellCompositionCommand _shell;
  static const _definitionSlot = 'definition';
  @override
  String get commandType => 'p10.tower.compose';
  @override
  String get normalizedIntentKey => jsonEncode({
        'schema': 'p10.tower.v1',
        'projectId': _basis.id.value,
        'siteId': _basis.siteId.value,
        'baseVersion': _basis.version.value,
        'planFingerprint': plan.semanticFingerprint
      });
  MutationIdentityReservation _view(MutationIdentityReservation parent,
          String scope, Iterable<String> slots) =>
      parent.selectEntitySlots({
        for (final slot in slots) slot: jsonEncode([scope, slot])
      });
  ProjectAggregateRoot _state(
      ProjectAggregateRoot current, ProjectCommandCandidate candidate) {
    final state = candidate.resolveState(current);
    return ProjectAggregateRoot(
        id: current.id,
        siteId: current.siteId,
        version: current.version,
        stores: state.stores,
        engineeringMetadata: state.engineeringMetadata);
  }

  ProjectAggregateRoot _stage(ProjectAggregateRoot current,
          MutationIdentityReservation reservation) =>
      _state(
          current,
          _shell.buildCandidate(
              current: current,
              reservation:
                  _view(reservation, 'shell', _shell.reservationSlots.keys)));
  Iterable<(String, LevelApartmentCompositionCommand)> _children(
      ProjectAggregateRoot stage,
      MutationIdentityReservation shellReservation) sync* {
    final buildingId =
        shellReservation.entityId<BuildingId>(_shell.buildingSlot);
    for (final level in plan.shell.levelStack.levels) {
      if (level.parameters.kind != ProjectLevelKind.residential) continue;
      final levelId = shellReservation.entityId<LevelId>(level.reservationSlot);
      final corridor = stage.stores.levels[levelId]!.spaceIds.singleWhere(
          (id) => stage.stores.spaces[id]!.usage == SpaceUsage.corridor);
      yield (
        level.parameters.generationKey,
        LevelApartmentCompositionCommand(
            project: stage,
            target: LevelWizardTarget(
                projectId: stage.id,
                siteId: stage.siteId,
                buildingId: buildingId,
                levelId: levelId,
                baseVersion: stage.version),
            compositionKey: 'residential.apartments',
            slots: [
              for (final placement in plan.apartments)
                ApartmentPlacementSlot.fromCandidateSet(
                    key: placement.request.key,
                    displayName: placement.request.displayName,
                    candidateSet: placement.candidateSet,
                    selection: placement.candidateSet.selectionFor(
                        placement.candidateSet.recommendedCandidate),
                    transform: placement.transform,
                    accessSpaceId: corridor),
            ])
      );
    }
  }

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) {
    final shell = _shell.reserveIdentities(factory);
    final stage = _state(
        _basis, _shell.buildCandidate(current: _basis, reservation: shell));
    return MutationIdentityReservation.combineEntityReservations({
      'shell': shell,
      for (final (key, child) in _children(stage, shell))
        key: child.reserveIdentities(factory),
      'lineage': MutationIdentityReservation.allocate(
          factory: factory,
          entitySlots: {
            _definitionSlot: ReservedEntityIdKind.typicalFloorDefinition
          }),
    });
  }

  @override
  void validateReservation(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    final shell = _view(reservation, 'shell', _shell.reservationSlots.keys);
    _shell.validateReservation(current: current, reservation: shell);
    final stage = _stage(current, reservation);
    final expected = {
      for (final slot in _shell.reservationSlots.keys)
        jsonEncode(['shell', slot]),
      jsonEncode(['lineage', _definitionSlot])
    };
    for (final (key, child) in _children(stage, shell)) {
      expected.addAll(
          child.reservationSlots.keys.map((slot) => jsonEncode([key, slot])));
      child.validateReservation(
          current: stage,
          reservation: _view(reservation, key, child.reservationSlots.keys));
    }
    if (reservation.slots.length != expected.length ||
        !reservation.slots.containsAll(expected) ||
        reservation.entityIds.length != expected.length) {
      throw const TowerCompositionException('p10.tower.invalid-reservation');
    }
    final definitionId = reservation.entityId<TypicalFloorDefinitionId>(
        jsonEncode(['lineage', _definitionSlot]));
    if (current.engineeringMetadata.generationProvenanceRegistry
        .typicalFloorDefinitions
        .containsKey(definitionId)) {
      throw const TowerCompositionException('p10.tower.reservation-collision');
    }
  }

  @override
  ProjectCommandCandidate buildCandidate(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    validateReservation(current: current, reservation: reservation);
    final shellReservation =
        _view(reservation, 'shell', _shell.reservationSlots.keys);
    final shell = _stage(current, reservation);
    var proposed = shell;
    final floorEntities = <LevelId, Map<String, EntityId>>{};
    final floorKeys = <LevelId, String>{};
    for (final (key, child) in _children(shell, shellReservation)) {
      proposed = _state(
          proposed,
          child.buildCandidate(
              current: proposed,
              reservation:
                  _view(reservation, key, child.reservationSlots.keys)));
      final levelId = child.target.levelId;
      floorKeys[levelId] = key;
      floorEntities[levelId] = _floorEntities(shell, proposed, levelId);
    }
    final first = floorEntities.entries.first;
    final definitionId = reservation.entityId<TypicalFloorDefinitionId>(
        jsonEncode(['lineage', _definitionSlot]));
    final fingerprint = TypicalFloorPattern.fingerprint(
        stores: proposed.stores, entities: first.value);
    final definition = TypicalFloorDefinition(
        id: definitionId,
        buildingId: shellReservation.entityId<BuildingId>(_shell.buildingSlot),
        templateId: plan.templateBinding.reference.id,
        templateVersion: plan.templateBinding.reference.templateVersion,
        definitionKey: plan.shell.parameters.typicalFloor?.definitionKey ??
            'residential.standard',
        patternFingerprint: fingerprint,
        entityKinds: {
          for (final entry in first.value.entries)
            entry.key: typicalFloorEntityKind(entry.value)
        });
    proposed = _state(
        proposed,
        RegisterTypicalFloorCommand(definition: definition, instances: [
          for (final entry in floorEntities.entries)
            TypicalFloorInstance(
                levelId: entry.key,
                definitionId: definitionId,
                generationKey: floorKeys[entry.key]!,
                patternFingerprint: fingerprint,
                entities: entry.value),
        ]).buildCandidate(proposed));
    return ProjectCommandCandidate.fromState(
        state: ProjectMutableState.fromProject(proposed),
        affectedEntityIds: {
          ...ProjectEntityDiff.between(current.stores, proposed.stores)
              .affectedEntityIds,
          definitionId
        });
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations(
      {required ProjectAggregateRoot before,
      required ProjectAggregateRoot candidate,
      required MutationIdentityReservation reservation}) sync* {
    yield* _shell.semanticOperations(
        before: before,
        candidate: candidate,
        reservation: _view(reservation, 'shell', _shell.reservationSlots.keys));
    yield CreateEntityOperation(
        entityId: reservation.entityId<TypicalFloorDefinitionId>(
            jsonEncode(['lineage', _definitionSlot])),
        ownerId: _view(reservation, 'shell', _shell.reservationSlots.keys)
            .entityId<BuildingId>(_shell.buildingSlot));
  }
}

Map<String, EntityId> _floorEntities(
    ProjectAggregateRoot shell, ProjectAggregateRoot project, LevelId levelId) {
  final level = shell.stores.levels[levelId]!;
  final entities = <String, EntityId>{'level': levelId};
  for (final id in level.zoneIds) {
    entities['common.zone.${shell.stores.zones[id]!.kind.name}'] = id;
  }
  var index = 0;
  for (final id in level.spaceIds) {
    final key = 'common.space.${index++}';
    entities[key] = id;
    final edges = shell.stores.boundaries[id]!.orderedEdgeIds;
    for (var i = 0; i < edges.length; i++) {
      entities['$key.edge.$i'] = edges[i];
    }
  }
  index = 0;
  for (final opening
      in shell.stores.openings.values.where((o) => o.levelId == levelId)) {
    entities['common.opening.${index++}'] = opening.id;
  }
  index = 0;
  for (final relation in shell.stores.adjacencies.values.where((a) =>
      level.spaceIds.contains(a.spaceAId) &&
      level.spaceIds.contains(a.spaceBId))) {
    entities['common.adjacency.${index++}'] = relation.id;
  }
  final registry = project.engineeringMetadata.generationProvenanceRegistry;
  final parent = registry.levelCompositions.values
      .singleWhere((m) => m.levelId == levelId);
  for (final child in parent.apartments.entries) {
    for (final provenance in registry.entities.values
        .where((e) => e.generationId == child.value.generationId)) {
      entities['apartment.${child.key}.${provenance.generationKey}'] =
          provenance.entityId;
    }
  }
  final reverse = {
    for (final entry in entities.entries) entry.value: entry.key
  };
  final relations = parent.generatedAdjacencies.values
      .map((id) => project.stores.adjacencies[id]!)
      .toList()
    ..sort((a, b) {
      String key(ProjectSpaceAdjacencyEntity value) {
        final keys = [reverse[value.spaceAId]!, reverse[value.spaceBId]!]
          ..sort();
        return jsonEncode([keys, value.kind.name]);
      }

      return key(a).compareTo(key(b));
    });
  for (var i = 0; i < relations.length; i++) {
    entities['contact.$i'] = relations[i].id;
  }
  return entities;
}
