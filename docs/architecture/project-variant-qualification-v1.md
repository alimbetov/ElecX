# Project Variant Qualification v1

## Status

Qualification strategy for `feat/project-structure-authoring` and future Project Composition & Generation implementation.

This document is subordinate to:

- `docs/architecture/native-project-portability-and-sync.md`
- `docs/architecture/project-composition-foundation-decisions-v1.md`
- `docs/architecture/project-composition-generation-v1.md`
- `docs/architecture/project-template-wizard-v1.md`
- `docs/architecture/project-navigator-current-location-v1.md`

ElecX remains native-only. Supported qualification targets are macOS, Windows, Linux, Android, iOS and iPadOS. Web/browser is out of scope.

## Objective

The feature must not be qualified only by one demo project or one golden journey.

The goal is a repeatable variant smoke/qualification system that proves the architecture across representative project shapes, topology families, engineering profiles, persistence paths, navigator current-location behavior and regeneration scenarios.

The qualification strategy intentionally avoids a full Cartesian product. Instead it uses:

- boundary-value scenarios;
- representative scenarios;
- pairwise/combinatorial coverage;
- risk-selected scenarios;
- deterministic seeded fixtures;
- stress scenarios kept separate from ordinary smoke.

## Qualification layers

### L1 — Runtime smoke

Minimum native application health:

```text
launch
open Project Hub
create project
open editor
show valid current project location in navigator
save
close
relaunch
reopen same project
```

Pass criteria:

- no MissingPluginException;
- no Web/browser fallback;
- project identity preserved;
- save/reopen succeeds;
- editor reaches an operable state;
- navigator and editor agree on active Building/Level context.

### L2 — Structural smoke

Exercise canonical composition primitives:

```text
Site
Building
multiple Buildings
Level
Basement
Ground/plinth
Technical level
Roof
Zone
Room/Space
Opening
VerticalCore
OutdoorZone
ServiceEntry
```

Pass criteria:

- unique stable IDs;
- no dangling references;
- project graph valid after each committed action;
- navigator current location remains valid after mutation;
- Undo/Redo restores valid graphs;
- save/reopen preserves semantic equality.

### L3 — Generator smoke

Exercise architectural generation families:

```text
Apartment
Cottage
Building
Residential complex
```

Representative apartment set:

```text
1-room  / compact
2-room  / linear
3-room  / dualAspect
5-room  / splitDayNight
10-room / multiWing
```

Additional pairwise coverage rotates parameters such as:

```text
entry side
facade/window sides
kitchen mode
bathroom mode
balcony/loggia mode
approximate area band
shape/aspect ratio
topology family
```

The generator test does not assert one exact pixel layout unless a case is explicitly golden. It asserts canonical invariants.

### L4 — Engineering starter smoke

Representative engineering profiles:

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

Pass criteria include logical connectivity, not merely rendered symbols.

Examples:

```text
Switch controls Luminaire
SocketGroup belongs to Circuit
Circuit terminates at DistributionBoard/Protection role
LAN outlet has a data path toward rack/patch role
Fire detector participates in a fire loop/panel topology
```

### L5 — Regeneration safety smoke

Required sequence:

```text
generate
→ manually modify selected generated entity/field
→ regenerate selected discipline
→ preview diff
→ commit
→ save
→ reopen
```

Pass criteria:

- manual entities preserved;
- overridden generated fields preserved by default;
- unrelated disciplines unchanged;
- unresolved conflicts explicitly surfaced;
- stable identities preserved for logically unchanged entities;
- one committed regeneration action is one Undo transaction.

### L6 — Persistence/migration smoke

Required paths:

```text
current schema save/reopen
older supported schema → migrate → reopen
JSON transitional project → future Drift import
portable snapshot/export when introduced
```

Pass criteria:

- schemaVersion moves only through registered migrations;
- projectId unchanged;
- stable entity IDs unchanged where semantics are unchanged;
- resume context never rebinds by matching label or level number;
- no silent inferred engineering meaning;
- migration failure is fail-closed.

### L7 — Cross-platform native smoke

For the same committed project fixture:

```text
macOS → save
Windows → open/edit/save
Linux → open/edit/save
Android → open/edit/save
iPadOS/iOS → open/edit/save
```

Exact UI layout may differ. Persisted engineering semantics must not.

## QualificationScenario contract

Variant cases should be data-driven rather than hand-written widget flows only.

Conceptual contract:

```dart
final class QualificationScenario {
  final String id;
  final TemplateRef template;
  final WizardParameters parameters;
  final EngineeringGenerationProfile? engineeringProfile;
  final Set<EngineeringDiscipline> disciplines;
  final QualificationExpectation expectation;
}
```

