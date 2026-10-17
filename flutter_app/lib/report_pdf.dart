import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'report_data.dart';
import 'report_export_strings.dart';

Future<Uint8List> buildReportPdf(Map<String, dynamic> data, String lang) async {
  final copy = ReportExportStrings(lang);
  data = reportExportData(data, lang);
  final blocks = (data['export_blocks'] as List).cast<Map<String, String>>();
  final pdf = pw.Document(title: copy.text('title'), author: 'Medivaanii');
  final regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
  final needsCjk = copy.code == 'zh' ||
      blocks.any((block) =>
          RegExp(r'[\u2E80-\u9FFF\uF900-\uFAFF]').hasMatch(block['text']!));
  final fallback = <pw.Font>[
    if (needsCjk)
      pw.Font.ttf(
          await rootBundle.load('assets/fonts/NotoSansSC-Pdf-Regular.ttf')),
  ];
  final bodyStyle = pw.TextStyle(
      font: regular, fontFallback: fallback, fontSize: 11, lineSpacing: 3);
  final titleStyle = pw.TextStyle(
      font: bold,
      fontFallback: fallback,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromHex('#242C2B'));
  final headerStyle = titleStyle.copyWith(fontSize: 16);
  final subHeaderStyle =
      bodyStyle.copyWith(fontSize: 9, color: PdfColors.grey600, lineSpacing: 0);
  final footerStyle =
      bodyStyle.copyWith(fontSize: 8, color: PdfColors.grey500, lineSpacing: 0);
  final contentWidth = PdfPageFormat.a4.width - 72;
  final text = _PdfText(contentWidth);
  final items = <pw.Widget>[
    pw.SizedBox(height: 10),
    await text.build(copy.text('explanation'), titleStyle, bold: true),
    pw.SizedBox(height: 3),
  ];

  for (final block in blocks) {
    final value = block['text']!;
    switch (block['kind']) {
      case 'space':
        items.add(pw.SizedBox(height: 8));
      case 'heading':
        items.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
            child: await text.build(value, titleStyle, bold: true)));
      case 'bullet':
        items.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: 16, child: pw.Text('•', style: bodyStyle)),
                  pw.Expanded(
                      child: await text.build(value, bodyStyle,
                          maxWidth: contentWidth - 16)),
                ])));
      case 'field':
        final label = '${block['label']}: ';
        final labelStyle = titleStyle.copyWith(fontSize: 11);
        final suffix = block['suffix'];
        // Indic labels need shaping, while the source value (range, page or
        // printed reading) can remain searchable vector text when Latin.
        final field = _PdfText.needsShaping(label) ||
                _PdfText.needsShaping(value) ||
                (suffix != null && _PdfText.needsShaping(suffix))
            ? pw.Wrap(spacing: 3, runSpacing: 2, children: [
                await text.build(label, labelStyle, bold: true),
                await text.build(value, bodyStyle),
                if (suffix != null) await text.build('· $suffix', bodyStyle),
              ])
            : pw.RichText(
                text: pw.TextSpan(style: bodyStyle, children: [
                pw.TextSpan(text: label, style: labelStyle),
                pw.TextSpan(text: value),
                if (suffix != null) pw.TextSpan(text: ' · $suffix'),
              ]));
        items.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5), child: field));
      default:
        items.add(await text.build(value, bodyStyle));
        items.add(pw.SizedBox(height: 4));
    }
  }

  final header = await text.build(copy.text('title'), headerStyle, bold: true);
  final date = copy.displayDate((data['report_date'] ?? '').toString());
  final subtitle =
      await text.build('${copy.text('generatedBy')}  •  $date', subHeaderStyle);
  final footer = await text.build(copy.text('footer'), footerStyle,
      maxWidth: contentWidth * .7);
  final hindiPageLabel = copy.code == 'hi'
      ? await text.build(copy.sourcePage('').trim(), footerStyle)
      : null;
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      maxPages: 100,
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          header,
          subtitle,
          pw.Divider(color: PdfColor.fromHex('#A32E35'), thickness: 1),
          pw.SizedBox(height: 2),
        ],
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          footer,
          if (hindiPageLabel != null)
            pw.Row(children: [
              hindiPageLabel,
              pw.Text(' ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: footerStyle),
            ])
          else
            pw.Text(copy.pageCount(ctx.pageNumber, ctx.pagesCount),
                style: footerStyle),
        ],
      ),
      build: (ctx) => items,
    ),
  );
  return pdf.save();
}

/// dart_pdf embeds glyphs but does not perform Indic OpenType shaping. Use
/// Flutter's existing shaper for Devanagari runs so vowel signs and conjuncts
/// remain legible. Only these runs are embedded as transparent, 3x-resolution
/// images; Latin source facts and the other supported languages stay vector.
class _PdfText {
  _PdfText(this.width);
  final double width;
  static Future<void>? _fonts;
  static bool needsShaping(String value) =>
      RegExp(r'[\u0900-\u097F]').hasMatch(value);

  static Future<void> _loadFonts() => _fonts ??= () async {
        final devanagari = FontLoader('MedivaaniiPdfDevanagari')
          ..addFont(
              rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'))
          ..addFont(
              rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf'));
        final latin = FontLoader('MedivaaniiPdfLatin')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
        await Future.wait([devanagari.load(), latin.load()]);
      }();

  Future<pw.Widget> build(String value, pw.TextStyle style,
      {bool bold = false, double? maxWidth}) async {
    if (!needsShaping(value)) return pw.Text(value, style: style);
    await _loadFonts();
    final fontSize = style.fontSize ?? 11;
    final color = style.color ?? PdfColors.black;
    final paragraph = (ui.ParagraphBuilder(ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      fontFamily: 'MedivaaniiPdfDevanagari',
      fontSize: fontSize,
      fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
      height: 1.35,
    ))
          ..pushStyle(ui.TextStyle(
            color: ui.Color.fromARGB(255, (color.red * 255).round(),
                (color.green * 255).round(), (color.blue * 255).round()),
            fontFamily: 'MedivaaniiPdfDevanagari',
            fontFamilyFallback: const ['MedivaaniiPdfLatin', 'NotoSansSC'],
            fontSize: fontSize,
            fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
            height: 1.35,
          ))
          ..addText(value))
        .build()
      ..layout(ui.ParagraphConstraints(width: (maxWidth ?? width) - 2));
    final logicalWidth = paragraph.longestLine.ceilToDouble() + 2;
    final logicalHeight = paragraph.height.ceilToDouble() + 2;
    const scale = 3.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(scale);
    canvas.drawParagraph(paragraph, const ui.Offset(1, 1));
    final picture = recorder.endRecording();
    final raster = await picture.toImage(
        (logicalWidth * scale).ceil(), (logicalHeight * scale).ceil());
    final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
    raster.dispose();
    picture.dispose();
    paragraph.dispose();
    if (bytes == null) throw StateError('Unable to render PDF text.');
    return pw.Image(pw.MemoryImage(bytes.buffer.asUint8List()),
        width: logicalWidth, height: logicalHeight);
  }
}
