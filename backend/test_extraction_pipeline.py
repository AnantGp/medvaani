"""Physical-source/API acceptance tests; provider calls never receive blocked results."""
import json
from pathlib import Path
import pytest
from starlette.testclient import TestClient
import main
from ocr import read_document
from test_fixtures.report_layout import build_report


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(main, 'docling_worker', None, raising=False)
    monkeypatch.setattr(main.agents, 'translate_all_with_claude', lambda *a: pytest.fail('Unexpected translation'))
    return TestClient(main.app)


def upload(client, path):
    reply = client.post('/upload', files={'file': (path.name, path.read_bytes())}, data={'language': 'English'})
    assert reply.status_code == 200
    job = client.get('/job/' + reply.json()['job_id']).json()
    record = main.processing_jobs.pop(reply.json()['job_id'])
    assert not Path(record['temp_file']).exists()
    return job


def test_upload_guidelines_only_is_blocked(client, tmp_path):
    path = tmp_path / 'guidelines.pdf'
    build_report(path, [], guidelines=True)
    job = upload(client, path)
    assert job['status'] == 'completed'
    result = job['result']
    assert result['extraction_quality']['state'] == 'blocked'
    assert not json.loads(result['parsed_data'])['lab_values']
    assert '70' not in result['simple_explanation']


def test_upload_real_result_and_guideline_separates_counts(client, tmp_path):
    path = tmp_path / 'results.pdf'
    build_report(path, [('Creatinine', '0.9', 'mg/dL', '0.6-1.2')], guidelines=True)
    result = upload(client, path)['result']
    assert result['extraction_version'] == 4
    assert result['extraction_quality']['eligible_count'] == 1
    parsed = json.loads(result['parsed_data'])
    assert [r['test_name'] for r in parsed['lab_values']] == ['Creatinine']
    assert result['report_date'] == '2026-01-14'
    assert parsed['document']['source_digest']
    assert parsed['lab_values'][0]['source_fields']['value']['page'] == 1


def test_failed_page_is_partial_not_all_normal(client, tmp_path, monkeypatch):
    path = tmp_path / 'partial.pdf'
    build_report(path, [('Creatinine', '0.9', 'mg/dL', '0.6-1.2')])
    doc = read_document(str(path))
    doc['diagnostics'].append({'code': 'page_failed', 'page': 2})
    monkeypatch.setattr(main, 'read_document', lambda p: doc, raising=False)
    result = upload(client, path)['result']
    assert result['extraction_quality']['state'] == 'partial'
    assert result['extraction_quality']['failed_pages'] == [2]
    assert 'Partial report' in result['simple_explanation']


def test_worker_timeout_cleans_upload_and_preserves_native_rows(client, tmp_path, monkeypatch):
    class Worker:
        def convert(self, *a, **kw):
            raise TimeoutError('worker timed out')
    monkeypatch.setattr(main, 'docling_worker', Worker(), raising=False)
    path = tmp_path / 'unknown.pdf'
    build_report(path, [('Creatinine', '0.9', 'mg/dL', '0.6-1.2')], provider='Example Laboratory')
    result = upload(client, path)['result']
    assert result['extraction_quality']['state'] == 'partial'
    assert result['extraction_quality']['eligible_count'] == 1
    assert any(i['code'] == 'worker_timeout' for i in result['extraction_quality']['issues'])


def test_review_and_question_endpoints_enforce_quality(client):
    legacy = {'extraction_version': 3, 'review': {'confirmed': True}, 'parsed_data': {'lab_values': [{'test_name': 'High risk group', 'value': '70'}]}}
    assert client.post('/report/question', json={'report': legacy, 'question': 'higher results'}).json()['supported'] is False
    assert client.post('/report/review', json={'report': legacy, 'labs': legacy['parsed_data']['lab_values']}).status_code == 400
    assert client.post('/retranslate', json={**legacy, 'language': 'Hindi'}).status_code == 409


def test_legacy_history_cannot_generate_current_interpretation(client, monkeypatch):
    legacy = {'patient_id': 'anonymous', 'report_date': '2025-01-01', 'parsed_data': json.dumps({'lab_values': [{'test_name': 'Creatinine', 'value': '8.8', 'unit': 'mg/dL', 'status': 'high'}]}), 'simple_explanation': 'Old cached explanation'}
    monkeypatch.setattr(main.db, 'get_patient_reports', lambda *a, **k: [legacy, legacy])
    result = client.get('/patient/anonymous/history').json()['reports'][0]
    assert result['extraction_quality']['state'] == 'legacy_unverified'
    assert not result.get('simple_explanation')
    assert not client.get('/patient/anonymous/temporal').json()['time_series']


def test_unreadable_result_cell_remains_a_review_candidate(client, tmp_path):
    path = tmp_path / 'uncertain.pdf'
    build_report(path, [('Creatinine', '0.9', 'mg/dL', '0.6-1.2'), ('Glucose', '???', 'mg/dL', '70-100')])
    result = upload(client, path)['result']
    assert result['extraction_quality']['state'] == 'partial'
    assert result['extraction_quality']['needs_review_count'] == 1
    rows = json.loads(result['parsed_data'])['lab_values']
    assert rows[1]['value'] == '???'
    assert rows[1]['acceptance_state'] == 'needs_review'
