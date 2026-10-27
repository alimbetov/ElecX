import 'p9_canonical_serialization.dart';
import 'p9_sha256.dart';

const String apartmentVerifiedProductCatalogSchemaVersion =
    'p9.product-catalog.v1';

enum ApartmentEquipmentProductKind {
  circuitBreaker,
  rcbo,
  cable,
  distributionBoard,
}

/// Source-pinned price used only after engineering and normative eligibility.
final class ApartmentVerifiedPrice {
  ApartmentVerifiedPrice({
    required this.amountMinor,
    required this.currencyCode,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (amountMinor < 0 ||
        !_isCurrencyCode(currencyCode) ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError('P9.5-B price evidence is invalid.');
    }
  }

  final int amountMinor;
  final String currencyCode;
  final String sourceId;
  final String sourceRevision;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('amountMinor', amountMinor.toString()),
        MapEntry('currencyCode', currencyCode),
        MapEntry('sourceId', sourceId),
        MapEntry('sourceRevision', sourceRevision),
      ]);

  String get evidenceFingerprint => p9Sha256Hex(stableSerialization);
}

/// Product-level declaration that a variant is verified for the exact
/// normative profile consumed by P9.4/P9.5.
final class ApartmentProductNormativeDeclaration {
  ApartmentProductNormativeDeclaration({
    required this.declarationId,
    required this.profileId,
    required this.profileVersion,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (declarationId.trim().isEmpty ||
        profileId.trim().isEmpty ||
        profileVersion.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError('P9.5-B normative declaration is invalid.');
    }
  }

  final String declarationId;
  final String profileId;
  final String profileVersion;
  final String sourceId;
  final String sourceRevision;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('declarationId', declarationId),
        MapEntry('profileId', profileId),
        MapEntry('profileVersion', profileVersion),
        MapEntry('sourceId', sourceId),
        MapEntry('sourceRevision', sourceRevision),
      ]);

  String get evidenceFingerprint => p9Sha256Hex(stableSerialization);
}

/// Strongly typed ratings for the first P9 equipment auto-configuration slice.
///
/// Fields are intentionally explicit instead of a dynamic attribute map. The
/// variant constructor validates which ratings are mandatory for each product
/// kind, so missing engineering data fails closed.
final class ApartmentEquipmentTechnicalRatings {
  const ApartmentEquipmentTechnicalRatings({
    this.ratedVoltageV,
    this.ratedCurrentA,
    this.breakingCapacityKA,
    this.residualCurrentMA,
    this.poleCount,
    this.moduleWidth,
    this.conductorCrossSectionMm2,
    this.currentCapacityA,
    this.supportedPhaseCount,
    this.moduleCapacity,
  });

  final double? ratedVoltageV;
  final double? ratedCurrentA;
  final double? breakingCapacityKA;
  final double? residualCurrentMA;
  final int? poleCount;
  final int? moduleWidth;
  final double? conductorCrossSectionMm2;
  final double? currentCapacityA;
  final int? supportedPhaseCount;
  final int? moduleCapacity;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('ratedVoltageV', _canonicalDouble(ratedVoltageV)),
        MapEntry('ratedCurrentA', _canonicalDouble(ratedCurrentA)),
        MapEntry('breakingCapacityKA', _canonicalDouble(breakingCapacityKA)),
        MapEntry('residualCurrentMA', _canonicalDouble(residualCurrentMA)),
        MapEntry('poleCount', poleCount?.toString() ?? ''),
        MapEntry('moduleWidth', moduleWidth?.toString() ?? ''),
        MapEntry(
          'conductorCrossSectionMm2',
          _canonicalDouble(conductorCrossSectionMm2),
        ),
        MapEntry('currentCapacityA', _canonicalDouble(currentCapacityA)),
        MapEntry(
          'supportedPhaseCount',
          supportedPhaseCount?.toString() ?? '',
        ),
        MapEntry('moduleCapacity', moduleCapacity?.toString() ?? ''),
      ]);
}

final class ApartmentVerifiedProductVariant {
  ApartmentVerifiedProductVariant({
    required this.variantId,
    required this.manufacturer,
    required this.model,
    required this.kind,
    required this.ratings,
    required this.technicalSourceId,
    required this.technicalSourceRevision,
    required this.price,
    Iterable<ApartmentProductNormativeDeclaration> normativeDeclarations =
        const [],
  }) : normativeDeclarations = List.unmodifiable(
          normativeDeclarations.toList()
            ..sort(
              (left, right) =>
                  left.stableSerialization.compareTo(right.stableSerialization),
            ),
        ) {
    if (variantId.trim().isEmpty ||
        manufacturer.trim().isEmpty ||
        model.trim().isEmpty ||
        technicalSourceId.trim().isEmpty ||
        technicalSourceRevision.trim().isEmpty) {
      throw ArgumentError('P9.5-B product identity/source is invalid.');
    }
    _validateRatings(kind: kind, ratings: ratings);
  }

