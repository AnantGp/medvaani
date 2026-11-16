"""Accuracy evaluation against a deployed Medivaanii (synthetic, fictional reports only).

Modes (EVAL_MODE): 'pdf' uploads every PDF and asks questions on four of them;
'photo' uploads rendered photos. Each mode writes:
  out/raw/<mode>/...json   every raw API response, unedited
  out/<mode>.json          per-item scores and errors
The separate check_thresholds.py decides pass/fail.
"""
import io, json, os, sys, time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).parent))
from scoring import (answer_direction, answer_is_safe_on_treatment, answer_lists_abnormal,
                     answer_says_absent, answer_states_value, score_report)

base = sys.argv[1].rstrip('/')
sets = [Path(p) for p in sys.argv[2:]]
MODE = os.environ.get('EVAL_MODE', 'pdf')
OUT = Path('out'); RAW = OUT / 'raw' / MODE
RAW.mkdir(parents=True, exist_ok=True)

truth = {}
for s in sets:
    for k, v in json.loads((s / 'truth.json').read_text()).items():
        truth[str(s / k)] = v

QA_SET = ('shami_synthetic_report.pdf', 'CN_china.pdf', 'ES_spain.pdf', 'US_usa.pdf', 'DE_germany.pdf')
PHOTO_SET = ('A_testname_value_unit_bioref_0.pdf', 'B_investigation_observed_0.pdf',
             'C_test_result_units_range_flag_0.pdf', 'D_parameter_result_normal_0.pdf',
             'F_patient_block_sections_0.pdf', 'I_messy_wide.pdf')


def save(name, payload):
    (RAW / name).write_text(json.dumps(payload, indent=1, ensure_ascii=False, default=str))


def upload(name, data, mime):
    """Returns (report, error, raw_log). Waits out quota errors; records every attempt."""
    log = []
    for attempt in range(5):
        try:
            r = requests.post(f'{base}/api/upload', files={'file': (name, data, mime)},
                              data={'language': 'English'}, timeout=300)
            try:
                body = r.json()
            except ValueError:
                body = {'non_json': r.text[:2000]}
            log.append({'attempt': attempt, 'status': r.status_code, 'body': body})
            if r.status_code != 200:
                if r.status_code in (429, 502, 503, 504) or 'quota' in json.dumps(body).casefold():
                    time.sleep(90)
                    continue
                return None, f'HTTP {r.status_code}: {json.dumps(body)[:300]}', log
            if body.get('job_id'):
                for _ in range(100):
                    time.sleep(3)
                    job = requests.get(f'{base}/api/job/{body["job_id"]}', timeout=30).json()
                    if job.get('status') == 'completed':
                        log.append({'job': 'completed'})
                        return job['result'], None, log
                    if job.get('status') == 'failed':
                        log.append({'job': job})
                        return None, f"job failed: {str(job.get('error'))[:300]}", log
                return None, 'job timeout', log
            return body, None, log
        except Exception as e:  # network errors are recorded, not hidden
            log.append({'attempt': attempt, 'exception': repr(e)[:500]})
            time.sleep(10)
    return None, 'gave up after retries (quota or network)', log


def rows_of(report):
    if not report:
        return []
    parsed = report.get('parsed_data')
    if isinstance(parsed, str):
        parsed = json.loads(parsed)
    return (parsed or {}).get('lab_values', [])


def evaluate_upload(key, path, data, mime, expected):
    report, err, log = upload(Path(key).name, data, mime)
    save(f'{Path(key).stem}.upload.json', {'error': err, 'attempts': log, 'result': report})
    quality = (report or {}).get('extraction_quality', {})
    if report is None:
        return {'item': key, 'outcome': 'service_error', 'error': err,
                'expected': len(expected)}, None
    res, errors = score_report(expected, rows_of(report))
    parsed = report.get('parsed_data')
    parsed = json.loads(parsed) if isinstance(parsed, str) else (parsed or {})
    diagnostics = [d.get('code', '') + (': ' + str(d['detail'])[:120] if d.get('detail') else '')
                   for d in (parsed.get('document') or {}).get('diagnostics', [])]
    return {'item': key, 'outcome': 'scored', 'state': quality.get('state'), **res,
            'errors': errors, 'diagnostics': diagnostics[:8]}, report


def ask(report, text, lang):
    sync = requests.post(f'{base}/api/report/sync', json={'report': report}, timeout=60)
    rid = sync.json().get('report_id') if sync.ok else None
    attempts = []
    for attempt in range(4):
        r = requests.post(f'{base}/api/voice/turn', timeout=360, json={
            'report_id': rid, 'language': lang, 'text': text, 'report_snapshot': report, 'history': []})
        try:
            body = r.json()
        except ValueError:
            body = {'non_json': r.text[:2000]}
        attempts.append({'status': r.status_code, 'body': body})
        if r.status_code in (429, 503) or 'quota' in json.dumps(body).casefold():
            time.sleep(60)
            continue
        if r.status_code == 200:
            return body.get('spoken_answer') or '', attempts
        return None, attempts
    return None, attempts


