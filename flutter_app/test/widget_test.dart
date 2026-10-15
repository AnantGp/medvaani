import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/report_workspace.dart';
import 'report_fixture.dart';

const languages = [
  {'name': 'English', 'native': 'English', 'code': 'en'},
  {'name': 'Hindi', 'native': 'हिन्दी', 'code': 'hi'},
];

ReportWorkspace workspace(
        {int index = 0,
        Map<String, dynamic>? report,
        bool loading = false,
        String language = 'English',
        VoidCallback? retry,
        VoidCallback? photo,
        VoidCallback? camera,
        void Function(String, [String?])? narrate,
        String? audioError,
        Widget? explorer,
        ValueChanged<int>? navigate}) =>
    ReportWorkspace(
      index: index,
      onNavigate: navigate ?? (_) {},
      language: language,
      languages: languages,
      onLanguage: (_) {},
      onUpload: () {},
      onPhoto: photo ?? () {},
      onCamera: camera ?? () {},
      onDownload: () {},
      onRetryTranslation: retry ?? () {},
      onSpeak: (String text, String language) => narrate?.call(text, language),
      onPause: () {},
      onResume: () {},
      onStop: () {},
      onSpeechEnabled: (_) {},
      report: report == null ? null : displayReport(report),
      sourceExplorer: explorer,
      audioError: audioError,
      loading: loading,
      fileName: 'sample-report.pdf',
    );

