# ElecX macOS desktop UAT — 2026-11-08

**Technical Foundation: PARTIAL. Desktop User Journey: PARTIAL.**

A real native macOS window was built, launched and operated. An engineer can create a project/floor, draw rooms, place a board and load, connect a prototype group/route and reopen the persisted result. The complete requested named residential design and P12 engineering review cannot be declared PASS.

## Provenance and environment

- Repository: https://github.com/alimbetov/ElecX; existing PR #32.
- Only development branch: `feat/p12a8-engineering-preview-diff`.
- Exact starting SHA fetched from origin: `b4c4a85749d0ca3a9e912ad6256862078052f055`.
- Tested fix SHA: `0b7d527c255387c491adffe586d2af7825b93bdb` (inspector scrolling, compact navigation, widget/native integration tests). The following report/evidence commit does not change executable code.
- Worktree: `/Users/ruslanalimbetov/Documents/electra/ElecX-desktop-uat`.
- Original `ElecX` checkout remained on main at `6a1c93ef2a198d85c63543c5626bdc15f8f340cd`; its pre-existing edits to analysis_options.yaml/pubspec.lock were preserved. No merge, main development or push performed.
- macOS 15.6 (24G84), arm64; Flutter 3.47.7, Dart 3.13.5; Xcode 26.3 (17C529), CocoaPods 1.17.0.
- SDK explicitly invoked at `/Users/ruslanalimbetov/Documents/electra/flutter-sdk` because PATH pointed to a different Flutter/Dart installation.
- `flutter doctor -v`: macOS/Xcode and network available; warnings for PATH and missing Android SDK. Android is unrelated to the macOS target. Available devices: macOS desktop and Chrome. Desktop already enabled; no global Flutter feature settings changed.
- `flutter pub get` succeeded. sqlite3 3.9.0 uses the existing official system-source hook for macOS. No dependency pin/lockfile, SQLite transport, SHA-256 validation or signing/safety bypass was changed.
- Detailed evidence: `artifacts/desktop-uat/environment.json`, logs/flutter-doctor.txt, flutter-devices.txt, dependencies.txt, pub-get.txt.

## Executed journey and actual data

Native GUI, without direct database insertion or internal application API mutations:

1. Launch/close/relaunch and local four-digit unlock using 1234; hub and existing projects visible.
2. New Project and basic building wizard opened; default building generated/applied. CUA text insertion updated accessibility state without reliably updating visible Flutter text; those name attempts are not counted as product failures or successful named input.
3. Four rooms drawn through the toolbar's two-corner click interaction. Dimensions were 2.40×2.10 m for two rooms and 2.40×1.60 m for two rooms. Names remained Комната 1–4. Plan/Floor/Wall switching and selection were exercised.
4. On Комната 4: board on Floor; socket on compatible Wall 1. UI confirmation placed each component. Connected socket to board through its inspector. UI created one electrical group and one route.
5. Entered 1000 W and 230 V. Preliminary P/U indicator showed approximately 4.35 A, explicitly not a circuit design calculation. Assigned TEST user choice QF-1 / 16 A / 2P. This is test data, not a qualified protection recommendation. Cable form was inspected; no cable specification was committed. Missing-cable warning remained.
6. Save via UI; Cmd+Q; relaunch/unlock; open saved project. Hub showed 2 components / 1 route. Four rooms, selected-room identity, board/load link, route, power and protection were retained. `19-reopened-properties.ax.txt` records the restored identity and values.

Additionally, the new **native macOS integration test** starts the real app, uses UI taps/enterText, creates `ElecX Residential Acceptance`, enters `Building A`, generates the building preview, checks the Diff widget, applies geometry, draws four rooms, saves, returns to hub, reopens, checks all four room names and opens the compact engineering drawer. It does not seed objects via repositories/domain calls. The wizard default also creates Ground (level 0) and Level 1; the automated rooms are on Ground. The separate manual POWER project is on Level 1. It does not automate the POWER scenario or prove P12 Apply readiness. Repeated development runs create separate projects with the same acceptance name; these are distinct runs, not duplicate entities produced by one save.

Type=Residential, Purpose=Apartment electrical design, named Site and four requested room names were not fulfilled through production UI. These remain explicit gaps.

## Results and limitations

