# P8 Wizard Responsive UX + Apartment Carousel Contract v1

## Status

Mandatory UX addendum for `feat/p8-wizard-preview-diff`.

This document specializes the presentation requirements of:

- `docs/architecture/p8-wizard-preview-diff-implementation-v1.md`;
- `docs/architecture/project-template-wizard-v1.md`;
- `docs/architecture/apartment-topology-catalog-v1.md`.

If a generic Wizard layout requirement conflicts with this document for responsive presentation or apartment variant selection, this document wins. Domain, identity, mutation, persistence and generation semantics remain governed by the foundation architecture.

## Product objective

Wizard must be equally usable on:

```text
phone
small tablet
large tablet / iPad
laptop
desktop / large monitor
```

The same Wizard session, typed parameters, candidate identities, semantic diff and commit lifecycle are reused on all form factors. Responsive presentation must never change project semantics.

For apartment generation, topology variants are selected through a first-class horizontally scrollable **SVG/vector apartment carousel**. The carousel is not decorative. It is the canonical user interaction for comparing and selecting generated apartment candidates before the normal P8 preview/diff step.

## UX invariants

### UX-I01 — Responsive by available width

Layout decisions use the Wizard surface's available logical width, not platform name, OS, model name or hard-coded `isTablet` checks.

Orientation changes, split-screen, desktop window resize and tablet stage-manager resizing must reflow without restarting the Wizard or regenerating candidates.

### UX-I02 — One session across reflow

Responsive re-layout must preserve:

```text
selected provider
entered parameters
validation state
candidate list
selected candidate id
carousel position where practical
preview state
reserved preview/apply lifecycle
```

A resize must not create a new Wizard session, allocate new candidate identities or mutate the canonical project.

### UX-I03 — Touch first, pointer complete

Every primary flow must work with touch alone and with mouse/trackpad + keyboard alone.

No essential action may depend on hover.

### UX-I04 — Apartment carousel is mandatory

When a provider exposes multiple apartment topology candidates, the UI MUST present them as a horizontally navigable carousel with snap-to-candidate behavior.

A static vertical list or dense grid is not the primary selector.

### UX-I05 — Selection is explicit

Scrolling the carousel changes focus/inspection only after snap completion. The selected candidate is always visually unambiguous and represented by stable `WizardCandidateId`, never by transient list index alone.

### UX-I06 — Preview is lightweight

Carousel cards render the provider's `WizardPreviewScene`/SVG-compatible vector projection. They must not instantiate a full editable project canvas for every card.

### UX-I07 — No semantic divergence

The SVG/vector card, enlarged preview and committed candidate all refer to the same semantic candidate. SVG is a projection, never the source of project geometry.

## Adaptive width classes

Use Flutter logical pixels from the actual Wizard content constraints.

Recommended v1 classes:

```text
compact   < 600
medium    600..899
expanded  900..1399
wide      >= 1400
```

These thresholds are presentation defaults, not persisted business semantics. Small tuning is permitted during qualification only if the UX behavior and tests remain equivalent.

Do not branch on Android/iOS/macOS/Windows/Linux to choose the structural layout.

## Shell composition by width

### Compact — phone / narrow split-screen

Primary composition:

```text
┌──────────────────────────────┐
│ title + progress             │
├──────────────────────────────┤
│ current step                 │
│                              │
│ parameters OR carousel       │
│ OR preview/diff              │
│                              │
├──────────────────────────────┤
│ sticky Back / Continue       │
└──────────────────────────────┘
```

Rules:

- one primary column;
- no permanently visible secondary inspector;
- parameters use full available width;
- validation is inline near the field plus an optional compact summary;
- primary navigation is sticky above safe-area/insets;
- detail/semantic diff opens as the next Wizard step or a full-height sheet;
- no horizontal page-level overflow;
- carousel itself remains horizontal and gesture-driven.

### Medium — portrait tablet / large phone landscape

Primary composition:

```text
┌────────────────────────────────────────┐
│ title + progress                       │
├────────────────────────────────────────┤
│ main step content                      │
│                                        │
│ carousel / preview takes priority      │
│ parameter groups may form 2 columns    │
├────────────────────────────────────────┤
│ sticky Back / Continue / Apply         │
└────────────────────────────────────────┘
```

