import '../../composition_provenance_command.dart';
import 'p10_generation_evidence.dart';
import 'dart:convert';

import '../../../../domain/boundary_topology.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/project_orientation.dart';
import '../../../../domain/project_site_layout.dart';
import '../../../../domain/rectilinear_polygon_relations.dart';
import '../../../../domain/semantic_sha256.dart';
import '../../project_mutation.dart';
import '../../project_mutation_reservation.dart';
import 'building_generation_parameters.dart';
import 'building_shell_composition.dart';
import 'cottage_composition.dart';
import 'residential_tower_composition.dart';

/// One building's layout uses Building-local coordinates. Only parameters'
/// placement supplies the translation/orientation into the Site frame.
final class SiteBuildingSlot {
  SiteBuildingSlot(
      {required this.key,
      required this.parameters,
      required this.layout,
      Iterable<TowerApartmentRequest> apartments = const []})
      : apartments = List.unmodifiable(apartments) {
    _key(key);
  }
  final String key;
  final BuildingGenerationParameters parameters;
  final BuildingCompositionLayout layout;
  final List<TowerApartmentRequest> apartments;
}

final class SharedSiteAnchorRequest {
  SharedSiteAnchorRequest(
      {required this.key,
      required String name,
      required this.kind,
      required this.point,
      Iterable<String> buildingKeys = const [],
      Iterable<BuildingId> existingBuildingIds = const []})
      : name = name.trim(),
        buildingKeys = Set.unmodifiable(buildingKeys),
        existingBuildingIds = Set.unmodifiable(existingBuildingIds) {
    _key(key);
    for (final key in this.buildingKeys) {
      _key(key);
    }
    if (this.name.isEmpty ||
        this.buildingKeys.length + this.existingBuildingIds.length < 2) {
      throw ArgumentError(
          'A shared anchor must explicitly serve at least two buildings.');
    }
  }
  final String key;
  final String name;
  final ProjectSiteAnchorKind kind;
  final BoundaryPointMm point;
  final Set<String> buildingKeys;
  final Set<BuildingId> existingBuildingIds;
  Map<String, Object?> toCanonicalJson() => {
        'key': key,
        'name': name,
        'kind': kind.name,
        'xMm': point.xMm,
        'yMm': point.yMm,
        'buildingKeys': buildingKeys.toList()..sort(),
        'existingBuildingIds':
            existingBuildingIds.map((id) => id.value).toList()..sort(),
      };
}

final class SiteBuildingProposal {
  const SiteBuildingProposal._(
      {required this.slot,
      required this.placement,
      required this.command,
      required this.buildingSlot,
      required this.fingerprint});
  final SiteBuildingSlot slot;
  final ProjectBuildingSitePlacement placement;
  final ReservedProjectCommand command;
  final String buildingSlot;
  final String fingerprint;
}

/// An immutable proposal, without allocated persistent identities or a second
/// building graph. The existing cottage/tower generators own building content.
final class SiteCompositionPlan {
  SiteCompositionPlan._(
      {required this.compositionKey,
      required this.projectId,
      required this.siteId,
      required this.baseVersion,
      required Iterable<SiteBuildingProposal> buildings,
      required Iterable<SharedSiteAnchorRequest> anchors})
      : buildings = List.unmodifiable(buildings),
        anchors = List.unmodifiable(anchors);
  final String compositionKey;
  final ProjectId projectId;
  final SiteId siteId;
  final LocalProjectVersion baseVersion;
  final List<SiteBuildingProposal> buildings;
  final List<SharedSiteAnchorRequest> anchors;
  String get semanticFingerprint => semanticSha256Hex(jsonEncode({
        'schema': 'p10.site.v1',
        'compositionKey': compositionKey,
        'projectId': projectId.value,
        'siteId': siteId.value,
        'baseVersion': baseVersion.value,
        'buildings': [
          for (final proposal in buildings)
            {
              'key': proposal.slot.key,
              'requestFingerprint': proposal.slot.parameters.requestFingerprint,
              'childFingerprint': proposal.fingerprint,
              'placement': proposal.placement.toCanonicalJson(),
            }
        ],
        'sharedAnchors':
            anchors.map((anchor) => anchor.toCanonicalJson()).toList(),
      }));
}

