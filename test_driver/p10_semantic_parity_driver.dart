import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(responseDataCallback: (data) async {
      final parity = data?['p10SemanticParity'];
      if (parity == null) {
        throw StateError('Missing native P10 semantic artifact');
      }
      final file = File('build/p10-final-acceptance/p10-semantic-parity.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(parity));
    });
