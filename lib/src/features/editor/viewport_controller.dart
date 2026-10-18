import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../domain/geometry.dart';

final class ViewportController extends ChangeNotifier {
  ViewportController({
    double zoom = 1.0,
    Offset panWorldMm = Offset.zero,
    this.minZoom = 0.35,
    this.maxZoom = 6.0,
  })  : _zoom = zoom,
        _panWorldMm = panWorldMm;

  final double minZoom;
  final double maxZoom;

  double _zoom;
  Offset _panWorldMm;

  double get zoom => _zoom;
  Offset get panWorldMm => _panWorldMm;

  void setZoom(double value) {
    final next = value.clamp(minZoom, maxZoom).toDouble();
    if (next == _zoom) return;
    _zoom = next;
    notifyListeners();
  }

  void zoomIn() => setZoom(_zoom * 1.25);
  void zoomOut() => setZoom(_zoom / 1.25);

  void reset() {
    _zoom = 1.0;
    _panWorldMm = Offset.zero;
    notifyListeners();
  }

  void panByWorld(Offset deltaWorldMm) {
    if (deltaWorldMm == Offset.zero) return;
    _panWorldMm += deltaWorldMm;
    notifyListeners();
  }

  Offset worldToScreen({
    required MmPoint point,
    required Size viewportSize,
    required MmBounds worldBounds,
  }) {
    final base = Offset(
      (point.x - worldBounds.left) / worldBounds.width * viewportSize.width,
      viewportSize.height -
          (point.y - worldBounds.bottom) /
              worldBounds.height *
              viewportSize.height,
    );
    final center = viewportSize.center(Offset.zero);
    final panScreen = Offset(
      _panWorldMm.dx / worldBounds.width * viewportSize.width,
      -_panWorldMm.dy / worldBounds.height * viewportSize.height,
    );
    return center + (base - center) * _zoom + panScreen * _zoom;
  }

  MmPoint screenToWorld({
    required Offset screen,
    required Size viewportSize,
    required MmBounds worldBounds,
  }) {
    final center = viewportSize.center(Offset.zero);
    final panScreen = Offset(
      _panWorldMm.dx / worldBounds.width * viewportSize.width,
      -_panWorldMm.dy / worldBounds.height * viewportSize.height,
    );
    final base = center + (screen - center) / _zoom - panScreen;
    return MmPoint(
      (worldBounds.left +
              base.dx / viewportSize.width * worldBounds.width)
          .round(),
      (worldBounds.bottom +
              (viewportSize.height - base.dy) /
                  viewportSize.height *
                  worldBounds.height)
          .round(),
    );
  }

  void zoomAroundScreenPoint({
    required double targetZoom,
    required Offset screenPoint,
    required Size viewportSize,
    required MmBounds worldBounds,
  }) {
    final anchor = screenToWorld(
      screen: screenPoint,
      viewportSize: viewportSize,
      worldBounds: worldBounds,
    );
    setZoom(targetZoom);
    final after = worldToScreen(
      point: anchor,
      viewportSize: viewportSize,
      worldBounds: worldBounds,
    );
    final deltaScreen = screenPoint - after;
    _panWorldMm += Offset(
      deltaScreen.dx / viewportSize.width * worldBounds.width / _zoom,
      -deltaScreen.dy / viewportSize.height * worldBounds.height / _zoom,
    );
    notifyListeners();
  }

  void fitBounds({
    required MmBounds target,
    required Size viewportSize,
    required MmBounds worldBounds,
    double paddingPx = 48,
  }) {
    if (target.width <= 0 || target.height <= 0) return;
    final availableWidth = (viewportSize.width - paddingPx * 2).clamp(1.0, double.infinity);
    final availableHeight = (viewportSize.height - paddingPx * 2).clamp(1.0, double.infinity);
    final worldPixelsPerMmX = viewportSize.width / worldBounds.width;
    final worldPixelsPerMmY = viewportSize.height / worldBounds.height;
    final zoomX = availableWidth / (target.width * worldPixelsPerMmX);
    final zoomY = availableHeight / (target.height * worldPixelsPerMmY);
    _zoom = zoomX < zoomY ? zoomX : zoomY;
    _zoom = _zoom.clamp(minZoom, maxZoom).toDouble();

    final worldCenter = worldBounds.center;
    final targetCenter = target.center;
    _panWorldMm = Offset(
      (worldCenter.x - targetCenter.x).toDouble(),
      (worldCenter.y - targetCenter.y).toDouble(),
    );
    notifyListeners();
  }
}
