import 'dart:convert';

import '../../../../domain/boundary_topology.dart';
import '../../../../domain/boundary_host_registry.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/project_service_anchor.dart';
import '../../../../domain/project_service_anchor_integrity.dart';
import '../../../../domain/semantic_sha256.dart';
import '../../project_mutation.dart';
import '../../project_mutation_reservation.dart';
import 'building_generation_parameters.dart';

sealed class ServiceAnchorTarget {
  const ServiceAnchorTarget();
  void validate(ProjectAggregateRoot project);
  Map<String, Object?> toCanonicalJson();
  ProjectServiceAnchor materialize(
      ServiceAnchorRequest request, SiteId siteId, ServiceEntryId id);
  EntityId ownerId(SiteId siteId);
}

final class SiteServiceAnchorTarget extends ServiceAnchorTarget {
  SiteServiceAnchorTarget(
      {required this.point, Iterable<BuildingId> servedBuildingIds = const []})
      : servedBuildingIds = Set.unmodifiable(servedBuildingIds) {
    validateServiceAnchorPoint(point);
  }
  final BoundaryPointMm point;
  final Set<BuildingId> servedBuildingIds;
  @override
  void validate(ProjectAggregateRoot project) =>
      ServiceAnchorRules.site(project, point, servedBuildingIds);
  @override
  Map<String, Object?> toCanonicalJson() => {
        'type': 'site',
        'xMm': point.xMm,
        'yMm': point.yMm,
        'servedBuildingIds': servedBuildingIds.map((id) => id.value).toList()
          ..sort()
      };
  @override
  ProjectServiceAnchor materialize(
          ServiceAnchorRequest request, SiteId siteId, ServiceEntryId id) =>
      ProjectSiteServiceAnchor(
          id: id,
          siteId: siteId,
          name: request.name,
          kind: request.kind,
          point: point,
          servedBuildingIds: servedBuildingIds);
  @override
  EntityId ownerId(SiteId siteId) => siteId;
}

final class SpaceServiceAnchorTarget extends ServiceAnchorTarget {
  const SpaceServiceAnchorTarget(
      {required this.buildingId,
      required this.levelId,
      required this.spaceId,
      required this.point,
      this.heightMm = 0});
  final BuildingId buildingId;
  final LevelId levelId;
  final SpaceId spaceId;
  final BoundaryPointMm point;
  final int heightMm;
  @override
  void validate(ProjectAggregateRoot project) => ServiceAnchorRules.space(
      project, buildingId, levelId, spaceId, point, heightMm);
  @override
  Map<String, Object?> toCanonicalJson() => {
        'type': 'space',
        'buildingId': buildingId.value,
        'levelId': levelId.value,
        'spaceId': spaceId.value,
        'xMm': point.xMm,
        'yMm': point.yMm,
        'heightMm': heightMm
      };
  @override
  ProjectServiceAnchor materialize(
          ServiceAnchorRequest request, SiteId siteId, ServiceEntryId id) =>
      ProjectSpaceServiceAnchor(
          id: id,
          siteId: siteId,
          name: request.name,
          kind: request.kind,
          buildingId: buildingId,
          levelId: levelId,
          spaceId: spaceId,
          point: point,
          heightMm: heightMm);
  @override
  EntityId ownerId(SiteId siteId) => spaceId;
}

final class BoundaryServiceAnchorTarget extends ServiceAnchorTarget {
  const BoundaryServiceAnchorTarget(
      {required this.buildingId,
      required this.levelId,
      required this.spaceId,
      required this.binding,
      this.heightMm = 0});
  final BuildingId buildingId;
  final LevelId levelId;
  final SpaceId spaceId;
  final ServiceAnchorBoundaryBinding binding;
  final int heightMm;
  @override
  void validate(ProjectAggregateRoot project) {
    ServiceAnchorRules.boundary(
        project, buildingId, levelId, spaceId, binding, heightMm);
  }

  @override
  Map<String, Object?> toCanonicalJson() => {
        'type': 'boundary',
        'buildingId': buildingId.value,
        'levelId': levelId.value,
        'spaceId': spaceId.value,
        'heightMm': heightMm,
        'binding': binding.toCanonicalJson()
      };
  @override
  ProjectServiceAnchor materialize(
          ServiceAnchorRequest request, SiteId siteId, ServiceEntryId id) =>
      ProjectBoundaryServiceAnchor(
          id: id,
          siteId: siteId,
          name: request.name,
          kind: request.kind,
          buildingId: buildingId,
          levelId: levelId,
          spaceId: spaceId,
          heightMm: heightMm);
  @override
  EntityId ownerId(SiteId siteId) => spaceId;
}

