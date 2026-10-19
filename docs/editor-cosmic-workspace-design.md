# ElecX space-first CAD workspace design

## Intent

The editor must feel like an engineering workstation, not a generic Material application. The drawing is the primary product surface. Navigation, commands, properties and context are supporting instruments and must consume only the space justified by their current task.

## Spatial priority

1. Canvas.
2. Active command / precision controls.
3. Current context and surfaces.
4. Navigator.
5. Inspector.
6. Secondary settings.

The editor must never reserve large permanent areas for controls that are used only occasionally.

## Desktop geometry

Baseline chrome:

- app bar: 48 px;
- command dock: 46 px;
- context strip: 36 px;
- navigator: 248 px expanded / 44 px collapsed;
- inspector: 300 px expanded / 44 px collapsed;
- canvas inset: 8 px.

Compared with the previous 58 + 54 + 44 px top chrome and 280 + 360 px side panels, this gives materially more drawing area while retaining discoverability.

## Focus mode

Focus mode hides Navigator, Inspector and context strip. It preserves the command dock and current drawing so the engineer can work with maximum spatial concentration. Exiting focus mode restores the previous expanded/collapsed panel choices.

## Panel contract

Navigator and Inspector must support:

- expanded state;
- compact 44 px rail;
- one-click restore;
- no modal transition for normal desktop collapse;
- drawer presentation on Tablet/Mobile.

The rail keeps orientation and avoids the cognitive cost of making panels disappear completely.

## Command dock

Primary commands remain icon-first and stable across form factors. Desktop pointer targets are 38 px; Tablet/Mobile remain 40+ px. Group order is stable:

1. authoring;
2. electrical / precision;
3. history;
4. viewport;
5. layers / routing.

The active tool is indicated by selected treatment, not by permanent text labels.

## Context strip

The context strip is a compact breadcrumb-like operational row. It shows only the current meaningful path such as level, apartment/common zone and room. It must not repeat verbose titles already present in the Navigator and Inspector.

## Dynamic minimap

`ContextMiniMap` remains temporary by default and opens as a draggable bottom sheet:

- compact overview;
- medium working height;
- expanded navigation height;
- swipe down / explicit action to close.

It reuses current model geometry and selection state. It must not create a parallel project model.

## Visual language

- neutral graphite/steel surfaces;
- one accent family reserved for active command, selection and focus;
- thin dividers instead of card nesting;
- minimal elevation;
- compact typography for metadata;
- geometry and engineering evidence must visually dominate application chrome;
- light and dark modes share the same information hierarchy.

## Responsive behavior

### Desktop

Persistent/collapsible rails, full command dock, optional focus mode.

### Tablet

Canvas-first. Navigator and Inspector use drawers. Minimap uses bottom sheet.

### Mobile

Canvas-first field workspace. Minimap and contextual controls use bottom sheet/drawers. No attempt is made to reproduce the desktop three-panel layout.

## Acceptance

The workspace is acceptable when:

1. collapsing both side panels gains substantial canvas width without removing access to them;
2. focus mode can be entered/exited without changing project/editor state;
3. minimap can be opened and dismissed without changing model data;
4. the same primary icon vocabulary is preserved on all form factors;
5. active room/surface/context remains legible without multiple duplicated title areas;
6. light/dark mode does not reduce drawing contrast;
7. panel/chrome sizes are governed by shared tokens rather than scattered magic numbers.
