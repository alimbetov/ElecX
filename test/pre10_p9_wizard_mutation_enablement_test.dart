import 'package:elecx/src/features/editor/canonical_editor_production_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CanonicalEditorProductionRuntimeConfig config({
    bool canonicalOwnership = false,
    bool authoringOwnership = false,
  }) =>
      CanonicalEditorProductionRuntimeConfig(
        resolveRuntime: (_, __) => null,
        onCanonicalMutationCommitted: canonicalOwnership
            ? (_, __) => const CanonicalAuthoringOwnershipReceipt.accepted()
            : null,
        onAuthoringCommitted: authoringOwnership
            ? (_, __) => const CanonicalAuthoringOwnershipReceipt.accepted()
            : null,
      );

  test('PRE10-CQ27 wizard mutation capability requires both ownership hooks', () {
    final disabled = config();
    expect(disabled.authoringEnabled, isFalse);
    expect(disabled.wizardMutationEnabled, isFalse);

    final canonicalOnly = config(canonicalOwnership: true);
    expect(canonicalOnly.authoringEnabled, isFalse);
    expect(canonicalOnly.wizardMutationEnabled, isFalse);

    final authoringOnly = config(authoringOwnership: true);
    expect(authoringOnly.authoringEnabled, isFalse);
    expect(authoringOnly.wizardMutationEnabled, isFalse);

    final enabled = config(
      canonicalOwnership: true,
      authoringOwnership: true,
    );
    expect(enabled.authoringEnabled, isTrue);
    expect(enabled.wizardMutationEnabled, isTrue);
  });
}
