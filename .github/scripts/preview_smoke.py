"""Smoke-test a Vercel deployment with a synthetic (non-patient) lab report.

Results are printed as GitHub annotations so they are visible on the commit.
"""
import io
import json
import sys
import time

import requests
from reportlab.pdfgen import canvas

base = sys.argv[1].rstrip('/')
failures = []


def note(title, message):
    print(f'::notice title={title}::{message}')


def fail(title, message):
    failures.append(title)
    print(f'::error title={title}::{message}')


def sample_pdf(header):
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=(600, 800))
    c.setFont('Helvetica', 10)
    c.drawString(40, 760, 'Sample Diagnostics Laboratory - synthetic test report')
    c.drawString(40, 744, 'Patient: SAMPLE   Sample Collected On : 01/Nov/2026   Sample Type : Blood')
    cols = [40, 230, 310, 400, 520]
    for x, text in zip(cols, header):
        c.drawString(x, 710, text)
    rows = [('Haemoglobin', '11.2', 'g/dL', '12.0 - 15.5', 'L'),
            ('Ferritin', '9', 'ng/mL', '15 - 150', 'L'),
            ('TSH', '2.1', 'mIU/L', '0.4 - 4.0', ''),
            ('HbA1c', '6.1', '%', '4.0 - 5.6', 'H'),
            ('Serum Creatinine', '0.9', 'mg/dL', '0.6 - 1.1', '')]
    y = 690
    for row in rows:
        for x, text in zip(cols, row):
            c.drawString(x, y, text)
        y -= 18
    c.drawString(40, y - 20, 'End of report. Synthetic sample for software testing.')
    c.save()
    return buf.getvalue()


def upload(name, pdf):
    r = requests.post(f'{base}/api/upload', files={'file': (name, pdf, 'application/pdf')},
                      data={'language': 'English'}, timeout=300)
    data = r.json()
    if r.status_code != 200:
        fail(f'upload {name}', f'HTTP {r.status_code}: {str(data)[:300]}')
        return None
    if data.get('job_id'):
        for _ in range(60):
            time.sleep(3)
            job = requests.get(f'{base}/api/job/{data["job_id"]}', timeout=30).json()
            if job.get('status') == 'completed':
                return job['result']
            if job.get('status') == 'failed':
                fail(f'upload {name}', str(job.get('error'))[:300])
                return None
        fail(f'upload {name}', 'job did not finish')
        return None
    return data


note('target', base)
page = requests.get(base + '/', timeout=60)
if page.status_code == 200 and 'Medivaanii' in page.text:
    note('page', 'index.html served')
else:
    fail('page', f'HTTP {page.status_code}')

health = requests.get(f'{base}/api/health', timeout=60)
if health.ok and health.json().get('status') == 'healthy':
    note('api health', 'healthy')
else:
    fail('api health', f'HTTP {health.status_code} {health.text[:200]}')

for name, header in [('result-layout.pdf', ['Test', 'Result', 'Units', 'Reference Range', 'Flag']),
                     ('value-layout.pdf', ['Test Name', 'Value', 'Unit', 'Bio. Ref Interval', 'Flag'])]:
    report = upload(name, sample_pdf(header))
    if not report:
        continue
    quality = report.get('extraction_quality', {})
    rows = json.loads(report['parsed_data']).get('lab_values', [])
    summary = ', '.join(f"{r['test_name']}={r['value']} {r.get('unit', '')} [{r.get('acceptance_state')}]" for r in rows)
    if len(rows) >= 5:
        note(f'extract {name}', f"{quality.get('state')}: {len(rows)} rows: {summary}"[:900])
    else:
        fail(f'extract {name}', f"{quality.get('state')}: {len(rows)} rows: {summary}"[:900])
    if name == 'result-layout.pdf' and rows:
        question = requests.post(f'{base}/api/report/question', json={
            'report': report, 'question': 'What is my ferritin value?', 'language': 'English'}, timeout=120)
        if question.ok:
            note('question', json.dumps(question.json())[:900])
        else:
            fail('question', f'HTTP {question.status_code} {question.text[:300]}')

sys.exit(1 if failures else 0)
