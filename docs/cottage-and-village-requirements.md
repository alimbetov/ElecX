# Cottage and cottage-village editor requirements

## Goal

ElecX must support the same spatial/electrical workflow for a detached cottage, townhouse unit and full cottage village without introducing a separate CAD engine.

Canonical hierarchy:

```text
Project
└─ Site
   ├─ Shared outdoor infrastructure
   │  ├─ Streets / driveways
   │  ├─ Pedestrian paths
   │  ├─ Common lighting
   │  ├─ Transformer / generator / PV area
   │  └─ Shared low-voltage/data routes
   └─ Lots
      ├─ Lot 1
      │  ├─ House 1
      │  │  ├─ Basement / plinth
      │  │  ├─ Floor 1
      │  │  ├─ Floor 2
      │  │  └─ Attic / technical level
      │  └─ Private yard / parking / landscape zones
      ├─ Lot 2
      └─ ...
```

## Domain rules

1. A cottage is a regular `Building`; no separate room/surface model is introduced.
2. A cottage village is a `ComposedSite` containing multiple `Building` objects, lots, outdoor zones and shared networks.
3. Every lot has site-coordinate geometry in integer millimetres.
4. House rooms/corridors remain `EngineeringSpace` instances and use the same surfaces, openings, components, snap and routing engines as an apartment building.
5. Repeating a typical house must deep-clone building/level/room identities. Editing House 7 must not mutate House 8.
6. Shared infrastructure is modelled at site level and may serve many buildings.
7. Private-yard infrastructure belongs to a lot/outdoor zone; common streets and common lighting remain site-wide.
8. Routing from a common source into a house must cross explicit site/building connection points.
9. Site-level routing and building-level routing must remain separate graph layers connected through explicit entry nodes.

## Supported cottage levels

The model must support typical cottage combinations:

```text
B1 / basement
0 / plinth or ground datum when needed
1 / first floor
2 / second floor
3 / optional third/attic floor
roof / technical
```

There is no restriction preventing deeper basements; the signed level model remains reusable.

## Site overview UX

At village scale the primary workspace is a site map:

```text
┌─────────────────────────────────────────────────────────┐
│ Site: Green Village                         Layers  Fit │
├──────────────┬──────────────────────────────────────────┤
│ NAVIGATOR    │                                          │
│ Street A     │     Lot 1       Lot 2       Lot 3       │
│ Lot 1        │    ┌─────┐     ┌─────┐     ┌─────┐      │
│ Lot 2        │    │ H1  │     │ H2  │     │ H3  │      │
│ Lot 3        │    └─────┘     └─────┘     └─────┘      │
│ Common infra │──────────── shared electrical ───────────│
└──────────────┴──────────────────────────────────────────┘
```

Required behavior:

- Site camera uses the same `WorldCamera` and LOD principles as building plans.
- Far zoom: show lots/building footprints and shared networks only.
- Medium zoom: show private yard zones, entrances and external equipment.
- Near zoom: allow selection of building/lot connections and route nodes.
- Double click/tap a house -> open building level navigator.
- Breadcrumb must preserve `Site > Lot > House > Level > Room`.
- Back navigation returns to the exact previous site camera when practical.

## Typical-house workflow

```text
Draw House Template
      ↓
Define levels / rooms / corridors / surfaces
      ↓
Place electrical system and service-entry point
      ↓
Create N lots / houses from template
      ↓
Each house receives unique ids
      ↓
Engineer may detach/customize one house independently
```

Future enhancement: template inheritance with explicit `propagate / detach` operations. Initial behavior remains safe deep cloning.

## Shared engineering networks

The village must support independent shared networks:

- electrical power;
- outdoor lighting;
- data / telecom;
- CCTV;
- access control;
- fire alarm where applicable;
- future EV charging and distributed generation.

Target routing hierarchy:

```text
Transformer / external source
       ↓
Site electrical graph
       ↓
Street / common cable route
       ↓
Lot service-entry node
       ↓
House main board
       ↓
House routing graph
       ↓
Floors / rooms / components
```

The same concept applies to low-voltage/data systems.

## Acceptance scenarios

1. Create one detached cottage on one lot and edit its room/corridor geometry with the normal editor.
2. Clone a typical house into 12 lots: all building, level and room ids are unique.
3. Edit House 7: House 8 remains unchanged.
4. A shared electrical network serves every configured cottage.
5. Site overview can represent private lots and common infrastructure in one coordinate system.
6. A route cannot jump directly from a site source to an interior socket; it must enter through an explicit building connection/main-board topology.
7. Performance must depend on visible lots/buildings at current LOD, not total village object count.
