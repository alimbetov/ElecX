final class EditorProjectSchemaMigrator {
  const EditorProjectSchemaMigrator._();

  static const int currentSchemaVersion = 8;

  static Map<String, Object?> migrate(
    Map<String, Object?> source, {
    DateTime? legacyTimestamp,
  }) {
    final rawVersion = source['schemaVersion'];
    if (rawVersion is! int) {
      throw const FormatException('schemaVersion must be an integer.');
    }
    if (rawVersion < 1) {
      throw FormatException('Unsupported ElecX project schema $rawVersion.');
    }
    if (rawVersion > currentSchemaVersion) {
      throw FormatException(
        'Unsupported ElecX project schema $rawVersion; latest supported is '
        '$currentSchemaVersion.',
      );
    }

    var version = rawVersion;
    var result = Map<String, Object?>.from(source);
    while (version < currentSchemaVersion) {
      result = switch (version) {
        1 => _v1ToV2(result, legacyTimestamp: legacyTimestamp),
        2 => _v2ToV3(result),
        3 => _v3ToV4(result),
        4 => _v4ToV5(result),
        5 => _v5ToV6(result),
        6 => _v6ToV7(result),
        7 => _v7ToV8(result),
        _ => throw FormatException(
            'No ElecX migration registered from schema $version.',
          ),
      };
      version = result['schemaVersion']! as int;
    }
    return result;
  }

  /// Schema v7 persisted physical penetration aggregates but predated stable
  /// SlabId ownership. Migration never guesses a slab from geometry or level
  /// order: every legacy penetration receives an explicit null slabId. New v8
  /// authoring can then persist canonical slab identity, while v7 readers reject
  /// v8 instead of silently dropping engineering-significant host identity.
  static Map<String, Object?> _v7ToV8(Map<String, Object?> source) {
    final p2Raw = source['p2'];
    if (p2Raw is! Map) {
      throw const FormatException('p2 must be an object for schema v7.');
    }
    final p2 = p2Raw.map((key, value) => MapEntry(key.toString(), value));
    final routesRaw = p2['routes'];
    if (routesRaw is! List) {
      throw const FormatException('p2.routes must be an array for schema v7.');
    }

    final routes = <Object?>[];
    for (final routeRaw in routesRaw) {
      if (routeRaw is! Map) {
        throw const FormatException('p2.routes item must be an object.');
      }
      final route =
          routeRaw.map((key, value) => MapEntry(key.toString(), value));
      final penetrationsRaw = route['penetrations'];
      if (penetrationsRaw is! List) {
        throw const FormatException(
          'route.penetrations must be an array for schema v7.',
        );
      }
      final penetrations = <Object?>[];
      for (final penetrationRaw in penetrationsRaw) {
        if (penetrationRaw is! Map) {
          throw const FormatException('route.penetration must be an object.');
        }
        final penetration = penetrationRaw.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        penetrations.add(<String, Object?>{
          ...penetration,
          'slabId': null,
        });
      }
      routes.add(<String, Object?>{
        ...route,
        'penetrations': penetrations,
      });
    }

    return <String, Object?>{
      ...source,
      'schemaVersion': 8,
      'p2': <String, Object?>{
        ...p2,
        'routes': routes,
      },
    };
  }

  /// Schema v6 has durable route-anchor identity but predates physical
  /// wall/slab penetration aggregates. Upgrade every route explicitly with an
  /// empty penetration collection. New v7 writers can then persist physical
  /// crossings, while older v6 readers reject v7 instead of silently dropping
  /// engineering-significant penetration data on a later save.
  static Map<String, Object?> _v6ToV7(Map<String, Object?> source) {
    final p2Raw = source['p2'];
    if (p2Raw is! Map) {
      throw const FormatException('p2 must be an object for schema v6.');
    }
    final p2 = p2Raw.map((key, value) => MapEntry(key.toString(), value));
    final routesRaw = p2['routes'];
    if (routesRaw is! List) {
      throw const FormatException('p2.routes must be an array for schema v6.');
    }

    final routes = <Object?>[];
    for (final routeRaw in routesRaw) {
      if (routeRaw is! Map) {
        throw const FormatException('p2.routes item must be an object.');
      }
      final route =
          routeRaw.map((key, value) => MapEntry(key.toString(), value));
      routes.add(<String, Object?>{
        ...route,
        'penetrations': const <Object?>[],
      });
    }

    return <String, Object?>{
      ...source,
      'schemaVersion': 7,
      'p2': <String, Object?>{
        ...p2,
        'routes': routes,
      },
    };
  }

  /// Schema v5 persisted route geometry but omitted durable RouteAnchorId
  /// values. Migration must never invent identities from point or segment
  /// ordinals, so every legacy segment is marked explicitly with an empty
  /// anchorIds array. P7A adoption can then assign durable identities through
  /// its explicit migration path before canonical wall-host capture.
  static Map<String, Object?> _v5ToV6(Map<String, Object?> source) {
    final p2Raw = source['p2'];
    if (p2Raw is! Map) {
      throw const FormatException('p2 must be an object for schema v5.');
    }
    final p2 = p2Raw.map((key, value) => MapEntry(key.toString(), value));
    final routesRaw = p2['routes'];
    if (routesRaw is! List) {
      throw const FormatException('p2.routes must be an array for schema v5.');
    }

    final routes = <Object?>[];
    for (final routeRaw in routesRaw) {
      if (routeRaw is! Map) {
        throw const FormatException('p2.routes item must be an object.');
      }
      final route =
          routeRaw.map((key, value) => MapEntry(key.toString(), value));
      final segmentsRaw = route['segments'];
      if (segmentsRaw is! List) {
        throw const FormatException('route.segments must be an array.');
      }
      final segments = <Object?>[];
      for (final segmentRaw in segmentsRaw) {
        if (segmentRaw is! Map) {
          throw const FormatException('route.segment must be an object.');
        }
        final segment =
            segmentRaw.map((key, value) => MapEntry(key.toString(), value));
        segments.add(<String, Object?>{
          ...segment,
          'anchorIds': const <Object?>[],
        });
      }
      routes.add(<String, Object?>{
        ...route,
        'segments': segments,
      });
    }

    return <String, Object?>{
      ...source,
      'schemaVersion': 6,
      'p2': <String, Object?>{
        ...p2,
        'routes': routes,
      },
    };
  }

  static Map<String, Object?> _v4ToV5(Map<String, Object?> source) {
    final workspaceRaw = source['workspace'];
    if (workspaceRaw is! Map) {
      throw const FormatException('workspace must be an object for schema v4.');
    }
    final workspace =
        workspaceRaw.map((key, value) => MapEntry(key.toString(), value));
    final resumeRaw = workspace['resume'];
    if (resumeRaw is! Map) {
      throw const FormatException(
        'workspace.resume must be an object for schema v4.',
      );
    }
    final resume = resumeRaw.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    return <String, Object?>{
      ...source,
      'schemaVersion': 5,
      'workspace': <String, Object?>{
        ...workspace,
        'resume': <String, Object?>{
          ...resume,
          'canonicalSurface': null,
        },
      },
    };
  }

  static Map<String, Object?> _v3ToV4(Map<String, Object?> source) {
    final p2Raw = source['p2'];
    if (p2Raw is! Map) {
      throw const FormatException('p2 must be an object for schema v3.');
    }
    final p2 = p2Raw.map((key, value) => MapEntry(key.toString(), value));
    return <String, Object?>{
      ...source,
      'schemaVersion': 4,
      'p2': <String, Object?>{
        ...p2,
        'sizingEvidenceByRoute': const <String, Object?>{},
      },
    };
  }

  static Map<String, Object?> _v2ToV3(Map<String, Object?> source) {
    final p2Raw = source['p2'];
    if (p2Raw is! Map) {
      throw const FormatException('p2 must be an object for schema v2.');
    }
    final p2 = p2Raw.map((key, value) => MapEntry(key.toString(), value));
    return <String, Object?>{
      ...source,
      'schemaVersion': 3,
      'p2': <String, Object?>{...p2, 'circuitBundles': const <Object?>[]},
    };
  }

  static Map<String, Object?> _v1ToV2(
    Map<String, Object?> source, {
    DateTime? legacyTimestamp,
  }) {
    final projectId = source['projectId'];
    final projectName = source['projectName'];
    if (projectId is! String || projectId.trim().isEmpty) {
      throw const FormatException('Legacy projectId must be non-empty.');
    }
    if (projectName is! String || projectName.trim().isEmpty) {
      throw const FormatException('Legacy projectName must be non-empty.');
    }
    final timestamp =
        (legacyTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0))
            .toUtc()
            .toIso8601String();
    return <String, Object?>{
      ...source,
      'schemaVersion': 2,
      'metadata': <String, Object?>{
        'projectId': projectId,
        'projectName': projectName,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      },
    };
  }
}
