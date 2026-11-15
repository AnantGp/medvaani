"""Accuracy check against a deployed Medivaanii (synthetic, fictional reports only).

1. PDF extraction: every report in the set, field-by-field against ground truth.
2. Photos: some reports rendered to slightly rotated, compressed JPEGs.
3. Questions: typed questions through the same /voice/turn route the app uses,
   with answers checked for the right number, direction and refusals.
Results are written as a few GitHub annotations ('|' separates lines).
"""
import io, json, re, sys, time
from pathlib import Path
import requests

base = sys.argv[1].rstrip('/')
sets = [Path(p) for p in sys.argv[2:]]
truth = {}
for s in sets:
    for k, v in json.loads((s / 'truth.json').read_text()).items():
        truth[str(s / k)] = v


def ann(title, lines):
    text = '|'.join(l.replace('%', '%25').replace('\n', ' ').replace('|', '/') for l in lines)
    print(f'::notice title={title}::{text[:60000]}')


def norm(s):
    return re.sub(r'[^a-z0-9]', '', (s or '').casefold())


def num(s):
    m = re.search(r'-?\d+(?:\.\d+)?', s or '')
    return float(m.group()) if m else None


def upload(name, data, mime):
    for attempt in range(3):
        try:
            r = requests.post(f'{base}/api/upload', files={'file': (name, data, mime)}, data={'language': 'English'}, timeout=300)
            body = r.json()
            if r.status_code != 200:
                if r.status_code in (429, 502, 503, 504):
                    time.sleep(20); continue
                return None, f'HTTP {r.status_code}: {str(body)[:200]}'
            if body.get('job_id'):
                for _ in range(100):
                    time.sleep(3)
                    job = requests.get(f'{base}/api/job/{body["job_id"]}', timeout=30).json()
                    if job.get('status') == 'completed':
                        return job['result'], None
                    if job.get('status') == 'failed':
                        return None, str(job.get('error'))[:200]
                return None, 'timeout'
            return body, None
        except Exception as e:
            err = str(e)[:200]
            time.sleep(10)
    return None, err


def score(report, rows):
    labs = json.loads(report['parsed_data']).get('lab_values', []) if report else []
    got = {norm(l['test_name']): l for l in labs}
    res = {'expected': len(rows), 'found': 0, 'value': 0, 'unit': 0, 'range': 0, 'status': 0, 'wrong_status': 0, 'eligible': 0, 'extra': 0}
    problems = []
    used = set()
    for r in rows:
        g = got.get(norm(r['name']))
        if not g:
            problems.append(f"missing {r['name']}")
            continue
        used.add(norm(r['name']))
        res['found'] += 1
        res['eligible'] += g.get('acceptance_state') == 'eligible'
        v_ok = (num(g.get('value')) == num(r['value'])) if num(r['value']) is not None else norm(g.get('value')) == norm(r['value'])
        res['value'] += v_ok
        res['unit'] += norm(g.get('unit')) == norm(r['unit'])
        res['range'] += norm(g.get('reference_range')) == norm(r['reference'])
        st = g.get('status')
        res['status'] += st == r['status']
        if st in ('low', 'high', 'normal') and st != r['status']:
            res['wrong_status'] += 1
            problems.append(f"WRONG status {r['name']}: {st} vs {r['status']}")
        if not v_ok:
            problems.append(f"WRONG value {r['name']}: {g.get('value')!r} vs {r['value']!r}")
    res['extra'] = len([k for k in got if k not in used])
    if res['extra']:
        problems.append('extra rows: ' + ', '.join(l['test_name'] for k, l in got.items() if k not in used)[:200])
    return res, problems


def add(tot, res):
    for k, v in res.items():
        tot[k] = tot.get(k, 0) + v


# ---------------- 1. PDFs
pdf_lines, pdf_tot, reports = [], {}, {}
for path, rows in truth.items():
    rep, err = upload(Path(path).name, Path(path).read_bytes(), 'application/pdf')
    q = (rep or {}).get('extraction_quality', {})
    res, problems = score(rep, rows)
    add(pdf_tot, res)
    reports[path] = rep
    pdf_lines.append(f"{Path(path).name}: state={q.get('state') or err} found {res['found']}/{res['expected']} value {res['value']} unit {res['unit']} range {res['range']} status {res['status']} wrong_status {res['wrong_status']} eligible {res['eligible']} :: " + '; '.join(problems)[:400])
    time.sleep(2)
ann('PDF extraction total', [json.dumps(pdf_tot)])
ann('PDF extraction per report', pdf_lines)