final class ServiceAnchorRequest {
  ServiceAnchorRequest(
      {required this.key,
      required String name,
      required this.kind,
      required this.target})
      : name = name.trim() {
    _key(key);
    if (this.name.isEmpty ||
        isServiceEntryKind(kind) != (target is BoundaryServiceAnchorTarget)) {
      throw ArgumentError(
          'A named entry requires a durable wall target; areas use Site/Space targets.');
    }
  }
  final String key;
  final String name;
  final ProjectServiceAnchorKind kind;
  final ServiceAnchorTarget target;
  Map<String, Object?> toCanonicalJson() => {
        'key': key,
        'name': name,
        'kind': kind.name,
        'target': target.toCanonicalJson()
      };
}

final class ServiceAnchorCompositionPlan {
  ServiceAnchorCompositionPlan._(
      {required this.projectId,
      required this.siteId,
      required this.baseVersion,
      required this.compositionKey,
      required Iterable<ServiceAnchorRequest> requests})
      : requests = List.unmodifiable(requests);
  final ProjectId projectId;
  final SiteId siteId;
  final LocalProjectVersion baseVersion;
  final String compositionKey;
  final List<ServiceAnchorRequest> requests;
  String get canonicalRequest => jsonEncode({
        'schema': 'p10.service-anchors.v1',
        'projectId': projectId.value,
        'siteId': siteId.value,
        'baseVersion': baseVersion.value,
        'compositionKey': compositionKey,
        'requests': requests.map((r) => r.toCanonicalJson()).toList()
      });
  String get semanticFingerprint => semanticSha256Hex(canonicalRequest);
}

/// Pure P10.10 generator. Locations are explicit architectural input; it never
/// guesses equipment, supply capacity, protection, circuits or routing.
final class ServiceAnchorCompositionGenerator {
  const ServiceAnchorCompositionGenerator();
  ServiceAnchorCompositionPlan generate(
      {required ProjectAggregateRoot project,
      required String compositionKey,
      required Iterable<ServiceAnchorRequest> requests}) {
    _key(compositionKey);
    final ordered = requests.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (ordered.length > 256 ||
        ordered.map((r) => r.key).toSet().length != ordered.length) {
      throw const ServiceAnchorException('p10.service-anchor.invalid-request');
    }
    final locations = <String>{};
    for (final request in ordered) {
      request.target.validate(project);
      final location = jsonEncode({
        'kind': request.kind.name,
        'target': request.target.toCanonicalJson()
      });
      if (!locations.add(location)) {
        throw const ServiceAnchorException(
            'p10.service-anchor.duplicate-request');
      }
    }
    return ServiceAnchorCompositionPlan._(
        projectId: project.id,
        siteId: project.siteId,
        baseVersion: project.version,
        compositionKey: compositionKey,
        requests: ordered);
  }

  /// Consumes P10.1's pending anchor intent once real canonical hosts exist.
  /// Every requested kind needs an explicit compatible location; none is lost
  /// through an implicit default or a guessed building/room identity.
  ServiceAnchorCompositionPlan forBuilding(
      {required ProjectAggregateRoot project,
      required BuildingId buildingId,
      required String compositionKey,
      required ServiceAnchorParameters parameters,
      required Map<BuildingServiceAnchorKind, ServiceAnchorTarget> locations}) {
    if (project.stores.buildings[buildingId]?.siteId != project.siteId ||
        locations.length != parameters.kinds.length ||
        !locations.keys.toSet().containsAll(parameters.kinds)) {
      throw const ServiceAnchorException(
          'p10.service-anchor.building-locations-incomplete');
    }
    final requests = <ServiceAnchorRequest>[];
    for (final kind in parameters.kinds.toList()
      ..sort((a, b) => a.name.compareTo(b.name))) {
      final target = locations[kind]!;
      final servesBuilding = switch (target) {
        SiteServiceAnchorTarget() =>
          target.servedBuildingIds.contains(buildingId),
        SpaceServiceAnchorTarget() => target.buildingId == buildingId,
        BoundaryServiceAnchorTarget() => target.buildingId == buildingId,
      };
      if (!servesBuilding) {
        throw const ServiceAnchorException(
            'p10.service-anchor.building-target-mismatch');
      }
      requests.add(ServiceAnchorRequest(
          key: kind.name,
          name: _label(kind),
          kind: ProjectServiceAnchorKind.values.byName(kind.name),
          target: target));
    }
    return generate(
        project: project, compositionKey: compositionKey, requests: requests);
  }
}

