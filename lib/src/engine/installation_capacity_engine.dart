import '../domain/installation_path.dart';

enum InstallationDefectKind {
  unknownPathSection,
  unknownPathSpec,
  unknownChannel,
  mediumNotAllowed,
  areaOverfill,
  cableCountExceeded,
  dedicatedChannelConflict,
}

enum InstallationDefectSeverity { warning, error }

final class InstallationDefect {
  const InstallationDefect({
    required this.kind,
    required this.severity,
    required this.objectId,
    required this.message,
    this.relatedRouteIds = const [],
  });

  final InstallationDefectKind kind;
  final InstallationDefectSeverity severity;
  final String objectId;
  final String message;
  final List<String> relatedRouteIds;
}

final class ChannelUtilization {
  const ChannelUtilization({
    required this.pathSectionId,
    required this.channelId,
    required this.cableCount,
    required this.occupiedAreaMm2,
    required this.fillRatio,
    required this.effectiveFillLimit,
    required this.reserveAvailableRatio,
  });

  final String pathSectionId;
  final String channelId;
  final int cableCount;
  final double occupiedAreaMm2;
  final double fillRatio;
  final double effectiveFillLimit;
  final double reserveAvailableRatio;

  double get fillPercent => fillRatio * 100;
  double get reserveAvailablePercent => reserveAvailableRatio * 100;
}

final class InstallationCapacityRequest {
  const InstallationCapacityRequest({
    required this.pathSpecs,
    required this.sections,
    required this.occupancies,
  });

  final List<InstallationPathSpec> pathSpecs;
  final List<InstallationPathSection> sections;
  final List<RouteOccupancy> occupancies;
}

final class InstallationCapacityResult {
  const InstallationCapacityResult({
    required this.defects,
    required this.channels,
  });

  final List<InstallationDefect> defects;
  final List<ChannelUtilization> channels;

  bool get hasErrors =>
      defects.any((item) => item.severity == InstallationDefectSeverity.error);
}

