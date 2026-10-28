import 'package:elecx/src/features/auth/pin_unlock_screen.dart';
import 'package:elecx/src/features/projects/platform_project_hub_screen.dart';
import 'package:elecx/src/features/projects/project_wizard_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PRE10-Q01 startup responsive qualification', () {
    const cases = <_StartupPresentationCase>[
      _StartupPresentationCase(
        label: 'phone portrait 390x844 scale 1.0',
        size: Size(390, 844),
      ),
      _StartupPresentationCase(
        label: 'phone landscape 844x390 scale 1.0',
        size: Size(844, 390),
      ),
      _StartupPresentationCase(
        label: 'phone landscape 844x390 scale 2.0',
        size: Size(844, 390),
        textScale: 2,
      ),
      _StartupPresentationCase(
        label: 'short desktop 800x600 scale 2.0',
        size: Size(800, 600),
        textScale: 2,
      ),
      _StartupPresentationCase(
        label: 'tablet 768x1024 scale 2.0',
        size: Size(768, 1024),
        textScale: 2,
      ),
      _StartupPresentationCase(
        label: 'desktop 1440x900 scale 2.0',
        size: Size(1440, 900),
        textScale: 2,
      ),
    ];

    for (final presentation in cases) {
      testWidgets(presentation.label, (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = presentation.size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_startupApp(presentation: presentation));
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: '${presentation.label}: startup must not overflow or throw',
        );
        expect(find.byType(PinUnlockScreen), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        expect(find.text('⌫'), findsOneWidget);
      });
    }
  });

  testWidgets(
    'PRE10-Q02 desktop physical digits and backspace operate startup PIN directly',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _startupApp(
          presentation: const _StartupPresentationCase(
            label: 'desktop keyboard',
            size: Size(1280, 720),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.pump(const Duration(milliseconds: 150));

      expect(
        find.byType(PlatformProjectHubScreen),
        findsOneWidget,
        reason: '1234 entered from the physical keyboard must unlock startup',
      );
    },
  );

  testWidgets('PRE10-Q03 English locale has no hard-coded Russian startup copy',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _startupApp(
        presentation: const _StartupPresentationCase(
          label: 'English startup',
          size: Size(390, 844),
          locale: Locale('en'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Быстрый вход инженера'), findsNothing);
    expect(
      find.textContaining('локальная быстрая разблокировка'),
      findsNothing,
    );
  });
}

Widget _startupApp({required _StartupPresentationCase presentation}) =>
    MaterialApp(
      locale: presentation.locale,
      supportedLocales: ProjectWizardLocalizations.supportedLocales,
      localizationsDelegates: ProjectWizardLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(presentation.textScale),
        ),
        child: child!,
      ),
      home: const PinUnlockScreen(),
    );

final class _StartupPresentationCase {
  const _StartupPresentationCase({
    required this.label,
    required this.size,
    this.textScale = 1,
    this.locale = const Locale('en'),
  });

  final String label;
  final Size size;
  final double textScale;
  final Locale locale;
}
