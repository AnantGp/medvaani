"""The AI layout reader may only choose text that is printed on the page."""
import asyncio
import json
import re
from pathlib import Path

import pytest

from ai_rows import decimal_comma_document, read_rows, rows_from_model
from ocr import read_document
from report_quality import flag_status, validate_document

ROOT = Path(__file__).resolve().parents[1]
SHAMI = ROOT / 'test_data' / 'shami' / 'shami_synthetic_report.pdf'


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
    truth = json.loads((ROOT / 'test_data' / 'shami' / 'truth.json').read_text())['shami_synthetic_report.pdf']
    truth = [t for t in truth if not t.get('optional')]
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


def test_unit_glued_to_the_value_is_separated():
    page = _page([[('Haematocrit', .05), ('41.2%', .4), ('40–50%', .6)]])
    rows, problems = rows_from_model([
        {'line': 'p1.L1', 'test_name': 'Haematocrit', 'value': '41.2%', 'reference_range': '40–50%'}], page, 'd')
    assert not problems and rows[0]['value'] == '41.2' and rows[0]['unit'] == '%'


def test_transient_ai_failures_are_retried():
    calls = []

    async def flaky(messages, **_):
        calls.append(1)
        if len(calls) < 3:
            raise RuntimeError('temporarily unavailable')
        return {'rows': [{'line': 'p1.L1', 'test_name': 'Haemoglobin', 'value': '13.6', 'unit': 'g/dL'}]}, 'm'
    import ai_rows
    ai_rows.RETRY_WAITS = (0, 0, 0)
    rows, _ = asyncio.run(ai_rows.read_rows(PAGE, 'd', chat=flaky))
    assert len(calls) == 3 and rows[0]['value'] == '13.6'


def test_rows_the_model_skipped_are_recovered_from_the_same_columns():
    """The model stopped two lines early on a Korean table; the page still has them."""
    from pathlib import Path
    from ocr import read_document
    from ai_rows import recover_sibling_rows
    doc = read_document(str(Path(__file__).parent.parent / 'test_data/world/KR_korea.pdf'))
    pages = doc['pages']
    lines = pages[0]['lines']
    items = []
    for number, line in enumerate(lines, 1):
        words = [w['text'] for w in line['words']]
        if len(words) < 4 or not re.fullmatch(r'\d+(?:\.\d+)?', words[1]) or words[0] in {'AST', 'ALT'}:
            continue
        flag = words[2] if words[2] in {'H', 'L'} else ''
        rest = words[3:] if flag else words[2:]
        items.append({'line': f'p1.L{number}', 'test_name': words[0], 'value': words[1], 'flag': flag,
                      'flag_meaning': {'H': 'high', 'L': 'low'}.get(flag, ''),
                      'unit': rest[0], 'reference_range': rest[1]})
    rows, _ = rows_from_model(items, pages, 'd')
    assert len(rows) == 8 and not {'AST', 'ALT'} & {r['test_name'] for r in rows}
    extra = recover_sibling_rows(rows, pages, 'd')
    assert [(r['test_name'], r['value'], r['unit'], r['reference_range']) for r in extra] == [
        ('AST', '21', 'IU/L', '0~32'), ('ALT', '19', 'IU/L', '0~33')]
    # Headers, patient details and the footer are never turned into results.
    assert all(r['source_fields']['value']['text'] == r['value'] for r in extra)


def test_sibling_recovery_needs_three_agreeing_rows():
    from ai_rows import recover_sibling_rows
    assert recover_sibling_rows([], [{'page': 1, 'lines': []}], 'd') == []
