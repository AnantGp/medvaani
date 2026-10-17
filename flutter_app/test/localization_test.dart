import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/app_strings.dart';
import 'package:medical_cdss/report_workspace.dart';

const _languages = [
  {'code': 'en', 'name': 'English', 'native': 'English'},
  {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
  {'code': 'es', 'name': 'Spanish', 'native': 'Español'},
  {'code': 'zh', 'name': 'Mandarin', 'native': '中文'},
];

void main() {
  test('UI catalogs retain every named parameter across all four languages',
      () {
    final variables = RegExp(r'\{(\w+)\}');
    for (final key in AppStrings.keys) {
      final original = variables.allMatches(key).map((m) => m[1]).toSet();
      for (final language in _languages) {
        final translated = AppStrings(language['name']!).t(key);
        expect(translated.trim(), isNotEmpty, reason: key);
        expect(
            variables.allMatches(translated).map((m) => m[1]).toSet(), original,
            reason: '${language['code']}: $key');
      }
    }
  });

  test('explicit app preference wins over a report language', () {
    expect(AppStrings.preferredName('Spanish', 'Hindi'), 'Spanish');
    expect(AppStrings.preferredName(null, 'Hindi'), 'Hindi');
    expect(AppStrings.preferredName(null), 'English');
    expect(AppStrings.preferredName('unknown', 'unknown'), 'English');
  });

  test('localized labels preserve exact report fields', () {
    for (final language in _languages) {
      final copy = AppStrings(language['name']!);
      expect(copy.t('Ref: {range}', {'range': '>= 4.0 µmol/L'}),
          contains('>= 4.0 µmol/L'));
      expect(copy.t('Listen to {test}', {'test': 'HbA1c (IFCC)'}),
          contains('HbA1c (IFCC)'));
      expect(
          copy.error(
              'The free AI quota is busy or exhausted. Please wait and try again.'),
          copy.t(
              'The free AI quota is busy or exhausted. Please wait and try again.'));
    }
  });

  testWidgets('global language changes the upload journey before any report',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var language = 'English';
    await tester.pumpWidget(MaterialApp(
        theme: medivaaniiTheme(),
        home: StatefulBuilder(
            builder: (context, setState) => ReportWorkspace(
                  index: 0,
                  language: language,
                  languages: _languages,
                  onLanguage: (value) => setState(() => language = value),
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
                ))));
    for (final entry in _languages) {
      await tester.tap(find.text(entry['native']!));
      await tester.pumpAndSettle();
      final copy = AppStrings(entry['name']!);
      expect(find.text(copy.t('Your report.\nA clearer conversation.')),
          findsOneWidget);
      expect(find.text(copy.t('Choose PDF')), findsOneWidget);
      expect(find.text(copy.t('Take photo')), findsOneWidget);
      expect(find.text(copy.t('Settings')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: entry['name']);
    }
  });
}
