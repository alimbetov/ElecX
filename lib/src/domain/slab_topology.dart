import 'boundary_topology.dart';
import 'project_identity.dart';

/// Physical role of one horizontal building slab.
enum SlabKind {
  foundation,
  interLevel,
  roof,
}

/// Stable side of one physical slab.
///
/// The names are geometric, not room-facing UI labels. A room ceiling may
/// project onto the slab's below face, while the floor of the level above may
/// project onto the same slab's above face.
enum SlabFaceSide {
  below,
  above,
}

/// Durable reference to one physical side of a slab.
///
/// This is the vertical analogue of stable wall identity: floor/ceiling editor
/// projections can change independently, while engineering routing continues to
/// refer to the same [SlabId] and physical side.
final class SlabFaceRef {
  const SlabFaceRef({required this.slabId, required this.side});

  final SlabId slabId;
  final SlabFaceSide side;

  SlabFaceRef get opposite => SlabFaceRef(
        slabId: slabId,
        side: side == SlabFaceSide.below
            ? SlabFaceSide.above
            : SlabFaceSide.below,
      );

  @override
  bool operator ==(Object other) =>
      other is SlabFaceRef && other.slabId == slabId && other.side == side;

  @override
  int get hashCode => Object.hash(slabId, side);

  @override
  String toString() => '${slabId.value}:${side.name}';
}

/// Canonical physical horizontal boundary of a building.
///
/// A slab is deliberately independent from room floor/ceiling projections.
/// [belowLevelId] and [aboveLevelId] describe the two level-side identities of
/// the physical construction. Exterior sides are represented by `null`:
/// foundation = null -> level, roof = level -> null, inter-level = level -> level.
final class ProjectSlab {
  ProjectSlab({
    required this.id,
    required this.buildingId,
    required this.kind,
    required this.elevationMm,
    required this.thicknessMm,
    required this.materialId,
    required Iterable<BoundaryPointMm> footprint,
    this.belowLevelId,
    this.aboveLevelId,
  }) : footprint = List.unmodifiable(footprint) {
    if (thicknessMm <= 0) {
      throw ArgumentError.value(
        thicknessMm,
        'thicknessMm',
        'Slab thickness must be positive.',
      );
    }
    if (materialId.trim().isEmpty) {
      throw ArgumentError.value(
        materialId,
        'materialId',
        'Slab material id must be non-empty.',
      );
    }
    if (this.footprint.length < 3) {
      throw ArgumentError.value(
        this.footprint.length,
        'footprint',
        'Slab footprint requires at least three points.',
      );
    }
    if (_signedDoubleArea(this.footprint) == 0) {
      throw ArgumentError.value(
        this.footprint,
        'footprint',
        'Slab footprint must have non-zero area.',
      );
    }
    if (belowLevelId == null && aboveLevelId == null) {
      throw ArgumentError(
        'A slab must border at least one canonical level.',
      );
    }
    if (belowLevelId != null && belowLevelId == aboveLevelId) {
      throw ArgumentError(
        'A slab cannot border the same level on both sides.',
      );
    }
    switch (kind) {
      case SlabKind.foundation:
        if (belowLevelId != null || aboveLevelId == null) {
          throw ArgumentError(
            'Foundation slab requires exterior below and a level above.',
          );
        }
      case SlabKind.interLevel:
        if (belowLevelId == null || aboveLevelId == null) {
          throw ArgumentError(
            'Inter-level slab requires canonical levels on both sides.',
          );
        }
      case SlabKind.roof:
        if (belowLevelId == null || aboveLevelId != null) {
          throw ArgumentError(
            'Roof slab requires a level below and exterior above.',
          );
        }
    }
  }

  final SlabId id;
  final BuildingId buildingId;
  final SlabKind kind;
  final LevelId? belowLevelId;
  final LevelId? aboveLevelId;
  final int elevationMm;
  final int thicknessMm;
  final String materialId;
  final List<BoundaryPointMm> footprint;

  SlabFaceRef get belowFace =>
      SlabFaceRef(slabId: id, side: SlabFaceSide.below);

  SlabFaceRef get aboveFace =>
      SlabFaceRef(slabId: id, side: SlabFaceSide.above);

  /// Returns the canonical level adjacent to [face], or null when that side is
  /// building exterior/ground.
  LevelId? levelForFace(SlabFaceRef face) {
    if (face.slabId != id) {
      throw ArgumentError.value(
        face,
        'face',
        'Slab face belongs to ${face.slabId}, not $id.',
      );
    }
    return switch (face.side) {
      SlabFaceSide.below => belowLevelId,
      SlabFaceSide.above => aboveLevelId,
    };
  }
}

enum SlabTopologyIssueCode {
  storeKeyIdMismatch,
  duplicateLevelPair,
}

final class SlabTopologyIssue {
  const SlabTopologyIssue({
    required this.code,
    required this.message,
    this.slabId,
  });

  final SlabTopologyIssueCode code;
  final SlabId? slabId;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

/// Validates invariants that are independent from the wider project aggregate.
/// Cross-reference validation against buildings and levels belongs to the
/// canonical project aggregate validator.
abstract final class SlabTopologyValidator {
  static List<SlabTopologyIssue> validate(Map<SlabId, ProjectSlab> slabs) {
    final issues = <SlabTopologyIssue>[];
    final levelPairs = <String, SlabId>{};

    for (final entry in slabs.entries) {
      final slab = entry.value;
      if (entry.key != slab.id) {
        issues.add(
          SlabTopologyIssue(
            code: SlabTopologyIssueCode.storeKeyIdMismatch,
            slabId: slab.id,
            message: 'Slab store key ${entry.key} does not match entity id '
                '${slab.id}.',
          ),
        );
      }

      final pairKey = _levelPairKey(slab);
      final existing = levelPairs[pairKey];
      if (existing != null) {
        issues.add(
          SlabTopologyIssue(
            code: SlabTopologyIssueCode.duplicateLevelPair,
            slabId: slab.id,
            message: 'Slabs $existing and ${slab.id} claim the same physical '
                'level-side pair $pairKey.',
          ),
        );
      } else {
        levelPairs[pairKey] = slab.id;
      }
    }

    return List.unmodifiable(issues);
  }

  static void validateOrThrow(Map<SlabId, ProjectSlab> slabs) {
    final issues = validate(slabs);
    if (issues.isNotEmpty) {
      throw SlabTopologyValidationException(issues);
    }
  }
}

final class SlabTopologyValidationException implements Exception {
  SlabTopologyValidationException(Iterable<SlabTopologyIssue> issues)
      : issues = List.unmodifiable(issues);

  final List<SlabTopologyIssue> issues;

  @override
  String toString() => 'Invalid slab topology:\n${issues.join('\n')}';
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

String _levelPairKey(ProjectSlab slab) =>
    '${slab.buildingId.value}|${slab.belowLevelId?.value ?? 'exterior'}|'
    '${slab.aboveLevelId?.value ?? 'exterior'}';
