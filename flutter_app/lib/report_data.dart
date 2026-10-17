import 'dart:convert';
import 'app_content_utils.dart';
import 'report_export_strings.dart';

Map<String, dynamic> mergeReportTranslation(
    Map<String, dynamic> current,
    Map<String, dynamic> requested,
    Map<String, dynamic> translated,
    String language) {
  final revision = jsonEncode(parsedReportData(requested));
  if (parsedReportData(requested).isEmpty ||
      jsonEncode(parsedReportData(current)) != revision ||
      jsonEncode(parsedReportData(
              {'parsed_data': translated['translation_source_revision']})) !=
          revision) {
    return current;
  }
  // Preserve the current report and correction overlays. Translation only
  // supplies language fields for the exact extraction revision requested.
  return {
    ...current,
    'translated_explanation': translated['translated_explanation'] ?? '',
    'translation_source_revision': translated['translation_source_revision'],
    'translated_suggestions': translated['translated_suggestions'] ?? [],
    'disease_explanation_lang': translated['disease_explanation_lang'] ??
        translated['disease_explanation_hi'] ??
        '',
    'solution_plan_lang': translated['solution_plan_lang'] ??
        translated['solution_plan_hi'] ??
        '',
    'target_language': language,
  };
}

Map<String, dynamic> parsedReportData(Map report) {
  dynamic parsed = report['parsed_data'];
  if (parsed is String) {
    try {
      parsed = jsonDecode(parsed);
    } catch (_) {
      return {};
    }
  }
  return parsed is Map ? Map<String, dynamic>.from(parsed) : {};
}

String reportQualityState(Map report) {
  if (report['extraction_version'] != 4 ||
      parsedReportData(report)['schema_version'] != 4) {
    return 'legacy_unverified';
  }
  final quality = report['extraction_quality'];
  final state = quality is Map ? quality['state'] : null;
  if (state == 'blocked') return 'blocked';
  final declared = declaredMeasurementCount(report);
  if (declared != null &&
      declared != reportLabValues(report['parsed_data']).length) {
    return 'partial';
  }
  return ['ready', 'partial', 'blocked'].contains(state)
      ? state.toString()
      : 'blocked';
}

int? declaredMeasurementCount(Map report) {
  final matches = RegExp(
          r'(\d+)\s*(?:usable\s*measurements|laboratory\s*results\s*extracted)',
          caseSensitive: false)
      .allMatches((report['extracted_text'] ?? '').toString());
  final counts = matches.map((m) => int.parse(m[1]!)).toList()..sort();
  final quality = report['extraction_quality'];
  final supplied =
      quality is Map ? quality['expected_measurement_count'] : null;
  return supplied is int
      ? supplied
      : counts.isEmpty
          ? null
          : counts.last;
}

Map<String, int> reportComparisonCounts(Map report) {
  final rows = reportLabValues(report['parsed_data']).where((r) =>
      r['record_type'] == 'measurement' && r['acceptance_state'] != 'rejected');
  final abnormal = rows
      .where((r) =>
          r['acceptance_state'] == 'eligible' &&
          ['high', 'low', 'abnormal', 'critical'].contains(r['status']))
      .length;
  final normal = rows
      .where(
          (r) => r['acceptance_state'] == 'eligible' && r['status'] == 'normal')
      .length;
  return {
    'abnormal': abnormal,
    'normal': normal,
    'unclassified': rows.length - abnormal - normal
  };
}

bool measurementMatchesFilter(Map row, String filter) {
  final eligible = row['acceptance_state'] == 'eligible';
  final status = eligible ? row['status'] : 'unknown';
  return switch (filter) {
    'flagged' =>
      eligible && ['high', 'low', 'abnormal', 'critical'].contains(status),
    'normal' => eligible && status == 'normal',
    'unclassified' =>
      !['high', 'low', 'abnormal', 'critical', 'normal'].contains(status),
    'review' => !eligible,
    _ => true,
  };
}

bool reportOutputAllowed(Map report) =>
    ['ready', 'partial'].contains(reportQualityState(report));

List<Map<String, dynamic>> eligibleReportLabValues(Map report) =>
    reportOutputAllowed(report)
        ? reportLabValues(report['parsed_data'])
            .where((row) =>
                row['record_type'] == 'measurement' &&
                row['acceptance_state'] == 'eligible' &&
                row['measurement_id'] != null)
            .toList()
        : [];

List<Map<String, dynamic>> eligibleReportNarratives(Map report) {
  if (!reportOutputAllowed(report)) return [];
  final notes = parsedReportData(report)['source_narratives'];
  return notes is List
      ? notes
          .whereType<Map>()
          .where((row) =>
              row['record_type'] == 'narrative' &&
              row['acceptance_state'] == 'eligible' &&
              row['measurement_id'] != null &&
              ['findings', 'diagnosis', 'impression'].contains(row['section']))
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : [];
}

