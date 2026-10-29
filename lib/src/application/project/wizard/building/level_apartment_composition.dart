import 'dart:convert';

import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/boundary_host_migration.dart';
import '../../../../domain/boundary_topology.dart';
import '../../../../domain/boundary_opening_profile_validation.dart';
import '../../../../domain/generation_provenance_integrity.dart';
import '../../../../domain/level_apartment_composition.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_entity_stores_copy.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/project_space_semantics.dart';
import '../../../../domain/rectilinear_polygon_relations.dart';
import '../../../../domain/semantic_sha256.dart';
import '../../project_mutation.dart';
import '../../project_mutation_reservation.dart';
import '../apartment/apartment_candidate_set_service.dart';
import '../apartment/apartment_canonical_materializer.dart';
import '../apartment/apartment_generation_provenance_builder.dart';
import '../apartment/apartment_wizard_parameters.dart';
import '../wizard_contracts.dart';
import 'apartment_placement.dart';

final class LevelApartmentSlotRequest {
  const LevelApartmentSlotRequest(
      {required this.key,
      required this.displayName,
      required this.request,
      required this.transform,
      required this.accessSpaceId});
  final String key;
  final String displayName;
  final ApartmentRequestInput request;
  final ApartmentPlacementTransform transform;
  final SpaceId accessSpaceId;
}

/// P10.5 adapter. P9 owns apartment generation/qualification and ranking.
final class LevelApartmentCompositionGenerator {
  const LevelApartmentCompositionGenerator(
      {this.apartments = const ApartmentCandidateSetService()});
  final ApartmentCandidateSetService apartments;

  LevelApartmentCompositionCommand generate(
      {required ProjectAggregateRoot project,
      required LevelWizardTarget target,
      required String compositionKey,
      required Iterable<LevelApartmentSlotRequest> requests}) {
    final slots = <ApartmentPlacementSlot>[];
    final ordered = requests.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (ordered.isEmpty || ordered.length > 128) {
      throw const ApartmentCompositionException(
          'p10.apartments.invalid-slot-count');
    }
    for (final request in ordered) {
      final result = apartments.generateForComposition(
          input: request.request, target: target, project: project);
      final set = result.candidateSet;
      if (!result.accepted || set == null) {
        throw const ApartmentCompositionException('p10.apartments.p9-rejected');
      }
      slots.add(ApartmentPlacementSlot.fromCandidateSet(
          key: request.key,
          displayName: request.displayName,
          candidateSet: set,
          selection: set.selectionFor(set.recommendedCandidate),
          transform: request.transform,
          accessSpaceId: request.accessSpaceId));
    }
    return LevelApartmentCompositionCommand(
        project: project,
        target: target,
        compositionKey: compositionKey,
        slots: slots);
  }
}

/// Immutable composition proposal. The shared reservation/preview coordinator
/// owns allocation, stale checks, atomic Apply and the single Undo transaction.
/// No Wizard UI, persistence or secondary mutation session lives here.
final class LevelApartmentCompositionCommand implements ReservedProjectCommand {
  LevelApartmentCompositionCommand._(
      {required this.target,
      required this.compositionKey,
      required this.apartments,
      required List<_Entry> entries,
      required List<_Contact> contacts})
      : _entries = List.unmodifiable(entries),
        _contacts = List.unmodifiable(contacts);

