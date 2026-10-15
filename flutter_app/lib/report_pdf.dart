import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'app_content_utils.dart';
import 'report_data.dart';

Future<Uint8List> buildReportPdf(Map<String, dynamic> data, String lang) async {
  data = reportExportData(data);
  final pdf = pw.Document();
  final isEnglish = lang == 'English';

  String fontAssetRegular = 'assets/fonts/NotoSans-Regular.ttf';
  String fontAssetBold = 'assets/fonts/NotoSans-Bold.ttf';
  if (['Hindi', 'Marathi', 'Nepali'].contains(lang)) {
    fontAssetRegular = 'assets/fonts/NotoSansDevanagari-Regular.ttf';
    fontAssetBold = 'assets/fonts/NotoSansDevanagari-Bold.ttf';
  } else if (lang == 'Tamil') {
    fontAssetRegular = 'assets/fonts/NotoSansTamil-Regular.ttf';
    fontAssetBold = 'assets/fonts/NotoSansTamil-Regular.ttf';
  } else if (['Bengali', 'Assamese'].contains(lang)) {
    fontAssetRegular = 'assets/fonts/NotoSansBengali-Regular.ttf';
    fontAssetBold = 'assets/fonts/NotoSansBengali-Regular.ttf';
  } else if (['Arabic', 'Urdu', 'Persian'].contains(lang)) {
    fontAssetRegular = 'assets/fonts/NotoSansArabic-Regular.ttf';
    fontAssetBold = 'assets/fonts/NotoSansArabic-Regular.ttf';
  }

  if (['Telugu', 'Gujarati', 'Kannada', 'Malayalam'].contains(lang)) {
    fontAssetRegular = 'assets/fonts/NotoSans$lang-Regular.ttf';
    fontAssetBold = fontAssetRegular;
  }

  final fontDataRegular = await rootBundle.load(fontAssetRegular);
  final fontDataBold = await rootBundle.load(fontAssetBold);
  final ttfRegular = pw.Font.ttf(fontDataRegular);
  final ttfBold = pw.Font.ttf(fontDataBold);

  final fontDataFallback =
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final ttfFallback = pw.Font.ttf(fontDataFallback);

  final suggestions =
      (data['suggestions'] as List? ?? []).map((s) => s.toString()).toList();
  final translatedSuggestions = (data['translated_suggestions'] as List? ?? [])
      .map((s) => s.toString())
      .toList();
  final translatedExplanation =
      (data['translated_explanation'] ?? '').toString();
  final diseaseEn = (data['disease_explanation_en'] ?? '').toString();
  final solutionEn = (data['solution_plan_en'] ?? '').toString();
  final diseaseLang =
      (data['disease_explanation_lang'] ?? data['disease_explanation_hi'] ?? '')
          .toString();
  final solutionLang =
      (data['solution_plan_lang'] ?? data['solution_plan_hi'] ?? '').toString();
  final medicalSummary = (data['medical_summary'] ?? '').toString();
  final simpleExplanation = (data['simple_explanation'] ?? '').toString();

  final List<pw.Widget> items = [];
  final bodyStyle = pw.TextStyle(
      font: ttfRegular,
      fontFallback: [ttfFallback],
      fontSize: 11,
      lineSpacing: 3);
  final titleStyle = pw.TextStyle(
      font: ttfBold,
      fontFallback: [ttfFallback],
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromHex('#242C2B'));
  final headerStyle = pw.TextStyle(
      font: ttfBold,
      fontFallback: [ttfFallback],
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromHex('#242C2B'));
  final subHeaderStyle = pw.TextStyle(
      font: ttfRegular,
      fontFallback: [ttfFallback],
      fontSize: 9,
      color: PdfColors.grey600);
  final footerStyle = pw.TextStyle(
      font: ttfRegular,
      fontFallback: [ttfFallback],
      fontSize: 8,
      color: PdfColors.grey500);

  List<String> splitBody(String body) {
    final raw = professionalReportText(body);
    final List<String> parts = [];
    for (final para in raw.split('\n')) {
      final p = para.trim();
      if (p.isEmpty) continue;
      if (p.length <= 150) {
        parts.add(p);
      } else {
        final sentences = p.split(RegExp(r'(?<=[.!?])\s+'));
        for (final s in sentences) {
          final t = s.trim();
          if (t.isNotEmpty) parts.add(t);
        }
      }
    }
    return parts.isEmpty ? [body.trim()] : parts;
  }

  void addSection(String title, String body) {
    if (body.trim().isEmpty) return;
    if (items.isNotEmpty) {
      items.add(pw.Divider(color: PdfColors.grey300, thickness: 0.5));
    }
    items.add(pw.SizedBox(height: 10));
    items.add(pw.Text(title, style: titleStyle));
    items.add(pw.SizedBox(height: 3));
    for (final block in reportDocument(body)) {
      if (block.kind == ReportBlockKind.heading) {
        items.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
            child: pw.Text(block.text, style: titleStyle)));
      } else if (block.kind == ReportBlockKind.field) {
        items.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.RichText(
                text: pw.TextSpan(style: bodyStyle, children: [
              pw.TextSpan(
                  text: '${block.label}: ',
                  style: titleStyle.copyWith(fontSize: 11)),
              pw.TextSpan(text: block.text),
            ]))));
      } else if (block.kind == ReportBlockKind.notice) {
        items.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
            child: pw.Text(block.label!, style: titleStyle)));
        for (final chunk in splitBody(block.text)) {
          items.add(pw.Text(chunk, style: bodyStyle));
        }
        items.add(pw.SizedBox(height: 8));
      } else if (block.kind == ReportBlockKind.bullet ||
          block.kind == ReportBlockKind.numbered) {
        items.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                      width: 16,
                      child: pw.Text(
                          block.number == null ? '•' : '${block.number}.',
                          style: bodyStyle)),
                  pw.Expanded(child: pw.Text(block.text, style: bodyStyle)),
                ])));
      } else {
        for (final chunk in splitBody(block.text)) {
          items.add(pw.Text(chunk, style: bodyStyle));
        }
        items.add(pw.SizedBox(height: 6));
      }
    }
  }

  void addBullets(String title, List<String> bullets) {
    if (bullets.isEmpty) return;
    if (items.isNotEmpty) {
      items.add(pw.Divider(color: PdfColors.grey300, thickness: 0.5));
    }
    items.add(pw.SizedBox(height: 10));
    items.add(pw.Text(title, style: titleStyle));
    items.add(pw.SizedBox(height: 3));
    for (final b in bullets) {
      final chunks = splitBody(professionalReportText(b));
      if (chunks.every((chunk) => chunk.isEmpty)) continue;
      items.add(pw.Text('  \u2022  ${chunks.first}', style: bodyStyle));
      for (final extra in chunks.skip(1)) {
        items.add(pw.Text('     $extra', style: bodyStyle));
      }
      items.add(pw.SizedBox(height: 2));
    }
  }

  addSection('Simple explanation', simpleExplanation);
  if (!isEnglish && translatedExplanation.isNotEmpty) {
    addSection('$lang Explanation', translatedExplanation);
  }
  addSection('Medical summary', medicalSummary);
  addSection('Disease Explanation', diseaseEn);
  addSection('Solutions to Improve', solutionEn);
  if (!isEnglish && diseaseLang.isNotEmpty) {
    addSection('Disease Explanation ($lang)', diseaseLang);
  }
  if (!isEnglish && solutionLang.isNotEmpty) {
    addSection('Solutions ($lang)', solutionLang);
  }
  addBullets('Suggestions', suggestions);
  if (!isEnglish && translatedSuggestions.isNotEmpty) {
    addBullets('$lang Suggestions', translatedSuggestions);
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      maxPages: 100,
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Medical Report Summary', style: headerStyle),
          pw.Text(
              'Generated by Medivaanii  \u2022  ${_displayDate((data['report_date'] ?? '').toString())}',
              style: subHeaderStyle),
          pw.Divider(color: PdfColor.fromHex('#A32E35'), thickness: 1),
          pw.SizedBox(height: 2),
        ],
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Medivaanii · Educational summary', style: footerStyle),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: footerStyle),
        ],
      ),
      build: (ctx) => items,
    ),
  );
  return pdf.save();
}

String _displayDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
