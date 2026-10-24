import 'package:flutter/material.dart';

import '../features/auth/pin_unlock_screen.dart';
import '../features/projects/project_wizard_localizations.dart';
import 'elecx_theme.dart';

class ElecXApp extends StatelessWidget {
  const ElecXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElecX',
      debugShowCheckedModeBanner: false,
      theme: ElecXTheme.light(),
      darkTheme: ElecXTheme.dark(),
      themeMode: ThemeMode.system,
      supportedLocales: ProjectWizardLocalizations.supportedLocales,
      localizationsDelegates: ProjectWizardLocalizations.localizationsDelegates,
      home: const PinUnlockScreen(),
    );
  }
}