  factory LevelApartmentCompositionCommand(
      {required ProjectAggregateRoot project,
      required LevelWizardTarget target,
      required String compositionKey,
      required Iterable<ApartmentPlacementSlot> slots}) {
    _requireTarget(project, target);
    final key = compositionKey.trim();
    final ordered = slots.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(key) ||
        ordered.isEmpty ||
        ordered.length > 128 ||
        ordered.map((slot) => slot.key).toSet().length != ordered.length) {
      throw const ApartmentCompositionException('p10.apartments.invalid-slots');
    }
    final placed = ordered.map(PlacedApartmentCandidate.new).toList();
    final level = project.stores.levels[target.levelId]!;
    final existing = {
      for (final id in level.spaceIds) id: _polygon(project, id)
    };
    final entries = <_Entry>[];
    for (final apartment in placed) {
      final accessId = apartment.slot.accessSpaceId;
      final space = project.stores.spaces[accessId];
      final zone =
          project.stores.zones[project.index.structuralZoneBySpace[accessId]];
      if (space == null ||
          space.levelId != target.levelId ||
          zone?.kind != ProjectStructuralZoneKind.common ||
          (space.type != ProjectSpaceType.corridor &&
              space.type != ProjectSpaceType.hall)) {
        throw const ApartmentCompositionException(
            'p10.apartments.common-access-missing');
      }
      final intents = apartment.geometry.openingIntents;
      final primary = intents.indexed
          .where((entry) => entry.$2.kind == GeometryOpeningKind.primaryEntry)
          .toList();
      if (primary.length != 1) {
        throw const ApartmentCompositionException(
            'p10.apartments.invalid-primary-entry');
      }
      final intent = primary.single.$2;
      final door = _doorInterval(intent.hostSegment);
      final matching = project.stores.boundaries[accessId]!.edges.values
          .where((edge) => RectilinearPolygonRelations.containsSegment(
              GeometrySegmentMm(start: edge.start, end: edge.end), door))
          .toList();
      if (matching.length != 1) {
        throw const ApartmentCompositionException(
            'p10.apartments.entry-not-on-common-boundary');
      }
      final edge = matching.single;
      final offsets = _offsets(edge, door);
      for (final reference in project
          .engineeringMetadata.boundaryHostedObjectRegistry
          .forSpace(accessId)) {
        if (reference.objectKind == BoundaryHostedObjectKind.opening &&
            reference.host.edgeId == edge.id &&
            reference.startOffsetMm != null &&
            reference.endOffsetMm != null &&
            reference.startOffsetMm! < offsets.end &&
            reference.endOffsetMm! > offsets.start) {
          throw const ApartmentCompositionException(
              'p10.apartments.entry-overlap');
        }
      }
      entries.add(_Entry(apartment.slot.key, intent.fromSpaceKey!,
          primary.single.$1, accessId, edge.id, offsets.start, offsets.end));
      for (final generated in _spaces(apartment.geometry)) {
        for (final old in existing.values) {
          if (RectilinearPolygonRelations.overlapsInterior(
              generated.polygon, old)) {
            throw const ApartmentCompositionException(
                'p10.apartments.collision');
          }
        }
      }
    }
    for (var a = 0; a < entries.length; a++) {
      for (var b = a + 1; b < entries.length; b++) {
        if (entries[a].edgeId == entries[b].edgeId &&
            entries[a].start < entries[b].end &&
            entries[b].start < entries[a].end) {
          throw const ApartmentCompositionException(
              'p10.apartments.entry-overlap');
        }
      }
    }
    final contacts = <_Contact>[];
    for (var a = 0; a < placed.length; a++) {
      final left = placed[a];
      final entry = entries[a];
      for (final room in _spaces(left.geometry)) {
        for (final old in existing.entries) {
          if (RectilinearPolygonRelations.sharedSegments(
                  room.polygon, old.value)
              .isEmpty) {
            continue;
          }
          final access =
              room.semanticKey == entry.spaceKey && old.key == entry.accessId;
          contacts.add(_Contact(
              left.slot.key, room.semanticKey, null, null, old.key, access));
        }
        for (var b = a + 1; b < placed.length; b++) {
          final right = placed[b];
          for (final other in _spaces(right.geometry)) {
            if (RectilinearPolygonRelations.overlapsInterior(
                room.polygon, other.polygon)) {
              throw const ApartmentCompositionException(
                  'p10.apartments.collision');
            }
            if (RectilinearPolygonRelations.sharedSegments(
                    room.polygon, other.polygon)
                .isNotEmpty) {
              contacts.add(_Contact(left.slot.key, room.semanticKey,
                  right.slot.key, other.semanticKey, null, false));
            }
          }
        }
      }
    }
    if (entries.any((entry) => !contacts
        .any((contact) => contact.access && contact.aSlot == entry.slotKey))) {
      throw const ApartmentCompositionException(
          'p10.apartments.access-unresolved');
    }
    return LevelApartmentCompositionCommand._(
        target: target,
        compositionKey: key,
        apartments: List.unmodifiable(placed),
        entries: entries,
        contacts: contacts..sort((a, b) => a.key.compareTo(b.key)));
  }

  final LevelWizardTarget target;
  final String compositionKey;
  final List<PlacedApartmentCandidate> apartments;
  final List<_Entry> _entries;
  final List<_Contact> _contacts;
  static const _materializer = ApartmentCanonicalMaterializer();
  static const _provenance = ApartmentGenerationProvenanceBuilder();
  static const _parentSlot = 'p10:level-composition:generation';

  @override
  String get commandType => 'p10.level.compose-apartments';
  @override
  String get normalizedIntentKey => jsonEncode({
        'schema': LevelApartmentCompositionManifest.generatorVersion,
        'projectId': target.projectId.value,
        'buildingId': target.buildingId.value,
        'levelId': target.levelId.value,
        'baseVersion': target.baseVersion.value,
        'compositionKey': compositionKey,
        'apartments': [
          for (final apartment in apartments) apartment.slot.toCanonicalJson()
        ],
        'relations': _contacts.map((contact) => contact.key).toList()
      });
  String get candidateFingerprint => semanticSha256Hex(normalizedIntentKey);

  String _childSlot(String key, String local) =>
      jsonEncode(['p10', compositionKey, 'apartment', key, local]);
  String _relationSlot(_Contact contact) =>
      jsonEncode(['p10', compositionKey, 'relation', contact.key]);
  Map<String, ReservedEntityIdKind> get _slots => {
        _parentSlot: ReservedEntityIdKind.generation,
        for (final apartment in apartments)
          for (final entry
              in _materializer.reservationSlotsFor(apartment.geometry).entries)
            _childSlot(apartment.slot.key, entry.key): entry.value,
        for (final contact in _contacts)
          _relationSlot(contact): ReservedEntityIdKind.spaceAdjacency,
      };
  MutationIdentityReservation _child(MutationIdentityReservation reservation,
          PlacedApartmentCandidate apartment) =>
      reservation.selectEntitySlots({
        for (final local
            in _materializer.reservationSlotsFor(apartment.geometry).keys)
          local: _childSlot(apartment.slot.key, local)
      });

  @override
  MutationIdentityReservation reserveIdentities(EntityIdFactory factory) =>
      MutationIdentityReservation.allocate(
          factory: factory, entitySlots: _slots);

  @override
  void validateReservation(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    _requireTarget(current, target);
    if (reservation.slots.length != _slots.length ||
        !reservation.slots.containsAll(_slots.keys) ||
        reservation.entityIds.length != _slots.length) {
      throw const ApartmentCompositionException(
          'p10.apartments.invalid-reservation');
    }
    for (final id in reservation.entityIds) {
      final exists = switch (id) {
        ZoneId() => current.stores.zones.containsKey(id),
        SpaceId() => current.stores.spaces.containsKey(id),
        BoundaryEdgeId() => current.index.boundaryEdges.containsKey(id),
        OpeningId() => current.stores.openings.containsKey(id),
        SpaceAdjacencyId() => current.stores.adjacencies.containsKey(id),
        GenerationId() => current
                .engineeringMetadata.generationProvenanceRegistry.manifests
                .containsKey(id) ||
            current.engineeringMetadata.generationProvenanceRegistry
                .levelCompositions
                .containsKey(id),
        _ => true,
      };
      if (exists) {
        throw const ApartmentCompositionException(
            'p10.apartments.reservation-collision');
      }
    }
    if (current.engineeringMetadata.generationProvenanceRegistry
        .levelCompositions.values
        .any((value) =>
            value.levelId == target.levelId &&
            value.compositionKey == compositionKey)) {
      throw const ApartmentCompositionException(
          'p10.apartments.composition-already-exists');
    }
    for (final apartment in apartments) {
      _materializer.validateReservation(
          current: current,
          target: target,
          candidate: apartment.geometry,
          reservation: _child(reservation, apartment),
          insertionMode: ApartmentInsertionMode.additionalApartment);
    }
  }

  @override
  ProjectCommandCandidate buildCandidate(
      {required ProjectAggregateRoot current,
      required MutationIdentityReservation reservation}) {
    validateReservation(current: current, reservation: reservation);
    var proposed = current;
    final children = <String, ComposedApartmentLineage>{};
    for (var index = 0; index < apartments.length; index++) {
      final apartment = apartments[index];
      final local = _child(reservation, apartment);
      final state = _materializer
          .buildCandidate(
              current: proposed,
              target: target,
              candidate: apartment.geometry,
              template: apartment.slot.source.template,
              reservation: local,
              insertionMode: ApartmentInsertionMode.additionalApartment,
              apartmentName: apartment.slot.displayName)
          .resolveState(proposed);
      proposed = _root(current, state);
      final entry = _entries[index];
      final openingId =
          local.entityId<OpeningId>('opening:${entry.openingIndex}');
      final opening = proposed.stores.openings[openingId]!;
      final openings = {
        ...proposed.stores.openings,
        openingId: ProjectOpeningEntity(
            id: opening.id,
            levelId: opening.levelId,
            kind: opening.kind,
            connectedSpaceIds: {...opening.connectedSpaceIds, entry.accessId},
            widthMm: opening.widthMm,
            heightMm: opening.heightMm,
            baseElevationMm: opening.baseElevationMm)
      };
      final hosts = proposed.engineeringMetadata.boundaryHostedObjectRegistry
          .putOpening(
              openingId: openingId,
              host: BoundaryEdgeHostRef(
                  spaceId: entry.accessId, edgeId: entry.edgeId),
              startOffsetMm: entry.start,
              endOffsetMm: entry.end);
      proposed = _root(
          current,
          ProjectMutableState(
              engineeringMetadata: proposed.engineeringMetadata
                  .withBoundaryHostedObjectRegistry(hosts),
              stores: proposed.stores.copyWith(openings: openings)));
      final registry = _provenance.build(
          current: proposed.engineeringMetadata.generationProvenanceRegistry,
          materializedProject: proposed,
          target: target,
          candidate: apartment.geometry,
          reservation: local,
          input: ApartmentGenerationProvenanceInput(
              providerTemplateId: TemplateId('p9-apartment-provider'),
              providerTemplateVersion: 1,
              candidateIdentity: apartment.slot.source.identity,
              familyId: apartment.geometry.family.code));
      proposed = _root(
          current,
          ProjectMutableState(
              engineeringMetadata: proposed.engineeringMetadata
                  .withGenerationProvenanceRegistry(registry),
              stores: proposed.stores));
      children[apartment.slot.key] = ComposedApartmentLineage(
          generationId: local.entityId<GenerationId>(
              ApartmentGenerationProvenanceBuilder.generationSlot),
          apartmentZoneId: local.entityId<ZoneId>('zone:apartment'),
          accessSpaceId: entry.accessId,
          sourceCandidateFingerprint:
              apartment.slot.source.candidateFingerprint,
          transform: apartment.slot.transform);
    }
    final adjacencies = {...proposed.stores.adjacencies};
    final relations = <String, SpaceAdjacencyId>{};
    for (final contact in _contacts) {
      final a = reservation.entityId<SpaceId>(
          _childSlot(contact.aSlot, 'space:${contact.aSpace}'));
      final b = contact.existingB ??
          reservation.entityId<SpaceId>(
              _childSlot(contact.bSlot!, 'space:${contact.bSpace}'));
      final id = reservation.entityId<SpaceAdjacencyId>(_relationSlot(contact));
      final entry = contact.access
          ? _entries.firstWhere((entry) => entry.slotKey == contact.aSlot)
          : null;
      adjacencies[id] = ProjectSpaceAdjacencyEntity(
          id: id,
          spaceAId: a,
          spaceBId: b,
          kind: contact.access
              ? SpaceAdjacencyKind.opening
              : SpaceAdjacencyKind.sharedBoundary,
          openingId: entry == null
              ? null
              : reservation.entityId<OpeningId>(
                  _childSlot(entry.slotKey, 'opening:${entry.openingIndex}')));
      relations[contact.key] = id;
    }
    final parentId = reservation.entityId<GenerationId>(_parentSlot);
    final registry = proposed.engineeringMetadata.generationProvenanceRegistry;
    final parent = LevelApartmentCompositionManifest(
        generationId: parentId,
        projectId: current.id,
        buildingId: target.buildingId,
        levelId: target.levelId,
        compositionKey: compositionKey,
        canonicalRequest: normalizedIntentKey,
        candidateFingerprint: candidateFingerprint,
        apartments: children,
        generatedAdjacencies: relations);
    final nextRegistry = registry.copyWith(
        levelCompositions: {...registry.levelCompositions, parentId: parent});
    proposed = _root(
        current,
        ProjectMutableState(
            engineeringMetadata: proposed.engineeringMetadata
                .withGenerationProvenanceRegistry(nextRegistry),
            stores: proposed.stores.copyWith(adjacencies: adjacencies)));
    GenerationProvenanceIntegrityValidator.validateOrThrow(nextRegistry,
        project: proposed);
    try {
      final adoptedSpaces = <SpaceId>{
        ..._entries.map((entry) => entry.accessId),
        for (final apartment in apartments)
          for (final space in _spaces(apartment.geometry))
            reservation.entityId<SpaceId>(
                _childSlot(apartment.slot.key, 'space:${space.semanticKey}')),
      };
      for (final spaceId in adoptedSpaces) {
        BoundaryOpeningProfileValidator.validateSpace(
            spaceId: spaceId,
            openings: proposed.stores.openings.values,
            hostedObjects:
                proposed.engineeringMetadata.boundaryHostedObjectRegistry,
            wallProfiles:
                proposed.engineeringMetadata.boundaryWallProfileRegistry);
      }
    } on BoundaryOpeningProfileException {
      throw const ApartmentCompositionException(
          'p10.apartments.invalid-opening-host');
    }
    LevelApartmentCompositionIntegrity.validateOrThrow(
        registry: nextRegistry, projectId: current.id, stores: proposed.stores);
    return ProjectCommandCandidate.fromState(
        state: ProjectMutableState.fromProject(proposed),
        affectedEntityIds:
            ProjectEntityDiff.between(current.stores, proposed.stores)
                .affectedEntityIds);
  }

  @override
  Iterable<ProjectSemanticOperation> semanticOperations(
      {required ProjectAggregateRoot before,
      required ProjectAggregateRoot candidate,
      required MutationIdentityReservation reservation}) sync* {
    final diff = ProjectEntityDiff.between(before.stores, candidate.stores);
    for (final id in diff.addedEntityIds) {
      final EntityId owner = switch (id) {
        SpaceId() =>
          candidate.index.structuralZoneBySpace[id] ?? target.levelId,
        BoundaryEdgeId() => candidate.index.boundaryEdges[id]!.spaceId,
        _ => target.levelId,
      };
      yield CreateEntityOperation(entityId: id, ownerId: owner);
    }
    for (final id in diff.updatedEntityIds) {
      yield UpdateEntityOperation(entityId: id);
    }
  }
}

