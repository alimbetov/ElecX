import 'package:flutter/material.dart';

/// Shared density and spacing contract for the ElecX engineering workspace.
///
/// The editor is deliberately denser than ordinary application chrome while
/// preserving minimum pointer/touch targets for primary actions.
abstract final class EditorUiTokens {
  static const double appBarHeight = 48;
  static const double commandBarHeight = 46;
  static const double contextBarHeight = 36;
  static const double desktopNavigatorWidth = 248;
  static const double desktopInspectorWidth = 300;
  static const double collapsedRailWidth = 44;
  static const double panelHeaderHeight = 40;
  static const double commandTarget = 38;
  static const double compactCommandTarget = 40;
  static const double panelRadius = 10;
  static const double canvasInset = 8;
  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 12;
  static const double gapLg = 16;

  static BorderSide divider(BuildContext context) => BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.75),
      );
}
