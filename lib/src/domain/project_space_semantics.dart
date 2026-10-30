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
  electricalRiser,
  telecomRiser,
  commercial,
  commonArea,
}

enum OpeningKind { door, window, openPassage, hatch, serviceOpening, other }

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
  }) : connectedSpaceIds = _validateConnectedSpaces(connectedSpaceIds) {
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

  static Set<SpaceId> _validateConnectedSpaces(Iterable<SpaceId> source) {
    final values = List<SpaceId>.of(source);
    if (values.isEmpty || values.length > 2) {
      throw ArgumentError.value(
        values,
        'connectedSpaceIds',
        'Opening must connect one or two spaces.',
      );
    }
    final unique = Set<SpaceId>.of(values);
    if (unique.length != values.length) {
      throw ArgumentError.value(
        values,
        'connectedSpaceIds',
        'Opening connectivity cannot contain the same space twice.',
      );
    }
    return Set<SpaceId>.unmodifiable(unique);
  }
}

enum SpaceAdjacencyKind { sharedBoundary, opening, openPassage, vertical }

/// Symmetric semantic adjacency between exactly two spaces.
///
/// Endpoints are normalized by stable [SpaceId] value so the same unordered
/// pair has one canonical representation. Swapping authoring input order must
/// never create a semantic diff, version increment or persistence fingerprint
/// change.
final class ProjectSpaceAdjacencyEntity {
  ProjectSpaceAdjacencyEntity({
    required this.id,
    required SpaceId spaceAId,
    required SpaceId spaceBId,
    required this.kind,
    this.openingId,
  })  : spaceAId = _firstSpace(spaceAId, spaceBId),
        spaceBId = _secondSpace(spaceAId, spaceBId) {
    if (this.spaceAId == this.spaceBId) {
      throw ArgumentError(
        'Space adjacency cannot reference the same space twice.',
      );
    }
    if (kind == SpaceAdjacencyKind.opening && openingId == null) {
      throw ArgumentError('Opening adjacency requires openingId.');
    }
    if (kind != SpaceAdjacencyKind.opening && openingId != null) {
      throw ArgumentError('Only opening adjacency may reference openingId.');
    }
  }

  final SpaceAdjacencyId id;
  final SpaceId spaceAId;
  final SpaceId spaceBId;
  final SpaceAdjacencyKind kind;
  final OpeningId? openingId;

  Set<SpaceId> get spaceIds => Set.unmodifiable(<SpaceId>{spaceAId, spaceBId});

  static SpaceId _firstSpace(SpaceId left, SpaceId right) =>
      left.value.compareTo(right.value) <= 0 ? left : right;

  static SpaceId _secondSpace(SpaceId left, SpaceId right) =>
      left.value.compareTo(right.value) <= 0 ? right : left;
}

enum OverlayDiscipline {
  fireSafety,
  accessControl,
  security,
  electrical,
  telecom,
  lighting,
  custom,
}

enum OverlayClassificationKind {
  fireCompartment,
  smokeZone,
  evacuationZone,
  accessControlZone,
  securityZone,
  restrictedArea,
  electricalZone,
  emergencySupplyZone,
  telecomZone,
  networkZone,
  lightingControlZone,
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
        name,
        'name',
        'Overlay name must be non-empty.',
      );
    }
    if (!_supportsKind(discipline, kind)) {
      throw ArgumentError(
        'Overlay kind ${kind.name} is incompatible with discipline '
        '${discipline.name}.',
      );
    }
  }

  final OverlayClassificationId id;
  final String name;
  final OverlayDiscipline discipline;
  final OverlayClassificationKind kind;
  final Set<SpaceId> spaceIds;

  static bool _supportsKind(
    OverlayDiscipline discipline,
    OverlayClassificationKind kind,
  ) {
    if (kind == OverlayClassificationKind.custom) {
      return true;
    }
    return switch (discipline) {
      OverlayDiscipline.fireSafety =>
        kind == OverlayClassificationKind.fireCompartment ||
            kind == OverlayClassificationKind.smokeZone ||
            kind == OverlayClassificationKind.evacuationZone,
      OverlayDiscipline.accessControl =>
        kind == OverlayClassificationKind.accessControlZone ||
            kind == OverlayClassificationKind.restrictedArea,
      OverlayDiscipline.security =>
        kind == OverlayClassificationKind.securityZone ||
            kind == OverlayClassificationKind.restrictedArea,
      OverlayDiscipline.electrical =>
        kind == OverlayClassificationKind.electricalZone ||
            kind == OverlayClassificationKind.emergencySupplyZone,
      OverlayDiscipline.telecom =>
        kind == OverlayClassificationKind.telecomZone ||
            kind == OverlayClassificationKind.networkZone,
      OverlayDiscipline.lighting =>
        kind == OverlayClassificationKind.lightingControlZone,
      OverlayDiscipline.custom => false,
    };
  }
}
