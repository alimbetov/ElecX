# Desktop UX review

The app can open a real editable floor plan, draw rooms, place equipment and save/reopen a connected prototype electrical group. The requested residential workflow remains incomplete. This assessment uses real native window captures, not code-generated mockups.

## Discoverability

New Project is prominent. The first PIN screen does not explain which PIN to use; any four digits work in the current prototype. The navigator's primary structural buttons are disabled with no actionable explanation. The rectangle toolbar has a tooltip, but a first-time user must discover both the icon and the two-corner click gesture. Dragging did not create a room. A wizard icon beside the Site is less obvious than the disabled `+ Building` button.

Equipment discovery improves on a large window: the catalog has categories and a visible distribution board entry. The POWER workflow is presented as `Силовые` / `POWERAC`, not as an explicit discipline switch. Connecting a selected socket to a board is discoverable in the electrical-group card, and the app produces a group and route. The manual protection dialog correctly says it stores an engineer's decision and does not select a rating automatically.

## Workflow continuity and usability

Site → Building → Level → Room is present, with canonical IDs visible in accessibility output. Drawing rooms and selecting Plan/Floor/Wall works. Socket placement opens a compatible wall. A placement cursor requires explicit confirmation; Repeat remains active for the board until cancelled. Both are useful CAD concepts but need a clearer onboarding path.

The app does not expose the requested Type/Purpose fields, and no clear rename flow for Site/Level/drawn Rooms was found. Geometry authoring is therefore more complete than named project structure authoring. The engineer cannot complete the entire specified journey without undocumented knowledge. Large canvas HUDs obscure lower component controls. Internal terms such as “canonical” and raw component identifiers appear in product-facing UI.

## Functional completeness

Working native UI: local quick unlock, project hub, basic building wizard, rectangle rooms, dimensions/grid/snap display, selection, surface switching, equipment placement, board assignment, generated group/route, load power, user-selected protection parameters, P/U estimate and incomplete-data warnings, Save/Close/Reopen.

Partial: cable dialog accepts a text specification; calculation requires additional qualified inputs and is disabled in the exercised state. The P/U estimate is explicitly preliminary and is not a validated circuit calculation. The group shown in legacy editor UI is not evidence that P11/P12 canonical engineering selection, provenance and trusted evidence review are integrated.

Code-only / unqualified for this journey: P12 typed engineering proposal/diff, evidence admission/review, fault/coordination gates, reserved engineering candidate, typed canonical POWER selection persistence. No production P12 review screen was found. P9 Apartment Engineering Preview is a separate feature gated by a source-backed runtime pipeline. These are integration/scope gaps, not proof that safety gates are broken.

## Visual maturity

The dark CAD workspace has a consistent technical palette, useful selection handles, dimensions and surface preview. It still feels like several engineering prototypes connected together: English/Russian/internal identifiers mix, structural controls are unavailable, the sidebar stacks too much content, and status overlays dominate the canvas. Stronger visual polish alone would not resolve missing workflow integration.

The compact inspector initially lacked a visible open action; an explicit AppBar button is now added and covered by regression tests. The confirmed sidebar RenderFlex overflow is fixed using a bounded scroll section shared between desktop and drawer. Equipment/selection keeps a separate viewport. Final native retest screenshots in SCREENSHOT_INDEX document the result. Contrast was visually adequate for primary labels/actions; dim dimension/grid text can be difficult to read. No instrumented WCAG contrast audit was performed.

## Window coverage

- Initial native window: 800×628 logical points, captured as 1600×1256 pixels (2×).
- 1280×800 window: real 2560×1600 PNG; core desktop layout exercised.
- Requested 1440×900 window was attempted by dragging the native resize corner; macOS clamped available window height to 858 points. Actual capture: 2880×1716 pixels (1440×858). Do not claim a successful 1440×900 native window check.
- Native full screen: 1470×920 logical points, 2940×1840 PNG. Baseline sidebar still overflowed by 31 px.
- Maximized normal window: 1470×858 logical points.

Exact 1440×900 native window acceptance remains unverified on this display arrangement. No system display settings were changed.

## Data integrity

A native process restart restored four rooms, board, socket, one group/route, 1000 W at 230 V, and QF-1/16 A/2P. Hub counters were 2 components / 1 route. The reopened accessibility transcript preserves the canonical selected-room ID and component/route identity. No duplicate rooms or lost tested properties were observed. Repeated automated runs intentionally create independently identified acceptance projects; identical project names from those runs are not persistence duplication.

This does not certify every canonical registry or every subsystem's lifecycle. No objects were manually inserted into the database and no safety gate was bypassed.

## Next sprint priorities

1. Complete read-only P12 Engineering Preview/Diff integration with authoritative evidence and explicit blocked-Apply reasons.
2. Connect structural authoring controls to qualified request dialogs/geometry workflows; add rename and project metadata support through canonical contracts.
3. Coordinate canvas overlays and expose a compact status HUD; make rectangle and placement gestures explicit.
4. Explain unavailable calculation and apartment wizard inputs, and provide an actionable first-run quick-unlock message.
5. Consolidate localization and remove internal implementation terminology from routine screens.


## Advanced routing retest — 2026-11-09

See [Multi-surface routing acceptance](MULTI_SURFACE_ROUTING_FINAL_REPORT.md) on baseline 9f15d985. P12 toolbar review now exists (supersedes earlier missing-entry finding); source remains unavailable and Apply blocked. Five-room/nine-component/local Wall→Ceiling save-reopen verified; required cross-room/canonical branching acceptance BLOCKED. Earlier basic UAT observations remain historical, not proof of advanced routing.
