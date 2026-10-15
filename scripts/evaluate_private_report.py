"""Evaluate AFTER extraction. Private evidence must be written outside Git."""
import argparse
import json
import re
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path
from time import perf_counter

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from ocr import read_document
from digital_results import extract_digital_results
from report_quality import validate_document


def normalized(value):
    return re.sub(r'\s+', '', str(value)).casefold().replace('µ', 'u').replace('μ', 'u').replace('–', '-').replace('−', '-')


def same_value(a, b):
    try:
        return Decimal(str(a)) == Decimal(str(b))
    except InvalidOperation:
        return normalized(a) == normalized(b)


def evaluate(source, expected_path, output, docling_python=None, api=False):
    target = Path(output).resolve()
    repo = Path(__file__).resolve().parents[1]
    if target.is_relative_to(repo):
        raise ValueError('Write private evaluation evidence outside the repository.')
    target.parent.mkdir(parents=True, exist_ok=True)
    start = perf_counter()
    document = read_document(str(source))
    rows, issues = extract_digital_results(document['pages'], document['source_digest'])
    document['candidates'] = rows
    document['diagnostics'].extend(issues)
    if docling_python:
        from docling_worker import DoclingWorker
        from docling_adapter import extract_docling_results, reconcile_measurements
        worker = DoclingWorker(python=docling_python)
        try:
            native = worker.convert(str(source), [p['page'] for p in document['pages']])
            extra, diagnostics = extract_docling_results(native, document['source_digest'])
            document['candidates'] = reconcile_measurements(rows, extra)
            document['diagnostics'].extend(diagnostics)
        finally:
            worker.close()
    rows, quality = validate_document(document)
    if api:
        from starlette.testclient import TestClient
        import main
        reply = TestClient(main.app).post('/upload', files={'file': (source.name, source.read_bytes())}, data={'language': 'English'})
        job_id = reply.json()['job_id']
        job = main.processing_jobs.pop(job_id)
        if job['status'] != 'completed':
            raise RuntimeError('API processing failed')
        response = job['result']
        rows = json.loads(response['parsed_data'])['lab_values']
        quality = response['extraction_quality']
        Path(output).with_name('api-response.json').write_text(json.dumps(response, ensure_ascii=False))
    # Expected data is never available to either extractor or the validation policy.
    expected = json.loads(Path(expected_path).read_text())
    matched, extras = {}, []
    for row in rows:
        found = next((i for i, e in enumerate(expected)
                      if row['source_fields']['value']['page'] == e['pdf_page']
                      and normalized(row['test_name']) == normalized(e['test_name'])
                      and same_value(row['value'], e['value'])
                      and normalized(row['unit']) == normalized(e['unit'])), None)
        if found is None:
            extras.append(row)
        else:
            matched.setdefault(found, []).append(row)
    refs = sum(any(normalized(r['reference_range']) == normalized(expected[i]['reference_range'])
                   for r in rs) for i, rs in matched.items())
    result = {'expected': len(expected), 'extracted': len(rows), 'correct_core': len(matched),
              'complete_references': refs, 'extra_or_incorrect': len(extras),
              'duplicates': sum(len(rs) - 1 for rs in matched.values()), 'quality': quality,
              'sample_dates': sorted({r.get('sample_date') or 'unknown' for r in rows}),
              'seconds': perf_counter() - start, 'missing': [e for i, e in enumerate(expected) if i not in matched],
              'extras': extras, 'rows': rows,
              'reference_mismatches': [{'expected': expected[i], 'actual': rs[0]['reference_range']}
                                       for i, rs in matched.items() if not any(normalized(r['reference_range']) == normalized(expected[i]['reference_range']) for r in rs)]}
    target.write_text(json.dumps(result, indent=2, ensure_ascii=False))
    print(json.dumps({key: result[key] for key in ['expected', 'extracted', 'correct_core', 'complete_references',
                                                    'extra_or_incorrect', 'duplicates', 'quality', 'sample_dates', 'seconds']}))
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--expected', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--docling-python')
    p.add_argument('--api', action='store_true')
    a = p.parse_args()
    result = evaluate(a.source, a.expected, a.output, a.docling_python, a.api)
    passed = (result['correct_core'] == result['expected'] == result['extracted']
              and result['complete_references'] == result['expected'] and result['extra_or_incorrect'] == 0
              and result['duplicates'] == 0 and result['quality']['eligible_count'] == result['expected'])
    sys.exit(0 if passed else 1)
