import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/boundary_host_migration.dart';
import '../../../../domain/boundary_host_registry.dart';
import '../../../../domain/boundary_topology.dart';
import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_entity_stores_copy.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/project_space_semantics.dart';
import '../../project_mutation.dart';
import '../../project_mutation_reservation.dart';
import '../wizard_contracts.dart';

final class ApartmentMaterializationException implements Exception {
  const ApartmentMaterializationException(this.code, [this.facts = const {}]);

  final String code;
  final Map<String, Object?> facts;

  @override
  String toString() => code;
}

/// Pure P9.11A materialization kernel used by P9.10 reserved Preview/Diff.
///
/// The kernel owns no repository, version, history or random allocator. All
/// durable identities are supplied by one immutable P8 reservation. The same
/// canonical candidate is therefore reusable by P8 Apply without regeneration.
final class ApartmentCanonicalMaterializer {
  const ApartmentCanonicalMaterializer();

  static const String materializerVersion = 'p9.apartment.materializer.v1';
  static const int primaryEntryWidthMm = 900;
  static const int internalDoorWidthMm = 900;
  static const int openPassageWidthMm = 1200;
  static const int defaultOpeningHeightMm = 2100;

  MutationIdentityReservation reserveIdentities({
    required EntityIdFactory factory,
    required ApartmentGeometryCandidate candidate,
  }) =>
      MutationIdentityReservation.allocate(
        factory: factory,
        entitySlots: _reservationSlots(candidate),
      );

  void validateReservation({
    required ProjectAggregateRoot current,
    required LevelWizardTarget target,
    required ApartmentGeometryCandidate candidate,
    required MutationIdentityReservation reservation,
  }) {
    _validateTarget(current, target);
    _validateCandidate(candidate);

    final expected = _reservationSlots(candidate);
    if (!_sameStrings(reservation.slots, expected.keys.toSet())) {
      throw ApartmentMaterializationException(
        'p9.materialize.missing-reservation-slot',
        {
          'expectedSlots': expected.keys.toList()..sort(),
          'actualSlots': reservation.slots.toList()..sort(),
        },
      );
    }

    for (final entry in expected.entries) {
      final id = reservation.entityId<EntityId>(entry.key);
      if (!_matchesKind(id, entry.value)) {
        throw ApartmentMaterializationException(
          'p9.materialize.missing-reservation-slot',
          {'slot': entry.key, 'actualType': id.runtimeType.toString()},
        );
      }
      if (_entityExists(current, id)) {
        throw ApartmentMaterializationException(
          'p9.materialize.reservation-collision',
          {'slot': entry.key, 'entityId': id.value},
        );
      }
    }
  }

