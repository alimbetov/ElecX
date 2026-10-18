import 'editor_controller.dart';

enum EditorViewportCommand { zoomIn, zoomOut, reset }

final class _ViewportCommandState {
  int revision = 0;
  EditorViewportCommand? command;
}

final Expando<_ViewportCommandState> _viewportStates =
    Expando<_ViewportCommandState>('ElecX viewport command state');

extension EditorViewportCommands on EditorController {
  _ViewportCommandState get _viewportState =>
      _viewportStates[this] ??= _ViewportCommandState();

  int get viewportCommandRevision => _viewportState.revision;

  EditorViewportCommand? get viewportCommand => _viewportState.command;

  void requestViewportCommand(EditorViewportCommand command) {
    final state = _viewportState
      ..revision += 1
      ..command = command;
    // The editor shell already listens to this controller. Reusing its
    // notification keeps viewport shortcuts in the same synchronous UI cycle
    // without introducing a second application-state controller.
    notifyListeners();
  }
}
