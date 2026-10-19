import 'surfaces.dart';
import 'wall_profile.dart';

enum BoundaryEditProfile {
  wall,
  structuralProfile,
  openings,
}

final class WallProfileSegment {
  const WallProfileSegment({
    required this.a,
    required this.b,
  });

  final WallProfilePoint a;
  final WallProfilePoint b;
}

/// Resolves the non-rectangular top-profile edges that represent beams,
/// notches, boxed elements or other structural intrusions in wall elevation.
abstract final class BoundaryEditingResolver {
  static List<WallProfileSegment> structuralSegments({
    required WallProfile profile,
    required int wallHeightMm,
  }) {
    final vertices = profile.vertices;
    if (vertices.length < 2) return const [];
    final segments = <WallProfileSegment>[];
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      if (_isStructuralSegment(a, b, wallHeightMm)) {
        segments.add(WallProfileSegment(a: a, b: b));
      }
    }
    return List.unmodifiable(segments);
  }

  static bool _isStructuralSegment(
    WallProfilePoint a,
    WallProfilePoint b,
    int wallHeightMm,
  ) {
    if (a.yMm == 0 && b.yMm == 0) return false;
    final isOuterStart = a.xMm == 0 && b.xMm == 0;
    final isOuterEnd = a.xMm == profileWidth(a, b) && b.xMm == profileWidth(a, b);
    if (isOuterStart || isOuterEnd) return false;
    return a.yMm < wallHeightMm || b.yMm < wallHeightMm;
  }

  // Kept local to avoid requiring wall length in the resolver contract. Outer
  // vertical edges are also naturally excluded by the y<height rule only when
  // custom geometry exists, so this helper intentionally does not attempt to
  // infer the full wall width from two points.
  static int profileWidth(WallProfilePoint a, WallProfilePoint b) =>
      a.xMm > b.xMm ? a.xMm : b.xMm;

  static bool openingBelongsToProfile(
    ArchitecturalOpening opening,
    BoundaryEditProfile profile,
  ) =>
      profile == BoundaryEditProfile.openings;
}