final class SiteCompositionGenerator {
  const SiteCompositionGenerator();
  SiteCompositionPlan generate(
      {required ProjectAggregateRoot project,
      required String compositionKey,
      required Iterable<SiteBuildingSlot> slots,
      Iterable<SharedSiteAnchorRequest> anchors = const [],
      bool allowSingleBuilding = false}) {
    _key(compositionKey);
    final site = project.stores.sites[project.siteId]!;
    final ordered = slots.toList()..sort((a, b) => a.key.compareTo(b.key));
    final shared = anchors.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (ordered.isEmpty ||
        ordered.length > 64 ||
        ordered.length + site.buildingIds.length <
            (allowSingleBuilding ? 1 : 2) ||
        ordered.map((slot) => slot.key).toSet().length != ordered.length ||
        shared.map((anchor) => anchor.key).toSet().length != shared.length) {
      throw const SiteLayoutException('p10.site.invalid-slots');
    }
    final existing = project.engineeringMetadata.siteLayout;
    if (!existing.placements.keys.toSet().containsAll(site.buildingIds)) {
      throw const SiteLayoutException('p10.site.existing-placement-missing');
    }
    final proposals = <SiteBuildingProposal>[];
    final footprints = [...existing.placements.values];
    for (final slot in ordered) {
      final p = slot.parameters;
      if (p.siteId != project.siteId) {
        throw const SiteLayoutException('p10.site.foreign-site');
      }
      final placement = ProjectBuildingSitePlacement(
          xMm: p.placement.xMm,
          yMm: p.placement.yMm,
          orientation: p.placement.orientation,
          widthMm: slot.layout.footprintWidthMm,
          depthMm: slot.layout.footprintDepthMm);
      if (footprints.any((other) =>
          RectilinearPolygonRelations.overlapsInterior(
              placement.siteFootprint, other.siteFootprint))) {
        throw const SiteLayoutException('p10.site.overlapping-footprints');
      }
      footprints.add(placement);
      // Existing architectural generators receive an explicit local origin.
      // Site placement is applied by the canonical projection, never baked into
      // P9 geometry, opening hosts or typical-floor baseline fingerprints.
      final local = BuildingGenerationParameters(
          kind: p.kind,
          siteId: p.siteId,
          displayName: p.displayName,
          placement: BuildingSitePlacement(
              xMm: 0,
              yMm: 0,
              orientation: ProjectEngineeringNorth.fromDegrees(0)),
          levelStack: p.levelStack,
          commonCore: p.commonCore,
          serviceAnchors: p.serviceAnchors,
          typicalFloor: p.typicalFloor,
          template: p.template,
          schemaVersion: p.schemaVersion,
          generatorVersion: p.generatorVersion);
      final ReservedProjectCommand command;
      final String buildingSlot;
      final String fingerprint;
      if (p.kind == BuildingCompositionKind.detachedHouse) {
        if (slot.apartments.isNotEmpty) {
          throw const SiteLayoutException('p10.site.cottage-apartment-slots');
        }
        final child = CottageCompositionCommand.create(
            project: project,
            compositionKey: slot.key,
            parameters: local,
            layout: slot.layout,
            allowExistingBuildings: true);
        command = child;
        buildingSlot = child.buildingSlot;
        fingerprint = child.plan.semanticFingerprint;
      } else if (p.kind == BuildingCompositionKind.residentialTower) {
        final child = ResidentialTowerCompositionCommand.create(
            project: project,
            compositionKey: slot.key,
            parameters: local,
            layout: slot.layout,
            requests: slot.apartments,
            allowExistingBuildings: true);
        command = child;
        buildingSlot = child.buildingSlot;
        fingerprint = child.plan.semanticFingerprint;
      } else {
        throw const SiteLayoutException('p10.site.unsupported-building-kind');
      }
      proposals.add(SiteBuildingProposal._(
          slot: slot,
          placement: placement,
          command: command,
          buildingSlot: buildingSlot,
          fingerprint: fingerprint));
    }
    final keys = ordered.map((slot) => slot.key).toSet();
    for (final anchor in shared) {
      if (!keys.containsAll(anchor.buildingKeys) ||
          !site.buildingIds.containsAll(anchor.existingBuildingIds)) {
        throw const SiteLayoutException('p10.site.anchor-target-missing');
      }
      // Validate point/grid and typed shared ownership before reservation.
      if (anchor.point.xMm.abs() > 1000000000 ||
          anchor.point.yMm.abs() > 1000000000 ||
          anchor.point.xMm % 10 != 0 ||
          anchor.point.yMm % 10 != 0) {
        throw const SiteLayoutException('p10.site.invalid-anchor-point');
      }
    }
    for (final point in [
      ...existing.sharedAnchors.values.map((a) => a.point),
      ...shared.map((a) => a.point)
    ]) {
      if (footprints.any((p) {
        final rect = p.siteFootprint;
        return point.xMm > rect.minX &&
            point.xMm < rect.maxX &&
            point.yMm > rect.minY &&
            point.yMm < rect.maxY;
      })) {
        throw const SiteLayoutException('p10.site.anchor-inside-building');
      }
    }
    return SiteCompositionPlan._(
        compositionKey: compositionKey,
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
        buildings: proposals,
        anchors: shared);
  }
}