Rules:

- one or two parameter columns depending on field width;
- carousel shows selected card plus meaningful neighboring context;
- preview may use a bottom/side details pane when space allows;
- no desktop-only micro-controls.

### Expanded — landscape tablet / laptop

Primary composition:

```text
┌──────────────────────────────────────────────────────────────┐
│ title + progress                                            │
├──────────────────────┬───────────────────────────────────────┤
│ parameters           │ candidate / preview workspace         │
│ 280..360 logical px  │                                       │
│                      │ carousel                              │
│                      │ enlarged selected preview             │
│                      │ summary / warnings                    │
├──────────────────────┴───────────────────────────────────────┤
│ Back                                      Continue / Apply   │
└──────────────────────────────────────────────────────────────┘
```

Rules:

- left parameter rail remains visible where this does not squeeze preview below usability;
- candidate browsing and enlarged preview stay on the same surface;
- semantic diff can appear as a collapsible side/bottom inspector;
- no modal dialog is required for ordinary candidate switching.

### Wide — desktop / large monitor

Primary composition:

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ Wizard title / progress / context                                          │
├───────────────────┬──────────────────────────────────────┬─────────────────┤
│ Parameters        │ Preview workspace                    │ Diff / details  │
│ 300..380          │                                      │ 320..420        │
│                   │ large selected topology             │ summary         │
│                   │                                      │ warnings        │
│                   │ apartment carousel                   │ semantic diff   │
├───────────────────┴──────────────────────────────────────┴─────────────────┤
│ Back                                                       Apply           │
└────────────────────────────────────────────────────────────────────────────┘
```

Rules:

- support efficient comparison without forcing dialog chains;
- keep the selected apartment preview large enough to inspect room topology;
- right diff/details panel may collapse to enlarge the plan;
- resizing down to expanded/medium must preserve state and selection.

## Apartment topology carousel

### Role

The apartment topology carousel displays the bounded candidate set returned by P9, normally 3..6 candidates.

Conceptual flow:

```text
ApartmentWizardParameters
        ↓
ApartmentTopologyCandidate[]
        ↓
WizardPreviewScene[]
        ↓
ApartmentTopologyCarousel
        ↓
selected WizardCandidateId
        ↓
large preview + candidate facts
        ↓
normal P8 preview/diff
```

### Card content

Each card should contain only decision-relevant information:

```text
SVG/vector mini-plan
variant/family name
approximate total area
habitable-room count
bathroom count
balcony/loggia indicator when applicable
short score/fit label if meaningful
warning badge when candidate is valid but notable
```

Do not overload cards with detailed engineering metadata.

Detailed facts belong in the selected-candidate inspector/preview.

### Card geometry

Cards use a stable aspect ratio so scrolling does not jump as candidate content changes.

The SVG/vector plan should occupy most of the card area.

Text must remain readable without zooming on supported phone widths.

### Responsive carousel density

The carousel adapts visible context while preserving one selected item.

Recommended behavior:

```text
compact:
  ~1.10..1.20 cards visible
  selected card centered
  sliver of next/previous card communicates horizontal affordance

medium:
  ~1.35..2.20 cards visible depending on width
  selected card remains dominant

expanded:
  ~2.2..3.4 cards visible
  selected card emphasized

wide:
  ~3..5 cards visible
  selected card may be larger than neighbors or centrally emphasized
