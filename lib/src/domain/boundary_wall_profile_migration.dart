import 'project_identity.dart';
import 'wall_profile.dart';

enum BoundaryWallProfileMigrationIssueCode {
  profileWidthMismatch,
  splitPointOutsideProfile,
  invalidClippedProfile,
  mergeProfileHeightMismatch,
  mergeProfileShapeUnsupported,
}

final class BoundaryWallProfileMigrationException implements Exception {
  const BoundaryWallProfileMigrationException({
    required this.code,
    required this.message,
  });

  final BoundaryWallProfileMigrationIssueCode code;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

/// Domain-specific P7A-5 transform for wall elevation profiles.
///
/// Generic hosted-object remap is intentionally insufficient here because a
/// profile owns the full wall face. Split must transform the profile payload,
/// not merely choose one result edge. Merge is accepted only for rectangular
/// profiles with equal height until a lossless general polygon-union contract
/// is introduced.
abstract final class BoundaryWallProfileMigration {
  static Map<BoundaryEdgeId, WallProfile> split({
    required BoundaryEdgeId sourceEdgeId,
    required BoundaryEdgeId firstResultEdgeId,
    required BoundaryEdgeId secondResultEdgeId,
    required int sourceLengthMm,
    required int splitOffsetMm,
    required Map<BoundaryEdgeId, WallProfile> profiles,
  }) {
    final source = profiles[sourceEdgeId];
    if (source == null) return Map.unmodifiable(profiles);
    if (source.maxX != sourceLengthMm) {
      throw BoundaryWallProfileMigrationException(
        code: BoundaryWallProfileMigrationIssueCode.profileWidthMismatch,
        message: 'Profile width ${source.maxX}mm does not match source edge '
            '$sourceLengthMm mm.',
      );
    }
    if (splitOffsetMm <= 0 || splitOffsetMm >= sourceLengthMm) {
      throw BoundaryWallProfileMigrationException(
        code: BoundaryWallProfileMigrationIssueCode.splitPointOutsideProfile,
        message: 'Split offset must lie strictly inside the wall profile.',
      );
    }

    final leftVertices = _clipVertical(
      source.vertices,
      boundaryX: splitOffsetMm,
      keepLeft: true,
    );
    final rightVertices = _clipVertical(
      source.vertices,
      boundaryX: splitOffsetMm,
      keepLeft: false,
    )
        .map((point) => WallProfilePoint(point.xMm - splitOffsetMm, point.yMm))
        .toList(growable: false);
    final left = _profileOrThrow(leftVertices, 'left split result');
    final right = _profileOrThrow(rightVertices, 'right split result');

    if (left.maxX != splitOffsetMm ||
        right.maxX != sourceLengthMm - splitOffsetMm) {
      throw const BoundaryWallProfileMigrationException(
        code: BoundaryWallProfileMigrationIssueCode.invalidClippedProfile,
        message: 'Split profile widths do not match result edge lengths.',
      );
    }

    final result = Map<BoundaryEdgeId, WallProfile>.from(profiles)
      ..remove(sourceEdgeId)
      ..[firstResultEdgeId] = left
      ..[secondResultEdgeId] = right;
    return Map.unmodifiable(result);
  }

