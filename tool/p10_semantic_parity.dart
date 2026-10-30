import 'dart:convert';
import 'dart:io';

import '../qualification_test/support/p10_qualification_fixture.dart';

void main(List<String> args) {
  final data = p10SemanticParity();
  final file = File(args.isEmpty
      ? 'build/p10-final-acceptance/p10-semantic-parity.json'
      : args.single);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(data));
  stdout.writeln(
      'P10 semantic parity: ${(data['cases'] as List).length} families');
}
