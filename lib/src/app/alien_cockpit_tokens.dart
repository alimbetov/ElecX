import 'package:flutter/material.dart';

/// Product-signature visual tokens for the ElecX engineering cockpit.
///
/// These are intentionally semantic rather than decorative. Glow and accent
/// colors represent concrete editor states (selection, continuation, warning,
/// fault) and must never become a substitute for model state or validation.
abstract final class AlienCockpitTokens {
  // Deep-space dark surfaces.
  static const darkVoid = Color(0xFF050A0E);
  static const darkCanvas = Color(0xFF071116);
  static const darkPanel = Color(0xFF0A171D);
  static const darkPanelRaised = Color(0xFF102229);
  static const darkPanelHighest = Color(0xFF173039);

  // Product identity accents.
  static const cyan = Color(0xFF49E6FF);
  static const cyanBright = Color(0xFF8BF3FF);
  static const violet = Color(0xFFA58CFF);
  static const aqua = Color(0xFF56F0C4);

  // Engineering statuses.
  static const warning = Color(0xFFFFC857);
  static const fault = Color(0xFFFF6B7A);
  static const valid = Color(0xFF64F5A8);

  // Semantic signal aliases used by cockpit widgets. These names describe
  // meaning rather than palette and can survive a future visual refresh.
  static const signalCyan = cyan;
  static const signalViolet = violet;
  static const signalAqua = aqua;
  static const signalWarning = warning;
  static const signalFault = fault;
  static const signalValid = valid;

  // Neutral drawing chrome.
  static const coolText = Color(0xFFD7E7EB);
  static const coolMuted = Color(0xFF8DA7AE);
  static const coolOutline = Color(0xFF36515A);
  static const coolOutlineStrong = Color(0xFF4A6D77);

  static const lightSeed = Color(0xFF087D93);
  static const darkSeed = cyan;

  static const double selectedHaloAlpha = 0.18;
  static const double hoverHaloAlpha = 0.10;
  static const double panelGlowAlpha = 0.08;

  static BoxDecoration panelDecoration(
    ColorScheme scheme, {
    bool active = false,
    bool elevated = false,
    double radius = 8,
  }) {
    final borderColor = active
        ? scheme.primary.withValues(alpha: 0.78)
        : scheme.outlineVariant.withValues(alpha: 0.78);
    return BoxDecoration(
      color: elevated
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: active
          ? [
              BoxShadow(
                color: scheme.primary.withValues(alpha: panelGlowAlpha),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ]
          : const [],
    );
  }
}
