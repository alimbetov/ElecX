PRAGMA foreign_keys = ON;

ALTER TABLE component_type ADD COLUMN system_class TEXT;
ALTER TABLE component_type ADD COLUMN calculation_kind TEXT;
ALTER TABLE component_type ADD COLUMN route_preference_id TEXT;
ALTER TABLE component_type ADD COLUMN min_ambient_c REAL;
ALTER TABLE component_type ADD COLUMN max_ambient_c REAL;
ALTER TABLE component_type ADD COLUMN max_relative_humidity_percent REAL;
ALTER TABLE component_type ADD COLUMN allow_wet_zone INTEGER NOT NULL DEFAULT 1 CHECK (allow_wet_zone IN (0, 1));
ALTER TABLE component_type ADD COLUMN allow_dusty INTEGER NOT NULL DEFAULT 1 CHECK (allow_dusty IN (0, 1));
ALTER TABLE component_type ADD COLUMN allow_corrosive INTEGER NOT NULL DEFAULT 0 CHECK (allow_corrosive IN (0, 1));
ALTER TABLE component_type ADD COLUMN preferred_height_mm INTEGER;
ALTER TABLE component_type ADD COLUMN preferred_ceiling_offset_mm INTEGER;
ALTER TABLE component_type ADD COLUMN default_power_factor REAL;
ALTER TABLE component_type ADD COLUMN default_poe_class TEXT;

CREATE TABLE component_type_allowed_surface (
    component_type_id TEXT NOT NULL REFERENCES component_type(id) ON DELETE CASCADE,
    surface_type TEXT NOT NULL CHECK (surface_type IN ('floor', 'ceiling', 'wall')),
    PRIMARY KEY (component_type_id, surface_type)
);

CREATE TABLE component_type_allowed_room_usage (
    component_type_id TEXT NOT NULL REFERENCES component_type(id) ON DELETE CASCADE,
    room_usage_type TEXT NOT NULL,
    PRIMARY KEY (component_type_id, room_usage_type)
);

CREATE TABLE component_type_required_environment_tag (
    component_type_id TEXT NOT NULL REFERENCES component_type(id) ON DELETE CASCADE,
    environment_tag TEXT NOT NULL,
    PRIMARY KEY (component_type_id, environment_tag)
);

CREATE TABLE component_type_forbidden_environment_tag (
    component_type_id TEXT NOT NULL REFERENCES component_type(id) ON DELETE CASCADE,
    environment_tag TEXT NOT NULL,
    PRIMARY KEY (component_type_id, environment_tag)
);

CREATE INDEX idx_component_type_system_class
    ON component_type(system_class);

CREATE INDEX idx_component_type_calculation_kind
    ON component_type(calculation_kind);

-- Component placement must be validated in the domain layer before insert:
-- 1. target room_surface.surface_type is allowed for component_type;
-- 2. room_environment satisfies temperature/humidity/wet/dust/corrosive limits;
-- 3. every instantiated port comes from component_type_port;
-- 4. engineering_connection.connection_type is allowed by both endpoint ports;
-- 5. component_type.system_class selects the routing/calculation policy.
