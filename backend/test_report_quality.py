"""Acceptance policy regressions, using synthetic source-backed measurements."""
import copy
import importlib
import importlib.util


def policy():
    assert importlib.util.find_spec('report_quality') is not None, 'Source validation policy is missing'
    return importlib.import_module('report_quality')


def sample_measurement(name='Creatinine', value='0.8', unit='mg/dL', reference='0.5-1.2'):
    fields = {}
    for key, text, x, width in [('test_name', name, .06, .30), ('value', value, .43, .09),
                                ('unit', unit, .60, .10), ('reference_range', reference, .76, .18)]:
        if text:
            fields[key] = {'text': text, 'page': 1, 'box': [x, .3, width, .02], 'method': 'native'}
    return {'measurement_id': 'synthetic-creatinine', 'record_type': 'measurement',
            'test_name': name, 'value': value, 'unit': unit, 'reference_range': reference,
            'panel': 'Kidney', 'source_fields': fields, 'issues': [], 'status': 'unknown',
            'status_source': 'unknown', 'acceptance_state': 'eligible'}


def document(*rows, diagnostics=None):
    return {'source_digest': 'synthetic-document', 'pages': [{'page': 1, 'width': 600, 'height': 800}],
            'input_type': 'pdf', 'candidates': list(rows), 'diagnostics': diagnostics or [], 'extracted_text': ''}


def test_guideline_is_never_eligible():
    row = sample_measurement('High risk group', '<70', 'mg/dL', '<100')
    row['record_type'] = 'guideline'
    checked, quality = policy().validate_document(document(row))
    assert checked[0]['acceptance_state'] == 'rejected'
    assert quality['eligible_count'] == 0 and quality['state'] == 'blocked'


def test_mislabelled_guideline_cannot_enter_outputs_from_a_saved_report():
    row = sample_measurement('High risk group', '70', 'mg/dL', '<100')
    parsed = {'schema_version': 4, 'lab_values': [row], 'document': document()}
    assert policy().eligible_measurements(parsed) == []
    assert not policy().can_generate_report_output({'extraction_version': 4, 'parsed_data': parsed})


def test_legacy_report_cannot_generate_outputs_even_after_confirmation():
    report = {'extraction_version': 3, 'review': {'confirmed': True},
              'parsed_data': {'lab_values': [sample_measurement()]}}
    assert policy().report_quality(report)['state'] == 'legacy_unverified'
    assert policy().can_generate_report_output(report) is False


def test_confirmation_does_not_resolve_unit_issue():
    row = sample_measurement('TSH', '5.5', 'wU/ml', '0.5-4.5')
    checked, quality = policy().validate_document(document(row))
    assert checked[0]['acceptance_state'] == 'needs_review'
    assert any(i['code'] == 'unit_incompatible' for i in checked[0]['issues'])
    assert quality['eligible_count'] == 0


def test_missing_reference_keeps_valid_measurement_comparison_unknown():
    row = sample_measurement('PLR (Platelet Lymphocyte Ratio)', '90', 'Ratio', '')
    checked, quality = policy().validate_document(document(row))
    assert checked[0]['acceptance_state'] == 'eligible'
    assert checked[0]['status'] == 'unknown'
    assert quality['state'] == 'ready' and quality['eligible_count'] == 1


def test_literal_source_value_alone_does_not_prove_field_association():
    row = sample_measurement()
    row['source_fields']['unit']['page'] = 2
    checked, quality = policy().validate_document(document(row))
    assert checked[0]['acceptance_state'] == 'needs_review'
    assert quality['state'] == 'blocked'


def test_eligible_count_and_partial_coverage_exclude_uncertain_rows():
    good = sample_measurement()
    bad = copy.deepcopy(good)
    bad['measurement_id'] = 'uncertain'
    del bad['source_fields']['value']
    checked, quality = policy().validate_document(document(good, bad))
    assert quality['eligible_count'] == 1 and quality['needs_review_count'] == 1
    assert quality['state'] == 'partial'
    assert [r['measurement_id'] for r in policy().eligible_measurements({'lab_values': checked})] == ['synthetic-creatinine']


def test_failed_page_is_explicit_partial_coverage():
    checked, quality = policy().validate_document(document(sample_measurement(),
        diagnostics=[{'code': 'page_failed', 'page': 2}]))
    assert quality['state'] == 'partial' and quality['failed_pages'] == [2]


def test_stable_id_uses_source_identity_not_review_value_or_list_position():
    assert importlib.util.find_spec('report_records') is not None, 'Measurement contract is missing'
    from report_records import measurement_id
    box = [.4, .3, .1, .02]
    assert measurement_id('a', 1, 'blood', box) == measurement_id('a', 1, 'blood', box)
    assert measurement_id('a', 1, 'blood', box) != measurement_id('a', 2, 'blood', box)
    assert measurement_id('a', 1, 'blood', box) != measurement_id('b', 1, 'blood', box)


def test_ocr_fields_need_explicit_source_check_even_with_plausible_units():
    row = sample_measurement()
    for field in row['source_fields'].values():
        field['method'] = 'ocr'
    checked, quality = policy().validate_document(document(row))
    assert checked[0]['acceptance_state'] == 'needs_review'
    assert quality['eligible_count'] == 0


def test_per_field_photo_source_check_can_make_supported_fields_eligible():
    row = sample_measurement()
    for field in row['source_fields'].values():
        field['method'] = 'ocr'
    row['source_checked_fields'] = ['test_name', 'value', 'unit', 'reference_range']
    checked, _ = policy().validate_document(document(row))
    assert checked[0]['acceptance_state'] == 'eligible'
    assert checked[0]['status_source'] == 'reviewed_source'


def test_ocr_narrative_is_not_eligible_without_a_source_check():
    row = {'record_type': 'narrative', 'measurement_id': 'note', 'section': 'findings', 'text': 'Sample observation', 'source_fields': {'text': {'text': 'Sample observation', 'page': 1, 'box': [.1, .2, .5, .03], 'method': 'ocr'}}}
    checked, quality = policy().validate_document(document(row))
    assert checked[0]['acceptance_state'] == 'needs_review'
    assert quality['state'] == 'blocked'


def test_ocr_flag_requires_its_own_source_check():
    row = sample_measurement()
    row['source_fields']['flag'] = {'text': 'Normal', 'page': 1, 'box': [.96, .2, .03, .02], 'method': 'ocr'}
    checked, _ = policy().validate_document(document(row))
    assert checked[0]['acceptance_state'] == 'needs_review'
    row['source_checked_fields'] = ['flag']
    checked, _ = policy().validate_document(document(row))
    assert checked[0]['acceptance_state'] == 'eligible'
