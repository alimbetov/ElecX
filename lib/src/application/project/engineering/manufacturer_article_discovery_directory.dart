/// Reference-only identity directory based on official manufacturer pages.
/// An article record is NOT a reviewed coordination table, does not attest a
/// PDF content hash and can never qualify a project safety gate by itself.
final class ManufacturerArticleDiscoveryRecord {
  const ManufacturerArticleDiscoveryRecord({
    required this.manufacturerId,
    required this.articleNumber,
    required this.deviceKind,
    required this.productFamily,
    required this.poleCount,
    required this.ratedCurrentA,
    required this.officialProductUrl,
    this.tripCurve,
    this.residualType,
    this.ratedResidualCurrentMa,
  });

  final String manufacturerId;
  final String articleNumber;
  final String deviceKind;
  final String productFamily;
  final int poleCount;
  final double ratedCurrentA;
  final String officialProductUrl;
  final String? tripCurve;
  final String? residualType;
  final double? ratedResidualCurrentMa;

  /// Deliberately cannot be mistaken for approved engineering evidence.
  bool get isManufacturerCoordinationQualified => false;
}

/// Official product identity is separated from independently reviewed
/// manufacturer coordination and installation suitability.
abstract final class ManufacturerArticleDiscoveryDirectory {
  static const acti9Ic60n16aC = ManufacturerArticleDiscoveryRecord(
    manufacturerId: 'Schneider Electric',
    articleNumber: 'A9F74116',
    deviceKind: 'mcb',
    productFamily: 'Acti9 iC60N',
    poleCount: 1,
    ratedCurrentA: 16,
    tripCurve: 'C',
    officialProductUrl:
        'https://www.se.com/sg/en/product/A9F74116/ic60n-miniature-circuit-breaker-1p-16a-c-curve/',
  );

  static const acti9Iid40a30maAc = ManufacturerArticleDiscoveryRecord(
    manufacturerId: 'Schneider Electric',
    articleNumber: 'A9R11240',
    deviceKind: 'rcd',
    productFamily: 'Acti9 iID',
    poleCount: 2,
    ratedCurrentA: 40,
    residualType: 'AC',
    ratedResidualCurrentMa: 30,
    officialProductUrl:
        'https://www.se.com/ae/en/product/A9R11240/residual-current-circuit-breaker-rccb-acti9-iid-2p-40a-ac-type-30ma/',
  );

  static const articles = [
    acti9Ic60n16aC,
    acti9Iid40a30maAc,
  ];
}
