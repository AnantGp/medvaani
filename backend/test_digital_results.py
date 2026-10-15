import importlib
import importlib.util
from ocr import read_document
from test_fixtures.report_layout import build_report


def extract(path):
    assert importlib.util.find_spec('digital_results') is not None, 'Coordinate result extraction is missing'
    adapter = importlib.import_module('digital_results')
    document = read_document(path)
    rows, diagnostics = adapter.extract_digital_results(document['pages'], document['source_digest'])
    return rows, diagnostics


def test_single_result_panel_is_a_measurement(tmp_path):
    rows, _ = extract(build_report(tmp_path / 'single.pdf', [('Creatinine', '0.8', 'mg/dL', '0.5-1.2')]))
    assert len(rows) == 1
    assert rows[0]['test_name'] == 'Creatinine' and rows[0]['value'] == '0.8'
    assert all(rows[0]['source_fields'][f]['box'] for f in ['test_name', 'value', 'unit', 'reference_range'])


def test_multiline_lipid_reference_stays_one_field(tmp_path):
    reference = 'Desirable : <150\nBorderline high : 150-199\nHigh : 200-499\nVery high : >500'
    rows, _ = extract(build_report(tmp_path / 'lipids.pdf', [('Triglycerides', '160.0', 'mg/dL', reference)]))
    assert rows[0]['reference_range'] == reference
    assert len(rows[0]['source_fields']['reference_range']['boxes']) == 4


def test_guideline_beside_results_is_not_a_measurement(tmp_path):
    rows, diagnostics = extract(build_report(tmp_path / 'guidelines.pdf', [('Creatinine', '0.8', 'mg/dL', '0.5-1.2')], guidelines=True))
    assert [r['test_name'] for r in rows] == ['Creatinine']
    assert any(d.get('code') == 'nonmeasurement_row' for d in diagnostics)


def test_qualitative_and_interval_urine_values_keep_units(tmp_path):
    data = [('Glucose', 'Negative', '', 'Negative'), ('Pus Cells', '1-2', '/HPF', '0-5'),
            ('Colour', 'Pale Yellow', '', 'Pale Yellow')]
    rows, _ = extract(build_report(tmp_path / 'urine.pdf', data))
    assert [(r['test_name'], r['value'], r['unit']) for r in rows] == [(n, v, u) for n, v, u, _ in data]


def test_machine_method_metadata_never_becomes_test_name(tmp_path):
    rows, _ = extract(build_report(tmp_path / 'methods.pdf', [('Hemoglobin', '14.2', 'g/dL', '13-17'), ('Platelets', '240', '10^3/uL', '150-410')]))
    assert [r['test_name'] for r in rows] == ['Hemoglobin', 'Platelets']


def test_history_columns_do_not_replace_current_result(tmp_path):
    rows, _ = extract(build_report(tmp_path / 'history.pdf', [('Creatinine', '0.8', 'mg/dL', '0.5-1.2')], history=True))
    assert len(rows) == 1 and rows[0]['value'] == '0.8'
    assert rows[0]['sample_date'] == '2026-01-14'
    assert rows[0]['source_fields']['value']['page'] == 2


def test_footer_in_reference_column_is_not_part_of_reference(tmp_path):
    rows, _ = extract(build_report(tmp_path / 'footer.pdf', [('Creatinine', '0.8', 'mg/dL', '0.5-1.2')], footer=True))
    assert rows[0]['reference_range'] == '0.5-1.2'


def test_supported_document_profile_excludes_guidelines_when_brand_is_on_cover(tmp_path):
    rows, diagnostics = extract(build_report(tmp_path / 'cover.pdf', [('Creatinine', '0.8', 'mg/dL', '0.5-1.2')],
        history=True, brand_first_page_only=True, guidelines=True))
    assert len(rows) == 1
    assert not any(d['code'] == 'unsupported_layout' for d in diagnostics)


def test_reference_interval_wrapping_onto_next_line_is_preserved(tmp_path):
    reference = 'Optimal : <100\nnear /above Optimal:100 -\n129\nHigh : 160 - 189'
    rows, _ = extract(build_report(tmp_path / 'wrapped-range.pdf', [('LDL Cholesterol', '92.0', 'mg/dL', reference)]))
    assert rows[0]['reference_range'] == reference


