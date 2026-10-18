enum EditorLayoutMode {
  mobile,
  tablet,
  desktop,
}

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
        EditorLayoutMode.desktop => 280,
        EditorLayoutMode.tablet => 340,
        EditorLayoutMode.mobile => 300,
      };

  static double inspectorWidth(EditorLayoutMode mode) => switch (mode) {
        EditorLayoutMode.desktop => 360,
        EditorLayoutMode.tablet => 380,
        EditorLayoutMode.mobile => 320,
      };
}
