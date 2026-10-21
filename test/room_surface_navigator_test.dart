import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_shell_state.dart';
import 'package:elecx/src/features/editor/room_surface_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projection fails closed when canonical and editor room affinity differ',
      () {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    expect(
      RoomSurfaceNavigatorProjection.fromEditor(
        controller: controller,
        canonicalSpaceId: SpaceId('canonical-room'),
        legacySpaceId: 'another-room',
      ),
      isNull,
    );
  });

  testWidgets('selected room reveals one navigator and drives editor surface',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomSurfaceNavigator(
            controller: controller,
            canonicalSpaceId: SpaceId('canonical-room-101'),
            legacySpaceId: 'room-101',
            collapsed: false,
            onToggleCollapsed: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('room-surface-navigator')),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('room-surface-mini-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-surface-wall-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-surface-wall-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-surface-wall-4')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('room-surface-floor')));
    await tester.pump();
    expect(controller.activeSurface?.type, SurfacePlaneType.floor);
    expect(find.text('Current surface: Floor'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('room-surface-ceiling')));
    await tester.pump();
    expect(controller.activeSurface?.type, SurfacePlaneType.ceiling);
    expect(find.text('Current surface: Ceiling'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('room-surface-wall-2')));
    await tester.pump();
    expect(controller.activeSurface?.type, SurfacePlaneType.wall);
    expect(controller.activeSurface?.wallIndex, 2);
    expect(find.text('Current surface: Wall 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Wall 3, current surface'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('room-surface-plan')));
    await tester.pump();
    expect(controller.viewMode, EditorViewMode.plan);
    expect(controller.activeSurface, isNull);
    expect(find.text('Current surface: Plan'), findsOneWidget);
  });

  testWidgets('L-shaped room exposes every real boundary wall', (tester) async {
    final controller = _lShapedController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: RoomSurfaceNavigator(
          controller: controller,
          canonicalSpaceId: SpaceId('canonical-l-room'),
          legacySpaceId: 'l-room',
          collapsed: false,
          onToggleCollapsed: () {},
        ),
      ),
    );

    for (var index = 0; index < 6; index++) {
      expect(
        find.byKey(ValueKey('room-surface-wall-$index')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey('room-surface-wall-6')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('room-surface-wall-5')));
    await tester.pump();
    expect(controller.activeSurface?.wallIndex, 5);
    expect(find.text('Current surface: Wall 6'), findsOneWidget);
  });

  testWidgets('canvas/editor surface changes update navigator highlight',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: RoomSurfaceNavigator(
          controller: controller,
          canonicalSpaceId: SpaceId('canonical-room-101'),
          legacySpaceId: 'room-101',
          collapsed: false,
          onToggleCollapsed: () {},
        ),
      ),
    );

    controller.showWall(1);
    await tester.pump();

    expect(find.text('Current surface: Wall 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Wall 2, current surface'), findsOneWidget);
  });

  testWidgets('collapse is shell-only and preserves room and active surface',
      (tester) async {
    final controller = EditorController.demo();
    final shell = EditorShellState();
    addTearDown(controller.dispose);
    addTearDown(shell.dispose);

    controller.showWall(2);
    final selectedBefore = controller.selectedSpaceId;
    final surfaceBefore = controller.activeSurface;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: shell,
          builder: (context, _) => RoomSurfaceNavigator(
            controller: controller,
            canonicalSpaceId: SpaceId('canonical-room-101'),
            legacySpaceId: 'room-101',
            collapsed: shell.roomSurfaceNavigatorCollapsed,
            onToggleCollapsed: shell.toggleRoomSurfaceNavigatorCollapsed,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('room-surface-collapse')));
    await tester.pump();

    expect(shell.roomSurfaceNavigatorCollapsed, isTrue);
    expect(find.byKey(const ValueKey('room-surface-mini-view')), findsNothing);
    expect(controller.selectedSpaceId, selectedBefore);
    expect(controller.activeSurface, surfaceBefore);

    await tester.tap(find.byKey(const ValueKey('room-surface-collapse')));
    await tester.pump();

    expect(shell.roomSurfaceNavigatorCollapsed, isFalse);
    expect(
        find.byKey(const ValueKey('room-surface-mini-view')), findsOneWidget);
    expect(find.text('Current surface: Wall 3'), findsOneWidget);
  });

  testWidgets('navigator is hidden when no room is selected', (tester) async {
    final controller = EditorController.demo()..selectSpace(null);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: RoomSurfaceNavigator(
          controller: controller,
          canonicalSpaceId: null,
          legacySpaceId: null,
          collapsed: false,
          onToggleCollapsed: () {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('room-surface-navigator')),
      findsNothing,
    );
  });
}

EditorController _lShapedController() {
  final boundary = MmPolygon(const [
    MmPoint(0, 0),
    MmPoint(6000, 0),
    MmPoint(6000, 2500),
    MmPoint(3500, 2500),
    MmPoint(3500, 5000),
    MmPoint(0, 5000),
  ]);
  final controller = EditorController.restored(
    level: BuildingLevel(
      id: 'level-l',
      name: 'L Level',
      elevationMm: 0,
      spaces: [
        EngineeringSpace(
          id: 'l-room',
          name: 'L Room',
          type: SpaceType.room,
          boundary: boundary,
          referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
        ),
      ],
    ),
    openings: const [],
  );
  controller.selectSpace('l-room');
  return controller;
}
