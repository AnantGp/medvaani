import json
import pytest
import tempfile
from pathlib import Path
from agents import summary_agent, simplify_agent, get_medical_interpretation, infer_status_from_reference, parse_numeric_value, detect_status_from_line
from report_review import apply_review, answer_question, attach_review


def report(status="unknown", source="unknown"):
    from test_fixtures.report_layout import build_report
    from ocr import read_document
    from digital_results import extract_digital_results, source_field
    from report_quality import validate_document
    with tempfile.TemporaryDirectory() as tmp:
        path = build_report(Path(tmp) / 'synthetic.pdf', [('Glucose', '145', 'mg/dL', '')],
                            flags={'Glucose': status} if source == 'report' else None)
        doc = read_document(path)
        rows, diagnostics = extract_digital_results(doc['pages'], doc['source_digest'])
    row = rows[0]
    if source == 'report':
        word = next(w for w in doc['pages'][0]['words'] if w['text'] == status)
        row['source_fields']['flag'] = source_field([word], 1, 'native')
        row['reference_range'] = ''
        row['source_fields'].pop('reference_range', None)
    doc['candidates'] = rows
    rows, quality = validate_document(doc)
    return {'extraction_version': 4, 'extraction_quality': quality,
            'parsed_data': json.dumps({'schema_version': 4, 'lab_values': rows, 'findings': [], 'diagnosis': [],
                                      'document': {k: v for k, v in doc.items() if k != 'candidates'}}),
            'extracted_text': doc['extracted_text'], 'target_language': 'English'}


def test_unknown_is_never_presented_as_all_normal():
    state = report()
    assert "All laboratory values within normal" not in summary_agent(state)["medical_summary"]
    simple = simplify_agent(state)["simplified_explanation"]
    assert "All your lab tests" not in simple
    assert "no supported comparison" in simple
    assert "does not establish that they are normal or abnormal" in simple


def test_normal_result_is_not_called_abnormal():
    assert "abnormal" not in get_medical_interpretation("WBC", "normal", "7500", "/uL").lower()


def test_generic_abnormal_flag_does_not_invent_a_direction():
    assert detect_status_from_line("Glucose: 145 mg/dL - Abnormal") == "abnormal"


def test_empty_extraction_is_not_a_normal_health_assessment():
    state = {"parsed_data": json.dumps({"lab_values": []})}
    assert "No usable laboratory" in simplify_agent(state)["simplified_explanation"]


def test_review_recomputes_changed_values_using_only_corrected_reference():
    original = report("high", "report")
    rows = json.loads(original["parsed_data"])["lab_values"]
    rows[0].update(value="95", reference_range="70-100")
    result = apply_review(original, rows, infer_status_from_reference, parse_numeric_value)
    row = json.loads(result["parsed_data"])["lab_values"][0]
    assert row["status"] == "normal" and row["status_source"] == "reviewed_range"
    assert result["review"]["edited_lab_ids"] == [0]
    assert result["translated_explanation"] == ""
    assert "95 mg/dL" in result["simple_explanation"]


def test_changed_value_without_range_is_unknown():
    original = report("high", "report")
    rows = json.loads(original["parsed_data"])["lab_values"]
    rows[0]["value"] = "95"
    result = apply_review(original, rows, infer_status_from_reference, parse_numeric_value)
    assert json.loads(result["parsed_data"])["lab_values"][0]["status"] == "unknown"


def test_questions_return_exact_source_and_preserve_unknown():
    result = answer_question(report(), "What does my glucose result mean?")
    assert "cannot be reliably classified" in result["answer"]
    assert result["sources"][0]["source_quote"] == "Glucose 145 mg/dL"
    assert "diabetes" not in result["answer"].lower()


def test_questions_do_not_invent_unreported_tests_or_treatment():
    assert not answer_question(report(), "What is my vitamin D?")["supported"]
    assert not answer_question(report(), "Which medication should I take?")["supported"]


def test_review_rejects_invented_or_invalid_rows():
    with pytest.raises(ValueError):
        apply_review(report(), [], infer_status_from_reference, parse_numeric_value)


