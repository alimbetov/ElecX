import '../../composition_provenance_command.dart';
import 'p10_generation_evidence.dart';
import 'dart:convert';

import '../../../../domain/boundary_host_migration.dart';
import '../../../../domain/boundary_topology.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/project_service_anchor.dart';
import '../../../../domain/project_site_layout.dart';
import '../../../../domain/project_space_semantics.dart';
import '../../../../domain/semantic_sha256.dart';
import '../../project_mutation.dart';
import '../../project_mutation_reservation.dart';
import '../apartment/apartment_wizard_parameters.dart';
import '../wizard_contracts.dart';
import 'building_template_catalog.dart';
import 'residential_tower_composition.dart';
import 'service_anchor_composition.dart';
import 'site_composition.dart';

enum BuildingWizardWallSide { left, right, bottom, top }

/// Explicit transient location in one generated building. Applied entries retain
/// only canonical typed owners and the existing P7 durable physical host.
final class BuildingWizardServiceAnchorInput {
  const BuildingWizardServiceAnchorInput(
      {required this.key,
      required this.name,
      required this.kind,
      required this.buildingKey,
      this.sitePoint,
      this.levelKey = 'ground',
      this.spaceUsage = SpaceUsage.corridor,
      this.side = BuildingWizardWallSide.left,
      this.offsetMm = 300,
      this.heightMm = 1200});
  final String key;
  final String name;
  final ProjectServiceAnchorKind kind;
  final String buildingKey;
  final BoundaryPointMm? sitePoint;
  final String levelKey;
  final SpaceUsage spaceUsage;
  final BuildingWizardWallSide side;
  final int offsetMm;
  final int heightMm;
  Map<String, Object?> toCanonicalJson() => {
        'key': key,
        'name': name.trim(),
        'kind': kind.name,
        'buildingKey': buildingKey,
        if (sitePoint != null) ...{
          'xMm': sitePoint!.xMm,
          'yMm': sitePoint!.yMm
        } else ...{
          'levelKey': levelKey,
          'spaceUsage': spaceUsage.name,
          'side': side.name,
          'offsetMm': offsetMm,
          'heightMm': heightMm
        }
      };
  ServiceAnchorRequest resolve(ProjectAggregateRoot project,
      Map<String, BuildingId> buildings, List<SiteBuildingSlot> slots) {
    final building = buildings[buildingKey];
    if (building == null || isServiceEntryKind(kind) != (sitePoint == null)) {
      throw const ServiceAnchorException('p10.wizard.invalid-service-target');
    }
    if (sitePoint != null) {
      return ServiceAnchorRequest(
          key: key,
          name: name,
          kind: kind,
          target: SiteServiceAnchorTarget(
              point: sitePoint!, servedBuildingIds: [building]));
    }
    final source = slots
        .singleWhere((s) => s.key == buildingKey)
        .parameters
        .levelStack
        .levels
        .where((l) => l.generationKey == levelKey)
        .toList();
    if (source.length != 1) {
      throw const ServiceAnchorException('p10.wizard.unresolved-level');
    }
    // Transient source slot -> generated LevelId join; display numbers/names
    // and persistent-ID encodings never select the physical owner.
    final levels = project.stores.buildings[building]!.levelIds
        .map((id) => project.stores.levels[id]!)
        .where((l) =>
            l.displayOrder == source.single.ordinal &&
            l.kind == source.single.kind)
        .toList();
    if (levels.length != 1) {
      throw const ServiceAnchorException('p10.wizard.unresolved-level');
    }
    final spaces = levels.single.spaceIds
        .where((id) => project.stores.spaces[id]!.usage == spaceUsage)
        .toList();
    if (spaces.length != 1) {
      throw const ServiceAnchorException('p10.wizard.ambiguous-service-space');
    }
    final space = spaces.single;
    final edges = project.stores.boundaries[space]!.edges.values.toList();
    final xs = edges.expand((e) => [e.start.xMm, e.end.xMm]).toList()..sort();
    final ys = edges.expand((e) => [e.start.yMm, e.end.yMm]).toList()..sort();
    final walls = edges
        .where((e) => switch (side) {
              BuildingWizardWallSide.left =>
                e.start.xMm == xs.first && e.end.xMm == xs.first,
              BuildingWizardWallSide.right =>
                e.start.xMm == xs.last && e.end.xMm == xs.last,
              BuildingWizardWallSide.bottom =>
                e.start.yMm == ys.first && e.end.yMm == ys.first,
              BuildingWizardWallSide.top =>
                e.start.yMm == ys.last && e.end.yMm == ys.last,
            })
        .toList();
    if (walls.length != 1) {
      throw const ServiceAnchorException('p10.wizard.ambiguous-service-wall');
    }
    return ServiceAnchorRequest(
        key: key,
        name: name,
        kind: kind,
        target: BoundaryServiceAnchorTarget(
            buildingId: building,
            levelId: levels.single.id,
            spaceId: space,
            heightMm: heightMm,
            binding: ServiceAnchorBoundaryBinding(
                host: BoundaryEdgeHostRef(
                    spaceId: space, edgeId: walls.single.id),
                offsetMm: offsetMm)));
  }
}

