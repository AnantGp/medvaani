"""Calls every user-facing API of a deployed Medivaanii and prints what came back."""
import json, sys, time
from pathlib import Path
import requests

base = sys.argv[1].rstrip('/')
pdf = Path(sys.argv[2])
lines = []

def note(name, r=None, extra='', t=0.0):
    if r is None:
        lines.append(f'{name}: {extra}')
        return
    body = r.text[:400].replace('\n', ' ')
    lines.append(f'{name}: HTTP {r.status_code} in {t:.1f}s · {body}')

def call(name, method, path, **kw):
    t = time.time()
    try:
        r = requests.request(method, base + path, timeout=300, **kw)
        note(name, r, t=time.time() - t)
        return r
    except Exception as e:
        note(name, extra=f'EXCEPTION {e!r}'[:400])

call('root', 'GET', '/api/')
call('health', 'GET', '/api/health')
call('languages', 'GET', '/api/languages')

r = call('upload', 'POST', '/api/upload', files={'file': (pdf.name, pdf.read_bytes(), 'application/pdf')},
         data={'language': 'English'})
report = None
if r is not None and r.ok:
    body = r.json()
    if body.get('job_id'):
        for _ in range(100):
            time.sleep(3)
            j = requests.get(f"{base}/api/job/{body['job_id']}", timeout=30).json()
            if j.get('status') in ('completed', 'failed'):
                lines.append(f"job: {j.get('status')} {str(j.get('error') or '')[:300]}")
                report = j.get('result')
                break
    else:
        report = body
if report:
    parsed = report.get('parsed_data')
    parsed = json.loads(parsed) if isinstance(parsed, str) else (parsed or {})
    diags = [d.get('code') for d in (parsed.get('document') or {}).get('diagnostics', [])]
    lines.append(f"extraction: state={report.get('extraction_quality', {}).get('state')} rows={len(parsed.get('lab_values', []))} diagnostics={diags[:12]}")
    s = call('report sync', 'POST', '/api/report/sync', json={'report': report})
    rid = s.json().get('report_id') if s is not None and s.ok else None
    for lang, q in [('en', 'What is my haemoglobin?'), ('hi', 'मेरा HbA1c कितना है?')]:
        call(f'voice turn ({lang})', 'POST', '/api/voice/turn', json={
            'report_id': rid, 'language': lang, 'text': q, 'report_snapshot': report, 'history': []})
        time.sleep(5)
call('synthesize', 'POST', '/api/synthesize', json={'text': 'Your haemoglobin is 13.6 grams per decilitre.', 'language': 'en'})

out = '\n'.join(lines)
print(out)
print('::notice title=api probe::' + out.replace('%', '%25').replace('\n', '%0A')[:3800])
