import 'package:flutter/foundation.dart';

import 'editor_controller.dart';

enum EditorViewportCommand { zoomIn, zoomOut, reset, fitSelection }

final class EditorViewportCommandEvent {
  const EditorViewportCommandEvent({
    required this.revision,
    required this.command,
  });

  final int revision;
  final EditorViewportCommand command;
}

final Expando<ValueNotifier<EditorViewportCommandEvent?>> _viewportBuses =
    Expando<ValueNotifier<EditorViewportCommandEvent?>>(
  'ElecX viewport command bus',
);

extension EditorViewportCommands on EditorController {
  ValueNotifier<EditorViewportCommandEvent?> get viewportCommandListenable =>
      _viewportBuses[this] ??= ValueNotifier<EditorViewportCommandEvent?>(null);

  int get viewportCommandRevision =>
      viewportCommandListenable.value?.revision ?? 0;

  EditorViewportCommand? get viewportCommand =>
      viewportCommandListenable.value?.command;

  void requestViewportCommand(EditorViewportCommand command) {
    final nextRevision = viewportCommandRevision + 1;
    viewportCommandListenable.value = EditorViewportCommandEvent(
      revision: nextRevision,
      command: command,
    );
  }
}