def test_text_only_reextract_requires_original_and_preserves_reviewed_corrections():
    import main
    from starlette.testclient import TestClient
    client = TestClient(main.app)
    original = report()
    original['extracted_text'] = 'Glucose: 95 mg/dL\nReference range: 70-100 mg/dL'
    original['source_layout'] = [{'page': 1, 'text': 'Glucose: 95 mg/dL'}]
    result = client.post('/report/reextract', json={'report': original})
    assert result.status_code == 400
    assert json.loads(original['parsed_data'])['lab_values'][0]['value'] == '145'
    original['review'] = {'confirmed': True}
    assert client.post('/report/reextract', json={'report': original}).status_code == 400


def test_source_evidence_does_not_fabricate_a_quote():
    result = attach_review(report(), "A heading without a source result")
    assert result["source_evidence"][0]["source_quote"] is None


def test_reviewed_flag_is_not_labelled_as_an_original_report_flag():
    original = report()
    rows = json.loads(original["parsed_data"])["lab_values"]
    rows[0].update(status="normal", flag_override=True)
    result = apply_review(original, rows, infer_status_from_reference, parse_numeric_value)
    assert json.loads(result["parsed_data"])["lab_values"][0]["status_source"] == "user_review"
    assert "You marked" in result["simple_explanation"]


def test_provider_failure_does_not_label_english_as_a_translation(monkeypatch):
    import agents
    monkeypatch.setattr(agents, "translate_all_with_claude", lambda fields, language: fields)
    result = agents.translate_agent({"target_language": "Hindi", "simplified_explanation": "English explanation.",
                                    "solution_plan_en": "Check the source.", "suggestions": []})
    assert result["translated_explanation"] == ""
    assert result["solution_plan_hi"] == ""


def test_review_and_question_endpoints_follow_corrected_evidence():
    import main
    from starlette.testclient import TestClient
    client = TestClient(main.app)
    original = report("high", "report")
    rows = json.loads(original["parsed_data"])["lab_values"]
    rows[0].update(value="95", reference_range="70-100")
    reviewed = client.post('/report/review', json={"report": original, "labs": rows, "language": "English"})
    assert reviewed.status_code == 200
    result = client.post('/report/question', json={"report": reviewed.json(), "question": "What does glucose mean?", "language": "English"})
    assert result.status_code == 200
    assert "95 mg/dL" in result.json()["answer"]
    assert "within" in result.json()["answer"]
    assert result.json()["sources"][0]["source_quote"] == "Glucose 145 mg/dL high"


def test_malformed_endpoint_requests_are_rejected():
    import main
    from starlette.testclient import TestClient
    client = TestClient(main.app)
    assert client.post('/report/review', json=[]).status_code == 400
    assert client.post('/report/question', json={"report": report(), "question": ""}).status_code == 400


def test_findings_are_not_duplicated_by_overlapping_keywords():
    from agents import extract_list
    assert extract_list('Clinical Findings: A reported observation.', ['Findings', 'Finding']) == ['A reported observation.']


def test_findings_only_report_can_answer_summary_without_inventing_labs():
    from test_fixtures.report_layout import build_report
    from digital_results import source_field
    from ocr import read_document
    with tempfile.TemporaryDirectory() as tmp:
        doc = read_document(build_report(Path(tmp) / 'notes.pdf', [], notes=['Findings: A reported observation.']))
    line = next(l for l in doc['pages'][0]['lines'] if l['text'].startswith('Findings:'))
    item = {'measurement_id': 'synthetic-note', 'record_type': 'narrative', 'section': 'findings',
            'text': 'A reported observation.', 'source_quote': line['text'],
            'source_fields': {'text': source_field(line['words'][1:], 1, 'native')}}
    result = answer_question({'extraction_version': 4, 'parsed_data': {'schema_version': 4, 'lab_values': [],
        'source_narratives': [item], 'document': {'pages': doc['pages']}},
        'extracted_text': doc['extracted_text']}, 'Summarise my report')
    assert result['supported']
    assert result['sources'][0]['source_quote'] == 'Findings: A reported observation.'
    assert 'Glucose' not in result['answer']


