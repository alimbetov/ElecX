import 'package:drift/drift.dart';

import '../domain/component_catalog_v2.dart';
import '../domain/engineering_graph.dart';
import '../domain/room_environment.dart';
import '../domain/surfaces.dart';
import 'component_catalog_repository.dart';

/// Drift-backed catalog repository using runtime SQL deliberately.
///
/// This keeps the domain independent from generated Drift table classes while
/// the schema is still evolving. The repository boundary can later switch to
/// generated tables without changing editor/cursor consumers.
final class DriftComponentCatalogRepository
    implements ComponentCatalogRepository {
  DriftComponentCatalogRepository(this._db);

  final GeneratedDatabase _db;

  Future<void> ensureSchema() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS component_type (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        discipline TEXT NOT NULL,
        system_class TEXT NOT NULL,
        calculation_kind TEXT NOT NULL,
        route_preference_id TEXT,
        preferred_height_mm INTEGER,
        preferred_ceiling_offset_mm INTEGER,
        min_ambient_c REAL NOT NULL,
        max_ambient_c REAL NOT NULL,
        max_relative_humidity_percent REAL NOT NULL,
        allow_wet_zone INTEGER NOT NULL,
        allow_dusty INTEGER NOT NULL,
        allow_corrosive INTEGER NOT NULL,
        rated_power_w INTEGER,
        nominal_voltage_v INTEGER,
        power_factor REAL NOT NULL,
        poe_class TEXT
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS component_type_allowed_surface (
        component_type_id TEXT NOT NULL REFERENCES component_type(id) ON DELETE CASCADE,
        surface_type TEXT NOT NULL,
        PRIMARY KEY(component_type_id, surface_type)
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS component_type_allowed_room_usage (
        component_type_id TEXT NOT NULL REFERENCES component_type(id) ON DELETE CASCADE,
        room_usage_type TEXT NOT NULL,
        PRIMARY KEY(component_type_id, room_usage_type)
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS component_type_port (
        id TEXT PRIMARY KEY,
        component_type_id TEXT NOT NULL REFERENCES component_type(id) ON DELETE CASCADE,
        code TEXT NOT NULL,
        direction TEXT NOT NULL,
        UNIQUE(component_type_id, code)
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS component_port_connection_type (
        component_type_port_id TEXT NOT NULL REFERENCES component_type_port(id) ON DELETE CASCADE,
        connection_type TEXT NOT NULL,
        PRIMARY KEY(component_type_port_id, connection_type)
      )
    ''');
  }

  Future<void> seedDefaultsIfEmpty() async {
    await ensureSchema();
    final countRow = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM component_type',
        )
        .getSingle();
    if (countRow.read<int>('c') == 0) {
      await replaceAll(ComponentCatalogV2.entries);
    }
  }

  @override
  Future<List<ComponentCatalogEntryV2>> all() async {
    await ensureSchema();
    final rows = await _db
        .customSelect(
          'SELECT * FROM component_type ORDER BY discipline, name',
        )
        .get();
    final result = <ComponentCatalogEntryV2>[];
    for (final row in rows) {
      result.add(await _mapEntry(row));
    }
    return List.unmodifiable(result);
  }

  @override
  Future<ComponentCatalogEntryV2?> byId(String id) async {
    await ensureSchema();
    final rows = await _db.customSelect(
      'SELECT * FROM component_type WHERE id = ? LIMIT 1',
      variables: [Variable<String>(id)],
    ).get();
    if (rows.isEmpty) return null;
    return _mapEntry(rows.single);
  }

  @override
  Future<List<ComponentCatalogEntryV2>> forSurface(
    SurfacePlaneType surface,
  ) async {
    await ensureSchema();
    final rows = await _db.customSelect(
      '''
      SELECT ct.*
      FROM component_type ct
      JOIN component_type_allowed_surface s ON s.component_type_id = ct.id
      WHERE s.surface_type = ?
      ORDER BY ct.discipline, ct.name
      ''',
      variables: [Variable<String>(surface.name)],
    ).get();
    final result = <ComponentCatalogEntryV2>[];
    for (final row in rows) {
      result.add(await _mapEntry(row));
    }
    return List.unmodifiable(result);
  }

  @override
  Future<List<ComponentCatalogEntryV2>> forSystem(
    EngineeringSystemClass systemClass,
  ) async {
    await ensureSchema();
    final rows = await _db.customSelect(
      'SELECT * FROM component_type WHERE system_class = ? ORDER BY name',
      variables: [Variable<String>(systemClass.name)],
    ).get();
    final result = <ComponentCatalogEntryV2>[];
    for (final row in rows) {
      result.add(await _mapEntry(row));
    }
    return List.unmodifiable(result);
  }

  @override
  Future<void> replaceAll(Iterable<ComponentCatalogEntryV2> entries) async {
    await ensureSchema();
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM component_port_connection_type');
      await _db.customStatement('DELETE FROM component_type_port');
      await _db
          .customStatement('DELETE FROM component_type_allowed_room_usage');
      await _db.customStatement('DELETE FROM component_type_allowed_surface');
      await _db.customStatement('DELETE FROM component_type');

      for (final entry in entries) {
        await _insertEntry(entry);
      }
    });
  }

  Future<void> _insertEntry(ComponentCatalogEntryV2 entry) async {
    final env = entry.environment;
    final load = entry.loadDefaults;
    await _db.customStatement(
      '''
      INSERT INTO component_type (
        id, code, name, discipline, system_class, calculation_kind,
        route_preference_id, preferred_height_mm, preferred_ceiling_offset_mm,
        min_ambient_c, max_ambient_c, max_relative_humidity_percent,
        allow_wet_zone, allow_dusty, allow_corrosive,
        rated_power_w, nominal_voltage_v, power_factor, poe_class
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        entry.id,
        entry.code,
        entry.name,
        entry.discipline.name,
        entry.systemClass.name,
        entry.calculationKind.name,
        entry.routePreferenceId,
        entry.mounting.preferredHeightMm,
        entry.mounting.preferredCeilingOffsetMm,
        env.minAmbientC,
        env.maxAmbientC,
        env.maxRelativeHumidityPercent,
        env.allowWetZone ? 1 : 0,
        env.allowDusty ? 1 : 0,
        env.allowCorrosive ? 1 : 0,
        load.ratedPowerW,
        load.nominalVoltageV,
        load.powerFactor,
        load.poeClass,
      ],
    );

    for (final surface in entry.mounting.allowedSurfaces) {
      await _db.customStatement(
        'INSERT INTO component_type_allowed_surface VALUES (?, ?)',
        [entry.id, surface.name],
      );
    }
    for (final usage in env.allowedUsageTypes ?? const <RoomUsageType>{}) {
      await _db.customStatement(
        'INSERT INTO component_type_allowed_room_usage VALUES (?, ?)',
        [entry.id, usage.name],
      );
    }
    for (final port in entry.ports) {
      final portRowId = '${entry.id}:${port.id}';
      await _db.customStatement(
        'INSERT INTO component_type_port (id, component_type_id, code, direction) VALUES (?, ?, ?, ?)',
        [portRowId, entry.id, port.id, port.direction.name],
      );
      for (final connection in port.allowedConnections) {
        await _db.customStatement(
          'INSERT INTO component_port_connection_type VALUES (?, ?)',
          [portRowId, connection.name],
        );
      }
    }
  }

  Future<ComponentCatalogEntryV2> _mapEntry(QueryRow row) async {
    final id = row.read<String>('id');
    final surfaceRows = await _db.customSelect(
      'SELECT surface_type FROM component_type_allowed_surface WHERE component_type_id = ?',
      variables: [Variable<String>(id)],
    ).get();
    final usageRows = await _db.customSelect(
      'SELECT room_usage_type FROM component_type_allowed_room_usage WHERE component_type_id = ?',
      variables: [Variable<String>(id)],
    ).get();
    final portRows = await _db.customSelect(
      'SELECT id, code, direction FROM component_type_port WHERE component_type_id = ? ORDER BY code',
      variables: [Variable<String>(id)],
    ).get();

    final ports = <EngineeringPortSpec>[];
    for (final portRow in portRows) {
      final portRowId = portRow.read<String>('id');
      final connectionRows = await _db.customSelect(
        'SELECT connection_type FROM component_port_connection_type WHERE component_type_port_id = ?',
        variables: [Variable<String>(portRowId)],
      ).get();
      ports.add(
        EngineeringPortSpec(
          id: portRow.read<String>('code'),
          direction: _enumByName(
            EngineeringPortDirection.values,
            portRow.read<String>('direction'),
          ),
          allowedConnections: connectionRows
              .map(
                (r) => _enumByName(
                  EngineeringConnectionType.values,
                  r.read<String>('connection_type'),
                ),
              )
              .toSet(),
        ),
      );
    }

    final usageTypes = usageRows
        .map(
          (r) => _enumByName(
            RoomUsageType.values,
            r.read<String>('room_usage_type'),
          ),
        )
        .toSet();

    return ComponentCatalogEntryV2(
      id: id,
      code: row.read<String>('code'),
      name: row.read<String>('name'),
      discipline: _enumByName(
        EngineeringDiscipline.values,
        row.read<String>('discipline'),
      ),
      systemClass: _enumByName(
        EngineeringSystemClass.values,
        row.read<String>('system_class'),
      ),
      calculationKind: _enumByName(
        EngineeringCalculationKind.values,
        row.read<String>('calculation_kind'),
      ),
      mounting: ComponentMountingPolicy(
        allowedSurfaces: surfaceRows
            .map(
              (r) => _enumByName(
                SurfacePlaneType.values,
                r.read<String>('surface_type'),
              ),
            )
            .toSet(),
        preferredHeightMm: row.readNullable<int>('preferred_height_mm'),
        preferredCeilingOffsetMm:
            row.readNullable<int>('preferred_ceiling_offset_mm'),
      ),
      environment: ComponentEnvironmentConstraints(
        minAmbientC: row.read<double>('min_ambient_c'),
        maxAmbientC: row.read<double>('max_ambient_c'),
        maxRelativeHumidityPercent:
            row.read<double>('max_relative_humidity_percent'),
        allowWetZone: row.read<int>('allow_wet_zone') == 1,
        allowDusty: row.read<int>('allow_dusty') == 1,
        allowCorrosive: row.read<int>('allow_corrosive') == 1,
        allowedUsageTypes: usageTypes.isEmpty ? null : usageTypes,
      ),
      ports: ports,
      loadDefaults: ComponentLoadDefaults(
        ratedPowerW: row.readNullable<int>('rated_power_w'),
        nominalVoltageV: row.readNullable<int>('nominal_voltage_v'),
        powerFactor: row.read<double>('power_factor'),
        poeClass: row.readNullable<String>('poe_class'),
      ),
      routePreferenceId: row.readNullable<String>('route_preference_id'),
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String name) => values.firstWhere(
      (value) => value.name == name,
      orElse: () => throw StateError('Unknown enum value $name for $T'),
    );
