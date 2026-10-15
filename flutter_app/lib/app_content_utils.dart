String normalizeReportText(String? value) {
  if (value == null) return '';

  final cleaned = value
      .replaceAll(RegExp(r'\r\n?|\n'), '\n')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  if (cleaned.isEmpty) return '';

  return cleaned.split('\n').map((line) => line.trim()).join('\n');
}

List<String> splitIntoReadableParagraphs(String? value, {int? maxParagraphs}) {
  final normalized = normalizeReportText(value);
  if (normalized.isEmpty) return const [];

  final paragraphs = normalized
      .split(RegExp(r'\n\s*\n'))
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .toList();

  if (paragraphs.isEmpty) return [normalized];
  return maxParagraphs == null
      ? paragraphs
      : paragraphs.take(maxParagraphs).toList();
}

enum ReportBlockKind { heading, paragraph, bullet, numbered, notice, field }

class ReportBlock {
  const ReportBlock(this.kind, this.text, {this.number, this.label});
  final ReportBlockKind kind;
  final String text;
  final String? number;
  final String? label;
}

// Only generated explanatory copy is cleaned. Source/OCR text and lab values
// remain untouched. Keep medical symbols (µ, ±, ≥, arrows) and Indic joiners.
String professionalReportText(String? value) => normalizeReportText(value)
    .replaceAll(
        RegExp(
            r'[\u{1F000}-\u{1FAFF}\u260E\u2611\u26A0\u26A1\u2705\u270F\u274C\u2753\u2757]\uFE0F?',
            unicode: true),
        '')
    .split('\n')
    .map((line) => line.trim())
    .join('\n')
    .trim();

const _reportHeadings = {
  'abnormal results explained': 'Abnormal results explained',
  'understanding your lab tests': 'Understanding your lab tests',
  'clinical findings': 'Clinical findings',
  'diagnosis/impression': 'Diagnosis / impression',
  'what should you do next': 'What should you do next?',
  'why doctor interpretation matters': 'Why doctor interpretation matters',
  'what lab tests tell us': 'What lab tests tell us',
  'why see your doctor': 'Why see your doctor?',
  'detailed laboratory analysis': 'Detailed laboratory analysis',
  'medical recommendations': 'Medical recommendations',
  'important notes': 'Important notes',
  'results in this report': 'Results in this report',
  'diagnosis / impression reported': 'Diagnosis / impression reported',
};

const _reportFields = {
  'patient': 'Patient',
  'report date': 'Report date',
  'overall assessment': 'Overall assessment',
  'result': 'Result',
  'reference range': 'Reference range',
  'interpretation': 'Interpretation',
  'report clues': 'Report clues',
  'original source': 'Original source',
  'originally printed value': 'Originally printed value',
};

/// A small, explicit document model instead of displaying backend prose as one
/// text blob. It preserves every content line and tolerates translated prose.
List<ReportBlock> reportDocument(String? value) {
  final blocks = <ReportBlock>[];
  final prose = <String>[];
  void flush() {
    if (prose.isNotEmpty) {
      blocks.add(ReportBlock(ReportBlockKind.paragraph, prose.join(' ')));
      prose.clear();
    }
  }

  for (final line in professionalReportText(value).split('\n')) {
    if (line.isEmpty) {
      flush();
      continue;
    }
    if (RegExp(r'^[=\-_]{3,}$').hasMatch(line)) continue;
    if (RegExp(r'^YOUR MEDICAL REPORT(?: - GENERAL)?(?: EXPLANATION)?$',
            caseSensitive: false)
        .hasMatch(line)) {
      continue;
    }
    final bullet = RegExp(r'^[•*\-]\s+(.+)$').firstMatch(line);
    final numbered = RegExp(r'^(\d+)[.)]\s+(.+)$').firstMatch(line);
    final notice = RegExp(
            r'^(ATTENTION NEEDED|GOOD NEWS|REMEMBER|IMPORTANT):\s*(.+)$',
            caseSensitive: false)
        .firstMatch(line);
    final headingKey = line.replaceFirst(RegExp(r'[:?]$'), '').toLowerCase();
    final heading = _reportHeadings[headingKey];
    final markdown = RegExp(r'^#{1,4}\s+(.+)$').firstMatch(line);
    final field = RegExp(r'^([^:]+):\s*(.+)$').firstMatch(line);
    final fieldKey = field?[1]?.toLowerCase();
    if (bullet != null ||
        numbered != null ||
        notice != null ||
        heading != null ||
        markdown != null ||
        _reportFields.containsKey(fieldKey) ||
        fieldKey == 'test') {
      flush();
      if (bullet != null) {
        blocks.add(ReportBlock(ReportBlockKind.bullet, bullet[1]!));
      } else if (numbered != null) {
        blocks.add(ReportBlock(ReportBlockKind.numbered, numbered[2]!,
            number: numbered[1]));
      } else if (notice != null) {
        final label = notice[1]!.toLowerCase();
        blocks.add(ReportBlock(ReportBlockKind.notice, notice[2]!,
            label: '${label[0].toUpperCase()}${label.substring(1)}'));
      } else if (fieldKey == 'test') {
        blocks.add(ReportBlock(ReportBlockKind.heading, field![2]!));
      } else if (_reportFields.containsKey(fieldKey)) {
        blocks.add(ReportBlock(ReportBlockKind.field, field![2]!,
            label: _reportFields[fieldKey]));
      } else {
        blocks.add(
            ReportBlock(ReportBlockKind.heading, heading ?? markdown![1]!));
      }
    } else {
      prose.add(line);
    }
  }
  flush();
  return blocks;
}
