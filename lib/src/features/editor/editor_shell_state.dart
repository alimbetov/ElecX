import 'package:flutter/foundation.dart';

final class EditorShellState extends ChangeNotifier {
  bool _navigatorVisible = true;
  bool _inspectorVisible = true;
  bool _contextBarVisible = true;
  bool _compassRequestedVisible = false;
  bool _focusMode = false;

  bool get navigatorVisible => _navigatorVisible && !_focusMode;
  bool get inspectorVisible => _inspectorVisible && !_focusMode;
  bool get contextBarVisible => _contextBarVisible && !_focusMode;

  /// User preference for the transient compass overlay in this editor session.
  ///
  /// Focus mode may temporarily suppress the effective visibility without
  /// changing this requested state.
  bool get compassRequestedVisible => _compassRequestedVisible;

  /// Whether focus mode is currently suppressing a requested compass overlay.
  bool get compassSuppressedByFocusMode =>
      _compassRequestedVisible && _focusMode;

  /// Effective compass visibility after shell-level suppression is applied.
  bool get compassVisible =>
      _compassRequestedVisible && !compassSuppressedByFocusMode;

  bool get focusMode => _focusMode;

  void toggleNavigator() {
    if (_focusMode) {
      return;
    }
    _navigatorVisible = !_navigatorVisible;
    notifyListeners();
  }

  void toggleInspector() {
    if (_focusMode) {
      return;
    }
    _inspectorVisible = !_inspectorVisible;
    notifyListeners();
  }

  void toggleContextBar() {
    if (_focusMode) {
      return;
    }
    _contextBarVisible = !_contextBarVisible;
    notifyListeners();
  }

  /// Toggles the user's requested compass state even while focus mode is on.
  ///
  /// This is intentionally different from panel toggles: focus mode suppresses
  /// the compass presentation, but must not prevent the user from changing the
  /// preference that will become effective after focus mode exits.
  void toggleCompass() {
    setCompassRequestedVisible(!_compassRequestedVisible);
  }

  /// Sets the requested compass state idempotently.
  void setCompassRequestedVisible(bool value) {
    if (_compassRequestedVisible == value) {
      return;
    }
    _compassRequestedVisible = value;
    notifyListeners();
  }

  void toggleFocusMode() {
    setFocusMode(!_focusMode);
  }

  /// Sets focus mode deterministically and without duplicate notifications.
  void setFocusMode(bool value) {
    if (_focusMode == value) {
      return;
    }
    _focusMode = value;
    notifyListeners();
  }

  void exitFocusMode() {
    setFocusMode(false);
  }
}