final class SiteCompositionCommand implements CompositionProvenanceSource {
  @override
  CompositionGenerationEvidence get generationEvidence => p10GenerationEvidence(
      'p10.site.v1',
      plan.semanticFingerprint,
      {for (final b in plan.buildings) b.slot.key: b.slot.parameters});

  const SiteCompositionCommand._(this.plan);
  factory SiteCompositionCommand.create(
          {required ProjectAggregateRoot project,
          required String compositionKey,
          required Iterable<SiteBuildingSlot> slots,
          Iterable<SharedSiteAnchorRequest> anchors = const [],
          bool allowSingleBuilding = false,
          SiteCompositionGenerator generator =
              const SiteCompositionGenerator()}) =>
      SiteCompositionCommand._(generator.generate(
          project: project,
          compositionKey: compositionKey,
          slots: slots,
          anchors: anchors,
          allowSingleBuilding: allowSingleBuilding));
  final SiteCompositionPlan plan;
  @override
  String get commandType => 'p10.site.compose';
  @override
  String get normalizedIntentKey => jsonEncode(
      {'schema': 'p10.site.v1', 'planFingerprint': plan.semanticFingerprint});
  String _scope(SiteBuildingProposal building) =>
      'building:${building.slot.key}';
  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.combineEntityReservations({
        for (final building in plan.buildings)
          _scope(building): building.command.reserveIdentities(factory),
        'site': MutationIdentityReservation.allocate(
            factory: factory,
            entitySlots: {
              for (final anchor in plan.anchors)
                anchor.key: ReservedEntityIdKind.serviceEntry,
            }),
      });
  @override
  void validateReservation(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    if (current.id != plan.projectId || current.siteId != plan.siteId) {
      throw const SiteLayoutException('p10.site.foreign-target');
    }
    if (current.version != plan.baseVersion) {
      throw StaleProjectMutationException(
          expectedVersion: plan.baseVersion, currentVersion: current.version);
    }
    var expected = plan.anchors.length;
    for (final building in plan.buildings) {
      final child = reservation.selectEntityScope(_scope(building));
      building.command
          .validateReservation(current: current, reservation: child);
      expected += child.slots.length;
    }
    final anchors = reservation.selectEntityScope('site');
    if (reservation.slots.length != expected ||
        reservation.entityIds.length != expected ||
        anchors.slots.length != plan.anchors.length ||
        !anchors.slots.containsAll(plan.anchors.map((a) => a.key))) {
      throw const SiteLayoutException('p10.site.invalid-reservation');
    }
    for (final anchor in plan.anchors) {
      final id = anchors.entityId<ServiceEntryId>(anchor.key);
      if (current.engineeringMetadata.siteLayout.sharedAnchors
              .containsKey(id) ||
          current.engineeringMetadata.siteLayout.serviceAnchors
              .containsKey(id)) {
        throw const SiteLayoutException('p10.site.reservation-collision');
      }
    }
  }