  static Map<BoundaryEdgeId, WallProfile> merge({
    required BoundaryEdgeId firstSourceEdgeId,
    required BoundaryEdgeId secondSourceEdgeId,
    required BoundaryEdgeId resultEdgeId,
    required int firstLengthMm,
    required int secondLengthMm,
    required Map<BoundaryEdgeId, WallProfile> profiles,
  }) {
    final first = profiles[firstSourceEdgeId];
    final second = profiles[secondSourceEdgeId];
    if (first == null && second == null) return Map.unmodifiable(profiles);
    if (first == null || second == null) {
      throw const BoundaryWallProfileMigrationException(
        code:
            BoundaryWallProfileMigrationIssueCode.mergeProfileShapeUnsupported,
        message:
            'Cannot merge one explicit wall profile with one implicit wall '
            'profile without an explicit default-height contract.',
      );
    }
    if (first.maxX != firstLengthMm || second.maxX != secondLengthMm) {
      throw const BoundaryWallProfileMigrationException(
        code: BoundaryWallProfileMigrationIssueCode.profileWidthMismatch,
        message: 'Wall profile width does not match its source edge length.',
      );
    }
    if (!_isRectangle(first) || !_isRectangle(second)) {
      throw const BoundaryWallProfileMigrationException(
        code:
            BoundaryWallProfileMigrationIssueCode.mergeProfileShapeUnsupported,
        message: 'Only lossless equal-height rectangular profile merge is '
            'currently supported.',
      );
    }
    if (first.maxY != second.maxY) {
      throw const BoundaryWallProfileMigrationException(
        code: BoundaryWallProfileMigrationIssueCode.mergeProfileHeightMismatch,
        message: 'Adjacent rectangular profiles must have the same height.',
      );
    }
    final result = Map<BoundaryEdgeId, WallProfile>.from(profiles)
      ..remove(firstSourceEdgeId)
      ..remove(secondSourceEdgeId)
      ..[resultEdgeId] = WallProfile.rectangle(
        widthMm: firstLengthMm + secondLengthMm,
        heightMm: first.maxY,
      );
    return Map.unmodifiable(result);
  }

  static WallProfile _profileOrThrow(
    List<WallProfilePoint> vertices,
    String label,
  ) {
    final compact = <WallProfilePoint>[];
    for (final point in vertices) {
      if (compact.isEmpty || !_samePoint(compact.last, point)) {
        compact.add(point);
      }
    }
    if (compact.length > 1 && _samePoint(compact.first, compact.last)) {
      compact.removeLast();
    }
    if (compact.length < 4) {
      throw BoundaryWallProfileMigrationException(
        code: BoundaryWallProfileMigrationIssueCode.invalidClippedProfile,
        message: '$label contains fewer than four vertices.',
      );
    }
    try {
      return WallProfile(vertices: compact);
    } on ArgumentError catch (error) {
      throw BoundaryWallProfileMigrationException(
        code: BoundaryWallProfileMigrationIssueCode.invalidClippedProfile,
        message: '$label is invalid: $error',
      );
    }
  }

  static List<WallProfilePoint> _clipVertical(
    List<WallProfilePoint> input, {
    required int boundaryX,
    required bool keepLeft,
  }) {
    final output = <WallProfilePoint>[];
    bool inside(WallProfilePoint point) =>
        keepLeft ? point.xMm <= boundaryX : point.xMm >= boundaryX;

    for (var index = 0; index < input.length; index++) {
      final current = input[index];
      final previous = input[(index - 1 + input.length) % input.length];
      final currentInside = inside(current);
      final previousInside = inside(previous);
      if (currentInside) {
        if (!previousInside) {
          output.add(_intersection(previous, current, boundaryX));
        }
        output.add(current);
      } else if (previousInside) {
        output.add(_intersection(previous, current, boundaryX));
      }
    }
    return output;
  }

  static WallProfilePoint _intersection(
    WallProfilePoint a,
    WallProfilePoint b,
    int x,
  ) {
    final dx = b.xMm - a.xMm;
    if (dx == 0) return WallProfilePoint(x, a.yMm);
    final t = (x - a.xMm) / dx;
    final y = (a.yMm + (b.yMm - a.yMm) * t).round();
    return WallProfilePoint(x, y);
  }

  static bool _isRectangle(WallProfile profile) {
    if (profile.vertices.length != 4) return false;
    final expected = <WallProfilePoint>[
      const WallProfilePoint(0, 0),
      WallProfilePoint(profile.maxX, 0),
      WallProfilePoint(profile.maxX, profile.maxY),
      WallProfilePoint(0, profile.maxY),
    ];
    for (var index = 0; index < expected.length; index++) {
      if (!_samePoint(profile.vertices[index], expected[index])) return false;
    }
    return true;
  }

  static bool _samePoint(WallProfilePoint a, WallProfilePoint b) =>
      a.xMm == b.xMm && a.yMm == b.yMm;
}
