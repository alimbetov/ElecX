import 'package:flutter/foundation.dart';

import '../../data/component_catalog_repository.dart';
import '../../domain/component_catalog_v2.dart';
import '../../domain/engineering_graph.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';

final class ComponentCatalogSession extends ChangeNotifier {
  ComponentCatalogSession(this.repository);

  final ComponentCatalogRepository repository;
  final Map<String, ComponentCatalogEntryV2> _entries = {};

  bool _loaded = false;
  bool _loading = false;
  Object? _loadError;

  bool get loaded => _loaded;
  bool get loading => _loading;
  Object? get loadError => _loadError;
  List<ComponentCatalogEntryV2> get entries =>
      List.unmodifiable(_entries.values);

  ComponentCatalogEntryV2? byId(String id) => _entries[id];

  ComponentCatalogEntryV2 require(String id) {
    final entry = byId(id);
    if (entry == null) {
      throw ArgumentError.value(id, 'id', 'Unknown component catalog entry.');
    }
    return entry;
  }

  List<ComponentCatalogEntryV2> forSurface(SurfacePlaneType type) => entries
      .where((entry) => entry.mounting.allowedSurfaces.contains(type))
      .toList(growable: false);

  List<ComponentCatalogEntryV2> forSystem(EngineeringSystemClass systemClass) =>
      entries
          .where((entry) => entry.systemClass == systemClass)
          .toList(growable: false);

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      final loadedEntries = await repository.all();
      _entries
        ..clear()
        ..addEntries(loadedEntries.map((entry) => MapEntry(entry.id, entry)));
      _loaded = true;
    } catch (error) {
      _loadError = error;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void seedSynchronously(Iterable<ComponentCatalogEntryV2> entries) {
    _entries
      ..clear()
      ..addEntries(entries.map((entry) => MapEntry(entry.id, entry)));
    _loaded = true;
    _loadError = null;
  }
}

final Expando<ComponentCatalogSession> _catalogSessions =
    Expando<ComponentCatalogSession>('ElecX component catalog session');

extension ComponentCatalogSessionAccess on EditorController {
  ComponentCatalogSession get componentCatalog {
    final existing = _catalogSessions[this];
    if (existing != null) return existing;
    final session = ComponentCatalogSession(
      InMemoryComponentCatalogRepository(ComponentCatalogV2.entries),
    )..seedSynchronously(ComponentCatalogV2.entries);
    _catalogSessions[this] = session;
    return session;
  }

  void attachComponentCatalogRepository(ComponentCatalogRepository repository) {
    final session = ComponentCatalogSession(repository);
    _catalogSessions[this] = session;
  }
}
