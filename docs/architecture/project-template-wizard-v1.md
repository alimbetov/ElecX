# Project Template Wizard v1

## Status

Implementation specification for the native-only ElecX project/template generation wizard.

This specification is subordinate to and must comply with:

- `docs/architecture/native-project-portability-and-sync.md`
- `docs/architecture/project-structure-authoring-v1.md`

If any requirement in this document conflicts with the native portability architecture, `native-project-portability-and-sync.md` wins until an explicit architecture decision changes it.

## Platform scope

ElecX remains a native application only.

Supported targets:

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

Web/browser runtime is out of scope. The wizard MUST NOT introduce browser-specific UI, persistence, project schemas, fallbacks or business rules.

## Product objective

Add a visible `Wizard` action that can generate a valid starter project structure from deterministic engineering templates instead of forcing the user to draw every level and room manually.

The wizard is an authoring accelerator, not a second project model.

Its output is ordinary canonical ElecX project data and must immediately become editable by the same navigator/editor used for manually created projects.

## Primary UX

Desktop baseline:

```text
Project Hub / New Project

[ Blank ] [ Demo ] [ Wizard ]
```

The editor may also expose:

```text
NAVIGATOR
[ + Level ] [ + Room ] [ Wizard ]
```

The exact placement may adapt on mobile/tablet, but every platform invokes the same application/domain generation contract.

The wizard MUST support preview and cancellation before mutating the canonical project.

## Wizard modes

Initial supported generation families:

```text
Apartment
Cottage / detached house
Building
Residential complex
```

The architecture must allow later extension without adding a second project schema:

```text
Townhouse
Office building
Retail / commercial
Warehouse / industrial
School / clinic
Mixed-use building
```

These later families are outside v1 unless separately accepted.

## Apartment generator

The apartment generator supports popular residential arrangements from 1-room through 10-room configurations.

`roomCount` means the conventional habitable-room count selected by the user. Service spaces are generated separately and do not inflate this number.

Supported range:

```text
1 .. 10 habitable rooms
```

Minimum configurable inputs:

```text
roomCount
approximateAreaM2
shape / aspect ratio
entrySide
facade/window sides
topologyFamily
kitchenMode
bathroomMode
balconyMode
```

Suggested topology families:

```text
compact
linear
corridor
centralHall
corner
dualAspect
splitDayNight
openPlan
```

The generator may hide invalid families for a selected room count rather than produce poor geometry.

### Apartment space composition

Depending on selected parameters, generation may include:

```text
habitable rooms 1..10
entrance / hall
corridor
kitchen or kitchen-living room
bathroom / WC
storage / wardrobe
utility room
balcony / loggia when enabled
```

All generated spaces MUST use canonical `EngineeringSpace` / `SpaceType` semantics. The wizard must not invent a parallel `ApartmentRoom` persistence type unless a future domain ADR explicitly requires one.

## Cottage generator

Minimum inputs:

```text
floorCount
basement enabled/disabled
attic/roof configuration
garage enabled/disabled
habitable room count
approximate footprint
stair/core placement
topology family
```

The result is a normal `ComposedBuilding` containing canonical levels, rooms, zones and vertical cores.

Example presets:

```text
1-storey compact
1-storey L-shape
2-storey family house
2-storey + basement
2-storey + garage
3-storey large house
```

## Building generator

Minimum inputs:

```text
building type
storey count
basement count
technical levels
roof type
apartments per floor
apartment mix
stair cores
lift cores
common corridors
technical/service rooms
floor-to-floor height
```

Example apartment mix:

```text
2 × 1-room
2 × 2-room
1 × 3-room
```

Repeated floors must be generated as independent canonical entities with stable per-level/per-space identities. Repetition MUST NOT create shared mutable object aliases between levels.

## Residential complex generator

The residential-complex mode composes multiple canonical buildings on one canonical site.

Minimum inputs:

```text
building count
building presets / variants
site arrangement
courtyard configuration
parking / basement options
shared technical zones
building spacing
```

The output must remain compatible with the same `ProjectSite -> Building -> Level -> Zone -> Space` hierarchy and future site/network modelling.

A residential complex is not a special file format.

## Template catalog model

Wizard presets are versioned deterministic definitions.

Conceptual contract:

```text
TemplateDefinition
├── templateId
├── templateVersion
├── family
├── displayName
├── supportedParameterSchema
├── generatorVersion
└── constraints
```

A generated project may record template provenance as non-authoritative metadata for diagnostics/reproducibility, but the project MUST remain fully editable and valid if the original template is later removed from the catalog.

Project semantics must not depend on loading the original preset again.

## Deterministic generation rule

Given the same:

```text
templateId
templateVersion
normalized parameter set
generatorVersion
```

the generator should produce equivalent geometry/topology semantics.

Generated permanent project/entity identities are assigned at commit time and then remain stable. Preview-only draft identities must never leak into persisted project state.

The generator MUST NOT regenerate IDs of existing entities when a user subsequently edits the project.

## Generation pipeline

The wizard is implemented as an application/domain service, not widget-side graph construction.

Required flow:

```text
Wizard UI
   ↓
WizardRequest
   ↓
validate parameters
   ↓
ProjectTemplateGenerator
   ↓
GeneratedProjectDraft
   ↓
validate complete canonical graph
   ↓
preview
   ↓
user confirms
   ↓
assign stable permanent IDs
   ↓
atomic commit to canonical project/workspace
   ↓
normal local save/autosave/recovery
   ↓
future revision-aware sync
```

