// Explicit local export verification; never part of the default test suite.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/report_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const input = String.fromEnvironment('REPORT_JSON',
      defaultValue: 'test/fixtures/anonymous-report.json');
  const output = String.fromEnvironment('EXPORT_PATH');
  const language =
      String.fromEnvironment('EXPORT_LANGUAGE', defaultValue: 'English');
  test('build the exact app PDF from a source-backed response', () async {
    final data =
        jsonDecode(await File(input).readAsString()) as Map<String, dynamic>;
    final bytes = await buildReportPdf(data, language);
    expect(bytes.length, greaterThan(1000));
    final target = output.isEmpty
        ? '${Directory.systemTemp.path}/Medivaanii-export-check.pdf'
        : output;
    await File(target).writeAsBytes(bytes);
  });
}