def test_unknown_provider_guideline_identity_is_never_a_patient_measurement(tmp_path):
    rows, _ = extract(build_report(tmp_path / 'unknown.pdf', [('Creatinine', '0.9', 'mg/dL', '0.6-1.2')], provider='Example Laboratory', guidelines=True))
    assert [r['test_name'] for r in rows] == ['Creatinine']


def test_printed_flag_has_its_own_source_field(tmp_path):
    from report_quality import validate_document
    path = build_report(tmp_path / 'flag.pdf', [('Glucose', '145', 'mg/dL', '')], flags={'Glucose': 'High'})
    document = read_document(path)
    rows, _ = importlib.import_module('digital_results').extract_digital_results(document['pages'], document['source_digest'])
    checked, _ = validate_document({**document, 'candidates': rows})
    assert checked[0]['source_fields']['flag']['text'] == 'High'
    assert checked[0]['status'] == 'high'
    assert checked[0]['status_source'] == 'report'


def test_printed_flag_does_not_contaminate_reference_and_conflict_needs_review(tmp_path):
    from report_quality import validate_document
    rows, _ = extract(build_report(tmp_path / 'conflict.pdf', [('Glucose', '145', 'mg/dL', '70-100')], flags={'Glucose': 'Normal'}))
    checked, _ = validate_document({'candidates': rows})
    assert checked[0]['reference_range'] == '70-100'
    assert checked[0]['acceptance_state'] == 'needs_review'


def test_numbered_interpretation_prose_before_a_method_is_not_a_result(tmp_path):
    path = build_report(tmp_path / 'notes.pdf', [('7. See result notes', 'do not', 'use in', 'diagnosis'), ('Glucose', '95', 'mg/dL', '70-100')])
    rows, _ = extract(path)
    assert [r['test_name'] for r in rows] == ['Glucose']


def test_multiword_unreadable_patient_value_remains_visible_for_review(tmp_path):
    from report_quality import validate_document
    rows, diagnostics = extract(build_report(tmp_path / 'unreadable.pdf', [
        ('Creatinine', '0.9', 'mg/dL', '0.6-1.2'),
        ('Glucose', 'Unable to assay', 'mg/dL', '70-100')]))
    checked, quality = validate_document({'candidates': rows, 'diagnostics': diagnostics})
    assert len(checked) == 2
    assert quality['state'] == 'partial' and quality['needs_review_count'] == 1
    assert checked[1]['value'] == 'Unable to assay'
    assert checked[1]['source_fields']['value']['text'] == 'Unable to assay'


def test_colon_history_is_excluded_while_current_table_date_is_retained(tmp_path):
    from pypdf import PdfReader, PdfWriter
    from reportlab.pdfgen import canvas
    from report_quality import validate_document
    old = tmp_path / 'old.pdf'
    c = canvas.Canvas(str(old), pagesize=(600, 800))
    c.drawString(40, 740, 'Healthians Labs')
    c.drawString(40, 700, 'Historical summary 2024 / 2025')
    c.drawString(40, 660, 'Creatinine: 8.8 mg/dL')
    c.save()
    current = build_report(tmp_path / 'current.pdf', [('Creatinine', '0.8', 'mg/dL', '0.5-1.2')])
    writer = PdfWriter()
    for filename in (old, current):
        writer.append(PdfReader(filename))
    combined = tmp_path / 'combined.pdf'
    writer.write(combined)
    rows, diagnostics = extract(combined)
    checked, quality = validate_document({'candidates': rows, 'diagnostics': diagnostics})
    assert [r['value'] for r in checked] == ['0.8']
    assert checked[0]['sample_date'] == '2026-01-14'
    assert checked[0]['source_fields']['value']['page'] == 2
    assert quality['eligible_count'] == 1
    assert any(d.get('record_type') == 'historical' for d in diagnostics)


def test_named_line_without_current_result_context_is_explicitly_unresolved(tmp_path):
    from reportlab.pdfgen import canvas
    c = canvas.Canvas(str(tmp_path / 'ambiguous.pdf'))
    c.drawString(40, 700, 'Creatinine: 8.8 mg/dL')
    c.save()
    rows, diagnostics = extract(tmp_path / 'ambiguous.pdf')
    assert rows == []
    assert any(d['code'] == 'unresolved_result_region' for d in diagnostics)


