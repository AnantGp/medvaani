"""Build a synthetic lab-report test set with ground truth.

Every report is fictional. Layouts imitate common printed lab styles:
different header words, column orders, flag columns, section headings,
patient blocks, multi-page reports and comparator values.
"""
import json, random, sys
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
random.seed(7)

# name, unit, low, high, typical-normal value generator
TESTS = [
    ('Haemoglobin', 'g/dL', 13.0, 17.0, 1),
    ('Total Leucocyte Count', '10^3/uL', 4.0, 11.0, 1),
    ('Platelet Count', '10^3/uL', 150, 410, 0),
    ('RBC Count', 'million/uL', 4.5, 5.5, 2),
    ('Haematocrit (PCV)', '%', 40, 50, 1),
    ('MCV', 'fL', 83, 101, 1),
    ('MCH', 'pg', 27, 32, 1),
    ('MCHC', 'g/dL', 31.5, 34.5, 1),
    ('Fasting Blood Sugar', 'mg/dL', 70, 100, 0),
    ('HbA1c', '%', 4.0, 5.6, 1),
    ('Serum Creatinine', 'mg/dL', 0.7, 1.3, 2),
    ('Blood Urea Nitrogen', 'mg/dL', 7, 20, 1),
    ('Uric Acid', 'mg/dL', 3.5, 7.2, 1),
    ('Total Cholesterol', 'mg/dL', 0, 200, 0),
    ('Triglycerides', 'mg/dL', 0, 150, 0),
    ('HDL Cholesterol', 'mg/dL', 40, 60, 0),
    ('LDL Cholesterol', 'mg/dL', 0, 100, 0),
    ('SGPT (ALT)', 'U/L', 0, 41, 0),
    ('SGOT (AST)', 'U/L', 0, 40, 0),
    ('Alkaline Phosphatase', 'U/L', 40, 129, 0),
    ('Total Bilirubin', 'mg/dL', 0.3, 1.2, 2),
    ('TSH', 'uIU/mL', 0.27, 4.2, 2),
    ('Free T4', 'ng/dL', 0.93, 1.7, 2),
    ('Vitamin D (25-OH)', 'ng/mL', 30, 100, 1),
    ('Vitamin B12', 'pg/mL', 197, 771, 0),
    ('Ferritin', 'ng/mL', 30, 400, 0),
    ('Serum Sodium', 'mmol/L', 136, 145, 0),
    ('Serum Potassium', 'mmol/L', 3.5, 5.1, 1),
    ('Calcium', 'mg/dL', 8.6, 10.2, 1),
    ('ESR', 'mm/hr', 0, 15, 0),
]


def fmt(v, d):
    return f'{v:.{d}f}' if d else str(int(round(v)))


def make_row(t, mode):
    name, unit, lo, hi, d = t
    span = hi - lo if hi > lo else hi
    if mode == 'low' and lo > 0:
        v = lo - span * random.uniform(0.1, 0.4)
        v = max(v, lo * 0.3)
        status = 'low'
    elif mode == 'high':
        v = hi + span * random.uniform(0.1, 0.5)
        status = 'high'
    else:
        v = random.uniform(lo + span * 0.15, hi - span * 0.15) if lo > 0 else random.uniform(hi * 0.4, hi * 0.85)
        status = 'normal'
    value = fmt(v, d)
    if lo == 0:
        ref = f'< {fmt(hi, d)}'
    else:
        ref = f'{fmt(lo, d if d else 0)} - {fmt(hi, d if d else 0)}'
    # Recompute status from the printed (rounded) value and range.
    fv = float(value)
    if lo == 0:
        status = 'high' if fv >= hi else 'normal'
    else:
        status = 'low' if fv < lo else 'high' if fv > hi else 'normal'
    return {'name': name, 'value': value, 'unit': unit, 'reference': ref, 'status': status}


def pick_rows(n):
    tests = random.sample(TESTS, n)
    rows = []
    for t in tests:
        mode = random.choices(['normal', 'low', 'high'], [0.6, 0.2, 0.2])[0]
        rows.append(make_row(t, mode))
    return rows


