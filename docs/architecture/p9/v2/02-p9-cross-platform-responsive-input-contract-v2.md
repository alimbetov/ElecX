# P9 Cross-Platform Responsive & Input Contract v2

Status: **AUTHORITATIVE FOR P9 PRESENTATION / INPUT**  
Branch: `feat/p9-apartment-topology-generator`  
Applies to: P9.8, P9.9, P9.10, P9.13 and forward architecture for P10-P14

## 1. Purpose

Define one cross-platform interaction architecture for ElecX so P9 apartment generation behaves as the same product capability on desktop, tablet and phone while adapting layout and input mechanics to available viewport and input modality.

This contract exists to prevent future P10-P14 CAD functionality from depending on P9-specific desktop assumptions or mobile-only UI shortcuts.

The governing rule is:

```text
same semantic request
+ same catalog/generator/scoring versions
= same ordered candidate fingerprints

regardless of:
Windows / macOS / Linux / iPadOS / Android / iOS
mouse / trackpad / touch / stylus / keyboard
portrait / landscape
window size / split-screen
```

Only presentation, navigation density and input gesture mapping may vary.

## 2. Product posture by form factor

P9 functionality is not disabled by device class.

```text
Desktop
  PRIMARY professional authoring surface
  full Wizard + compare + Preview/Diff + precise CAD-ready interactions

Tablet
  FULL Wizard + compare + Preview/Diff + practical authoring
  touch/stylus optimized

Phone
  FULL Wizard + candidate review + Preview/Diff + Apply
  lightweight editing/review; not primary precision CAD surface
```

Phone limitations MAY apply to later precision CAD operations, but MUST NOT change P9 generation semantics or candidate quality.

## 3. Capability-driven, not OS-driven layout

UI layout MUST derive primarily from runtime capabilities:

```dart
final class ElecXPresentationCapabilities {
  final double logicalWidth;
  final double logicalHeight;
  final bool hasPrecisePointer;
  final bool hasHover;
  final bool hasTouch;
  final bool hasStylus;
  final bool hasHardwareKeyboard;
  final bool animationsDisabled;
  final double textScaleFactor;
}
```

OS/platform checks MAY select native conventions where needed, but MUST NOT be the primary breakpoint mechanism.

Forbidden design:

```dart
if (Platform.isWindows) desktopLayout();
if (Platform.isAndroid) mobileLayout();
```

Required direction:

```text
viewport + input capabilities + accessibility settings
                ↓
        presentation policy
```

This is required because an Android tablet may have mouse/keyboard, an iPad may run split-screen, and a desktop window may be narrower than a tablet.

## 4. Responsive width classes

P9 uses logical pixels, not physical device pixels.

Authoritative v2 width classes:

```text
COMPACT     < 600
MEDIUM      600..1023
EXPANDED    1024..1439
LARGE       >= 1440
```

These are layout classes, not device identities.

Typical mapping:

```text
phone portrait           COMPACT
phone landscape          often COMPACT/MEDIUM
tablet portrait          MEDIUM
tablet landscape         MEDIUM/EXPANDED
small desktop window     MEDIUM/EXPANDED
desktop                  EXPANDED/LARGE
```

No business logic may depend on width class.

## 5. Height constraints

Width alone is insufficient.

Presentation MUST handle short-height windows such as:

```text
1280 x 720 desktop
844 x 390 phone landscape
1024 x 600 tablet/window
```

Rules:

- primary actions remain reachable without overflow;
- content regions scroll independently where appropriate;
- action bars may become sticky;
- preview canvas uses remaining bounded space;
- no fixed-height panel may make Apply/Cancel unreachable.

## 6. Orientation and window resizing

### P9-PLAT-FR-001

Orientation/window resize MUST NOT:

- regenerate candidates;
- change ranking;
- clear parameter input;
- clear valid candidate selection;
- allocate new canonical IDs;
- close a prepared Preview;
- alter `candidateFingerprint`.

### P9-PLAT-FR-002

A layout-class transition is presentation-only state.

Example:

```text
900 px -> 1100 px
MEDIUM -> EXPANDED
```

The same Wizard session and exact selected candidate remain active.

