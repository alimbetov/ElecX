# ElecX spatial editor — product board + external audit

## Review model

This document records one deliberate review from two independent perspectives.

### Role A — product director / marketing / sales / visual design

Success criteria:
- the product must look recognisable within the first seconds of use;
- users must immediately understand that ElecX is a professional engineering instrument, not a generic CRUD application;
- the visual language must support demonstrations, screenshots and sales presentations;
- the UI must communicate active engineering state, not merely decorate the screen;
- novice electricians must be able to discover the next action without hiding expert shortcuts.

### Role B — external engineering / UX / UI audit company

Success criteria:
- interaction remains deterministic under mouse, keyboard, touch and stylus;
- visual hierarchy survives dark/light mode and dense engineering drawings;
- primary actions meet usable pointer/touch target sizes;
- geometry, status, warning, error and selection states are not encoded by decoration alone;
- animation never changes engineering state and can be disabled without changing semantics;
- CAD drawing remains visually quieter than controls only where that improves legibility;
- business/domain logic stays outside Flutter painters and widgets.

## Joint verdict

The existing foundation has a strong domain/editor architecture, but the visual shell is still too close to a standard Material application. The target should be an **alien engineering cockpit**: a restrained science-fiction control surface layered on top of a professional CAD instrument.

The design must avoid three failure modes:

1. **Neon toy UI** — glowing every control reduces hierarchy and quickly becomes tiring.
2. **Generic enterprise UI** — technically usable, but weak product identity and poor demo value.
3. **Decorative sci-fi** — visual effects that do not correspond to real state confuse engineering work.

The accepted direction is therefore:

> Dark deep-space canvas + cyan/teal instrumentation + violet secondary intelligence accent + amber warning + red fault, with thin illuminated borders, HUD-like status treatments and restrained glow only for active/selected states.

## Product design principles

### 1. Engineering state first

Every visual effect must map to a semantic state:

- normal;
- hover;
- selected;
- active command;
- valid preview;
- invalid preview;
- warning;
- error;
- locked/reference;
- route flow;
- transition/continuation point.

No decorative blinking or random glow is allowed.

### 2. Canvas remains the hero

The drawing canvas gets the largest visual area. Navigator and catalog are support systems. Panels should look like cockpit modules but must not compete with geometry.

### 3. One interaction contract

Desktop, tablet and mobile share one domain interaction model:

- select;
- preview;
- snap;
- validate;
- commit/cancel.

Input adapters differ, engineering semantics do not.

### 4. Progressive complexity

Beginner view shows:
- Select;
- Add component;
- Route;
- Snap;
- Dimensions;
- Undo/Redo.

Advanced actions remain discoverable through grouped menus/inspectors rather than a permanently expanded command wall.

### 5. Explainable automation

Any automatic route, equipment selection or optimization must show:
- what changed;
- why;
- measured benefit;
- violated/used constraints;
- accept/reject action.

## Alien cockpit visual system

### Base palette intent

Dark mode is the product-signature mode.

- background: near-black blue/green space tone;
- surfaces: layered blue-black panels;
- primary: luminous cyan;
- secondary: violet/lilac intelligence accent;
- tertiary: aqua/green continuation/navigation accent;
- warning: amber;
- error: warm red;
- drawing geometry: neutral cool grey;
- grid: subtle blue-grey;
- selected geometry: cyan with restrained halo.

Light mode remains fully supported for printing/daylight environments but uses the same semantic accent structure.

### Shape language

- small radii, not consumer-app pills everywhere;
- thin 1 px borders;
- occasional chamfer-like visual impression through stacked borders/lines rather than nonstandard hit shapes;
- compact headers with uppercase section labels;
- selected/active modules get a luminous edge, not a large filled blob.

### Motion

Allowed:
- selected cable-flow animation;
- short selection/activation fades;
- subtle status pulse for active placement/route continuation;
- panel open/close transitions.

Disallowed:
- continuous background animations;
- ornamental blinking;
- motion that changes perceived geometry;
- animation as the only error/selection indicator.

## Functional audit

### P0 — required before calling the spatial editor production-grade

1. Unify all component placement through `EngineeringPlacementCursorSession`.
2. Unify all component movement through `ComponentMoveSession`.
3. Keep route selection independent from component selection but coordinated at controller level.
4. Keep indoor/outdoor routes under one `routeId` and medium semantics.
5. Add a single semantic visual-state token system rather than object-specific arbitrary colors.
6. Provide explicit active-command feedback in toolbar/HUD.
7. Ensure panel/canvas switching never discards dirty drafts silently.
8. Ensure route simulation/optimization stays read-only until explicit apply.
9. Add accessibility-safe minimum targets and keyboard focus treatment.
10. Add visual regression/golden tests for the main workspace states once design stabilizes.

### P1 — ergonomics and sales quality

1. Command groups with labels/tooltips and overflow behavior.
2. Favorites/recent components in catalog.
3. Current-surface compatibility and placement-repeat state visible without opening settings.
4. Simulation findings panel linking directly to selected objects/routes.
5. Route continuation marker that previews destination host before switching.
6. Compact engineering status bar: scale, snap, active surface, route medium, validation state.
7. Optional reduced-motion mode.
8. Saved workspace layout per device class.

### P2 — premium differentiation

1. Multi-object optimization preview.
2. Animated circuit/data-flow diagnostics.
3. Layer/discipline isolation presets.
4. Command palette/search.
5. Comparison mode for current vs optimized routes.
6. Presentation/demo mode with simplified chrome.

## Commercial positioning verdict

The strongest product story is not “AutoCAD clone for electricians”. It is:

> **ElecX is an engineering cockpit that understands rooms, surfaces, electrical components, topology, routes, installation channels and validation.**

The visual identity should reinforce that story: the application appears advanced because its interface exposes real engineering state, not because it imitates science-fiction decoration.

## Acceptance criteria for the visual refresh

- Dark theme visually reads as one coherent cockpit system.
- Primary controls remain identifiable without relying on glow.
- Selected route/component is visible against both dark and light surfaces.
- Warning/error states remain distinguishable from selection.
- Text and icons remain readable at compact editor density.
- 44+ logical pixel touch targets are available for touch interaction paths even if desktop density is lower.
- No domain behaviour is implemented inside theme/widget styling code.
- Existing editor tests remain green.
