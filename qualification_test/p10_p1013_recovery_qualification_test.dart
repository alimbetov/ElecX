import 'dart:io';

import 'package:elecx/src/application/project/canonical_project_persistence_owner.dart';
import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/composition_provenance_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/p1011_wizard_fixture.dart';
import '../test/support/p109_site_fixture.dart';

void main() {
  test(
      'P10-E failed asynchronous Save preserves previous durable state; retry persists complete v19 lineage',
      () async {
    final directory = await Directory.systemTemp.createTemp('p10-recovery-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = _RejectSaveOnce(JsonProjectRepository(
        rootDirectory: directory,
        codec:
            const CompositionProvenanceAwareCanonicalProjectDocumentCodec()));
    final r = P1011WizardRuntime();
    final owner = CanonicalProjectPersistenceOwner(
        repository: repository, snapshot: p109Snapshot(r.mutations.current));
    await owner.save();
    final before = p1011Bytes(owner.project, includeVersion: false);
    expect(r.wizard.generatePreview(), isTrue);
    expect(r.wizard.confirm(), isTrue);
    owner.acceptMutation(
        sessionProject: r.mutations.current,
        result: r.wizard.commitResult!.mutation);
    final accepted = p1011Bytes(owner.project, includeVersion: false);
    repository.rejectNext = true;
    await expectLater(owner.save(), throwsStateError);
    expect(p1011Bytes(owner.project, includeVersion: false), accepted);
    final previous = (await repository.load(owner.projectId))!;
    expect(p1011Bytes(previous.aggregate, includeVersion: false), before);
    expect(r.mutations.undoDepth, 1);
    await owner.save();
    final reopened = (await CanonicalProjectPersistenceOwner.load(
        repository: repository, projectId: owner.projectId))!;
    expect(p1011Bytes(reopened.project, includeVersion: false), accepted);
    expect(
        reopened.project.engineeringMetadata.generationProvenanceRegistry
            .compositions,
        hasLength(1));
  });
}

final class _RejectSaveOnce implements ProjectRepository {
  _RejectSaveOnce(this.delegate);
  final ProjectRepository delegate;
  bool rejectNext = false;
  @override
  Future<List<ProjectSummary>> list() => delegate.list();
  @override
  Future<ProjectSnapshot?> load(ProjectId id) => delegate.load(id);
  @override
  Future<void> save(ProjectSnapshot snapshot) async {
    if (rejectNext) {
      rejectNext = false;
      throw StateError('Qualification write fault');
    }
    await delegate.save(snapshot);
  }
}
