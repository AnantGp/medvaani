import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/meds/med_engine.dart';
import 'package:medical_cdss/meds/meds_page.dart';
import 'package:medical_cdss/report_workspace.dart';

const _languages = [
  {'code': 'en', 'name': 'English', 'native': 'English'},
  {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
  {'code': 'es', 'name': 'Spanish', 'native': 'Español'},
  {'code': 'zh', 'name': 'Mandarin', 'native': '中文'},
];

Widget _meds(DateTime now, {double textScale = 1}) =>
    MaterialApp(
        theme: medivaaniiTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: Scaffold(
            body: MedsPage(
                language: 'English',
                now: () => now,
                load: () => sampleMedState(now).encode())));

Widget _upload({double textScale = 1}) => MaterialApp(
    theme: medivaaniiTheme(),
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!),
    home: ReportWorkspace(
      index: 0,
      language: 'English',
      languages: _languages,
      onLanguage: (_) {},
      onNavigate: (_) {},
      onUpload: () {},
      onPhoto: () {},
      onCamera: () {},
      onDownload: () {},
      onRetryTranslation: () {},
      onSpeak: (_, __) {},
      onPause: () {},
      onResume: () {},
      onStop: () {},
      onSpeechEnabled: (_) {},
    ));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final now = DateTime(2026, 11, 3, 8, 50);

  group('medicines page', () {
    testWidgets('controls are labelled and reachable on a phone',
        (tester) async {
      final handle = tester.ensureSemantics();
      _phone(tester);
      await tester.pumpWidget(_meds(now));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('check-in buttons name the medicine they act on',
        (tester) async {
      final handle = tester.ensureSemantics();
      _phone(tester);
      await tester.pumpWidget(_meds(now));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Check in for Metformin at 08:45'),
          findsWidgets);
      handle.dispose();
    });

    testWidgets('week grid cells say what happened, not just a colour',
        (tester) async {
      final handle = tester.ensureSemantics();
      _phone(tester);
      await tester.pumpWidget(_meds(now));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(r'^Thyroxine, .*: (Taken|Missed)$')),
          findsWidgets);
      handle.dispose();
    });

    testWidgets('section titles are headings', (tester) async {
      final handle = tester.ensureSemantics();
      _phone(tester);
      await tester.pumpWidget(_meds(now));
      await tester.pumpAndSettle();
      for (final title in ['My medicines', 'Today', 'This week']) {
        expect(tester.getSemantics(find.text(title)),
            containsSemantics(isHeader: true),
            reason: title);
      }
      handle.dispose();
    });

    testWidgets('does not overflow at 200% text size', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_meds(now, textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView).first,
          const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty medicine name is explained, not ignored',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_meds(now));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SingleChildScrollView).first,
          const Offset(0, -1200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a medicine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the medicine name.'), findsOneWidget);
    });
  });

  group('upload page', () {
    testWidgets('consent checkbox carries its own name', (tester) async {
      final handle = tester.ensureSemantics();
      _phone(tester);
      await tester.pumpWidget(_upload());
      await tester.pumpAndSettle();
      expect(
          find.bySemanticsLabel(RegExp(r'^This is a sample or anonymised')),
          findsWidgets);
      handle.dispose();
    });

    testWidgets('does not overflow at 200% text size', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_upload(textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
