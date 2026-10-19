import 'editor_ui_tokens.dart';

enum EditorLayoutMode { mobile, tablet, desktop }

abstract final class EditorLayoutPolicy {
  static const double tabletMinWidth = 700;
  static const double desktopMinWidth = 1180;

  static EditorLayoutMode forWidth(double width) {
    if (width >= desktopMinWidth) return EditorLayoutMode.desktop;
    if (width >= tabletMinWidth) return EditorLayoutMode.tablet;
    return EditorLayoutMode.mobile;
  }

  static bool persistentSidePanels(EditorLayoutMode mode) =>
      mode == EditorLayoutMode.desktop;

  static bool compactTools(EditorLayoutMode mode) =>
      mode != EditorLayoutMode.desktop;

  static double navigatorWidth(EditorLayoutMode mode) => switch (mode) {
    EditorLayoutMode.desktop => EditorUiTokens.desktopNavigatorWidth,
    EditorLayoutMode.tablet => 328,
    EditorLayoutMode.mobile => 292,
  };

  static double inspectorWidth(EditorLayoutMode mode) => switch (mode) {
    EditorLayoutMode.desktop => EditorUiTokens.desktopInspectorWidth,
    EditorLayoutMode.tablet => 356,
    EditorLayoutMode.mobile => 304,
  };
}
