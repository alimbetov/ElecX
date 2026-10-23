import 'boundary_topology.dart';
import 'project_identity.dart';

/// Physical role of one stable multi-level vertical routing volume.
enum VerticalCoreKind {
  /// Dedicated cable/conduit riser.
  riser,

  /// Generic building shaft that may host engineering routes.
  shaft,

  /// Service shaft reserved for engineering systems.
  serviceShaft,
}

/// Canonical physical vertical routing volume spanning two or more levels.
///
/// A [ProjectVerticalCore] is intentionally independent from individual slab
/// penetrations. The core owns stable cross-level plan identity and coverage;
/// every physical ceiling↔floor crossing still belongs to a concrete [SlabId]
/// and is materialized as its own penetration by the routing layer.
///
/// [footprint] is expressed in the building plan coordinate system and remains
/// stable while room/surface projections change. [levelIds] declares the
/// canonical levels on which the core is available; project-level validation
/// is responsible for proving that all referenced levels belong to
/// [buildingId].
final class ProjectVerticalCore {
  ProjectVerticalCore({
    required this.id,
    required this.buildingId,
    required this.kind,
    required Iterable<LevelId> levelIds,
    required Iterable<BoundaryPointMm> footprint,
    this.name,
  })  : levelIds = Set.unmodifiable(levelIds),
        footprint = List.unmodifiable(footprint) {
    if (name != null && name!.trim().isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Vertical core name must be null or non-empty.',
      );
    }
    if (this.levelIds.length < 2) {
      throw ArgumentError.value(
        this.levelIds.length,
        'levelIds',
        'A vertical core must span at least two canonical levels.',
      );
    }
    if (this.footprint.length < 3) {
      throw ArgumentError.value(
        this.footprint.length,
        'footprint',
        'Vertical core footprint requires at least three points.',
      );
    }
    if (_signedDoubleArea(this.footprint) == 0) {
      throw ArgumentError.value(
        this.footprint,
        'footprint',
        'Vertical core footprint must have non-zero area.',
      );
    }
  }

  final VerticalCoreId id;
  final BuildingId buildingId;
  final VerticalCoreKind kind;
  final Set<LevelId> levelIds;
  final List<BoundaryPointMm> footprint;
  final String? name;

  bool servesLevel(LevelId levelId) => levelIds.contains(levelId);
}

enum VerticalCoreTopologyIssueCode {
  storeKeyIdMismatch,
  duplicateCoreIdentity,
}

final class VerticalCoreTopologyIssue {
  const VerticalCoreTopologyIssue({
    required this.code,
    required this.message,
    this.verticalCoreId,
  });

  final VerticalCoreTopologyIssueCode code;
  final VerticalCoreId? verticalCoreId;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

/// Validates invariants that do not require the wider project aggregate.
/// Building/level ownership and level ordering are checked by the aggregate
/// validator once the core is attached to canonical project stores.
abstract final class VerticalCoreTopologyValidator {
  static List<VerticalCoreTopologyIssue> validate(
    Map<VerticalCoreId, ProjectVerticalCore> verticalCores,
  ) {
    final issues = <VerticalCoreTopologyIssue>[];
    final identities = <VerticalCoreId>{};

    for (final entry in verticalCores.entries) {
      final core = entry.value;
      if (entry.key != core.id) {
        issues.add(
          VerticalCoreTopologyIssue(
            code: VerticalCoreTopologyIssueCode.storeKeyIdMismatch,
            verticalCoreId: core.id,
            message: 'Vertical core store key ${entry.key} does not match '
                'entity id ${core.id}.',
          ),
        );
      }
      if (!identities.add(core.id)) {
        issues.add(
          VerticalCoreTopologyIssue(
            code: VerticalCoreTopologyIssueCode.duplicateCoreIdentity,
            verticalCoreId: core.id,
            message: 'Vertical core identity ${core.id} is duplicated.',
          ),
        );
      }
    }

    return List.unmodifiable(issues);
  }

  static void validateOrThrow(
    Map<VerticalCoreId, ProjectVerticalCore> verticalCores,
  ) {
    final issues = validate(verticalCores);
    if (issues.isNotEmpty) {
      throw VerticalCoreTopologyValidationException(issues);
    }
  }
}

final class VerticalCoreTopologyValidationException implements Exception {
  VerticalCoreTopologyValidationException(
    Iterable<VerticalCoreTopologyIssue> issues,
  ) : issues = List.unmodifiable(issues);

  final List<VerticalCoreTopologyIssue> issues;

  @override
  String toString() => 'Invalid vertical core topology:\n${issues.join('\n')}';
}

int _signedDoubleArea(List<BoundaryPointMm> points) {
  var area = 0;
  for (var index = 0; index < points.length; index++) {
    final current = points[index];
    final next = points[(index + 1) % points.length];
    area += current.xMm * next.yMm - next.xMm * current.yMm;
  }
  return area;
}
