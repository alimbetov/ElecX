import 'package:flutter/widgets.dart';

/// Localization surface shared by the application shell that exists before
/// feature-specific project and Wizard screens are mounted.
final class AppShellLocalizations {
  const AppShellLocalizations._(this.locale);

  final Locale locale;

  static AppShellLocalizations of(BuildContext context) =>
      AppShellLocalizations._(Localizations.localeOf(context));

  bool get isRussian => locale.languageCode.toLowerCase() == 'ru';

  String _pick(String en, String ru) => isRussian ? ru : en;

  String get engineerQuickAccess =>
      _pick('Engineer quick access', 'Быстрый вход инженера');

  String get prototypePinExplanation => _pick(
        'Prototype: PIN is a local quick unlock, not a replacement for an account.',
        'Prototype: PIN — локальная быстрая разблокировка, не замена учётной записи.',
      );

  String get deleteLastDigit =>
      _pick('Delete last digit', 'Удалить последнюю цифру');

  String get localStorageInitializationFailed => _pick(
        'ElecX local storage could not be initialized.',
        'Не удалось инициализировать локальное хранилище ElecX.',
      );

  String get retry => _pick('Retry', 'Повторить');
}
