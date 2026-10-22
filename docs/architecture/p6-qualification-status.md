# P6 qualification status

Branch: `feat/project-structure-authoring`

## Current gate

P6 implementation and hardening have landed through the production room-semantics wiring and ownership tests. The stage is not considered closed until the final branch HEAD passes the repository qualification workflows after formatter normalization.

The formatter-normalization commit removed the one-shot formatter workflow and normalized `lib/` and `test/`. Because that commit was authored by `github-actions[bot]`, GitHub marked the pull-request workflows for that bot-authored HEAD as `action_required` instead of executing the jobs. This document commit intentionally establishes a normal authored HEAD so the standard Flutter and macOS qualification workflows can execute against the normalized tree.

Required closure gates:

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- macOS analyze
- macOS test
- macOS debug build
- runtime `path_provider` smoke

Any code or test regression exposed by these gates is a P6 blocker and must be fixed before P6 is marked `DONE + HARDENED`.

## P6/P7 boundary remains unchanged

P6 owns `SpaceUsage`, openings, adjacency and overlay classifications. Durable wall identity, `BoundaryEdgeId` lineage and wall-host migration remain P7. P6 must not introduce a durable `wallIndex` foreign key.