Cancel before commit leaves the project unchanged.

## Proposed application contracts

Conceptually:

```dart
abstract interface class ProjectTemplateGenerator {
  GeneratedProjectDraft generate(ProjectWizardRequest request);
}

final class ProjectWizardRequest {
  final TemplateFamily family;
  final String templateId;
  final int templateVersion;
  final Map<String, Object?> parameters;
}

final class GeneratedProjectDraft {
  final ProjectSite site;
  final List<WizardValidationIssue> warnings;
  final WizardPreviewSummary summary;
}
```

The concrete Dart API may differ, but UI widgets must not directly manufacture the canonical graph.

## Preview requirements

Before commit the user sees at minimum:

```text
site/building count
level count
room count
approximate areas
selected topology
warnings
2D preview of generated geometry
```

Preview state is transient and is not autosaved as engineering project state.

The user can:

```text
Back
Change parameters
Regenerate preview
Create project
Cancel
```

## Geometry rules

Generated geometry must use the same deterministic integer-mm coordinate model as manual authoring.

Mandatory constraints:

- no degenerate polygons;
- no unintended room overlap;
- rooms remain inside their intended level envelope;
- openings/cores generated only with valid hosts;
- minimum geometry values are validated before commit;
- generated levels retain explicit elevation and floor-to-floor height;
- generation does not create platform-dependent floating-point layout differences.

## Popular apartment topology strategy

Do not hard-code one drawing per `roomCount` only.

Use a small set of composable topology families plus constraints, for example:

```text
1-room
├── compact
├── linear
└── corner

2-room
├── linear
├── dual-aspect
├── central-hall
└── corner

3-room
├── corridor
├── dual-aspect
├── split-day-night
└── corner

4..6-room
├── corridor
├── central-hall
├── split-day-night
└── dual-aspect

7..10-room
├── zoned corridor
├── central-hall
├── split-day-night
└── multi-wing
```

The exact preset library can grow independently from the canonical project schema.

## Native UI rule

The wizard UI is adaptive but native-only.

Desktop may use a multi-column modal/window:

```text
[Category] [Parameters] [Preview]
```

Tablet may use a wide stepper/sheet.

Phone may use a sequential full-screen stepper.

All variants MUST submit the same normalized `ProjectWizardRequest` and produce the same canonical result.

No Web implementation is required or implied.

## Local-first and persistence compatibility

Wizard generation is fully available offline.

It must not call backend services to create the project.

The generated result follows the accepted architecture:

```text
Native UI
  ↓
Application/domain generator
  ↓
canonical project model
  ↓
ProjectRepository boundary
  ↓
local native persistence
  ↓
future Sync Engine
```

Generated projects must round-trip through `EditorProjectDocument.capture()/restore()` during the current stage and remain compatible with the target Drift/SQLite persistence model.

## Sync/revision compatibility

The wizard creates canonical project state only.

Future synchronization uses the same stable identity and revision rules as manually authored projects.

The wizard MUST NOT:

- silently replace a remote project;
- reset `projectId` after creation;
- regenerate existing entity IDs during later edits;
- bypass revision conflicts;
- create a template-specific backend format.

## Failure behavior

Generation is fail-closed.

Reject before commit when there is:

```text
unsupported room count
invalid topology/parameter combination
invalid area/shape constraints
invalid level numbering/elevation
invalid generated geometry
duplicate permanent identity
invalid zone/space references
invalid vertical-core references
```

Warnings that do not invalidate the graph may be shown in preview, but invalid canonical geometry cannot be committed.

## Acceptance scenarios

Wizard v1 acceptance includes:

```text
W01 Wizard action is discoverable
W02 Wizard works without network
W03 Apartment family supports roomCount 1
W04 Apartment family supports roomCount 10
W05 at least multiple topology families are available where valid
W06 preview does not mutate canonical project
W07 cancel leaves project unchanged
W08 confirmed apartment generation creates canonical levels/zones/spaces
W09 cottage generation creates valid multi-level hierarchy
W10 building generation creates repeated floors with independent stable identities
W11 residential-complex generation creates multiple canonical buildings on one site
W12 generated project can be manually edited using normal tools
W13 save -> close -> reopen preserves generated hierarchy and geometry
W14 stable IDs survive save/reopen
W15 generated project remains compatible with future revision-aware sync contract
W16 same generated project can be opened on every supported native platform
W17 no Web/browser fallback or browser persistence is involved
```

## Implementation order

```text
G1 wizard architecture + request/result contracts
G2 deterministic template catalog
G3 apartment generator 1..10 rooms
G4 apartment topology-family library
G5 preview + validation
G6 atomic commit into canonical project
G7 cottage generator
G8 building/repeated-floor generator
G9 residential-complex composition
G10 persistence/reopen tests
G11 macOS qualification
G12 Windows/Linux qualification
G13 Android/iPadOS/iOS qualification
```

## Non-negotiable conclusion

The Wizard is a deterministic native authoring layer over the canonical ElecX project model.

It accelerates creation of apartments, cottages, buildings and residential complexes, but it MUST NOT create another domain model, persistence format, platform-specific project type or Web architecture.