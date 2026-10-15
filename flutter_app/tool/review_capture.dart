// Review-only rendering harness. Run explicitly with flutter test; this file is
// not part of the app or the default *_test.dart suite.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/report_workspace.dart';

void main() {
  setUpAll(() async {
    // Flutter's test-only fallback is Ahem (solid blocks). Replace that test
    // fallback with the SDK's Material Roboto for legible control labels.
    final materialFont = await File('/Users/anant/Documents/Codex/2026-10-09/ana/work/flutter-sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf').readAsBytes();
    for (final family in ['Roboto', 'Arial', '.AppleSystemUIFont']) {
      final fallback = FontLoader(family);
      fallback.addFont(Future.value(ByteData.sublistView(materialFont)));
      await fallback.load();
    }
    final manifest = jsonDecode(
            await File('build/web/assets/FontManifest.json').readAsString())
        as List;
    for (final family in manifest) {
      final loader = FontLoader(family['family']);
      for (final font in family['fonts']) {
        final bytes =
            await File('build/web/assets/${font['asset']}').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
  });
  testWidgets('render named review states from the actual workspace',
      (tester) async {
    final report = jsonDecode(File(
            '/Users/anant/Documents/Codex/2026-10-09/ana/outputs/medivaanii-synthetic-photo-response.json')
        .readAsStringSync()) as Map<String, dynamic>;
    final key = GlobalKey();
    Future<void> render(String name, Size size,
        {bool processing = false,
        bool labs = false,
        bool error = false}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
                debugShowCheckedModeBanner: false,
              theme: medivaaniiTheme(),
              home: ReportWorkspace(
                index: processing ? 0 : 1,
                onNavigate: (_) {},
                language: 'English',
                languages: const [
                  {'name': 'English', 'native': 'English', 'code': 'en'}
                ],
                onLanguage: (_) {},
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
                report: processing ? null : report,
                loading: processing,
                loadingMessage: 'Finding test names, values and units…',
                fileName: 'MedicalTranslation-TestPhoto.jpg',
                audioError: error
                    ? 'Narration unavailable. Check your connection and try Play again.'
                    : null,
              ))));
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/images/arogya_pandit_logo.png'),
          tester.element(find.byType(ReportWorkspace))));
      if (processing) {
        await tester.pump(const Duration(milliseconds: 250));
      } else {
        await tester.pumpAndSettle();
      }
      if (labs) {
        await tester.tap(find.text('Lab values (5)'));
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('../.impeccable/review/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }

    await render('report-desktop', const Size(1440, 900));
    await render('labs-mobile', const Size(390, 844), labs: true);
    await render('processing-mobile', const Size(390, 844), processing: true);
    await render('audio-error-mobile', const Size(390, 844), error: true);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
