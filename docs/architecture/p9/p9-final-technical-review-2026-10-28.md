# P9 Apartment Topology Generator — Final Technical Review

Date: 2026-10-28

Branch: `feat/p9-apartment-topology-generator`

## Decision

P9 is a **feature-complete merge candidate**.

Final merge acceptance is intentionally SHA-bound: the exact branch HEAD to be merged must pass the repository Flutter workflow with formatting, static analysis, the P8 NFR gates and the complete Flutter test suite, and the branch must not be behind `main`.

This review does not permit a green result from an older SHA to qualify a newer documentation or code commit.

## Scope boundary

The authoritative P9 product feature is apartment topology generation:

```text
parameters
  -> deterministic candidate generation
  -> ranking / candidate selection
  -> vector preview
  -> P8 Preview/Diff reservation
  -> canonical materialization
  -> provenance
  -> persistence
  -> Apply / Undo / Redo
```

The D1-D8 apartment electrical engineering pipeline is an additive capability layered on the same frozen Wizard command. It must never invent authoritative electrical data merely to make P9 topology usable.

Two explicit runtime modes therefore exist:

```text
topology-only
  no authoritative electrical pipeline is configured
  topology generation remains available
  no engineering proposal or electrical snapshot is created
  Preview explicitly states that electrical values were not assumed

engineering-enabled
  an authoritative ApartmentEngineeringPipeline is configured
  D8 output is frozen into the generated command
  Preview displays the exact frozen output
  Apply persists the same proposal without rerunning the pipeline
```

Silent fallback from engineering-enabled generation to fabricated or assumed electrical values is forbidden.

## Review findings and resolutions

### R1 — production Wizard composition could silently omit engineering

Resolution:

- production and topology-only provider construction are explicit;
- `ApartmentWizardProvider.production(...)` requires a pipeline;
- `ApartmentWizardProvider.geometryOnly()` represents the topology-only mode;
- runtime capability registration is scoped to `ProjectStructureAuthoringSession`, so it survives canonical project mutations, Undo and Redo;
- the canonical navigator chooses one of the two modes explicitly.

### R2 — full engineering orchestration started too late in the evidence chain

Resolution:

The production orchestrator supports the complete upstream chain before D2:

```text
D1 requirements
  -> authoritative supply evidence
  -> load calculation + evidence
  -> circuit synthesis + evidence
  -> exact synthesis lineage validation
  -> D2 -> D3 -> D4 -> D5 -> D6 -> D7 -> D8
```

Qualification fixture values are not production defaults.

### R3 — Preview hid the frozen D8 engineering output

Resolution:

`ApartmentEngineeringPreviewPanel` reads the exact `ApartmentEngineeringProposal` already frozen in `WizardSession.generatedCommand`. It performs no engineering calculation.

The engineering-enabled Preview exposes:

- panel summary;
- circuits and assigned phase;
- cable and conductor sizing;
- overcurrent protection;
- RCD/residual-current protection;
- fault current and disconnection evidence;
- protection coordination;
- installation sections and evidence sources;
- SLD nodes/connections;
- Why/explanation evidence;
- proposal/output/requirements fingerprints.

Topology-only Preview instead exposes an explicit no-electrical-assumptions state.

### R4 — applied engineering metadata was not first-class in canonical diff

Resolution:

`ProjectEngineeringMetadataDiff` now tracks `appliedEngineeringProposalRegistryChanged`. Therefore Apply, Undo and Redo changes to the frozen engineering snapshot are observable in the canonical change-set.

### R5 — persistence qualification stopped at codec level

Resolution:

Production-path qualification now exercises:

```text
Wizard Apply
  -> ProjectMutationSession
  -> CanonicalProjectPersistenceOwner.acceptMutation
  -> JsonProjectRepository.save
  -> schema-v13 codec
  -> JsonProjectRepository.load
  -> exact engineering snapshot comparison
```

### R6 — stale/tampered Preview qualification was incomplete

Resolution:

Qualification now proves:

- a canonical mutation after Preview blocks Apply with `staleBaseVersion`;
- stale failure does not persist an engineering snapshot;
- candidate-set lineage tampering fails before Preview can become applicable;
- Apply does not rerun engineering after a valid frozen Preview.

### R7 — repository hygiene contained generated analyzer output

Resolution:

The tracked root `analyze.log` was removed. Analyzer output remains CI evidence, not source-controlled product state.

## Merge gates

| Gate | Requirement | Review disposition |
|---|---|---|
| C1 | explicit production/topology runtime composition | CLOSED |
| C2 | Generate -> Preview/Diff -> Apply uses one frozen command and no rerun | CLOSED |
| C3 | Preview exposes D8 circuits/cable/protection/RCD/SLD/Why | CLOSED |
| C4 | save/reload restores exact engineering snapshot | CLOSED |
| C5 | Undo/Redo restores exact snapshot and does not rerun pipeline | CLOSED |
| C6 | stale/tampered proposals fail closed | CLOSED |
| C7 | exact final HEAD passes the complete repository CI workflow | REQUIRED AT MERGE |
| C8 | repository/docs hygiene and branch not behind `main` | REQUIRED AT MERGE |

C7 and the ancestry portion of C8 are deliberately evaluated on the final SHA after all review/documentation commits.

## Qualification anchors

The review adds or extends these qualification surfaces:

```text
test/p9_p96_apartment_wizard_engineering_pipeline_test.dart
  Q91-Q96 frozen engineering lifecycle
  Q102 stale canonical version rejection
  Q103 candidate-set lineage tamper rejection

test/p9_p96_applied_engineering_persistence_test.dart
  Q97 exact frozen Apply snapshot
  Q98 topology-only does not invent engineering state
  Q99 schema-v13 persistence
  Q100 schema-v12 compatibility
  Q101 exact Apply -> Undo -> Redo snapshot

test/p9_p96_production_persistence_owner_test.dart
  Q104 production persistence-owner disk round trip

test/p9_p96_apartment_engineering_preview_panel_test.dart
  Q105 explicit topology-only safety state
  Q106 frozen D8 presentation coverage
```

Existing P9 stage and Golden Journey tests remain part of the repository-wide Flutter test gate.

## Invariants retained

```text
same request + semantic versions -> deterministic ordered candidate set
candidate browsing allocates no canonical IDs
Preview and Apply use the same reserved candidate/command
Apply is atomic through ProjectMutationSession
Undo/Redo operate on canonical state snapshots
provenance survives persistence
engineering fingerprints participate in reserved intent
no production electrical value is invented when authoritative input is absent
```

## Non-blocking forward dependency

The current Project Hub does not itself synthesize authoritative supply/load/PSCC data. Consequently the default runtime can legitimately operate in topology-only mode.

Enabling the additive D1-D8 engineering mode in a production project requires a real authoritative source for supply, load, protection/catalog and policy inputs. That is an engineering-input composition dependency, not a reason to disable or reject the completed P9 topology generator.

## Merge acceptance rule

P9 may be marked `MERGE-READY` only when all of the following are true on the exact final branch HEAD:

```text
Dart formatting                         PASS
flutter analyze                         PASS
P8 NFR reference environment           PASS
P8 accessibility/i18n acceptance       PASS
complete flutter test                   PASS
branch behind main                      0
no generated temporary artifacts       PASS
```

If any newer commit is added, C7/C8 must be re-evaluated for that new SHA.
