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

  bool get isRussian => locale.languageCode.toLowerCase() == 'ru';
  String _pick(String en, String ru) => isRussian ? ru : en;

  String get title => _pick('Create building', 'Создание здания');
  String get apartmentTitle =>
      _pick('Apartment topology Wizard', 'Мастер планировки квартиры');
  String get cancel => _pick('Cancel', 'Отмена');
  String get back => _pick('Back', 'Назад');
  String get parameters => _pick('Parameters', 'Параметры');
  String get candidates => _pick('Variants', 'Варианты');
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
  String get generateVariants =>
      _pick('Generate variants', 'Сформировать варианты');
  String get preparePreview =>
      _pick('Prepare preview', 'Подготовить предпросмотр');
  String get numericError => _pick(
        'Level counts and height must be numbers.',
        'Количество этажей и высота должны быть числами.',
      );
  String get apartmentNumericError => _pick(
        'Room counts and area must be valid numbers.',
        'Количество помещений и площадь должны быть корректными числами.',
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
  String get apartmentPreviewEmptyHint => _pick(
        'Generate variants, select one, then prepare the canonical preview.',
        'Сформируйте варианты, выберите один и подготовьте канонический предпросмотр.',
      );
  String get changesEmpty => _pick(
        'Changes will appear after generation',
        'Изменения появятся после генерации',
      );
  String get changesEmptyHint => _pick(
        'Apply always commits the whole candidate.',
        'Применение выполняется ко всему варианту целиком.',
      );
  String changesCount(int count) =>
      _pick('Changes ($count)', 'Изменения ($count)');
  String get searchChanges => _pick('Search changes', 'Поиск изменений');
  String get noMatchingChanges =>
      _pick('No matching changes.', 'Изменения не найдены.');
  String groupedChangesCount(int semanticCount, int boundaryCount) => _pick(
        '$semanticCount semantic changes · $boundaryCount boundary edges',
        'Семантических изменений: $semanticCount · границ: $boundaryCount',
      );
  String get boundaryTopology => _pick('Boundary topology', 'Топология границ');
  String boundaryEdgeCount(int count) =>
      _pick('$count boundary edges', 'Границ: $count');
  String boundaryTopologySummary(int count) => _pick(
        'Boundary topology with $count edges',
        'Топология границ, сегментов: $count',
      );
  String get applyAll => _pick('Apply', 'Применить');
  String get noCandidates =>
      _pick('No candidates available.', 'Нет доступных вариантов.');
  String candidatePosition(String title, int index, int count) => _pick(
        '$title. Candidate $index of $count',
        '$title. Вариант $index из $count',
      );
  String selectedCandidate(int index, int count) => _pick(
        'Selected candidate $index of $count',
        '$title. Вариант $index из $count',
      );
  String get zoomIn => _pick('Zoom in', 'Увеличить');
  String get zoomOut => _pick('Zoom out', 'Уменьшить');
  String get resetView => _pick('Reset view', 'Сбросить вид');

  String get apartmentRooms => _pick('Habitable rooms', 'Жилых комнат');
  String get apartmentArea => _pick('Interior area, m²', 'Площадь, м²');
  String get apartmentBathrooms => _pick('Bathrooms', 'Ванных');
  String get apartmentSeparateWc => _pick('Separate WC', 'Отдельных WC');
  String get apartmentBalconies =>
      _pick('Balconies/loggias', 'Балконов/лоджий');
  String get apartmentBalconyKind =>
      _pick('Balcony type', 'Тип балкона/лоджии');
  String get apartmentKitchenMode => _pick('Kitchen', 'Кухня');
  String get apartmentCorridorMode => _pick('Corridor', 'Коридор');
  String get apartmentDayNight => _pick(
        'Prefer day/night separation',
        'Предпочитать разделение день/ночь',
      );
  String get apartmentSelectedVariant =>
      _pick('Selected apartment variant', 'Выбранный вариант квартиры');
  String get apartmentCanonicalPreview =>
      _pick('Canonical preview', 'Канонический предпросмотр');
  String get apartmentTopologyOnlyPreview =>
      _pick('Topology-only preview', 'Предпросмотр только топологии');
  String get apartmentTopologyOnlyEngineeringHint => _pick(
        'No electrical values are assumed. Engineering output becomes available only when authoritative electrical inputs are configured.',
        'Электрические параметры не предполагаются. Инженерный результат доступен только после настройки авторитетных электротехнических исходных данных.',
      );
  String get apartmentFrozenEngineeringOutput => _pick(
      'Frozen engineering output', 'Зафиксированный инженерный результат');
  String get apartmentExactD8OutputTooltip => _pick(
        'Exact D8 output used by Apply',
        'Точный результат D8, используемый при применении',
      );
  String get apartmentEngineeringSystem => _pick('System', 'Система');
  String get apartmentEngineeringVoltage => _pick('Voltage', 'Напряжение');
  String get apartmentEngineeringMaxPhaseCurrent =>
      _pick('Max phase current', 'Макс. ток фазы');
  String apartmentEngineeringCircuits(int count) =>
      _pick('Circuits ($count)', 'Цепи ($count)');
  String get apartmentEngineeringCircuitsShort => _pick('Circuits', 'Цепи');
  String get apartmentEngineeringImbalance => _pick('Imbalance', 'Небаланс');
  String get apartmentEngineeringNoBranchCircuits => _pick(
        'No branch circuits in this engineering projection.',
        'В инженерной проекции нет отходящих цепей.',
      );
  String get apartmentEngineeringSingleLineDiagram =>
      _pick('Single-line diagram', 'Однолинейная схема');
  String get apartmentEngineeringNoSldNodes => _pick(
        'No SLD nodes in this engineering projection.',
        'В инженерной проекции нет узлов однолинейной схемы.',
      );
  String get apartmentEngineeringWhy => _pick('Why', 'Обоснование');
  String get apartmentEngineeringNoExplanations => _pick(
        'No additional engineering explanations.',
        'Дополнительные инженерные обоснования отсутствуют.',
      );
  String get apartmentEngineeringLoad => _pick('Load', 'Нагрузка');
  String get apartmentEngineeringCable => _pick('Cable', 'Кабель');
  String get apartmentEngineeringOvercurrentProtection =>
      _pick('Overcurrent protection', 'Защита от сверхтока');
  String get apartmentEngineeringResidualProtection => _pick(
        'RCD / residual protection',
        'УЗО / дифференциальная защита',
      );
  String get apartmentEngineeringFaultDisconnection =>
      _pick('Fault / disconnection', 'КЗ / отключение');
  String get apartmentEngineeringCoordination =>
      _pick('Coordination', 'Селективность / координация');
  String apartmentEngineeringInstallation(String sectionId) =>
      _pick('Installation $sectionId', 'Прокладка $sectionId');
  String apartmentEngineeringCircuit(String circuitId) =>
      _pick('Circuit $circuitId', 'Цепь $circuitId');
  String apartmentEngineeringSldConnections(int count) => _pick(
        '$count SLD connections',
        'Соединений однолинейной схемы: $count',
      );
  String get apartmentEngineeringProposalFingerprint =>
      _pick('Proposal', 'Предложение');
  String get apartmentEngineeringOutputFingerprint =>
      _pick('Output', 'Результат');
  String get apartmentEngineeringRequirementsFingerprint =>
      _pick('Requirements', 'Требования');

  String get site => _pick('Site', 'Участок');
  String get building => _pick('Building', 'Здание');
  String get level => _pick('Level', 'Этаж');
  String get apartment => _pick('Apartment', 'Квартира');
  String get space => _pick('Space', 'Помещение');
  String get boundary => _pick('Boundary', 'Граница');
  String get door => _pick('Door', 'Дверь');
  String get openPassage => _pick('Open passage', 'Открытый проход');
  String get nameField => _pick('Name', 'Название');
  String get buildingsField => _pick('Buildings', 'Здания');
  String get displayOrderField => _pick('Display order', 'Порядок отображения');
  String get levelsField => _pick('Levels', 'Этажи');
  String get numberField => _pick('Number', 'Номер');
  String get elevationField => _pick('Elevation', 'Отметка');
  String get kindField => _pick('Kind', 'Тип');
  String get floorToFloorField => _pick('Floor-to-floor', 'Высота этажа');
  String get usageField => _pick('Usage', 'Назначение');
  String get spacesField => _pick('Spaces', 'Помещения');
  String get widthField => _pick('Width', 'Ширина');
  String get heightField => _pick('Height', 'Высота');
  String get connectedSpacesField =>
      _pick('Connected spaces', 'Связанные помещения');

  String diffText(String raw) {
    if (!isRussian) return raw;
    return raw
        .replaceFirst('Site “', '$site “')
        .replaceFirst('Building “', '$building “')
        .replaceFirst('Level ', '$level ')
        .replaceFirst('Apartment “', '$apartment “')
        .replaceFirst('Space “', '$space “')
        .replaceFirst('Boundary — ', '$boundary — ')
        .replaceFirst('Door: ', '$door: ')
        .replaceFirst('Open passage: ', '$openPassage: ')
        .replaceFirst('Relationships', 'Связи');
  }

  String diffField(String raw) => switch (raw) {
        'Name' => nameField,
        'Buildings' => buildingsField,
        'Display order' => displayOrderField,
        'Levels' => levelsField,
        'Number' => numberField,
        'Elevation' => elevationField,
        'Kind' => kindField,
        'Floor-to-floor' => floorToFloorField,
        'Usage' => usageField,
        'Spaces' => spacesField,
        'Width' => widthField,
        'Height' => heightField,
        'Connected spaces' => connectedSpacesField,
        _ => raw,
      };

  String previewSemanticLabel(String buildingName, int levelCount) => _pick(
        '$buildingName: $levelCount levels',
        '$buildingName: этажей $levelCount',
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
        'p9.parameters.room-count-out-of-range' => _pick(
            'Habitable room count must be between 1 and 10.',
            'Количество жилых комнат должно быть от 1 до 10.',
          ),
        'p9.parameters.area-out-of-range' => _pick(
            'Interior area must be between 15 and 500 m².',
            'Площадь должна быть от 15 до 500 м².',
          ),
        'p9.parameters.bathroom-count-out-of-range' => _pick(
            'Bathroom count must be between 1 and 6.',
            'Количество ванных должно быть от 1 до 6.',
          ),
        'p9.parameters.wc-count-out-of-range' => _pick(
            'Separate WC count must be between 0 and 4.',
            'Количество отдельных WC должно быть от 0 до 4.',
          ),
        'p9.parameters.balcony-count-out-of-range' => _pick(
            'Balcony/loggia count must be between 0 and 6.',
            'Количество балконов/лоджий должно быть от 0 до 6.',
          ),
        'p9.materialize.target-not-empty' => _pick(
            'Apartment generation requires an empty Level.',
            'Генерация квартиры требует пустого этажа.',
          ),
        'p9.provider.no-candidates' => _pick(
            'No qualified apartment variants match these parameters.',
            'Нет квалифицированных вариантов для заданных параметров.',
          ),
        _ => fallback,
      };
}
