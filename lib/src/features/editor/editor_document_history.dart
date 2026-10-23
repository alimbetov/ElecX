import 'package:flutter/foundation.dart';

import '../../application/project/project_mutation.dart';
import '../../application/project/project_structure_authoring.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/command_history.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

typedef CanonicalHistoryRematerializer = void Function();
typedef CanonicalHistoryReplayOwner = void Function(
  ProjectMutationResult result,
);

final class EditorDocumentHistory extends ChangeNotifier {
  EditorDocumentHistory(this.controller)
      : _architecture = _ArchitectureSnapshot.capture(controller),
        _p2 = controller.p2,
        _p2Revision = controller.p2.history.mutationRevision {
    controller.addListener(_onArchitectureChanged);
    _p2.addListener(_onP2Changed);
  }

  final EditorController controller;
  final List<_DocumentEntry> _undo = <_DocumentEntry>[];
  final List<_DocumentEntry> _redo = <_DocumentEntry>[];
  late _ArchitectureSnapshot _architecture;
  final EditorP2Session _p2;
  int _p2Revision;
  bool _replaying = false;
  int _canonicalProjectionDepth = 0;
  ProjectStructureAuthoringSession? _canonicalSession;
  LocalProjectVersion? _canonicalObservedVersion;
  CanonicalHistoryReplayOwner? _canonicalReplayOwner;

  bool get _canonicalJournalIsCurrent {
    final session = _canonicalSession;
    if (session == null) return true;
    final observed = _canonicalObservedVersion;
    return observed != null && session.project.version == observed;
  }

  bool get canUndo => _undo.isNotEmpty && _canonicalJournalIsCurrent;
  bool get canRedo => _redo.isNotEmpty && _canonicalJournalIsCurrent;
  int get undoDepth => _undo.length;
  int get redoDepth => _redo.length;
  String? get undoLabel => canUndo ? _undo.last.label : null;
  String? get redoLabel => canRedo ? _redo.last.label : null;

  bool hasCanonicalSessionAffinity(
    ProjectStructureAuthoringSession session,
  ) =>
      identical(_canonicalSession, session);

  void attachCanonicalSession(
    ProjectStructureAuthoringSession session, {
    CanonicalHistoryReplayOwner? onReplayed,
  }) {
    if (identical(_canonicalSession, session)) {
      _canonicalObservedVersion ??= session.project.version;
      _canonicalReplayOwner = onReplayed;
      return;
    }
    final hadPreviousSession = _canonicalSession != null;
    if (hadPreviousSession) _clearTimeline();
    _canonicalSession = session;
    _canonicalObservedVersion = session.project.version;
    _canonicalReplayOwner = onReplayed;
    if (hadPreviousSession) notifyListeners();
  }

  void detachCanonicalSession(ProjectStructureAuthoringSession session) {
    if (!identical(_canonicalSession, session)) return;
    _canonicalSession = null;
    _canonicalObservedVersion = null;
    _canonicalReplayOwner = null;
    _clearTimeline();
    notifyListeners();
  }

  /// A canonical mutation has already advanced the in-memory project, but the
  /// production persistence owner failed to acknowledge it. The transition
  /// must not remain on the unified Undo/Redo journal because its durability
  /// cannot be proven. Keep only the new canonical version baseline and clear
  /// the chronological timeline fail-closed.
  void invalidateAfterUnownedCanonicalCommit(
    ProjectStructureAuthoringSession session,
  ) {
    if (!identical(_canonicalSession, session)) return;
    _canonicalObservedVersion = session.project.version;
    _clearTimeline();
    notifyListeners();
  }

  /// A canonical transition is already authoritative and persistence ownership
  /// may have succeeded, but a later callback, journal registration or legacy
  /// projection diverged from that exact committed version. Discard the mixed
  /// timeline and re-baseline against the state that is actually authoritative.
  void invalidateAfterCommittedCanonicalDivergence(
    ProjectStructureAuthoringSession session,
  ) {
    if (!identical(_canonicalSession, session)) return;
    _clearTimeline();
    _refreshBaselines();
    notifyListeners();
  }