`QualificationExpectation` should primarily assert invariants and ranges rather than brittle exact counts unless the template contract guarantees exact counts.

Conceptual expectations:

```text
required building count
allowed level count/range
minimum/maximum space count
required SpaceUsage classes
required vertical-core kinds
required service-entry roles
required discipline graph roots
requires distribution board
requires network rack
requires fire panel
maximum blocking validation issues = 0
```

## Invariant oracles

Every generated or mutated candidate should be checked by reusable qualification oracles.

### Identity oracle

```text
all persistent IDs non-empty
all persistent IDs unique in their identity scope
no ID derived from list index/platform database row
renames preserve identity
logical regeneration preserves identity
```

### Hierarchy oracle

```text
all buildings belong to project/site
all levels belong to exactly one building
all zones reference existing spaces
all openings reference valid hosts
all vertical-core nodes reference valid levels
all service entries reference valid site/building targets
```

### Geometry oracle

```text
no degenerate room polygons
no unintended room overlap
spaces remain within expected level envelope when generator claims containment
openings have valid wall/surface hosts
all canonical coordinates use deterministic millimetre units
```

### Engineering graph oracle

```text
all endpoints exist
all ports support connected media
no dangling route endpoints
required generated loads have a valid source/distribution path
no discipline graph silently references removed structural entities
```

### Provenance oracle

```text
manual objects have manual/import provenance as appropriate
generated objects have generationId/template/generator context
overridden fields are explicit
lockedFromRegeneration is obeyed
generationKey is unique within one generation semantic scope
```

### Persistence oracle

```text
capture/save/reopen preserves canonical graph
semantic equality holds after round-trip
transient UI state such as hover/compass visibility/scroll offset is not promoted to engineering meaning
```

### Sync-readiness oracle

```text
projectId preserved
schemaVersion explicit
stable entity IDs preserved
no platform-local row ID leaks into canonical references
candidate operations can be represented as deterministic change-sets later
```

### Transaction oracle

```text
one semantic command produces one committed ProjectChangeSet
failed validation commits nothing
one committed structural/generation action produces one Undo record
one committed action publishes one canonical change boundary
cancel/preview leaves project semantic fingerprint unchanged
```

### Navigator projection oracle

```text
current Site/Building/Level derives from canonical navigation state
selected Zone/Room does not erase active Level context
same-number Levels in different Buildings are unambiguous by stable IDs
explicit navigation auto-expands required ancestors
explicit navigation reveals current node in scroll view
hover does not change current/selected project state
+ Building targets active Site
+ Level targets active Building
+ Room targets active Level
cancel/failure preserves previous current location
delete never leaves dangling current/selected IDs
canvas/editor selection and navigator path agree
breadcrumb and tree derive from the same source of truth
```

## Pairwise/combinatorial strategy

Do not execute every possible combination of all wizard parameters in ordinary CI.

Instead build a deterministic pairwise matrix per generator family.

Example apartment dimensions:

```text
roomCount: 1, 2, 3, 5, 10
topology: compact, linear, corner, dualAspect, splitDayNight, multiWing
kitchen: separate, kitchenLiving
bathroom: combined, split
balcony: none, balcony, loggia
engineering: none, Basic, Standard, Premium
```

The qualification-case generator selects a minimal deterministic set covering parameter pairs and mandatory boundary cases.

Unsupported combinations must fail validation before canonical commit rather than being silently coerced.

## Building/ЖК matrix

Representative building scenarios:

```text
B01 1 floor, no basement
B02 2 floors + basement
B03 5 floors, typical floors
B04 20 floors, multiple apartment mixes
B05 technical floor + roof
B06 shared vertical cores
B07 100-floor stress fixture (non-smoke performance suite)
```

Representative residential-complex scenarios:

```text
RC01 2 residential buildings on one site
RC02 3 buildings + shared courtyard
RC03 buildings + standalone parking/service block
RC04 shared electrical service entry
RC05 mixed building heights and apartment mixes
RC06 multi-building engineering backbone stress fixture
```

Mandatory navigator multi-building cases:

```text
NV01 Building A/Floor 2 and Building B/Floor 2 show distinct current paths
NV02 switch Building A → Building B updates active Building and Level atomically
NV03 create Level in Building B cannot appear under Building A
NV04 selecting deep Room reveals full ancestor path
NV05 deleting active Level chooses deterministic valid fallback
```

## Engineering matrix

Each discipline gets minimum semantic coverage.

### POWER

