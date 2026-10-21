# Project Variant Qualification v1

## Status

Qualification strategy for `feat/project-structure-authoring` and future Project Composition & Generation implementation.

This document is subordinate to:

- `docs/architecture/native-project-portability-and-sync.md`
- `docs/architecture/project-composition-foundation-decisions-v1.md`

It complements the authoring, Wizard, Navigator and Room Surface Navigator specifications.

ElecX remains native-only: macOS, Windows, Linux, Android, iOS and iPadOS. Web/browser is out of scope.

## Objective

Qualification must prove the architecture across representative project shapes, topology families, navigation contexts, engineering profiles, persistence paths and regeneration scenarios.

Do not qualify the subsystem through one demo project only.

Use:

- boundary-value cases;
- representative cases;
- pairwise/combinatorial coverage;
- risk-selected scenarios;
- deterministic fixtures;
- stress suites separated from ordinary smoke.

## Qualification layers

```text
L0 foundation contract gates
L1 runtime smoke
L2 structural smoke
L3 navigation/surface smoke
L4 generator smoke
L5 engineering starter smoke
L6 regeneration safety
L7 persistence/migration
L8 native cross-platform
L9 stress/performance
```

## L0 — foundation contract gates

Before UI/Generator implementation may be considered qualified, prove:

```text
F01 ProjectId and SiteId are distinct
F02 persistent IDs never derive from level number/list index/platform/local row id
F03 LevelId survives rename/renumber
F04 multi-building aggregate stores full semantics for every Building
F05 active Level is referenced by LevelId
F06 ProjectCommand commits through one atomic mutation boundary
F07 failed mutation leaves canonical fingerprint unchanged
F08 one semantic command yields one ProjectChangeSet + one UndoRecord
F09 stale LocalProjectVersion cannot overwrite newer local state
F10 ProjectRepository hides filesystem/SQLite/backend implementation details
F11 SpaceUsage round-trips as canonical data
F12 structural zones and overlay classifications are separate
F13 stable BoundaryEdgeId/lineage exists before durable wall-host expansion
F14 ProjectNavigationState is ID-backed
F15 ProjectIndex provides direct entity lookup
F16 no Web/browser architecture exists
```

## L1 — runtime smoke

```text
launch
open Project Hub
create project
open editor
show valid current project location
save
close
relaunch
reopen same project
```

Pass criteria:

- no MissingPluginException;
- no browser fallback;
- project identity preserved;
- save/reopen succeeds;
- editor and navigator agree on active Building/Level.

## L2 — structural smoke

Exercise:

```text
Site
multiple Buildings
Level / Basement / Ground / Technical / Roof
StructuralZone
Space
Opening
VerticalCore
OutdoorZone
ServiceEntry
```

Mandatory invariants:

- unique stable IDs;
- no dangling references;
- valid graph after every committed action;
- Undo/Redo returns valid graphs;
- same-number Levels in different Buildings are unambiguous;
- save/reopen preserves canonical semantic fingerprint.

## L3 — navigation and Room Surface Navigator smoke

### Project Navigator

```text
N01 current Site/Building/Level visible
N02 selected Room does not erase active Level context
N03 deep Room selection expands ancestors
N04 explicit navigation scrolls current node into view
N05 Building A/Floor 2 != Building B/Floor 2
N06 +Building targets active Site
N07 +Level targets active Building
N08 +Room targets active Level
N09 create Level makes it current
N10 create Room selects/reveals it
N11 delete active entity chooses deterministic fallback
N12 breadcrumb/tree/editor derive from one navigation state
N13 hover/focus do not silently mutate selection
```

### Room Surface Navigator

```text
RSN01 hidden when no Room selected
RSN02 one lightweight navigator for selected Room only
RSN03 Plan/Floor/Ceiling/Wall selection is bidirectional with Canvas
RSN04 polygon/L-shaped rooms expose all canonical edges
RSN05 current surface is accessible without color alone
RSN06 collapse/expand does not dirty project
RSN07 switching Room invalidates only local projection
RSN08 wall removal/split cannot silently rebind to same numeric index
RSN09 removed/ambiguous active wall falls back deterministically to Plan
RSN10 keyboard/touch invoke same semantic surface command
```

