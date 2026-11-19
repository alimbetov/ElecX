import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_keyboard_scope.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_viewport_commands.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'text field input never invokes canvas tool or viewport shortcuts',
      (tester) async {
    final editor = EditorController.demo();
    final focus = FocusNode();
    final canvasFocus = FocusNode();
    addTearDown(() {
      focus.dispose();
      canvasFocus.dispose();
      editor.disposeP2State();
      editor.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: EditorKeyboardScope(
          controller: editor,
          child: Column(children: [
            TextField(focusNode: focus),
            Focus(focusNode: canvasFocus, child: const SizedBox(height: 40))
          ])),
    )));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final revision = editor.viewportCommandRevision;
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    expect(editor.viewportCommandRevision, revision);
    expect(editor.tool, EditorTool.select);
    canvasFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    expect(editor.tool, EditorTool.guide);
  });
}
