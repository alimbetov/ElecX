abstract final class ViewportZoomPolicy {
  static const double maxZoomInFromFit = 20;
  static const double maxZoomOutFromFit = 8;
  static const double absoluteMinMmPerPixel = 0.25;

  static double minMmPerPixel(double fitMmPerPixel) {
    if (fitMmPerPixel <= 0) {
      throw ArgumentError.value(fitMmPerPixel, 'fitMmPerPixel');
    }
    final relative = fitMmPerPixel / maxZoomInFromFit;
    return relative < absoluteMinMmPerPixel
        ? absoluteMinMmPerPixel
        : relative;
  }

  static double maxMmPerPixel(double fitMmPerPixel) {
    if (fitMmPerPixel <= 0) {
      throw ArgumentError.value(fitMmPerPixel, 'fitMmPerPixel');
    }
    return fitMmPerPixel * maxZoomOutFromFit;
  }
}