LAYOUTS = {
    # header labels, column x positions, flag column?, patient block?, section headings?
    'A_testname_value_unit_bioref': dict(headers=['Test Name', 'Value', 'Unit', 'Bio. Ref Interval'], xs=[40, 255, 340, 430], flag=False),
    'B_investigation_observed': dict(headers=['Investigation', 'Observed Value', 'Unit', 'Reference Range'], xs=[40, 230, 330, 420], flag=False),
    'C_test_result_units_range_flag': dict(headers=['Test', 'Result', 'Units', 'Reference Range', 'Flag'], xs=[40, 220, 300, 390, 520], flag=True),
    'D_parameter_result_normal': dict(headers=['Parameter', 'Result', 'Unit', 'Normal Range'], xs=[40, 240, 320, 420], flag=False),
    'E_ref_before_unit': dict(headers=['Test Name', 'Result', 'Bio. Ref. Interval', 'Units'], xs=[40, 240, 330, 470], flag=False, ref_first=True),
    'F_patient_block_sections': dict(headers=['Test Description', 'Value(s)', 'Unit(s)', 'Reference Range'], xs=[40, 250, 340, 430], flag=False, sections=True),
    'G_inline_flag_star': dict(headers=['Test Name', 'Result', 'Unit', 'Biological Ref. Range'], xs=[40, 240, 330, 420], flag=False, inline_flag=True),
    'H_multipage': dict(headers=['Test Name', 'Value', 'Unit', 'Bio. Ref Interval'], xs=[40, 255, 340, 430], flag=False, rows=26),
}


def draw(path, layout, rows, lab_name):
    c = canvas.Canvas(str(path), pagesize=A4)
    W, H = A4
    cfg = LAYOUTS[layout]

    def page_header():
        c.setFont('Helvetica-Bold', 14)
        c.drawString(40, H - 50, lab_name)
        c.setFont('Helvetica', 9)
        c.drawString(40, H - 64, 'NABL accredited laboratory  |  Ph: 0124 400 0000')
        c.setFont('Helvetica', 10)
        c.drawString(40, H - 90, 'Patient Name : Test Person')
        c.drawString(320, H - 90, 'Age / Sex : 42 Y / M')
        c.drawString(40, H - 104, 'Sample Collected On : 12/Oct/2026 08:10')
        c.drawString(320, H - 104, 'Lab ID : 2610120045')
        c.drawString(40, H - 118, 'Referred By : Self')
        c.drawString(320, H - 118, 'Sample Type : Serum')
        c.setFont('Helvetica-Bold', 10)
        for x, label in zip(cfg['xs'], cfg['headers']):
            c.drawString(x, H - 145, label)
        c.line(40, H - 150, W - 40, H - 150)

    page_header()
    y = H - 170
    sections = ['HAEMATOLOGY', 'BIOCHEMISTRY', 'THYROID PROFILE'] if cfg.get('sections') else []
    per_section = (len(rows) + len(sections) - 1) // len(sections) if sections else None
    for i, r in enumerate(rows):
        if sections and i % per_section == 0:
            c.setFont('Helvetica-Bold', 11)
            c.drawString(40, y, sections[i // per_section])
            y -= 20
        if y < 80:
            c.setFont('Helvetica', 8)
            c.drawString(40, 40, 'Page continues. This is a computer generated report.')
            c.showPage()
            page_header()
            y = H - 170
        c.setFont('Helvetica', 10)
        value = r['value']
        if cfg.get('inline_flag') and r['status'] != 'normal':
            value = value + (' L' if r['status'] == 'low' else ' H')
        cols = [r['name'], value, r['reference'], r['unit']] if cfg.get('ref_first') else [r['name'], value, r['unit'], r['reference']]
        for x, text in zip(cfg['xs'], cols):
            c.drawString(x, y, text)
        if cfg['flag'] and r['status'] != 'normal':
            c.drawString(cfg['xs'][4], y, 'L' if r['status'] == 'low' else 'H')
        y -= 22
    c.setFont('Helvetica', 8)
    c.drawString(40, 60, '*** End of Report ***')
    c.drawString(40, 48, 'Results relate only to the sample tested. Please correlate clinically.')
    c.save()


LABS = ['Sunrise Diagnostics', 'Metro Path Labs', 'CityCare Laboratory', 'Healthline Diagnostic Centre']
truth = {}
n = 0
for layout, cfg in LAYOUTS.items():
    for k in range(3):
        rows = pick_rows(cfg.get('rows', random.randint(8, 14)))
        name = f'{layout}_{k}.pdf'
        draw(OUT / name, layout, rows, LABS[(n + k) % len(LABS)])
        truth[name] = rows
        n += 1
(OUT / 'truth.json').write_text(json.dumps(truth, indent=1))
print(len(truth), 'reports,', sum(len(v) for v in truth.values()), 'rows')
