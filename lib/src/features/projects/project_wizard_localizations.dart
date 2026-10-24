import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// P8-owned localization surface. The Wizard intentionally keeps its strings
/// in one typed resource instead of scattering locale checks through widgets.
final class ProjectWizardLocalizations {
  const ProjectWizardLocalizations._(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('ru')];

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static ProjectWizardLocalizations of(BuildContext context) =>
      ProjectWizardLocalizations._(Localizations.localeOf(context));

  bool get _ru => locale.languageCode.toLowerCase() == 'ru';
  String _pick(String en, String ru) => _ru ? ru : en;

  String get title => _pick('Create building', 'Создание здания');
  String get cancel => _pick('Cancel', 'Отмена');
  String get parameters => _pick('Parameters', 'Параметры');
  String get preview => _pick('Preview', 'Предпросмотр');
  String get changes => _pick('Changes', 'Изменения');
  String get buildingName => _pick('Building name', 'Название здания');
  String get aboveGroundLevels =>
      _pick('Above-ground levels', 'Надземных этажей');
  String get basementLevels => _pick('Basement levels', 'Подземных этажей');
  String get floorHeight => _pick('Floor height, mm', 'Высота этажа, мм');
  String get createGround =>
      _pick('Create separate level 0', 'Создать отдельный этаж 0');
  String get createGroundHint => _pick(
        'Positive levels keep numbering 1..N.',
        'Положительные этажи сохраняют нумерацию 1..N.',
      );
  String get generate => _pick('Generate', 'Сформировать');
  String get numericError => _pick(
        'Level counts and height must be numbers.',
        'Количество этажей и высота должны быть числами.',
      );
  String get generationFailed => _pick(
        'Could not generate a candidate',
        'Не удалось сформировать вариант',
      );
  String get projectChanged => _pick('Project changed', 'Проект изменился');
  String get stalePreview => _pick(
        'The preview is stale. Refresh it before applying.',
        'Предпросмотр устарел. Обновите его перед применением.',
      );
  String get refreshPreview =>
      _pick('Refresh preview', 'Обновить предпросмотр');
  String get fixRequired =>
      _pick('Correction required', 'Требуется исправление');
  String get warning => _pick('Warning', 'Предупреждение');
  String get previewEmpty => _pick(
        'Preview has not been generated yet',
        'Предпросмотр ещё не сформирован',
      );
  String get previewEmptyHint => _pick(
        'Fill in the parameters and press “Generate”.',
        'Заполните параметры и нажмите «Сформировать».',
      );
  String get changesEmpty => _pick(
        'Changes will appear after generation',
        'Изменения появятся после генерации',
      );
  String get changesEmptyHint => _pick(
        'Apply always commits the whole candidate.',
        'Применение выполняется ко всему варианту целиком.',
      );
  String changesCount(int count) => _pick('Changes ($count)', 'Изменения ($count)');
  String get applyAll => _pick('Apply all', 'Применить всё');
  String get noCandidates =>
      _pick('No candidates available.', 'Нет доступных вариантов.');
  String candidatePosition(String title, int index, int count) => _pick(
        '$title. Candidate $index of $count',
        '$title. Вариант $index из $count',
      );
  String selectedCandidate(int index, int count) => _pick(
        'Selected candidate $index of $count',
        'Выбран вариант $index из $count',
      );

  String validationMessage(String code, String fallback) => switch (code) {
        'basic-building.target.unsupported' => _pick(
            'Basic Building requires a new-project or Site target.',
            'Базовое здание доступно только для нового проекта или участка.',
          ),
        'basic-building.name.empty' =>
          _pick('Building name is required.', 'Укажите название здания.'),
        'basic-building.above-ground.out-of-range' => _pick(
            'Above-ground level count must be between 1 and 200.',
            'Количество надземных этажей должно быть от 1 до 200.',
          ),
        'basic-building.basement.out-of-range' => _pick(
            'Basement level count must be between 0 and 30.',
            'Количество подземных этажей должно быть от 0 до 30.',
          ),
        'basic-building.height.non-positive' => _pick(
            'Floor-to-floor height must be a positive millimetre value.',
            'Высота этажа должна быть положительным значением в миллиметрах.',
          ),
        _ => fallback,
      };
}
