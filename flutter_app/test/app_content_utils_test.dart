import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/app_content_utils.dart';

void main() {
  test('export source fields retain their own labelled lines', () {
    final blocks = reportDocument(
        '• Glucose: 95 mg/dL\nOriginal source: Page 2\nOriginally printed value: 145\nReference range: 70-100');
    expect(
        blocks
            .where((b) => b.kind == ReportBlockKind.field)
            .map((b) => b.label),
        containsAll([
          'Original source',
          'Originally printed value',
          'Reference range'
        ]));
  });
  test('preserves paragraph boundaries when normalizing report text', () {
    expect(normalizeReportText(' First paragraph.\r\n\r\n Second paragraph. '),
        'First paragraph.\n\nSecond paragraph.');
  });

  test('keeps every returned paragraph rather than limiting the report', () {
    final paragraphs = List.generate(9, (i) => 'Finding ${i + 1}.');
    expect(splitIntoReadableParagraphs(paragraphs.join('\n\n')), paragraphs);
  });

  test('removes decorative emoji while preserving measurements and scripts',
      () {
    expect(
        professionalReportText(
            '⚠️ Glucose ≥ 145 mg/dL\n1. 📞 Discuss µL, ± and ↑ with your doctor\nहिन्दी தமிழ்'),
        'Glucose ≥ 145 mg/dL\n1.  Discuss µL, ± and ↑ with your doctor\nहिन्दी தமிழ்');
  });

  test('formats a legacy explanation without losing findings or numbered steps',
      () {
    final blocks = reportDocument('YOUR MEDICAL REPORT EXPLANATION\n=====\n'
        '⚠️ ATTENTION NEEDED: 2 results outside the range\n\n'
        'Abnormal Results Explained:\n• Glucose: 145mg/dL (high)\n'
        'What this means: Discuss the result.\n\nWHAT SHOULD YOU DO NEXT?\n---\n'
        '1. 📞 Contact your doctor\n2. 📝 Bring your report\n\nFinal paragraph.');
    expect(blocks.map((b) => b.kind), [
      ReportBlockKind.notice,
      ReportBlockKind.heading,
      ReportBlockKind.bullet,
      ReportBlockKind.paragraph,
      ReportBlockKind.heading,
      ReportBlockKind.numbered,
      ReportBlockKind.numbered,
      ReportBlockKind.paragraph
    ]);
    expect(blocks[2].text, 'Glucose: 145mg/dL (high)');
    expect(blocks[6].number, '2');
    expect(blocks.last.text, 'Final paragraph.');
  });
}
