import 'package:flutter/widgets.dart';

import '../../application/project/wizard/building/building_composition_wizard_command.dart';
import '../../application/project/wizard/building/building_composition_wizard_provider.dart';
import '../../domain/project_service_anchor.dart';

final class BuildingCompositionWizardLocalizations {
  BuildingCompositionWizardLocalizations(BuildContext context)
      : ru = Localizations.localeOf(context).languageCode == 'ru';
  final bool ru;
  String text(String key) {
    final pair = _labels[key];
    if (pair == null) return ru ? 'Параметр' : 'Parameter';
    return ru ? pair.$2 : pair.$1;
  }

  String family(BuildingCompositionWizardFamily f) => text(switch (f) {
        BuildingCompositionWizardFamily.cottage => 'cottage',
        BuildingCompositionWizardFamily.residentialTower => 'tower',
        BuildingCompositionWizardFamily.residentialComplex => 'complex'
      });
  String side(BuildingWizardWallSide s) => text('side.${s.name}');
  String anchor(ProjectServiceAnchorKind k) => text('anchor.${k.name}');
  String summary(
          int buildings, int levels, int apartments, int cores, int anchors) =>
      ru
          ? 'Добавить: зданий — $buildings, этажей — $levels, квартир — $apartments, ядер — $cores, сервисных привязок — $anchors.'
          : 'Add $buildings buildings, $levels levels, $apartments apartments, $cores cores, $anchors service anchors.';
  static const _labels = <String, (String, String)>{
    'title': ('Residential composition', 'Жилая композиция'),
    'family': ('Composition family', 'Тип композиции'),
    'cottage': ('Cottage', 'Коттедж'),
    'tower': ('Residential tower', 'Жилая башня'),
    'complex': ('Residential complex', 'Жилой комплекс'),
    'name': ('Building name', 'Название здания'),
    'template': (
      'Published template v1 · catalog v1',
      'Опубликованный шаблон v1 · каталог v1'
    ),
    'x': ('Site X, mm', 'X участка, мм'),
    'y': ('Site Y, mm', 'Y участка, мм'),
    'width': ('Footprint width, mm', 'Ширина габарита, мм'),
    'depth': ('Footprint depth, mm', 'Глубина габарита, мм'),
    'rotation': ('Clockwise rotation', 'Поворот по часовой стрелке'),
    'floors': ('Residential levels above ground', 'Жилых этажей выше нулевого'),
    'basements': ('Basement levels', 'Подземных этажей'),
    'height': ('Storey height, mm', 'Высота этажа, мм'),
    'technical': ('Technical level', 'Технический этаж'),
    'roof': ('Roof level', 'Уровень кровли'),
    'cores': ('Cores and common areas', 'Ядра и общие помещения'),
    'stairs': ('Stair cores', 'Лестничных ядер'),
    'lifts': ('Lift cores', 'Лифтовых ядер'),
    'shafts': ('Service shafts', 'Сервисных шахт'),
    'electricalRisers': ('Electrical risers', 'Электрических стояков'),
    'telecomRisers': ('Telecom risers', 'Стояков связи'),
    'corridorWidth': ('Corridor width, mm', 'Ширина коридора, мм'),
    'technicalRoom': (
      'Technical room candidate',
      'Резерв технического помещения'
    ),
    'commonHall': ('Common hall', 'Общий холл'),
    'layout': ('Building-local layout', 'План в локальных координатах здания'),
    'originX': ('Corridor local X, mm', 'Локальный X коридора, мм'),
    'originY': ('Corridor local Y, mm', 'Локальный Y коридора, мм'),
    'corridorLength': ('Corridor length, mm', 'Длина коридора, мм'),
    'mix': ('Typical-floor apartment mix', 'Состав квартир типового этажа'),
    'rooms': ('Habitable rooms', 'Жилых комнат'),
    'area': ('Interior area, m²', 'Внутренняя площадь, м²'),
    'bathrooms': ('Bathrooms', 'Санузлов'),
    'addApartment': ('Add apartment', 'Добавить квартиру'),
    'remove': ('Remove', 'Удалить'),
    'addCottage': ('Add cottage', 'Добавить коттедж'),
    'addTower': ('Add tower', 'Добавить башню'),
    'services': (
      'Service and infrastructure anchors',
      'Сервисные и инфраструктурные привязки'
    ),
    'serviceHint': (
      'Entries use the ground-level corridor and a selected building-local wall. Areas use explicit Site coordinates.',
      'Вводы размещаются на выбранной локальной стене коридора нулевого этажа. Резервы — по явным координатам участка.'
    ),
    'side': (
      'Corridor wall in building-local frame',
      'Стена коридора в локальных координатах'
    ),
    'offset': ('Offset from edge start, mm', 'Отступ от начала ребра, мм'),
    'anchorHeight': ('Height above level, mm', 'Высота над этажом, мм'),
    'side.left': ('Left (minimum X)', 'Левая (минимальный X)'),
    'side.right': ('Right (maximum X)', 'Правая (максимальный X)'),
    'side.bottom': ('Bottom (minimum Y)', 'Нижняя (минимальный Y)'),
    'side.top': ('Top (maximum Y)', 'Верхняя (максимальный Y)'),
    'existing': ('Place existing buildings', 'Размещение существующих зданий'),
    'existingHint': (
      'Enter the missing Site placements explicitly. Existing local geometry stays unchanged; placements are included in this preview and Apply.',
      'Укажите отсутствующие размещения явно. Локальная геометрия сохранится; размещения войдут в этот предпросмотр и применение.'
    ),
    'invalid': (
      'Review required numeric fields, template limits and explicit locations.',
      'Проверьте обязательные числовые поля, ограничения шаблона и явные размещения.'
    ),
    'failure': (
      'Composition could not be prepared or applied. Review footprint clearance, apartment fit and physical service hosts.',
      'Не удалось подготовить или применить композицию. Проверьте габариты, размещение квартир и физические хосты вводов.'
    ),
    'overview': ('Site overview', 'Обзор участка'),
    'details': ('Canonical changes', 'Канонические изменения'),
    'architectureOnly': (
      'Architectural reservations; equipment and engineering sizing are configured later.',
      'Архитектурные резервы; оборудование и инженерные расчёты настраиваются позднее.'
    ),
    'shared': ('Shared Site anchors', 'Общие привязки участка'),
    'sharedHint': (
      'Optional shared service area for every building in this composition.',
      'Необязательный общий сервисный резерв для всех зданий этой композиции.'
    ),
    'anchor.electricalEntry': (
      'Electrical service entry',
      'Электрический ввод'
    ),
    'anchor.telecomEntry': ('Telecom / fiber entry', 'Ввод связи / оптики'),
    'anchor.fireBackboneEntry': (
      'Fire backbone entry',
      'Ввод пожарной магистрали'
    ),
    'anchor.intercomCctvEntry': (
      'Intercom / CCTV entry',
      'Ввод домофонии / CCTV'
    ),
    'anchor.generatorArea': ('Generator area', 'Резерв генератора'),
    'anchor.transformerArea': (
      'Transformer / substation area',
      'Резерв трансформатора / подстанции'
    ),
    'anchor.pvInverterArea': ('PV / inverter area', 'Резерв PV / инвертора'),
    'anchor.batteryUpsArea': ('Battery / UPS area', 'Резерв батареи / UPS'),
    'anchor.evChargingArea': ('EV charging area', 'Резерв зарядки EV'),
    'anchor.externalLightingFeeder': (
      'External lighting feeder',
      'Ввод наружного освещения'
    ),
  };
}