## 7. P9 screen composition by width class

### 7.1 COMPACT

Primary model:

```text
single task column

[step/header]
[parameters OR candidate card OR preview]
[details accordion/sheet]
[sticky Back/Cancel/Continue/Apply]
```

Candidate browsing:

```text
one primary candidate card
horizontal swipe / explicit Previous / Next
page indicator
Compare/details opens full-screen route or sheet
```

P8 Diff:

```text
full-screen semantic list
collapsible groups
search/filter optional secondary action
preview and diff switched by tab/segmented control
```

### 7.2 MEDIUM

Primary model:

```text
parameters + candidate region
or
2-column candidate grid
```

Selected preview may use:

```text
main preview
+ bottom/side details sheet
```

### 7.3 EXPANDED

Primary model:

```text
left: parameters/steps
center: candidate grid / preview
right: candidate details or semantic Diff
```

Candidate grid normally 2-3 columns.

### 7.4 LARGE

May use persistent three-pane workspace:

```text
Wizard controls | visual compare/preview | semantic details/Diff
```

Maximum readable widths SHOULD cap text/detail panes; extra width benefits canvas/compare area rather than stretching forms indefinitely.

## 8. Candidate-card responsive contract

Every candidate card MUST expose the same semantic information independent of width:

```text
family
habitable room count
interior requested/realized area
appendage summary when present
kitchen mode
score / rank summary
selection state
```

COMPACT MAY collapse secondary score details but MUST NOT hide blocker/warning state.

Candidate ordering is identical across all form factors.

## 9. Compare behavior

Desktop/tablet with enough width MAY show multiple candidates simultaneously.

Phone MAY show one at a time.

This difference MUST NOT alter:

```text
candidate set
ranking
selection identity
candidate fingerprints
```

A compare UI is a projection of one immutable candidate set.

## 10. Input modality contract

ElecX distinguishes operations from gestures.

Semantic operations:

```text
selectCandidate
nextCandidate
previousCandidate
openCandidateDetails
zoomIn
zoomOut
zoomToFit
panPreview
openDiff
apply
cancel
back
```

Each platform maps available inputs to these operations.

## 11. Mouse / trackpad contract

On precise-pointer surfaces:

```text
primary click       select / activate
secondary click     optional context menu only
wheel               scroll by default
Ctrl/Cmd + wheel    zoom preview where native convention permits
trackpad pinch      zoom preview when available
middle/space-drag   optional pan shortcut for CAD-style surfaces
hover               enhancement only
```

### P9-PLAT-INV-001

No mandatory action may require hover.

### P9-PLAT-INV-002

No mandatory action may require right-click.

## 12. Touch contract

Touch targets:

```text
minimum interactive target: 48 x 48 logical px
```

Gestures:

```text
tap                 select/activate
horizontal swipe    candidate navigation only when gesture does not conflict with nested canvas pan
pinch               preview zoom
one-finger drag     preview pan when canvas is in pan mode / clearly captured
long press           optional context/details action, never sole access path
```

Gesture conflicts MUST be resolved explicitly.

A horizontal swipe on a candidate carousel MUST NOT accidentally pan a zoomed preview canvas.

Recommended rule:

```text
carousel gesture owns drag outside interactive preview canvas
preview canvas owns drag after pointer-down begins inside canvas and zoom/pan interaction is enabled
```

## 13. Stylus contract

P9 does not require stylus to function.

When stylus is present:

- stylus behaves as a precise pointer for selection/pan;
- hover may enhance previews where OS exposes it;
- pressure/tilt MUST NOT affect P9 candidate semantics;
- future P10-P14 CAD tools MAY add stylus-specific authoring while reusing the same semantic command layer.

## 14. Hardware keyboard contract

Desktop and tablet with hardware keyboard MUST support predictable focus navigation.

Minimum:

```text
Tab / Shift+Tab     move focus
Enter / Space       activate focused control
Escape              close transient details / cancel current modal layer; must not silently discard committed data
Arrow keys          candidate navigation when candidate collection owns focus
Ctrl/Cmd + +/-      zoom preview when focused
Ctrl/Cmd + 0        zoom to fit
```

