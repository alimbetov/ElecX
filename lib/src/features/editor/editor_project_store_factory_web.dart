import 'dart:html' as html;

import 'browser_project_store.dart';
import 'editor_project_document.dart';
import 'editor_project_recovery.dart';

final class _HtmlLocalStorageBackend implements BrowserKeyValueStore {
  const _HtmlLocalStorageBackend();

  html.Storage get _storage => html.window.localStorage;

  @override
  Iterable<String> get keys => List<String>.unmodifiable(_storage.keys);

  @override
  String? read(String key) => _storage[key];

  @override
  void remove(String key) => _storage.remove(key);

  @override
  void write(String key, String value) {
    _storage[key] = value;
  }
}

Future<EditorProjectStore> openDefaultEditorProjectStore() async =>
    BrowserEditorProjectStore(const _HtmlLocalStorageBackend());

Future<EditorProjectRecoveryStore> openDefaultEditorProjectRecoveryStore() async =>
    BrowserEditorProjectRecoveryStore(const _HtmlLocalStorageBackend());
