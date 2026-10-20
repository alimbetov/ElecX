import 'package:elecx/src/app/engineering_colors.dart';
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
