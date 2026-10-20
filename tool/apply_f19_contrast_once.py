from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old[:140]!r}')
    p.write_text(text.replace(old, new, 1))

Path('lib/src/app/engineering_colors.dart').write_text(r'''import 'package:flutter/material.dart';

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
''')

replace_once(
    'lib/src/app/elecx_theme.dart',
    "import 'alien_cockpit_tokens.dart';\n",
    "import 'alien_cockpit_tokens.dart';\nimport 'engineering_colors.dart';\n",
)
replace_once(
    'lib/src/app/elecx_theme.dart',
    "      colorScheme: scheme,\n",
    "      colorScheme: scheme,\n      extensions: <ThemeExtension<dynamic>>[\n        dark ? EngineeringColors.dark() : EngineeringColors.light(),\n      ],\n",
)

replace_once(
    'lib/src/features/editor/engineering_selection_inspector.dart',
    "import '../../app/alien_cockpit_tokens.dart';\n",
    "import '../../app/engineering_colors.dart';\n",
)
replace_once(
    'lib/src/features/editor/engineering_selection_inspector.dart',
    "    final assigned = bundle != null;\n    return _InspectorScaffold(\n",
    "    final assigned = bundle != null;\n    final engineering = Theme.of(context).extension<EngineeringColors>()!;\n    return _InspectorScaffold(\n",
)
replace_once(
    'lib/src/features/editor/engineering_selection_inspector.dart',
    "      statusColor: assigned\n          ? AlienCockpitTokens.signalAqua\n          : AlienCockpitTokens.signalWarning,\n",
    "      statusColor: assigned ? engineering.registered : engineering.warning,\n",
)
replace_once(
    'lib/src/features/editor/engineering_selection_inspector.dart',
    "    final assigned = bundle != null;\n    return _InspectorScaffold(\n      title: bundle?.cable.designation ?? routeId,\n",
    "    final assigned = bundle != null;\n    final engineering = Theme.of(context).extension<EngineeringColors>()!;\n    return _InspectorScaffold(\n      title: bundle?.cable.designation ?? routeId,\n",
)
replace_once(
    'lib/src/features/editor/engineering_selection_inspector.dart',
    "      statusColor: assigned\n          ? AlienCockpitTokens.signalAqua\n          : AlienCockpitTokens.signalCyan,\n",
    "      statusColor: assigned ? engineering.registered : engineering.info,\n",
)
replace_once(
    'lib/src/features/editor/engineering_selection_inspector.dart',
    "    final scheme = Theme.of(context).colorScheme;\n    final signal = statusColor ?? AlienCockpitTokens.signalCyan;\n",
    "    final scheme = Theme.of(context).colorScheme;\n    final engineering = Theme.of(context).extension<EngineeringColors>()!;\n    final signal = statusColor ?? engineering.info;\n",
)

replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "import '../../app/alien_cockpit_tokens.dart';\n",
    "import '../../app/engineering_colors.dart';\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "    final scheme = Theme.of(context).colorScheme;\n    return Column(\n      children: [\n        Container(\n",
    "    final scheme = Theme.of(context).colorScheme;\n    final engineering = Theme.of(context).extension<EngineeringColors>()!;\n    return Column(\n      children: [\n        Container(\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "                color: AlienCockpitTokens.signalAqua.withValues(alpha: 0.22),\n",
    "                color: engineering.active.withValues(alpha: 0.22),\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "              const Icon(\n                Icons.monitor_heart_outlined,\n                size: 17,\n                color: AlienCockpitTokens.signalAqua,\n              ),\n",
    "              Icon(\n                Icons.monitor_heart_outlined,\n                size: 17,\n                color: engineering.active,\n              ),\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "    final scheme = Theme.of(context).colorScheme;\n    return Container(\n      height: EditorUiTokens.panelHeaderHeight + 4,\n",
    "    final scheme = Theme.of(context).colorScheme;\n    final engineering = Theme.of(context).extension<EngineeringColors>()!;\n    return Container(\n      height: EditorUiTokens.panelHeaderHeight + 4,\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "            color: AlienCockpitTokens.signalCyan.withValues(alpha: 0.16),\n",
    "            color: engineering.info.withValues(alpha: 0.16),\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "          const Icon(\n            Icons.widgets_outlined,\n            size: 17,\n            color: AlienCockpitTokens.signalCyan,\n          ),\n",
    "          Icon(\n            Icons.widgets_outlined,\n            size: 17,\n            color: engineering.info,\n          ),\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "            const Padding(\n              padding: EdgeInsets.only(right: 7),\n              child: Icon(\n                Icons.radar,\n                size: 15,\n                color: AlienCockpitTokens.signalAqua,\n              ),\n            ),\n",
    "            Padding(\n              padding: const EdgeInsets.only(right: 7),\n              child: Icon(\n                Icons.radar,\n                size: 15,\n                color: engineering.active,\n              ),\n            ),\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "  Widget build(BuildContext context) => Padding(\n        padding: const EdgeInsets.fromLTRB(5, 9, 5, 5),\n",
    "  Widget build(BuildContext context) {\n    final engineering = Theme.of(context).extension<EngineeringColors>()!;\n    return Padding(\n        padding: const EdgeInsets.fromLTRB(5, 9, 5, 5),\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "                color: AlienCockpitTokens.signalViolet,\n",
    "                color: engineering.category,\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "      );\n}\n\nclass _EquipmentCard",
    "      );\n  }\n}\n\nclass _EquipmentCard",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "    final scheme = Theme.of(context).colorScheme;\n    final signal = placing\n        ? AlienCockpitTokens.signalAqua\n        : compatible\n            ? AlienCockpitTokens.signalCyan\n            : scheme.onSurfaceVariant;\n",
    "    final scheme = Theme.of(context).colorScheme;\n    final engineering = Theme.of(context).extension<EngineeringColors>()!;\n    final signal = placing\n        ? engineering.active\n        : compatible\n            ? engineering.info\n            : scheme.onSurfaceVariant;\n",
)
replace_once(
    'lib/src/features/editor/device_catalog_panel.dart',
    "                                  : AlienCockpitTokens.signalWarning,\n",
    "                                  : engineering.warning,\n",
)

Path('test/f19_engineering_contrast_test.dart').write_text(r'''import 'package:elecx/src/app/engineering_colors.dart';
import 'package:elecx/src/app/elecx_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Color _blend(Color foreground, Color background) =>
    Color.alphaBlend(foreground, background);

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  for (final theme in <ThemeData>[ElecXTheme.light(), ElecXTheme.dark()]) {
    final mode = theme.brightness.name;
    test('F19 $mode engineering status text meets 4.5 contrast', () {
      final colors = theme.extension<EngineeringColors>();
      expect(colors, isNotNull);
      final c = colors!;
      final panel = theme.colorScheme.surfaceContainerLow;
      for (final signal in <Color>[
        c.info,
        c.active,
        c.registered,
        c.warning,
        c.fault,
      ]) {
        final tinted = _blend(signal.withValues(alpha: 0.07), panel);
        expect(
          _contrast(signal, tinted),
          greaterThanOrEqualTo(4.5),
          reason: '$mode $signal on $tinted',
        );
      }
      expect(_contrast(c.warning, panel), greaterThanOrEqualTo(4.5));
    });
  }

  test('F19 light and dark engineering palettes are theme-specific', () {
    final light = ElecXTheme.light().extension<EngineeringColors>()!;
    final dark = ElecXTheme.dark().extension<EngineeringColors>()!;
    expect(light.info, isNot(dark.info));
    expect(light.registered, isNot(dark.registered));
    expect(light.warning, isNot(dark.warning));
  });
}
''')