```

Exact viewport fractions may be tuned, but qualification must preserve visible neighboring context and an obvious selected card.

### Snap behavior

Carousel MUST snap to one candidate after gesture/scroll completion.

Requirements:

```text
one stable selected WizardCandidateId;
no resting state halfway between two candidates;
fast swipe may advance multiple candidates but ends on one item;
selection callback fires only when the settled candidate changes;
programmatic selection scrolls the selected card into a predictable focal position.
```

Do not use raw pixel offset as candidate identity.

### Candidate ordering

Provider ordering is deterministic.

P9 should normally order candidates by a stable score/ranking policy, with deterministic tie-breaking.

The carousel must not reshuffle candidates as SVG cards lazily render.

### Indicators

Compact/medium surfaces SHOULD expose a lightweight position indicator:

```text
● ○ ○ ○
2 / 5
```

Use whichever is clearer for the number of candidates; do not duplicate both if unnecessary.

On expanded/wide surfaces, neighboring cards often provide enough position context, but keyboard focus and selected styling remain mandatory.

## Input modalities

### Touch

Required:

```text
horizontal swipe/drag;
tap card to select and snap;
tap selected card or explicit action to inspect enlarged preview;
minimum primary touch target 48x48 logical px;
no tiny pagination arrows as the only navigation mechanism.
```

Vertical page scrolling and horizontal carousel scrolling must be gesture-arbitrated predictably. A mostly horizontal gesture belongs to the carousel; a mostly vertical gesture should continue page scrolling where applicable.

### Mouse

Required:

```text
click card to select;
visible previous/next controls on pointer-rich expanded/wide layouts when useful;
horizontal wheel/trackpad scroll;
Shift + vertical wheel may map to horizontal carousel movement where Flutter/platform behavior supports it naturally;
drag-to-scroll may be supported but must not be the only pointer mechanism.
```

### Trackpad

Two-finger horizontal scrolling must feel native and must snap after the gesture settles.

Do not fight high-resolution momentum scrolling with excessive programmatic jumps.

### Keyboard

When carousel or a card has focus:

```text
Left / Right     previous / next candidate
Home             first candidate
End              last candidate
Enter / Space    select focused candidate when selection is distinct
```

Tab navigation must move through logical controls without requiring a user to tab through every SVG primitive.

On desktop, keyboard selection must scroll the card into view.

## Focus, hover and selection

These are separate states:

```text
focused candidate
hovered candidate
selected candidate
```

Hover is visual assistance only.

The selected state MUST be distinguishable without color alone. Use at least one additional signal such as border weight, check/selected icon, elevation/scale or explicit label.

Keyboard focus MUST have its own focus indicator even when the candidate is already selected.

## Accessibility and semantics

Each candidate card is one semantic control; internal SVG paths are not exposed individually to the accessibility tree.

Suggested semantic description:

```text
"Вариант 2 из 5, угловая планировка, 78 квадратных метров, 3 комнаты, 1 санузел, лоджия. Выбран."
```

Semantic text comes from typed candidate metadata, not OCR/SVG text extraction.

Requirements:

- screen-reader traversal order follows deterministic carousel order;
- selected state is announced;
- warning/blocker state is announced;
- text scale must not clip critical actions;
- cards must remain operable with large text even if metadata wraps;
- reduced-motion preference should suppress nonessential scale/physics flourish while preserving clear snapping/selection.

## SVG/vector rendering contract

Apartment cards consume the P8 `WizardPreviewScene` abstraction.

Pipeline:

```text
semantic candidate
   ↓
WizardPreviewScene
   ├── polygons
   ├── lines
   ├── labels
   └── markers
   ↓
Flutter CustomPainter / vector renderer
   ↓
optional deterministic SVG serialization
```

Rules:

- no WebView;
- no DOM/JavaScript dependency;
- no external URLs inside generated SVG;
- no remote font requirement;
- deterministic viewBox/coordinate transform;
- candidate scene uses integer-mm semantic geometry before display scaling;
- card renderer fits scene to bounds with stable padding;
- text labels may be selectively simplified on tiny cards but semantic topology must not be changed;
- enlarged preview can render more labels/details from the same scene.

## Carousel performance

The bounded P9 set is small, but implementation must still avoid unnecessary rebuilds.

Requirements:

```text
candidate semantics immutable while displayed;
cache/reuse computed WizardPreviewScene per candidate;
do not regenerate apartment topology during every carousel frame;
do not rebuild canonical ProjectAggregate while swiping;
repaint only cards whose visual state changed where practical;
pre-render/pre-cache selected candidate and immediate neighbors;
lazy render farther candidates if future catalogs grow;
```

For current P9 3..6 candidates, keeping lightweight vector scenes resident is acceptable.

Animation target should remain visually smooth on supported mobile/tablet hardware. Qualification should detect obvious jank but must not encode platform-specific project semantics.

## Selected candidate workspace

Carousel and enlarged selected preview are synchronized by `WizardCandidateId`.

### Compact

Recommended:

```text
[ carousel card ]
[ candidate facts ]
[ View larger ]
[ Continue ]
```

`View larger` may open a full-screen preview sheet/page with pinch-to-zoom/pan for inspection. Zoom/pan is transient presentation state.

### Medium

Recommended:

```text
[ horizontal carousel ]
[ enlarged selected plan ]
[ candidate facts / warnings ]
```

### Expanded/Wide

Recommended:

```text
parameters | enlarged selected plan | details/diff
           | carousel                |
