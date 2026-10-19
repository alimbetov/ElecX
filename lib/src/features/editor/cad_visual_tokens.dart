import 'package:flutter/material.dart';

/// Shared visual contract for geometry-heavy editor surfaces.
///
/// CAD geometry remains neutral. Accent colors are reserved for semantic editor
/// states so the alien-cockpit identity improves hierarchy rather than adding
/// decorative noise.
abstract final class CadVisualTokens {
  static const double geometryStroke = 1.35;
  static const double selectedGeometryStroke = 2.4;
  static const double profileStroke = 1.8;
  static const double openingStroke = 2.4;
  static const double selectedOpeningStroke = 4.0;
  static const double routeStroke = 2.8;
  static const double selectedRouteStroke = 3.4;
  static const double selectedRouteHaloStroke = 10.0;
  static const double transitionNodeRadius = 3.2;
  static const double transitionMarkerRadius = 8.0;

  static const double vertexHandleRadius = 6.5;
  static const double edgeHandleSize = 9;
  static const double openingHandleRadius = 6;
  static const double openingMoveHandleSize = 11;
  static const double hitTargetPx = 18;

  static const double surfaceRadius = 8;
  static const double surfacePadding = 10;

  static Color geometry(ColorScheme scheme) => scheme.outline;

  static Color selectedGeometry(ColorScheme scheme) => scheme.primary;

  static Color hoverGeometry(ColorScheme scheme) =>
      scheme.primary.withValues(alpha: 0.78);

  static Color profile(ColorScheme scheme) => scheme.tertiary;

  static Color opening(ColorScheme scheme) => scheme.tertiary;

  static Color selectedOpening(ColorScheme scheme) => scheme.secondary;

  static Color route(ColorScheme scheme) => scheme.primary;

  static Color transition(ColorScheme scheme) => scheme.tertiary;

  static Color validPreview(ColorScheme scheme) => scheme.tertiary;

  static Color invalidPreview(ColorScheme scheme) => scheme.error;

  static Color warning(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
          ? const Color(0xFFFFC857)
          : const Color(0xFF8B5E00);

  static Color locked(ColorScheme scheme) =>
      scheme.onSurfaceVariant.withValues(alpha: 0.48);

  static Color reference(ColorScheme scheme) =>
      scheme.secondary.withValues(alpha: 0.62);

  static Color ghostFill(ColorScheme scheme) =>
      scheme.onSurface.withValues(alpha: 0.025);

  static Color selectedFill(ColorScheme scheme) =>
      scheme.primary.withValues(alpha: 0.075);

  static Color hoverFill(ColorScheme scheme) =>
      scheme.primary.withValues(alpha: 0.05);

  static Color selectedHalo(ColorScheme scheme) =>
      scheme.primary.withValues(alpha: 0.16);

  static Color gridMinor(ColorScheme scheme) =>
      scheme.outlineVariant.withValues(alpha: 0.24);

  static Color gridMajor(ColorScheme scheme) =>
      scheme.outlineVariant.withValues(alpha: 0.54);

  static Color profileGuide(ColorScheme scheme) =>
      scheme.tertiary.withValues(alpha: 0.76);
}