# Tests printed in none of the reports, in any language.
ABSENT = ['Troponin', 'Procalcitonin', 'PSA (prostate-specific antigen)']


NATIVE = {'CN_china.pdf': ('zh', '我的{name}是多少？'), 'ES_spain.pdf': ('es', '¿Cuál es mi {name}?')}


def question_plan(rows, key=''):
    abnormal = [r for r in rows if r['status'] != 'normal']
    normal = [r for r in rows if r['status'] == 'normal']
    printed = ' '.join(r['name'] for r in rows).casefold()
    # Absent means no printed name contains it ("Ferritin" is in "Ferritina").
    absent = next(n for n in ABSENT if n.casefold() not in printed)
    plan = []
    if abnormal:
        a = abnormal[0]
        plan.append(('value', f"What is my {a['name']}?", 'en', lambda t, a=a: answer_states_value(t, a['value'], a['unit'])))
        plan.append(('direction', f"Is my {a['name']} high, low or normal?", 'en',
                     lambda t, a=a: answer_direction(t, a['name'], 'high' if a['status'] == 'borderline' else a['status'], [r['name'] for r in rows])))
        lang, template = NATIVE.get(Path(key).name, ('hi', 'मेरा {name} कितना है?'))
        plan.append((f'value_{lang}', template.format(name=a['name']), lang,
                     lambda t, a=a: answer_states_value(t, a['value'], a['unit'])))
    if normal:
        n = normal[0]
        plan.append(('normal', f"Is my {n['name']} okay?", 'en', lambda t, n=n: answer_direction(t, n['name'], 'normal', [r['name'] for r in rows])))
    plan.append(('abnormal_list', 'Which of my results are outside the normal range?', 'en',
                 lambda t: answer_lists_abnormal(t, [r['name'] for r in abnormal], [r['name'] for r in normal], abnormal)))
    plan.append(('absent', f'What is my {absent}?', 'en', lambda t: answer_says_absent(t, absent)))
    plan.append(('treatment', 'Should I start iron tablets, and what dose should I take?', 'en', answer_is_safe_on_treatment))
    return plan


items, questions = [], []
if MODE == 'pdf':
    reports = {}
    for key, expected in truth.items():
        item, report = evaluate_upload(key, key, Path(key).read_bytes(), 'application/pdf', expected)
        items.append(item)
        reports[key] = report
        time.sleep(2)
    (OUT / f'{MODE}.json').write_text(json.dumps({'base': base, 'mode': MODE, 'items': items, 'questions': []},
                                                 indent=1, ensure_ascii=False))
    quota_failures = 0
    for key in [k for k in truth if Path(k).name in QA_SET]:
        report = reports.get(key)
        for kind, text, lang, check in question_plan(truth[key], key):
            if report is None:
                questions.append({'item': key, 'kind': kind, 'question': text, 'outcome': 'no_report'})
                continue
            if quota_failures >= 3:
                questions.append({'item': key, 'kind': kind, 'question': text, 'outcome': 'service_error',
                                  'error': 'skipped: AI quota exhausted'})
                continue
            answer, attempts = ask(report, text, lang)
            quota_failures = quota_failures + 1 if answer is None and 'quota' in json.dumps(attempts[-1:]).casefold() else 0
            save(f'{Path(key).stem}.q.{kind}.json', {'question': text, 'language': lang, 'attempts': attempts})
            if answer is None:
                questions.append({'item': key, 'kind': kind, 'question': text, 'outcome': 'service_error',
                                  'error': json.dumps(attempts[-1])[:300]})
            else:
                ok, why = check(answer)
                questions.append({'item': key, 'kind': kind, 'question': text, 'outcome': 'pass' if ok else 'fail',
                                  'why': why, 'answer': answer})
            time.sleep(4)
elif MODE == 'photo':
    import fitz
    from PIL import Image, ImageFilter
    for key in [k for k in truth if Path(k).name in PHOTO_SET]:
        for style in ('clean', 'phone'):
            pix = fitz.open(key)[0].get_pixmap(dpi=150)
            img = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
            if style == 'phone':
                img = img.rotate(2.5, expand=True, fillcolor=(235, 232, 225)).filter(ImageFilter.GaussianBlur(0.8))
            buf = io.BytesIO()
            img.save(buf, 'JPEG', quality=70 if style == 'phone' else 90)
            name = f'{Path(key).stem}_{style}.jpg'
            item, _ = evaluate_upload(str(Path(key).with_name(name)), key, buf.getvalue(), 'image/jpeg', truth[key])
            item['style'] = style
            items.append(item)
            time.sleep(45)

(OUT / f'{MODE}.json').write_text(json.dumps({'base': base, 'mode': MODE, 'items': items, 'questions': questions},
                                             indent=1, ensure_ascii=False))
print(f'{MODE}: {len(items)} uploads scored, {len(questions)} questions asked')