/// ID-free candidate evidence. Proposed structure remains the existing P10 plan;
/// the only materialized candidate is the shared frozen reserved preview.
final class BuildingCompositionCandidate {
  BuildingCompositionCandidate(
      {required this.architecture,
      required Iterable<BuildingWizardServiceAnchorInput> serviceAnchors,
      Map<BuildingId, ProjectBuildingSitePlacement> existingPlacements =
          const {}})
      : serviceAnchors = List.unmodifiable(
            serviceAnchors.toList()..sort((a, b) => a.key.compareTo(b.key))),
        existingPlacements = Map.unmodifiable(existingPlacements),
        templates = Map.unmodifiable({
          for (final b in architecture.plan.buildings)
            b.slot.key:
                BuildingTemplateCatalog.residentialV1().bind(b.slot.parameters)
        }) {
    if (this.serviceAnchors.length > 256 ||
        this.serviceAnchors.map((a) => a.key).toSet().length !=
            this.serviceAnchors.length) {
      throw ArgumentError('Duplicate service request key.');
    }
    for (final anchor in this.serviceAnchors) {
      if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(anchor.key) ||
          anchor.name.trim().isEmpty ||
          isServiceEntryKind(anchor.kind) != (anchor.sitePoint == null) ||
          anchor.offsetMm < 0 ||
          anchor.heightMm < 0) {
        throw const ServiceAnchorException('p10.wizard.invalid-service-input');
      }
      if (anchor.sitePoint != null) {
        validateServiceAnchorPoint(anchor.sitePoint!);
      }
    }
    for (final b in architecture.plan.buildings) {
      final selected =
          b.slot.parameters.serviceAnchors.kinds.map((k) => k.name).toSet();
      final supplied = this
          .serviceAnchors
          .where((a) => a.buildingKey == b.slot.key)
          .map((a) => a.kind.name)
          .toSet();
      if (selected.length != supplied.length ||
          !selected.containsAll(supplied)) {
        throw const ServiceAnchorException(
            'p10.wizard.service-locations-incomplete');
      }
    }
    if (this.serviceAnchors.any((a) => !templates.containsKey(a.buildingKey))) {
      throw const ServiceAnchorException('p10.wizard.foreign-service-building');
    }
  }
  static const generatorVersion = 'p10.11.v1';
  final SiteCompositionCommand architecture;
  final List<BuildingWizardServiceAnchorInput> serviceAnchors;
  final Map<BuildingId, ProjectBuildingSitePlacement> existingPlacements;
  final Map<String, BuildingTemplateBinding> templates;
  int get deterministicRank => 0;
  final List<WizardValidationIssue> validationEvidence = const [
    WizardValidationIssue(
        code: 'p10.wizard.architecture-only',
        message: 'Architectural reservations without engineering sizing.',
        severity: WizardIssueSeverity.info)
  ];
  String get requestFingerprint => semanticSha256Hex(canonicalRequest);
  String get canonicalRequest => jsonEncode({
        'schema': generatorVersion,
        'projectId': architecture.plan.projectId.value,
        'siteId': architecture.plan.siteId.value,
        'baseVersion': architecture.plan.baseVersion.value,
        'compositionKey': architecture.plan.compositionKey,
        'buildings': [
          for (final b in architecture.plan.buildings)
            {
              'key': b.slot.key,
              'parameters': b.slot.parameters.requestFingerprint,
              'layout': b.slot.layout.toCanonicalJson(),
              'apartments': [
                for (final a
                    in b.slot.apartments.toList()
                      ..sort((a, b) => a.key.compareTo(b.key)))
                  {
                    'key': a.key,
                    'name': a.displayName,
                    'request': const ApartmentRequestNormalizer()
                        .normalize(a.input)
                        .request!
                        .intentFingerprint,
                  }
              ],
            }
        ],
        'sharedAnchors':
            architecture.plan.anchors.map((a) => a.toCanonicalJson()).toList(),
        'services': serviceAnchors.map((a) => a.toCanonicalJson()).toList(),
        'placements': [
          for (final id
              in existingPlacements.keys.toList()
                ..sort((a, b) => a.value.compareTo(b.value)))
            {
              'buildingId': id.value,
              ...existingPlacements[id]!.toCanonicalJson()
            }
        ]
      });
  String get candidateFingerprint => semanticSha256Hex(jsonEncode({
        'request': requestFingerprint,
        'architecture': architecture.plan.semanticFingerprint,
        'templates': {
          for (final e in templates.entries) e.key: e.value.templateFingerprint
        },
        'generatorVersion': generatorVersion
      }));
  List<String> get apartmentCandidateFingerprints => List.unmodifiable([
        for (final b in architecture.plan.buildings)
          if (b.command is ResidentialTowerCompositionCommand)
            for (final a in (b.command as ResidentialTowerCompositionCommand)
                .plan
                .apartments)
              a.candidateSet.recommendedCandidate.candidateFingerprint
      ]);
}