Application-global Undo/Redo remains owned by existing project command architecture and MUST NOT be shadowed by Wizard-local candidate navigation.

Any additional shortcut must be documented in a central shortcut registry rather than hidden in widgets.

## 15. Focus model

Focus order follows task order, not widget-tree accident.

Typical order:

```text
Wizard step/header
parameter controls
Generate
candidate collection
selected candidate details
Preview
Diff controls
Cancel / Apply
```

When responsive layout rearranges panes, logical focus order remains task-consistent.

Opening a modal/sheet traps focus appropriately and restores focus to the invoking control on close.

## 16. Screen reader / semantics contract

Candidate geometry is not exposed wall-by-wall.

Each candidate is one selectable semantic entity with concise summary.

Example content:

```text
Candidate 2 of 5.
Three-room split day/night apartment.
Interior area 78.5 square metres.
One loggia 4.2 square metres.
Kitchen-living room.
Score 87 percent.
Selected.
```

Preview canvas exposes:

- overall apartment semantic label;
- optional structured room summary;
- no hundreds of individual line-segment accessibility nodes.

Diff uses hierarchical semantic groups and announces add/update/remove state.

## 17. Text scaling

P9 supports at least:

```text
1.0
1.3
2.0
```

Rules:

- no clipped essential labels;
- actions may switch from text+icon to accessible icon-only only when tooltip/semantics preserve meaning;
- forms may reflow from row to column;
- card metadata may wrap;
- preview canvas must not consume the only available height;
- horizontal scrolling is not a substitute for ordinary text reflow except intentional CAD canvas regions.

## 18. Safe areas / system insets

Phone/tablet UI MUST respect:

```text
status/navigation bars
notches / dynamic islands
home indicator
IME/soft keyboard
fold/hinge bounds when exposed by framework
```

Primary Apply/Cancel actions must never sit behind system UI or IME.

## 19. Soft keyboard behavior

When editing parameters on phone/tablet:

- focused input remains visible;
- action bar remains reachable or intentionally moves above IME;
- closing IME does not trigger generation/apply;
- decimal area input is converted at application boundary using locale-aware presentation parser into typed integer `dm²` value;
- semantic value is locale-independent after conversion.

## 20. Preview viewport contract

P9 preview uses one platform-neutral viewport model:

```dart
final class PreviewViewportState {
  final double scale;
  final double translationX;
  final double translationY;
}
```

This is transient presentation state and never participates in candidate/canonical fingerprints.

Required operations:

```text
zoomToFit
zoomAroundAnchor
pan
resetView
```

Bounds:

- finite scale only;
- configurable min/max zoom;
- prevent unrecoverable panning completely away from content;
- `zoomToFit` always restores a usable view.

## 21. Preview gesture invariants

### P9-PLAT-INV-003

Zoom/pan cannot mutate generated geometry.

### P9-PLAT-INV-004

Changing viewport state cannot invalidate candidate selection or P8 reservation.

### P9-PLAT-INV-005

The same `ApartmentTopologyVectorScene` is rendered on all platforms; only viewport/painter mapping differs.

## 22. P8 Preview / Diff responsive behavior

Preview and Diff are the same semantic artifacts on all form factors.

Allowed presentation variants:

```text
COMPACT: preview/diff tabs or stacked routes
MEDIUM: preview + collapsible detail panel
EXPANDED/LARGE: split preview + persistent Diff panel
```

Not allowed:

- mobile-specific reduced Diff semantics;
- hiding changes only because screen is small;
- Apply without access to full blocker/conflict information.

## 23. Navigation architecture

Wizard navigation MUST be state-driven, not tied to a particular desktop pane hierarchy.

Semantic route/step state:

```text
parameters
candidates
candidateDetails
preview
completed
```

Responsive UI may present these as:

```text
panes
tabs
full-screen pages
bottom sheets
```

but one session state machine remains authoritative.

## 24. Back behavior

`Back` means move to previous Wizard semantic step, preserving valid input and candidate set where contracts allow.

Platform system back (Android/iOS navigation gesture) maps to the same semantic operation.

Back MUST NOT equal Cancel/Discard unless the UI explicitly asks for confirmation where state would be lost.

