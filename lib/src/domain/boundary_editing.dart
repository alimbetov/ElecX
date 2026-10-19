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

    // Exclude the two outer wall sides. Structural verticals (beam/notch
    // sides) do not touch finished-floor level.
    if (a.xMm == b.xMm && (a.yMm == 0 || b.yMm == 0)) return false;

    // A rectangular wall has only floor, outer sides and a top edge exactly at
    // wallHeightMm. Any remaining segment that drops below that top envelope
    // belongs to the editable structural profile.
    return a.yMm < wallHeightMm || b.yMm < wallHeightMm;
  }

  static bool openingBelongsToProfile(
    ArchitecturalOpening opening,
    BoundaryEditProfile profile,
  ) =>
      profile == BoundaryEditProfile.openings;
}