  @override
  ProjectCommandCandidate buildCandidate(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    validateReservation(current: current, reservation: reservation);
    var proposed = current;
    final placements = {...current.engineeringMetadata.siteLayout.placements};
    final ids = <String, BuildingId>{};
    for (final building in plan.buildings) {
      final child = reservation.selectEntityScope(_scope(building));
      final state = building.command
          .buildCandidate(current: proposed, reservation: child)
          .resolveState(proposed);
      proposed = ProjectAggregateRoot(
          id: current.id,
          siteId: current.siteId,
          version: current.version,
          engineeringMetadata: state.engineeringMetadata,
          stores: state.stores);
      final id = child.entityId<BuildingId>(building.buildingSlot);
      ids[building.slot.key] = id;
      placements[id] = building.placement;
    }
    final shared = {...current.engineeringMetadata.siteLayout.sharedAnchors};
    final anchors = reservation.selectEntityScope('site');
    for (final anchor in plan.anchors) {
      final id = anchors.entityId<ServiceEntryId>(anchor.key);
      shared[id] = ProjectSharedSiteAnchor(
          id: id,
          siteId: current.siteId,
          name: anchor.name,
          kind: anchor.kind,
          point: anchor.point,
          servedBuildingIds: {
            ...anchor.existingBuildingIds,
            for (final key in anchor.buildingKeys) ids[key]!
          });
    }
    final layout = current.engineeringMetadata.siteLayout
        .copyWith(placements: placements, sharedAnchors: shared);
    proposed = ProjectAggregateRoot(
        id: current.id,
        siteId: current.siteId,
        version: current.version,
        stores: proposed.stores,
        engineeringMetadata:
            proposed.engineeringMetadata.copyWith(siteLayout: layout));
    final definitions = proposed.engineeringMetadata
        .generationProvenanceRegistry.typicalFloorDefinitions.keys
        .where((id) => !current.engineeringMetadata.generationProvenanceRegistry
            .typicalFloorDefinitions
            .containsKey(id));
    return ProjectCommandCandidate.fromState(
        state: ProjectMutableState.fromProject(proposed),
        affectedEntityIds: {
          ...ProjectEntityDiff.between(current.stores, proposed.stores)
              .affectedEntityIds,
          ...shared.keys,
          ...definitions
        });
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations(
      {required ProjectAggregateRoot before,
      required ProjectAggregateRoot candidate,
      required MutationIdentityReservation reservation}) sync* {
    final diff = ProjectEntityDiff.between(before.stores, candidate.stores);
    for (final id in diff.addedEntityIds) {
      final EntityId? owner = switch (id) {
        BuildingId() => candidate.siteId,
        LevelId() => candidate.stores.levels[id]!.buildingId,
        ZoneId() => candidate.stores.zones[id]!.levelId,
        SpaceId() => candidate.index.structuralZoneBySpace[id] ??
            candidate.stores.spaces[id]!.levelId,
        BoundaryEdgeId() => candidate.index.boundaryEdges[id]!.spaceId,
        SlabId() => candidate.stores.slabs[id]!.buildingId,
        VerticalCoreId() => candidate.stores.verticalCores[id]!.buildingId,
        OpeningId() => candidate.stores.openings[id]!.levelId,
        SpaceAdjacencyId() => candidate
            .stores.spaces[candidate.stores.adjacencies[id]!.spaceAId]!.levelId,
        _ => null,
      };
      yield CreateEntityOperation(entityId: id, ownerId: owner);
    }
    for (final id in diff.updatedEntityIds) {
      yield UpdateEntityOperation(entityId: id);
    }
    for (final id in candidate.engineeringMetadata.generationProvenanceRegistry
        .typicalFloorDefinitions.keys) {
      if (!before.engineeringMetadata.generationProvenanceRegistry
          .typicalFloorDefinitions
          .containsKey(id)) {
        yield CreateEntityOperation(
            entityId: id,
            ownerId: candidate.engineeringMetadata.generationProvenanceRegistry
                .typicalFloorDefinitions[id]!.buildingId);
      }
    }
    for (final id
        in candidate.engineeringMetadata.siteLayout.sharedAnchors.keys) {
      if (!before.engineeringMetadata.siteLayout.sharedAnchors
          .containsKey(id)) {
        yield CreateEntityOperation(entityId: id, ownerId: candidate.siteId);
      }
    }
  }
}

void _key(String value) {
  if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(value)) {
    throw ArgumentError('A canonical semantic key is required.');
  }
}
