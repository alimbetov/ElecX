import 'package:elecx/src/features/editor/viewport_zoom_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zoom range stays proportional to fitted drawing scale', () {
    expect(ViewportZoomPolicy.minMmPerPixel(10), 0.5);
    expect(ViewportZoomPolicy.maxMmPerPixel(10), 80);
  });

  test('zoom in never goes below absolute engineering floor', () {
    expect(ViewportZoomPolicy.minMmPerPixel(2), 0.25);
  });

  test('invalid fit scale is rejected', () {
    expect(() => ViewportZoomPolicy.minMmPerPixel(0), throwsArgumentError);
    expect(() => ViewportZoomPolicy.maxMmPerPixel(-1), throwsArgumentError);
  });
}
