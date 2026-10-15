import 'dart:convert';
import 'dart:io';

// Presentation tests consume an anonymous API contract generated from a real
// physical PDF. Extraction/eligibility semantics are tested in the backend.
Map<String, dynamic> displayReport(Map<String, dynamic> data) {
  if (data.containsKey('extraction_version')) return data;
  final source =
      jsonDecode(File('test/fixtures/anonymous-report.json').readAsStringSync())
          as Map<String, dynamic>;
  final baseParsed =
      jsonDecode(source['parsed_data'] as String) as Map<String, dynamic>;
  dynamic parsed = data['parsed_data'] ?? baseParsed;
  if (parsed is String) parsed = jsonDecode(parsed);
  final rows =
      (parsed['lab_values'] as List? ?? []).whereType<Map>().map((row) {
    final matches = (baseParsed['lab_values'] as List)
        .where((r) => r['test_name'] == row['test_name']);
    final proof = matches.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(matches.first as Map);
    return {
      ...proof,
      ...row,
      'record_type': 'measurement',
      'acceptance_state': row['acceptance_state'] ?? 'eligible',
      'measurement_id': proof['measurement_id'] ?? row['test_name']
    };
  }).toList();
  return {
    ...source,
    'medical_summary': '',
    'translated_explanation': '',
    ...data,
    'source_evidence':
        (data['source_evidence'] as List? ?? source['source_evidence'] as List)
            .asMap()
            .entries
            .map((entry) => {
                  ...Map<String, dynamic>.from(entry.value as Map),
                  if (entry.key < rows.length)
                    'measurement_id': rows[entry.key]['measurement_id']
                })
            .toList(),
    'parsed_data': {
      ...Map<String, dynamic>.from(parsed as Map),
      'schema_version': 4,
      'lab_values': rows
    }
  };
}
