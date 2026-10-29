import 'dart:convert';

import 'apartment_topology/apartment_geometry.dart';
import 'boundary_topology.dart';
import 'project_identity.dart';
import 'project_orientation.dart';
import 'project_service_anchor.dart';

final class SiteLayoutException implements Exception {
  const SiteLayoutException(this.code);
  final String code;
  @override
  String toString() => code;
}

/// Explicit Building-local -> Site-local transform. Local canonical geometry
/// and P9/P10 lineage stay unchanged when the building is moved or rotated.
/// Orientation reuses Project North's normalized clockwise +Y convention.
final class ProjectBuildingSitePlacement {
  ProjectBuildingSitePlacement(
      {required this.xMm,
      required this.yMm,
      required this.orientation,
      required this.widthMm,
      required this.depthMm}) {
    _coordinate(xMm);
    _coordinate(yMm);
    if (widthMm <= 0 ||
        depthMm <= 0 ||
        widthMm > 1000000 ||
        depthMm > 1000000 ||
        widthMm % 10 != 0 ||
        depthMm % 10 != 0 ||
        orientation.milliDegreesClockwiseFromPositiveY % 90000 != 0) {
      throw ArgumentError(
          'Site placement requires grid-aligned dimensions and quarter-turn orientation.');
    }
    // Also reject transformed corners outside the canonical exact-mm range.
    for (final point in localFootprint.vertices) {
      toSite(point);
    }
  }
  final int xMm;
  final int yMm;
  final ProjectEngineeringNorth orientation;
  final int widthMm;
  final int depthMm;
  RectilinearPolygonMm get localFootprint => RectilinearPolygonMm.rectangle(
      xMm: 0, yMm: 0, widthMm: widthMm, heightMm: depthMm);
  BoundaryPointMm toSite(BoundaryPointMm point) {
    final (x, y) = _rotate(point.xMm, point.yMm,
        orientation.milliDegreesClockwiseFromPositiveY ~/ 90000);
    _coordinate(xMm + x, grid: false);
    _coordinate(yMm + y, grid: false);
    return BoundaryPointMm(xMm: xMm + x, yMm: yMm + y);
  }

  BoundaryPointMm toBuilding(BoundaryPointMm point) {
    final (x, y) = _rotate(point.xMm - xMm, point.yMm - yMm,
        (4 - orientation.milliDegreesClockwiseFromPositiveY ~/ 90000) % 4);
    return BoundaryPointMm(xMm: x, yMm: y);
  }

  RectilinearPolygonMm get siteFootprint =>
      RectilinearPolygonMm.normalized(localFootprint.vertices.map(toSite));
  Map<String, Object?> toCanonicalJson() => {
        'xMm': xMm,
        'yMm': yMm,
        'orientationMilliDegrees':
            orientation.milliDegreesClockwiseFromPositiveY,
        'widthMm': widthMm,
        'depthMm': depthMm,
      };
  bool sameAs(ProjectBuildingSitePlacement other) =>
      xMm == other.xMm &&
      yMm == other.yMm &&
      orientation == other.orientation &&
      widthMm == other.widthMm &&
      depthMm == other.depthMm;
}

/// Architectural shared anchors only. System-specific entries and engineering
/// equipment/content remain P10.10 and later engineering stages.
enum ProjectSiteAnchorKind { sharedServiceArea, sharedAccessPoint }

