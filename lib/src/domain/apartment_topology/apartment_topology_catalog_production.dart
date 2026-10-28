import 'apartment_topology_catalog.dart';
import 'apartment_topology_catalog_v4.dart';

/// Single production entry point for the apartment topology catalog.
///
/// Historical versioned catalogs remain available for migration/regression
/// fixtures only. Runtime generation and qualification must use this entry point
/// so tests do not accidentally validate a stale catalog version.
abstract final class P9ProductionApartmentTopologyCatalog {
  static ApartmentTopologyCatalog create() =>
      P9ApartmentTopologyCatalogV4.create();
}
