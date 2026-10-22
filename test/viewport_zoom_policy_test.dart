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

  test('F12 horizontal scroll does not zoom', () {
    expect(
      ViewportZoomPolicy.factorForScrollDelta(dx: 80, dy: 0),
      isNull,
    );
    expect(
      ViewportZoomPolicy.factorForScrollDelta(dx: 80, dy: 10),
      isNull,
    );
  });

  test('F12 wheel zoom follows magnitude and direction with a safe cap', () {
    final tinyIn = ViewportZoomPolicy.factorForScrollDelta(dx: 0, dy: -1)!;
    final largeIn = ViewportZoomPolicy.factorForScrollDelta(dx: 0, dy: -120)!;
    final hugeIn = ViewportZoomPolicy.factorForScrollDelta(dx: 0, dy: -1200)!;
    final out = ViewportZoomPolicy.factorForScrollDelta(dx: 0, dy: 120)!;

    expect(tinyIn, greaterThan(1));
    expect(tinyIn, lessThan(largeIn));
    expect(largeIn, ViewportZoomPolicy.maxWheelFactor);
    expect(hugeIn, ViewportZoomPolicy.maxWheelFactor);
    expect(out, closeTo(1 / ViewportZoomPolicy.maxWheelFactor, 1e-9));
  });
}
