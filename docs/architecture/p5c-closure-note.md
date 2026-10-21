# P5C Closure Note — Project Structure Authoring

Status target: `P5C CLOSED` after the branch qualification gates pass on the final P5C hardening commit.

This note fixes the closure boundary for P5C. It is intentionally narrow: P5C owns canonical project-structure authoring UX and controlled runtime projection into the transitional editor. It does not pull later persistence, geometry, compass, or room-surface roadmap work forward.

## Included in P5C

- canonical `ProjectNavigationState` as the structural navigation source of truth;
- indexed Project Navigator and breadcrumb operating on stable typed IDs;
- discoverable `+ Building`, `+ Level`, and `+ Room` actions;
- all structure mutations routed through the canonical P3/P4 mutation path;
- exact `BuildingId` / `LevelId` / `ZoneId` / `SpaceId` navigation;
- controlled canonical-to-legacy canvas projection through `CanonicalEditorRuntimeCutoverCoordinator` and `CanonicalEditorWorkspaceAdapter`;
- reverse legacy selection projection back into canonical navigation;
- production opt-in wiring in `UnifiedWorkspaceEditorScreen`;
- workspace re-resolution after Open/Recovery replacement;
- fail-closed runtime materialization for canonical entities that do not yet have a valid legacy canvas representation;
- a visible blocked-state banner instead of synthetic geometry or silent fallback;
- explicit persistence-ownership gating for production structure authoring;
- serialization of async structure-authoring actions so one user intent cannot overlap another resolver/publication operation.

## Non-negotiable invariants

### One canonical navigation authority

`ProjectNavigationState` is authoritative for canonical Building / Level / Zone / Space location. Legacy canvas state is a projection boundary during migration and must not become a second canonical navigation model.

### Stable identity

`levelNumber` is never canonical identity, a canonical foreign key, or a canonical navigation key.

The only permitted use during P5C cutover is the final compatibility call inside the legacy adapter after the target Level has already been resolved by:

```text
LevelId
  -> explicit canonical-to-legacy Level binding
  -> concrete legacy BuildingLevel.id
  -> legacy levelNumber
  -> old workspace API
```

No canonical flow may resolve a Level by number or label.

### Fail-closed hybrid mode

Unsupported or incomplete runtime mappings must not silently degrade to a guessed legacy target.

Examples:

- unbound canonical Building -> blocked;
- unbound canonical Level -> blocked;
- unbound canonical Zone -> blocked;
- canonical Room without valid legacy geometry -> `blockedMissingGeometry`;
- incoherent canonical Space/Zone path -> blocked;
- invalid reverse legacy binding -> rejected.

A blocked canonical target may exist successfully in the canonical graph while the canvas remains on the last valid materialized target. P5C must not invent room rectangles or other fake geometry only to make the legacy canvas open.

## Persistence ownership invariant

Production structure authoring is enabled only when an explicit canonical persistence owner is supplied:

```text
canonical authoring enabled
    <=>
canonical persistence owner exists
```

Without `onAuthoringCommitted`:

```text
+ Building  disabled
+ Level     disabled
+ Room      disabled
```

Canonical navigation remains available.

`onAuthoringCommitted` is an ownership-transfer boundary, not an analytics event and not a best-effort notification. A host that supplies it accepts responsibility for the committed canonical state and for carrying that state into its persistence workflow. The standard legacy `EditorProjectDocument` Save path must never be presented as canonical persistence.

P5C does not require the final Drift/SQLite backend. The production storage implementation remains P16 scope.

## Runtime concurrency rule

Only one structure-authoring action may be in flight at a time. While a Building, Level, or Room request/publish flow is awaiting completion, all three structure-authoring controls are disabled. This prevents double-tap/double-click overlap from creating multiple canonical entities from one user intent or racing persistence publication.

## Production wiring qualification

P5C closure requires qualification of these paths:

```text
Navigator
  -> typed canonical navigation
  -> coordinator
  -> adapter
  -> canvas
```

```text
canvas selection
  -> adapter reverse binding
  -> coordinator
  -> ProjectNavigationState
  -> Navigator / breadcrumb
```

And the following cases:

- equal `levelNumber` values in different Buildings still navigate by exact `LevelId`;
- Open/Recovery replaces the workspace and resolves a fresh canonical runtime binding;
- canonical projection does not mark the legacy document Modified;
- missing runtime materialization shows controlled blocked state and does not partially mutate the canvas;
- production authoring controls are all disabled when no persistence owner exists and the canonical graph version remains unchanged;
- with a persistence owner, a successful structure authoring action publishes exactly once with the exact created typed `EntityId`;
- repeated editor notifications without navigation changes do not cause repeated canonical pulls;
- feedback loops between canonical push and legacy listeners are suppressed.

## Deferred by design

The following are explicitly not P5C closure requirements:

- final canonical persistence backend / Drift / SQLite -> P16;
- full Room geometry ownership and semantic usage -> P6/P7;
- stable `BoundaryEdgeId` wall topology -> P7;
- opt-in project compass work -> P5D;
- Room Surface Navigator shell/projection -> P5E;
- full canonical rewrite of outdoor/site runtime state -> later roadmap scope.

## Closure statement

P5C may be marked `CLOSED` when the final P5C hardening commit passes the branch Flutter quality/verification workflow and the macOS Desktop workflow, with no P5C-scope regression remaining.

At closure the expected state is:

```text
P5C CLOSED

Included:
- canonical Navigator
- canonical breadcrumb
- +Building / +Level / +Room UX
- controlled legacy canvas cutover
- production screen integration
- fail-closed materialization
- explicit persistence ownership gate
- serialized async authoring controls

Deferred:
- final canonical persistence backend -> P16
- Room geometry ownership -> P6/P7
- compass -> P5D
- Room Surface Navigator -> P5E
```
