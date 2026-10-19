import 'cable_spec.dart';
import 'route_host.dart';

enum InstallationMethod {
  concealedWall,
  conduit,
  cableTray,
  facade,
  undergroundTrench,
  undergroundDuct,
  overheadSpan,
  riserShaft,
}

enum ChannelCapacityModel { areaFill, cableCount, dedicated }

final class InstallationChannelSpec {
  InstallationChannelSpec({
    required this.id,
    required this.capacityModel,
    this.usableAreaMm2,
    this.maxCableCount,
    this.maxFillRatio = 0.40,
    this.reserveRatio = 0.20,
    this.allowedSegregationClasses = const {
      CableSegregationClass.power,
      CableSegregationClass.data,
      CableSegregationClass.control,
      CableSegregationClass.safety,
      CableSegregationClass.optical,
      CableSegregationClass.coaxial,
      CableSegregationClass.other,
    },
  }) {
    if (id.isEmpty) throw ArgumentError('Channel id must be non-empty.');
    if (maxFillRatio <= 0 || maxFillRatio > 1) {
      throw ArgumentError.value(maxFillRatio, 'maxFillRatio');
    }
    if (reserveRatio < 0 || reserveRatio >= 1) {
      throw ArgumentError.value(reserveRatio, 'reserveRatio');
    }
    if (capacityModel == ChannelCapacityModel.areaFill &&
        (usableAreaMm2 == null || usableAreaMm2! <= 0)) {
      throw ArgumentError('Area-fill channel requires positive usableAreaMm2.');
    }
    if (capacityModel == ChannelCapacityModel.cableCount &&
        (maxCableCount == null || maxCableCount! <= 0)) {
      throw ArgumentError(
          'Cable-count channel requires positive maxCableCount.');
    }
  }

  final String id;
  final ChannelCapacityModel capacityModel;
  final double? usableAreaMm2;
  final int? maxCableCount;
  final double maxFillRatio;
  final double reserveRatio;
  final Set<CableSegregationClass> allowedSegregationClasses;

  double get effectiveFillLimit => maxFillRatio * (1 - reserveRatio);
}

final class InstallationPathSpec {
  InstallationPathSpec({
    required this.id,
    required this.name,
    required this.method,
    required Iterable<InstallationChannelSpec> channels,
    this.materialCostPerMeter,
    this.laborCostPerMeter,
  }) : channels = List.unmodifiable(channels) {
    if (id.isEmpty)
      throw ArgumentError('Installation path id must be non-empty.');
    if (this.channels.isEmpty) {
      throw ArgumentError('Installation path requires at least one channel.');
    }
    final ids = this.channels.map((item) => item.id).toSet();
    if (ids.length != this.channels.length) {
      throw ArgumentError('Installation channel ids must be unique.');
    }
  }

  final String id;
  final String name;
  final InstallationMethod method;
  final List<InstallationChannelSpec> channels;
  final double? materialCostPerMeter;
  final double? laborCostPerMeter;

  InstallationChannelSpec? channelById(String id) {
    for (final channel in channels) {
      if (channel.id == id) return channel;
    }
    return null;
  }
}

/// A concrete part of an installation path located on one route host.
final class InstallationPathSection {
  const InstallationPathSection({
    required this.id,
    required this.pathSpecId,
    required this.host,
    required this.lengthMm,
  });

  final String id;
  final String pathSpecId;
  final RouteHostRef host;
  final double lengthMm;
}

/// Assignment of one or more identical cables to one physical channel.
final class RouteOccupancy {
  const RouteOccupancy({
    required this.routeId,
    required this.pathSectionId,
    required this.channelId,
    required this.cable,
    this.quantity = 1,
  }) : assert(quantity > 0);

  final String routeId;
  final String pathSectionId;
  final String channelId;
  final CableSpec cable;
  final int quantity;

  double get occupiedAreaMm2 => cable.occupiedCircularAreaMm2 * quantity;
}
