PRAGMA foreign_keys = ON;

ALTER TABLE component_type ADD COLUMN system_class TEXT;
ALTER TABLE component_type ADD COLUMN calculation_kind TEXT;

ALTER TABLE engineering_circuit ADD COLUMN system_class TEXT;
ALTER TABLE engineering_circuit ADD COLUMN calculation_kind TEXT;

ALTER TABLE engineering_connection ADD COLUMN system_class TEXT;

ALTER TABLE engineering_route ADD COLUMN calculation_kind TEXT;

CREATE TABLE engineering_validation_snapshot (
    id TEXT PRIMARY KEY,
    circuit_id TEXT REFERENCES engineering_circuit(id) ON DELETE CASCADE,
    route_id TEXT REFERENCES engineering_route(id) ON DELETE CASCADE,
    calculation_kind TEXT NOT NULL,
    normative_profile_id TEXT,
    status TEXT NOT NULL CHECK (status IN ('pass', 'warning', 'fail')),
    payload_json TEXT NOT NULL,
    calculated_at_epoch_ms INTEGER NOT NULL
);

CREATE INDEX idx_validation_circuit
    ON engineering_validation_snapshot(circuit_id, calculation_kind);

CREATE TABLE data_link_snapshot (
    id TEXT PRIMARY KEY,
    circuit_id TEXT NOT NULL REFERENCES engineering_circuit(id) ON DELETE CASCADE,
    route_id TEXT REFERENCES engineering_route(id) ON DELETE SET NULL,
    category_id TEXT,
    route_length_mm INTEGER NOT NULL CHECK (route_length_mm >= 0),
    permanent_link_length_mm INTEGER,
    channel_length_mm INTEGER,
    poe_class TEXT,
    source_power_w REAL,
    required_power_w REAL,
    voltage_at_device_v REAL,
    status TEXT NOT NULL CHECK (status IN ('pass', 'warning', 'fail')),
    calculated_at_epoch_ms INTEGER NOT NULL
);

CREATE TABLE fiber_link_snapshot (
    id TEXT PRIMARY KEY,
    circuit_id TEXT NOT NULL REFERENCES engineering_circuit(id) ON DELETE CASCADE,
    route_id TEXT REFERENCES engineering_route(id) ON DELETE SET NULL,
    fiber_type_id TEXT NOT NULL,
    route_length_mm INTEGER NOT NULL CHECK (route_length_mm >= 0),
    source_budget_db REAL,
    cable_loss_db REAL,
    connector_loss_db REAL,
    splice_loss_db REAL,
    reserve_db REAL,
    remaining_margin_db REAL,
    status TEXT NOT NULL CHECK (status IN ('pass', 'warning', 'fail')),
    calculated_at_epoch_ms INTEGER NOT NULL
);

CREATE TABLE dc_link_snapshot (
    id TEXT PRIMARY KEY,
    circuit_id TEXT NOT NULL REFERENCES engineering_circuit(id) ON DELETE CASCADE,
    route_id TEXT REFERENCES engineering_route(id) ON DELETE SET NULL,
    nominal_voltage_v REAL NOT NULL CHECK (nominal_voltage_v > 0),
    load_current_a REAL NOT NULL CHECK (load_current_a >= 0),
    route_length_mm INTEGER NOT NULL CHECK (route_length_mm >= 0),
    conductor_section_mm2 REAL,
    voltage_drop_v REAL,
    voltage_drop_percent REAL,
    voltage_at_load_v REAL,
    status TEXT NOT NULL CHECK (status IN ('pass', 'warning', 'fail')),
    calculated_at_epoch_ms INTEGER NOT NULL
);

CREATE TABLE fire_loop_snapshot (
    id TEXT PRIMARY KEY,
    circuit_id TEXT NOT NULL REFERENCES engineering_circuit(id) ON DELETE CASCADE,
    route_id TEXT REFERENCES engineering_route(id) ON DELETE SET NULL,
    topology_kind TEXT NOT NULL,
    node_count INTEGER NOT NULL CHECK (node_count >= 0),
    route_length_mm INTEGER NOT NULL CHECK (route_length_mm >= 0),
    loop_resistance_ohm REAL,
    end_voltage_v REAL,
    isolator_count INTEGER,
    status TEXT NOT NULL CHECK (status IN ('pass', 'warning', 'fail')),
    calculated_at_epoch_ms INTEGER NOT NULL
);
