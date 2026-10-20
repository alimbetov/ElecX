from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 match, got {count}')
    p.write_text(text.replace(old, new, 1))

p = 'lib/src/features/editor/editor_project_document.dart'
replace_once(
    p,
    "import 'editor_p2_session.dart';\n",
    "import 'editor_p2_session.dart';\nimport 'project_persistence_metadata.dart';\nimport 'project_schema_migrator.dart';\n",
    'document imports',
)
replace_once(
    p,
    '''  const EditorProjectDocument({\n    required this.schemaVersion,\n    required this.projectId,\n    required this.projectName,\n''',
    '''  const EditorProjectDocument({\n    required this.schemaVersion,\n    required this.metadata,\n''',
    'document constructor metadata',
)
replace_once(
    p,
    '''  static const currentSchemaVersion = 1;\n\n  final int schemaVersion;\n  final String projectId;\n  final String projectName;\n''',
    '''  static const currentSchemaVersion =\n      EditorProjectSchemaMigrator.currentSchemaVersion;\n\n  final int schemaVersion;\n  final EditorProjectMetadata metadata;\n  String get projectId => metadata.projectId;\n  String get projectName => metadata.projectName;\n  DateTime get createdAt => metadata.createdAt;\n  DateTime get updatedAt => metadata.updatedAt;\n''',
    'document metadata fields',
)
replace_once(
    p,
    '''  factory EditorProjectDocument.capture(EditorBuildingWorkspace workspace) {\n    final editor = workspace.editor;\n''',
    '''  factory EditorProjectDocument.capture(\n    EditorBuildingWorkspace workspace, {\n    EditorProjectMetadata? metadata,\n    DateTime? now,\n  }) {\n    final editor = workspace.editor;\n''',
    'capture signature',
)
replace_once(
    p,
    '''    workspace.synchronizeActiveEditorState();\n    return EditorProjectDocument(\n      schemaVersion: currentSchemaVersion,\n      projectId: workspace.site.site.id,\n      projectName: workspace.site.site.name,\n''',
    '''    workspace.synchronizeActiveEditorState();\n    final projectMetadata = metadata ??\n        EditorProjectMetadata.create(\n          projectName: workspace.site.site.name,\n          projectId: workspace.site.site.id,\n          now: now,\n        );\n    return EditorProjectDocument(\n      schemaVersion: currentSchemaVersion,\n      metadata: projectMetadata,\n''',
    'capture metadata',
)
replace_once(
    p,
    '''        'schemaVersion': schemaVersion,\n        'projectId': projectId,\n        'projectName': projectName,\n        'building': _buildingToJson(building),\n''',
    '''        'schemaVersion': schemaVersion,\n        'metadata': {\n          'projectId': metadata.projectId,\n          'projectName': metadata.projectName,\n          'createdAt': metadata.createdAt.toUtc().toIso8601String(),\n          'updatedAt': metadata.updatedAt.toUtc().toIso8601String(),\n        },\n        'building': _buildingToJson(building),\n''',
    'document metadata json',
)
replace_once(
    p,
    '''  factory EditorProjectDocument.fromJson(Map<String, Object?> json) {\n    final version = _int(json['schemaVersion'], 'schemaVersion');\n    if (version != currentSchemaVersion) {\n      throw FormatException(\n        'Unsupported ElecX project schema $version; expected '\n        '$currentSchemaVersion.',\n      );\n    }\n    final workspace = _map(json['workspace'], 'workspace');\n''',
    '''  factory EditorProjectDocument.fromJson(\n    Map<String, Object?> json, {\n    DateTime? legacyTimestamp,\n  }) {\n    final migrated = EditorProjectSchemaMigrator.migrate(\n      json,\n      legacyTimestamp: legacyTimestamp,\n    );\n    final version = _int(migrated['schemaVersion'], 'schemaVersion');\n    final metadataJson = _map(migrated['metadata'], 'metadata');\n    final workspace = _map(migrated['workspace'], 'workspace');\n''',
    'document migration entry',
)
replace_once(
    p,
    '''    return EditorProjectDocument(\n      schemaVersion: version,\n      projectId: _string(json['projectId'], 'projectId'),\n      projectName: _string(json['projectName'], 'projectName'),\n      building: _buildingFromJson(_map(json['building'], 'building')),\n      site: _siteFromJson(_map(json['site'], 'site')),\n''',
    '''    final createdAt = DateTime.parse(\n      _string(metadataJson['createdAt'], 'metadata.createdAt'),\n    ).toUtc();\n    final updatedAt = DateTime.parse(\n      _string(metadataJson['updatedAt'], 'metadata.updatedAt'),\n    ).toUtc();\n    if (updatedAt.isBefore(createdAt)) {\n      throw const FormatException('metadata.updatedAt precedes createdAt.');\n    }\n    return EditorProjectDocument(\n      schemaVersion: version,\n      metadata: EditorProjectMetadata(\n        projectId: _string(metadataJson['projectId'], 'metadata.projectId'),\n        projectName: _string(metadataJson['projectName'], 'metadata.projectName'),\n        createdAt: createdAt,\n        updatedAt: updatedAt,\n      ),\n      building: _buildingFromJson(_map(migrated['building'], 'building')),\n      site: _siteFromJson(_map(migrated['site'], 'site')),\n''',
    'document metadata decode',
)
text = Path(p).read_text()
text = text.replace("_map(json['p2'], 'p2')", "_map(migrated['p2'], 'p2')", 1)
Path(p).write_text(text)

