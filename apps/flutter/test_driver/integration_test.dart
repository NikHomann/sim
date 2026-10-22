// Host side of the L5 web flows (docs/port/04-test-plan.md §1): connects to the
// app through flutter_driver, waits for the integration test result and writes
// the JSON report the test assembled (`binding.reportData`) to
// `E2E_REPORT_PATH` (default `build/e2e/<suite>.json`), also when the test
// fails, so CI always has the artifact.
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    timeout: const Duration(minutes: 10),
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final report = data ?? <String, dynamic>{};
      final suite = report['suite'] as String? ?? 'e2e';
      final path =
          Platform.environment['E2E_REPORT_PATH'] ?? 'build/e2e/$suite.json';
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );
      stdout.writeln('e2e report: ${file.absolute.path}');
    },
  );
}
