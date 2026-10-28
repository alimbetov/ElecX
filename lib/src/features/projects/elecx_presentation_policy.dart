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
  /// class. Large text may project a MEDIUM viewport into compact visual density
  /// when the denser two-region composition would make primary actions or
  /// preview content unreachable. The authoritative width class remains MEDIUM;
  /// only presentation density changes. Expanded classes may collapse one
  /// density level for accessibility. Generation, ordering, reservation,
  /// fingerprints, and canonical state are never affected.
  static ElecXLayoutMode layoutModeFor({
    required double logicalWidth,
    required double textScaleFactor,
  }) {
    final widthClass = widthClassFor(logicalWidth);
    final scale = textScaleFactor < 1 ? 1.0 : textScaleFactor;

    return switch (widthClass) {
      ElecXResponsiveWidthClass.compact => ElecXLayoutMode.compact,
      ElecXResponsiveWidthClass.medium =>
        scale >= 1.8 ? ElecXLayoutMode.compact : ElecXLayoutMode.medium,
      ElecXResponsiveWidthClass.expanded =>
        scale >= 1.8 ? ElecXLayoutMode.medium : ElecXLayoutMode.expanded,
      ElecXResponsiveWidthClass.large =>
        scale >= 1.8 ? ElecXLayoutMode.medium : ElecXLayoutMode.expanded,
    };
  }
}
