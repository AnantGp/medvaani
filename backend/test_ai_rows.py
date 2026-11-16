"""The AI layout reader may only choose text that is printed on the page."""
import asyncio
import json
from pathlib import Path

import pytest

from ai_rows import decimal_comma_document, read_rows, rows_from_model
from ocr import read_document
from report_quality import flag_status, validate_document

ROOT = Path(__file__).resolve().parents[1]
SHAMI = ROOT / 'test_data' / 'shami_synthetic_report.pdf'


def _page(lines):
    """A one-page document from (text, x) word tuples per line."""
    out = []
    for n, words in enumerate(lines):
        ws = [{'text': t, 'x': x, 'y': .1 + n * .03, 'width': .05, 'height': .01} for t, x in words]
        out.append({'page': 1, 'text': ' '.join(t for t, _ in words), 'box': [.05, .1 + n * .03, .9, .01],
                    'words': ws, 'method': 'native'})
    return [{'page': 1, 'width': 600, 'height': 800, 'words': [w for l in out for w in l['words']],
             'lines': out, 'regions': []}]


PAGE = _page([
    [('Haemoglobin', .05), ('13.6', .4), ('g/dL', .48), ('13.0–17.0', .6)],
    [('HbA1c', .05), ('17.8', .4), ('%', .48), ('<5.7', .6)],
])


def test_value_not_printed_is_rejected():
    rows, problems = rows_from_model([
        {'line': 'p1.L1', 'test_name': 'Haemoglobin', 'value': '13.9', 'unit': 'g/dL'}], PAGE, 'd')
    assert rows == [] and problems[0]['code'] == 'ai_value_not_on_page'


def test_invented_test_is_rejected():
    rows, problems = rows_from_model([
        {'line': 'p1.L1', 'test_name': 'Ferritin', 'value': '13.6', 'unit': 'g/dL'}], PAGE, 'd')
    assert rows == [] and problems[0]['code'] == 'ai_name_not_on_page'


def test_number_must_stand_alone():
    rows, _ = rows_from_model([
        {'line': 'p1.L2', 'test_name': 'HbA1c', 'value': '7.8', 'unit': '%'}], PAGE, 'd')
    assert rows == []


def test_fields_come_from_page_words_not_the_model():
    rows, _ = rows_from_model([
        {'line': 'p1.L1', 'test_name': 'HAEMOGLOBIN', 'value': '13.6', 'unit': 'g/dl',
         'reference_range': '13.0–17.0'}], PAGE, 'd')
    row = rows[0]
    assert row['test_name'] == 'Haemoglobin'          # printed spelling, not the model's
    assert row['unit'] == 'g/dL'
    assert row['source_fields']['value']['box'][0] == pytest.approx(.4)


def test_unknown_line_is_rejected():
    rows, problems = rows_from_model([{'line': 'p9.L1', 'test_name': 'x', 'value': '1'}], PAGE, 'd')
    assert rows == [] and problems[0]['code'] == 'ai_row_unlocated'


@pytest.mark.parametrize('text,expected', [
    ('H', 'high'), ('↓', 'low'), ('Within range', 'normal'), ('Borderline high', 'high'),
    ('Slightly low', 'low'), ('Prediabetes range', 'high'), ('erhöht', 'high'), ('偏低', 'low'),
    ('Desirable', 'normal'), ('', None)])
def test_printed_flags_in_several_languages(text, expected):
    assert flag_status(text) == expected


def test_decimal_comma_detection():
    assert decimal_comma_document([{'value': '5,8', 'reference_range': '4,0 - 5,6'}])
    assert not decimal_comma_document([{'value': '7,200', 'reference_range': '4,000 - 11,000'}])
    assert not decimal_comma_document([{'value': '5.8', 'reference_range': '4,0 - 5,6'}])


@pytest.mark.skipif(not SHAMI.exists(), reason='fixture missing')
def test_shami_report_with_a_perfect_reader_is_fully_grounded():
    """Given correct choices, every Shami result is located and labelled correctly."""
    truth = json.loads((ROOT / 'test_data' / 'shami_truth.json').read_text())['shami_synthetic_report.pdf']
    doc = read_document(str(SHAMI))
    lines = {l['text']: f"p{p['page']}.L{i}" for p in doc['pages'] for i, l in enumerate(p['lines'], 1) if l['words']}
    flags = ['Within range', 'Above normal range', 'Prediabetes range', 'Desirable', 'Above optimal',
             'Slightly low', 'Borderline high', 'Above goal']
    items = []
    for t in truth:
        if t['name'] in ('MCV', 'MCH', 'MCHC'):
            text = next(tx for tx in lines if tx.startswith('MCV /'))
        else:
            text = next(tx for tx in lines if tx.startswith(t['name'].split()[0])
                        and f" {t['value']}" in f' {tx}')
        items.append({'line': lines[text], 'test_name': t['name'], 'value': t['value'], 'unit': t['unit'],
                      'reference_range': t['reference'], 'flag': next((f for f in flags if text.endswith(f)), '')})

    async def perfect(messages, **_):
        return {'rows': items}, 'test'
    rows, problems = asyncio.run(read_rows(doc['pages'], doc['source_digest'], chat=perfect))
    assert not problems and len(rows) == len(truth)
    doc['candidates'] = rows
    measurements, quality = validate_document(doc)
    by_name = {m['test_name']: m for m in measurements}
    for t in truth:
        assert by_name[t['name']]['value'] == t['value']
        assert by_name[t['name']]['status'] == t['status'], t['name']
