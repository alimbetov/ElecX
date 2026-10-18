# ElecX Unified Icon Toolbar UI Contract

## Goal

ElecX uses one command vocabulary across Desktop, Tablet and Mobile. The same command must use the same icon, selection state and tooltip everywhere. Form factors may change placement and density, but must not invent a different command model.

## Core rule

**One command -> one icon -> one behavior.**

Text labels are secondary UI. Frequently used CAD actions are represented by compact icon buttons; names remain available through tooltips, selected-state context, the status bar and accessibility semantics.

## Primary CAD toolbar

| Command | Icon | Shortcut | Notes |
| --- | --- | --- | --- |
| Select | `near_me_outlined` | V | Primary selection tool |
| Room | `crop_square` | R | Available on Plan |
| Guide | `straighten` | G | Construction/reference guide |
| Cable route | `alt_route` | C | Surface-aware route |
| Snap | `grid_4x4` / `grid_off` | future | Toggle; selected state visible |
| Dimensions | `straighten` | future | Toggle dimension visibility |
| Fit | `fit_screen` | 0 | Fit current context |
| Zoom out | `zoom_out` | - | Camera command |
| Zoom in | `zoom_in` | + | Camera command |
| Properties | `tune` | future | Opens contextual inspector |

## Geometry

- Desktop/Tablet icon button target: 40-44 px.
- Mobile touch target: minimum 44-48 px.
- Icon size: 20-22 px for primary tools, 18-20 px for secondary actions.
- Group gap: 4 px inside a tool group, 8-12 px between groups.
- Avoid text-bearing toolbar buttons for primary commands.
- Do not reduce hit target merely to reduce visual width.

## Grouping

The primary toolbar is divided into stable groups:

1. **Authoring**: Select, Room, Guide, Route.
2. **Precision**: Snap, Dimensions.
3. **Viewport**: Fit, Zoom out, Zoom in.
4. **Context**: Properties / more actions.

Groups should be separated by a subtle divider or larger gap, not by unrelated button styles.

## Selection and toggle states

- Active tool uses a filled tonal icon button or equivalent selected background.
- Toggle ON uses selected background and active icon.
- Toggle OFF remains visible but visually neutral.
- Disabled command must stay in the same location where practical to preserve muscle memory.
- A selected tool must also be named in the status/context area so icon-only UI remains unambiguous.

## Responsive behavior

### Desktop

Use a horizontal icon toolbar near the canvas. Project tree and Inspector remain visible. Tooltips are mandatory.

### Tablet

Use the same horizontal icon order. Project tree and Inspector move to drawers. Do not rename or reorder commands solely because the layout is narrower.

### Mobile

Use the same command icons in a compact bottom or floating command bar. Less-frequent precision/context actions may move into a secondary expandable row/menu, but their icons and semantics remain identical.

## Surface navigation

Plan / Floor / Ceiling / Wall are not authoring tools and must remain a separate navigation group. They may use compact icon+short-label controls because surface identity is spatial context rather than a CAD command.

Recommended compact labels:

- Plan: map icon + `Plan`
- Floor: grid icon + `Floor`
- Ceiling: ceiling icon + `Ceil`
- Walls: wall icon + `W1`, `W2`, ...

## Accessibility

Every icon-only action must provide:

- tooltip/semantic label;
- selected/pressed state;
- minimum touch target;
- keyboard equivalent where available;
- no information encoded by color alone.

## Anti-patterns prohibited

- Different icon for the same command on different form factors.
- Desktop text buttons while Tablet uses unrelated icons for the same tool.
- Tiny icon targets below touch accessibility size.
- Multiple visual styles for peer commands without semantic reason.
- Hiding active state solely because a toolbar is compact.
- Mixing viewport actions with model-authoring actions without grouping.

## Acceptance

The toolbar is considered unified when an engineer can switch between Desktop, Tablet and Mobile and recognize all primary commands from position and icon alone, while every command continues to invoke the same EditorController / viewport command path.
