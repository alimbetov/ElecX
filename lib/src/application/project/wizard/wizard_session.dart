import '../../../domain/project_aggregate.dart';
import '../project_mutation.dart';
import '../project_mutation_reservation.dart';
import 'project_wizard_mutation_port.dart';
import 'wizard_contracts.dart';

enum WizardSessionStatus {
  idle,
  selectingFamily,
  editingParameters,
  generating,
  selectingVariant,
  previewReady,
  previewBlocked,
  committing,
  completed,
  cancelled,
  failed,
}

enum WizardPreviewBlockReason { staleBaseVersion, noChanges }

/// One application-level Wizard state machine.
///
/// It owns draft parameters and a reserved preview only. Canonical versioning,
/// validation, commit and Undo/Redo remain owned by [ProjectWizardMutationPort]
/// and its shared ProjectMutationSession.
final class WizardSession {
  WizardSession({
    required WizardTargetContext target,
    required this.registry,
    required this.mutations,
  }) : _target = target {
    if (mutations.project.id != target.projectId ||
        mutations.project.siteId != target.siteId) {
      throw ArgumentError(
        'Wizard target must belong to the canonical mutation project.',
      );
    }
  }

  WizardTargetContext _target;
  final WizardProviderRegistry registry;
  final ProjectWizardMutationPort mutations;

  WizardSessionStatus _status = WizardSessionStatus.idle;
  WizardProvider? _provider;
  WizardParameters? _parameters;
  WizardParameterValidation _validation =
      const WizardParameterValidation.valid();
  ReservedProjectMutationPreview? _preview;
  ReservedProjectCommand? _generatedCommand;
  ReservedProjectMutationCommitResult? _commitResult;
  WizardPreviewBlockReason? _blockReason;
  Object? _failure;

  WizardTargetContext get target => _target;
  WizardSessionStatus get status => _status;
  WizardProvider? get provider => _provider;
  WizardParameters? get parameters => _parameters;
  WizardParameterValidation get validation => _validation;
  ReservedProjectMutationPreview? get preview => _preview;

  /// The exact immutable command used to create [preview].
  ///
  /// Provider-specific presentation may inspect this object to render rich
  /// preview data, but Apply always commits the already frozen reserved preview
  /// and never rebuilds the command or reruns a provider pipeline.
  ReservedProjectCommand? get generatedCommand => _generatedCommand;

  ReservedProjectMutationCommitResult? get commitResult => _commitResult;
  WizardPreviewBlockReason? get blockReason => _blockReason;
  Object? get failure => _failure;

  bool get canConfirm =>
      _status == WizardSessionStatus.previewReady &&
      (_preview?.hasChanges ?? false) &&
      !_validation.hasBlockers;

  List<WizardProviderDescriptor> get availableProviders =>
      registry.availableFor(_target);

  bool begin() {
    if (_status != WizardSessionStatus.idle) return false;
    _status = WizardSessionStatus.selectingFamily;
    return true;
  }

  bool selectFamily(WizardFamilyId familyId) {
    if (_status != WizardSessionStatus.selectingFamily &&
        _status != WizardSessionStatus.editingParameters) {
      return false;
    }
    final selected = registry.providerFor(familyId, _target);
    if (selected == null) return false;
    _provider = selected;
    _parameters = selected.defaultsFor(_target);
    _validation = const WizardParameterValidation.valid();
    _discardPreparedPreview();
    _commitResult = null;
    _blockReason = null;
    _failure = null;
    _status = WizardSessionStatus.editingParameters;
    return true;
  }

  bool updateParameters(WizardParameters parameters) {
    final selected = _provider;
    if (selected == null || !selected.acceptsParameters(parameters)) {
      return false;
    }
    if (_status != WizardSessionStatus.editingParameters &&
        _status != WizardSessionStatus.previewReady &&
        _status != WizardSessionStatus.previewBlocked &&
        _status != WizardSessionStatus.failed) {
      return false;
    }
    _parameters = parameters;
    _validation = const WizardParameterValidation.valid();
    _discardPreparedPreview();
    _commitResult = null;
    _blockReason = null;
    _failure = null;
    _status = WizardSessionStatus.editingParameters;
    return true;
  }

