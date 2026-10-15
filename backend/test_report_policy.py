import copy
import json
from report_quality import validate_document, report_quality
from report_review import answer_question, apply_review, attach_review, evidence
from agents import infer_status_from_reference, parse_numeric_value
from test_report_quality import sample_measurement, document


def typed_report(*rows):
    doc = document(*rows)
    checked, quality = validate_document(doc)
    return {'extraction_version': 4, 'extraction_quality': quality,
            'parsed_data': {'schema_version': 4, 'lab_values': checked,
                            'document': {k: v for k, v in doc.items() if k != 'candidates'}},
            'extracted_text': '\n'.join(f"{r['test_name']}: {r['value']} {r['unit']}" for r in rows),
            'target_language': 'English'}


def glucose(value='145', reference='70-100'):
    row = sample_measurement('Glucose', value, 'mg/dL', reference)
    row['measurement_id'] = 'synthetic-glucose'
    row.update(status='high' if value == '145' and reference else 'unknown', status_source='reference_range' if reference else 'unknown')
    return row


def test_higher_question_never_matches_guideline_high():
    target = sample_measurement('High', '200', 'mg/dL', '160-189')
    target.update(record_type='guideline', measurement_id='guideline-high')
    result = answer_question(typed_report(glucose(), target), 'Which values are higher than they should be?')
    assert 'Glucose: 145' in result['answer']
    assert 'High: 200' not in result['answer']
    assert result['sources'][0]['measurement_id'] == 'synthetic-glucose'


def test_partial_question_mentions_coverage():
    bad = sample_measurement('TSH', '5.5', 'wU/ml', '0.5-4.5')
    bad['measurement_id'] = 'uncertain-tsh'
    result = answer_question(typed_report(glucose(), bad), 'Summarise my report')
    assert 'partial' in result['answer'].casefold()
    assert 'TSH: 5.5' not in result['answer']


def test_unknown_rows_are_not_abnormal_by_default():
    result = answer_question(typed_report(glucose(reference='')), 'Which results are abnormal?')
    assert 'Glucose: 145' not in result['answer']
    assert result['sources'] == []


def test_changed_measurement_retains_original_source_boxes():
    report = typed_report(glucose())
    rows = copy.deepcopy(report['parsed_data']['lab_values'])
    rows[0]['value'] = '95'
    result = apply_review(report, rows, infer_status_from_reference, parse_numeric_value)
    current = json.loads(result['parsed_data'])['lab_values'][0]
    assert current['source_fields']['value'] == report['parsed_data']['lab_values'][0]['source_fields']['value']
    assert current['corrections']['value']['confirmed']
    assert current['status'] == 'normal'


def test_review_confirmation_cannot_bypass_missing_source():
    row = glucose()
    del row['source_fields']['value']
    report = typed_report(row)
    result = apply_review(report, report['parsed_data']['lab_values'], infer_status_from_reference, parse_numeric_value)
    assert report_quality(result)['state'] == 'blocked'
    assert json.loads(result['parsed_data'])['lab_values'][0].get('source_fields') is not None


def test_image_tsh_unit_wu_is_not_accepted_as_uiu_in_answers():
    bad = sample_measurement('TSH', '5.5', 'wU/ml', '0.5-4.5')
    result = answer_question(typed_report(bad), 'What is my TSH?')
    assert result['supported'] is False and result['sources'] == []
    assert 'TSH: 5.5' not in result['answer']


def test_inequality_and_contextual_references_are_not_scalar_ranges():
    bounded = glucose('<100')
    contextual = sample_measurement('TSH', '2.8', 'µIU/ml', 'Pregnancy first trimester: 0.1-2.5')
    checked, _ = validate_document(document(bounded, contextual))
    assert all(row['status'] == 'unknown' for row in checked)


def test_legacy_question_is_unsupported_and_confirmation_cannot_promote_it():
    report = {'parsed_data': {'lab_values': [{'test_name': 'High', 'value': '200', 'unit': 'mg/dL'}]},
              'extracted_text': 'High: 200 mg/dL', 'review': {'confirmed': True}, 'extraction_version': 3}
    assert not answer_question(report, 'Which values are higher?')['supported']


def test_rebuilt_evidence_uses_original_fields_after_saved_evidence_is_lost():
    report = typed_report(glucose())
    rows = copy.deepcopy(report['parsed_data']['lab_values'])
    rows[0]['value'] = '95'
    corrected = apply_review(report, rows, infer_status_from_reference, parse_numeric_value)
    rebuilt = evidence(json.loads(corrected['parsed_data']), corrected['extracted_text'])
    assert rebuilt[0]['original_fields']['value'] == '145'
    assert rebuilt[0]['original_fields']['status'] == 'high'


def test_high_inside_a_named_test_is_not_a_high_results_intent():
    row = sample_measurement('High sensitivity CRP', '0.8', 'mg/L', '0-3')
    result = answer_question(typed_report(row), 'Explain my High sensitivity CRP')
    assert 'High sensitivity CRP: 0.8' in result['answer']
