# ElecX editor device modes

ElecX uses one project model, geometry engine, command model and surface topology across all form factors. Only workspace composition and input affordances change.

## Breakpoints

- Mobile: width < 700 px
- Tablet: width >= 700 px and < 1180 px
- Desktop: width >= 1180 px

Breakpoints are based on available editor width, not operating-system identity. A resizable desktop window can therefore exercise all three layouts.

## Desktop

Desktop is the primary authoring workstation.

- persistent project navigator on the left;
- persistent contextual inspector on the right;
- full labelled tool strip;
- surface strip for Plan / Floor / Ceiling / Wall 1..N;
- status bar;
- mouse/keyboard CAD workflow;
- maximum canvas area between persistent panels.

## Tablet

Tablet is canvas-first but remains an authoring client.

- project navigator is a left drawer;
- inspector is a right drawer;
- compact icon-first tool strip;
- horizontal surface strip;
- canvas remains visible at maximum practical size;
- the same room/opening/route commands are used as Desktop.

Touch pan/pinch is a required follow-up input adapter on top of WorldCamera; it must not create a second camera model.

## Mobile

Mobile is a field-oriented compact editor.

- canvas occupies the central workspace;
- project navigator is a drawer;
- contextual properties are an end drawer;
- primary tools are in a bottom NavigationBar;
- surface navigation remains horizontally scrollable;
- a compact context badge shows selected room and current tool;
- detailed status text is intentionally removed from the permanent chrome.

Complex mass-authoring is Desktop-first, but Mobile uses the same model and commands, so small edits remain compatible with the same project.

## Shared invariants

All modes share:

- EditorController state;
- selected project/level/space/surface;
- integer-millimetre geometry;
- WorldCamera-based rendering;
- SpatialSceneIndex and culling;
- semantic LOD;
- adaptive grid;
- openings and wall profiles;
- cable route model;
- future electrical component model;
- future command history and sync.

No device-specific project format is permitted.

## Manual acceptance

Resize a desktop window through all three ranges and verify:

1. selection survives layout transitions;
2. active Plan/Floor/Ceiling/Wall survives layout transitions;
3. room list and inspector refer to the same selected room;
4. opening edits update the same model in every layout;
5. route draft remains present while changing layout width;
6. no horizontal overflow appears at 430, 768, 1024, 1180 and 1440 px widths.
