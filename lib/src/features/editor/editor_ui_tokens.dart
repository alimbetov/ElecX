import 'package:flutter/material.dart';

/// Shared density and spacing contract for the ElecX engineering workspace.
///
/// Desktop chrome stays compact, while touch/stylus interaction paths must
/// expose larger targets through adaptive interaction policies.
abstract final class EditorUiTokens {
  static const double appBarHeight = 48;
  static const double commandBarHeight = 48;
  static const double contextBarHeight = 36;
  static const double desktopNavigatorWidth = 252;
  static const double desktopInspectorWidth = 312;
  static const double collapsedRailWidth = 46;
  static const double panelHeaderHeight = 40;

  // Pointer-oriented desktop controls.
  static const double commandTarget = 40;

  // Compact/mobile chrome must still preserve a comfortable target. Fine-grain
  // device-specific hit targets are owned by EditorInteractionPolicy.
  static const double compactCommandTarget = 44;
  static const double minimumTouchTarget = 44;

  static const double panelRadius = 8;
  static const double controlRadius = 7;
  static const double canvasInset = 8;
  static const double panelBorder = 1;
  static const double activePanelBorder = 1.4;
  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 12;
  static const double gapLg = 16;

  static BorderSide divider(BuildContext context) => BorderSide(
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.72),
      );

  static BorderSide activeBorder(BuildContext context) => BorderSide(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.78),
        width: activePanelBorder,
      );
}