  final String variantId;
  final String manufacturer;
  final String model;
  final ApartmentEquipmentProductKind kind;
  final ApartmentEquipmentTechnicalRatings ratings;
  final String technicalSourceId;
  final String technicalSourceRevision;
  final ApartmentVerifiedPrice price;
  final List<ApartmentProductNormativeDeclaration> normativeDeclarations;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('variantId', variantId),
        MapEntry('manufacturer', manufacturer),
        MapEntry('model', model),
        MapEntry('kind', kind.name),
        MapEntry('ratings', ratings.stableSerialization),
        MapEntry('technicalSourceId', technicalSourceId),
        MapEntry('technicalSourceRevision', technicalSourceRevision),
        MapEntry('price', price.stableSerialization),
        for (final declaration in normativeDeclarations)
          MapEntry('normativeDeclaration', declaration.stableSerialization),
      ]);

  String get variantFingerprint => p9Sha256Hex(stableSerialization);
}

/// Immutable P9.5-B catalog snapshot.
///
/// The snapshot is revision-pinned and currency-homogeneous so deterministic
/// ranking never compares nominal amounts in different currencies.
final class ApartmentVerifiedProductVariantCatalog {
  ApartmentVerifiedProductVariantCatalog({
    required this.catalogId,
    required this.catalogRevision,
    required this.sourceId,
    required this.sourceRevision,
    required this.currencyCode,
    required Iterable<ApartmentVerifiedProductVariant> variants,
    this.schemaVersion = apartmentVerifiedProductCatalogSchemaVersion,
  }) : variants = List.unmodifiable(
          variants.toList()
            ..sort((left, right) => left.variantId.compareTo(right.variantId)),
        ) {
    if (schemaVersion.trim().isEmpty ||
        catalogId.trim().isEmpty ||
        catalogRevision.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty ||
        !_isCurrencyCode(currencyCode)) {
      throw ArgumentError('P9.5-B catalog identity/source is invalid.');
    }
    if (this.variants.isEmpty) {
      throw ArgumentError('P9.5-B catalog must contain product variants.');
    }
    final ids = <String>{};
    for (final variant in this.variants) {
      if (!ids.add(variant.variantId)) {
        throw ArgumentError(
          'Duplicate P9.5-B product variant ${variant.variantId}.',
        );
      }
      if (variant.price.currencyCode != currencyCode) {
        throw ArgumentError(
          'P9.5-B catalog currency mismatch for ${variant.variantId}.',
        );
      }
    }
  }

  final String schemaVersion;
  final String catalogId;
  final String catalogRevision;
  final String sourceId;
  final String sourceRevision;
  final String currencyCode;
  final List<ApartmentVerifiedProductVariant> variants;

  Iterable<ApartmentVerifiedProductVariant> variantsOfKind(
    ApartmentEquipmentProductKind kind,
  ) =>
      variants.where((variant) => variant.kind == kind);

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('schemaVersion', schemaVersion),
        MapEntry('catalogId', catalogId),
        MapEntry('catalogRevision', catalogRevision),
        MapEntry('sourceId', sourceId),
        MapEntry('sourceRevision', sourceRevision),
        MapEntry('currencyCode', currencyCode),
        for (final variant in variants)
          MapEntry('variant', variant.stableSerialization),
      ]);

  String get catalogFingerprint => p9Sha256Hex(stableSerialization);
}

void _validateRatings({
  required ApartmentEquipmentProductKind kind,
  required ApartmentEquipmentTechnicalRatings ratings,
}) {
  switch (kind) {
    case ApartmentEquipmentProductKind.circuitBreaker:
      _requirePositive(ratings.ratedVoltageV, 'ratedVoltageV');
      _requirePositive(ratings.ratedCurrentA, 'ratedCurrentA');
      _requirePositive(ratings.breakingCapacityKA, 'breakingCapacityKA');
      _requirePositiveInt(ratings.poleCount, 'poleCount');
      _requirePositiveInt(ratings.moduleWidth, 'moduleWidth');
      break;
    case ApartmentEquipmentProductKind.rcbo:
      _requirePositive(ratings.ratedVoltageV, 'ratedVoltageV');
      _requirePositive(ratings.ratedCurrentA, 'ratedCurrentA');
      _requirePositive(ratings.breakingCapacityKA, 'breakingCapacityKA');
      _requirePositive(ratings.residualCurrentMA, 'residualCurrentMA');
      _requirePositiveInt(ratings.poleCount, 'poleCount');
      _requirePositiveInt(ratings.moduleWidth, 'moduleWidth');
      break;
    case ApartmentEquipmentProductKind.cable:
      _requirePositive(
        ratings.conductorCrossSectionMm2,
        'conductorCrossSectionMm2',
      );
      _requirePositive(ratings.currentCapacityA, 'currentCapacityA');
      break;
    case ApartmentEquipmentProductKind.distributionBoard:
      _requirePositiveInt(ratings.supportedPhaseCount, 'supportedPhaseCount');
      _requirePositiveInt(ratings.moduleCapacity, 'moduleCapacity');
      break;
  }
}

void _requirePositive(double? value, String field) {
  if (value == null || !value.isFinite || value <= 0) {
    throw ArgumentError('P9.5-B $field must be finite and positive.');
  }
}

void _requirePositiveInt(int? value, String field) {
  if (value == null || value <= 0) {
    throw ArgumentError('P9.5-B $field must be positive.');
  }
}

String _canonicalDouble(double? value) => value == null ? '' : value.toString();

bool _isCurrencyCode(String value) =>
    RegExp(r'^[A-Z]{3}$').hasMatch(value.trim());
