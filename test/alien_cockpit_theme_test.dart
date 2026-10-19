import 'package:elecx/src/app/alien_cockpit_tokens.dart';
import 'package:elecx/src/app/elecx_theme.dart';
import 'package:elecx/src/features/editor/cad_visual_tokens.dart';
import 'package:elecx/src/features/editor/editor_ui_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark theme exposes the cockpit semantic palette', () {
    final theme = ElecXTheme.dark();
    final scheme = theme.colorScheme;

    expect(theme.brightness, Brightness.dark);
    expect(scheme.primary, AlienCockpitTokens.cyan);
    expect(scheme.secondary, AlienCockpitTokens.violet);
    expect(scheme.tertiary, AlienCockpitTokens.aqua);
    expect(scheme.error, AlienCockpitTokens.fault);
    expect(scheme.surface, AlienCockpitTokens.darkCanvas);
    expect(scheme.surfaceContainerLowest, AlienCockpitTokens.darkVoid);
  });

  test('light theme keeps semantic accents without dark-only surfaces', () {
    final theme = ElecXTheme.light();

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, isNot(AlienCockpitTokens.cyan));
    expect(theme.colorScheme.error, isNotNull);
  });

  test('compact editor target meets the explicit touch ergonomics floor', () {
    expect(
      EditorUiTokens.compactCommandTarget,
      greaterThanOrEqualTo(EditorUiTokens.minimumTouchTarget),
    );
    expect(EditorUiTokens.minimumTouchTarget, greaterThanOrEqualTo(44));
  });

  testWidgets('semantic CAD states remain distinct in dark mode',
      (tester) async {
    late Color selected;
    late Color invalid;
    late Color warning;
    late Color locked;

    await tester.pumpWidget(
      MaterialApp(
        theme: ElecXTheme.dark(),
        home: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            selected = CadVisualTokens.selectedGeometry(scheme);
            invalid = CadVisualTokens.invalidPreview(scheme);
            warning = CadVisualTokens.warning(scheme);
            locked = CadVisualTokens.locked(scheme);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(selected, isNot(invalid));
    expect(selected, isNot(warning));
    expect(invalid, isNot(warning));
    expect(locked.a, lessThan(selected.a));
  });
}
