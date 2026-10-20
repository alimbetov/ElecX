import '../domain/wall_profile.dart';

/// One point of the wall's upper contour projected into plan semantics.
///
/// [xMm] is the distance from the wall start. [depthFromTopMm] describes how
/// far the usable wall face drops below its maximum height at that position.
/// The plan renderer uses the depth only as a visual offset; it must never
/// mutate the room footprint.
final class WallPlanProfilePoint {
  const WallPlanProfilePoint({required this.xMm, required this.depthFromTopMm});

  final int xMm;
  final int depthFromTopMm;
}

abstract final class WallProfilePlanProjection {
  static List<WallPlanProfilePoint> topContour(WallProfile profile) {
    // WallProfile stores the floor edge first and the upper contour afterwards
    // from right to left. Reverse the upper part to obtain wall-start -> wall-end
    // order while preserving vertical notch/step pairs at identical X values.
    return List.unmodifiable([
      for (final point in profile.vertices.skip(2).toList().reversed)
        WallPlanProfilePoint(
          xMm: point.xMm,
          depthFromTopMm: profile.maxY - point.yMm,
        ),
    ]);
  }

  static bool hasVerticalVariation(WallProfile profile) =>
      topContour(profile).any((point) => point.depthFromTopMm > 0);
}