void _requireTarget(ProjectAggregateRoot project, LevelWizardTarget target) {
  if (project.id != target.projectId ||
      project.siteId != target.siteId ||
      project.stores.levels[target.levelId]?.buildingId != target.buildingId) {
    throw const ApartmentCompositionException('p10.apartments.foreign-target');
  }
  if (project.version != target.baseVersion) {
    throw StaleProjectMutationException(
        expectedVersion: target.baseVersion, currentVersion: project.version);
  }
}

ProjectAggregateRoot _root(
        ProjectAggregateRoot current, ProjectMutableState state) =>
    ProjectAggregateRoot(
        id: current.id,
        siteId: current.siteId,
        version: current.version,
        engineeringMetadata: state.engineeringMetadata,
        stores: state.stores);
List<GeneratedSpaceGeometry> _spaces(ApartmentGeometryCandidate value) =>
    [...value.interiorSpaces, ...value.exteriorAppendages];
RectilinearPolygonMm _polygon(ProjectAggregateRoot project, SpaceId id) {
  final boundary = project.stores.boundaries[id];
  if (boundary == null) {
    throw const ApartmentCompositionException(
        'p10.apartments.target-geometry-missing');
  }
  try {
    return RectilinearPolygonMm.normalized([
      for (final edgeId in boundary.orderedEdgeIds)
        boundary.edges[edgeId]!.start
    ], gridMm: 1);
  } on ArgumentError {
    throw const ApartmentCompositionException(
        'p10.apartments.target-geometry-invalid');
  }
}

