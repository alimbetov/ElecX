import 'package:elecx/src/features/editor/cable_authoring_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget screen({
    bool source = false,
    bool draft = false,
    bool targets = false,
    bool ready = false,
    bool disconnected = false,
    bool remote = false,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: CableAuthoringGuidance(
            hasSource: source,
            hasDraft: draft,
            hasCompatibleTarget: targets,
            readyToFinish: ready,
            transitionDisconnected: disconnected,
            crossRoomBlocked: remote,
          ),
        ),
      );

  testWidgets('initial guide asks for a source port', (tester) async {
    await tester.pumpWidget(screen());
    expect(
        find.byKey(const ValueKey('cable-guided-authoring')), findsOneWidget);
    expect(find.textContaining('Выберите щит'), findsOneWidget);
    expect(find.text('1 · Источник'), findsOneWidget);
  });

  testWidgets('after source guide explains physical routing', (tester) async {
    await tester.pumpWidget(screen(source: true, draft: true));
    expect(find.textContaining('общего ребра'), findsOneWidget);
    expect(find.text('2 · Путь'), findsOneWidget);
  });

  testWidgets('compatible target advances to destination step', (tester) async {
    await tester.pumpWidget(screen(source: true, draft: true, targets: true));
    expect(find.textContaining('совместимый конечный порт'), findsOneWidget);
    expect(find.text('3 · Приёмник'), findsOneWidget);
  });

  testWidgets('ready means confirm; it does not auto-commit', (tester) async {
    await tester.pumpWidget(
      screen(source: true, draft: true, targets: true, ready: true),
    );
    expect(find.textContaining('нажмите «Завершить»'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('disconnected transition takes priority over ready state',
      (tester) async {
    await tester.pumpWidget(
      screen(
        source: true,
        draft: true,
        targets: true,
        ready: true,
        disconnected: true,
      ),
    );
    expect(find.textContaining('Переход не подтверждён'), findsOneWidget);
    expect(find.textContaining('нажмите «Завершить»'), findsNothing);
  });

  testWidgets('remote compatible devices still need a physical passage',
      (tester) async {
    await tester.pumpWidget(screen(source: true, draft: true, remote: true));
    expect(find.textContaining('подтверждённая проходка'), findsOneWidget);
    expect(
        find.textContaining('соединение напрямую запрещено'), findsOneWidget);
  });
}
