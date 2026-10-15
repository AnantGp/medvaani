import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/report_review_widgets.dart';
import 'package:medical_cdss/report_workspace.dart';
import 'report_fixture.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: medivaaniiTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(20), child: child))));
  }

  testWidgets(
      'review preserves exact source while submitting a corrected value',
      (tester) async {
    List<Map<String, dynamic>>? corrected;
    await show(
        tester,
        ReportReviewPanel(
            report: displayReport({
              'parsed_data': {
                'lab_values': [
                  {
                    'test_name': 'Glucose',
                    'value': '145',
                    'unit': 'mg/dL',
                    'reference_range': '70-100',
                    'status': 'high'
                  }
                ]
              },
              'extracted_text': 'Glucose: 145 mg/dL 70-100',
              'source_evidence': [
                {
                  'test_name': 'Glucose',
                  'source_quote': 'Glucose: 145 mg/dL 70-100'
                }
              ]
            }),
            onConfirm: (rows) => corrected = rows));
    expect(find.byType(TextFormField), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('edit-result-0')));
    await tester.tap(find.byKey(const ValueKey('edit-result-0')));
    await tester.pumpAndSettle();
    final value = find.widgetWithText(TextFormField, 'Value');
    await tester.ensureVisible(value);
    await tester.enterText(value, '95');
    await tester.tap(find.text('Save correction'));
    await tester.pumpAndSettle();
    final confirm = find.text('Confirm & continue');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    expect(corrected![0]['value'], '95');
    expect(corrected![0]['unit'], 'mg/dL');
    expect(corrected![0]['reference_range'], '70-100');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'review cancellation preserves result and uncertainty filter remains usable on mobile',
      (tester) async {
    await show(
        tester,
        ReportReviewPanel(
            report: displayReport({
              'parsed_data': {
                'lab_values': [
                  {
                    'test_name': 'Creatinine',
                    'value': '0.9',
                    'unit': 'mg/dL',
                    'reference_range': '0.6-1.2',
                    'status': 'normal'
                  },
                  {
                    'test_name': 'Glucose',
                    'value': '95',
                    'unit': 'mg/dL',
                    'reference_range': '',
                    'status': 'unknown',
                    'acceptance_state': 'needs_review'
                  }
                ]
              },
              'source_evidence': [
                {'source_quote': 'Creatinine: 0.9 mg/dL'},
                {'source_quote': 'Glucose: 95 mg/dL'}
              ]
            }),
            onConfirm: (_) {}));
    await tester.ensureVisible(find.byKey(const ValueKey('edit-result-0')));
    await tester.tap(find.byKey(const ValueKey('edit-result-0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Value'), '9');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('0.9'), findsOneWidget);
    final filter = find.text('Needs check · 1');
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-result-0')), findsNothing);
    expect(find.byKey(const ValueKey('edit-result-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report questions show their source and review action',
      (tester) async {
    var reviews = 0;
    await show(
        tester,
        ReportQuestions(
            onReview: () => reviews++,
            onAsk: (_) async => {
                  'answer': 'Glucose cannot be classified from this report.',
                  'answer_language': 'English',
                  'sources': [
                    {
                      'test_name': 'Glucose',
                      'source_quote': 'Glucose: 145 mg/dL'
                    }
                  ],
                }));
    await tester.tap(find.text('Which results are flagged?'));
    await tester.pumpAndSettle();
    expect(find.text('Glucose cannot be classified from this report.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Source: Glucose'));
    await tester.tap(find.text('Source: Glucose'));
    await tester.pumpAndSettle();
    expect(find.text('Glucose: 145 mg/dL'), findsOneWidget);
    await tester
        .ensureVisible(find.text('Review original and extracted results'));
    await tester.tap(find.text('Review original and extracted results'));
    expect(reviews, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('question failures show retryable feedback', (tester) async {
    await show(
        tester,
        ReportQuestions(
            onReview: () {}, onAsk: (_) async => throw Exception('offline')));
    await tester.tap(find.text('Summarise my report'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'The answer is unavailable. Check your connection and try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
