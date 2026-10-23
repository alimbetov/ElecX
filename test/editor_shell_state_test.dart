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

  test('compass is opt-in and hidden by default', () {
    final shell = EditorShellState();

    expect(shell.compassRequestedVisible, isFalse);
    expect(shell.compassSuppressedByFocusMode, isFalse);
    expect(shell.compassVisible, isFalse);
  });

  test('focus mode suppresses compass without losing requested visibility', () {
    final shell = EditorShellState();
    shell.toggleCompass();

    expect(shell.compassRequestedVisible, isTrue);
    expect(shell.compassSuppressedByFocusMode, isFalse);
    expect(shell.compassVisible, isTrue);

    shell.toggleFocusMode();
    expect(shell.focusMode, isTrue);
    expect(shell.compassRequestedVisible, isTrue);
    expect(shell.compassSuppressedByFocusMode, isTrue);
    expect(shell.compassVisible, isFalse);

    shell.toggleFocusMode();
    expect(shell.focusMode, isFalse);
    expect(shell.compassRequestedVisible, isTrue);
    expect(shell.compassSuppressedByFocusMode, isFalse);
    expect(shell.compassVisible, isTrue);
  });

  test('compass preference can change while focus mode remains active', () {
    final shell = EditorShellState();
    shell.setFocusMode(true);

    shell.toggleCompass();
    expect(shell.compassRequestedVisible, isTrue);
    expect(shell.compassSuppressedByFocusMode, isTrue);
    expect(shell.compassVisible, isFalse);

    shell.toggleCompass();
    expect(shell.compassRequestedVisible, isFalse);
    expect(shell.compassSuppressedByFocusMode, isFalse);
    expect(shell.compassVisible, isFalse);

    shell.setCompassRequestedVisible(true);
    expect(shell.compassRequestedVisible, isTrue);
    expect(shell.compassSuppressedByFocusMode, isTrue);
    expect(shell.compassVisible, isFalse);

    shell.exitFocusMode();
    expect(shell.compassSuppressedByFocusMode, isFalse);
    expect(shell.compassVisible, isTrue);
  });

  test('setting the same compass request is notification-idempotent', () {
    final shell = EditorShellState();
    var notifications = 0;
    shell.addListener(() => notifications += 1);

    shell.setCompassRequestedVisible(false);
    expect(notifications, 0);

    shell.setCompassRequestedVisible(true);
    expect(notifications, 1);

    shell.setCompassRequestedVisible(true);
    expect(notifications, 1);
  });

  test('setting focus mode is deterministic and notification-idempotent', () {
    final shell = EditorShellState();
    shell.setCompassRequestedVisible(true);
    var notifications = 0;
    shell.addListener(() => notifications += 1);

    shell.setFocusMode(false);
    expect(notifications, 0);
    expect(shell.compassVisible, isTrue);

    shell.setFocusMode(true);
    expect(notifications, 1);
    expect(shell.focusMode, isTrue);
    expect(shell.compassRequestedVisible, isTrue);
    expect(shell.compassSuppressedByFocusMode, isTrue);
    expect(shell.compassVisible, isFalse);

    shell.setFocusMode(true);
    expect(notifications, 1);

    shell.setFocusMode(false);
    expect(notifications, 2);
    expect(shell.focusMode, isFalse);
    expect(shell.compassRequestedVisible, isTrue);
    expect(shell.compassSuppressedByFocusMode, isFalse);
    expect(shell.compassVisible, isTrue);
  });
}