- Strict requested matrix: **4 of 9 rows PASS, 5 PARTIAL**. See USER_JOURNEY_MATRIX.md. All seven UAT areas were investigated; investigation is not equivalent to passing each case.
- Defects/gaps: **P0 0 / P1 1 / P2 6 / P3 1**. Two P2 fixed. The P1 is an explicitly planned P12 UI capability gap, not a regression of previously accepted production Apply.
- No observed data loss in the tested lifecycle. This does not certify all canonical POWER registries or all component types.
- No production P12 review screen was found for typed proposal/diff/evidence/safety diagnostics. Application/domain implementations exist. P9 Apartment Preview and the ordinary building wizard are distinct and must not be used as evidence of P12 UI completion.
- `readyToApply` remains false in the relevant evidence/safety proposal paths. Production Apply was not invoked, enabled or bypassed. No EngineeringGraph, schema or safety semantics changed.
- `+ Building / + Level / + Room` callbacks are absent from the production bootstrap; users must discover alternate rectangle/wizard paths. Full canonical structural dialog/materialization qualification and authoritative P12 input/evidence composition are needed before these broader P1/P2 gaps can safely be closed.

## Implemented correction

D01: removed the unconstrained stack of semantics, room-group overview and circuit status above the equipment inspector. A shared `EngineeringInspectorPanel` bounds and scrolls that context section and keeps a separate equipment/selection viewport. Both desktop sidebar and compact end drawer use it. No calculation, mutation ownership or persistence behavior changed.

D08: added an explicit compact AppBar action opening the existing engineering end drawer. This fixes the missing navigation path when a custom AppBar action list hides Flutter's automatic end-drawer button.

Widget regression cases at panel heights 400, 600 and 760 verify absence of layout exceptions and scroll/tap access to the load form with a connected circuit and tall semantics content. Native post-fix retest evidence is listed in SCREENSHOT_INDEX.md.

## Verification

| Check | Result | Evidence |
|---|---|---|
| Baseline flutter analyze | PASS, no issues | logs/analyze.txt |
| Baseline full flutter test | PASS, 2059 tests | logs/tests.txt |
| Inspector regression | PASS, 4 cases including compact navigation | logs/targeted-final.txt |
| Targeted panel/group/overview/hub suite after fix | PASS, 16 tests total, includes the 4 above | logs/targeted-final.txt |
| Final flutter analyze | PASS, no issues | logs/analyze-final.txt |
| Native UI integration | PASS, 1 test including compact drawer | logs/native-user-journey-with-drawer.txt |
| Native Save/Close/Reopen with engineering group | PASS for tested properties | screenshots/18*, 19* |

Native integration emitted a “Failed to foreground app; open returned 1” warning on its final run, but the test completed successfully; independent production GUI retests confirm actual visible behavior. Ephemeral localhost debugger URLs are omitted and trailing console whitespace is normalized in the saved run logs.

The native test was developed iteratively. Earlier failures remain in logs: a Diff finder incorrectly skipped a hidden compact tab; a transient saved Snackbar was asserted without waiting for file I/O; the reopen check initially used a custom navigator tooltip rather than Scaffold's menu icon. The final test waits for actual save completion and verifies reopened rooms. These earlier assertion failures are not reported as product defects.

After running the native integration runner, an ordinary incremental flutter run produced a black window; an extra test process was found and closed through the macOS app menu. Generated build files were then cleaned and `lib/main.dart` explicitly rebuilt. The clean main.dart build returned to the quick-unlock screen and normal projects. D01 was then visually verified at 1280×800 and native full screen: no overflow; scrolling reveals group actions; tapping the previously hidden Load action opens the expected form. Evidence: screenshots 23–25. The final compact navigation fix was then verified in ordinary production GUI at 800×628: the new button opens the drawer and scrolling exposes Load/Cable/Protection actions, without overflow (screenshots 26–27). No source/dependency workaround was introduced for this build transition. This is an observed build/run transition issue with an extra test runner; the exact incremental-cache root cause was not established.

## Display coverage

Real native screenshots: 800×628, 1280×800, maximized 1470×858, attempted 1440×900 clamped by macOS to 1440×858, and native full screen 1470×920 logical points, all captured at 2× pixel density. Exact 1440×900 normal-window verification is not claimed. No display settings changed.

## Release judgment and next work

Technical foundation is substantial: macOS build, SQLite system-source dependencies, canonical geometry path, editor interactions and tested persistence work. It remains PARTIAL because production UI/runtime composition for authoritative engineering review and complete structural authoring is unfinished.

The desktop journey is PARTIAL: useful room/equipment sketching and prototype electrical grouping can be performed and persisted, but the named residential brief and evidence-backed P12 review cannot be completed. GREEN CI is not used as a substitute for this result.

Priority next sprint: read-only P12 review and exact unavailable-gate guidance; supported named structure/project metadata; qualified structural action wiring; coordinated canvas overlays; first-run instructions and consistent localization. Keep production engineering Apply blocked until all existing evidence and safety acceptance gates are satisfied.
