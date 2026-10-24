import '../../../domain/project_aggregate.dart';
import '../../../domain/project_identity.dart';
import '../project_mutation_reservation.dart';

/// Canonical insertion scope supported by one Wizard provider.
enum WizardTargetScope { newProject, site, building, level }

/// Explicit target context. Wizard code never infers ownership from widget state.
sealed class WizardTargetContext {
  const WizardTargetContext({
    required this.projectId,
    required this.siteId,
    required this.baseVersion,
  });

  final ProjectId projectId;
  final SiteId siteId;
  final LocalProjectVersion baseVersion;

  WizardTargetScope get scope;
}

final class NewProjectWizardTarget extends WizardTargetContext {
  const NewProjectWizardTarget({
    required super.projectId,
    required super.siteId,
    required super.baseVersion,
  });

  @override
  WizardTargetScope get scope => WizardTargetScope.newProject;
}

final class SiteWizardTarget extends WizardTargetContext {
  const SiteWizardTarget({
    required super.projectId,
    required super.siteId,
    required super.baseVersion,
  });

  @override
  WizardTargetScope get scope => WizardTargetScope.site;
}

final class BuildingWizardTarget extends WizardTargetContext {
  const BuildingWizardTarget({
    required super.projectId,
    required super.siteId,
    required super.baseVersion,
    required this.buildingId,
  });

  final BuildingId buildingId;

  @override
  WizardTargetScope get scope => WizardTargetScope.building;
}

final class LevelWizardTarget extends WizardTargetContext {
  const LevelWizardTarget({
    required super.projectId,
    required super.siteId,
    required super.baseVersion,
    required this.buildingId,
    required this.levelId,
  });

  final BuildingId buildingId;
  final LevelId levelId;

  @override
  WizardTargetScope get scope => WizardTargetScope.level;
}

final class WizardFamilyId {
  WizardFamilyId(String value) : value = _requireNonEmpty(value, 'familyId');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is WizardFamilyId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Root contract for strongly typed provider parameters.
///
/// This is intentionally extensible outside this library because later P9/P10
/// providers live in their own implementation units while still plugging into
/// the common P8 Wizard runtime.
abstract class WizardParameters {
  const WizardParameters();
}

enum WizardIssueSeverity { info, warning, blocker }

final class WizardValidationIssue {
  const WizardValidationIssue({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final WizardIssueSeverity severity;
}

final class WizardParameterValidation {
  WizardParameterValidation(Iterable<WizardValidationIssue> issues)
      : issues = List.unmodifiable(issues);

  const WizardParameterValidation.valid() : issues = const [];

  final List<WizardValidationIssue> issues;

  bool get hasBlockers =>
      issues.any((issue) => issue.severity == WizardIssueSeverity.blocker);
  bool get isValid => !hasBlockers;
}

final class WizardProviderDescriptor {
  WizardProviderDescriptor({
    required this.templateId,
    required this.templateVersion,
    required String generatorVersion,
    required this.familyId,
    required String displayName,
    required Iterable<WizardTargetScope> supportedScopes,
  })  : generatorVersion = _requireNonEmpty(
          generatorVersion,
          'generatorVersion',
        ),
        displayName = _requireNonEmpty(displayName, 'displayName'),
        supportedScopes = Set.unmodifiable(supportedScopes) {
    if (templateVersion <= 0) {
      throw ArgumentError.value(
        templateVersion,
        'templateVersion',
        'Must be positive.',
      );
    }
    if (this.supportedScopes.isEmpty) {
      throw ArgumentError('Wizard provider must support at least one scope.');
    }
  }

  final TemplateId templateId;
  final int templateVersion;
  final String generatorVersion;
  final WizardFamilyId familyId;
  final String displayName;
  final Set<WizardTargetScope> supportedScopes;

  bool supports(WizardTargetContext target) =>
      supportedScopes.contains(target.scope);
}

/// Type-erased application boundary used by the one shared Wizard session.
/// Provider implementations should normally extend [TypedWizardProvider].
abstract interface class WizardProvider {
  WizardProviderDescriptor get descriptor;

  WizardParameters defaultsFor(WizardTargetContext target);

  bool acceptsParameters(WizardParameters parameters);

  WizardParameterValidation validateParameters(
    WizardParameters parameters,
    WizardTargetContext target,
  );

  ReservedProjectCommand generate(
    WizardParameters parameters,
    WizardGenerationContext context,
  );
}

/// Typed adapter that keeps provider implementation code free from casts while
/// allowing the common Wizard state machine to switch families at runtime.
abstract base class TypedWizardProvider<P extends WizardParameters>
    implements WizardProvider {
  const TypedWizardProvider();

  P typedDefaultsFor(WizardTargetContext target);

  WizardParameterValidation validateTypedParameters(
    P parameters,
    WizardTargetContext target,
  );

  ReservedProjectCommand generateTyped(
    P parameters,
    WizardGenerationContext context,
  );

  @override
  P defaultsFor(WizardTargetContext target) => typedDefaultsFor(target);

  @override
  bool acceptsParameters(WizardParameters parameters) => parameters is P;

  @override
  WizardParameterValidation validateParameters(
    WizardParameters parameters,
    WizardTargetContext target,
  ) {
    if (parameters is! P) {
      return WizardParameterValidation([
        WizardValidationIssue(
          code: 'wizard.parameters.type-mismatch',
          message:
              'Parameters do not belong to provider ${descriptor.familyId.value}.',
          severity: WizardIssueSeverity.blocker,
        ),
      ]);
    }
    return validateTypedParameters(parameters, target);
  }

  @override
  ReservedProjectCommand generate(
    WizardParameters parameters,
    WizardGenerationContext context,
  ) {
    if (parameters is! P) {
      throw ArgumentError.value(
        parameters,
        'parameters',
        'Parameters do not belong to provider ${descriptor.familyId.value}.',
      );
    }
    return generateTyped(parameters, context);
  }
}

final class WizardGenerationContext {
  const WizardGenerationContext({
    required this.target,
    required this.project,
  });

  final WizardTargetContext target;
  final ProjectAggregateRoot project;
}

/// Explicit capability registry. Production UI asks this registry what is
/// available instead of hard-coding family buttons.
final class WizardProviderRegistry {
  WizardProviderRegistry(Iterable<WizardProvider> providers)
      : _providers = List.unmodifiable(providers) {
    final ids = <WizardFamilyId>{};
    for (final provider in _providers) {
      if (!ids.add(provider.descriptor.familyId)) {
        throw ArgumentError(
          'Duplicate Wizard family ${provider.descriptor.familyId.value}.',
        );
      }
    }
  }

  final List<WizardProvider> _providers;

  List<WizardProviderDescriptor> availableFor(WizardTargetContext target) =>
      List.unmodifiable(
        _providers
            .where((provider) => provider.descriptor.supports(target))
            .map((provider) => provider.descriptor),
      );

  WizardProvider? providerFor(
    WizardFamilyId familyId,
    WizardTargetContext target,
  ) {
    for (final provider in _providers) {
      if (provider.descriptor.familyId == familyId &&
          provider.descriptor.supports(target)) {
        return provider;
      }
    }
    return null;
  }
}

String _requireNonEmpty(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return normalized;
}