final class ServiceAnchorCompositionCommand implements ReservedProjectCommand {
  const ServiceAnchorCompositionCommand(this.plan);
  factory ServiceAnchorCompositionCommand.create(
          {required ProjectAggregateRoot project,
          required String compositionKey,
          required Iterable<ServiceAnchorRequest> requests}) =>
      ServiceAnchorCompositionCommand(const ServiceAnchorCompositionGenerator()
          .generate(
              project: project,
              compositionKey: compositionKey,
              requests: requests));
  final ServiceAnchorCompositionPlan plan;
  @override
  String get commandType => 'p10.service-anchors.compose';
  @override
  String get normalizedIntentKey => plan.canonicalRequest;
  String _slot(ServiceAnchorRequest request) =>
      jsonEncode(['p10.service-anchor', plan.compositionKey, request.key]);
  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(factory: factory, entitySlots: {
        for (final r in plan.requests)
          _slot(r): ReservedEntityIdKind.serviceEntry
      });
  @override
  void validateReservation(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    if (current.id != plan.projectId || current.siteId != plan.siteId) {
      throw const ServiceAnchorException('p10.service-anchor.foreign-target');
    }
    if (current.version != plan.baseVersion) {
      throw StaleProjectMutationException(
          expectedVersion: plan.baseVersion, currentVersion: current.version);
    }
    if (reservation.slots.length != plan.requests.length ||
        reservation.entityIds.length != plan.requests.length ||
        !reservation.slots.containsAll(plan.requests.map(_slot))) {
      throw const ServiceAnchorException(
          'p10.service-anchor.invalid-reservation');
    }
    for (final request in plan.requests) {
      request.target.validate(current);
      final id = reservation.entityId<ServiceEntryId>(_slot(request));
      final layout = current.engineeringMetadata.siteLayout;
      if (layout.serviceAnchors.containsKey(id) ||
          layout.sharedAnchors.containsKey(id) ||
          current.engineeringMetadata.boundaryHostedObjectRegistry.references
              .containsKey(
                  BoundaryHostedObjectRegistry.serviceEntryObjectKey(id))) {
        throw const ServiceAnchorException(
            'p10.service-anchor.reservation-collision');
      }
    }
  }

  @override
  ProjectCommandCandidate buildCandidate(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    validateReservation(current: current, reservation: reservation);
    final anchors = {...current.engineeringMetadata.siteLayout.serviceAnchors};
    var hosts = current.engineeringMetadata.boundaryHostedObjectRegistry;
    for (final request in plan.requests) {
      final id = reservation.entityId<ServiceEntryId>(_slot(request));
      anchors[id] = request.target.materialize(request, current.siteId, id);
      if (request.target case final BoundaryServiceAnchorTarget target) {
        hosts = hosts.putServiceEntry(
            id: id,
            host: target.binding.host,
            offsetMm: target.binding.offsetMm);
      }
    }
    final metadata = current.engineeringMetadata.copyWith(
        siteLayout: current.engineeringMetadata.siteLayout
            .copyWith(serviceAnchors: anchors),
        boundaryHostedObjectRegistry: hosts);
    // Full physical/identity validation happens on the same canonical root.
    final proposed = ProjectAggregateRoot(
        id: current.id,
        siteId: current.siteId,
        version: current.version,
        stores: current.stores,
        engineeringMetadata: metadata);
    return ProjectCommandCandidate.fromState(
        state: ProjectMutableState.fromProject(proposed),
        affectedEntityIds: {
          current.siteId,
          ...reservation.entityIds,
          for (final request in plan.requests)
            request.target.ownerId(current.siteId)
        });
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations(
      {required ProjectAggregateRoot before,
      required ProjectAggregateRoot candidate,
      required MutationIdentityReservation reservation}) sync* {
    for (final request in plan.requests) {
      yield CreateEntityOperation(
          entityId: reservation.entityId<ServiceEntryId>(_slot(request)),
          ownerId: request.target.ownerId(before.siteId));
    }
  }
}

void _key(String value) {
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9._-]{0,95}$').hasMatch(value)) {
    throw ArgumentError('A canonical semantic key is required.');
  }
}

String _label(BuildingServiceAnchorKind kind) => switch (kind) {
      BuildingServiceAnchorKind.electricalEntry => 'Electrical service entry',
      BuildingServiceAnchorKind.telecomEntry => 'Telecom / fiber entry',
      BuildingServiceAnchorKind.fireBackboneEntry => 'Fire backbone entry',
      BuildingServiceAnchorKind.intercomCctvEntry =>
        'Intercom / CCTV backbone entry',
      BuildingServiceAnchorKind.generatorArea => 'Generator area',
      BuildingServiceAnchorKind.transformerArea =>
        'Transformer / substation area',
      BuildingServiceAnchorKind.pvInverterArea => 'PV / inverter area',
      BuildingServiceAnchorKind.batteryUpsArea => 'Battery / UPS area',
      BuildingServiceAnchorKind.evChargingArea => 'EV charging area',
      BuildingServiceAnchorKind.externalLightingFeeder =>
        'External lighting feeder',
    };