GeometrySegmentMm _doorInterval(GeometrySegmentMm segment) {
  final inset =
      (segment.lengthMm - ApartmentCanonicalMaterializer.primaryEntryWidthMm) ~/
          2;
  if (inset < 0) {
    throw const ApartmentCompositionException('p10.apartments.entry-too-small');
  }
  final dx = segment.end.xMm.compareTo(segment.start.xMm);
  final dy = segment.end.yMm.compareTo(segment.start.yMm);
  return GeometrySegmentMm(
      start: BoundaryPointMm(
          xMm: segment.start.xMm + dx * inset,
          yMm: segment.start.yMm + dy * inset),
      end: BoundaryPointMm(
          xMm: segment.start.xMm +
              dx * (inset + ApartmentCanonicalMaterializer.primaryEntryWidthMm),
          yMm: segment.start.yMm +
              dy *
                  (inset +
                      ApartmentCanonicalMaterializer.primaryEntryWidthMm)));
}

({int start, int end}) _offsets(
    ProjectBoundaryEdge edge, GeometrySegmentMm segment) {
  final a = (segment.start.xMm - edge.start.xMm).abs() +
      (segment.start.yMm - edge.start.yMm).abs();
  final b = (segment.end.xMm - edge.start.xMm).abs() +
      (segment.end.yMm - edge.start.yMm).abs();
  return a < b ? (start: a, end: b) : (start: b, end: a);
}

final class _Entry {
  const _Entry(this.slotKey, this.spaceKey, this.openingIndex, this.accessId,
      this.edgeId, this.start, this.end);
  final String slotKey;
  final String spaceKey;
  final int openingIndex;
  final SpaceId accessId;
  final BoundaryEdgeId edgeId;
  final int start;
  final int end;
}

final class _Contact {
  const _Contact(this.aSlot, this.aSpace, this.bSlot, this.bSpace,
      this.existingB, this.access);
  final String aSlot;
  final String aSpace;
  final String? bSlot;
  final String? bSpace;
  final SpaceId? existingB;
  final bool access;
  String get key => jsonEncode([
        access ? 'access' : 'shared',
        aSlot,
        aSpace,
        bSlot,
        bSpace,
        existingB?.value
      ]);
}