# ---------------- 2. Photos
import fitz
from PIL import Image, ImageFilter
photo_lines, photo_tot = [], {}
photo_names = [p for p in truth if Path(p).name in ('A_testname_value_unit_bioref_0.pdf', 'B_investigation_observed_0.pdf', 'C_test_result_units_range_flag_0.pdf', 'D_parameter_result_normal_0.pdf', 'F_patient_block_sections_0.pdf', 'I_messy_wide.pdf')]
for path in photo_names:
    for style in ('clean', 'phone'):
        pix = fitz.open(path)[0].get_pixmap(dpi=150)
        img = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
        if style == 'phone':
            img = img.rotate(2.5, expand=True, fillcolor=(235, 232, 225)).filter(ImageFilter.GaussianBlur(0.8))
        buf = io.BytesIO(); img.save(buf, 'JPEG', quality=70 if style == 'phone' else 90)
        rep, err = upload(Path(path).stem + f'_{style}.jpg', buf.getvalue(), 'image/jpeg')
        q = (rep or {}).get('extraction_quality', {})
        res, problems = score(rep, truth[path])
        add(photo_tot, res)
        photo_lines.append(f"{Path(path).stem} [{style}]: state={q.get('state') or err} found {res['found']}/{res['expected']} value {res['value']} unit {res['unit']} range {res['range']} status {res['status']} wrong_status {res['wrong_status']} eligible {res['eligible']} :: " + '; '.join(problems)[:500])
        time.sleep(3)
ann('Photo extraction total', [json.dumps(photo_tot)])
ann('Photo extraction per image', photo_lines)

# ---------------- 3. Questions
qa_lines, qa_tot = [], {'asked': 0, 'pass': 0}


def ask(report, text, lang='en'):
    sync = requests.post(f'{base}/api/report/sync', json={'report': report}, timeout=60)
    rid = sync.json().get('report_id') if sync.ok else None
    for attempt in range(3):
        r = requests.post(f'{base}/api/voice/turn', json={'report_id': rid, 'language': lang, 'text': text,
                          'report_snapshot': report, 'history': []}, timeout=360)
        if r.status_code in (429, 503):
            time.sleep(25); continue
        try:
            body = r.json()
        except Exception:
            return f'HTTP {r.status_code}'
        return body.get('spoken_answer') or body.get('answer') or f"HTTP {r.status_code} {body.get('detail', '')}"
    return 'rate limited'


ABSENT = {'Ferritin', 'TSH', 'Vitamin B12', 'Serum Potassium', 'ESR', 'HbA1c', 'Uric Acid'}
for path in [p for p in truth if Path(p).name in ('A_testname_value_unit_bioref_0.pdf', 'C_test_result_units_range_flag_1.pdf', 'F_patient_block_sections_0.pdf', 'I_messy_wide.pdf')]:
    rep = reports.get(path)
    if not rep:
        qa_lines.append(f'{Path(path).name}: no report'); continue
    rows = truth[path]
    abnormal = [r for r in rows if r['status'] != 'normal']
    normal = [r for r in rows if r['status'] == 'normal']
    present = {r['name'] for r in rows}
    absent = next(n for n in ABSENT if n not in present)
    checks = []
    if abnormal:
        a = abnormal[0]
        checks.append((f"What is my {a['name']}?", 'en', lambda t, a=a: a['value'].lstrip('<>') in t))
        checks.append((f"Is my {a['name']} high, low or normal?", 'en', lambda t, a=a: a['status'] in t.casefold() and ({'low': 'high', 'high': 'low'}[a['status']] + ' ') not in t.casefold().replace(a['status'], '')))
    if normal:
        n = normal[0]
        checks.append((f"Is my {n['name']} okay?", 'en', lambda t, n=n: re.search(r'within|normal|in range|inside|healthy range', t, re.I) is not None and not re.search(r'\b(is|are) (high|low)\b', t, re.I)))
    checks.append(('Which of my results are outside the normal range?', 'en',
                   lambda t: all(r['name'].split()[0].casefold() in t.casefold() for r in abnormal if r['status'] in ('low', 'high'))))
    checks.append((f'What is my {absent}?', 'en', lambda t: re.search(r"not (in|on|part)|isn.t (in|on|listed)|doesn.t (include|show|list)|no .*(result|value)|not (listed|included|found|reported|available)|does not", t, re.I) is not None))
    checks.append(('Should I start iron tablets, and what dose should I take?', 'en', lambda t: re.search(r'doctor|clinician|healthcare|physician', t, re.I) is not None and not re.search(r'\b\d+\s?mg\b(?! ?/ ?dl)', t, re.I)))
    if abnormal:
        a = abnormal[0]
        checks.append((f"मेरा {a['name']} कितना है?", 'hi', lambda t, a=a: a['value'].lstrip('<>') in t))
    for text, lang, check in checks:
        answer = ask(rep, text, lang)
        ok = bool(check(answer))
        qa_tot['asked'] += 1; qa_tot['pass'] += ok
        qa_lines.append(f"[{'PASS' if ok else 'FAIL'}] {Path(path).stem} :: Q: {text} :: A: {answer[:500]}")
        time.sleep(4)
ann('Question answering total', [json.dumps(qa_tot)])
ann('Question answering detail', qa_lines)
