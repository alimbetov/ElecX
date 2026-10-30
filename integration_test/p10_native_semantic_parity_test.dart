import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../qualification_test/support/p10_qualification_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('P10-Q19 native composition semantic artifact', (tester) async {
    final data = p10SemanticParity();
    expect(data['cases'], hasLength(3));
    binding.reportData = {'p10SemanticParity': data};
  });
}