# Pass file timestamps into legacy migration and sort project hub by recency.
replace_once(
    p,
    '''    final document = EditorProjectDocument.fromJson(\n      raw.map((key, value) => MapEntry(key.toString(), value)),\n    );\n''',
    '''    final stat = await source.stat();\n    final document = EditorProjectDocument.fromJson(\n      raw.map((key, value) => MapEntry(key.toString(), value)),\n      legacyTimestamp: stat.modified.toUtc(),\n    );\n''',
    'load legacy timestamp',
)
replace_once(
    p,
    '''      result.add(\n        EditorProjectDocument.fromJson(\n          raw.map((key, value) => MapEntry(key.toString(), value)),\n        ),\n      );\n    }\n    result.sort((a, b) => a.projectName.compareTo(b.projectName));\n''',
    '''      final stat = await entity.stat();\n      result.add(\n        EditorProjectDocument.fromJson(\n          raw.map((key, value) => MapEntry(key.toString(), value)),\n          legacyTimestamp: stat.modified.toUtc(),\n        ),\n      );\n    }\n    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));\n''',
    'list legacy timestamp and recency',
)

# Add schema/identity regressions.
p = 'test/editor_project_persistence_test.dart'
text = Path(p).read_text()
text = text.replace(
    "import 'package:elecx/src/features/editor/editor_project_document.dart';\n",
    "import 'package:elecx/src/features/editor/editor_project_document.dart';\nimport 'package:elecx/src/features/editor/project_persistence_metadata.dart';\n",
    1,
)
anchor = "  test('unsupported schema is rejected explicitly', () {"
if text.count(anchor) != 1:
    raise RuntimeError('persistence test anchor mismatch')
addition = r'''  test('project identity is independent from physical site identity', () {
    final now = DateTime.utc(2026, 10, 20, 8);
    final first = EditorProjectMetadata.create(projectName: 'Проект A', now: now);
    final second = EditorProjectMetadata.create(projectName: 'Проект B', now: now);

    expect(first.projectId, isNot(second.projectId));
    expect(first.projectId, isNot('site-1'));
    expect(first.createdAt, now);
    expect(first.updatedAt, now);
  });

  test('schema v1 migrates to v2 metadata without losing project identity', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final v2 = EditorProjectDocument.capture(workspace).toJson();
    final metadata = Map<String, Object?>.from(v2['metadata']! as Map);
    final legacy = Map<String, Object?>.from(v2)
      ..['schemaVersion'] = 1
      ..['projectId'] = metadata['projectId']
      ..['projectName'] = metadata['projectName']
      ..remove('metadata');
    final migratedAt = DateTime.utc(2026, 10, 20, 7, 30);

    final decoded = EditorProjectDocument.fromJson(
      legacy,
      legacyTimestamp: migratedAt,
    );

    expect(decoded.schemaVersion, 2);
    expect(decoded.projectId, metadata['projectId']);
    expect(decoded.projectName, metadata['projectName']);
    expect(decoded.createdAt, migratedAt);
    expect(decoded.updatedAt, migratedAt);
  });

'''
Path(p).write_text(text.replace(anchor, addition + anchor, 1))
