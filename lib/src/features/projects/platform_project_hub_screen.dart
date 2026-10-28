import 'package:flutter/material.dart';

import '../../application/project/project_repository.dart';
import '../../infrastructure/project/canonical_project_repository_factory.dart';
import '../app_shell_localizations.dart';
import '../editor/editor_project_document.dart';
import '../editor/editor_project_recovery.dart';
import '../editor/editor_project_store_factory.dart';
import 'project_hub_screen.dart';

typedef EditorProjectStoreOpener = Future<EditorProjectStore> Function();
typedef EditorProjectRecoveryStoreOpener = Future<EditorProjectRecoveryStore>
    Function();
typedef CanonicalProjectRepositoryOpener = Future<ProjectRepository> Function();

class PlatformProjectHubScreen extends StatefulWidget {
  const PlatformProjectHubScreen({
    this.projectStoreOpener = openDefaultEditorProjectStore,
    this.recoveryStoreOpener = openDefaultEditorProjectRecoveryStore,
    this.canonicalRepositoryOpener = openDefaultCanonicalProjectRepository,
    super.key,
  });

  final EditorProjectStoreOpener projectStoreOpener;
  final EditorProjectRecoveryStoreOpener recoveryStoreOpener;
  final CanonicalProjectRepositoryOpener canonicalRepositoryOpener;

  @override
  State<PlatformProjectHubScreen> createState() =>
      _PlatformProjectHubScreenState();
}

class _PlatformProjectHubScreenState extends State<PlatformProjectHubScreen> {
  late Future<_PlatformProjectStores> _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = _openStores();
  }

  Future<_PlatformProjectStores> _openStores() async => _PlatformProjectStores(
        projectStore: await widget.projectStoreOpener(),
        recoveryStore: await widget.recoveryStoreOpener(),
        canonicalRepository: await widget.canonicalRepositoryOpener(),
      );

  void _retry() => setState(() => _storesFuture = _openStores());

  @override
  Widget build(BuildContext context) => FutureBuilder<_PlatformProjectStores>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            final l10n = AppShellLocalizations.of(context);
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.localStorageInitializationFailed,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const ValueKey('platform-storage-retry'),
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          final stores = snapshot.requireData;
          return ProjectHubScreen(
            projectStore: stores.projectStore,
            recoveryStore: stores.recoveryStore,
            canonicalProjectRepository: stores.canonicalRepository,
          );
        },
      );
}

final class _PlatformProjectStores {
  const _PlatformProjectStores({
    required this.projectStore,
    required this.recoveryStore,
    required this.canonicalRepository,
  });

  final EditorProjectStore projectStore;
  final EditorProjectRecoveryStore recoveryStore;
  final ProjectRepository canonicalRepository;
}