```

The carousel remains available while inspecting the large preview so the user can switch variants without backing out.

## Zoom and inspection

Mini-card SVG plans are fit-to-card and are not independently zoomable.

Enlarged preview SHOULD support:

```text
pinch zoom on touch;
trackpad pinch where available;
mouse wheel + modifier or explicit zoom controls;
pan after zoom;
Fit to view;
Reset view.
```

Zoom/pan changes must not alter candidate geometry or diff.

## Wizard navigation ergonomics

Primary action placement must be predictable.

### Compact/Medium

Use a sticky bottom action bar:

```text
[ Back ]                    [ Continue ]
```

On final preview:

```text
[ Back ]                       [ Apply ]
```

Respect system safe areas and software keyboard insets.

### Expanded/Wide

Actions may remain in a persistent footer or a consistent lower-right command area.

Do not move `Apply` between unrelated corners across steps.

`Cancel` is secondary and must not sit where an accidental thumb tap is likely to hit it instead of Continue/Apply.

## Parameter form ergonomics

Parameter groups are progressive and semantic.

Apartment v1 should favor understandable inputs:

```text
rooms
approximate area
bathrooms
balcony/loggia
kitchen mode
corridor preference
advanced topology preferences
```

Advanced inputs such as facade sides/aspect ratio may be collapsed initially when not required.

Rules:

- numeric fields expose appropriate mobile keyboards;
- increment/decrement controls must not be the only way to enter large values;
- validation appears close to the relevant field;
- changing a parameter marks current generated candidates stale and requires/regenerates a new candidate set according to the session policy;
- avoid triggering heavy regeneration on every keystroke; debounce or explicit Generate/Update may be used for expensive providers;
- preserve entered values when moving back/forward.

## Variant regeneration behavior

When parameters materially change:

```text
existing candidate set → stale draft UI state
new deterministic generation → new candidate set
```

The UI must not pretend an old SVG remains valid for new parameters.

If the previously selected semantic variant is still present with the same stable draft key, it may remain selected; otherwise selection falls back deterministically, normally to the top-ranked candidate.

No canonical project mutation occurs during this process.

## Visual hierarchy

The selected apartment plan is the main visual object.

Priority:

```text
1. selected topology drawing
2. primary candidate facts
3. warnings / fit information
4. other candidates
5. secondary explanatory text
```

Do not make the card chrome visually heavier than the plan.

Do not require the user to read long descriptions to understand candidate differences.

## Responsive failure rules

The following are release blockers:

```text
horizontal overflow of the Wizard shell on supported compact widths;
primary Apply/Continue obscured by safe area or keyboard;
SVG card cropped so topology is not recognizable;
carousel cannot be operated by touch;
carousel cannot be operated by keyboard on desktop;
selection is ambiguous between neighboring candidates;
window resize loses parameters/candidates/selection;
orientation change restarts Wizard;
text scaling hides primary actions;
carousel gesture prevents normal vertical page use;
hover-only required action;
platform-specific candidate ordering or geometry.
```

## Suggested Flutter presentation decomposition

Presentation-only names may vary, but responsibility should remain separated.

```text
WizardResponsiveShell
├── WizardProgressHeader
├── WizardAdaptiveStepBody
├── WizardParameterPanel
├── ApartmentTopologyCarousel
│   ├── ApartmentTopologyCard
│   ├── CarouselNavigationControls
│   └── CarouselPositionIndicator
├── WizardSelectedCandidatePreview
├── WizardCandidateFacts
├── WizardDiffPanel
└── WizardActionBar
```

Application/domain code must not import these widgets.

Suggested state boundary:

```text
WizardSessionController
    ↓ immutable view state
WizardResponsiveShell
    ↓
