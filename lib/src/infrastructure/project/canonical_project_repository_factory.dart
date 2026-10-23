import '../../application/project/project_repository.dart';
import 'canonical_project_repository_factory_native.dart' as platform;

Future<ProjectRepository> openDefaultCanonicalProjectRepository() =>
    platform.openDefaultCanonicalProjectRepository();