  /// Records one already-committed P3 mutation in the same chronological
  /// journal as legacy architecture and P2 electrical edits.
  ///
  /// The version must be exactly one step after the last observed canonical
  /// version. Any gap means a canonical mutation bypassed this production
  /// journal, so chronological Undo can no longer be proven and is discarded.
  void recordCanonicalCommit({
    required ProjectStructureAuthoringSession session,
    required String label,
    required CanonicalHistoryRematerializer rematerialize,
  }) {
    if (_replaying) {
      throw StateError(
        'Canonical production history cannot register a new commit during replay.',
      );
    }
    if (!identical(_canonicalSession, session)) {
      throw StateError(
        'Canonical production history lost session affinity before commit registration.',
      );
    }

    final observed = _canonicalObservedVersion;
    final current = session.project.version;
    if (observed == null || current.value != observed.value + 1) {
      _canonicalObservedVersion = current;
      _clearTimeline();
      notifyListeners();
      return;
    }

    _canonicalObservedVersion = current;
    _push(
      _CanonicalEntry(
        label: label,
        session: session,
        rematerialize: rematerialize,
      ),
    );
  }

  /// Runs canonical -> legacy projection without manufacturing a second legacy
  /// architecture/P2 history entry. Screen dirty-state listeners remain active;
  /// this suppression is scoped only to the unified document-history journal.
  T runCanonicalProjection<T>(T Function() action) {
    _canonicalProjectionDepth++;
    try {
      return action();
    } finally {
      _canonicalProjectionDepth--;
      _architecture = _ArchitectureSnapshot.capture(controller);
      _p2Revision = _p2.history.mutationRevision;
    }
  }

  void _onArchitectureChanged() {
    if (_replaying) return;
    final next = _ArchitectureSnapshot.capture(controller);
    if (_canonicalProjectionDepth > 0) {
      _architecture = next;
      return;
    }
    if (!_architecture.sameDocumentIdentity(next)) {
      _push(_ArchitectureEntry(before: _architecture, after: next));
    }
    _architecture = next;
  }

  void _onP2Changed() {
    if (_replaying) return;
    final revision = _p2.history.mutationRevision;
    if (_canonicalProjectionDepth > 0) {
      _p2Revision = revision;
      return;
    }
    if (revision == _p2Revision) return;

    if (_p2.history.lastMutationKind != CommandHistoryMutationKind.execute ||
        revision != _p2Revision + 1) {
      _clearTimeline();
      _p2Revision = revision;
      notifyListeners();
      return;
    }

    _p2Revision = revision;
    _push(_P2Entry(label: _p2.history.undoLabel ?? 'Electrical edit'));
  }

  void _push(_DocumentEntry entry) {
    _undo.add(entry);
    if (_undo.length > 200) _undo.removeAt(0);
    _redo.clear();
    notifyListeners();
  }

  void _clearTimeline() {
    _undo.clear();
    _redo.clear();
  }

  bool undo() {
    if (_p2.isManipulating) return false;
    if (_rejectCanonicalVersionGap()) return false;
    if (_undo.isEmpty) return false;
    final entry = _undo.removeLast();
    _replaying = true;
    var succeeded = false;
    try {
      entry.undo(this);
      _redo.add(entry);
      _refreshBaselines();
      succeeded = true;
    } catch (_) {
      _reconcileCanonicalAfterHistoryFailure(entry);
      _clearTimeline();
      _refreshBaselines();
    } finally {
      _replaying = false;
    }
    notifyListeners();
    return succeeded;
  }

  bool redo() {
    if (_p2.isManipulating) return false;
    if (_rejectCanonicalVersionGap()) return false;
    if (_redo.isEmpty) return false;
    final entry = _redo.removeLast();
    _replaying = true;
    var succeeded = false;
    try {
      entry.redo(this);
      _undo.add(entry);
      _refreshBaselines();
      succeeded = true;
    } catch (_) {
      _reconcileCanonicalAfterHistoryFailure(entry);
      _clearTimeline();
      _refreshBaselines();
    } finally {
      _replaying = false;
    }
    notifyListeners();
    return succeeded;
  }

