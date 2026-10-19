import 'dart:math' as math;

import '../domain/site_orientation.dart';
import '../domain/surfaces.dart';

final class DaylightWindowInput {
  const DaylightWindowInput({
    required this.id,
    required this.wall,
    required this.centerOffsetMm,
    required this.sillHeightMm,
    required this.widthMm,
    required this.heightMm,
    required this.wallPlanAzimuthDegrees,
    this.visibleLightTransmittance = 0.7,
  }) : assert(centerOffsetMm >= 0),
       assert(sillHeightMm >= 0),
       assert(widthMm > 0),
       assert(heightMm > 0),
       assert(visibleLightTransmittance > 0 && visibleLightTransmittance <= 1);

  final String id;
  final RoomSurfaceRef wall;
  final int centerOffsetMm;
  final int sillHeightMm;
  final int widthMm;
  final int heightMm;
  final double wallPlanAzimuthDegrees;
  final double visibleLightTransmittance;
}

final class DaylightReachZone {
  const DaylightReachZone({
    required this.windowId,
    required this.facadeAzimuthDegrees,
    required this.nominalDepthMm,
    required this.effectiveDepthMm,
    required this.centerlineStrength,
  });

  final String windowId;
  final double facadeAzimuthDegrees;

  /// Geometric rule-of-thumb depth before transmittance/orientation weighting.
  final int nominalDepthMm;

  /// Approximate daylight-assist reach used for editor visualization only.
  final int effectiveDepthMm;

  /// 0..1 editor weight for placement hints, not an illuminance value.
  final double centerlineStrength;
}

final class LightingPlacementHint {
  const LightingPlacementHint({
    required this.position,
    required this.reason,
    required this.priority,
  });

  final SurfacePointMm position;
  final String reason;
  final double priority;
}

/// Geometric daylight-assist layer for early spatial design.
///
/// This deliberately does not claim lux/DF compliance. It converts project
/// north + window geometry into deterministic daylight reach zones and uses
/// them to bias luminaire placement away from over-lit window bands and toward
/// deeper room zones. A future photometric engine can replace the heuristic
/// while keeping the same spatial contracts.
abstract final class DaylightAssistEngine {
  static DaylightReachZone reachForWindow({
    required DaylightWindowInput window,
    required ProjectNorth projectNorth,
  }) {
    final facadeAzimuth = projectNorth.toTrueAzimuth(
      window.wallPlanAzimuthDegrees,
    );

    // A common early-design heuristic: useful daylight penetration is roughly
    // 1.5-2.0 times the window head height above the work plane. We use 1.75x
    // as a neutral geometric baseline and explicitly label it non-compliance.
    const assumedWorkPlaneHeightMm = 800;
    final headHeightMm = window.sillHeightMm + window.heightMm;
    final heightAboveWorkPlane = math.max(
      0,
      headHeightMm - assumedWorkPlaneHeightMm,
    );
    final nominalDepth = (heightAboveWorkPlane * 1.75).round();

    final orientationWeight = _orientationWeight(facadeAzimuth);
    final strength = (window.visibleLightTransmittance * orientationWeight)
        .clamp(0.15, 1.0);
    final effectiveDepth = (nominalDepth * strength).round();

    return DaylightReachZone(
      windowId: window.id,
      facadeAzimuthDegrees: facadeAzimuth,
      nominalDepthMm: nominalDepth,
      effectiveDepthMm: effectiveDepth,
      centerlineStrength: strength,
    );
  }

  /// Generates simple ceiling placement hints along the room depth axis.
  /// [roomDepthMm] is measured inward from the facade/window wall.
  static List<LightingPlacementHint> ceilingHints({
    required int roomWidthMm,
    required int roomDepthMm,
    required DaylightReachZone daylight,
    int preferredSpacingMm = 1800,
  }) {
    if (roomWidthMm <= 0 || roomDepthMm <= 0 || preferredSpacingMm <= 0) {
      return const [];
    }

    final firstArtificialBand = math.min(
      roomDepthMm,
      math.max(0, daylight.effectiveDepthMm),
    );
    final usableDepth = roomDepthMm - firstArtificialBand;
    if (usableDepth <= 0) {
      return [
        LightingPlacementHint(
          position: SurfacePointMm(roomWidthMm ~/ 2, roomDepthMm ~/ 2),
          reason: 'Контрольная точка: помещение в зоне сильного естественного света.',
          priority: 0.35,
        ),
      ];
    }

    final rows = math.max(1, (usableDepth / preferredSpacingMm).ceil());
    final columns = math.max(1, (roomWidthMm / preferredSpacingMm).ceil());
    final rowStep = usableDepth / rows;
    final columnStep = roomWidthMm / columns;
    final hints = <LightingPlacementHint>[];

    for (var row = 0; row < rows; row++) {
      final y = (firstArtificialBand + rowStep * (row + 0.5)).round();
      for (var column = 0; column < columns; column++) {
        final x = (columnStep * (column + 0.5)).round();
        final depthFactor = roomDepthMm == 0 ? 0.0 : y / roomDepthMm;
        hints.add(
          LightingPlacementHint(
            position: SurfacePointMm(x, y),
            reason: y <= daylight.effectiveDepthMm
                ? 'Компенсация естественного света у фасада.'
                : 'Основное искусственное освещение глубокой зоны помещения.',
            priority: (0.55 + 0.45 * depthFactor).clamp(0.0, 1.0),
          ),
        );
      }
    }
    return List.unmodifiable(hints);
  }

  static double _orientationWeight(double azimuth) {
    // Northern hemisphere design-assist weighting only. South-facing facades
    // receive the strongest generic weight, north-facing the weakest. This is
    // not a solar-position or illuminance calculation.
    final radians = (azimuth - 180) * math.pi / 180;
    final southness = (math.cos(radians) + 1) / 2;
    return 0.55 + 0.45 * southness;
  }
}