final class ProjectSharedSiteAnchor {
  ProjectSharedSiteAnchor(
      {required this.id,
      required this.siteId,
      required String name,
      required this.kind,
      required this.point,
      required Iterable<BuildingId> servedBuildingIds})
      : name = name.trim(),
        servedBuildingIds = Set.unmodifiable(servedBuildingIds) {
    _coordinate(point.xMm);
    _coordinate(point.yMm);
    if (this.name.isEmpty || this.servedBuildingIds.length < 2) {
      throw ArgumentError(
          'A shared Site anchor requires a name and at least two buildings.');
    }
  }
  final ServiceEntryId id;
  final SiteId siteId;
  final String name;
  final ProjectSiteAnchorKind kind;
  final BoundaryPointMm point;
  final Set<BuildingId> servedBuildingIds;
  Map<String, Object?> toCanonicalJson() => {
        'id': id.value,
        'siteId': siteId.value,
        'name': name,
        'kind': kind.name,
        'xMm': point.xMm,
        'yMm': point.yMm,
        'servedBuildingIds': servedBuildingIds.map((id) => id.value).toList()
          ..sort(),
      };
}

/// Canonical physical placement metadata, keyed by existing BuildingId values.
/// This owns transforms and shared anchors, never another building/floor graph.
final class ProjectSiteLayout {
  const ProjectSiteLayout.empty()
      : placements = const {},
        sharedAnchors = const {},
        serviceAnchors = const {};
  ProjectSiteLayout(
      {Map<BuildingId, ProjectBuildingSitePlacement> placements = const {},
      Map<ServiceEntryId, ProjectSharedSiteAnchor> sharedAnchors = const {},
      Map<ServiceEntryId, ProjectServiceAnchor> serviceAnchors = const {}})
      : placements = Map.unmodifiable(placements),
        sharedAnchors = Map.unmodifiable(sharedAnchors),
        serviceAnchors = Map.unmodifiable(serviceAnchors);
  final Map<BuildingId, ProjectBuildingSitePlacement> placements;
  final Map<ServiceEntryId, ProjectSharedSiteAnchor> sharedAnchors;
  final Map<ServiceEntryId, ProjectServiceAnchor> serviceAnchors;
  bool get isEmpty =>
      placements.isEmpty && sharedAnchors.isEmpty && serviceAnchors.isEmpty;
  ProjectSiteLayout copyWith(
          {Map<BuildingId, ProjectBuildingSitePlacement>? placements,
          Map<ServiceEntryId, ProjectSharedSiteAnchor>? sharedAnchors,
          Map<ServiceEntryId, ProjectServiceAnchor>? serviceAnchors}) =>
      ProjectSiteLayout(
          placements: placements ?? this.placements,
          sharedAnchors: sharedAnchors ?? this.sharedAnchors,
          serviceAnchors: serviceAnchors ?? this.serviceAnchors);
  Map<String, Object?> toCanonicalJson() => {
        'schemaVersion': 1,
        'coordinateFrame': 'building-local.v1',
        'placements': [
          for (final id
              in placements.keys.toList()
                ..sort((a, b) => a.value.compareTo(b.value)))
            {'buildingId': id.value, ...placements[id]!.toCanonicalJson()}
        ],
        if (serviceAnchors.isNotEmpty)
          'serviceAnchors': [
            for (final id
                in serviceAnchors.keys.toList()
                  ..sort((a, b) => a.value.compareTo(b.value)))
              serviceAnchors[id]!.toCanonicalJson()
          ],
        'sharedAnchors': [
          for (final id
              in sharedAnchors.keys.toList()
                ..sort((a, b) => a.value.compareTo(b.value)))
            sharedAnchors[id]!.toCanonicalJson()
        ],
      };
  bool sameAs(ProjectSiteLayout other) =>
      jsonEncode(toCanonicalJson()) == jsonEncode(other.toCanonicalJson());
}

(int, int) _rotate(int x, int y, int turns) => switch (turns) {
      0 => (x, y),
      1 => (y, -x),
      2 => (-x, -y),
      3 => (-y, x),
      _ => throw ArgumentError('Quarter-turns must be normalized.'),
    };
void _coordinate(int value, {bool grid = true}) {
  if (value.abs() > 1000000000 || (grid && value % 10 != 0)) {
    throw ArgumentError(
        'Site coordinates must use the supported 10mm integer grid.');
  }
}
