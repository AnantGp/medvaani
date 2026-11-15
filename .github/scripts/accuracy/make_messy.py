"""Harder cases: comparators, text ranges, multi-line names, qualitative rows, tight columns."""
import json, sys
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
OUT = Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
W, H = A4
ROWS = [
 # name lines, value, unit, ref lines, expected status
 (['C-Reactive Protein (CRP)'], '<0.5', 'mg/L', ['< 5.0'], 'normal'),
 (['eGFR'], '>90', 'mL/min/1.73m2', ['> 60'], 'normal'),
 (['Total Cholesterol'], '232', 'mg/dL', ['Desirable: < 200', 'Borderline: 200-239', 'High: >= 240'], 'high'),
 (['LDL Cholesterol', '(Calculated)'], '148', 'mg/dL', ['< 100'], 'high'),
 (['Glycated Haemoglobin', '(HbA1c)'], '7.8', '%', ['Normal: < 5.7', 'Prediabetes: 5.7 - 6.4', 'Diabetes: >= 6.5'], 'high'),
 (['Urine Protein'], 'Negative', '', ['Negative'], 'normal'),
 (['Hepatitis B Surface Antigen'], 'Non Reactive', '', ['Non Reactive'], 'normal'),
 (['Haemoglobin'], '10.4', 'g/dL', ['12.0 - 15.5'], 'low'),
 (['Vitamin D (25-OH)'], '14.2', 'ng/mL', ['Deficient: < 20', 'Insufficient: 20 - 29', 'Sufficient: 30 - 100'], 'low'),
 (['TSH'], '6.82', 'uIU/mL', ['0.27 - 4.20'], 'high'),
]
def draw(path, xs, header, gap):
    c = canvas.Canvas(str(path), pagesize=A4)
    c.setFont('Helvetica-Bold', 14); c.drawString(40, H-50, 'Northgate Diagnostics')
    c.setFont('Helvetica', 10)
    c.drawString(40, H-80, 'Patient Name : Test Person     Age/Sex : 35 Y / F')
    c.drawString(40, H-94, 'Sample Collected On : 03/Nov/2026     Sample Type : Serum')
    c.setFont('Helvetica-Bold', 10)
    for x, h in zip(xs, header): c.drawString(x, H-120, h)
    y = H - 145
    for names, v, u, refs, _ in ROWS:
        c.setFont('Helvetica', 10)
        for i, n in enumerate(names): c.drawString(xs[0], y - 12*i, n)
        c.drawString(xs[1], y, v); c.drawString(xs[2], y, u)
        for i, r in enumerate(refs): c.drawString(xs[3], y - 12*i, r)
        y -= max(len(names), len(refs)) * 12 + gap
    c.save()
truth = {}
variants = {
 'I_messy_wide': ([40, 250, 330, 420], ['Test Name', 'Result', 'Unit', 'Bio. Ref Interval'], 14),
 'I_messy_tight': ([40, 200, 260, 345], ['Test Name', 'Result', 'Unit', 'Bio. Ref Interval'], 8),
}
for k, (xs, hdr, gap) in variants.items():
    draw(OUT / f'{k}.pdf', xs, hdr, gap)
    truth[f'{k}.pdf'] = [{'name': ' '.join(n), 'value': v, 'unit': u, 'reference': ' '.join(r), 'status': s} for n, v, u, r, s in ROWS]
(OUT / 'truth.json').write_text(json.dumps(truth, indent=1))