  ProjectCommandCandidate buildCandidate({
    required ProjectAggregateRoot current,
    required LevelWizardTarget target,
    required ApartmentGeometryCandidate candidate,
    required ApartmentTopologyTemplate template,
    required MutationIdentityReservation reservation,
  }) {
    validateReservation(
      current: current,
      target: target,
      candidate: candidate,
      reservation: reservation,
    );

    final generatedSpaces = _generatedSpaces(candidate);
    final specs = <String, TopologySpaceSpec>{
      for (final space in generatedSpaces)
        space.semanticKey: _specFor(space.semanticKey, template),
    };
    final spaceIds = <String, SpaceId>{
      for (final space in generatedSpaces)
        space.semanticKey:
            reservation.entityId<SpaceId>(_spaceSlot(space.semanticKey)),
    };

    final nextSpaces =
        Map<SpaceId, ProjectSpaceEntity>.from(current.stores.spaces);
    final nextBoundaries =
        Map<SpaceId, SpaceBoundaryTopology>.from(current.stores.boundaries);
    final affected = <EntityId>{target.levelId};

    for (final generated in generatedSpaces) {
      final spec = specs[generated.semanticKey]!;
      final spaceId = spaceIds[generated.semanticKey]!;
      final space = ProjectSpaceEntity(
        id: spaceId,
        levelId: target.levelId,
        name: _canonicalSpaceName(spec.usage, generated.semanticKey),
        type: spec.type,
        usage: spec.usage,
      );
      nextSpaces[spaceId] = space;
      affected.add(spaceId);

      final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
      final ordered = <BoundaryEdgeId>[];
      final segments = generated.polygon.segments;
      for (var index = 0; index < segments.length; index++) {
        final edgeId = reservation.entityId<BoundaryEdgeId>(
          _edgeSlot(generated.semanticKey, index),
        );
        final segment = segments[index];
        edges[edgeId] = ProjectBoundaryEdge(
          id: edgeId,
          spaceId: spaceId,
          start: segment.start,
          end: segment.end,
        );
        ordered.add(edgeId);
        affected.add(edgeId);
      }
      final topology = SpaceBoundaryTopology(
        spaceId: spaceId,
        orderedEdgeIds: ordered,
        edges: edges,
      );
      topology.validateOrThrow();
      nextBoundaries[spaceId] = topology;
    }

    final zoneId = reservation.entityId<ZoneId>(_zoneSlot);
    final nextZones =
        Map<ZoneId, ProjectStructuralZoneEntity>.from(current.stores.zones)
          ..[zoneId] = ProjectStructuralZoneEntity(
            id: zoneId,
            levelId: target.levelId,
            name: 'Apartment 1',
            kind: ProjectStructuralZoneKind.apartment,
            spaceIds: spaceIds.values,
          );
    affected.add(zoneId);

    final level = current.stores.levels[target.levelId]!;
    final nextLevel = ProjectLevelEntity(
      id: level.id,
      buildingId: level.buildingId,
      name: level.name,
      levelNumber: level.levelNumber,
      elevationMm: level.elevationMm,
      kind: level.kind,
      floorToFloorHeightMm: level.floorToFloorHeightMm,
      displayOrder: level.displayOrder,
      zoneIds: {...level.zoneIds, zoneId},
      spaceIds: {...level.spaceIds, ...spaceIds.values},
    );
    final nextLevels =
        Map<LevelId, ProjectLevelEntity>.from(current.stores.levels)
          ..[target.levelId] = nextLevel;

    final nextOpenings =
        Map<OpeningId, ProjectOpeningEntity>.from(current.stores.openings);
    BoundaryHostedObjectRegistry hostedRegistry =
        current.engineeringMetadata.boundaryHostedObjectRegistry;
    final openingIds = <int, OpeningId>{};
    for (var index = 0; index < candidate.openingIntents.length; index++) {
      final intent = candidate.openingIntents[index];
      final fromKey = intent.fromSpaceKey;
      if (fromKey == null || !spaceIds.containsKey(fromKey)) {
        throw ApartmentMaterializationException(
          'p9.materialize.opening-intent-missing',
          {'openingIndex': index, 'fromSpaceKey': fromKey},
        );
      }
      final fromSpaceId = spaceIds[fromKey]!;
      final toSpaceId =
          intent.toSpaceKey == null ? null : spaceIds[intent.toSpaceKey!];
      if (intent.toSpaceKey != null && toSpaceId == null) {
        throw ApartmentMaterializationException(
          'p9.materialize.opening-intent-missing',
          {'openingIndex': index, 'toSpaceKey': intent.toSpaceKey},
        );
      }

      final openingId = reservation.entityId<OpeningId>(_openingSlot(index));
      openingIds[index] = openingId;
      final profile = _openingProfile(intent);
      final topology = nextBoundaries[fromSpaceId]!;
      final hostEdge = _hostEdge(topology, intent.hostSegment);
      if (hostEdge == null) {
        throw ApartmentMaterializationException(
          'p9.materialize.opening-host-invalid',
          {'openingIndex': index, 'spaceKey': fromKey},
        );
      }
      if (profile.widthMm > intent.hostSegment.lengthMm) {
        throw ApartmentMaterializationException(
          'p9.materialize.opening-does-not-fit',
          {
            'openingIndex': index,
            'openingWidthMm': profile.widthMm,
            'hostLengthMm': intent.hostSegment.lengthMm,
          },
        );
      }

      final local = _openingOffsetsOnEdge(
        edge: hostEdge,
        intentSegment: intent.hostSegment,
        openingWidthMm: profile.widthMm,
      );
      hostedRegistry = hostedRegistry.putOpening(
        openingId: openingId,
        host: BoundaryEdgeHostRef(spaceId: fromSpaceId, edgeId: hostEdge.id),
        startOffsetMm: local.startMm,
        endOffsetMm: local.endMm,
      );
      nextOpenings[openingId] = ProjectOpeningEntity(
        id: openingId,
        levelId: target.levelId,
        kind: switch (intent.kind) {
          GeometryOpeningKind.primaryEntry ||
          GeometryOpeningKind.door =>
            OpeningKind.door,
          GeometryOpeningKind.openPassage => OpeningKind.openPassage,
        },
        connectedSpaceIds: {
          fromSpaceId,
          if (toSpaceId != null) toSpaceId,
        },
        widthMm: profile.widthMm,
        heightMm: defaultOpeningHeightMm,
        baseElevationMm: 0,
      );
      affected.add(openingId);
    }

    final openingByPair = <String, int>{};
    for (var index = 0; index < candidate.openingIntents.length; index++) {
      final intent = candidate.openingIntents[index];
      if (intent.kind == GeometryOpeningKind.primaryEntry ||
          intent.fromSpaceKey == null ||
          intent.toSpaceKey == null) {
        continue;
      }
      openingByPair[_pairKey(intent.fromSpaceKey!, intent.toSpaceKey!)] = index;
    }

    final nextAdjacencies =
        Map<SpaceAdjacencyId, ProjectSpaceAdjacencyEntity>.from(
      current.stores.adjacencies,
    );
    final pairs = <String, ({String left, String right})>{};
    for (final boundary in candidate.sharedBoundaries) {
      pairs[boundary.pair.stableKey] = (
        left: boundary.pair.leftKey,
        right: boundary.pair.rightKey,
      );
    }
    final pairKeys = pairs.keys.toList()..sort();
    for (final pairKey in pairKeys) {
      final pair = pairs[pairKey]!;
      final adjacencyId = reservation.entityId<SpaceAdjacencyId>(
        _adjacencySlot(pairKey),
      );
      final openingIndex = openingByPair[pairKey];
      final openingIntent =
          openingIndex == null ? null : candidate.openingIntents[openingIndex];
      final openingId = openingIndex == null ? null : openingIds[openingIndex];
      final kind = switch (openingIntent?.kind) {
        GeometryOpeningKind.door => SpaceAdjacencyKind.opening,
        GeometryOpeningKind.openPassage => SpaceAdjacencyKind.openPassage,
        _ => SpaceAdjacencyKind.sharedBoundary,
      };
      nextAdjacencies[adjacencyId] = ProjectSpaceAdjacencyEntity(
        id: adjacencyId,
        spaceAId: spaceIds[pair.left]!,
        spaceBId: spaceIds[pair.right]!,
        kind: kind,
        openingId: kind == SpaceAdjacencyKind.opening ? openingId : null,
      );
      affected.add(adjacencyId);
    }

    final stores = current.stores.copyWith(
      levels: nextLevels,
      zones: nextZones,
      spaces: nextSpaces,
      openings: nextOpenings,
      adjacencies: nextAdjacencies,
      boundaries: nextBoundaries,
    );
    final metadata = current.engineeringMetadata
        .withBoundaryHostedObjectRegistry(hostedRegistry);

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: metadata,
        stores: stores,
      ),
      affectedEntityIds: affected,
    );
  }

  Iterable<ProjectSemanticOperation> semanticOperations({
    required LevelWizardTarget target,
    required ApartmentGeometryCandidate candidate,
    required MutationIdentityReservation reservation,
  }) sync* {
    yield UpdateEntityOperation(entityId: target.levelId);

    final zoneId = reservation.entityId<ZoneId>(_zoneSlot);
    yield CreateEntityOperation(entityId: zoneId, ownerId: target.levelId);

    for (final space in _generatedSpaces(candidate)) {
      final spaceId =
          reservation.entityId<SpaceId>(_spaceSlot(space.semanticKey));
      yield CreateEntityOperation(entityId: spaceId, ownerId: zoneId);
      for (var index = 0; index < space.polygon.segments.length; index++) {
        yield CreateEntityOperation(
          entityId: reservation.entityId<BoundaryEdgeId>(
            _edgeSlot(space.semanticKey, index),
          ),
          ownerId: spaceId,
        );
      }
    }

    for (var index = 0; index < candidate.openingIntents.length; index++) {
      final intent = candidate.openingIntents[index];
      final owner = intent.fromSpaceKey == null
          ? target.levelId
          : reservation.entityId<SpaceId>(_spaceSlot(intent.fromSpaceKey!));
      yield CreateEntityOperation(
        entityId: reservation.entityId<OpeningId>(_openingSlot(index)),
        ownerId: owner,
      );
    }

    final pairKeys = candidate.sharedBoundaries
        .map((boundary) => boundary.pair.stableKey)
        .toSet()
        .toList()
      ..sort();
    for (final pairKey in pairKeys) {
      yield CreateEntityOperation(
        entityId: reservation.entityId<SpaceAdjacencyId>(
          _adjacencySlot(pairKey),
        ),
        ownerId: target.levelId,
      );
    }
  }

  Map<String, ReservedEntityIdKind> _reservationSlots(
    ApartmentGeometryCandidate candidate,
  ) {
    _validateCandidate(candidate);
    final slots = <String, ReservedEntityIdKind>{
      _zoneSlot: ReservedEntityIdKind.zone,
    };
    for (final space in _generatedSpaces(candidate)) {
      slots[_spaceSlot(space.semanticKey)] = ReservedEntityIdKind.space;
      for (var index = 0; index < space.polygon.segments.length; index++) {
        slots[_edgeSlot(space.semanticKey, index)] =
            ReservedEntityIdKind.boundaryEdge;
      }
    }
    for (var index = 0; index < candidate.openingIntents.length; index++) {
      slots[_openingSlot(index)] = ReservedEntityIdKind.opening;
    }
    final pairKeys = candidate.sharedBoundaries
        .map((boundary) => boundary.pair.stableKey)
        .toSet()
        .toList()
      ..sort();
    for (final pairKey in pairKeys) {
      slots[_adjacencySlot(pairKey)] = ReservedEntityIdKind.spaceAdjacency;
    }
    return slots;
  }

  void _validateTarget(ProjectAggregateRoot current, LevelWizardTarget target) {
    if (current.id != target.projectId || current.siteId != target.siteId) {
      throw const ApartmentMaterializationException(
        'p9.materialize.target-missing',
      );
    }
    final level = current.stores.levels[target.levelId];
    if (level == null) {
      throw const ApartmentMaterializationException(
        'p9.materialize.target-missing',
      );
    }
    if (level.buildingId != target.buildingId) {
      throw const ApartmentMaterializationException(
        'p9.materialize.target-owner-mismatch',
      );
    }
    final hasSpaces = level.spaceIds.isNotEmpty ||
        current.stores.spaces.values
            .any((space) => space.levelId == target.levelId);
    final hasZones = level.zoneIds.isNotEmpty ||
        current.stores.zones.values
            .any((zone) => zone.levelId == target.levelId);
    if (hasSpaces || hasZones) {
      throw const ApartmentMaterializationException(
        'p9.materialize.target-not-empty',
      );
    }
  }

  void _validateCandidate(ApartmentGeometryCandidate candidate) {
    if (!candidate.validation.accepted) {
      throw const ApartmentMaterializationException(
        'p9.materialize.candidate-invalid',
      );
    }
    if (_generatedSpaces(candidate).isEmpty) {
      throw const ApartmentMaterializationException(
        'p9.materialize.candidate-invalid',
        {'reason': 'no-spaces'},
      );
    }
    final primaryEntries = candidate.openingIntents
        .where((intent) => intent.kind == GeometryOpeningKind.primaryEntry)
        .length;
    if (primaryEntries != 1) {
      throw ApartmentMaterializationException(
        'p9.materialize.opening-intent-missing',
        {'primaryEntryCount': primaryEntries},
      );
    }
  }

  List<GeneratedSpaceGeometry> _generatedSpaces(
    ApartmentGeometryCandidate candidate,
  ) =>
      [...candidate.interiorSpaces, ...candidate.exteriorAppendages]
        ..sort((left, right) => left.semanticKey.compareTo(right.semanticKey));

  TopologySpaceSpec _specFor(
    String semanticKey,
    ApartmentTopologyTemplate template,
  ) {
    final matches = template.spaces
        .where(
          (spec) =>
              semanticKey == spec.semanticKey ||
              semanticKey.startsWith('${spec.semanticKey}:'),
        )
        .toList()
      ..sort((left, right) =>
          right.semanticKey.length.compareTo(left.semanticKey.length));
    if (matches.isEmpty) {
      throw ApartmentMaterializationException(
        'p9.materialize.candidate-invalid',
        {'reason': 'space-spec-missing', 'semanticKey': semanticKey},
      );
    }
    return matches.first;
  }

  String _canonicalSpaceName(SpaceUsage usage, String semanticKey) {
    final ordinal = int.tryParse(semanticKey.split(':').last) ?? 1;
    final base = switch (usage) {
      SpaceUsage.bedroom => 'Bedroom',
      SpaceUsage.livingRoom => 'Living Room',
      SpaceUsage.kitchen => 'Kitchen',
      SpaceUsage.kitchenLiving => 'Kitchen-Living',
      SpaceUsage.diningRoom => 'Dining Room',
      SpaceUsage.bathroom => 'Bathroom',
      SpaceUsage.wc => 'WC',
      SpaceUsage.showerRoom => 'Shower Room',
      SpaceUsage.entranceHall => 'Entrance Hall',
      SpaceUsage.corridor => 'Corridor',
      SpaceUsage.commonHall => 'Common Hall',
      SpaceUsage.wardrobe => 'Wardrobe',
      SpaceUsage.storage => 'Storage',
      SpaceUsage.pantry => 'Pantry',
      SpaceUsage.laundry => 'Laundry',
      SpaceUsage.balcony => 'Balcony',
      SpaceUsage.loggia => 'Loggia',
      SpaceUsage.terrace => 'Terrace',
      SpaceUsage.office => 'Office',
      SpaceUsage.study => 'Study',
      _ => _titleCase(usage.name),
    };
    final repeated = const {
      SpaceUsage.bedroom,
      SpaceUsage.bathroom,
      SpaceUsage.wc,
      SpaceUsage.showerRoom,
      SpaceUsage.balcony,
      SpaceUsage.loggia,
      SpaceUsage.terrace,
      SpaceUsage.storage,
      SpaceUsage.wardrobe,
    };
    return repeated.contains(usage) ? '$base $ordinal' : base;
  }

  _OpeningProfile _openingProfile(OpeningIntent intent) => _OpeningProfile(
        widthMm: switch (intent.kind) {
          GeometryOpeningKind.primaryEntry => primaryEntryWidthMm,
          GeometryOpeningKind.door => internalDoorWidthMm,
          GeometryOpeningKind.openPassage => openPassageWidthMm,
        },
      );

  ProjectBoundaryEdge? _hostEdge(
    SpaceBoundaryTopology topology,
    GeometrySegmentMm segment,
  ) {
    final matches = topology.edges.values
        .where((edge) => _edgeContainsSegment(edge, segment))
        .toList()
      ..sort((left, right) => left.id.value.compareTo(right.id.value));
    if (matches.length != 1) return null;
    return matches.single;
  }

  bool _edgeContainsSegment(
      ProjectBoundaryEdge edge, GeometrySegmentMm segment) {
    final edgeVertical = edge.start.xMm == edge.end.xMm;
    if (edgeVertical != segment.vertical) return false;
    if (edgeVertical) {
      if (edge.start.xMm != segment.start.xMm) return false;
      final edgeMin = _min(edge.start.yMm, edge.end.yMm);
      final edgeMax = _max(edge.start.yMm, edge.end.yMm);
      final segmentMin = _min(segment.start.yMm, segment.end.yMm);
      final segmentMax = _max(segment.start.yMm, segment.end.yMm);
      return segmentMin >= edgeMin && segmentMax <= edgeMax;
    }
    if (edge.start.yMm != segment.start.yMm) return false;
    final edgeMin = _min(edge.start.xMm, edge.end.xMm);
    final edgeMax = _max(edge.start.xMm, edge.end.xMm);
    final segmentMin = _min(segment.start.xMm, segment.end.xMm);
    final segmentMax = _max(segment.start.xMm, segment.end.xMm);
    return segmentMin >= edgeMin && segmentMax <= edgeMax;
  }

  ({int startMm, int endMm}) _openingOffsetsOnEdge({
    required ProjectBoundaryEdge edge,
    required GeometrySegmentMm intentSegment,
    required int openingWidthMm,
  }) {
    final inset = (intentSegment.lengthMm - openingWidthMm) ~/ 2;
    final first = _pointAlong(intentSegment, inset);
    final second = _pointAlong(intentSegment, inset + openingWidthMm);
    final firstOffset = _distanceOnEdge(edge, first);
    final secondOffset = _distanceOnEdge(edge, second);
    final start = _min(firstOffset, secondOffset);
    final end = _max(firstOffset, secondOffset);
    if (start < 0 || end <= start || end > _edgeLength(edge)) {
      throw ApartmentMaterializationException(
        'p9.materialize.opening-does-not-fit',
        {'edgeId': edge.id.value, 'startOffsetMm': start, 'endOffsetMm': end},
      );
    }
    return (startMm: start, endMm: end);
  }

  BoundaryPointMm _pointAlong(GeometrySegmentMm segment, int distanceMm) {
    if (distanceMm < 0 || distanceMm > segment.lengthMm) {
      throw const ApartmentMaterializationException(
        'p9.materialize.opening-does-not-fit',
      );
    }
    final dx = segment.end.xMm.compareTo(segment.start.xMm);
    final dy = segment.end.yMm.compareTo(segment.start.yMm);
    return BoundaryPointMm(
      xMm: segment.start.xMm + dx * distanceMm,
      yMm: segment.start.yMm + dy * distanceMm,
    );
  }

  int _distanceOnEdge(ProjectBoundaryEdge edge, BoundaryPointMm point) {
    if (edge.start.xMm == edge.end.xMm) {
      if (point.xMm != edge.start.xMm) return -1;
      final minY = _min(edge.start.yMm, edge.end.yMm);
      final maxY = _max(edge.start.yMm, edge.end.yMm);
      if (point.yMm < minY || point.yMm > maxY) return -1;
      return (point.yMm - edge.start.yMm).abs();
    }
    if (point.yMm != edge.start.yMm) return -1;
    final minX = _min(edge.start.xMm, edge.end.xMm);
    final maxX = _max(edge.start.xMm, edge.end.xMm);
    if (point.xMm < minX || point.xMm > maxX) return -1;
    return (point.xMm - edge.start.xMm).abs();
  }

  int _edgeLength(ProjectBoundaryEdge edge) =>
      (edge.end.xMm - edge.start.xMm).abs() +
      (edge.end.yMm - edge.start.yMm).abs();

  bool _entityExists(ProjectAggregateRoot current, EntityId id) {
    if (id is ZoneId) return current.stores.zones.containsKey(id);
    if (id is SpaceId) return current.stores.spaces.containsKey(id);
    if (id is OpeningId) return current.stores.openings.containsKey(id);
    if (id is SpaceAdjacencyId) {
      return current.stores.adjacencies.containsKey(id);
    }
    if (id is BoundaryEdgeId) {
      return current.index.boundaryEdges.containsKey(id);
    }
    return false;
  }

  bool _matchesKind(EntityId id, ReservedEntityIdKind kind) => switch (kind) {
        ReservedEntityIdKind.zone => id is ZoneId,
        ReservedEntityIdKind.space => id is SpaceId,
        ReservedEntityIdKind.opening => id is OpeningId,
        ReservedEntityIdKind.spaceAdjacency => id is SpaceAdjacencyId,
        ReservedEntityIdKind.boundaryEdge => id is BoundaryEdgeId,
        _ => false,
      };
}

const String _zoneSlot = 'zone:apartment';
String _spaceSlot(String semanticKey) => 'space:$semanticKey';
String _edgeSlot(String semanticKey, int index) => 'edge:$semanticKey:$index';
String _openingSlot(int index) => 'opening:$index';
String _adjacencySlot(String pairKey) => 'adj:$pairKey';

String _pairKey(String left, String right) =>
    left.compareTo(right) <= 0 ? '$left|$right' : '$right|$left';

bool _sameStrings(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

String _titleCase(String raw) {
  if (raw.isEmpty) return 'Space';
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    final char = raw[index];
    if (index == 0) {
      buffer.write(char.toUpperCase());
    } else if (char.toUpperCase() == char && char.toLowerCase() != char) {
      buffer.write(' ${char.toLowerCase()}');
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

int _min(int left, int right) => left < right ? left : right;
int _max(int left, int right) => left > right ? left : right;

final class _OpeningProfile {
  const _OpeningProfile({required this.widthMm});

  final int widthMm;
}