abstract final class InstallationCapacityEngine {
  static InstallationCapacityResult evaluate(
      InstallationCapacityRequest request) {
    final defects = <InstallationDefect>[];
    final utilizations = <ChannelUtilization>[];
    final specById = <String, InstallationPathSpec>{
      for (final spec in request.pathSpecs) spec.id: spec,
    };
    final sectionById = <String, InstallationPathSection>{
      for (final section in request.sections) section.id: section,
    };

    final grouped = <String, List<RouteOccupancy>>{};
    for (final occupancy in request.occupancies) {
      final section = sectionById[occupancy.pathSectionId];
      if (section == null) {
        defects.add(
          InstallationDefect(
            kind: InstallationDefectKind.unknownPathSection,
            severity: InstallationDefectSeverity.error,
            objectId: occupancy.pathSectionId,
            message: 'Unknown installation path section.',
            relatedRouteIds: [occupancy.routeId],
          ),
        );
        continue;
      }
      final path = specById[section.pathSpecId];
      if (path == null) {
        defects.add(
          InstallationDefect(
            kind: InstallationDefectKind.unknownPathSpec,
            severity: InstallationDefectSeverity.error,
            objectId: section.pathSpecId,
            message: 'Unknown installation path specification.',
            relatedRouteIds: [occupancy.routeId],
          ),
        );
        continue;
      }
      final channel = path.channelById(occupancy.channelId);
      if (channel == null) {
        defects.add(
          InstallationDefect(
            kind: InstallationDefectKind.unknownChannel,
            severity: InstallationDefectSeverity.error,
            objectId: occupancy.channelId,
            message: 'Unknown channel on installation path ${path.id}.',
            relatedRouteIds: [occupancy.routeId],
          ),
        );
        continue;
      }
      if (!channel.allowedSegregationClasses.contains(
        occupancy.cable.segregationClass,
      )) {
        defects.add(
          InstallationDefect(
            kind: InstallationDefectKind.mediumNotAllowed,
            severity: InstallationDefectSeverity.error,
            objectId: occupancy.channelId,
            message:
                '${occupancy.cable.segregationClass.name} media is not allowed in channel ${channel.id}.',
            relatedRouteIds: [occupancy.routeId],
          ),
        );
      }
      grouped
          .putIfAbsent('${section.id}::${channel.id}', () => <RouteOccupancy>[])
          .add(occupancy);
    }

    for (final entry in grouped.entries) {
      final separator = entry.key.indexOf('::');
      final sectionId = entry.key.substring(0, separator);
      final channelId = entry.key.substring(separator + 2);
      final section = sectionById[sectionId]!;
      final path = specById[section.pathSpecId]!;
      final channel = path.channelById(channelId)!;
      final occupancies = entry.value;
      final cableCount = occupancies.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );
      final occupiedArea = occupancies.fold<double>(
        0,
        (sum, item) => sum + item.occupiedAreaMm2,
      );

      switch (channel.capacityModel) {
        case ChannelCapacityModel.areaFill:
          final area = channel.usableAreaMm2!;
          final fillRatio = occupiedArea / area;
          final available = (channel.effectiveFillLimit - fillRatio)
              .clamp(0.0, 1.0)
              .toDouble();
          utilizations.add(
            ChannelUtilization(
              pathSectionId: sectionId,
              channelId: channelId,
              cableCount: cableCount,
              occupiedAreaMm2: occupiedArea,
              fillRatio: fillRatio,
              effectiveFillLimit: channel.effectiveFillLimit,
              reserveAvailableRatio: available,
            ),
          );
          if (fillRatio > channel.effectiveFillLimit) {
            defects.add(
              InstallationDefect(
                kind: InstallationDefectKind.areaOverfill,
                severity: InstallationDefectSeverity.error,
                objectId: channelId,
                message:
                    'Channel fill is ${(fillRatio * 100).toStringAsFixed(1)}%; effective limit with reserve is ${(channel.effectiveFillLimit * 100).toStringAsFixed(1)}%.',
                relatedRouteIds: [for (final item in occupancies) item.routeId],
              ),
            );
          }
        case ChannelCapacityModel.cableCount:
          final maxCount = channel.maxCableCount!;
          final ratio = cableCount / maxCount;
          utilizations.add(
            ChannelUtilization(
              pathSectionId: sectionId,
              channelId: channelId,
              cableCount: cableCount,
              occupiedAreaMm2: occupiedArea,
              fillRatio: ratio,
              effectiveFillLimit: 1,
              reserveAvailableRatio: (1 - ratio).clamp(0.0, 1.0).toDouble(),
            ),
          );
          if (cableCount > maxCount) {
            defects.add(
              InstallationDefect(
                kind: InstallationDefectKind.cableCountExceeded,
                severity: InstallationDefectSeverity.error,
                objectId: channelId,
                message:
                    'Channel contains $cableCount cables; maximum is $maxCount.',
                relatedRouteIds: [for (final item in occupancies) item.routeId],
              ),
            );
          }
        case ChannelCapacityModel.dedicated:
          final uniqueRoutes = occupancies.map((item) => item.routeId).toSet();
          final conflict = uniqueRoutes.length > 1 || cableCount > 1;
          utilizations.add(
            ChannelUtilization(
              pathSectionId: sectionId,
              channelId: channelId,
              cableCount: cableCount,
              occupiedAreaMm2: occupiedArea,
              fillRatio: conflict ? 1.0 : 0.0,
              effectiveFillLimit: 0,
              reserveAvailableRatio: conflict ? 0.0 : 1.0,
            ),
          );
          if (conflict) {
            defects.add(
              InstallationDefect(
                kind: InstallationDefectKind.dedicatedChannelConflict,
                severity: InstallationDefectSeverity.error,
                objectId: channelId,
                message:
                    'Dedicated channel must contain exactly one cable route.',
                relatedRouteIds: uniqueRoutes.toList(growable: false),
              ),
            );
          }
      }
    }

    return InstallationCapacityResult(
      defects: List.unmodifiable(defects),
      channels: List.unmodifiable(utilizations),
    );
  }
}
