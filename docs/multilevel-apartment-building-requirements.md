# Multilevel apartment building editor — B30…16

## Scope

ElecX must support large apartment buildings without flattening the model into one list of rooms. The reference scenario is a 16-floor residential tower with underground levels down to B30.

Canonical hierarchy:

```text
Project
└─ Site
   └─ Building
      ├─ Vertical cores
      │  ├─ Stair cores
      │  ├─ Elevator shafts
      │  ├─ Electrical risers
      │  └─ ELV/cable risers
      └─ Levels B30 … B1, 1 … 16
         ├─ Apartments
         │  ├─ Apartment 701
         │  │  ├─ Entrance / corridor
         │  │  ├─ Living / kitchen
         │  │  ├─ Bedrooms
         │  │  ├─ Bathrooms
         │  │  └─ Utility / balconies
         │  └─ Apartment 702 …
         ├─ Common areas
         │  ├─ Common corridor
         │  ├─ Lift lobby
         │  └─ Stair lobby
         └─ Technical / service zones
```

## Domain rules

1. A room remains an `EngineeringSpace` with physical geometry.
2. An apartment is not a room type. It is a semantic `BuildingZone` grouping several spaces on one level.
3. One space may belong to at most one level zone.
4. Level number is signed and independent from elevation.
5. B30 is level number `-30`; B1 is `-1`; residential floors are `1…16`.
6. Repeated floors are cloned with stable unique room/zone ids. Editing floor 7 must never mutate floor 6 or 8 implicitly.
7. Common areas, parking, storage and technical areas use the same zone abstraction but are not apartments.
8. Vertical objects are explicit building topology: stairs, elevators, electrical risers, service shafts and cable risers.
9. Electrical and ELV routing between levels must pass through an allowed vertical core or another explicit vertical transition. A route may not jump directly between arbitrary floors.
10. Every electrical object remains bound to a physical `RoomSurfaceRef`; the building/zone hierarchy adds semantic navigation, not alternative geometry.

## Level stack UX

The desktop navigator must not render 46 expanded levels at once. Use a compact level stack:

```text
BUILDING A

[ Residential ] [ Basement ] [ All ]

 16  ─  Residential
 15  ─  Residential
 ...
  7  ─  Residential  ← current
 ...
  1  ─  Residential
──── ground datum ────
 B1  ─  Basement
 B2  ─  Basement
 ...
 B30 ─  Basement
```

Required interactions:

- click level → open its plan while preserving zoom if possible;
- PageUp / PageDown → previous/next physical level;
- Ctrl/Cmd+G → go to level by number (`-30`, `-1`, `1`, `16`);
- filter Residential / Basement / All;
- show level name, elevation and apartment count;
- keep current level pinned/visible during scrolling;
- provide `Fit Level` and `Fit Apartment` actions.

## Apartment navigator

Inside a residential level:

```text
LEVEL 7
├─ Apartment 701   74.2 m²
│  ├─ Hall
│  ├─ Kitchen-living
│  ├─ Bedroom 1
│  ├─ Bedroom 2
│  └─ Bathroom
├─ Apartment 702   61.4 m²
└─ COMMON
   ├─ Corridor
   ├─ Lift lobby
   └─ Stair lobby
```

Required behavior:

- selecting apartment highlights all its rooms but does not merge their geometry;
- double click apartment → fit apartment;
- electrical summary can aggregate per apartment;
- room remains independently selectable/editable;
- apartment number is stable and unique within the building business rules;
- common areas are never silently assigned to an apartment.

## Typical-floor workflow

A 16-floor building should not require drawing the same layout sixteen times.

Workflow:

```text
Draw one typical residential level
      ↓
Assign rooms to apartments/common areas
      ↓
Define stairs/elevators/risers
      ↓
Repeat as floors 1…16
      ↓
Each floor receives stable unique ids
      ↓
Engineer may modify an individual floor independently
```

The same mechanism applies to B30…B1 basement templates.

Future enhancement: explicit template linkage with `inherit / detach / propagate selected changes`. Initial implementation uses safe deep clones so no cross-floor mutation is possible.

## Vertical engineering topology

Vertical routing must use explicit cores:

```text
Apartment 1601
   │
   └─ circuit route
        │
        ▼
Electrical riser ER-1
        │
  ┌─────┼─────┐
  ▼     ▼     ▼
 L16   L15   ...
        │
        ▼
       B1
        │
        ▼
Main switchboard / source
```

A vertical core must declare which level numbers it serves. Later `BuildingRoutingGraph` will map level-local `RouteEngine` graphs through these core nodes.

## Performance requirements

Reference building: B30…16 = 46 levels.

The editor must:

- load/render only the active level geometry by default;
- keep other levels as lightweight metadata/index entries;
- use LOD for optional ghost levels;
- never perform snap intersection search across all building levels;
- never include every level in active canvas hit-testing;
- keep vertical-core topology indexed separately from level-local geometry;
- support at least hundreds of apartments and thousands of rooms without changing domain contracts.

## Acceptance scenarios

1. Build a tower with levels B30…B1 and 1…16: exactly 46 levels.
2. Clone a typical floor containing multiple apartments: all generated room and zone ids are unique.
3. Edit geometry/metadata on floor 7: floor 8 remains unchanged.
4. Select apartment 701: only spaces assigned to that apartment become the apartment selection set.
5. A room cannot belong simultaneously to Apartment 701 and COMMON.
6. Electrical riser ER-1 serves B30…16 and can later be used as a legal cross-level routing transition.
7. Selecting B30, B1, 1 and 16 produces deterministic level identity and elevation.
8. Active-level rendering does not require loading or painting geometry from the other 45 levels.
