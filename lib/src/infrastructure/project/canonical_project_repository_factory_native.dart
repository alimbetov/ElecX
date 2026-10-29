import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../application/project/project_repository.dart';
import '../../serialization/project/common_core_aware_canonical_project_document_codec.dart';
import 'json_project_repository.dart';

Future<ProjectRepository> openDefaultCanonicalProjectRepository() async {
  final documents = await getApplicationDocumentsDirectory();
  return JsonProjectRepository(
    rootDirectory: Directory(
      path.join(documents.path, 'ElecX', 'canonical-projects'),
    ),
    codec: const CommonCoreAwareCanonicalProjectDocumentCodec(),
  );
}
