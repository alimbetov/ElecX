import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS resolves application documents directory', (tester) async {
    expect(Platform.isMacOS, isTrue);

    final directory = await getApplicationDocumentsDirectory();

    expect(directory.path, isNotEmpty);
    expect(directory.isAbsolute, isTrue);
  });
}
