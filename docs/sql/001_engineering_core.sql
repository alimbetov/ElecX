PRAGMA foreign_keys = ON;

CREATE TABLE project (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE site (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    latitude REAL,
    longitude REAL,
    altitude_m REAL,
    climate_profile_id TEXT,
    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE TABLE building (
    id TEXT PRIMARY KEY,
    site_id TEXT NOT NULL REFERENCES site(id) ON DELETE CASCADE,
    name TEXT NOT NULL
);

CREATE TABLE building_level (
    id TEXT PRIMARY KEY,
    building_id TEXT NOT NULL REFERENCES building(id) ON DELETE CASCADE,
    level_number INTEGER NOT NULL,
    name TEXT NOT NULL,
    elevation_mm INTEGER NOT NULL,
    UNIQUE(building_id, level_number)
);

CREATE TABLE room (
    id TEXT PRIMARY KEY,
    level_id TEXT NOT NULL REFERENCES building_level(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    space_type TEXT NOT NULL,
    local_origin_x_mm INTEGER NOT NULL DEFAULT 0,
    local_origin_y_mm INTEGER NOT NULL DEFAULT 0,
    rotation_microrad INTEGER NOT NULL DEFAULT 0,
    grid_minor_step_mm INTEGER NOT NULL DEFAULT 100 CHECK (grid_minor_step_mm > 0)
);

CREATE TABLE room_environment (
    room_id TEXT PRIMARY KEY REFERENCES room(id) ON DELETE CASCADE,
    usage_type TEXT NOT NULL,
    temperature_regime TEXT NOT NULL,
    design_min_c REAL NOT NULL,
    design_max_c REAL NOT NULL,
    design_nominal_c REAL,
    max_relative_humidity_percent REAL,
    wet_zone INTEGER NOT NULL DEFAULT 0 CHECK (wet_zone IN (0, 1)),
    dusty INTEGER NOT NULL DEFAULT 0 CHECK (dusty IN (0, 1)),
    corrosive INTEGER NOT NULL DEFAULT 0 CHECK (corrosive IN (0, 1)),
    CHECK (design_min_c <= design_max_c),
    CHECK (design_nominal_c IS NULL OR design_nominal_c BETWEEN design_min_c AND design_max_c),
    CHECK (max_relative_humidity_percent IS NULL OR max_relative_humidity_percent BETWEEN 0 AND 100)
);

CREATE TABLE room_environment_tag (
    room_id TEXT NOT NULL REFERENCES room(id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    PRIMARY KEY (room_id, tag)
);

CREATE TABLE room_boundary_vertex (
    room_id TEXT NOT NULL REFERENCES room(id) ON DELETE CASCADE,
    vertex_index INTEGER NOT NULL CHECK (vertex_index >= 0),
    x_mm INTEGER NOT NULL,
    y_mm INTEGER NOT NULL,
    PRIMARY KEY (room_id, vertex_index)
);

CREATE TABLE room_surface (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL REFERENCES room(id) ON DELETE CASCADE,
    surface_type TEXT NOT NULL CHECK (surface_type IN ('floor', 'ceiling', 'wall')),
    wall_index INTEGER,
    height_mm INTEGER,
    UNIQUE(room_id, surface_type, wall_index),
    CHECK ((surface_type = 'wall' AND wall_index IS NOT NULL) OR
           (surface_type <> 'wall' AND wall_index IS NULL))
);

CREATE TABLE wall_construction (
    surface_id TEXT PRIMARY KEY REFERENCES room_surface(id) ON DELETE CASCADE,
    thickness_mm INTEGER NOT NULL CHECK (thickness_mm > 0),
    construction_type_id TEXT,
    material_id TEXT
);

CREATE TABLE component_type (
    id TEXT PRIMARY KEY,
    discipline TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    default_power_w INTEGER,
    default_voltage_v INTEGER,
    metadata_json TEXT,
    CHECK (default_power_w IS NULL OR default_power_w >= 0),
    CHECK (default_voltage_v IS NULL OR default_voltage_v > 0)
);

CREATE TABLE component_type_port (
    id TEXT PRIMARY KEY,
    component_type_id TEXT NOT NULL REFERENCES component_type(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('input', 'output', 'bidirectional')),
    UNIQUE(component_type_id, code)
);

CREATE TABLE component_port_connection_type (
    component_type_port_id TEXT NOT NULL REFERENCES component_type_port(id) ON DELETE CASCADE,
    connection_type TEXT NOT NULL,
    PRIMARY KEY(component_type_port_id, connection_type)
);

CREATE TABLE engineering_component (
    id TEXT PRIMARY KEY,
    component_type_id TEXT NOT NULL REFERENCES component_type(id),
    room_id TEXT NOT NULL REFERENCES room(id) ON DELETE CASCADE,
    surface_id TEXT NOT NULL REFERENCES room_surface(id) ON DELETE CASCADE,
    local_x_mm INTEGER NOT NULL,
    local_y_mm INTEGER NOT NULL,
    rotation_mdeg INTEGER NOT NULL DEFAULT 0,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    rated_power_w INTEGER,
    voltage_v INTEGER,
    label TEXT NOT NULL,
    metadata_json TEXT,
    CHECK (rated_power_w IS NULL OR rated_power_w >= 0),
    CHECK (voltage_v IS NULL OR voltage_v > 0)
);

CREATE INDEX idx_component_room ON engineering_component(room_id);
CREATE INDEX idx_component_surface ON engineering_component(surface_id);
CREATE INDEX idx_component_type ON engineering_component(component_type_id);

CREATE TABLE engineering_component_port (
    id TEXT PRIMARY KEY,
    component_id TEXT NOT NULL REFERENCES engineering_component(id) ON DELETE CASCADE,
    type_port_id TEXT NOT NULL REFERENCES component_type_port(id),
    UNIQUE(component_id, type_port_id)
);

CREATE TABLE engineering_circuit (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    discipline TEXT NOT NULL,
    name TEXT NOT NULL,
    nominal_voltage_v INTEGER,
    phase_count INTEGER,
    demand_factor REAL NOT NULL DEFAULT 1.0,
    simultaneity_factor REAL NOT NULL DEFAULT 1.0,
    power_factor REAL NOT NULL DEFAULT 1.0,
    protective_device_type_id TEXT,
    protective_device_rating_a REAL,
    CHECK (demand_factor > 0 AND demand_factor <= 1),
    CHECK (simultaneity_factor > 0 AND simultaneity_factor <= 1),
    CHECK (power_factor > 0 AND power_factor <= 1)
);

CREATE TABLE engineering_connection (
    id TEXT PRIMARY KEY,
    circuit_id TEXT REFERENCES engineering_circuit(id) ON DELETE SET NULL,
    from_port_id TEXT NOT NULL REFERENCES engineering_component_port(id) ON DELETE CASCADE,
    to_port_id TEXT NOT NULL REFERENCES engineering_component_port(id) ON DELETE CASCADE,
    connection_type TEXT NOT NULL,
    route_id TEXT,
    CHECK (from_port_id <> to_port_id)
);

CREATE TABLE engineering_route (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    system_kind TEXT NOT NULL,
    cable_type_id TEXT,
    total_length_mm INTEGER NOT NULL DEFAULT 0 CHECK (total_length_mm >= 0)
);

CREATE TABLE engineering_route_segment (
    id TEXT PRIMARY KEY,
    route_id TEXT NOT NULL REFERENCES engineering_route(id) ON DELETE CASCADE,
    segment_index INTEGER NOT NULL CHECK (segment_index >= 0),
    surface_id TEXT NOT NULL REFERENCES room_surface(id),
    UNIQUE(route_id, segment_index)
);

CREATE TABLE engineering_route_point (
    segment_id TEXT NOT NULL REFERENCES engineering_route_segment(id) ON DELETE CASCADE,
    point_index INTEGER NOT NULL CHECK (point_index >= 0),
    local_x_mm INTEGER NOT NULL,
    local_y_mm INTEGER NOT NULL,
    PRIMARY KEY(segment_id, point_index)
);

CREATE TABLE cable_type (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    conductor_material_id TEXT NOT NULL,
    insulation_class_id TEXT NOT NULL,
    core_count INTEGER NOT NULL CHECK (core_count > 0),
    section_mm2 REAL NOT NULL CHECK (section_mm2 > 0),
    rated_voltage_v INTEGER,
    metadata_json TEXT
);

CREATE TABLE circuit_load_snapshot (
    id TEXT PRIMARY KEY,
    circuit_id TEXT NOT NULL REFERENCES engineering_circuit(id) ON DELETE CASCADE,
    connected_load_w REAL NOT NULL CHECK (connected_load_w >= 0),
    design_load_w REAL NOT NULL CHECK (design_load_w >= 0),
    design_current_a REAL NOT NULL CHECK (design_current_a >= 0),
    calculated_at_epoch_ms INTEGER NOT NULL
);

CREATE TABLE circuit_cable_sizing_snapshot (
    id TEXT PRIMARY KEY,
    circuit_id TEXT NOT NULL REFERENCES engineering_circuit(id) ON DELETE CASCADE,
    route_id TEXT REFERENCES engineering_route(id) ON DELETE SET NULL,
    cable_type_id TEXT NOT NULL REFERENCES cable_type(id),
    normative_profile_id TEXT NOT NULL,
    route_length_mm INTEGER NOT NULL CHECK (route_length_mm >= 0),
    ambient_temperature_c REAL NOT NULL,
    grouped_loaded_circuit_count INTEGER NOT NULL CHECK (grouped_loaded_circuit_count > 0),
    installation_method_id TEXT NOT NULL,
    design_current_a REAL NOT NULL CHECK (design_current_a >= 0),
    corrected_ampacity_a REAL NOT NULL CHECK (corrected_ampacity_a >= 0),
    voltage_drop_percent REAL NOT NULL CHECK (voltage_drop_percent >= 0),
    selected_section_mm2 REAL NOT NULL CHECK (selected_section_mm2 > 0),
    calculated_at_epoch_ms INTEGER NOT NULL
);

CREATE INDEX idx_connection_circuit ON engineering_connection(circuit_id);
CREATE INDEX idx_route_segment_route ON engineering_route_segment(route_id);
CREATE INDEX idx_sizing_circuit ON circuit_cable_sizing_snapshot(circuit_id);