def test_source_fields_survive_multiple_reviews_without_overwriting_original():
    original = report('high', 'report')
    original = attach_review(original, original['extracted_text'])
    for value in ('95', '102'):
        rows = json.loads(original['parsed_data'])['lab_values']
        rows[0].update(value=value, reference_range='70-100')
        original = apply_review(original, rows, infer_status_from_reference, parse_numeric_value)
    source = original['source_evidence'][0]
    assert source['original_fields']['value'] == '145'
    assert source['source_quote'] == 'Glucose 145 mg/dL high'
    assert json.loads(original['parsed_data'])['lab_values'][0]['value'] == '102'


def test_similar_number_is_not_evidence_for_the_extracted_value():
    value = report()
    value['parsed_data'] = {'lab_values':[{'test_name':'Creatinine','value':'1.8'}]}
    result = attach_review(value, 'Creatinine: 11.8 mg/dL')
    assert result['source_evidence'][0]['source_quote'] is None
    assert result['source_evidence'][0]['original_fields'] is None


@pytest.mark.parametrize('reference', ['', '70-200'])
def test_confirmed_flag_override_replaces_ocr_flag_but_keeps_original(reference):
    from report_quality import validate_document
    original = report('high', 'report')
    parsed = json.loads(original['parsed_data'])
    row = parsed['lab_values'][0]
    row['source_fields']['flag']['method'] = 'ocr'
    if reference:
        row['reference_range'] = reference
        row['source_fields']['reference_range'] = {
            **row['source_fields']['value'], 'text': reference, 'method': 'native'}
    parsed['lab_values'], _ = validate_document({'candidates': [row]})
    original['parsed_data'] = json.dumps(parsed)
    rows = json.loads(original['parsed_data'])['lab_values']
    rows[0].update(status='normal', flag_override=True)
    result = apply_review(original, rows, infer_status_from_reference, parse_numeric_value)
    checked = json.loads(result['parsed_data'])['lab_values'][0]
    assert checked['status'] == 'normal' and checked['status_source'] == 'user_review'
    assert checked['acceptance_state'] == 'eligible'
    assert checked['source_fields']['flag']['text'] == 'high'
    assert checked['corrections']['status']['value'] == 'normal'


def test_override_conflicting_with_applicable_range_still_needs_review():
    from report_quality import validate_document
    original = report('high', 'report')
    parsed = json.loads(original['parsed_data'])
    row = parsed['lab_values'][0]
    row['reference_range'] = '70-100'
    row['source_fields']['reference_range'] = {**row['source_fields']['value'], 'text': '70-100'}
    parsed['lab_values'], _ = validate_document({'candidates': [row]})
    original['parsed_data'] = json.dumps(parsed)
    rows = json.loads(original['parsed_data'])['lab_values']
    rows[0].update(status='normal', flag_override=True)
    checked = json.loads(apply_review(original, rows, infer_status_from_reference, parse_numeric_value)['parsed_data'])['lab_values'][0]
    assert checked['acceptance_state'] == 'needs_review'
    assert any(i['code'] == 'flag_range_conflict' for i in checked['issues'])


@pytest.mark.parametrize('section', ['Findings', 'Diagnosis', 'Impression'])
def test_source_backed_narrative_survives_summary_and_unchecked_ocr_does_not(tmp_path, section):
    from agents import parse_agent
    from report_review import content
    from ocr import read_document
    from test_fixtures.report_layout import build_report
    doc = read_document(build_report(tmp_path / 'note.pdf', [], notes=[f'{section}: Follow-up imaging advised']))
    parsed = json.loads(parse_agent({}, document=doc)['parsed_data'])
    output = content(parsed)
    assert 'Follow-up imaging advised' in output['simple_explanation']
    assert 'Follow-up imaging advised' in output['medical_summary']
    parsed['source_narratives'][0]['source_fields']['text']['method'] = 'ocr'
    assert 'Follow-up imaging advised' not in content(parsed)['simple_explanation']