Map<String, dynamic> restoredReport(Map<String, dynamic> report) {
  if (reportOutputAllowed(report)) return report;
  return {
    ...report,
    for (final key in [
      'simple_explanation',
      'medical_summary',
      'translated_explanation',
      'disease_explanation_en',
      'disease_explanation_lang',
      'disease_explanation_hi',
      'solution_plan_en',
      'solution_plan_lang',
      'solution_plan_hi'
    ])
      key: '',
    'suggestions': [],
    'translated_suggestions': []
  };
}

String reportCoverageText(Map report) {
  final quality = report['extraction_quality'] is Map
      ? report['extraction_quality'] as Map
      : {};
  return '${quality['eligible_count'] ?? 0} usable measurements · ${quality['eligible_narrative_count'] ?? 0} source-backed notes · ${quality['needs_review_count'] ?? 0} need source review · ${quality['unresolved_result_regions'] ?? 0} unresolved regions';
}

Map<String, dynamic> reportExportData(Map<String, dynamic> report,
    [String language = 'English']) {
  final copy = ReportExportStrings(language);
  if (!reportOutputAllowed(report)) {
    throw StateError(copy.text('blocked'));
  }
  final labs = eligibleReportLabValues(report);
  final notes = eligibleReportNarratives(report);
  final quality = report['extraction_quality'] is Map
      ? report['extraction_quality'] as Map
      : {};
  final blocks = <Map<String, String>>[];
  final lines = <String>[];
  void add(String kind, String text, {String? label, String? suffix}) {
    blocks.add({
      'kind': kind,
      'text': text,
      if (label != null) 'label': label,
      if (suffix != null) 'suffix': suffix,
    });
    lines.add(switch (kind) {
      'field' => '$label: $text${suffix == null ? '' : ' · $suffix'}',
      'bullet' => '• $text',
      _ => text,
    });
  }

  if (reportQualityState(report) == 'partial') {
    add('paragraph', copy.text('partial'));
  }
  add('paragraph', copy.coverage(quality));
  add('space', '');
  if (labs.isNotEmpty) add('heading', copy.text('results'));
  for (final row in labs) {
    // Source names, values, units and reference text remain verbatim. Only
    // generated labels and the comparison state use the selected language.
    add('bullet', '${row['test_name']}: ${row['value']} ${row['unit'] ?? ''}');
    if (row['source_fields'] is Map && row['source_fields']['value'] is Map) {
      final source = row['source_fields']['value'];
      add('field', copy.sourcePage(source['page']),
          label: copy.text('originalSource'));
      if (source['text'] != row['value']) {
        add('field', '${source['text']}',
            label: copy.text('printedValue'),
            suffix: copy.text('correctedValue'));
      }
    }
    if ((row['reference_range'] ?? '').toString().isNotEmpty) {
      add('field', '${row['reference_range']}',
          label: copy.text('referenceRange'));
    }
    if ((row['status'] ?? 'unknown') == 'unknown') {
      add('paragraph', copy.text('noComparison'));
    } else {
      add('field', copy.status(row['status']), label: copy.text('comparison'));
    }
    add('space', '');
  }
  for (final note in notes) {
    add('heading', copy.text(note['section'].toString()));
    add('bullet', '${note['text']}');
    if (note['source_fields'] is Map && note['source_fields']['text'] is Map) {
      add('field', copy.sourcePage(note['source_fields']['text']['page']),
          label: copy.text('originalSource'));
    }
    add('space', '');
  }
  add('paragraph', copy.text('disclaimer'));
  return {
    ...report,
    'simple_explanation': lines.join('\n'),
    // The PDF consumes only these locally generated, source-backed blocks;
    // saved translated prose is not part of the selected-language export.
    'export_blocks': blocks,
    'medical_summary': '',
    'translated_explanation':
        report['translation_source_revision'] == report['parsed_data']
            ? report['translated_explanation'] ?? ''
            : '',
    'suggestions': [],
    'translated_suggestions': [],
    'disease_explanation_en': '',
    'disease_explanation_lang': '',
    'disease_explanation_hi': '',
    'solution_plan_en': '',
    'solution_plan_lang': '',
    'solution_plan_hi': ''
  };
}

List<Map<String, dynamic>> reportLabValues(dynamic value) {
  dynamic parsed = value;
  if (parsed is String) {
    try {
      parsed = jsonDecode(parsed);
    } on FormatException {
      return const [];
    }
  }
  if (parsed is! Map || parsed['lab_values'] is! List) return const [];
  return (parsed['lab_values'] as List)
      .whereType<Map>()
      .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

String reportText(dynamic value) {
  if (value is! String) return '';
  return normalizeReportText(value
      .replaceAllMapped(
          RegExp(r'\*\*(.*?)\*\*'), (match) => match.group(1) ?? '')
      .replaceAllMapped(RegExp(r'`([^`]*)`'), (match) => match.group(1) ?? '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-=]{3,}\s*$', multiLine: true), ''));
}

/// The list and the voice context use every extracted measurement, including
/// readings that still need review. Review state is never silently upgraded.
List<Map<String, dynamic>> workspaceMeasurements(Map? report) => report == null
    ? []
    : reportLabValues(report['parsed_data'])
        .where((row) =>
            row['measurement_id'] != null &&
            row['record_type'] == 'measurement' &&
            row['acceptance_state'] != 'rejected')
        .toList();
