import 'package:flutter/foundation.dart';

final class EditorShellState extends ChangeNotifier {
  bool _navigatorVisible = true;
  bool _inspectorVisible = true;
  bool _contextBarVisible = true;
  bool _focusMode = false;

  bool get navigatorVisible => _navigatorVisible && !_focusMode;
  bool get inspectorVisible => _inspectorVisible && !_focusMode;
  bool get contextBarVisible => _contextBarVisible && !_focusMode;
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

  void toggleFocusMode() {
    _focusMode = !_focusMode;
    notifyListeners();
  }

  void exitFocusMode() {
    if (!_focusMode) {
      return;
    }
    _focusMode = false;
    notifyListeners();
  }
}