```text
socket groups
high-load dedicated circuit
board assignment
protection role
service-entry/source path
```

### LIGHTING

```text
luminaire generation
switch/control relation
lighting circuit
board assignment
```

### LAN

```text
data outlet
media-compatible cable path
rack/patch role
```

### CCTV

```text
camera placement role
network/power or PoE dependency
recording/network root role
```

### ACS

```text
reader/door relation
controller role
power/data/control topology
```

### FIRE

```text
detector/notification roles
loop topology
fire panel/root role
```

The current electrical-only compatibility model must not be treated as sufficient proof for non-power disciplines.

## Preview/cancel qualification

Every Wizard/regeneration path has tests proving:

```text
open preview
→ generate candidate
→ inspect diff
→ cancel
```

Canonical project semantic fingerprint before and after cancel must be equal.

No permanent IDs allocated during preview may leak into committed stores unless the design explicitly allocates them transactionally at commit.

## Diff qualification

Diff engine must classify at least:

```text
ADD
UPDATE
PRESERVE
REMOVE
CONFLICT
```

Tests cover:

- new generated item;
- generated item changed only by generator;
- manually modified generated item;
- manually created competing item;
- removed template role;
- locked entity;
- unrelated discipline.

## Undo/Redo qualification

Required transaction scenarios:

```text
create one level → Undo → Redo
generate apartment → Undo → Redo
create floors 2..20 → Undo → Redo
regenerate Lighting → Undo → Redo
remove dependency-safe structure → Undo → Redo
```

Every intermediate state must satisfy canonical graph validation and leave navigator current location valid.

## Performance qualification

Ordinary smoke is separated from stress/performance gates.

Performance fixtures include:

```text
100+ floors
1000+ spaces
multiple buildings
5000+ engineering components
large route graph
large navigator tree
```

Measure at least:

- command execution time;
- candidate validation time;
- navigator projection/update time;
- current-node reveal/lookup time;
- save/autosave serialization time;
- memory growth during Wizard preview/regeneration;
- rebuild counts for transient hover/selection changes.

Reject designs that require full-project deep-copy for every pointer move, hover or parameter slider tick, or repeated O(N²) scans to reveal current tree location.

## Native platform sequence

Development qualification order:

```text
1 macOS
2 Windows
3 Linux
4 Android
5 iPadOS / iOS
```

A feature is not cross-platform complete merely because macOS passes. macOS is the first reference qualification platform.

## CI gate groups

Recommended CI grouping:

```text
Q1 domain/application invariants
Q2 mutation/undo tests
Q3 Wizard deterministic generator tests
Q4 variant/pairwise generator matrix
Q5 engineering topology tests
Q6 provenance/regeneration tests
Q7 persistence/migration tests
Q8 navigator projection/current-location + widget/accessibility tests
Q9 macOS native integration
Q10 Windows/Linux native integration
Q11 Android/iOS/iPadOS qualification as runners/devices become available
Q12 stress/performance suite outside every-commit smoke when cost is high
```

## Release/merge qualification summary

A future implementation PR should publish a compact qualification report such as:

```text
Project Composition Qualification

Structural scenarios          PASS
Navigator current location    PASS
Apartment variant matrix      PASS
Cottage variants              PASS
Building variants             PASS
Residential complex variants  PASS
Engineering profiles          PASS
Regeneration safety           PASS
Undo/Redo                     PASS
Persistence/migrations        PASS
Native platform gates         PASS/expected staged status
Web dependency check          PASS (none)
```

Exact numeric counts are generated by the test catalog and should be reported by CI.

## Merge blockers

The following are merge-blocking for the corresponding implementation stage:

- invalid canonical graph can be committed;
- duplicate/dangling persistent IDs;
- navigator/editor disagree about active Building/Level;
- same-number Levels in different Buildings are ambiguous;
- current location remains hidden inside collapsed ancestors after explicit navigation;
- authoring actions can target stale/hidden context;
- delete/migration leaves dangling current/selected IDs;
- preview mutates the live project;
- generation loses manual edits silently;
- regeneration crosses discipline boundaries without declared dependency;
- save/reopen changes engineering semantics;
- migration loses identities silently;
- one supported native platform creates semantics another cannot open;
- any Web/browser-specific persistence or project semantics are introduced;
- Wizard tests cover only one happy-path demo without boundary/variant qualification.

## Non-negotiable conclusion

Variant qualification is part of the feature architecture, not an optional late QA activity.

The implementation is considered robust only when project composition and generation are validated across representative structural, navigator, generator, engineering, persistence and native-platform combinations while preserving the same canonical ElecX project semantics.