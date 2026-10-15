"""Photo intake regressions: unreadable images must never become report text."""
import io
import os

import pytest
from PIL import Image, ImageDraw, ImageFont
from starlette.testclient import TestClient

import main
from ocr import extract_text


def report_photo():
    image = Image.new("RGB", (1400, 900), "white")
    font_path = os.path.join(os.path.dirname(__file__), "..", "flutter_app", "assets", "fonts", "NotoSans-Regular.ttf")
    font = ImageFont.truetype(font_path, 42)
    ImageDraw.Draw(image).multiline_text((80, 80), "SYNTHETIC TEST REPORT\nLaboratory Results\nHemoglobin: 11.2 g/dL\nPlatelets: 240 10^3/uL", font=font, fill="black", spacing=30)
    return image


def test_blank_photo_fails_instead_of_returning_error_prose(tmp_path):
    path = tmp_path / "blank.png"
    Image.new("RGB", (700, 900), "white").save(path)
    with pytest.raises(ValueError, match="clearer photo"):
        extract_text(str(path))


def test_corrupt_photo_fails_before_medical_parsing(tmp_path):
    path = tmp_path / "broken.jpg"
    path.write_bytes(b"This is not an image")
    with pytest.raises(ValueError, match="could not read this photo"):
        extract_text(str(path))


def test_camera_exif_rotation_preserves_readable_values(tmp_path):
    path = tmp_path / "camera.jpg"
    image = report_photo().transpose(Image.Transpose.ROTATE_90)
    exif = image.getexif()
    exif[274] = 6
    image.save(path, exif=exif, quality=95)
    text = extract_text(str(path))
    assert "Hemoglobin: 11.2 g/dL" in text
    assert "Platelets: 240" in text


def test_photo_coordinates_come_from_the_same_ocr_pass(tmp_path):
    path = tmp_path / 'photo.png'
    report_photo().save(path)
    layout = []
    text = extract_text(str(path), layout=layout)
    line = next(line for line in layout if 'Hemoglobin' in line['text'])
    assert '11.2' in line['text'] and line['text'] in text
    assert line['method'] == 'ocr' and line['page'] == 1
    x, y, width, height = line['box']
    assert 0 < x < .2 and .2 < y < .5 and 0 < width < 1 and 0 < height < .1
    assert any(word['text'] == '11.2' for word in line['words'])


def test_scanned_pdf_has_page_coordinates_without_a_fake_text_layer(tmp_path):
    path = tmp_path / 'scan.pdf'
    report_photo().save(path, format='PDF')
    layout = []
    text = extract_text(str(path), layout=layout)
    assert 'Hemoglobin' in text
    assert any(line['page'] == 1 and line['method'] == 'ocr' and '11.2' in line['text'] for line in layout)


def test_legacy_source_location_recovery_does_not_create_or_modify_a_report():
    buffer = io.BytesIO()
    report_photo().save(buffer, format='PNG')
    before = set(main.processing_jobs)
    result = TestClient(main.app).post('/report/source-layout',files={'file':('original.png',buffer.getvalue())})
    assert result.status_code == 200
    assert any('Hemoglobin' in line['text'] for line in result.json()['source_layout'])
    assert 'parsed_data' not in result.json()
    assert set(main.processing_jobs) == before


def test_unreadable_results_do_not_generate_a_placeholder_report(monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    image = report_photo()
    ImageDraw.Draw(image).rectangle((0, 0, 1400, 900), fill="white")
    font = ImageFont.truetype(os.path.join(os.path.dirname(__file__), "..", "flutter_app", "assets", "fonts", "NotoSans-Regular.ttf"), 42)
    ImageDraw.Draw(image).multiline_text((80, 80), "Laboratory Report\nPathology Hospital\nPatient Name: Test\nHemoglobin results unreadable\nGlucose results unreadable", font=font, fill="black", spacing=30)
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    client = TestClient(main.app)
    response = client.post("/upload", files={"file": ("unreadable.png", buffer.getvalue())}, data={"language": "English"})
    job_id = response.json()["job_id"]
    try:
        job = client.get(f"/job/{job_id}").json()
        assert job["status"] == "failed"
        assert "result" not in job
        assert "clearer photo" in job["error"]
    finally:
        main.processing_jobs.pop(job_id, None)


@pytest.mark.parametrize("name,data,status", [
    ("report.txt", b"unsupported", 415),
    ("empty.jpg", b"", 400),
    ("large.jpg", b"x" * (10 * 1024 * 1024 + 1), 413),
], ids=["unsupported-type", "empty-file", "too-large"])
def test_upload_rejects_invalid_files_before_creating_jobs(name, data, status, monkeypatch):
    # Prevent the slow interpretation pipeline; invalid intake must not reach it.
    monkeypatch.setattr(main, "process_report_async", lambda job_id: None)
    before = set(main.processing_jobs)
    response = TestClient(main.app).post("/upload", files={"file": (name, data)})
    try:
        assert response.status_code == status
        assert set(main.processing_jobs) == before
    finally:
        for job_id in set(main.processing_jobs) - before:
            job = main.processing_jobs.pop(job_id)
            if os.path.exists(job["temp_file"]):
                os.remove(job["temp_file"])
