import 'package:flutter/material.dart';

import '../editor/spatial_editor_screen.dart';

class ProjectHubScreen extends StatelessWidget {
  const ProjectHubScreen({super.key});

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SpatialEditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Проекты'),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Новый проект'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Продолжить', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.apartment),
              title: const Text('Демо — БЦ Alatau'),
              subtitle: const Text('Этаж 1 · пространственный редактор'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openEditor(context),
            ),
          ),
          const SizedBox(height: 28),
          Text('Мои проекты', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.folder_outlined),
              title: Text('Пока пусто'),
              subtitle: Text('Создайте первый объект и его пространственную модель.'),
            ),
          ),
        ],
      ),
    );
  }
}