  /// Rejects every document-history replay when the attached canonical session
  /// has advanced outside this journal. This guard deliberately runs before
  /// examining the top entry: a P2/legacy entry must not be replayed "through"
  /// a hidden P3 transition just because it happens to sit above the last
  /// canonical entry.
  bool _rejectCanonicalVersionGap() {
    final session = _canonicalSession;
    if (session == null) return false;
    final observed = _canonicalObservedVersion;
    if (observed != null && session.project.version == observed) return false;

    final topEntry =
        _undo.isNotEmpty ? _undo.last : (_redo.isNotEmpty ? _redo.last : null);
    if (topEntry is _CanonicalEntry) {
      _reconcileCanonicalAfterHistoryFailure(topEntry);
    }
    _clearTimeline();
    _refreshBaselines();
    notifyListeners();
    return true;
  }

  /// A canonical replay can fail before mutation because the observed version
  /// is stale, or after mutation because rematerialization/ownership failed.
  /// In both cases canonical state remains authoritative. Re-project it when
  /// the entry still belongs to the attached canonical session so the legacy
  /// editor cannot remain a second, stale representation after the timeline is
  /// invalidated.
  void _reconcileCanonicalAfterHistoryFailure(_DocumentEntry entry) {
    if (entry is! _CanonicalEntry) return;
    final session = _canonicalSession;
    if (session == null || !identical(session, entry.session)) return;
    try {
      entry.rematerialize();
    } catch (_) {
      // The timeline is still invalidated below. A rematerialization failure is
      // intentionally not allowed to trigger a second history mutation.
    }
  }

  void _refreshBaselines() {
    _architecture = _ArchitectureSnapshot.capture(controller);
    _p2Revision = _p2.history.mutationRevision;
    final canonical = _canonicalSession;
    if (canonical != null) {
      _canonicalObservedVersion = canonical.project.version;
    }
  }

  void _restoreArchitecture(_ArchitectureSnapshot snapshot) {
    controller.restoreDocumentArchitecture(
      level: snapshot.level,
      openings: snapshot.openings,
      roomSequence: snapshot.roomSequence,
      openingSequence: snapshot.openingSequence,
      selectedSpaceId: snapshot.selectedSpaceId,
      selectedOpeningId: snapshot.selectedOpeningId,
    );
  }

  void _undoP2() => _p2.undo();
  void _redoP2() => _p2.redo();

  void _undoCanonical(_CanonicalEntry entry) {
    final session = _requireCanonicalAffinity(entry);
    final owner = _requireCanonicalReplayOwner();
    final result = session.undoCanonicalMutation();
    if (result == null) {
      throw StateError('Canonical history expected an undoable P3 mutation.');
    }
    _canonicalObservedVersion = result.project.version;

    // A canonical replay is already authoritative once ProjectMutationSession
    // advances. Persistence ownership must therefore be attempted before any
    // compatibility projection that can fail. This mirrors the normal P7A-5
    // commit path and guarantees that rematerialization failure cannot prevent
    // the persistence owner from seeing the committed canonical transition.
    owner(result);
    _requireCanonicalReplayResultCurrent(session, result);
    entry.rematerialize();
    _requireCanonicalReplayResultCurrent(session, result);
  }

  void _redoCanonical(_CanonicalEntry entry) {
    final session = _requireCanonicalAffinity(entry);
    final owner = _requireCanonicalReplayOwner();
    final result = session.redoCanonicalMutation();
    if (result == null) {
      throw StateError('Canonical history expected a redoable P3 mutation.');
    }
    _canonicalObservedVersion = result.project.version;
    owner(result);
    _requireCanonicalReplayResultCurrent(session, result);
    entry.rematerialize();
    _requireCanonicalReplayResultCurrent(session, result);
  }

