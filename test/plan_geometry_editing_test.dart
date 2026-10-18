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

  test('opening remains selected while direct editing stays on plan', () {
    final controller = EditorController.demo();
    final opening = controller.openings.first;

    controller.selectOpeningForPlan(opening);

    expect(controller.selectedOpeningId, opening.id);
    expect(controller.viewMode, EditorViewMode.plan);
    expect(controller.activeSurface, opening.hostWall);
  });

  test('opening center drag moves opening along host wall', () {
    final controller = EditorController.demo();
    final opening = controller.openings.first;
    controller.selectOpeningForPlan(opening);

    expect(controller.moveSelectedOpeningAlongWall(1800), isTrue);
    expect(
      controller.selectedOpening!.offsetFromStartMm,
      1800 - opening.widthMm ~/ 2,
    );
  });

  test('opening edge drag resizes width and rejects invalid geometry', () {
    final controller = EditorController.demo();
    final opening = controller.openings.first;
    controller.selectOpeningForPlan(opening);

    final oldEnd = opening.offsetFromStartMm + opening.widthMm;
    expect(controller.resizeSelectedOpeningFromStart(400), isTrue);
    expect(controller.selectedOpening!.offsetFromStartMm, 400);
    expect(controller.selectedOpening!.widthMm, oldEnd - 400);

    final before = controller.selectedOpening!;
    expect(controller.resizeSelectedOpeningFromEnd(99999), isFalse);
    expect(controller.selectedOpening!.widthMm, before.widthMm);
  });
}
