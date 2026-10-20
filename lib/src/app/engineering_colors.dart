import 'package:flutter/material.dart';

import 'alien_cockpit_tokens.dart';

@immutable
final class EngineeringColors extends ThemeExtension<EngineeringColors> {
  const EngineeringColors({
    required this.info,
    required this.active,
    required this.registered,
    required this.warning,
    required this.fault,
    required this.category,
    required this.onStatus,
  });

  factory EngineeringColors.dark() => const EngineeringColors(
        info: AlienCockpitTokens.signalCyan,
        active: AlienCockpitTokens.signalAqua,
        registered: AlienCockpitTokens.signalAqua,
        warning: AlienCockpitTokens.signalWarning,
        fault: AlienCockpitTokens.signalFault,
        category: AlienCockpitTokens.signalViolet,
        onStatus: AlienCockpitTokens.darkVoid,
      );

  factory EngineeringColors.light() => const EngineeringColors(
        info: Color(0xFF00505F),
        active: Color(0xFF005B4A),
        registered: Color(0xFF00624F),
        warning: Color(0xFF654800),
        fault: Color(0xFF9F1239),
        category: Color(0xFF4C3F99),
        onStatus: Colors.white,
      );

  final Color info;
  final Color active;
  final Color registered;
  final Color warning;
  final Color fault;
  final Color category;
  final Color onStatus;

  static EngineeringColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<EngineeringColors>() ??
        (theme.brightness == Brightness.dark
            ? EngineeringColors.dark()
            : EngineeringColors.light());
  }

  @override
  EngineeringColors copyWith({
    Color? info,
    Color? active,
    Color? registered,
    Color? warning,
    Color? fault,
    Color? category,
    Color? onStatus,
  }) =>
      EngineeringColors(
        info: info ?? this.info,
        active: active ?? this.active,
        registered: registered ?? this.registered,
        warning: warning ?? this.warning,
        fault: fault ?? this.fault,
        category: category ?? this.category,
        onStatus: onStatus ?? this.onStatus,
      );

  @override
  EngineeringColors lerp(covariant EngineeringColors? other, double t) {
    if (other == null) return this;
    return EngineeringColors(
      info: Color.lerp(info, other.info, t)!,
      active: Color.lerp(active, other.active, t)!,
      registered: Color.lerp(registered, other.registered, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      fault: Color.lerp(fault, other.fault, t)!,
      category: Color.lerp(category, other.category, t)!,
      onStatus: Color.lerp(onStatus, other.onStatus, t)!,
    );
  }
}
