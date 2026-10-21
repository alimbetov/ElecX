# Native project portability and backend sync

## Status

Accepted architectural invariant for ElecX.

## Supported platforms

ElecX is a native application. The supported runtime targets are:

```text
Desktop
├── macOS
├── Windows
└── Linux

Mobile
├── Android
├── iOS
└── iPadOS
```

Browser/Web runtime is intentionally out of scope.

## Product invariant

A project created on any supported desktop platform must be the same logical project on every other supported platform.

The required user journey is:

```text
Create/edit on macOS / Windows / Linux
        ↓
local durable save
        ↓
backend sync/upload
        ↓
download on Android / iOS / iPadOS
        ↓
open and continue editing offline
        ↓
sync changes back to backend
        ↓
open the updated project on any other supported device
```

Platform is never part of project identity.

## Canonical project model

All clients MUST use one canonical project contract. Desktop and mobile MUST NOT have separate project formats, schemas, identifiers, migration chains or business rules.

At minimum the project contract owns stable identifiers and versions for:

- `ProjectId`;
- `ProjectRevision`;
- `schemaVersion`;
- building/site/level/room/surface entities;
- component, port and equipment identities;
- cable routes and engineering graph edges;
- circuits, panels and protection devices;
- calculation inputs/results and normative-profile references;
- project assets and attachment references.

Externally visible entity identities MUST be stable UUID-like identifiers, not platform-local integer identities.

## Local-first execution model

ElecX MUST remain usable without network connectivity.

```text
UI / Editor
    ↓
Domain/Application services
    ↓
ProjectRepository
    ↓
Local database
    ↓
Sync engine
    ↓
Backend
```

Editor gestures and engineering commands MUST NOT synchronously depend on backend round-trips. Dragging a component, editing a cable route, undo/redo, calculations and autosave operate against local state first.

The backend is synchronization, backup, revision distribution and sharing infrastructure; it is not the interactive editor database.

## Local persistence

The target local persistence stack is:

```text
Flutter
  ↓
ProjectRepository
  ↓
Drift
  ↓
SQLite
```

The same logical schema and migration chain MUST be used on:

- macOS;
- Windows;
- Linux;
- Android;
- iOS;
- iPadOS.

Platform-specific code may select filesystem locations, database drivers, permissions and lifecycle integration, but MUST NOT duplicate domain or persistence semantics.

## Backend ownership

The backend is the authoritative synchronization service for user-accessible project revisions.

Recommended ownership split:

```text
Backend
├── PostgreSQL
│   ├── project metadata
│   ├── ownership/access
│   ├── revision metadata
│   ├── sync state
│   └── sharing metadata
│
└── Object storage
    ├── plans
    ├── images
    ├── PDFs
    ├── equipment documents
    ├── previews
    └── other binary assets
```

Large binary assets MUST NOT be embedded repeatedly into normalized project records.

## Revision model

Project synchronization MUST be revision-aware.

A project carries at least:

```text
projectId
schemaVersion
revision
updatedAt
```

A sync request MUST state the client's base revision. The server MUST reject or explicitly resolve stale-base writes; silent last-write-wins data loss is not acceptable for engineering projects.

Example:

```text
backend revision = 41
Windows edits project
local revision   = 42
sync base        = 41
server accepts   = 42

iPad local       = 39
backend           = 42
iPad downloads   = 42
```

## Conflict policy

The initial implementation may use snapshot/revision synchronization, but the architecture MUST preserve stable entity IDs so that later synchronization can become change-set or operation based.

Future operations may look like:

```text
MOVE_COMPONENT(componentId, x, y)
UPDATE_ROUTE(routeId, points)
ADD_COMPONENT(componentId, ...)
REMOVE_COMPONENT(componentId)
UPDATE_CIRCUIT(circuitId, ...)
```

Two devices editing from the same base revision MUST NOT silently overwrite each other's engineering changes. Conflict handling must be deterministic, visible and recoverable.

## ProjectRepository boundary

UI code MUST depend on repository/application contracts rather than SQLite, filesystem APIs or HTTP clients directly.

Conceptual contract:

```dart
abstract interface class ProjectRepository {
  Future<ProjectDocument> createProject(...);
  Future<ProjectDocument?> loadLocal(ProjectId id);
  Future<void> saveLocal(ProjectDocument project);
  Future<SyncResult> sync(ProjectId id);
  Future<void> download(ProjectId id);
  Future<void> deleteLocal(ProjectId id);
}
```

The exact Dart API may evolve, but the dependency direction is mandatory.

## Portable `.elecx` format

Backend sync MUST NOT be the only portability mechanism.

ElecX should support a portable project package for explicit export/import and offline transfer:

```text
project.elecx
├── manifest.json
├── project database/snapshot
├── assets/
└── preview
```

The package format MUST be versioned and derived from the same canonical project model. It MUST NOT create a second independent schema.

## Functional parity rule

Desktop and mobile share the same engineering capabilities and project semantics.

Differences are allowed only where interaction modality requires them, for example:

- mouse/keyboard vs touch/stylus;
- desktop panels vs adaptive mobile/tablet layouts;
- platform file pickers;
- lifecycle/background behavior;
- permission handling.

A feature is not considered cross-platform complete if it changes the persisted meaning of the project between desktop and mobile.

## Compatibility gate

Any schema or serialization change MUST prove:

1. an older supported project can be migrated forward;
2. the migrated project opens on every supported native platform;
3. save/reopen preserves engineering semantics;
4. upload/download preserves project identity and revision;
5. no platform introduces platform-specific domain data;
6. offline edit followed by sync is deterministic;
7. conflict paths are fail-closed and do not silently discard data.

## Development order

Implementation may be staged, but architecture parity is mandatory:

```text
1. macOS desktop baseline
2. Windows desktop
3. Linux desktop
4. Android
5. iPadOS / iOS
6. backend sync and revision hardening in parallel with native clients
```

Desktop-first development MUST NOT introduce contracts that make mobile a separate product implementation.

## Non-negotiable invariants

- One project identity across all devices.
- One canonical domain model.
- One SQLite/Drift schema and migration chain for native clients.
- Local-first editing and autosave.
- Backend synchronization is revision-aware.
- No silent last-write-wins loss of engineering changes.
- Stable entity identifiers are preserved across export/import and sync.
- Desktop and mobile differ in UX adaptation, not engineering semantics.
- Web/browser runtime is out of scope unless this decision is explicitly revisited by a future architecture decision.
