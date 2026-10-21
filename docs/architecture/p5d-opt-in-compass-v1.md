# P5D — Opt-in Compass v1

## Status

Hardened architecture and implementation specification for `feat/p5d-opt-in-compass-design`.

This document incorporates two repository-level architecture reviews performed on 2026-10-21. The second hard audit is authoritative for implementation readiness:

```text
docs/architecture/p5d-architecture-audit-v2-2026-10-21.md
```

P5D follows P5C and must preserve the P5C canonical-navigation, controlled-hybrid, persistence-owner and fail-closed invariants.

ElecX remains native-only:

- macOS
- Windows
- Linux
- Android
- iOS
- iPadOS

Web/browser runtime is out of scope.

---

## 1. Objective

Add a discoverable, opt-in compass that communicates the canonical engineering orientation of the project without becoming:

- a second navigation model;
- a viewport-transform owner;
- a geospatial/true-north subsystem;
- a widget-owned persistence path;
- a bypass around P3 canonical mutation semantics.

The compass is hidden by default and appears only after an explicit user action.

The overlay answers one question only:

```text
Where is canonical Project North relative to the current plan view?
```

It must not imply magnetic north, GPS heading, survey north, geographic north, device heading, or verified true north.

[remaining content unchanged]
