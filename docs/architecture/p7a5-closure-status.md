# P7A-5 Hosted-Object Migration — closure status

Branch: `feat/project-structure-authoring`

## Status

**P7A-5 = DONE + HARDENED + QUALIFIED.**

Qualified production-code HEAD:

```text
e747bf9c0f1c320a8a90fb5dbd4301697561d16b
```

The commit that adds this document is documentation-only and does not change the qualified production code.

## Closed scope

P7A-5 completes stable `BoundaryEdgeId` hosting and identity-changing boundary migration for the production editor.

Canonical hosted ownership now covers:

- openings;
- wall-hosted components;
- cable endpoints;
- route anchors with stable `RouteAnchorId`;
- wall-profile payloads through the dedicated `BoundaryWallProfileRegistry`.

Identity-changing boundary operations use explicit lineage and one P3 mutation boundary:

```text
input intent
  -> current BoundaryEdgeId projection
  -> topology candidate
  -> lineage
  -> hosted-reference remap
  -> wall-profile transform
  -> opening/profile preflight
  -> candidate validation
  -> atomic P3 commit
  -> ProjectChangeSet + UndoRecord
  -> generic persistence ownership acknowledgement
  -> legacy/P2 rematerialization
```

## Host identity invariants

- `wallIndex` is never durable hosted-object identity.
- Durable wall ownership is `(SpaceId, BoundaryEdgeId)`.
- `BoundaryHostedObjectRegistry` owns opening/component/cable-endpoint/route-anchor host references.
- `BoundaryWallProfileRegistry` separately owns wall-profile payloads because split/merge transforms profile geometry.
- Generic wall-profile ownership is rejected fail-closed.
- Hosted references to inactive, foreign or geometrically incompatible edges are rejected before persistence.

## Opening contract

P6 semantic opening payload and P7 physical host remain separate typed models but are cross-validated before topology commit.

A wall-hosted opening must prove:

- matching `ProjectOpeningEntity` identity;
- matching `SpaceId` host affinity;
- interval width equals semantic opening width;
- transformed wall profile accepts the full opening rectangle, including base elevation and height;
- orphan hosted openings and missing hosted references fail closed.

## Split / merge contract

Split:

- source edge identity is retired through explicit lineage;
- result edges receive new `BoundaryEdgeId` values;
- point hosts select exactly one child by geometry;
- interval hosts must fit completely inside one child;
- crossing/ambiguous hosts block the mutation;
- wall-profile payload is split geometrically.

Merge:

- source edges must be ordered-adjacent;
- source edges must be collinear and forward-directed;
- corner merge is rejected;
- point/interval offsets are rebased onto the result edge;
- wall profiles merge only when the transformation is lossless and supported.

These operations are also the production polygon insert/delete-vertex semantics: split creates a boundary vertex/two result edges, while merge removes the shared vertex/two source edges and creates one result edge. The general `replaceTopology` path remains available for tools that provide complete create/remove lineage explicitly.

## Route identity and split materialization

Interior route points use stable `RouteAnchorId`; segment/point list indices are never persisted as identity.

Legacy routes may be explicitly adopted by allocating route-anchor identities. Reopen rehydration resolves stable anchors through canonical registry affinity and fails closed on ambiguity.

When a collinear wall split places anchors of one source route segment on different result edges, production rematerialization may split that route segment losslessly while preserving:

- route identity;
- endpoint identity;
- stable route-anchor identity;
- segment locks;
- mandatory waypoint affinity;
- engineering payload.

Forward and reverse traversal across the split boundary are supported. A true corner transition remains fail-closed unless represented by an explicit route topology transition.

## Production wiring

Identity-changing operations are reachable through production editor controls, not only application tests.

The production toolbar and keyboard path resolve the currently active transient wall ordinal through a fresh version-aware canonical projection before invoking P7A-5:

```text
mouse / touch toolbar action ----┐
keyboard Alt+A / Alt+S / Alt+M --┤
                                 v
                       fresh BoundaryEdgeId
                                 |
                                 v
              CanonicalBoundaryTopologyMigrationRuntime
                                 |
                                 v
                         shared P3 mutation
```

Actions:

- `Alt+A` / toolbar adoption action: explicit one-time legacy-host adoption;
- `Alt+S` / toolbar split action: split active wall at midpoint;
- `Alt+M` / toolbar merge action: merge active wall with its next canonical edge when lossless.

No input modality owns a separate engineering mutation path.

After an identity-changing commit, the legacy editor is rematerialized from canonical state and returns to Plan so a stale wall ordinal cannot survive the edge-identity change.

## History and ownership

P7A-5 uses the same `ProjectStructureAuthoringSession` and `ProjectMutationSession` as existing canonical authoring.

Topology, hosted references and wall-profile payloads commit atomically into one version transition and one canonical Undo boundary.

Undo/Redo rematerializes the current canonical state and uses the same generic project-wide persistence ownership boundary as other P3 mutations.

One-time legacy-host adoption is also a first-class P3 mutation on this same timeline. Split/merge never silently bootstrap legacy ownership during their own commit.

## Persistence

Canonical schema v6 durably persists:

- boundary topology and stable edge identities;
- boundary identity tombstones;
- hosted-object registry;
- wall-profile registry.

Older schemas migrate without inventing hosted identity or wall-profile payloads from legacy ordinals.

Current-schema corruption, dangling hosted references and incompatible profile payloads fail closed.

## Qualification

Exact qualified production-code HEAD:

```text
e747bf9c0f1c320a8a90fb5dbd4301697561d16b
```

Flutter workflow:

```text
Dart format gate          PASS
flutter analyze           PASS
flutter full test         PASS
quality job               SUCCESS
verification job          SUCCESS
```

macOS Desktop workflow on the same SHA:

```text
Flutter/macOS setup       PASS
flutter pub get           PASS
Analyze                   PASS
Test                      PASS
Build macOS debug app     PASS
Runtime path_provider     PASS
job                       SUCCESS
```

Qualification includes direct production runtime tests plus toolbar and keyboard acceptance paths that prove transient ordinal -> stable `BoundaryEdgeId` resolution before mutation.

## Next stage

P7A-5 closure allows the roadmap to move to **P7A-6 full hardening / adversarial qualification**.

P7A-6 should attack the completed contract rather than introduce another identity model. Priority adversarial areas include stale-version races, host-remap ambiguity, split/merge interruption, cross-room/shared-boundary cases, save/reopen after identity change, mixed P2/P3 chronology, lifecycle cancellation, large irregular polygons and long-route rematerialization.