## L4 — generator smoke

Families:

```text
Apartment
Cottage
Building
Residential complex
```

Representative apartment set:

```text
1-room  compact
2-room  linear
3-room  dualAspect
5-room  splitDayNight
10-room multiWing
```

Additional pairwise dimensions include entry side, facade/window sides, kitchen mode, bathroom mode, balcony/loggia, area band and engineering profile.

Unsupported combinations fail validation rather than being silently coerced.

## L5 — engineering starter smoke

Representative profiles:

```text
1-room Basic
2-room Standard
3-room Premium
10-room Standard
```

Discipline coverage:

```text
POWER
LIGHTING
LAN
CCTV
ACS
FIRE
```

Qualification asserts logical relations as well as rendered symbols:

```text
Switch controls Luminaire
SocketGroup belongs to Circuit
Circuit has distribution/protection path
LAN outlet has media path to patch/rack role
Fire detector belongs to fire loop/panel topology
```

Logical graph and physical route are tested as separate concepts.

## L6 — regeneration safety

Required sequence:

```text
generate
→ manually override selected generated properties
→ regenerate selected discipline
→ preview diff
→ commit
→ save
→ reopen
```

Pass criteria:

- manual entities preserved;
- overridden properties preserved by default;
- unrelated disciplines unchanged;
- conflicts explicit;
- logically unchanged entities preserve IDs;
- one regeneration commit is one Undo transaction;
- stale LocalProjectVersion blocks commit.

## L7 — persistence/migration

Required paths:

```text
current schema save/reopen
legacy JSON → migrated canonical document
older supported schema → migrate → reopen
future Drift import/round-trip
portable snapshot/export when introduced
```

Pass criteria:

- schema migration is registered/versioned;
- ProjectId unchanged;
- SiteId not substituted for ProjectId;
- LevelId/SpaceId/BoundaryEdgeId preserved where semantics survive;
- resume state never rebinds by label/level number/wall index;
- invalid migration is fail-closed;
- multi-building semantics round-trip completely.

## L8 — cross-platform native smoke

One committed project fixture is opened/edited/saved across supported native targets.

Exact UI layout may differ. Canonical engineering semantics may not.

Byte-for-byte file equality is not required.

## CanonicalProjectFingerprint oracle

Qualification uses a normalized semantic fingerprint for round-trip and failure assertions.

Include:

```text
stable identities
hierarchy
geometry
SpaceType/SpaceUsage
BoundaryEdge hosts/openings
engineering logical graph
circuits/routes
provenance/generation state
```

Exclude:

```text
hover/focus
navigator scroll
panel visibility
serialization key order
local DB row ids
non-semantic timestamps unless specifically under test
```

Required assertions:

```text
preview cancel         before == after
failed command         before == after
save/reopen            semantic fingerprint equal
migration              expected semantic fingerprint
cross-platform open    semantic fingerprint equivalent
```

## Reusable invariant oracles

### Identity oracle

```text
all persistent IDs non-empty and unique in scope
renames/renumber preserve identity
no ID derived from list index/level number/platform/local row id
regeneration preserves logically unchanged identity
```

### Hierarchy oracle

```text
all Buildings belong to Site/Project
all Levels belong to one Building
all StructuralZones reference existing Spaces
all openings reference valid BoundaryEdge hosts
all VerticalCore nodes reference valid LevelIds
all service entries reference existing targets
```

### Boundary topology oracle

```text
all persistent wall hosts reference BoundaryEdgeId
polygon edit explicitly maps preserved/split/merged/removed edges
removed edge never silently rebinds to same index
hosted openings/components/routes are remapped or conflicted explicitly
```

### Geometry oracle

```text
no degenerate room polygons
no unintended overlap
rooms remain inside promised envelopes
canonical coordinates use deterministic mm units
```

### Engineering graph oracle

```text
all endpoints exist
ports/media are compatible
logical relations are valid independently from physical routes
no dangling route endpoint
required loads have valid source/distribution topology
```

### Provenance oracle

