import copy
import importlib
import importlib.util
from report_quality import validate_document
from test_report_quality import sample_measurement, document


def adapter():
    assert importlib.util.find_spec('docling_adapter') is not None, 'Structured Docling adapter is missing'
    return importlib.import_module('docling_adapter')


def table_document(rows, *, header=True):
    all_rows = ([['Test Name', 'Value', 'Unit', 'Bio. Ref Interval']] if header else []) + rows
    grid = []
    for ri, row in enumerate(all_rows):
        grid.append([{'text': text, 'bbox': {'l': x, 't': 240 + ri * 20, 'r': x + width, 'b': 255 + ri * 20,
                                          'coord_origin': 'TOPLEFT'},
                     'start_row_offset_idx': ri, 'end_row_offset_idx': ri + 1,
                     'start_col_offset_idx': ci, 'end_col_offset_idx': ci + 1}
                    for ci, (text, x, width) in enumerate(zip(row, [36, 258, 360, 456], [180, 54, 60, 108]))])
    return {'pages': {'1': {'size': {'width': 600, 'height': 800}}}, 'texts': [],
            'tables': [{'prov': [{'page_no': 1, 'bbox': {'l': 36, 't': 240, 'r': 564, 'b': 400, 'coord_origin': 'TOPLEFT'}}],
                        'data': {'num_cols': 4, 'num_rows': len(grid), 'grid': grid}}]}


def test_multiline_reference_is_preserved_from_docling_json():
    reference = 'Desirable : <150\nBorderline high : 150-199\nHigh : 200-499'
    rows, _ = adapter().extract_docling_results(table_document([['Triglycerides Method: Laboratory', '160', 'mg/dL', reference]]), 'synthetic')
    assert rows[0]['test_name'] == 'Triglycerides'
    assert rows[0]['reference_range'] == reference
    assert rows[0]['source_fields']['reference_range']['page'] == 1


def test_headerless_table_needs_source_header_association():
    rows, diagnostics = adapter().extract_docling_results(table_document([['Creatinine', '0.8', 'mg/dL', '0.5-1.2']], header=False), 'synthetic')
    assert rows == [] and any(d['code'] == 'unparsed_table' for d in diagnostics)


def test_machine_prefix_does_not_shift_cbc_measurement():
    rows, _ = adapter().extract_docling_results(table_document([['Machine: Analyser Lymphocytes Method: VCS', '35', '%', '20-40']]), 'synthetic')
    checked, _ = validate_document(document(*rows))
    assert checked[0]['acceptance_state'] == 'needs_review'
    assert any(i['code'] == 'identity_contaminated' for i in checked[0]['issues'])


def test_split_urine_value_and_unit_is_uncertain_until_geometry_resolves_it():
    rows, diagnostics = adapter().extract_docling_results(table_document([['Pus Cells', '/HPF', '', ''], ['', '1-2', '', '0-5']]), 'synthetic')
    assert rows == []
    assert any(d['code'] == 'unresolved_result_region' for d in diagnostics)


def test_guideline_table_is_rejected():
    doc = table_document([['High risk group', '70', '100', '80']])
    doc['tables'][0]['data']['grid'][0] = [dict(c, text=t) for c, t in zip(doc['tables'][0]['data']['grid'][0], ['Risk group', 'LDL target', 'Non-HDL target', 'Apo-B target'])]
    assert adapter().extract_docling_results(doc, 'synthetic')[0] == []


def test_conflicting_unit_is_quarantined():
    native = sample_measurement()
    other = copy.deepcopy(native)
    other['unit'] = 'mmol/L'
    other['source_fields']['unit']['text'] = 'mmol/L'
    rows = adapter().reconcile_measurements([native], [other])
    checked, _ = validate_document(document(*rows))
    assert checked[0]['acceptance_state'] == 'needs_review'
    assert any(i['code'] == 'engine_conflict' and i['field'] == 'unit' for i in checked[0]['issues'])


def test_guideline_rows_inside_clinical_headers_stay_out_of_reconciliation():
    rows, diagnostics = adapter().extract_docling_results(table_document([
        ['High risk group', '70', 'mg/dL', '<100'],
        ['Booking ID', '20259620364', '', ''],
        ['Creatinine', '0.8', 'mg/dL', '0.5-1.2']]), 'synthetic')
    combined = adapter().reconcile_measurements([], rows)
    checked, quality = validate_document(document(*combined, diagnostics=diagnostics))
    assert [r['test_name'] for r in checked] == ['Creatinine']
    assert quality['eligible_count'] == 1
    assert sum(d['code'] == 'nonmeasurement_row' for d in diagnostics) == 2


def test_docling_historical_table_is_not_a_current_result():
    doc = table_document([['Creatinine', '8.8', 'mg/dL', '0.5-1.2']])
    doc['texts'] = [{'text': 'Historical results 2024', 'prov': [{'page_no': 1,
        'bbox': {'l': 36, 't': 180, 'r': 200, 'b': 200, 'coord_origin': 'TOPLEFT'}}]}]
    rows, diagnostics = adapter().extract_docling_results(doc, 'synthetic')
    assert rows == []
    assert any(d.get('record_type') == 'historical' for d in diagnostics)


def test_reconciliation_does_not_promote_nonmeasurement_records():
    extra = sample_measurement()
    extra['record_type'] = 'guideline'
    assert adapter().reconcile_measurements([], [extra]) == []
