# P7A-5 Hosted-Object Migration — closure status

Branch: `feat/project-structure-authoring`

## Status

**P7A-5 = DONE + HARDENED + QUALIFIED.**

Qualified production-code HEAD:

```text
0da97676b11baeaa5dfe92c5357185df058f9a08
```

The commit that updates this document is documentation-only and does not change the qualified production code.

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
  -> unified history registration
  -> legacy/P2 rematerialization
```

## Host identity invariants

- `wallIndex` is never durable hosted-object identity.
- Durable wall ownership is `(SpaceId, BoundaryEdgeId)`.
- `BoundaryHostedObjectRegistry` owns opening/component/cable-endpoint/route-anchor host references.
- `BoundaryWallProfileRegistry` separately owns wall-profile payloads because split/merge transforms profile geometry.
- Generic wall-profile ownership is rejected fail-closed.
- Hosted references to inactive, foreign or geometrically incompatible edges are rejected before persistence.
- A topology migration for one `SpaceId` cannot add, delete or mutate wall-profile payloads owned by another space.

## Opening contract

P6 semantic opening payload and P7 physical host remain separate typed models but are cross-validated before topology commit and at the persistence snapshot boundary once a space has canonical hosted ownership.

A wall-hosted opening must prove:

- matching `ProjectOpeningEntity` identity;
- matching `SpaceId` host affinity;
- canonical opening object key affinity;
- interval width equals semantic opening width;
- transformed wall profile accepts the full opening rectangle, including base elevation and height;
- orphan hosted openings and missing hosted references fail closed.

Canonical schema v6 reopen applies the same adopted-space opening/profile invariant. Corrupted JSON that leaves a hosted opening without its semantic opening is rejected as a `FormatException`.

## Split / merge contract

Split:

- source edge identity is retired through explicit lineage;
- result edges receive new `BoundaryEdgeId` values;
- point hosts select exactly one child by geometry;
- interval hosts must fit completely inside one child;
- crossing/ambiguous hosts block the mutation;
- wall-profile payload is split geometrically;
- production midpoint split uses an exact integer-millimetre lattice point on the source edge;
- primitive diagonal edges with no representable interior integer-mm point fail closed instead of rounding off-segment geometry.

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
- `Alt+S` / toolbar split action: split the active wall at the nearest exact representable integer-mm point to its midpoint;
- `Alt+M` / toolbar merge action: merge active wall with its next canonical edge when lossless.

No input modality owns a separate engineering mutation path.

After an identity-changing commit, the legacy editor is rematerialized from canonical state and returns to Plan so a stale wall ordinal cannot survive the edge-identity change.

## History and ownership

P7A-5 uses the same `ProjectStructureAuthoringSession` and `ProjectMutationSession` as existing canonical authoring.

Topology, hosted references and wall-profile payloads commit atomically into one version transition and one canonical Undo boundary.

Production history registration now occurs only after the project-wide persistence owner acknowledges the canonical mutation. If the owner throws after the in-memory P3 commit, the canonical project remains authoritative and is rematerialized into the legacy editor, but the unified Undo/Redo timeline is invalidated fail-closed because durability cannot be proven.

Undo/Redo rematerializes the current canonical state and uses the same generic project-wide persistence ownership boundary as other P3 mutations.

One-time legacy-host adoption is also a first-class P3 mutation on this same timeline. Split/merge never silently bootstrap legacy ownership during their own commit.

## Persistence

Canonical schema v6 durably persists:

- boundary topology and stable edge identities;
- boundary identity tombstones;
- hosted-object registry;
- wall-profile registry.

Older schemas migrate without inventing hosted identity or wall-profile payloads from legacy ordinals.

For a space that already has canonical hosted ownership, `ProjectSnapshot` validates semantic openings against canonical hosts and wall profiles before persistence. Current-schema corruption, dangling hosted references, orphan hosted openings and incompatible profile payloads fail closed.

## Final hardening audit

The final P7A-5 closure audit found and closed four additional defect classes after the earlier qualification:

1. **Cross-space wall-profile mutation** — the general topology replacement path could receive a project-level wall-profile registry and mutate another space. Preview and commit-candidate boundaries now reject any foreign-space profile delta.
2. **Non-representable diagonal midpoint split** — integer division could produce a point outside a diagonal edge. Production split now resolves an exact integer-mm lattice point and fails closed when no interior lattice point exists.
3. **Persistence ownership failure after P3 commit** — unified history was previously registered before persistence acknowledgement. History is now registered only after ownership succeeds; an unowned committed transition invalidates the unified timeline.
4. **Schema-v6 orphan opening on save/reopen** — persistence structural validation did not re-check adopted opening/profile semantics. `ProjectSnapshot` now enforces adopted-space opening ownership, the schema-v6 fixture uses canonical opening identity, and corrupt reopen is rejected.

Regression coverage was added for all four cases.

## Qualification

Exact qualified production-code HEAD:

```text
0da97676b11baeaa5dfe92c5357185df058f9a08
```

Flutter workflow — run `2675`:

```text
Dart format gate          PASS
flutter analyze           PASS
flutter full test         PASS
quality job               SUCCESS
verification job          SUCCESS
```

macOS Desktop workflow — run `611` on the same SHA:

```text
Flutter/macOS setup       PASS
flutter pub get           PASS
Analyze                   PASS
Test                      PASS
Build macOS debug app     PASS
Runtime path_provider     PASS
job                       SUCCESS
```

Qualification includes direct production runtime tests, toolbar and keyboard acceptance paths, cross-space isolation, ownership-failure history semantics, exact split-lattice behavior, schema-v6 opening/profile reopen corruption, and existing canonical migration coverage.

## Next stage

P7A-5 closure allows the roadmap to move to **P7A-6 full hardening / adversarial qualification**.

P7A-6 should attack the completed contract rather than introduce another identity model. Priority adversarial areas include stale-version races, host-remap ambiguity under long edit sequences, split/merge interruption, shared-boundary semantics between rooms, mixed P2/P3 chronology stress, lifecycle cancellation, very large irregular polygons, long-route rematerialization and performance profiling.
