import '../../../domain/boundary_host_migration.dart';
import '../../../domain/boundary_topology.dart';
import '../../../domain/project_aggregate.dart';
import '../../../domain/project_identity.dart';
import '../project_mutation_reservation.dart';

enum WizardPreviewRole {
  buildingFrame,
  level,
  referenceLevel,
  basement,
  label,
  apartmentZone,
  spaceRegion,
  boundary,
  opening,
  entryMarker,
}

sealed class WizardPreviewElement {
  const WizardPreviewElement({
    required this.key,
    required this.role,
    this.sourceEntityId,
  });

  final String key;
  final WizardPreviewRole role;
  final EntityId? sourceEntityId;
}

final class WizardPreviewPoint {
  const WizardPreviewPoint(this.x, this.y);

  final double x;
  final double y;
}

final class WizardPreviewRect extends WizardPreviewElement {
  const WizardPreviewRect({
    required super.key,
    required super.role,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    super.sourceEntityId,
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
    super.sourceEntityId,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

final class WizardPreviewPolygon extends WizardPreviewElement {
  WizardPreviewPolygon({
    required super.key,
    required super.role,
    required Iterable<WizardPreviewPoint> points,
    super.sourceEntityId,
  }) : points = List.unmodifiable(points) {
    if (this.points.length < 3) {
      throw ArgumentError('Wizard preview polygon requires at least 3 points.');
    }
  }

  final List<WizardPreviewPoint> points;
}

final class WizardPreviewText extends WizardPreviewElement {
  const WizardPreviewText({
    required super.key,
    required super.role,
    required this.x,
    required this.y,
    required this.text,
    super.sourceEntityId,
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
        'Basic Building preview Building $buildingId is missing.',
      );
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
        sourceEntityId: building.id,
      ),
      WizardPreviewRect(
        key: 'building-frame',
        role: WizardPreviewRole.buildingFrame,
        x: left,
        y: top,
        width: buildingWidth,
        height: levels.length * rowHeight,
        sourceEntityId: building.id,
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
            sourceEntityId: level.id,
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
          sourceEntityId: level.id,
        ),
        WizardPreviewText(
          key: 'level-elevation:${level.id.value}',
          role: role,
          x: left + buildingWidth - 132,
          y: y + 21,
          text: _signedMm(level.elevationMm),
          sourceEntityId: level.id,
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

/// P9.10 large-preview projection from the exact reserved canonical candidate.
///
/// It consumes only canonical Zone/Space/Boundary/Opening state. It never reads
/// P9 generator geometry and never parses SVG back into engineering state.
final class ApartmentWizardPreviewProjector {
  const ApartmentWizardPreviewProjector();

  WizardPreviewScene project(ReservedProjectMutationPreview preview) {
    final candidate = preview.candidate;
    final zoneId = _apartmentZoneId(preview, candidate);
    if (zoneId == null) {
      throw StateError('Apartment preview has no created apartment zone.');
    }
    final zone = candidate.stores.zones[zoneId];
    if (zone == null || zone.spaceIds.isEmpty) {
      throw StateError('Apartment preview zone is missing canonical Spaces.');
    }

    final topologies = <SpaceId, SpaceBoundaryTopology>{};
    for (final spaceId in zone.spaceIds) {
      final topology = candidate.stores.boundaries[spaceId];
      if (topology == null) {
        throw StateError('Apartment Space $spaceId has no canonical boundary.');
      }
      topology.validateOrThrow();
      topologies[spaceId] = topology;
    }

    final edges = topologies.values.expand((topology) => topology.edges.values);
    final points = edges.expand((edge) => [edge.start, edge.end]).toList();
    if (points.isEmpty) {
      throw StateError('Apartment preview has no boundary geometry.');
    }

    final minX = points.map((point) => point.xMm).reduce(_minInt);
    final maxX = points.map((point) => point.xMm).reduce(_maxInt);
    final minY = points.map((point) => point.yMm).reduce(_minInt);
    final maxY = points.map((point) => point.yMm).reduce(_maxInt);
    final geometryWidth = maxX - minX;
    final geometryHeight = maxY - minY;
    if (geometryWidth <= 0 || geometryHeight <= 0) {
      throw StateError('Apartment preview canonical geometry is degenerate.');
    }

    const width = 720.0;
    const height = 560.0;
    const margin = 48.0;
    const titleBand = 34.0;
    final scaleX = (width - margin * 2) / geometryWidth;
    final scaleY = (height - margin * 2 - titleBand) / geometryHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final originY = margin + titleBand;

    WizardPreviewPoint transform(BoundaryPointMm point) => WizardPreviewPoint(
          margin + (point.xMm - minX) * scale,
          originY + (maxY - point.yMm) * scale,
        );

    final elements = <WizardPreviewElement>[
      WizardPreviewText(
        key: 'apartment-zone:${zone.id.value}',
        role: WizardPreviewRole.apartmentZone,
        x: margin,
        y: 28,
        text: zone.name,
        sourceEntityId: zone.id,
      ),
    ];

    final orderedSpaces = zone.spaceIds.toList()
      ..sort((left, right) {
        final leftSpace = candidate.stores.spaces[left]!;
        final rightSpace = candidate.stores.spaces[right]!;
        final usage = leftSpace.usage.name.compareTo(rightSpace.usage.name);
        if (usage != 0) return usage;
        final name = leftSpace.name.compareTo(rightSpace.name);
        return name != 0 ? name : left.value.compareTo(right.value);
      });

    for (final spaceId in orderedSpaces) {
      final space = candidate.stores.spaces[spaceId]!;
      final topology = topologies[spaceId]!;
      final polygon = <WizardPreviewPoint>[
        for (final edgeId in topology.orderedEdgeIds)
          transform(topology.edges[edgeId]!.start),
      ];
      elements.add(
        WizardPreviewPolygon(
          key: 'space-region:${spaceId.value}',
          role: WizardPreviewRole.spaceRegion,
          points: polygon,
          sourceEntityId: spaceId,
        ),
      );

      var minSceneX = polygon.first.x;
      var maxSceneX = polygon.first.x;
      var minSceneY = polygon.first.y;
      var maxSceneY = polygon.first.y;
      for (final point in polygon.skip(1)) {
        if (point.x < minSceneX) minSceneX = point.x;
        if (point.x > maxSceneX) maxSceneX = point.x;
        if (point.y < minSceneY) minSceneY = point.y;
        if (point.y > maxSceneY) maxSceneY = point.y;
      }
      elements.add(
        WizardPreviewText(
          key: 'space-label:${spaceId.value}',
          role: WizardPreviewRole.label,
          x: (minSceneX + maxSceneX) / 2,
          y: (minSceneY + maxSceneY) / 2,
          text: space.name,
          sourceEntityId: spaceId,
        ),
      );

      for (final edgeId in topology.orderedEdgeIds) {
        final edge = topology.edges[edgeId]!;
        final start = transform(edge.start);
        final end = transform(edge.end);
        elements.add(
          WizardPreviewLine(
            key: 'boundary:${edgeId.value}',
            role: WizardPreviewRole.boundary,
            x1: start.x,
            y1: start.y,
            x2: end.x,
            y2: end.y,
            sourceEntityId: edgeId,
          ),
        );
      }
    }

    final openings = candidate.stores.openings.values
        .where(
          (opening) => opening.connectedSpaceIds.any(zone.spaceIds.contains),
        )
        .toList()
      ..sort((left, right) => left.id.value.compareTo(right.id.value));
    final registry = candidate.engineeringMetadata.boundaryHostedObjectRegistry;
    for (final opening in openings) {
      BoundaryHostedReference? host;
      for (final spaceId in opening.connectedSpaceIds) {
        host = registry.openingHost(opening.id, spaceId);
        if (host != null) break;
      }
      if (host == null ||
          host.startOffsetMm == null ||
          host.endOffsetMm == null) {
        throw StateError(
            'Opening ${opening.id} has no canonical boundary host.');
      }
      final topology = topologies[host.host.spaceId];
      final edge = topology?.edges[host.host.edgeId];
      if (edge == null) {
        throw StateError('Opening ${opening.id} host edge is not active.');
      }
      final start = transform(_pointAtOffset(edge, host.startOffsetMm!));
      final end = transform(_pointAtOffset(edge, host.endOffsetMm!));
      elements.add(
        WizardPreviewLine(
          key: 'opening:${opening.id.value}',
          role: opening.connectedSpaceIds.length == 1
              ? WizardPreviewRole.entryMarker
              : WizardPreviewRole.opening,
          x1: start.x,
          y1: start.y,
          x2: end.x,
          y2: end.y,
          sourceEntityId: opening.id,
        ),
      );
    }

    return WizardPreviewScene(
      width: width,
      height: height,
      semanticLabel: '${zone.name}: ${zone.spaceIds.length} spaces',
      elements: elements,
    );
  }

  ZoneId? _apartmentZoneId(
    ReservedProjectMutationPreview preview,
    ProjectAggregateRoot candidate,
  ) {
    final created = <ZoneId>[];
    for (final operation in preview.semanticChangeSet.operations) {
      if (operation is CreateEntityOperation && operation.entityId is ZoneId) {
        final id = operation.entityId as ZoneId;
        if (candidate.stores.zones[id]?.kind ==
            ProjectStructuralZoneKind.apartment) {
          created.add(id);
        }
      }
    }
    if (created.length != 1) return null;
    return created.single;
  }

  BoundaryPointMm _pointAtOffset(ProjectBoundaryEdge edge, int offsetMm) {
    final length = (edge.end.xMm - edge.start.xMm).abs() +
        (edge.end.yMm - edge.start.yMm).abs();
    if (offsetMm < 0 || offsetMm > length) {
      throw StateError('Hosted opening offset is outside its boundary edge.');
    }
    final dx = edge.end.xMm.compareTo(edge.start.xMm);
    final dy = edge.end.yMm.compareTo(edge.start.yMm);
    return BoundaryPointMm(
      xMm: edge.start.xMm + dx * offsetMm,
      yMm: edge.start.yMm + dy * offsetMm,
    );
  }
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
            'width="${_n(element.width)}" height="${_n(element.height)}" ',
          )
          ..write('fill="none" stroke="currentColor"/>');
      } else if (element is WizardPreviewLine) {
        buffer
          ..write('<line data-key="${_escape(element.key)}" ')
          ..write('x1="${_n(element.x1)}" y1="${_n(element.y1)}" ')
          ..write('x2="${_n(element.x2)}" y2="${_n(element.y2)}" ')
          ..write('stroke="currentColor"/>');
      } else if (element is WizardPreviewPolygon) {
        buffer
          ..write('<polygon data-key="${_escape(element.key)}" points="')
          ..write(
            element.points
                .map((point) => '${_n(point.x)},${_n(point.y)}')
                .join(' '),
          )
          ..write('" fill="none" stroke="currentColor"/>');
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

int _minInt(int left, int right) => left < right ? left : right;
int _maxInt(int left, int right) => left > right ? left : right;
