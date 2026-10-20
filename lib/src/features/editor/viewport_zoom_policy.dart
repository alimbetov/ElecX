abstract final class ViewportZoomPolicy {
  static const double maxZoomInFromFit = 20;
  static const double maxZoomOutFromFit = 8;
  static const double absoluteMinMmPerPixel = 0.25;
  static const double maxWheelFactor = 1.18;
  static const double wheelReferenceDelta = 120;

  static double minMmPerPixel(double fitMmPerPixel) {
    if (fitMmPerPixel <= 0) {
      throw ArgumentError.value(fitMmPerPixel, 'fitMmPerPixel');
    }
    final relative = fitMmPerPixel / maxZoomInFromFit;
    return relative < absoluteMinMmPerPixel ? absoluteMinMmPerPixel : relative;
  }

  static double maxMmPerPixel(double fitMmPerPixel) {
    if (fitMmPerPixel <= 0) {
      throw ArgumentError.value(fitMmPerPixel, 'fitMmPerPixel');
    }
    return fitMmPerPixel * maxZoomOutFromFit;
  }

  /// Returns null when a pointer signal should not be treated as zoom.
  /// Horizontal/zero scroll is intentionally left to the surrounding scroll
  /// hierarchy. Vertical zoom scales with delta magnitude and is capped so a
  /// single high-resolution wheel event cannot cause a large jump.
  static double? factorForScrollDelta({
    required double dx,
    required double dy,
  }) {
    final vertical = dy.abs();
    if (vertical == 0 || dx.abs() > vertical) return null;
    final normalized = (vertical / wheelReferenceDelta).clamp(0.0, 1.0);
    if (normalized == 0) return null;
    final zoomInFactor = 1 + (maxWheelFactor - 1) * normalized;
    return dy < 0 ? zoomInFactor : 1 / zoomInFactor;
  }
}