## 25. Desktop window behavior

P9 desktop supports resizable windows.

Minimum supported functional viewport target:

```text
width  >= 800 logical px
height >= 600 logical px
```

Below this, the application MAY fall back to COMPACT presentation but must remain functionally operable down to the qualification bounds defined in P9.13.

Window resize during generation/render must not cancel computation unless explicit cancellation policy exists.

## 26. Tablet split-screen / multitasking

Tablet layout MUST tolerate width changes caused by split-screen/multitasking without session reset.

Examples:

```text
iPad full width -> split 2/3 -> split 1/2
Android tablet freeform / multi-window
```

The presentation may cross width classes dynamically while keeping candidate identity and preview state.

## 27. Phone posture

Phone supports the complete P9 decision flow:

```text
enter request
Generate
review every candidate
inspect details
open full semantic Diff
Preview
Apply / Cancel
```

Phone MUST NOT silently simplify the generator request or reduce candidate generation count for performance.

If device performance is insufficient, UI may show progress/cancellation, but semantic algorithm and thresholds remain the same unless a future explicitly versioned capability policy is introduced.

## 28. Progress and long-running work

If candidate generation exceeds an interaction threshold (recommended > 150 ms), presentation SHOULD expose progress/busy state without blocking accessibility focus indefinitely.

Rules:

- no duplicate Generate submissions;
- Cancel generation may discard transient candidate computation only;
- cancellation cannot mutate canonical project;
- generation completion after Wizard session disposal must not resurrect UI state.

## 29. Error presentation

`P9Failure` remains platform-neutral.

Presentation mapping:

```text
field error       near parameter control when space permits
blocker summary   persistent visible area before Preview/Apply
warning           candidate/details context
fatal integration error  route/dialog appropriate to form factor
```

Compact layouts may use sheets/accordions but must expose the same failure codes/facts semantically.

## 30. Theme / contrast

P9 supports light/dark themes without changing vector/candidate semantics.

Requirements:

- semantic roles map to theme tokens;
- selected candidate is distinguishable without color alone;
- warning/blocker state has icon/text semantics;
- focus indicator visible on keyboard-capable surfaces;
- high-contrast platform settings are respected where framework support exists.

## 31. Reduced motion

When reduced motion / disable animations is active:

- carousel transitions become instant/minimal;
- pane transitions avoid non-essential movement;
- selection and navigation semantics unchanged;
- no operation relies on animation to communicate completion.

## 32. Platform semantic equivalence invariant

### P9-PLAT-INV-006

For identical:

```text
NormalizedApartmentRequest
P9VersionSet
catalog contents
scoring profile
```

all supported platforms MUST produce identical ordered candidate fingerprints.

Viewport dimensions, orientation, pointer type, theme, text scale and locale MUST NOT participate in generation/ranking fingerprints.

## 33. Renderer equivalence

Pixel-identical rendering is NOT required between native platforms because font rasterization and graphics backends differ.

Required equality is:

```text
same vector scene semantic fingerprint
same ordered vector primitives
same candidate geometry source
```

Visual regression tests may use platform-specific golden baselines where necessary.

## 34. Performance posture by device class

P9 hard algorithmic NFRs remain common.

UI performance additionally targets:

```text
continuous pan/zoom presentation target: 60 fps where device supports it
no synchronous candidate generation on UI thread if it exceeds frame budget
no rebuild of all candidate geometry on every pointer move
```

Qualification reports algorithmic latency separately from rendering frame behavior.

## 35. State restoration

P9 v2 does not require persistence of an unfinished Wizard session across application restart unless existing app architecture already guarantees it.

However within one live session, responsive changes, orientation, route/pane transitions and temporary background/foreground cycles MUST preserve recoverable transient Wizard state according to platform lifecycle support.

Canonical state remains unchanged until Apply.

## 36. Test device / viewport matrix

Minimum layout qualification:

```text
PHONE
390 x 844 portrait
844 x 390 landscape

TABLET
768 x 1024 portrait
1024 x 768 landscape
1366 x 1024 large tablet / desktop-class tablet

DESKTOP
800 x 600 minimum functional
1280 x 720 compact desktop
1440 x 900 normal desktop
1920 x 1080 large desktop
```

