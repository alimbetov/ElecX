import '../domain/component_catalog_v2.dart';
import '../domain/engineering_graph.dart';
import '../domain/surfaces.dart';

abstract interface class ComponentCatalogRepository {
  Future<List<ComponentCatalogEntryV2>> all();

  Future<ComponentCatalogEntryV2?> byId(String id);

  Future<List<ComponentCatalogEntryV2>> forSurface(SurfacePlaneType surface);

  Future<List<ComponentCatalogEntryV2>> forSystem(
    EngineeringSystemClass systemClass,
  );

  Future<void> replaceAll(Iterable<ComponentCatalogEntryV2> entries);
}

final class InMemoryComponentCatalogRepository
    implements ComponentCatalogRepository {
  InMemoryComponentCatalogRepository([Iterable<ComponentCatalogEntryV2>? seed])
    : _entries = {
        for (final entry in seed ?? ComponentCatalogV2.entries) entry.id: entry,
      };

  final Map<String, ComponentCatalogEntryV2> _entries;

  @override
  Future<List<ComponentCatalogEntryV2>> all() async =>
      List.unmodifiable(_entries.values);

  @override
  Future<ComponentCatalogEntryV2?> byId(String id) async => _entries[id];

  @override
  Future<List<ComponentCatalogEntryV2>> forSurface(
    SurfacePlaneType surface,
  ) async => List.unmodifiable(
    _entries.values.where(
      (entry) => entry.mounting.allowedSurfaces.contains(surface),
    ),
  );

  @override
  Future<List<ComponentCatalogEntryV2>> forSystem(
    EngineeringSystemClass systemClass,
  ) async => List.unmodifiable(
    _entries.values.where((entry) => entry.systemClass == systemClass),
  );

  @override
  Future<void> replaceAll(Iterable<ComponentCatalogEntryV2> entries) async {
    _entries
      ..clear()
      ..addEntries(entries.map((entry) => MapEntry(entry.id, entry)));
  }
}
