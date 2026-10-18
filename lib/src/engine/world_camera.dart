import 'dart:math' as math;

import '../domain/geometry.dart';

final class WorldCamera {
  const WorldCamera({
    required this.centerMm,
    required this.mmPerPixel,
  }) : assert(mmPerPixel > 0);

  final MmPoint centerMm;
  final double mmPerPixel;

  WorldCamera zoomAt({
    required double factor,
    required double viewportWidthPx,
    required double viewportHeightPx,
    required double cursorXpx,
    required double cursorYpx,
    double minMmPerPixel = 0.1,
    double maxMmPerPixel = 100000,
  }) {
    if (factor <= 0) throw ArgumentError.value(factor, 'factor');
    final before = screenToWorld(
      viewportWidthPx: viewportWidthPx,
      viewportHeightPx: viewportHeightPx,
      xPx: cursorXpx,
      yPx: cursorYpx,
    );
    final nextScale = (mmPerPixel / factor).clamp(
      minMmPerPixel,
      maxMmPerPixel,
    );
    final provisional = WorldCamera(
      centerMm: centerMm,
      mmPerPixel: nextScale.toDouble(),
    );
    final after = provisional.screenToWorld(
      viewportWidthPx: viewportWidthPx,
      viewportHeightPx: viewportHeightPx,
      xPx: cursorXpx,
      yPx: cursorYpx,
    );
    return WorldCamera(
      centerMm: MmPoint(
        centerMm.x + before.x - after.x,
        centerMm.y + before.y - after.y,
      ),
      mmPerPixel: nextScale.toDouble(),
    );
  }

  WorldCamera panPixels(double dxPx, double dyPx) => WorldCamera(
        centerMm: MmPoint(
          centerMm.x - (dxPx * mmPerPixel).round(),
          centerMm.y + (dyPx * mmPerPixel).round(),
        ),
        mmPerPixel: mmPerPixel,
      );

  MmPoint screenToWorld({
    required double viewportWidthPx,
    required double viewportHeightPx,
    required double xPx,
    required double yPx,
  }) =>
      MmPoint(
        (centerMm.x + (xPx - viewportWidthPx / 2) * mmPerPixel).round(),
        (centerMm.y - (yPx - viewportHeightPx / 2) * mmPerPixel).round(),
      );

  MmBounds visibleWorldBounds({
    required double viewportWidthPx,
    required double viewportHeightPx,
    int overscanPx = 64,
  }) {
    final halfWidth = ((viewportWidthPx / 2 + overscanPx) * mmPerPixel).ceil();
    final halfHeight = ((viewportHeightPx / 2 + overscanPx) * mmPerPixel).ceil();
    return MmBounds(
      left: centerMm.x - halfWidth,
      bottom: centerMm.y - halfHeight,
      right: centerMm.x + halfWidth,
      top: centerMm.y + halfHeight,
    );
  }

  WorldCamera fitBounds({
    required MmBounds bounds,
    required double viewportWidthPx,
    required double viewportHeightPx,
    double paddingPx = 64,
  }) {
    final usableWidth = math.max(1.0, viewportWidthPx - paddingPx * 2);
    final usableHeight = math.max(1.0, viewportHeightPx - paddingPx * 2);
    final scaleX = math.max(1, bounds.width) / usableWidth;
    final scaleY = math.max(1, bounds.height) / usableHeight;
    return WorldCamera(
      centerMm: bounds.center,
      mmPerPixel: math.max(scaleX, scaleY),
    );
  }
}
