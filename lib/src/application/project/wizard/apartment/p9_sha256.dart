import '../../../../domain/semantic_sha256.dart';

/// Compatibility entry point for the existing P9 fingerprint contract.
String p9Sha256Hex(String value) => semanticSha256Hex(value);
