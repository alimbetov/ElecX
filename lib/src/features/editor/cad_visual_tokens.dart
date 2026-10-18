import 'package:flutter/material.dart';

/// Shared visual contract for geometry-heavy editor surfaces.
///
/// Keep these values independent from ordinary application chrome. CAD
/// geometry needs stable stroke hierarchy, selection emphasis and pointer
/// affordances across Plan, Room World and individual surfaces.
abstract final class CadVisualTokens {
  static const double geometryStroke = 1.35;
  static const double selectedGeometryStroke = 2.25;
  static const double profileStroke = 1.8;
  static const double openingStroke = 2.4;
  static const double selectedOpeningStroke = 4.0;
  static const double routeStroke = 2.8;
  static const double transitionNodeRadius = 3.2;

  static const double vertexHandleRadius = 6.5;
  static const double edgeHandleSize = 9;
  static const double openingHandleRadius = 6;
  static const double openingMoveHandleSize = 11;
  static const double hitTargetPx = 18;

  static const double surfaceRadius = 8;
  static const double surfacePadding = 10;

  static Color geometry(ColorScheme scheme) => scheme.outline;

  static Color selectedGeometry(ColorScheme scheme) => scheme.primary;

  static Color profile(ColorScheme scheme) => scheme.tertiary;

  static Color opening(ColorScheme scheme) => scheme.tertiary;

  static Color selectedOpening(ColorScheme scheme) => scheme.secondary;

  static Color route(ColorScheme scheme) => scheme.primary;

  static Color ghostFill(ColorScheme scheme) =>
      scheme.onSurface.withValues(alpha: 0.025);

  static Color selectedFill(ColorScheme scheme) =>
      scheme.primary.withValues(alpha: 0.07);

  static Color hoverFill(ColorScheme scheme) =>
      scheme.primary.withValues(alpha: 0.045);

  static Color gridMinor(ColorScheme scheme) =>
      scheme.outlineVariant.withValues(alpha: 0.30);

  static Color gridMajor(ColorScheme scheme) =>
      scheme.outlineVariant.withValues(alpha: 0.62);

  static Color profileGuide(ColorScheme scheme) =>
      scheme.tertiary.withValues(alpha: 0.76);
}
