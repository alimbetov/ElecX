import 'dart:math' as math;

import '../domain/geometry.dart';
import '../domain/project_model.dart';
import '../domain/site_orientation.dart';
import '../domain/surfaces.dart';

final class DaylightWindowInput {
  DaylightWindowInput({
    required this.id,
    required this.wall,
    required this.centerOffsetMm,
    required this.sillHeightMm,
    required this.widthMm,
    required this.heightMm,
    required this.wallPlanAzimuthDegrees,
    this.visibleLightTransmittance = 0.7,
  }) {
    if (id.isEmpty) {
      throw ArgumentError('Daylight window id must be non-empty.');
    }
    if (wall.type != SurfacePlaneType.wall) {
      throw ArgumentError('Daylight input must reference a wall surface.');
    }
    if (centerOffsetMm < 0 ||
        sillHeightMm < 0 ||
        widthMm <= 0 ||
        heightMm <= 0) {
      throw ArgumentError('Daylight window geometry is invalid.');
    }
    if (visibleLightTransmittance <= 0 || visibleLightTransmittance > 1) {
      throw ArgumentError.value(
        visibleLightTransmittance,
        'visibleLightTransmittance',
      );
    }
    if (!wallPlanAzimuthDegrees.isFinite) {
      throw ArgumentError.value(
        wallPlanAzimuthDegrees,
        'wallPlanAzimuthDegrees',
      );
    }
  }

  final String id;
  final RoomSurfaceRef wall;

  /// Window centre measured from the start vertex of the host wall.
  final int centerOffsetMm;
  final int sillHeightMm;
  final int widthMm;
  final int heightMm;

  /// Low-level plan azimuth input retained for imported/external geometry.
  /// Editor-owned windows should prefer [DaylightAssistEngine.planFrameForWindow]
  /// and [DaylightAssistEngine.reachForWindowOnRoom], which derive orientation
  /// from the actual room wall and cannot drift from plan geometry.
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

/// Plan-space reference frame anchored at the centre of one window.
///
/// [inwardX]/[inwardY] point into the room. Depth is therefore independent of
/// whether the host wall is horizontal, vertical or oblique in project space.
final class DaylightPlanFrame {
  const DaylightPlanFrame({
    required this.windowCenter,
    required this.tangentX,
    required this.tangentY,
    required this.inwardX,
    required this.inwardY,
    required this.facadePlanAzimuthDegrees,
  });

  final MmPoint windowCenter;
  final double tangentX;
  final double tangentY;
  final double inwardX;
  final double inwardY;
  final double facadePlanAzimuthDegrees;

  double depthMm(MmPoint point) {
    final dx = point.x - windowCenter.x;
    final dy = point.y - windowCenter.y;
    return dx * inwardX + dy * inwardY;
  }

  double lateralOffsetMm(MmPoint point) {
    final dx = point.x - windowCenter.x;
    final dy = point.y - windowCenter.y;
    return dx * tangentX + dy * tangentY;
  }
}

final class LightingPlacementHint {
  const LightingPlacementHint({
    required this.position,
    required this.reason,
    required this.priority,
    this.daylightInfluence = 0,
  });

  final SurfacePointMm position;
  final String reason;

  /// 0..1 ranking for artificial-light placement. Larger means greater need.
  final double priority;

