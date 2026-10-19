import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/catalog_component_placement.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog component ids remain monotonic after delete and re-add', () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);
    controller.showWall(0);
    final wall = controller.activeSurface!;

    final first = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('power.socket.general'),
      surface: wall,
      position: const SurfacePointMm(600, 300),
    );

    expect(controller.p2.deleteSelection(), isTrue);

    final second = controller.p2.placeCatalogComponent(
      entry: ComponentCatalogV2.require('power.socket.general'),
      surface: wall,
      position: const SurfacePointMm(1200, 300),
    );

    expect(second.id, isNot(first.id));
    expect(second.id, startsWith('component-2-'));
    expect(controller.p2.components.map((item) => item.id).toSet().length, 1);
  });
}
