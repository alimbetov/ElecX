import '../../domain/project_identity.dart';

/// Versioned transitional identity codec used only while the canonical project
/// is materialized into the legacy single-building editor document.
///
/// Old legacy ids remain untouched and keep their deterministic bootstrap
/// migration. Newly materialized canonical Levels, Zones and Spaces receive an
/// encoded legacy id that round-trips the exact canonical identity across
/// save/reopen.
abstract final class CanonicalLegacyIdentityCodec {
  static const String levelPrefix = 'elecx-canonical-level-v1:';
  static const String zonePrefix = 'elecx-canonical-zone-v1:';
  static const String spacePrefix = 'elecx-canonical-space-v1:';

  static bool isEncodedLevelId(String legacyId) =>
      legacyId.startsWith(levelPrefix);

  static bool isEncodedZoneId(String legacyId) => legacyId.startsWith(zonePrefix);

  static bool isEncodedSpaceId(String legacyId) =>
      legacyId.startsWith(spacePrefix);

  static String encodeLevelId(LevelId levelId) => _encode(
        prefix: levelPrefix,
        value: levelId.value,
        parameterName: 'levelId',
      );

  static String encodeZoneId(ZoneId zoneId) => _encode(
        prefix: zonePrefix,
        value: zoneId.value,
        parameterName: 'zoneId',
      );

  static String encodeSpaceId(SpaceId spaceId) => _encode(
        prefix: spacePrefix,
        value: spaceId.value,
        parameterName: 'spaceId',
      );

  /// Returns null for an ordinary pre-P8 legacy id.
  ///
  /// A value carrying the canonical bridge prefix is authoritative bridge data;
  /// malformed or non-canonical encoding therefore fails closed instead of
  /// falling back to a derived identity.
  static LevelId? tryDecodeLevelId(String legacyId) {
    final decoded = _tryDecode(
      legacyId: legacyId,
      prefix: levelPrefix,
      kind: 'LevelId',
    );
    return decoded == null ? null : LevelId(decoded);
  }

  static ZoneId? tryDecodeZoneId(String legacyId) {
    final decoded = _tryDecode(
      legacyId: legacyId,
      prefix: zonePrefix,
      kind: 'ZoneId',
    );
    return decoded == null ? null : ZoneId(decoded);
  }

  static SpaceId? tryDecodeSpaceId(String legacyId) {
    final decoded = _tryDecode(
      legacyId: legacyId,
      prefix: spacePrefix,
      kind: 'SpaceId',
    );
    return decoded == null ? null : SpaceId(decoded);
  }

  static String _encode({
    required String prefix,
    required String value,
    required String parameterName,
  }) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, parameterName, 'Must be non-empty.');
    }
    return '$prefix${Uri.encodeComponent(value)}';
  }

  static String? _tryDecode({
    required String legacyId,
    required String prefix,
    required String kind,
  }) {
    if (!legacyId.startsWith(prefix)) return null;
    final encoded = legacyId.substring(prefix.length);
    if (encoded.isEmpty) {
      throw FormatException('Encoded canonical $kind is empty.');
    }
    late final String decoded;
    try {
      decoded = Uri.decodeComponent(encoded);
    } on ArgumentError catch (error) {
      throw FormatException('Malformed encoded canonical $kind: $error');
    }
    if (decoded.isEmpty || Uri.encodeComponent(decoded) != encoded) {
      throw FormatException('Encoded canonical $kind is not in canonical form.');
    }
    return decoded;
  }
}
