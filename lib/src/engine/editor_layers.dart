enum EditorLayerId {
  architecture,
  openings,
  electrical,
  cableRoutes,
  dimensions,
  guides,
}

final class EditorLayerState {
  const EditorLayerState({
    required this.id,
    required this.visible,
    required this.locked,
  });

  final EditorLayerId id;
  final bool visible;
  final bool locked;

  EditorLayerState copyWith({bool? visible, bool? locked}) => EditorLayerState(
        id: id,
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
      );
}

final class EditorLayerRegistry {
  EditorLayerRegistry({Iterable<EditorLayerState>? layers})
      : _layers = {
          for (final layer in layers ?? defaults) layer.id: layer,
        };

  final Map<EditorLayerId, EditorLayerState> _layers;

  static const defaults = <EditorLayerState>[
    EditorLayerState(
      id: EditorLayerId.architecture,
      visible: true,
      locked: false,
    ),
    EditorLayerState(
      id: EditorLayerId.openings,
      visible: true,
      locked: false,
    ),
    EditorLayerState(
      id: EditorLayerId.electrical,
      visible: true,
      locked: false,
    ),
    EditorLayerState(
      id: EditorLayerId.cableRoutes,
      visible: true,
      locked: false,
    ),
    EditorLayerState(
      id: EditorLayerId.dimensions,
      visible: true,
      locked: false,
    ),
    EditorLayerState(
      id: EditorLayerId.guides,
      visible: true,
      locked: false,
    ),
  ];

  List<EditorLayerState> get layers => List.unmodifiable(_layers.values);

  EditorLayerState state(EditorLayerId id) => _layers[id]!;

  bool isVisible(EditorLayerId id) => state(id).visible;

  bool isLocked(EditorLayerId id) => state(id).locked;

  void setVisible(EditorLayerId id, bool value) {
    _layers[id] = state(id).copyWith(visible: value);
  }

  void setLocked(EditorLayerId id, bool value) {
    _layers[id] = state(id).copyWith(locked: value);
  }
}
