import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/engine/plan_geometry_editing.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/plan_geometry_editor_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vertex handle moves one boundary vertex', () {
    final source = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );

    final edited = PlanGeometryEditing.moveVertex(
      boundary: source,
      vertexIndex: 2,
      target: const MmPoint(4500, 3300),
    );

    expect(edited, isNotNull);
    expect(edited!.vertices[2], const MmPoint(4500, 3300));
    expect(edited.vertices[0], source.vertices[0]);
  });

  test('edge handle moves wall parallel to itself', () {
    final source = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );

    final edited = PlanGeometryEditing.moveEdge(
      boundary: source,
      edgeIndex: 0,
      dragStart: const MmPoint(2000, 0),
      dragCurrent: const MmPoint(2300, 500),
    );

    expect(edited, isNotNull);
    expect(edited!.vertices[0], const MmPoint(0, 500));
    expect(edited.vertices[1], const MmPoint(4000, 500));
    expect(edited.vertices[2], const MmPoint(4000, 3000));
  });

  test('invalid short edge is rejected', () {
    final source = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );

    final edited = PlanGeometryEditing.moveVertex(
      boundary: source,
      vertexIndex: 1,
      target: const MmPoint(100, 0),
    );

    expect(edited, isNull);
  });

  test('self-intersecting polygon is rejected', () {
    final source = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );

    final edited = PlanGeometryEditing.moveVertex(
      boundary: source,
      vertexIndex: 1,
      target: const MmPoint(2000, 4000),
    );

    expect(edited, isNull);
  });

  test('controller commits valid selected boundary atomically', () {
    final controller = EditorController.demo();
    final source = controller.selectedSpace!.boundary;
    final edited = PlanGeometryEditing.moveEdge(
      boundary: source,
      edgeIndex: 1,
      dragStart: const MmPoint(5200, 2800),
      dragCurrent: const MmPoint(5600, 2800),
    );

    expect(edited, isNotNull);
    expect(controller.commitSelectedBoundary(edited!), isTrue);
    expect(controller.selectedSpace!.boundary.bounds.right, 5600);
  });

  test('controller rejects boundary that invalidates hosted opening', () {
    final controller = EditorController.demo();
    final source = controller.selectedSpace!.boundary;
    final edited = PlanGeometryEditing.moveVertex(
      boundary: source,
      vertexIndex: 3,
      target: const MmPoint(3000, 4400),
    );

    expect(edited, isNotNull);
    expect(controller.commitSelectedBoundary(edited!), isFalse);
    expect(controller.selectedSpace!.boundary.vertices[3], source.vertices[3]);
  });
}
