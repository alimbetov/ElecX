import '../../../domain/project_aggregate.dart';
import '../../../domain/project_identity.dart';
import '../project_mutation_reservation.dart';

enum WizardPreviewRole {
  buildingFrame,
  level,
  referenceLevel,
  basement,
  label,
}

sealed class WizardPreviewElement {
  const WizardPreviewElement({required this.key, required this.role});

  final String key;
  final WizardPreviewRole role;
}

final class WizardPreviewRect extends WizardPreviewElement {
  const WizardPreviewRect({
    required super.key,
    required super.role,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

final class WizardPreviewLine extends WizardPreviewElement {
  const WizardPreviewLine({
    required super.key,
    required super.role,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

final class WizardPreviewText extends WizardPreviewElement {
  const WizardPreviewText({
    required super.key,
    required super.role,
    required this.x,
    required this.y,
    required this.text,
  });

  final double x;
  final double y;
  final String text;
}

final class WizardPreviewScene {
  WizardPreviewScene({
    required this.width,
    required this.height,
    required this.semanticLabel,
    required Iterable<WizardPreviewElement> elements,
  }) : elements = List.unmodifiable(elements) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Wizard preview dimensions must be positive.');
    }
    final keys = <String>{};
    for (final element in this.elements) {
      if (!keys.add(element.key)) {
        throw ArgumentError('Duplicate Wizard preview key ${element.key}.');
      }
    }
  }

  final double width;
  final double height;
  final String semanticLabel;
  final List<WizardPreviewElement> elements;
}

/// Provider-neutral canonical projection for the P8 Basic Building preview.
/// The scene is derived from the exact frozen candidate and therefore cannot
/// diverge from Apply by rerunning provider generation.
final class BasicBuildingWizardPreviewProjector {
  const BasicBuildingWizardPreviewProjector();

  WizardPreviewScene project(ReservedProjectMutationPreview preview) {
    final candidate = preview.candidate;
    final buildingId = _buildingId(preview, candidate);
    if (buildingId == null) {
      throw StateError('Basic Building preview has no affected Building.');
    }
    final building = candidate.stores.buildings[buildingId];
    if (building == null) {
      throw StateError(
          'Basic Building preview Building $buildingId is missing.');
    }
    final levels = candidate.stores.levels.values
        .where((level) => level.buildingId == buildingId)
        .toList()
      ..sort((left, right) {
        final elevation = right.elevationMm.compareTo(left.elevationMm);
        if (elevation != 0) return elevation;
        return right.levelNumber.compareTo(left.levelNumber);
      });
    if (levels.isEmpty) {
      throw StateError(
          'Basic Building preview must contain at least one Level.');
    }

    const width = 640.0;
    const left = 96.0;
    const buildingWidth = 448.0;
    const top = 68.0;
    const rowHeight = 32.0;
    const footer = 36.0;
    final height = top + levels.length * rowHeight + footer;
    final elements = <WizardPreviewElement>[
      WizardPreviewText(
        key: 'building-title',
        role: WizardPreviewRole.label,
        x: left,
        y: 30,
        text: building.name,
      ),
      WizardPreviewRect(
        key: 'building-frame',
        role: WizardPreviewRole.buildingFrame,
        x: left,
        y: top,
        width: buildingWidth,
        height: levels.length * rowHeight,
      ),
    ];

    for (var index = 0; index < levels.length; index++) {
      final level = levels[index];
      final y = top + index * rowHeight;
      final role = level.levelNumber < 0
          ? WizardPreviewRole.basement
          : level.elevationMm == 0
              ? WizardPreviewRole.referenceLevel
              : WizardPreviewRole.level;
      if (index > 0) {
        elements.add(
          WizardPreviewLine(
            key: 'level-line:${level.id.value}',
            role: role,
            x1: left,
            y1: y,
            x2: left + buildingWidth,
            y2: y,
          ),
        );
      }
      elements.addAll([
        WizardPreviewText(
          key: 'level-name:${level.id.value}',
          role: role,
          x: left + 16,
          y: y + 21,
          text: level.name,
        ),
        WizardPreviewText(
          key: 'level-elevation:${level.id.value}',
          role: role,
          x: left + buildingWidth - 132,
          y: y + 21,
          text: _signedMm(level.elevationMm),
        ),
      ]);
    }

    return WizardPreviewScene(
      width: width,
      height: height,
      semanticLabel: '${building.name}: ${levels.length} levels',
      elements: elements,
    );
  }

  BuildingId? _buildingId(
    ReservedProjectMutationPreview preview,
    ProjectAggregateRoot candidate,
  ) {
    for (final operation in preview.semanticChangeSet.operations) {
      if (operation is CreateEntityOperation &&
          operation.entityId is BuildingId) {
        return operation.entityId as BuildingId;
      }
      if (operation is UpdateEntityOperation &&
          operation.entityId is BuildingId) {
        return operation.entityId as BuildingId;
      }
    }
    for (final operation in preview.semanticChangeSet.operations) {
      if (operation is CreateEntityOperation && operation.entityId is LevelId) {
        return candidate.stores.levels[operation.entityId]?.buildingId;
      }
    }
    return null;
  }

  String _signedMm(int value) => value > 0 ? '+$value mm' : '$value mm';
}

/// Deterministic, inert SVG projection. It emits no scripts, event handlers,
/// foreignObject or external references and is never parsed back into canonical
/// geometry.
final class WizardSvgProjector {
  const WizardSvgProjector();

  String toSvg(WizardPreviewScene scene) {
    final buffer = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 ${_n(scene.width)} ${_n(scene.height)}" ')
      ..write('role="img" aria-label="${_escape(scene.semanticLabel)}">');
    for (final element in scene.elements) {
      if (element is WizardPreviewRect) {
        buffer
          ..write('<rect data-key="${_escape(element.key)}" ')
          ..write('x="${_n(element.x)}" y="${_n(element.y)}" ')
          ..write(
              'width="${_n(element.width)}" height="${_n(element.height)}" ')
          ..write('fill="none" stroke="currentColor"/>');
      } else if (element is WizardPreviewLine) {
        buffer
          ..write('<line data-key="${_escape(element.key)}" ')
          ..write('x1="${_n(element.x1)}" y1="${_n(element.y1)}" ')
          ..write('x2="${_n(element.x2)}" y2="${_n(element.y2)}" ')
          ..write('stroke="currentColor"/>');
      } else if (element is WizardPreviewText) {
        buffer
          ..write('<text data-key="${_escape(element.key)}" ')
          ..write('x="${_n(element.x)}" y="${_n(element.y)}">')
          ..write(_escape(element.text))
          ..write('</text>');
      }
    }
    buffer.write('</svg>');
    return buffer.toString();
  }

  String _n(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(3);

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
