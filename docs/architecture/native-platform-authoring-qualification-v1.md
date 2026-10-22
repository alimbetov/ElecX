# Native Platform Authoring Qualification v1

Branch: `feat/project-structure-authoring`

## Purpose

This document defines the cross-platform authoring contract for the project-structure roadmap without turning every platform runtime into a blocking gate for each architecture stage.

ElecX remains a native application with one canonical engineering model and platform-adaptive interaction layers.

Supported native targets:

```text
Desktop
├── macOS
├── Windows
└── Linux

Mobile / tablet
├── Android
├── iOS
└── iPadOS
```

Web/browser remains out of scope.

## Delivery rule

Development is desktop-first, not desktop-specific.

An architecture stage may close after its current executable qualification gates pass, provided that the implementation preserves the cross-platform invariants in this document.

Therefore:

```text
P6 semantic/domain closure
        │
        ├── current macOS qualification gate
        │
        └── MUST preserve portability invariants
                │
                ▼
             P7 may start
```

Windows, Linux, Android, iOS and iPadOS qualification are mandatory product-delivery tracks, but they do not retroactively block P6 closure or prevent P7 implementation unless a platform test exposes a real domain/application portability defect.

## Qualification levels

Do not use one ambiguous `DONE` flag for platform readiness.

Track two independent dimensions:

```text
Architecture readiness
- canonical semantics are platform-independent
- commands and mutation contracts are shared
- persistence format/identity is shared
- no platform-specific engineering state exists

Platform qualification
- application analyzes/builds/runs on the target
- input/lifecycle/adaptive UI behavior is exercised
- persistence runtime works on the target
- target-specific regressions are resolved
```

A stage may be `DONE + HARDENED` for domain/application semantics while some target-platform qualification remains pending.

## Non-negotiable cross-platform invariants

### Canonical model

All native targets MUST use the same:

- `ProjectId`, `SiteId`, `BuildingId`, `LevelId`, `ZoneId`, `SpaceId` and later stable topology identities;
- canonical project aggregate semantics;
- project mutation/version rules;
- `ProjectChangeSet` and undo/redo semantics;
- project persistence schema/codec semantics;
- future revision-aware sync contract.

There MUST NOT be a desktop project model and a separate mobile project model.

### Command parity

The same semantic user intention MUST reach the same application/domain command regardless of device class.

Example:

```text
Desktop inspector
        ┐
Mobile bottom sheet
        ├──> ChangeSpaceUsageCommand
Tablet side panel
        ┘
```

The input modality is allowed to differ. The committed engineering result is not.

### Platform code boundaries

Platform-specific behavior belongs in UI/runtime adapters.

The following are forbidden in domain/application semantics:

- `Platform.isMacOS`, `Platform.isWindows`, `Platform.isLinux`, `Platform.isAndroid`, `Platform.isIOS` branches that change engineering meaning;
- macOS-only file paths or identifiers;
- keyboard shortcuts as the only path to a semantic operation;
- mouse hover as a required prerequisite for an engineering operation;
- right-click/context-menu-only authoring actions;
- device-specific identifiers as persistent engineering identities;
- platform-specific project schemas or migrations.

`dart:io`, path-provider integration and native filesystem concerns remain outside domain/application code.

## Desktop interaction contract

Desktop targets are:

```text
macOS
Windows
Linux
```

Primary input channels:

- mouse;
- keyboard;
- trackpad;
- wheel/precision scrolling;
- desktop dialogs, menus and inspectors.

Desktop-specific UX MAY expose richer persistent panels, menu accelerators and hover affordances.

These affordances MUST remain optional interaction accelerators. They MUST NOT own canonical state or create a second mutation path.

Keyboard conventions may adapt per OS, for example Command vs Control, while invoking the same semantic action.

## Tablet interaction contract

Tablet is a first-class authoring target, not merely a stretched phone layout.

Primary expected inputs:

- touch;
- stylus / Apple Pencil where available;
- hardware keyboard;
- trackpad/mouse where available;
- orientation changes;
- split-view / constrained-width layouts.

Tablet must eventually support full project-structure authoring semantics.

Adaptive presentation may use:

- side inspector when width allows;
- bottom/side sheets under constrained width;
- touch-first controls;
- precision/stylus affordances.

The same command, version guard, validation and persistence path used by desktop remains authoritative.