/// One reserved architecture + service command; no feature-local mutation,
/// history, ID factory or persistence owner.
final class BuildingCompositionWizardCommand
    implements CompositionProvenanceSource {
  @override
  CompositionGenerationEvidence get generationEvidence => p10GenerationEvidence(
      BuildingCompositionCandidate.generatorVersion,
      composition.candidateFingerprint,
      {
        for (final b in composition.architecture.plan.buildings)
          b.slot.key: b.slot.parameters
      },
      canonicalRequest: composition.canonicalRequest);

  BuildingCompositionWizardCommand(
      {required this.basis, required this.composition});
  final ProjectAggregateRoot basis;
  final BuildingCompositionCandidate composition;
  @override
  String get commandType => 'p10.wizard.compose';
  @override
  String get normalizedIntentKey => jsonEncode({
        'requestFingerprint': composition.requestFingerprint,
        'candidateFingerprint': composition.candidateFingerprint
      });
  ProjectAggregateRoot _architecture(
      ProjectAggregateRoot current, MutationIdentityReservation reservation) {
    final staged =
        withExplicitWizardPlacements(current, composition.existingPlacements);
    final state = composition.architecture
        .buildCandidate(current: staged, reservation: reservation)
        .resolveState(staged);
    return ProjectAggregateRoot(
        id: current.id,
        siteId: current.siteId,
        version: current.version,
        stores: state.stores,
        engineeringMetadata: state.engineeringMetadata);
  }

  ServiceAnchorCompositionCommand _services(
      ProjectAggregateRoot stage, MutationIdentityReservation reservation) {
    final ids = {
      for (final b in composition.architecture.plan.buildings)
        b.slot.key: reservation
            .selectEntityScope('building:${b.slot.key}')
            .entityId<BuildingId>(b.buildingSlot)
    };
    return ServiceAnchorCompositionCommand.create(
        project: stage,
        compositionKey: 'wizard.services',
        requests: composition.serviceAnchors.map((a) => a.resolve(
            stage,
            ids,
            composition.architecture.plan.buildings
                .map((b) => b.slot)
                .toList())));
  }

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) {
    final architecture = composition.architecture.reserveIdentities(factory);
    final stage = _architecture(basis, architecture);
    return MutationIdentityReservation.combineEntityReservations({
      'architecture': architecture,
      'services': _services(stage, architecture).reserveIdentities(factory)
    });
  }

  @override
  void validateReservation(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    if (current.id != basis.id || current.siteId != basis.siteId) {
      throw const ServiceAnchorException('p10.wizard.foreign-target');
    }
    if (current.version != basis.version) {
      throw StaleProjectMutationException(
          expectedVersion: basis.version, currentVersion: current.version);
    }
    final architecture = reservation.selectEntityScope('architecture'),
        services = reservation.selectEntityScope('services');
    if (reservation.slots.length !=
            architecture.slots.length + services.slots.length ||
        reservation.entityIds.length != reservation.slots.length) {
      throw const ServiceAnchorException('p10.wizard.invalid-reservation');
    }
    final stage = _architecture(current, architecture);
    _services(stage, architecture)
        .validateReservation(current: stage, reservation: services);
  }

  @override
  ProjectCommandCandidate buildCandidate(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    validateReservation(current: current, reservation: reservation);
    final architecture = reservation.selectEntityScope('architecture');
    final stage = _architecture(current, architecture);
    final child = _services(stage, architecture).buildCandidate(
        current: stage, reservation: reservation.selectEntityScope('services'));
    final state = child.resolveState(stage);
    return ProjectCommandCandidate.fromState(state: state, affectedEntityIds: {
      current.siteId,
      ...ProjectEntityDiff.between(current.stores, state.stores)
          .affectedEntityIds,
      ...child.affectedEntityIds,
      ...composition.existingPlacements.keys
    });
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations(
      {required ProjectAggregateRoot before,
      required ProjectAggregateRoot candidate,
      required MutationIdentityReservation reservation}) sync* {
    yield* composition.architecture.semanticOperations(
        before: before,
        candidate: candidate,
        reservation: reservation.selectEntityScope('architecture'));
    for (final anchor
        in candidate.engineeringMetadata.siteLayout.serviceAnchors.values) {
      if (!before.engineeringMetadata.siteLayout.serviceAnchors
          .containsKey(anchor.id)) {
        yield CreateEntityOperation(
            entityId: anchor.id, ownerId: candidate.siteId);
      }
    }
    for (final id in composition.existingPlacements.keys) {
      yield UpdateEntityOperation(entityId: id);
    }
  }
}

ProjectAggregateRoot withExplicitWizardPlacements(ProjectAggregateRoot project,
    Map<BuildingId, ProjectBuildingSitePlacement> placements) {
  if (placements.isEmpty) return project;
  for (final id in placements.keys) {
    if (project.stores.buildings[id]?.siteId != project.siteId ||
        project.engineeringMetadata.siteLayout.placements.containsKey(id)) {
      throw const ServiceAnchorException(
          'p10.wizard.existing-placement-not-unplaced');
    }
  }
  return ProjectAggregateRoot(
      id: project.id,
      siteId: project.siteId,
      version: project.version,
      stores: project.stores,
      engineeringMetadata: project.engineeringMetadata.copyWith(
          siteLayout: project.engineeringMetadata.siteLayout.copyWith(
              placements: {
            ...project.engineeringMetadata.siteLayout.placements,
            ...placements
          })));
}
