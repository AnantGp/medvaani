import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/report_data.dart';

void main() {
  test(
      'count filters keep uncertain results out of within-range and flagged lists',
      () {
    final rows = [
      {'acceptance_state': 'eligible', 'status': 'normal'},
      {'acceptance_state': 'eligible', 'status': 'high'},
      {'acceptance_state': 'eligible', 'status': 'unknown'},
      {'acceptance_state': 'needs_review', 'status': 'normal'},
    ];
    expect(rows.where((row) => measurementMatchesFilter(row, 'all')).length, 4);
    expect(rows.where((row) => measurementMatchesFilter(row, 'flagged')).length,
        1);
    expect(
        rows.where((row) => measurementMatchesFilter(row, 'normal')).length, 1);
    expect(
        rows
            .where((row) => measurementMatchesFilter(row, 'unclassified'))
            .length,
        2);
  });

  test(
      'cached incomplete summary is partial and unknown comparisons stay separate',
      () {
    final report = <String, dynamic>{
      'extraction_version': 4,
      'extracted_text': '95usablemeasurements',
      'extraction_quality': {'state': 'ready'},
      'parsed_data': {
        'schema_version': 4,
        'lab_values': [
          {
            'record_type': 'measurement',
            'measurement_id': 'a',
            'test_name': 'Glucose',
            'value': '95',
            'unit': 'mg/dL',
            'acceptance_state': 'eligible',
            'status': 'unknown'
          },
          {
            'record_type': 'measurement',
            'measurement_id': 'b',
            'test_name': 'HDL',
            'value': '38.5',
            'unit': 'mg/dL',
            'acceptance_state': 'eligible',
            'status': 'low'
          }
        ]
      }
    };
    expect(reportQualityState(report), 'partial');
    expect(declaredMeasurementCount(report), 95);
    expect(reportComparisonCounts(report),
        {'abnormal': 1, 'normal': 0, 'unclassified': 1});
  });
  for (final section in ['findings', 'diagnosis', 'impression']) {
    for (final mixed in [false, true]) {
      test(
          '$section survives ${mixed ? 'mixed' : 'narrative-only'} export with its source',
          () {
        final report = <String, dynamic>{
          'extraction_version': 4,
          'extraction_quality': {
            'state': 'partial',
            'eligible_narrative_count': 1
          },
          'parsed_data': {
            'schema_version': 4,
            'lab_values': [
              if (mixed)
                {
                  'record_type': 'measurement',
                  'measurement_id': 'lab',
                  'acceptance_state': 'eligible',
                  'test_name': 'Glucose',
                  'value': '95',
                  'unit': 'mg/dL'
                }
            ],
            'source_narratives': [
              {
                'record_type': 'narrative',
                'measurement_id': 'note',
                'section': section,
                'acceptance_state': 'eligible',
                'text': 'Follow-up imaging advised',
                'source_fields': {
                  'text': {
                    'text': 'Follow-up imaging advised',
                    'page': 3,
                    'box': [.1, .2, .7, .03],
                    'method': 'native'
                  }
                }
              },
              {
                'record_type': 'narrative',
                'measurement_id': 'uncertain',
                'section': section,
                'acceptance_state': 'needs_review',
                'text': 'Uncertain OCR note'
              }
            ]
          }
        };
        final exported = reportExportData(report);
        expect(exported['simple_explanation'],
            contains('Follow-up imaging advised'));
        expect(exported['simple_explanation'],
            contains('Original source: Page 3'));
        expect(exported['simple_explanation'],
            isNot(contains('Uncertain OCR note')));
        expect(parsedReportData(exported)['source_narratives'],
            parsedReportData(report)['source_narratives']);
      });
    }
  }

  test('late translation cannot replace reviewed values or translations', () {
    final old = <String, dynamic>{'parsed_data': '{"value":"145"}'};
    final reviewed = <String, dynamic>{
      'parsed_data': '{"value":"95"}',
      'review': {'confirmed': true}
    };
    final translation = <String, dynamic>{
      'translated_explanation': 'Old 145',
      'translation_source_revision': old['parsed_data']
    };
    final merged = mergeReportTranslation(reviewed, old, translation, 'Hindi');
    expect(merged['parsed_data'], reviewed['parsed_data']);
    expect(merged['review'], reviewed['review']);
    expect(merged['translated_explanation'], isNull);
    final valid = mergeReportTranslation(
        reviewed,
        reviewed,
        {
          'translated_explanation': 'Current 95',
          'translation_source_revision': reviewed['parsed_data']
        },
        'Hindi');
    expect(valid['translated_explanation'], 'Current 95');
    expect(valid['review'], reviewed['review']);
  });

  test('confirmed legacy reports cannot generate outputs', () {
    final report = <String, dynamic>{
      'extraction_version': 3,
      'review': {'confirmed': true},
      'simple_explanation': 'Cached result'
    };
    expect(reportQualityState(report), 'legacy_unverified');
    expect(reportOutputAllowed(report), isFalse);
    expect(restoredReport(report)['simple_explanation'], '');
  });
  test('partial export includes only eligible measurements and coverage', () {
    final report = <String, dynamic>{
      'extraction_version': 4,
      'extraction_quality': {
        'state': 'partial',
        'eligible_count': 1,
        'needs_review_count': 1
      },
      'parsed_data': {
        'schema_version': 4,
        'lab_values': [
          {
            'record_type': 'measurement',
            'measurement_id': 'source-a',
            'test_name': 'Creatinine',
            'value': '0.9',
            'unit': 'mg/dL',
            'acceptance_state': 'eligible'
          },
          {
            'record_type': 'measurement',
            'measurement_id': 'source-b',
            'test_name': 'TSH',
            'value': '3',
            'unit': 'wU/ml',
            'acceptance_state': 'needs_review'
          },
        ]
      },
      'simple_explanation': 'Stale TSH explanation',
    };
    expect(eligibleReportLabValues(report), hasLength(1));
    expect(reportOutputAllowed(report), isTrue);
    final exported = reportExportData(report);
    expect(exported['simple_explanation'], contains('Partial report'));
    expect(exported['simple_explanation'], contains('Creatinine'));
    expect(exported['simple_explanation'], isNot(contains('TSH')));
  });
  test('exports translated prose only for the current extraction revision', () {
    final report = <String, dynamic>{
      'extraction_version': 4,
      'extraction_quality': {'state': 'ready'},
      'parsed_data': '{"schema_version":4,"lab_values":[]}',
      'translated_explanation': 'Translated explanation',
      'translation_source_revision': 'old'
    };
    expect(reportExportData(report)['translated_explanation'], '');
    report['translation_source_revision'] = report['parsed_data'];
    expect(reportExportData(report)['translated_explanation'],
        'Translated explanation');
  });
  test(
      'export shows physical source page and keeps printed value separate from correction',
      () {
    final report = <String, dynamic>{
      'extraction_version': 4,
      'extraction_quality': {'state': 'ready'},
      'parsed_data': {
        'schema_version': 4,
        'lab_values': [
          {
            'record_type': 'measurement',
            'measurement_id': 'one',
            'acceptance_state': 'eligible',
            'test_name': 'Glucose',
            'value': '95',
            'unit': 'mg/dL',
            'source_fields': {
              'value': {
                'text': '145',
                'page': 2,
                'box': [.1, .2, .1, .03]
              }
            }
          }
        ]
      }
    };
    final content = reportExportData(report)['simple_explanation'].toString();
    expect(content, contains('Original source: Page 2'));
    expect(content, contains('Originally printed value: 145'));
    expect(content, contains('Glucose: 95 mg/dL'));
  });
  test('cleans formatting markers while preserving the explanation paragraphs',
      () {
    expect(reportText('**Hemoglobin**\n\n# Explanation\nCarries oxygen.'),
        'Hemoglobin\n\nExplanation\nCarries oxygen.');
  });
  test('renders lab values returned as a JSON string without changing units',
      () {
    final rows = reportLabValues(
        '{"lab_values":[{"test_name":"Platelets","value":240,"unit":"10^3/µL"}]}');
    expect(rows, hasLength(1));
    expect(rows.single['value'], 240);
    expect(rows.single['unit'], '10^3/µL');
  });
  test('ignores malformed data instead of inventing test values', () {
    expect(reportLabValues('not JSON'), isEmpty);
    expect(
        reportLabValues({
          'lab_values': [
            null,
            12,
            {'test_name': 'Hb'}
          ]
        }),
        [
          {'test_name': 'Hb'}
        ]);
  });
}