  /// 0..1 heuristic daylight influence at this point. This is not lux/DF.
  final double daylightInfluence;
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
    SolarSiteContext? solarContext,
  }) {
    final facadeAzimuth = projectNorth.toTrueAzimuth(
      window.wallPlanAzimuthDegrees,
    );
    return _reach(
      window: window,
      facadeAzimuthDegrees: facadeAzimuth,
      solarContext: solarContext,
    );
  }

  /// Preferred editor entry point. The facade direction is derived from the
  /// room boundary instead of trusting a duplicated azimuth value on the
  /// window input.
  static DaylightReachZone reachForWindowOnRoom({
    required DaylightWindowInput window,
    required EngineeringSpace room,
    required ProjectNorth projectNorth,
    SolarSiteContext? solarContext,
  }) {
    final frame = planFrameForWindow(window: window, room: room);
    return _reach(
      window: window,
      facadeAzimuthDegrees: projectNorth.toTrueAzimuth(
        frame.facadePlanAzimuthDegrees,
      ),
      solarContext: solarContext,
    );
  }

  static DaylightPlanFrame planFrameForWindow({
    required DaylightWindowInput window,
    required EngineeringSpace room,
  }) {
    if (window.wall.spaceId != room.id || window.wall.wallIndex == null) {
      throw ArgumentError('Daylight window does not belong to the room.');
    }
    final wall = RoomSurfaceResolver.wall(room, window.wall.wallIndex!);
    final wallLength = wall.lengthMm;
    if (wallLength <= 0) {
      throw StateError('Daylight host wall has zero length.');
    }
    final halfWidth = window.widthMm / 2.0;
    if (window.centerOffsetMm - halfWidth < 0 ||
        window.centerOffsetMm + halfWidth > wallLength) {
      throw ArgumentError('Daylight window width exceeds the host wall.');
    }

    final dx = (wall.end.x - wall.start.x).toDouble();
    final dy = (wall.end.y - wall.start.y).toDouble();
    final tangentX = dx / wallLength;
    final tangentY = dy / wallLength;

    // For a CCW room polygon the interior lies to the left of every boundary
    // edge. For CW geometry it lies to the right. This keeps inward direction
    // correct after arbitrary room rotation and imported polygon orientation.
    final area2 = _signedArea2(room.boundary);
    if (area2 == 0) {
      throw ArgumentError('Room boundary has zero signed area.');
    }
    final inwardX = area2 > 0 ? -tangentY : tangentY;
    final inwardY = area2 > 0 ? tangentX : -tangentX;
    final outwardX = -inwardX;
    final outwardY = -inwardY;

    return DaylightPlanFrame(
      windowCenter: RoomSurfaceResolver.wallLocalToPlan(
        wall,
        window.centerOffsetMm,
      ),
      tangentX: tangentX,
      tangentY: tangentY,
      inwardX: inwardX,
      inwardY: inwardY,
      facadePlanAzimuthDegrees: _planAzimuthDegrees(outwardX, outwardY),
    );
  }

  /// Geometry-aware ceiling hints for arbitrary room rotation and wall
  /// orientation. Candidate points are clipped to the actual room polygon.
  static List<LightingPlacementHint> ceilingHintsForRoom({
    required EngineeringSpace room,
    required DaylightWindowInput window,
    required DaylightReachZone daylight,
    int preferredSpacingMm = 1800,
  }) {
    if (preferredSpacingMm <= 0) return const [];
    if (daylight.windowId != window.id) {
      throw ArgumentError('Daylight reach does not belong to the window.');
    }

    final frame = planFrameForWindow(window: window, room: room);
    final bounds = room.boundary.bounds;
    if (bounds.width <= 0 || bounds.height <= 0) return const [];

    final columns = math.max(1, (bounds.width / preferredSpacingMm).ceil());
    final rows = math.max(1, (bounds.height / preferredSpacingMm).ceil());
    final stepX = bounds.width / columns;
    final stepY = bounds.height / rows;
    final effectiveDepth = math.max(1, daylight.effectiveDepthMm).toDouble();
    final lateralScale = math.max(
      preferredSpacingMm.toDouble(),
      window.widthMm * 0.75,
    );
    final hints = <LightingPlacementHint>[];

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final point = MmPoint(
          (bounds.left + stepX * (column + 0.5)).round(),
          (bounds.bottom + stepY * (row + 0.5)).round(),
        );
        if (!room.boundary.contains(point)) continue;

        final depth = frame.depthMm(point);
        if (depth < 0) continue;
        final lateral = frame.lateralOffsetMm(point).abs();
        final depthInfluence = depth >= effectiveDepth
            ? 0.0
            : 1.0 - depth / effectiveDepth;
        final lateralRatio = lateral / lateralScale;
        final lateralInfluence = 1.0 / (1.0 + lateralRatio * lateralRatio);
        final daylightInfluence =
            (daylight.centerlineStrength * depthInfluence * lateralInfluence)
                .clamp(0.0, 1.0)
                .toDouble();
        final priority = (0.45 + 0.55 * (1.0 - daylightInfluence))
            .clamp(0.0, 1.0)
            .toDouble();

        hints.add(
          LightingPlacementHint(
            position: SurfacePointMm(point.x, point.y),
            reason: daylightInfluence >= 0.45
                ? 'Зона заметного естественного света: искусственный свет можно снизить.'
                : 'Глубокая/боковая зона: повышенный приоритет искусственного света.',
            priority: priority,
            daylightInfluence: daylightInfluence,
          ),
        );
      }
    }
    return List.unmodifiable(hints);
  }

  /// Legacy rectangular helper. [roomDepthMm] is measured inward from the
  /// facade/window wall. Prefer [ceilingHintsForRoom] for editor geometry.
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
          daylightInfluence: daylight.centerlineStrength,
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
        final depthFactor = y / roomDepthMm;
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

  static DaylightReachZone _reach({
    required DaylightWindowInput window,
    required double facadeAzimuthDegrees,
    required SolarSiteContext? solarContext,
  }) {
    // Early-design heuristic only. It is intentionally not a daylight-factor
    // or illuminance calculation.
    const assumedWorkPlaneHeightMm = 800;
    final headHeightMm = window.sillHeightMm + window.heightMm;
    final heightAboveWorkPlane = math.max(
      0,
      headHeightMm - assumedWorkPlaneHeightMm,
    );
    final nominalDepth = (heightAboveWorkPlane * 1.75).round();

    final orientationWeight = _orientationWeight(
      facadeAzimuthDegrees,
      solarContext,
    );
    final strength = (window.visibleLightTransmittance * orientationWeight)
        .clamp(0.15, 1.0)
        .toDouble();
    final effectiveDepth = (nominalDepth * strength).round();

    return DaylightReachZone(
      windowId: window.id,
      facadeAzimuthDegrees: facadeAzimuthDegrees,
      nominalDepthMm: nominalDepth,
      effectiveDepthMm: effectiveDepth,
      centerlineStrength: strength,
    );
  }

  static double _orientationWeight(
    double azimuth,
    SolarSiteContext? solarContext,
  ) {
    // Without latitude, orientation alone is insufficient evidence to claim
    // that one facade receives more useful daylight than another.
    if (solarContext == null) return 1.0;

    final preferredAzimuth = solarContext.latitudeDegrees >= 0 ? 180.0 : 0.0;
    final radians = (azimuth - preferredAzimuth) * math.pi / 180;
    final facingPreference = (math.cos(radians) + 1) / 2;
    return 0.55 + 0.45 * facingPreference;
  }

  static double _signedArea2(MmPolygon polygon) {
    var total = 0.0;
    final vertices = polygon.vertices;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      total += (a.x * b.y - b.x * a.y).toDouble();
    }
    return total;
  }

  static double _planAzimuthDegrees(double x, double y) {
    var degrees = math.atan2(x, y) * 180 / math.pi;
    if (degrees < 0) degrees += 360;
    return degrees;
  }
}
