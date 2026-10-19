import 'package:flutter/foundation.dart';

import '../../domain/boundary_editing.dart';
import '../../domain/surfaces.dart';
import 'editor_controller.dart';

final class OpeningEditDraft {
  const OpeningEditDraft({
    required this.openingId,
    required this.type,
    required this.offsetFromStartMm,
    required this.widthMm,
    required this.heightMm,
    required this.sillHeightMm,
  });

  factory OpeningEditDraft.fromOpening(ArchitecturalOpening opening) =>
      OpeningEditDraft(
        openingId: opening.id,
        type: opening.type,
        offsetFromStartMm: opening.offsetFromStartMm,
        widthMm: opening.widthMm,
        heightMm: opening.heightMm,
        sillHeightMm: opening.sillHeightMm,
      );

  final String openingId;
  final ArchitecturalOpeningType type;
  final int offsetFromStartMm;
  final int widthMm;
  final int heightMm;
  final int sillHeightMm;

  int get endOffsetMm => offsetFromStartMm + widthMm;
  int get topMm => sillHeightMm + heightMm;

  OpeningEditDraft copyWith({
    ArchitecturalOpeningType? type,
    int? offsetFromStartMm,
    int? widthMm,
    int? heightMm,
    int? sillHeightMm,
  }) =>
      OpeningEditDraft(
        openingId: openingId,
        type: type ?? this.type,
        offsetFromStartMm: offsetFromStartMm ?? this.offsetFromStartMm,
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        sillHeightMm: sillHeightMm ?? this.sillHeightMm,
      );

  ArchitecturalOpening toOpening(ArchitecturalOpening source) => source.copyWith(
        type: type,
        offsetFromStartMm: offsetFromStartMm,
        widthMm: widthMm,
        heightMm: heightMm,
        sillHeightMm: sillHeightMm,
      );

  bool matches(ArchitecturalOpening opening) =>
      opening.id == openingId &&
      opening.type == type &&
      opening.offsetFromStartMm == offsetFromStartMm &&
      opening.widthMm == widthMm &&
      opening.heightMm == heightMm &&
      opening.sillHeightMm == sillHeightMm;
}

final class BeamEditDraft {
  const BeamEditDraft({
    required this.startMm,
    required this.widthMm,
    required this.depthMm,
    required this.originalStartMm,
    required this.originalWidthMm,
    required this.originalDepthMm,
    required this.isNew,
  });

  factory BeamEditDraft.existing({
    required int startMm,
    required int widthMm,
    required int depthMm,
  }) =>
      BeamEditDraft(
        startMm: startMm,
        widthMm: widthMm,
        depthMm: depthMm,
        originalStartMm: startMm,
        originalWidthMm: widthMm,
        originalDepthMm: depthMm,
        isNew: false,
      );

  factory BeamEditDraft.newDraft({
    required int startMm,
    required int widthMm,
    required int depthMm,
  }) =>
      BeamEditDraft(
        startMm: startMm,
        widthMm: widthMm,
        depthMm: depthMm,
        originalStartMm: startMm,
        originalWidthMm: widthMm,
        originalDepthMm: depthMm,
        isNew: true,
      );

  final int startMm;
  final int widthMm;
  final int depthMm;
  final int originalStartMm;
  final int originalWidthMm;
  final int originalDepthMm;
  final bool isNew;

  bool get dirty =>
      isNew ||
      startMm != originalStartMm ||
      widthMm != originalWidthMm ||
      depthMm != originalDepthMm;

  BeamEditDraft copyWith({int? startMm, int? widthMm, int? depthMm}) =>
      BeamEditDraft(
        startMm: startMm ?? this.startMm,
        widthMm: widthMm ?? this.widthMm,
        depthMm: depthMm ?? this.depthMm,
        originalStartMm: originalStartMm,
        originalWidthMm: originalWidthMm,
        originalDepthMm: originalDepthMm,
        isNew: isNew,
      );
}

final class BoundaryEditSession extends ChangeNotifier {
  BoundaryEditProfile? _profile;
  String? _hoveredOpeningId;
  OpeningEditDraft? _openingDraft;
  BeamEditDraft? _beamDraft;

  bool get active => _profile != null;
  BoundaryEditProfile? get profile => _profile;
  String? get hoveredOpeningId => _hoveredOpeningId;
  OpeningEditDraft? get openingDraft => _openingDraft;
  BeamEditDraft? get beamDraft => _beamDraft;

  bool get draftDirty {
    final opening = _openingDraft;
    final beam = _beamDraft;
    return (opening != null && _openingDraftDirty) || (beam?.dirty ?? false);
  }

  bool _openingDraftDirty = false;

  void enter([BoundaryEditProfile profile = BoundaryEditProfile.wall]) {
    _profile = profile;
    _hoveredOpeningId = null;
    notifyListeners();
  }

  void setProfile(BoundaryEditProfile profile) {
    if (_profile == profile) return;
    _profile = profile;
    _hoveredOpeningId = null;
    clearDrafts();
    notifyListeners();
  }

  void hoverOpening(String? openingId) {
    if (_profile != BoundaryEditProfile.openings ||
        _hoveredOpeningId == openingId) {
      return;
    }
    _hoveredOpeningId = openingId;
    notifyListeners();
  }

  void beginOpeningDraft(ArchitecturalOpening opening) {
    if (_openingDraft?.openingId == opening.id) return;
    _openingDraft = OpeningEditDraft.fromOpening(opening);
    _openingDraftDirty = false;
    _beamDraft = null;
    notifyListeners();
  }

  void updateOpeningDraft(OpeningEditDraft draft) {
    if (_openingDraft == draft) return;
    _openingDraft = draft;
    _openingDraftDirty = true;
    notifyListeners();
  }

  void beginBeamDraft(BeamEditDraft draft) {
    _beamDraft = draft;
    _openingDraft = null;
    _openingDraftDirty = false;
    notifyListeners();
  }

  void updateBeamDraft(BeamEditDraft draft) {
    _beamDraft = draft;
    notifyListeners();
  }

  void markSaved() {
    final opening = _openingDraft;
    final beam = _beamDraft;
    if (opening != null) {
      _openingDraftDirty = false;
    }
    if (beam != null) {
      _beamDraft = BeamEditDraft.existing(
        startMm: beam.startMm,
        widthMm: beam.widthMm,
        depthMm: beam.depthMm,
      );
    }
    notifyListeners();
  }

  void clearDrafts() {
    _openingDraft = null;
    _beamDraft = null;
    _openingDraftDirty = false;
  }

  void discardDraft() {
    clearDrafts();
    notifyListeners();
  }

  void exit({bool force = false}) {
    if (draftDirty && !force) return;
    if (_profile == null && _hoveredOpeningId == null) return;
    _profile = null;
    _hoveredOpeningId = null;
    clearDrafts();
    notifyListeners();
  }
}

final Expando<BoundaryEditSession> _boundaryEditSessions =
    Expando<BoundaryEditSession>('ElecX boundary edit session');

extension BoundaryEditSessionAccess on EditorController {
  BoundaryEditSession get boundaryEditing =>
      _boundaryEditSessions[this] ??= BoundaryEditSession();
}