def test_exported_summary_continues_results_and_references_across_pages(tmp_path):
    from reportlab.pdfgen import canvas
    from report_quality import validate_document
    p = tmp_path / 'summary.pdf'
    c = canvas.Canvas(str(p), pagesize=(600, 800))
    c.setFont('Helvetica', 9)
    for y, text in [(750, 'Medical Report Summary'), (730, '2 usable measurements'),
                    (700, 'Results in this report'), (650, 'Triglycerides: 158.0 mg/dL'),
                    (625, 'Reference range: Desirable: <150')]:
        c.drawString(40, y, text)
    c.showPage(); c.setFont('Helvetica', 9)
    for y, text in [(750, 'Medical Report Summary'), (710, 'Borderline high: 150-199 High: 200-499'),
                    (690, 'Comparison unavailable from the supplied reference.'),
                    (650, 'Serum HDL Cholesterol: 38.5 mg/dL'), (625, 'Reference range: 40 - 60'),
                    (600, 'Report flag or supplied-range comparison: low')]:
        c.drawString(40, y, text)
    c.save()
    document = read_document(str(p))
    rows, diagnostics = importlib.import_module('digital_results').extract_digital_results(document['pages'], document['source_digest'])
    checked, quality = validate_document({**document, 'candidates': rows, 'diagnostics': diagnostics})
    assert len(checked) == 2
    assert checked[1]['test_name'] == 'Serum HDL Cholesterol'
    assert checked[1]['reference_range'] == '40 - 60'
    assert checked[1]['status'] == 'low'
    assert checked[1]['source_fields']['value']['page'] == 2
    assert checked[0]['reference_range'] == 'Desirable: <150\nBorderline high: 150-199 High: 200-499'
    assert [f['page'] for f in checked[0]['source_fields']['reference_range']['fragments']] == [1, 2]
    assert quality['eligible_count'] == 2


def test_declared_summary_count_cannot_hide_missing_measurements(tmp_path):
    from reportlab.pdfgen import canvas
    from report_quality import validate_document
    p = tmp_path / 'partial-summary.pdf'; c = canvas.Canvas(str(p))
    for y, text in [(740, 'Medical Report Summary'), (710, '3 usable measurements'),
                    (680, 'Results in this report'), (650, 'Glucose: 95 mg/dL'),
                    (625, 'Reference range: 70 - 100')]:
        c.drawString(40, y, text)
    c.save()
    doc = read_document(str(p))
    rows, diagnostics = importlib.import_module('digital_results').extract_digital_results(doc['pages'], doc['source_digest'])
    _, quality = validate_document({**doc, 'candidates': rows, 'diagnostics': diagnostics})
    assert quality['state'] == 'partial'
    assert quality['expected_measurement_count'] == 3
    assert quality['missing_measurement_count'] == 2


def test_summary_reference_categories_are_not_patient_measurements(tmp_path):
    from reportlab.pdfgen import canvas
    p = tmp_path / 'categories.pdf'
    c = canvas.Canvas(str(p))
    for y, text in [(740, 'Medical Report Summary'), (710, 'Results in this report'),
                    (680, 'Vitamin D: 25 ng/mL'), (650, 'Reference range: Deficient: <20'),
                    (625, 'Insufficient: 20-29'), (600, 'Sufficient: 30-100')]:
        c.drawString(40, y, text)
    c.save()
    rows, _ = extract(p)
    assert len(rows) == 1
    assert rows[0]['reference_range'] == 'Deficient: <20\nInsufficient: 20-29\nSufficient: 30-100'


def test_summary_reference_stops_before_numeric_followup_prose(tmp_path):
    from reportlab.pdfgen import canvas
    for end in ['Report flag or supplied-range comparison: normal', 'Comparison unavailable from the supplied reference.']:
        p = tmp_path / 'follow-up.pdf'
        c = canvas.Canvas(str(p))
        for y, text in [(740, 'Medical Report Summary'), (710, 'Results in this report'),
                        (680, 'Glucose: 95 mg/dL'), (650, 'Reference range: 70 - 100'),
                        (625, end), (600, 'Please repeat testing in 3 months.')]:
            c.drawString(40, y, text)
        c.save()
        rows, _ = extract(p)
        assert len(rows) == 1
        assert rows[0]['reference_range'] == '70 - 100'
