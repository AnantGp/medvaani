import importlib
import io
import pytest
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
from reportlab.pdfgen import canvas


def reader():
    import ocr
    assert hasattr(ocr, 'read_document'), 'Page-aware document reading is missing'
    return ocr.read_document


def test_digital_pdf_preserves_physical_page_and_word_boxes(tmp_path):
    path = tmp_path / 'report.pdf'
    c = canvas.Canvas(str(path), pagesize=(600, 800))
    c.drawString(40, 700, 'Synthetic laboratory report')
    c.showPage()
    c.drawString(40, 600, 'Creatinine 0.8 mg/dL')
    c.save()
    document = reader()(str(path))
    assert len(document['pages']) == 2
    word = next(w for w in document['pages'][1]['words'] if w['text'] == '0.8')
    assert .05 < word['x'] < .3 and .2 < word['y'] < .3
    assert document['pages'][1]['page'] == 2
    assert any(l['page'] == 2 and 'Creatinine' in l['text'] for l in document['pages'][1]['lines'])


def printed_image():
    image = Image.new('RGB', (1400, 900), 'white')
    font = ImageFont.truetype(str(Path(__file__).parents[1] / 'flutter_app/assets/fonts/NotoSans-Regular.ttf'), 42)
    ImageDraw.Draw(image).multiline_text((80, 100), 'SYNTHETIC LAB REPORT\nCreatinine: 0.8 mg/dL', font=font, fill='black', spacing=40)
    return image


def test_mixed_pdf_retains_scanned_second_page(tmp_path):
    from pypdf import PdfReader, PdfWriter
    first = io.BytesIO()
    c = canvas.Canvas(first)
    c.drawString(40, 700, 'Synthetic laboratory report')
    c.save()
    scan = io.BytesIO()
    printed_image().save(scan, format='PDF')
    writer = PdfWriter()
    writer.add_page(PdfReader(first).pages[0])
    writer.add_page(PdfReader(scan).pages[0])
    path = tmp_path / 'mixed.pdf'
    writer.write(path)
    document = reader()(str(path))
    assert any(w['text'].startswith('Creatinine') for w in document['pages'][1]['words'])
    assert any(l['method'] == 'ocr' and l['page'] == 2 for l in document['pages'][1]['lines'])


def test_invalid_pdf_raises_instead_of_becoming_report_text(tmp_path):
    path = tmp_path / 'invalid.pdf'
    path.write_bytes(b'This is not a PDF')
    with pytest.raises(ValueError):
        reader()(str(path))


def test_exif_photo_boxes_match_corrected_orientation(tmp_path):
    path = tmp_path / 'camera.jpg'
    image = printed_image().transpose(Image.Transpose.ROTATE_90)
    exif = image.getexif()
    exif[274] = 6
    image.save(path, exif=exif, quality=95)
    document = reader()(str(path))
    word = next(w for w in document['pages'][0]['words'] if w['text'] == '0.8')
    assert 0 < word['x'] < 1 and .15 < word['y'] < .4
    assert document['pages'][0]['page'] == 1