ApartmentTopologyCarousel(selectedCandidateId, candidates)
```

The carousel receives candidate view models and emits intent such as `selectCandidate(id)`; it does not mutate project state.

## Qualification matrix

The following scenarios are mandatory in addition to the main P8 qualification suite.

```text
UX01 compact width <600 has no shell horizontal overflow
UX02 compact carousel shows one dominant card plus neighboring affordance
UX03 touch swipe snaps to one stable candidate
UX04 tapping a neighboring card selects and snaps it
UX05 selected candidate survives compact ↔ medium reflow
UX06 selected candidate survives portrait ↔ landscape
UX07 parameters survive window resize
UX08 candidate set is not regenerated merely by resize
UX09 medium layout exposes useful neighboring candidate context
UX10 expanded layout supports parameters + preview concurrently
UX11 wide layout supports preview + carousel + diff without modal chain
UX12 mouse click selects a candidate
UX13 horizontal trackpad scroll navigates carousel
UX14 keyboard Left/Right navigates candidates
UX15 Home/End selects/focuses first/last candidate predictably
UX16 keyboard selection scrolls candidate into view
UX17 focus indicator is visible independently of selected state
UX18 selected state is distinguishable without color alone
UX19 screen reader announces candidate index + semantic facts + selection
UX20 SVG internals do not flood accessibility traversal
UX21 large text does not hide Apply/Continue
UX22 safe-area bottom inset does not obscure action bar
UX23 software keyboard does not make current required field/action unreachable
UX24 vertical page scroll and horizontal carousel gesture arbitration is stable
UX25 enlarged preview zoom/pan does not alter candidate/diff
UX26 carousel card rendering does not mutate LocalProjectVersion
UX27 carousel navigation does not change Undo depth
UX28 candidate order is deterministic for same generation result
UX29 mini preview and enlarged preview refer to same WizardCandidateId
UX30 committed candidate equals candidate selected/previewed before Apply
UX31 stale candidate set after parameter change cannot be applied as current
UX32 compact/medium/expanded/wide produce the same canonical result for same selected candidate
UX33 SVG serialization has no scripts/external URLs
UX34 candidate card fits topology without clipping semantic envelope
UX35 carousel remains usable with 3 candidates
UX36 carousel remains usable with 6 candidates
UX37 pointer hover is not required for any primary action
UX38 reduced-motion mode keeps selection/snap understandable
UX39 rapid swipes settle on exactly one candidate
UX40 double Apply cannot commit twice after carousel selection
```

Widget/golden tests should cover representative logical sizes rather than only named devices, for example:

```text
390x844      compact phone portrait
844x390      compact/medium phone landscape depending actual content width
768x1024     tablet portrait
1024x768     tablet landscape
1280x800     laptop / expanded
1440x900     wide desktop threshold neighborhood
1920x1080    wide desktop
```

Tests should also include constrained split-screen widths on tablet/desktop.

## Definition of Done

Responsive/carousel UX is complete only when:

```text
- one Wizard session survives all adaptive reflows;
- apartment variants use the mandatory horizontal snapping carousel;
- touch, mouse/trackpad and keyboard are all qualified;
- selected candidate is represented by WizardCandidateId, not carousel index;
- SVG/vector mini-previews are deterministic projections of candidate scenes;
- compact flow is one-column and thumb-operable;
- tablet flow uses additional space without becoming a stretched phone UI;
- desktop flow uses concurrent panels without forcing unnecessary dialogs;
- accessibility semantics are candidate-level, not SVG-path-level;
- no responsive action mutates canonical project state;
- same candidate produces the same canonical commit on every supported native form factor.
```

## Non-negotiable conclusion

ElecX Wizard is not a desktop dialog scaled down to mobile and not a mobile page stretched across desktop.

It is one adaptive native workflow with four width classes and one shared semantic session.

For apartment generation, the visual decision point is a smooth, snapping SVG/vector topology carousel:

```text
parameters
→ deterministic apartment candidates
→ swipe / scroll / arrows through SVG cards
→ select one topology
→ inspect enlarged preview
→ review semantic diff
→ Apply exact frozen candidate
```

The carousel is presentation only; canonical project truth remains the typed candidate and the existing P8 preview/commit pipeline.