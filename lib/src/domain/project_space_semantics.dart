import 'project_identity.dart';

/// Persisted purpose semantics for a canonical space.
///
/// This is deliberately independent from structural geometry/type and from
/// localized display names. Migration from older documents defaults to
/// [unknown] unless explicit semantic provenance exists.
enum SpaceUsage {
  unknown,
  bedroom,
  livingRoom,
  kitchen,
  kitchenLiving,
  diningRoom,
  bathroom,
  wc,
  showerRoom,
  entranceHall,
  corridor,
  commonHall,
  wardrobe,
  storage,
  pantry,
  laundry,
  balcony,
  loggia,
  terrace,
  office,
  study,
  garage,
  parking,
  electricalRoom,
  serverRoom,
  telecomRoom,
  fireControlRoom,
  utilityRoom,
  mechanicalRoom,
  stairwell,
  elevatorHall,
  elevatorShaft,
  serviceShaft,
  commercial,
  commonArea,
}

enum OpeningKind {
  door,
  window,
  openPassage,
  hatch,
  serviceOpening,
  other,
}

/// Canonical opening semantics before P7 durable wall hosting.
///
/// P6 owns identity, dimensions and space connectivity only. It intentionally
/// contains no `wallIndex`, polygon-edge position or persisted host edge. P7
/// later attaches this same [OpeningId] to a stable BoundaryEdgeId.
final class ProjectOpeningEntity {
  ProjectOpeningEntity({
    required this.id,
    required this.levelId,
    required this.kind,
    required Iterable<SpaceId> connectedSpaceIds,
    required this.widthMm,
    required this.heightMm,
    this.baseElevationMm = 0,
  }) : connectedSpaceIds = Set.unmodifiable(connectedSpaceIds) {
    if (this.connectedSpaceIds.isEmpty || this.connectedSpaceIds.length > 2) {
      throw ArgumentError.value(
        this.connectedSpaceIds,
        'connectedSpaceIds',
        'Opening must connect one or two spaces.',
      );
    }
    if (widthMm <= 0 || heightMm <= 0 || baseElevationMm < 0) {
      throw ArgumentError('Opening dimensions/elevation must be positive.');
    }
  }

  final OpeningId id;
  final LevelId levelId;
  final OpeningKind kind;
  final Set<SpaceId> connectedSpaceIds;
  final int widthMm;
  final int heightMm;
  final int baseElevationMm;
}

enum SpaceAdjacencyKind {
  sharedBoundary,
  opening,
  openPassage,
}

/// Symmetric semantic adjacency between exactly two spaces.
final class ProjectSpaceAdjacencyEntity {
  ProjectSpaceAdjacencyEntity({
    required this.id,
    required this.spaceAId,
    required this.spaceBId,
    required this.kind,
    this.openingId,
  }) {
    if (spaceAId == spaceBId) {
      throw ArgumentError(
          'Space adjacency cannot reference the same space twice.');
    }
    if (kind == SpaceAdjacencyKind.opening && openingId == null) {
      throw ArgumentError('Opening adjacency requires openingId.');
    }
  }

  final SpaceAdjacencyId id;
  final SpaceId spaceAId;
  final SpaceId spaceBId;
  final SpaceAdjacencyKind kind;
  final OpeningId? openingId;

  Set<SpaceId> get spaceIds => Set.unmodifiable(<SpaceId>{spaceAId, spaceBId});
}

enum OverlayDiscipline {
  fireSafety,
  accessControl,
  security,
  electrical,
  telecom,
  custom,
}

enum OverlayClassificationKind {
  fireCompartment,
  accessControlZone,
  securityZone,
  electricalZone,
  telecomZone,
  custom,
}

/// Cross-discipline many-to-many classification independent of structural zones.
final class ProjectOverlayClassificationEntity {
  ProjectOverlayClassificationEntity({
    required this.id,
    required this.name,
    required this.discipline,
    required this.kind,
    Iterable<SpaceId> spaceIds = const <SpaceId>[],
  }) : spaceIds = Set.unmodifiable(spaceIds) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
          name, 'name', 'Overlay name must be non-empty.');
    }
  }

  final OverlayClassificationId id;
  final String name;
  final OverlayDiscipline discipline;
  final OverlayClassificationKind kind;
  final Set<SpaceId> spaceIds;
}
