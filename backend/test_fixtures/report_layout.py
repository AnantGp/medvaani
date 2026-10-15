"""Anonymous physical PDF fixtures: expectations never enter the extractor."""
from reportlab.pdfgen import canvas


def build_report(path, rows, *, guidelines=False, history=False, provider='Healthians Labs', methods=True, footer=False, brand_first_page_only=False, flags=None, notes=()):
    c = canvas.Canvas(str(path), pagesize=(600, 800))
    if history:
        c.drawString(40, 740, provider)
        c.drawString(40, 700, 'Historical summary 2024 2025')
        c.drawString(40, 660, 'Creatinine 8.8 mg/dL - previous result in 2024')
        c.showPage()
    c.setFont('Helvetica', 10)
    if not brand_first_page_only:
        c.drawString(40, 760, provider)
    c.drawString(40, 735, 'Sample Collected On : 14/Jan/2026')
    c.drawString(40, 720, 'Sample Type : Serum')
    c.setFont('Helvetica', 11)
    for x, label in [(40, 'Test Name'), (255, 'Value'), (365, 'Unit'), (445, 'Bio. Ref Interval')]:
        c.drawString(x, 690, label)
    if flags:
        c.drawString(550, 690, 'Flag')
    c.setFont('Helvetica', 13)
    c.drawString(40, 665, 'Laboratory Results')
    y = 640
    for name, value, unit, reference in rows:
        c.setFont('Helvetica', 10)
        for x, text in [(40, name), (255, value), (365, unit)]:
            c.drawString(x, y, text)
        if flags and flags.get(name):
            c.drawString(550, y, flags[name])
        reference_lines = reference.split('\n') if reference else []
        for i, text in enumerate(reference_lines):
            c.drawString(445, y - 12 * i, text)
        if methods:
            c.setFont('Helvetica', 8)
            c.drawString(40, y - 13, 'Method: Laboratory method')
            c.drawString(40, y - 24, 'Machine: Synthetic analyser')
        y -= max(58, 14 * len(reference_lines) + 15)
    if guidelines:
        c.setFont('Helvetica', 11)
        c.drawString(40, y - 8, 'Reference guideline targets')
        c.setFont('Helvetica', 10)
        c.drawString(40, y - 35, 'High risk group')
        c.drawString(255, y - 35, '70')
        c.drawString(365, y - 35, 'mg/dL')
        c.drawString(445, y - 35, '<100')
    if footer:
        c.drawString(445, y + 5, 'Page 1 of 1')
    for note in notes:
        c.drawString(40, y - 20, note)
        y -= 24
    c.save()
    return str(path)
