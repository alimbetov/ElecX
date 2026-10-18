# ElecX Electrical Authoring — placement and cable routing requirements

## Goal

Electrical authoring is a model-backed layer over the spatial editor. Components live on real room surfaces and cable routes connect real component ports. No electrical object stores screen coordinates or duplicates architectural geometry.

## Component placement

The first component palette must include:

- socket outlet;
- switch / control point;
- lighting point;
- curtain motor / actuator;
- junction box;
- power source;
- distribution board;
- custom component placeholder for catalogue-backed equipment.

Every placed component stores:

- stable id;
- engineering type;
- host surface (`wall`, `floor`, `ceiling`);
- local X/Y in integer millimetres;
- rotation;
- label;
- voltage;
- optional rated power;
- electrical/control ports.

The same component must appear consistently in every projection that can physically see it. It must never be represented by unrelated copies per view.

## Placement UX

Desktop workflow:

1. Select a room and active surface.
2. Choose a component from the Electrical palette.
3. Hover previews the snapped installation point and distances to relevant boundaries.
4. Click places the component.
5. The component becomes selected and its inspector opens.
6. Escape cancels placement; repeated-placement mode may be enabled for repetitive sockets/lights.

Wall-mounted components use wall-local X/Y. Ceiling and floor components use room-plane local coordinates.

Snap candidates should include grid, wall endpoints, midpoints, room axes, guides, neighbouring components and relevant architectural edges.

## Component inspector

The contextual inspector must allow:

- component type/catalogue item;
- label;
- exact X/Y or wall-offset/height;
- rotation;
- rated power;
- voltage;
- mounting height where applicable;
- delete / duplicate;
- connection status;
- assigned circuit when available.

Direct drag and numeric editing must call the same validated command layer.

## Cable routing workflow

A cable route is not an anonymous polyline. It connects a source component port to a target component port.

Required interaction:

1. Start `Cable Route` from a selected source port or component.
2. Show compatible target ports and highlight them.
3. Route manually with snap and orthogonal guidance, or request an automatic candidate path.
4. Transition across wall/floor/ceiling using the existing physical surface topology.
5. Finish on a target port.
6. Store the route, geometric length and installation length including configurable reserve.

The editor must display:

- source and target;
- active surface segment;
- total length;
- reserve-adjusted length;
- cable type when chosen;
- invalid/disconnected state;
- surface transitions.

## Source semantics

A source may be a distribution board, power source, junction point or output port of another component. A target may be a socket, luminaire, motor, control device or another junction point.

Source and target references are port-level, not only component-level. This is required for future multi-circuit devices, controls, PE/N conductors and catalogue-backed terminal data.

## Auto-routing contract

Automatic routing is a suggestion engine, never a silent mutation. It should later optimize against:

- allowed surfaces;
- preferred wall/floor/ceiling routing zones;
- architectural openings and obstacles;
- beam/notch wall profiles;
- user guides;
- minimum bend and installation rules;
- route length;
- shared cable paths/trays;
- normative restrictions.

The user must be able to accept, edit or reject an automatically proposed route.

## Architecture

```text
Spatial model
   │
   ├── RoomSurfaceRef
   │      └── ElectricalComponentPlacement
   │               └── ElectricalPortDefinition
   │
   └── Surface topology
          └── ElectricalCableRoute
                 ├── source ElectricalEndpointRef
                 ├── target ElectricalEndpointRef
                 └── ElectricalRouteSegment 1..N
```

This layer becomes the input for later circuits, load calculations, cable sizing, protection selection, equipment catalogue selection and documentation.

## Acceptance scenarios

1. Place a socket on a wall at an exact X/Y position.
2. Place a switch on the same or another wall.
3. Place a lighting point on the ceiling.
4. Place a curtain motor near a window/ceiling zone.
5. Place a distribution board or power source.
6. Start a cable from a real source port and terminate it on a real consumer port.
7. Continue the same cable across wall/floor/ceiling transitions.
8. Display geometric route length and reserve-adjusted installation length.
9. Reject a route whose source or target port does not exist.
10. Keep component and route coordinates in millimetres independent of viewport zoom.