void main() {
  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: medivaaniiTheme(), home: child));
  }

  testWidgets(
      'legacy cache hides interpretation, audio and export but retains source',
      (tester) async {
    await show(
        tester,
        workspace(
            index: 1,
            report: {
              'extraction_version': 3,
              'review': {'confirmed': true},
              'simple_explanation': 'Old confident answer'
            },
            explorer: const Text('Original source available')));
    expect(find.text('Old confident answer'), findsNothing);
    expect(find.text('Download summary PDF'), findsNothing);
    expect(find.byTooltip('Play narration'), findsNothing);
    expect(find.text('Original source available'), findsOneWidget);
    expect(find.text('Read original again'), findsOneWidget);
  });

  testWidgets(
      'mobile navigation opens the explanation empty state without overflow',
      (tester) async {
    var index = 0;
    await show(
        tester,
        StatefulBuilder(
            builder: (context, setState) => workspace(
                index: index,
                navigate: (next) => setState(() => index = next))));
    await tester.tap(find.text('Explanation'));
    await tester.pumpAndSettle();
    expect(find.text('Your report, explained.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report opens in overview and explorer is available on demand',
      (tester) async {
    await show(
        tester,
        workspace(
            index: 1,
            report: {
              'simple_explanation': 'A source-grounded explanation.',
              'parsed_data': {
                'lab_values': [
                  {
                    'test_name': 'Creatinine',
                    'value': '1.8',
                    'unit': 'mg/dL',
                    'status': 'high'
                  }
                ]
              },
            },
            explorer: const SizedBox(
                height: 700, child: Text('Interactive source fixture'))));
    expect(find.text('Interactive source fixture'), findsNothing);
    expect(find.text('A source-grounded explanation.'), findsOneWidget);
    await tester.ensureVisible(find.text('Explorer'));
    await tester.tap(find.text('Explorer'));
    await tester.pumpAndSettle();
    expect(find.text('Interactive source fixture'), findsOneWidget);
    await tester.ensureVisible(find.text('Lab values (1)'));
    await tester.ensureVisible(find.text('Lab values (1)'));
    await tester.tap(find.text('Lab values (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Creatinine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'processing feedback stays visible before a report result arrives',
      (tester) async {
    await show(tester, workspace(loading: true));
    await tester.pump();
    expect(find.text('Reading your report'), findsOneWidget);
    expect(find.text('sample-report.pdf'), findsOneWidget);
    expect(find.text('Choose PDF'), findsNothing);
    expect(find.text('Take a photo'), findsNothing);
    expect(find.text('Choose photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile upload offers camera, saved photo and PDF together',
      (tester) async {
    await show(tester, workspace());
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('Choose PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop upload also exposes the photo capture option',
      (tester) async {
    await show(tester, workspace());
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pump();
    expect(find.text('Take a photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'all explanation paragraphs and JSON-string lab values are accessible',
      (tester) async {
    final paragraphs = List.generate(9, (i) => 'Finding ${i + 1}.');
    await show(
        tester,
        workspace(index: 1, report: {
          'simple_explanation': paragraphs.join('\n\n'),
          'parsed_data':
              '{"lab_values":[{"test_name":"Platelets","value":240,"unit":"10^3/µL","status":"normal"}]}',
        }));
    expect(find.text('Finding 9.'), findsOneWidget);
    await tester.ensureVisible(find.text('Lab values (1)'));
    await tester.tap(find.text('Lab values (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Platelets'), findsOneWidget);
    expect(find.text('240 10^3/µL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing translation keeps English readable and provides retry',
      (tester) async {
    var retries = 0;
    await show(
        tester,
        workspace(
            index: 1,
            language: 'Hindi',
            retry: () => retries++,
            report: {'simple_explanation': 'English source explanation.'}));
    expect(find.text('English source explanation.'), findsOneWidget);
    await tester.ensureVisible(find.text('Retry translation'));
    await tester.tap(find.text('Retry translation'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English fallback requests an English narration voice',
      (tester) async {
    String? voiceLanguage;
    String? spokenText;
    await show(
        tester,
        workspace(
            index: 1,
            language: 'Hindi',
            narrate: (text, [language]) {
              spokenText = text;
              voiceLanguage = language;
            },
            report: {'simple_explanation': 'English source explanation.'}));
    await tester.ensureVisible(find.byTooltip('Play narration'));
    await tester.tap(find.byTooltip('Play narration'));
    expect(spokenText, 'English source explanation.');
    expect(voiceLanguage, 'English');
  });

  testWidgets('translated explanation requests its own narration language',
      (tester) async {
    String? voiceLanguage;
    await show(
        tester,
        workspace(
            index: 1,
            language: 'Hindi',
            narrate: (_, [language]) => voiceLanguage = language,
            report: {
              'simple_explanation': 'English source.',
              'translated_explanation': 'यह हिन्दी में है।'
            }));
    await tester.ensureVisible(find.byTooltip('Play narration'));
    await tester.tap(find.byTooltip('Play narration'));
    expect(voiceLanguage, 'Hindi');
  });

  testWidgets('narration failure remains visible with a usable play control',
      (tester) async {
    await show(
        tester,
        workspace(
            index: 1,
            audioError: 'Narration unavailable. Try Play again.',
            report: {'simple_explanation': 'English source.'}));
    expect(find.text('Narration unavailable. Try Play again.'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find
                .ancestor(
                    of: find.byTooltip('Play narration'),
                    matching: find.byType(IconButton))
                .first)
            .onPressed,
        isNotNull);
  });

  testWidgets('lab status labels distinguish source flags from comparisons',
      (tester) async {
    await show(
        tester,
        workspace(index: 1, report: {
          'parsed_data': {
            'lab_values': [
              {
                'test_name': 'Hemoglobin',
                'value': '11.2',
                'unit': 'g/dL',
                'status': 'low',
                'status_source': 'report',
                'reference_range': ''
              },
              {
                'test_name': 'WBC',
                'value': '6800',
                'unit': '/uL',
                'status': 'normal',
                'status_source': 'reference_range',
                'reference_range': ''
              },
            ]
          }
        }));
    await tester.ensureVisible(find.text('Lab values (2)'));
    await tester.tap(find.text('Lab values (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Report flag: low'), findsOneWidget);
    expect(find.text('Compared with report range: normal'), findsOneWidget);
    expect(find.text('Reference: Not provided'), findsNWidgets(2));
  });
}
