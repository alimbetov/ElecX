# Spatial Editor v1

## Product goal

The first ElecX editor is designed around an engineer's real workflow rather than ELV delivery stages.

The spatial hierarchy is:

`Project -> Site -> Building -> Level -> Space`.

A `Space` can be a room, corridor, hall, technical room, stair, shaft or outdoor area. Engineering systems will later reference these same spaces instead of maintaining discipline-specific copies.

## Coordinate model

Persisted geometry uses integer millimetres. Every room has a `RoomReferenceFrame` with its own origin and rotation. v1 uses the geometric center as the default origin and renders automatic horizontal/vertical centerlines.

There are two visible grid levels in the first implementation:

1. floor grid — navigation and coarse construction;
2. room grid — local precision grid, independently configurable per room.

The next geometry increment adds rotated room frames, persistent user guides, midpoint/intersection snapping and polygon room editing.

## Editor interaction

The first vertical slice supports:

- selection;
- rectangular room creation by two snapped points;
- per-room grid values of 50/100/250/500 mm;
- automatic centerlines;
- room properties;
- project hierarchy panel;
- metric status bar.

The canvas is intentionally domain-light. Geometry and reference frames live in the domain layer so future electrical, LAN, CCTV, ACS and fire layers can reuse the same spatial model.

## Migration from Electra

ElecX reuses architectural lessons, not the old ELV stage ownership. The useful concepts retained are exact millimetre geometry, local coordinate frames, explicit spatial entities, snapping and deterministic transformations. The new editor starts at the project/space level so the spatial model becomes a shared source of truth.

## Next increments

- viewport pan/zoom with stable world-to-screen transform;
- polygon walls/rooms and wall editing;
- doors/windows/openings;
- rotated local room grids;
- guide objects and smart guides;
- endpoint/midpoint/center/intersection snap candidates;
- dimensions and measurements;
- copy floor / typical floor;
- persistence and revisions;
- engineering layer palette.