## Phone interaction contract

Phone is optimized for field use and constrained viewports.

The architecture MUST allow:

- project navigation;
- review/inspection;
- lightweight structural edits where product UX exposes them;
- room/space semantic editing;
- field corrections and verification;
- future measurements/commissioning workflows.

Phone UX is not required to mirror the desktop layout. It is required to preserve semantic parity for every operation it exposes.

## Touch and accessibility invariants

Any command exposed on touch targets MUST remain operable without hover, right click or precision mouse movement.

Required design constraints:

- minimum practical touch targets remain consistent with the existing 48dp project baseline;
- active/current/selected state cannot be encoded by color alone;
- focus state and semantics remain available where keyboard/accessibility services are present;
- cancellation and destructive confirmations must be available on touch;
- transient hover/preview state must never become required persisted state;
- orientation/layout changes must not silently mutate the engineering project.

## P6 portability contract

P6 owns semantic spaces, `SpaceUsage`, adjacency/opening semantics and overlay classification.

P6 MUST remain portable across all supported native targets at the domain/application level.

The following P6 properties are required before hand-off to P7:

- space semantics do not depend on translated display labels;
- semantic edits use canonical commands/mutation contracts;
- semantic edits preserve stable `SpaceId`;
- persistence round-trips semantic state independently of UI platform;
- undo/version behavior is platform-independent;
- inspector presentation is replaceable by adaptive desktop/mobile/tablet shells;
- no semantic command requires hover, right click, macOS key bindings or desktop-only layout state;
- no P6 state introduces a durable `wallIndex` foreign key.

## P6 closure policy

The current P6 executable closure gate remains:

```text
dart format
flutter analyze
flutter test
macOS analyze
macOS test
macOS debug build
runtime path_provider smoke
```

Once these gates pass on the final authored branch HEAD, P6 may be marked:

```text
P6 domain/application: DONE + HARDENED
macOS qualification: PASS
```

The following statuses may remain independently pending without blocking P7:

```text
Windows qualification: PENDING
Linux qualification: PENDING
Android qualification: PENDING
iOS qualification: PENDING
iPadOS/tablet qualification: PENDING
```

This is permitted only while the cross-platform invariants above remain satisfied.

## Regression rule

A later platform qualification failure is classified by root cause.

### Platform-adapter defect

Examples:

- Windows packaging;
- Linux plugin registration;
- Android lifecycle binding;
- iOS permission/runtime wiring;
- adaptive layout overflow.

These defects block that platform qualification but do not reopen completed domain stages by default.

### Architecture portability defect

Examples:

- domain code assumes macOS path behavior;
- semantic operation only exists through a keyboard shortcut;
- canonical state contains platform-specific identifiers;
- save/reopen produces different engineering state across platforms;
- touch path requires hover-owned state;
- mobile operation bypasses canonical mutation/version semantics.

These defects MUST reopen the responsible architecture stage as regressions and be fixed at the source boundary.

## P7 hand-off rule

P7 is NOT blocked by waiting for all target-platform CI environments.

P7 may start when:

1. P6 current closure gates pass;
2. P6 portability invariants are documented and preserved;
3. no known P6 domain/application code has a platform-specific semantic dependency.

P7 itself must follow the same portability rule for:

- `BoundaryEdgeId`;
- boundary lineage;
- wall-host migration;
- vertical topology;
- typical-floor lineage.

Stable topology identities must be device- and platform-independent from their first implementation.

## Roadmap integration

The intended execution model is:

```text
P6 semantic closure
        │
        ├── macOS qualification
        └── portability contract
        │
        ▼
P7 stable topology
        │
        ├──────────────┐
        │              │
        ▼              ▼
P8 generation      platform qualification tracks
                   ├── Windows
                   ├── Linux
                   ├── Android
                   ├── iOS
                   └── iPadOS
```

Platform qualification may run in parallel with later architecture work.

It must not create divergent domain models, command paths or persistence formats.

## Product-mode guidance

The intended interaction emphasis is:

```text
Desktop
precision-first full authoring

Tablet
full authoring with touch/stylus/keyboard/trackpad adaptation

Phone
field-first review, verification and lightweight authoring
```

This is a UX prioritization rule, not a domain capability fork.

## Final rule

ElecX has one engineering project model.

Platforms adapt how users interact with it; platforms do not redefine what the project means.
