abstract interface class EditorCommand<T> {
  String get label;

  T execute(T state);

  T undo(T state);
}

final class CommandHistory<T> {
  CommandHistory(this._state, {this.capacity = 200}) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity');
    }
  }

  T _state;
  final int capacity;
  final List<EditorCommand<T>> _undo = [];
  final List<EditorCommand<T>> _redo = [];

  T get state => _state;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoDepth => _undo.length;
  int get redoDepth => _redo.length;

  T execute(EditorCommand<T> command) {
    _state = command.execute(_state);
    _undo.add(command);
    if (_undo.length > capacity) {
      _undo.removeAt(0);
    }
    _redo.clear();
    return _state;
  }

  T undo() {
    if (_undo.isEmpty) return _state;
    final command = _undo.removeLast();
    _state = command.undo(_state);
    _redo.add(command);
    return _state;
  }

  T redo() {
    if (_redo.isEmpty) return _state;
    final command = _redo.removeLast();
    _state = command.execute(_state);
    _undo.add(command);
    return _state;
  }

  void replaceState(T state, {bool clearHistory = true}) {
    _state = state;
    if (clearHistory) {
      clear();
    }
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
