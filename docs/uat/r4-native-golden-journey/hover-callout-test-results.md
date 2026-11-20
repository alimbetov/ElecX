# UX-HOVER-01 — implementation & qualification record

**Branch:** `feat/p12a8-engineering-preview-diff`  
**Implementation baseline:** `471313768fb81143b1c0d73d22aa086068f28ffa` (spec)  
**Implementation HEAD at report creation:** `5eca8b4d2f507e2447e2da92540944646de5d6ca`  
**Verdict:** `PARTIAL / NATIVE NOT QUALIFIED` — CI and native UAT must still be verified on the exact final SHA.

## Scope implemented

- `lib/src/features/editor/engineering_hover_callout.dart`: ephemeral view model, hover delay, fade, animated line/card glow, reduced-motion suppression, boundary-aware positioning, `IgnorePointer` overlay.
- `lib/src/features/editor/surface_canvas.dart`: reuse of `_componentAt`, `_SurfaceProjection.surfaceToViewport`, cancellation upon pointer exit/down and suppression during cable/component manipulation.
- `lib/src/features/editor/editable_spatial_canvas.dart`: callout from existing plan equipment markers, without native system Tooltip collision.
- `test/features/editor/engineering_hover_callout_test.dart`: delay, cancellation, switch, reduced-motion smoke.

## Architecture / invariants

The implementation does not change `EngineeringGraph`, persisted cable/electrical entities, JSON serialization, or routing engines. The callout is read-only and excluded from pointer hit-testing. Technical purpose strings are **type-generic descriptions**, not claims about actual connected circuits or device ratings.

## Limitations and follow-ups

1. Native macOS interaction was **not** run by this authoring environment. Obtain genuine screenshots and a short recording before claiming UX-HOVER PASS.
2. Cable route / segment-specific hover descriptions are not wired yet. Existing cable-edit pointer priority must be preserved before extending support.
3. Full R4: device drag, port-to-port connection, manual route editing, save/reopen is a **separate release gate** and remains HOLD until qualified.
4. CI workflow runs may produce new analyzer/formatter/test findings; resolve these against the exact HEAD and update the report.
5. Screen reader/focus alternatives and long-text localization require a dedicated accessibility check.

## Commands for qualification

```sh
git fetch origin
git checkout feat/p12a8-engineering-preview-diff
git rev-parse HEAD
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/features/editor/engineering_hover_callout_test.dart
flutter test
flutter run -d macos -t lib/main.dart
```

## Native visual matrix

| Scenario | Status |
| --- | --- |
| Socket hover with line and card | NOT TESTED |
| Switch/luminaire/panel hover | NOT TESTED |
| Pointer exit and fast target switch | NOT TESTED |
| Smooth glow pulse / reduced motion | NOT TESTED |
| Zoom, pan, viewport edges | NOT TESTED |
| Hide on component drag and route editing | NOT TESTED |
| Port connection priority | NOT TESTED |
| Save/reopen domain snapshot unchanged | NOT TESTED |

No screenshot or video evidence is claimed here. Do not merge with `main` based only on source changes.
