import '../domain/electrical_placement.dart';

final class ElectricalSvgSymbol {
  const ElectricalSvgSymbol({
    required this.id,
    required this.type,
    required this.displayName,
    required this.svg,
  });

  final String id;
  final ElectricalComponentType type;
  final String displayName;
  final String svg;
}

abstract final class ElectricalSymbolCatalog {
  static const _stroke = '#263238';

  static final Map<ElectricalComponentType, ElectricalSvgSymbol> _symbols = {
    ElectricalComponentType.socketOutlet: ElectricalSvgSymbol(
      id: 'socket-outlet',
      type: ElectricalComponentType.socketOutlet,
      displayName: 'Розетка',
      svg: _wrap('<circle cx="12" cy="12" r="8" fill="none" stroke="$_stroke" stroke-width="1.6"/><path d="M8 12h8M10 9v6M14 9v6" stroke="$_stroke" stroke-width="1.4"/>'),
    ),
    ElectricalComponentType.switchControl: ElectricalSvgSymbol(
      id: 'switch-control',
      type: ElectricalComponentType.switchControl,
      displayName: 'Выключатель',
      svg: _wrap('<circle cx="12" cy="12" r="8" fill="none" stroke="$_stroke" stroke-width="1.6"/><path d="M8 15l8-6" stroke="$_stroke" stroke-width="1.6"/>'),
    ),
    ElectricalComponentType.lightingPoint: ElectricalSvgSymbol(
      id: 'lighting-point',
      type: ElectricalComponentType.lightingPoint,
      displayName: 'Точка освещения',
      svg: _wrap('<circle cx="12" cy="12" r="8" fill="none" stroke="$_stroke" stroke-width="1.6"/><path d="M7 7l10 10M17 7L7 17" stroke="$_stroke" stroke-width="1.4"/>'),
    ),
    ElectricalComponentType.curtainMotor: ElectricalSvgSymbol(
      id: 'curtain-motor',
      type: ElectricalComponentType.curtainMotor,
      displayName: 'Привод штор',
      svg: _wrap('<rect x="4" y="7" width="16" height="10" rx="2" fill="none" stroke="$_stroke" stroke-width="1.6"/><text x="12" y="14" text-anchor="middle" font-size="7" fill="$_stroke">M</text>'),
    ),
    ElectricalComponentType.junctionBox: ElectricalSvgSymbol(
      id: 'junction-box',
      type: ElectricalComponentType.junctionBox,
      displayName: 'Распредкоробка',
      svg: _wrap('<rect x="5" y="5" width="14" height="14" fill="none" stroke="$_stroke" stroke-width="1.6"/><circle cx="12" cy="12" r="2" fill="$_stroke"/>'),
    ),
    ElectricalComponentType.powerSource: ElectricalSvgSymbol(
      id: 'power-source',
      type: ElectricalComponentType.powerSource,
      displayName: 'Источник питания',
      svg: _wrap('<circle cx="12" cy="12" r="8" fill="none" stroke="$_stroke" stroke-width="1.6"/><path d="M12 5v14M8 9h8" stroke="$_stroke" stroke-width="1.4"/>'),
    ),
    ElectricalComponentType.distributionBoard: ElectricalSvgSymbol(
      id: 'distribution-board',
      type: ElectricalComponentType.distributionBoard,
      displayName: 'Щит',
      svg: _wrap('<rect x="5" y="4" width="14" height="16" rx="1" fill="none" stroke="$_stroke" stroke-width="1.6"/><path d="M9 8h6M9 12h6M9 16h6" stroke="$_stroke" stroke-width="1.2"/>'),
    ),
    ElectricalComponentType.custom: ElectricalSvgSymbol(
      id: 'custom-component',
      type: ElectricalComponentType.custom,
      displayName: 'Компонент',
      svg: _wrap('<rect x="5" y="5" width="14" height="14" rx="3" fill="none" stroke="$_stroke" stroke-width="1.6"/><path d="M12 8v8M8 12h8" stroke="$_stroke" stroke-width="1.4"/>'),
    ),
  };

  static ElectricalSvgSymbol forType(ElectricalComponentType type) =>
      _symbols[type]!;

  static List<ElectricalSvgSymbol> get all => List.unmodifiable(_symbols.values);

  static String _wrap(String body) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">$body</svg>';
}