For each applicable width:

```text
textScale 1.0
textScale 1.3
textScale 2.0
RU
EN
light/dark at representative points
```

Not every Cartesian product must be screenshot-goldened, but the qualification suite MUST cover every dimension and representative intersections.

## 37. Input qualification matrix

Required automated/manual-semantic coverage:

```text
mouse + keyboard
trackpad/mouse zoom-pan
single-touch
multi-touch pinch
stylus-as-pointer where test infrastructure permits
hardware keyboard on tablet semantics
system back on mobile
window resize / orientation change
```

No required action may exist only under one modality.

## 38. Responsive architecture acceptance tests

```text
P9-PLAT-AT-001 same request yields same ordered candidate fingerprints at 390/900/1440 widths
P9-PLAT-AT-002 orientation change preserves request and selected candidate
P9-PLAT-AT-003 desktop window resize across breakpoints preserves Wizard state
P9-PLAT-AT-004 tablet split-screen breakpoint transition preserves Wizard state
P9-PLAT-AT-005 candidate order identical in carousel and desktop grid
P9-PLAT-AT-006 full semantic Diff reachable on COMPACT
P9-PLAT-AT-007 no mandatory action requires hover/right-click/long-press
P9-PLAT-AT-008 keyboard-only flow reaches Generate/select/Preview/Apply
P9-PLAT-AT-009 touch-only flow reaches Generate/select/Preview/Apply
P9-PLAT-AT-010 pinch/pan changes viewport only, never geometry fingerprint
P9-PLAT-AT-011 text scale 2.0 causes no essential action loss
P9-PLAT-AT-012 soft keyboard does not hide active field or Apply/Continue path
P9-PLAT-AT-013 reduced motion preserves exact state transitions
P9-PLAT-AT-014 selected candidate distinction does not depend on color alone
P9-PLAT-AT-015 screen-reader candidate summary excludes wall-segment noise
P9-PLAT-AT-016 system Back maps to Wizard semantic Back, not silent discard
P9-PLAT-AT-017 candidate generation is not simplified on phone
P9-PLAT-AT-018 vector scene semantic fingerprint identical across supported native platforms
```

## 39. Forward contract for P10-P14

P9 establishes reusable infrastructure that later CAD-heavy phases MUST extend rather than replace:

```text
responsive capability model
width-class policy
semantic navigation state
input-operation abstraction
preview viewport state
keyboard shortcut registry
pointer/touch/stylus mapping
focus/a11y policy
safe-area/window-resize policy
```

Expected reuse:

```text
P10 building/ЖК generation
  multi-candidate building/floor compare using same responsive candidate workspace

P11 EngineeringGraph
  same navigation/focus/input capability model

P12 engineering starter generation
  same Wizard/preview/diff responsive architecture

P13 auto-placement
  precise pointer + touch/stylus command mappings

P14 auto-routing
  CAD canvas pan/zoom/select interaction built on the same viewport/input abstraction
```

P10-P14 MAY add new semantic operations, but MUST NOT fork separate desktop/mobile domain models.

## 40. Forbidden architecture

Explicitly forbidden:

```text
mobile-specific generator algorithm
phone-specific reduced candidate quality
OS-specific candidate ordering
widget-local authoritative Wizard state
hover-only command
right-click-only command
long-press-only command
direct gesture -> canonical mutation without semantic command
SVG parsing into geometry
screen pixels as engineering coordinates
orientation change -> session regeneration
separate desktop/mobile transaction paths
```

## 41. Exit gate

The cross-platform contract is implemented when:

- one responsive capability model drives P9 layout;
- COMPACT/MEDIUM/EXPANDED/LARGE presentations preserve one Wizard state machine;
- desktop/tablet/phone expose the complete P9 decision flow;
- mouse/keyboard/touch and supported stylus paths map to common semantic operations;
- preview viewport state is non-canonical;
- P8 Preview/Diff remains semantically complete at every width;
- P9-PLAT acceptance matrix passes;
- candidate/vector-scene fingerprints are platform-equivalent;
- no desktop/mobile fork exists in domain/application generation logic.
