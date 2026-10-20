import 'package:web/web.dart' as web;

import 'browser_project_store.dart';
import 'editor_project_document.dart';
import 'editor_project_recovery.dart';

final class _HtmlLocalStorageBackend implements BrowserKeyValueStore {
  const _HtmlLocalStorageBackend();

  web.Storage get _storage => web.window.localStorage;

  @override
  Iterable<String> get keys sync* {
    final storage = _storage;
    for (var index = 0; index < storage.length; index++) {
      final key = storage.key(index);
      if (key != null) yield key;
    }
  }

  @override
  String? read(String key) => _storage.getItem(key);

  @override
  void remove(String key) => _storage.removeItem(key);

  @override
  void write(String key, String value) {
    _storage.setItem(key, value);
  }
}

Future<EditorProjectStore> openDefaultEditorProjectStore() async =>
    BrowserEditorProjectStore(const _HtmlLocalStorageBackend());

Future<EditorProjectRecoveryStore>
    openDefaultEditorProjectRecoveryStore() async =>
        BrowserEditorProjectRecoveryStore(const _HtmlLocalStorageBackend());
