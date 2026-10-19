import 'package:elecx/src/features/editor/editor_shell_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('side panels collapse independently', () {
    final shell = EditorShellState();

    expect(shell.navigatorVisible, isTrue);
    expect(shell.inspectorVisible, isTrue);

    shell.toggleNavigator();
    expect(shell.navigatorVisible, isFalse);
    expect(shell.inspectorVisible, isTrue);

    shell.toggleInspector();
    expect(shell.navigatorVisible, isFalse);
    expect(shell.inspectorVisible, isFalse);
  });

  test('focus mode hides chrome without losing saved panel choices', () {
    final shell = EditorShellState();
    shell.toggleNavigator();

    shell.toggleFocusMode();
    expect(shell.focusMode, isTrue);
    expect(shell.navigatorVisible, isFalse);
    expect(shell.inspectorVisible, isFalse);
    expect(shell.contextBarVisible, isFalse);

    shell.toggleNavigator();
    shell.toggleInspector();
    shell.toggleContextBar();

    shell.toggleFocusMode();
    expect(shell.focusMode, isFalse);
    expect(shell.navigatorVisible, isFalse);
    expect(shell.inspectorVisible, isTrue);
    expect(shell.contextBarVisible, isTrue);
  });
}
