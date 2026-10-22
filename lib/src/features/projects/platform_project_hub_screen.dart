import 'package:flutter/material.dart';

import '../editor/editor_project_document.dart';
import '../editor/editor_project_recovery.dart';
import '../editor/editor_project_store_factory.dart';
import 'project_hub_screen.dart';

class PlatformProjectHubScreen extends StatefulWidget {
  const PlatformProjectHubScreen({super.key});

  @override
  State<PlatformProjectHubScreen> createState() =>
      _PlatformProjectHubScreenState();
}

class _PlatformProjectHubScreenState extends State<PlatformProjectHubScreen> {
  late final Future<_PlatformProjectStores> _storesFuture = _openStores();

  Future<_PlatformProjectStores> _openStores() async => _PlatformProjectStores(
    projectStore: await openDefaultEditorProjectStore(),
    recoveryStore: await openDefaultEditorProjectRecoveryStore(),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<_PlatformProjectStores>(
    future: _storesFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось инициализировать локальное хранилище ElecX.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
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
      );
    },
  );
}

final class _PlatformProjectStores {
  const _PlatformProjectStores({
    required this.projectStore,
    required this.recoveryStore,
  });

  final EditorProjectStore projectStore;
  final EditorProjectRecoveryStore recoveryStore;
}
