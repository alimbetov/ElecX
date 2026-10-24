import '../../domain/project_identity.dart';

/// Versioned transitional identity codec used only while the canonical project
/// is materialized into the legacy single-building editor document.
///
/// Old legacy level ids remain untouched and keep their deterministic bootstrap
/// migration. Newly materialized canonical Levels receive an encoded legacy id
/// that round-trips the exact [LevelId] across save/reopen.
abstract final class CanonicalLegacyIdentityCodec {
  static const String levelPrefix = 'elecx-canonical-level-v1:';

  static bool isEncodedLevelId(String legacyId) =>
      legacyId.startsWith(levelPrefix);

  static String encodeLevelId(LevelId levelId) {
    if (levelId.value.isEmpty) {
      throw ArgumentError.value(levelId.value, 'levelId', 'Must be non-empty.');
    }
    return '$levelPrefix${Uri.encodeComponent(levelId.value)}';
  }

  /// Returns null for an ordinary pre-P8 legacy id.
  ///
  /// A value carrying the P8 prefix is considered authoritative bridge data;
  /// malformed or non-canonical encoding therefore fails closed instead of
  /// falling back to a derived identity.
  static LevelId? tryDecodeLevelId(String legacyId) {
    if (!isEncodedLevelId(legacyId)) return null;
    final encoded = legacyId.substring(levelPrefix.length);
    if (encoded.isEmpty) {
      throw const FormatException('Encoded canonical LevelId is empty.');
    }
    late final String decoded;
    try {
      decoded = Uri.decodeComponent(encoded);
    } on ArgumentError catch (error) {
      throw FormatException('Malformed encoded canonical LevelId: $error');
    }
    if (decoded.isEmpty || Uri.encodeComponent(decoded) != encoded) {
      throw const FormatException(
        'Encoded canonical LevelId is not in canonical form.',
      );
    }
    return LevelId(decoded);
  }
}