  void _requireCanonicalReplayResultCurrent(
    ProjectStructureAuthoringSession session,
    ProjectMutationResult result,
  ) {
    if (!identical(_canonicalSession, session)) {
      throw StateError(
        'Canonical production history switched sessions during replay.',
      );
    }
    if (session.project.version != result.project.version) {
      throw StateError(
        'Canonical project advanced re-entrantly during history replay.',
      );
    }
  }

  ProjectStructureAuthoringSession _requireCanonicalAffinity(
    _CanonicalEntry entry,
  ) {
    final session = _canonicalSession;
    if (session == null || !identical(session, entry.session)) {
      throw StateError('Canonical production history lost session affinity.');
    }
    final observed = _canonicalObservedVersion;
    if (observed == null || session.project.version != observed) {
      throw StateError('Canonical production history observed a version gap.');
    }
    return session;
  }

  CanonicalHistoryReplayOwner _requireCanonicalReplayOwner() {
    final owner = _canonicalReplayOwner;
    if (owner == null) {
      throw StateError(
        'Canonical production history has no persistence owner for replay.',
      );
    }
    return owner;
  }

  @override
  void dispose() {
    controller.removeListener(_onArchitectureChanged);
    _p2.removeListener(_onP2Changed);
    super.dispose();
  }
}

sealed class _DocumentEntry {
  const _DocumentEntry();
  String get label;
  void undo(EditorDocumentHistory history);
  void redo(EditorDocumentHistory history);
}

final class _ArchitectureEntry extends _DocumentEntry {
  const _ArchitectureEntry({required this.before, required this.after});
  final _ArchitectureSnapshot before;
  final _ArchitectureSnapshot after;

  @override
  String get label => 'Edit architecture';

  @override
  void undo(EditorDocumentHistory history) =>
      history._restoreArchitecture(before);

  @override
  void redo(EditorDocumentHistory history) =>
      history._restoreArchitecture(after);
}

final class _P2Entry extends _DocumentEntry {
  const _P2Entry({required this.label});

  @override
  final String label;

  @override
  void undo(EditorDocumentHistory history) => history._undoP2();

  @override
  void redo(EditorDocumentHistory history) => history._redoP2();
}

final class _CanonicalEntry extends _DocumentEntry {
  const _CanonicalEntry({
    required this.label,
    required this.session,
    required this.rematerialize,
  });

  @override
  final String label;
  final ProjectStructureAuthoringSession session;
  final CanonicalHistoryRematerializer rematerialize;

  @override
  void undo(EditorDocumentHistory history) => history._undoCanonical(this);

  @override
  void redo(EditorDocumentHistory history) => history._redoCanonical(this);
}

final class _ArchitectureSnapshot {
  const _ArchitectureSnapshot({
    required this.level,
    required this.openings,
    required this.roomSequence,
    required this.openingSequence,
    required this.selectedSpaceId,
    required this.selectedOpeningId,
  });

  factory _ArchitectureSnapshot.capture(EditorController controller) =>
      _ArchitectureSnapshot(
        level: controller.level,
        openings: controller.openings,
        roomSequence: controller.roomSequence,
        openingSequence: controller.openingSequence,
        selectedSpaceId: controller.selectedSpaceId,
        selectedOpeningId: controller.selectedOpeningId,
      );

  final BuildingLevel level;
  final List<ArchitecturalOpening> openings;
  final int roomSequence;
  final int openingSequence;
  final String? selectedSpaceId;
  final String? selectedOpeningId;

  bool sameDocumentIdentity(_ArchitectureSnapshot other) =>
      identical(level, other.level) && identical(openings, other.openings);
}

final Expando<EditorDocumentHistory> _documentHistories =
    Expando<EditorDocumentHistory>('ElecX document history');

extension EditorDocumentHistoryAccess on EditorController {
  EditorDocumentHistory get documentHistory =>
      _documentHistories[this] ??= EditorDocumentHistory(this);

  void disposeDocumentHistory() {
    _documentHistories[this]?.dispose();
    _documentHistories[this] = null;
  }
}
