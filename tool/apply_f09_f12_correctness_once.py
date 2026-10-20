from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor missing in {path}: {old[:160]!r}')
    p.write_text(text.replace(old, new, 1))

# F09: route selection owns the visible route context. Any geometry focus from
# the previously selected route must be cleared before controls can act.
replace_once(
    'lib/src/features/editor/route_selection_session.dart',
    "import 'editor_controller.dart';\n",
    "import 'cable_editor_ui_session.dart';\nimport 'editor_controller.dart';\n",
)
replace_once(
    'lib/src/features/editor/route_selection_session.dart',
    '''    if (_selectedRouteId == routeId) return;
    _selectedRouteId = routeId;
    if (routeId != null) controller.p2.clearSelection();
    notifyListeners();
''',
    '''    if (_selectedRouteId == routeId) return;
    _selectedRouteId = routeId;
    controller.cableUi.clearFocus();
    if (routeId != null) controller.p2.clearSelection();
    notifyListeners();
''',
)

# F12: one deterministic scroll policy shared by Plan and Surface.
viewport = Path('lib/src/features/editor/viewport_zoom_policy.dart')
viewport.write_text(r'''abstract final class ViewportZoomPolicy {
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
''')

for path in [
    'lib/src/features/editor/surface_canvas.dart',
    'lib/src/features/editor/editable_spatial_canvas.dart',
]:
    p = Path(path)
    text = p.read_text()
    if "import 'viewport_zoom_policy.dart';" not in text:
        anchor = "import 'editor_viewport_commands.dart';\n"
        if anchor not in text:
            raise SystemExit(f'viewport import anchor missing in {path}')
        text = text.replace(anchor, anchor + "import 'viewport_zoom_policy.dart';\n", 1)
    if path.endswith('surface_canvas.dart'):
        old = '''                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _zoomAt(
                      event.localPosition,
                      event.scrollDelta.dy < 0 ? 1.18 : 1 / 1.18,
                      extent,
                    );
                  }
                },'''
        new = '''                onPointerSignal: (event) {
                  if (event is! PointerScrollEvent) return;
                  final factor = ViewportZoomPolicy.factorForScrollDelta(
                    dx: event.scrollDelta.dx,
                    dy: event.scrollDelta.dy,
                  );
                  if (factor == null) return;
                  GestureBinding.instance.pointerSignalResolver.register(
                    event,
                    (_) => _zoomAt(event.localPosition, factor, extent),
                  );
                },'''
    else:
        old = '''                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _zoomAt(
                      event.localPosition,
                      event.scrollDelta.dy < 0 ? 1.18 : 1 / 1.18,
                    );
                  }
                },'''
        new = '''                onPointerSignal: (event) {
                  if (event is! PointerScrollEvent) return;
                  final factor = ViewportZoomPolicy.factorForScrollDelta(
                    dx: event.scrollDelta.dx,
                    dy: event.scrollDelta.dy,
                  );
                  if (factor == null) return;
                  GestureBinding.instance.pointerSignalResolver.register(
                    event,
                    (_) => _zoomAt(event.localPosition, factor),
                  );
                },'''
    if old not in text:
        raise SystemExit(f'pointer signal anchor missing in {path}')
    p.write_text(text.replace(old, new, 1))

# F09 focused regression.
Path('test/route_selection_focus_regression_test.dart').write_text(r'''import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/cable_editor_ui_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/route_selection_session.dart';
import 'package:flutter_test/flutter_test.dart';

ElectricalCableRoute _route(String id, int y) => ElectricalCableRoute(
      id: id,
      source: const ElectricalEndpointRef(componentId: 'source', portId: 'out'),
      target: const ElectricalEndpointRef(componentId: 'target', portId: 'in'),
      segments: [
        ElectricalRouteSegment(
          surface: RoomSurfaceRef.wall('room-101', 1),
          points: [SurfacePointMm(100, y), SurfacePointMm(1000, y)],
        ),
      ],
    );

void main() {
  test('F09 selecting another route clears stale cable geometry focus', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.restoreP2State(
      EditorP2State(routes: [_route('route-a', 500), _route('route-b', 800)]),
    );

    controller.routeSelection.select('route-a');
    controller.cableUi.focusGeometry(routeId: 'route-a', segmentIndex: 0);
    expect(controller.cableUi.activeRouteId, 'route-a');
    expect(controller.cableUi.activeSegmentIndex, 0);

    controller.routeSelection.select('route-b');
    expect(controller.routeSelection.selectedRouteId, 'route-b');
    expect(controller.cableUi.activeRouteId, isNull);
    expect(controller.cableUi.activeSegmentIndex, isNull);

    controller.cableUi.toggleActiveSegmentLock();
    expect(controller.p2.routeConstraintsFor('route-a').lockedSegments, isEmpty);
    expect(controller.p2.routeConstraintsFor('route-b').lockedSegments, isEmpty);
  });
}
''')

# F12 policy regressions.
p = Path('test/viewport_zoom_policy_test.dart')
text = p.read_text()
if 'F12 horizontal scroll does not zoom' not in text:
    idx = text.rfind('\n}')
    if idx == -1:
        raise SystemExit('viewport policy test closing brace missing')
    addition = r'''

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
'''
    text = text[:idx] + addition + text[idx:]
p.write_text(text)
