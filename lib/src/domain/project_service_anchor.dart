import 'boundary_host_migration.dart';
import 'boundary_topology.dart';
import 'project_identity.dart';

enum ProjectServiceAnchorKind {
  electricalEntry,
  telecomEntry,
  fireBackboneEntry,
  intercomCctvEntry,
  generatorArea,
  transformerArea,
  pvInverterArea,
  batteryUpsArea,
  evChargingArea,
  externalLightingFeeder,
}

bool isServiceEntryKind(ProjectServiceAnchorKind kind) => switch (kind) {
      ProjectServiceAnchorKind.electricalEntry ||
      ProjectServiceAnchorKind.telecomEntry ||
      ProjectServiceAnchorKind.fireBackboneEntry ||
      ProjectServiceAnchorKind.intercomCctvEntry =>
        true,
      _ => false,
    };

final class ServiceAnchorException implements Exception {
  const ServiceAnchorException(this.code);
  final String code;
  @override
  String toString() => code;
}

/// Architectural attachment identity only, without equipment, sizing, circuits
/// or routes. Physical wall offsets belong exclusively to the P7 host registry.
sealed class ProjectServiceAnchor {
  ProjectServiceAnchor(
      {required this.id,
      required this.siteId,
      required String name,
      required this.kind})
      : name = name.trim() {
    if (this.name.isEmpty) {
      throw ArgumentError('A service anchor requires a name.');
    }
  }
  final ServiceEntryId id;
  final SiteId siteId;
  final String name;
  final ProjectServiceAnchorKind kind;
  Set<BuildingId> get servedBuildingIds;
  Map<String, Object?> get _base =>
      {'id': id.value, 'siteId': siteId.value, 'name': name, 'kind': kind.name};
  Map<String, Object?> toCanonicalJson();
}

final class ProjectSiteServiceAnchor extends ProjectServiceAnchor {
  ProjectSiteServiceAnchor(
      {required super.id,
      required super.siteId,
      required super.name,
      required super.kind,
      required this.point,
      Iterable<BuildingId> servedBuildingIds = const []})
      : servedBuildingIds = Set.unmodifiable(servedBuildingIds) {
    _areaKind(kind);
    validateServiceAnchorPoint(point);
  }
  final BoundaryPointMm point;
  @override
  final Set<BuildingId> servedBuildingIds;
  @override
  Map<String, Object?> toCanonicalJson() => {
        ..._base,
        'hostType': 'site',
        'xMm': point.xMm,
        'yMm': point.yMm,
        'servedBuildingIds': servedBuildingIds.map((id) => id.value).toList()
          ..sort()
      };
}

final class ProjectSpaceServiceAnchor extends ProjectServiceAnchor {
  ProjectSpaceServiceAnchor(
      {required super.id,
      required super.siteId,
      required super.name,
      required super.kind,
      required this.buildingId,
      required this.levelId,
      required this.spaceId,
      required this.point,
      this.heightMm = 0}) {
    _areaKind(kind);
    validateServiceAnchorPoint(point);
    _height(heightMm);
  }
  final BuildingId buildingId;
  final LevelId levelId;
  final SpaceId spaceId;
  final BoundaryPointMm point;
  final int heightMm;
  @override
  Set<BuildingId> get servedBuildingIds => Set.unmodifiable({buildingId});
  @override
  Map<String, Object?> toCanonicalJson() => {
        ..._base,
        'hostType': 'space',
        'buildingId': buildingId.value,
        'levelId': levelId.value,
        'spaceId': spaceId.value,
        'xMm': point.xMm,
        'yMm': point.yMm,
        'heightMm': heightMm
      };
}

final class ProjectBoundaryServiceAnchor extends ProjectServiceAnchor {
  ProjectBoundaryServiceAnchor(
      {required super.id,
      required super.siteId,
      required super.name,
      required super.kind,
      required this.buildingId,
      required this.levelId,
      required this.spaceId,
      this.heightMm = 0}) {
    if (!isServiceEntryKind(kind)) {
      throw ArgumentError('A wall entry requires an entry purpose.');
    }
    _height(heightMm);
  }
  final BuildingId buildingId;
  final LevelId levelId;
  final SpaceId spaceId;
  final int heightMm;
  @override
  Set<BuildingId> get servedBuildingIds => Set.unmodifiable({buildingId});
  @override
  Map<String, Object?> toCanonicalJson() => {
        ..._base,
        'hostType': 'boundary',
        'buildingId': buildingId.value,
        'levelId': levelId.value,
        'spaceId': spaceId.value,
        'heightMm': heightMm
      };
}

/// Transient authoring input. After Apply, the existing P7 registry alone owns
/// the edge and offset. Splits/merges can remap them without rewriting the entry.
final class ServiceAnchorBoundaryBinding {
  ServiceAnchorBoundaryBinding({required this.host, required this.offsetMm}) {
    if (offsetMm < 0) throw ArgumentError('A host offset cannot be negative.');
  }
  final BoundaryEdgeHostRef host;
  final int offsetMm;
  Map<String, Object?> toCanonicalJson() => {
        'spaceId': host.spaceId.value,
        'edgeId': host.edgeId.value,
        'offsetMm': offsetMm
      };
}

void validateServiceAnchorPoint(BoundaryPointMm point) {
  if (point.xMm.abs() > 1000000000 ||
      point.yMm.abs() > 1000000000 ||
      point.xMm % 10 != 0 ||
      point.yMm % 10 != 0) {
    throw ArgumentError(
        'Architectural points require the supported integer 10mm grid.');
  }
}

void _areaKind(ProjectServiceAnchorKind kind) {
  if (isServiceEntryKind(kind)) {
    throw ArgumentError('Service entries require a durable wall host.');
  }
}

void _height(int value) {
  if (value < 0 || value > 1000000) {
    throw ArgumentError('Unsupported anchor height.');
  }
}
