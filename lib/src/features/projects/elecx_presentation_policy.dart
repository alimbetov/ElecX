enum ElecXWidthClass { compact, medium, expanded, large }

enum ElecXLayoutMode { compact, medium, expanded }

/// Authoritative viewport policy for adaptive ElecX authoring surfaces.
///
/// Width classes follow the P9 cross-platform contract exactly and are based on
/// logical viewport width only. Accessibility may reduce visual density via
/// [layoutModeFor] without changing the authoritative width class or any domain
/// semantics.
final class ElecXPresentationPolicy {
  const ElecXPresentationPolicy._();

  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 1024;
  static const double largeMinWidth = 1440;

  static ElecXWidthClass widthClassFor(double logicalWidth) {
    if (logicalWidth < mediumMinWidth) return ElecXWidthClass.compact;
    if (logicalWidth < expandedMinWidth) return ElecXWidthClass.medium;
    if (logicalWidth < largeMinWidth) return ElecXWidthClass.expanded;
    return ElecXWidthClass.large;
  }

  /// Chooses a safe visual density while preserving the authoritative width
  /// class. Large text may collapse panes, but it never changes candidate
  /// generation, ordering, reservation, fingerprints, or canonical state.
  static ElecXLayoutMode layoutModeFor({
    required double logicalWidth,
    required double textScaleFactor,
  }) {
    final widthClass = widthClassFor(logicalWidth);
    final scale = textScaleFactor < 1 ? 1.0 : textScaleFactor;

    return switch (widthClass) {
      ElecXWidthClass.compact => ElecXLayoutMode.compact,
      ElecXWidthClass.medium =>
        scale > 1.3 ? ElecXLayoutMode.compact : ElecXLayoutMode.medium,
      ElecXWidthClass.expanded =>
        scale >= 1.8 ? ElecXLayoutMode.medium : ElecXLayoutMode.expanded,
      ElecXWidthClass.large =>
        scale >= 1.8 ? ElecXLayoutMode.medium : ElecXLayoutMode.expanded,
    };
  }
}