```text
origin explicit
GenerationId/template/generator metadata valid where applicable
generationKey unique in semantic scope
overriddenProperties explicit
lockedFromRegeneration honored
```

### Transaction oracle

```text
one command → one committed ProjectChangeSet
failed validation → zero commit
one semantic action → one UndoRecord
LocalProjectVersion increments once per commit
```

### Projection oracle

```text
navigator/editor/breadcrumb agree
active context distinct from selected entity
ProjectIndex resolves current nodes directly
hover/surface changes do not rebuild whole project tree
```

## Pairwise/combinatorial strategy

Do not execute a full Cartesian product in ordinary CI.

Build deterministic pairwise matrices per family plus mandatory boundaries and risk-selected cases.

Example apartment dimensions:

```text
roomCount: 1,2,3,5,10
topology: compact,linear,corner,dualAspect,splitDayNight,multiWing
kitchen: separate,kitchenLiving
bathroom: combined,split
balcony: none,balcony,loggia
engineering: none,Basic,Standard,Premium
```

## Multi-building matrix

```text
B01 one building, one level
B02 two buildings each with Floor 2
B03 five-floor building with typical floors
B04 twenty floors with mixed apartments
B05 basement + technical + roof
B06 shared service infrastructure
B07 100-floor stress fixture

RC01 two residential buildings
RC02 three buildings + courtyard
RC03 standalone parking/service block
RC04 shared electrical service entry
RC05 mixed heights/apartment mixes
RC06 multi-building engineering-backbone stress
```

## Wall topology matrix

```text
WALL01 rectangle room stable wall references
WALL02 L-shape >4 edges
WALL03 insert vertex splitting one wall
WALL04 remove/merge edge with opening host
WALL05 selected wall removed → Plan fallback
WALL06 route/component hosted on changed edge → remap or conflict
WALL07 save/reopen preserves BoundaryEdgeId semantics
```

## Undo/Redo qualification

```text
create level → Undo → Redo
create room → Undo → Redo
create floors 2..20 → Undo → Redo
generate apartment → Undo → Redo
regenerate Lighting → Undo → Redo
remove dependency-safe structure → Undo → Redo
```

Every intermediate state must validate and retain a valid navigation context.

## Performance/stress qualification

Stress fixtures:

```text
100+ floors
1000+ spaces
multiple buildings
5000+ engineering components
large logical graph
large route graph
large navigator tree
```

Measure:

- command execution;
- candidate validation;
- ProjectIndex lookup;
- navigator projection/current-node reveal;
- persistence/autosave;
- Wizard preview memory;
- regeneration diff time;
- repaint/rebuild counts for hover/surface selection.

Reject architectures that deep-copy the entire project for pointer/hover/slider changes or repeatedly scan the complete tree for ordinary navigation.

## CI gate groups

```text
Q0 foundation contract tests
Q1 identity/hierarchy/boundary topology
Q2 mutation/version/change-set/undo
Q3 ProjectRepository + codec + migration
Q4 navigator + Room Surface Navigator
Q5 deterministic Wizard + pairwise generator matrix
Q6 engineering graph/connectivity
Q7 provenance/regeneration
Q8 macOS native integration
Q9 Windows/Linux native integration
Q10 Android/iOS/iPadOS qualification
Q11 stress/performance outside every-commit smoke where necessary
```

## Merge blockers

The applicable implementation stage is blocked if any of these are true:

- duplicate authoritative copies of persistent entities are introduced;
- Level identity depends on level number;
- wall-host identity depends only on mutable wall index;
- invalid graph can commit;
- stale local candidate can overwrite newer state;
- preview mutates the live project;
- one command produces partial/multiple unintended commits;
- navigator/editor disagree about active context;
- same-number Levels across Buildings are ambiguous;
- generation silently loses manual overrides;
- migration changes semantic fingerprint unexpectedly;
- one native platform creates semantics another cannot open;
- Web/browser-specific persistence or project semantics are introduced.

## Non-negotiable conclusion

Variant qualification is part of the architecture.

The subsystem is robust only when identity, structural mutation, wall topology, navigation, generation, engineering graph, persistence and native-platform semantics are proven across representative variants rather than one happy-path demo.
