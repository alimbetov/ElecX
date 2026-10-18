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
    _navigatorVisible = !_navigatorVisible;
    notifyListeners();
  }

  void toggleInspector() {
    _inspectorVisible = !_inspectorVisible;
    notifyListeners();
  }

  void toggleContextBar() {
    _contextBarVisible = !_contextBarVisible;
    notifyListeners();
  }

  void toggleFocusMode() {
    _focusMode = !_focusMode;
    notifyListeners();
  }

  void exitFocusMode() {
    if (!_focusMode) return;
    _focusMode = false;
    notifyListeners();
  }
}
