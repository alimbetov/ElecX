import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/engine/adaptive_grid.dart';
import 'package:elecx/src/engine/performance_scene.dart';
import 'package:elecx/src/engine/spatial_scene_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('10k-room benchmark culls to local viewport candidates', () {
    final scene = PerformanceScene.grid(columns: 100, rows: 100);
    expect(scene.spaces, hasLength(10000));

    final index = SpatialSceneIndex(cellSizeMm: 5000)
      ..rebuildSpaces(scene.spaces);
    final visible = index.visibleSpaces(
      const MmBounds(left: 0, bottom: 0, right: 20000, top: 15000),
    );

    expect(visible.length, lessThan(100));
    expect(index.spaces.length, 10000);
  });

  test('adaptive grid keeps useful screen spacing across scales', () {
    final detail = AdaptiveGridPolicy.forScale(2);
    final room = AdaptiveGridPolicy.forScale(20);
    final site = AdaptiveGridPolicy.forScale(2000);

    expect(detail.minorStepMm, lessThan(room.minorStepMm));
    expect(room.minorStepMm, lessThan(site.minorStepMm));
    expect(detail.majorStepMm, greaterThan(detail.minorStepMm));
  });
}
