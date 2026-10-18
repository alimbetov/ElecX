enum RoomUsageType {
  living,
  bedroom,
  kitchen,
  bathroom,
  corridor,
  stair,
  electricalRoom,
  technical,
  parking,
  storage,
  serverRoom,
  commercial,
  industrial,
  outdoor,
  custom,
}

enum TemperatureRegime {
  heated,
  unheated,
  refrigerated,
  hot,
  outdoor,
  variable,
  custom,
}

/// Engineering environment attached to one room/space.
///
/// Temperatures are design values used by normative, routing and cable-sizing
/// engines. They are not UI-only metadata and must be persisted with the room.
final class RoomEnvironment {
  RoomEnvironment({
    required this.roomId,
    required this.usageType,
    required this.temperatureRegime,
    required this.designMinC,
    required this.designMaxC,
    this.designNominalC,
    this.maxRelativeHumidityPercent,
    this.wetZone = false,
    this.dusty = false,
    this.corrosive = false,
    this.environmentTags = const <String>{},
  }) {
    if (roomId.isEmpty) {
      throw ArgumentError('roomId must be non-empty.');
    }
    if (designMinC > designMaxC) {
      throw ArgumentError('designMinC must be <= designMaxC.');
    }
    final nominal = designNominalC;
    if (nominal != null && (nominal < designMinC || nominal > designMaxC)) {
      throw ArgumentError('designNominalC must be inside min/max range.');
    }
    final humidity = maxRelativeHumidityPercent;
    if (humidity != null && (humidity < 0 || humidity > 100)) {
      throw ArgumentError.value(
        humidity,
        'maxRelativeHumidityPercent',
        'Must be between 0 and 100.',
      );
    }
  }

  final String roomId;
  final RoomUsageType usageType;
  final TemperatureRegime temperatureRegime;
  final double designMinC;
  final double designMaxC;
  final double? designNominalC;
  final double? maxRelativeHumidityPercent;
  final bool wetZone;
  final bool dusty;
  final bool corrosive;
  final Set<String> environmentTags;

  double get cableSizingAmbientC => designMaxC;
}

/// Geographic/site context is intentionally separate from room-local geometry.
/// It may drive climate/normative profiles, while component positions remain
/// integer millimetres in room/surface coordinates.
final class SiteGeoReference {
  SiteGeoReference({
    required this.siteId,
    required this.latitude,
    required this.longitude,
    this.altitudeM,
    this.climateProfileId,
  }) {
    if (siteId.isEmpty) throw ArgumentError('siteId must be non-empty.');
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude');
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError.value(longitude, 'longitude');
    }
  }

  final String siteId;
  final double latitude;
  final double longitude;
  final double? altitudeM;
  final String? climateProfileId;
}