  bool generatePreview() {
    final selected = _provider;
    final draft = _parameters;
    if (_status != WizardSessionStatus.editingParameters ||
        selected == null ||
        draft == null) {
      return false;
    }
    if (mutations.version != _target.baseVersion) {
      _discardPreparedPreview();
      _blockReason = WizardPreviewBlockReason.staleBaseVersion;
      _status = WizardSessionStatus.previewBlocked;
      return false;
    }

    _validation = selected.validateParameters(draft, _target);
    if (_validation.hasBlockers) return false;

    _status = WizardSessionStatus.generating;
    _failure = null;
    try {
      final command = selected.generate(
        draft,
        WizardGenerationContext(target: _target, project: mutations.project),
      );
      final reserved = mutations.preview(command);
      _generatedCommand = command;
      _preview = reserved;
      if (!reserved.hasChanges) {
        _blockReason = WizardPreviewBlockReason.noChanges;
        _status = WizardSessionStatus.previewBlocked;
        return false;
      }
      _blockReason = null;
      _status = WizardSessionStatus.previewReady;
      return true;
    } on StaleProjectMutationException {
      _discardPreparedPreview();
      _blockReason = WizardPreviewBlockReason.staleBaseVersion;
      _status = WizardSessionStatus.previewBlocked;
      return false;
    } catch (error) {
      _discardPreparedPreview();
      _failure = error;
      _status = WizardSessionStatus.failed;
      return false;
    }
  }

  bool confirm() {
    final planned = _preview;
    if (!canConfirm || planned == null) return false;
    _status = WizardSessionStatus.committing;
    _failure = null;
    try {
      final result = mutations.commitPreview(planned);
      if (result == null) {
        _blockReason = WizardPreviewBlockReason.noChanges;
        _status = WizardSessionStatus.previewBlocked;
        return false;
      }
      _commitResult = result;
      _status = WizardSessionStatus.completed;
      return true;
    } on StaleProjectMutationException {
      _blockReason = WizardPreviewBlockReason.staleBaseVersion;
      _status = WizardSessionStatus.previewBlocked;
      return false;
    } catch (error) {
      _failure = error;
      _status = WizardSessionStatus.failed;
      return false;
    }
  }

  /// Rebinds the draft workflow to the current canonical version without
  /// changing any selected family or parameter values. A fresh preview must be
  /// generated after rebasing; the old reservation is never reused.
  bool rebaseToCurrent() {
    if (_status != WizardSessionStatus.previewBlocked ||
        _blockReason != WizardPreviewBlockReason.staleBaseVersion) {
      return false;
    }
    _target = _targetWithVersion(_target, mutations.version);
    _discardPreparedPreview();
    _commitResult = null;
    _blockReason = null;
    _failure = null;
    _status = _provider == null
        ? WizardSessionStatus.selectingFamily
        : WizardSessionStatus.editingParameters;
    return true;
  }

  bool back() {
    switch (_status) {
      case WizardSessionStatus.previewReady:
      case WizardSessionStatus.previewBlocked:
      case WizardSessionStatus.selectingVariant:
      case WizardSessionStatus.failed:
        _discardPreparedPreview();
        _blockReason = null;
        _failure = null;
        _status = WizardSessionStatus.editingParameters;
        return true;
      case WizardSessionStatus.editingParameters:
        _discardPreparedPreview();
        _provider = null;
        _parameters = null;
        _validation = const WizardParameterValidation.valid();
        _status = WizardSessionStatus.selectingFamily;
        return true;
      default:
        return false;
    }
  }

  bool cancel() {
    if (_status == WizardSessionStatus.completed ||
        _status == WizardSessionStatus.cancelled ||
        _status == WizardSessionStatus.committing) {
      return false;
    }
    _discardPreparedPreview();
    _commitResult = null;
    _blockReason = null;
    _failure = null;
    _status = WizardSessionStatus.cancelled;
    return true;
  }

  void _discardPreparedPreview() {
    final planned = _preview;
    if (planned != null) {
      mutations.discardPreview(planned);
      _preview = null;
    }
    _generatedCommand = null;
  }
}

WizardTargetContext _targetWithVersion(
  WizardTargetContext target,
  LocalProjectVersion version,
) =>
    switch (target) {
      NewProjectWizardTarget() => NewProjectWizardTarget(
          projectId: target.projectId,
          siteId: target.siteId,
          baseVersion: version,
        ),
      SiteWizardTarget() => SiteWizardTarget(
          projectId: target.projectId,
          siteId: target.siteId,
          baseVersion: version,
        ),
      BuildingWizardTarget(:final buildingId) => BuildingWizardTarget(
          projectId: target.projectId,
          siteId: target.siteId,
          baseVersion: version,
          buildingId: buildingId,
        ),
      LevelWizardTarget(:final buildingId, :final levelId) => LevelWizardTarget(
          projectId: target.projectId,
          siteId: target.siteId,
          baseVersion: version,
          buildingId: buildingId,
          levelId: levelId,
        ),
    };
