import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/engine/render_policy.dart';
import 'package:elecx/src/engine/spatial_index.dart';
import 'package:elecx/src/engine/world_camera.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Item implements SpatialIndexItem {
  const _Item(this.spatialId, this.spatialBounds);

  @override
  final String spatialId;

  @override
  final MmBounds spatialBounds;
}

void main() {
  group('WorldCamera', () {
    test('cursor anchored zoom preserves world point under cursor', () {
      const camera = WorldCamera(
        centerMm: MmPoint(10000, 5000),
        mmPerPixel: 10,
      );
      final before = camera.screenToWorld(
        viewportWidthPx: 1200,
        viewportHeightPx: 800,
        xPx: 900,
        yPx: 300,
      );
      final zoomed = camera.zoomAt(
        factor: 2,
        viewportWidthPx: 1200,
        viewportHeightPx: 800,
        cursorXpx: 900,
        cursorYpx: 300,
      );
      final after = zoomed.screenToWorld(
        viewportWidthPx: 1200,
        viewportHeightPx: 800,
        xPx: 900,
        yPx: 300,
      );
      expect(after, before);
      expect(zoomed.mmPerPixel, 5);
    });

    test('visible bounds include overscan', () {
      const camera = WorldCamera(centerMm: MmPoint(0, 0), mmPerPixel: 10);
      final bounds = camera.visibleWorldBounds(
        viewportWidthPx: 100,
        viewportHeightPx: 100,
        overscanPx: 10,
      );
      expect(bounds.left, -600);
      expect(bounds.right, 600);
      expect(bounds.bottom, -600);
      expect(bounds.top, 600);
    });
  });

  group('SpatialHashIndex', () {
    test('query returns only intersecting visible items', () {
      final index = SpatialHashIndex<_Item>(cellSizeMm: 1000);
      index.upsert(const _Item(
        'visible',
        MmBounds(left: 100, bottom: 100, right: 300, top: 300),
      ));
      index.upsert(const _Item(
        'hidden',
        MmBounds(left: 5000, bottom: 5000, right: 5200, top: 5200),
      ));
      final result = index.query(
        const MmBounds(left: 0, bottom: 0, right: 1000, top: 1000),
      );
      expect(result.map((item) => item.spatialId), ['visible']);
    });

    test('supports negative coordinates and removes stale cells', () {
      final index = SpatialHashIndex<_Item>(cellSizeMm: 1000);
      index.upsert(const _Item(
        'item',
        MmBounds(left: -1500, bottom: -500, right: -100, top: 100),
      ));
      expect(
        index.query(
          const MmBounds(left: -2000, bottom: -1000, right: 0, top: 500),
        ),
        hasLength(1),
      );

      index.upsert(const _Item(
        'item',
        MmBounds(left: 10000, bottom: 10000, right: 10100, top: 10100),
      ));
      expect(
        index.query(
          const MmBounds(left: -2000, bottom: -1000, right: 0, top: 500),
        ),
        isEmpty,
      );
      expect(index.length, 1);
    });
  });

  test('LOD becomes progressively richer as scale gets closer', () {
    expect(RenderPolicy.lodForWorldUnitsPerPixel(6000), RenderLod.site);
    expect(RenderPolicy.lodForWorldUnitsPerPixel(1500), RenderLod.building);
    expect(RenderPolicy.lodForWorldUnitsPerPixel(300), RenderLod.level);
    expect(RenderPolicy.lodForWorldUnitsPerPixel(50), RenderLod.room);
    expect(RenderPolicy.lodForWorldUnitsPerPixel(5), RenderLod.detail);
  });
}
