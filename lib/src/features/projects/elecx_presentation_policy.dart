import '../../application/project/wizard/apartment/apartment_preview_presentation.dart';

enum ElecXLayoutMode { compact, medium, expanded }

/// Authoritative viewport policy for adaptive ElecX authoring surfaces.
///
/// Width classification delegates to the shared P9 presentation contract.
/// Accessibility may reduce visual density via [layoutModeFor] without changing
/// the authoritative width class or any domain semantics.
final class ElecXPresentationPolicy {
  const ElecXPresentationPolicy._();

  static ElecXResponsiveWidthClass widthClassFor(double logicalWidth) =>
      responsiveWidthClassFor(logicalWidth);

  /// Chooses a safe visual density while preserving the authoritative width
  /// class. MEDIUM remains a two-region layout even at large text scales so a
  /// short landscape viewport does not acquire an additional navigation row.
  /// Expanded classes may collapse one density level for accessibility, but
  /// presentation never changes generation, ordering, reservation,
  /// fingerprints, or canonical state.
  static ElecXLayoutMode layoutModeFor({
    required double logicalWidth,
    required double textScaleFactor,
  }) {
    final widthClass = widthClassFor(logicalWidth);
    final scale = textScaleFactor < 1 ? 1.0 : textScaleFactor;

    return switch (widthClass) {
      ElecXResponsiveWidthClass.compact => ElecXLayoutMode.compact,
      ElecXResponsiveWidthClass.medium => ElecXLayoutMode.medium,
      ElecXResponsiveWidthClass.expanded =>
        scale >= 1.8 ? ElecXLayoutMode.medium : ElecXLayoutMode.expanded,
      ElecXResponsiveWidthClass.large =>
        scale >= 1.8 ? ElecXLayoutMode.medium : ElecXLayoutMode.expanded,
    };
  }
}
