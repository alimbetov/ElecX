import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/engine/world_camera.dart';
import 'package:elecx/src/features/editor/dynamic_wall_dimensions_overlay.dart';
import 'package:elecx/src/features/editor/wall_distance_guide_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Distance hold preserves last snapshot after deselection',
      (tester) async {
    final held = ValueNotifier<bool>(false);
    final room = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final guides = WallDistanceGuideCalculator.fromAnchor(
      room: room,
      anchor: const MmPoint(2000, 1500),
    );
    String? selected = 'socket-01';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: 600,
                height: 400,
                child: DynamicWallDimensionsOverlay(
                  selectionId: selected,
                  sceneId: 'project-a/level-1',
                  guides: selected == null ? const [] : guides,
                  camera: const WorldCamera(
                    centerMm: MmPoint(2000, 1500),
                    mmPerPixel: 10,
                  ),
                  viewport: const Size(600, 400),
                  held: held,
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('dynamic-wall-dimensions')),
        findsOneWidget);
    held.value = true;
    await tester.pump();
    update(() => selected = null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.byKey(const ValueKey('dynamic-wall-dimensions')),
        findsOneWidget);

    held.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump(const Duration(milliseconds: 720));
    await tester.pump();
    expect(find.byKey(const ValueKey('dynamic-wall-dimensions')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    held.dispose();
  });

  testWidgets('without hold, deselection eventually removes guides',
      (tester) async {
    final held = ValueNotifier<bool>(false);
    final room = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final guides = WallDistanceGuideCalculator.fromAnchor(
      room: room,
      anchor: const MmPoint(1800, 1500),
    );
    String? selection = 'device';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return DynamicWallDimensionsOverlay(
              selectionId: selection,
              sceneId: 'level-1',
              guides: selection == null ? const [] : guides,
              camera: const WorldCamera(
                centerMm: MmPoint(2000, 1500),
                mmPerPixel: 10,
              ),
              viewport: const Size(600, 400),
              held: held,
            );
          },
        ),
      ),
    );
    update(() => selection = null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pump(const Duration(milliseconds: 370));
    await tester.pump();
    expect(find.byKey(const ValueKey('dynamic-wall-dimensions')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    held.dispose();
  });
}
