import copy
import json
from pathlib import Path
from starlette.testclient import TestClient
import main
from test_fixtures.report_layout import build_report


def original_report(client, path):
    result = client.post('/upload', files={'file': (path.name, path.read_bytes())}, data={'language': 'English'})
    job = main.processing_jobs.pop(result.json()['job_id'])
    return job['result']


def migrate(client, path, report):
    return client.post('/report/reextract', files={'file': (path.name, path.read_bytes())}, data={'report': json.dumps(report), 'language': 'English'})


def test_original_byte_migration_preserves_confirmed_edits(tmp_path, monkeypatch):
    monkeypatch.setattr(main, 'docling_worker', None)
    path = tmp_path / 'source.pdf'
    build_report(path, [('Glucose', '145', 'mg/dL', '70-100')])
    client = TestClient(main.app)
    report = original_report(client, path)
    labs = json.loads(report['parsed_data'])['lab_values']
    labs[0]['value'] = '95'
    reviewed = client.post('/report/review', json={'report': report, 'labs': labs, 'language': 'English'}).json()
    result = migrate(client, path, reviewed)
    assert result.status_code == 200
    fresh = result.json()
    assert json.loads(fresh['parsed_data'])['lab_values'][0]['value'] == '95'
    assert fresh['source_evidence'][0]['original_fields']['value'] == '145'
    assert fresh['source_evidence'][0]['measurement_id'] == report['source_evidence'][0]['measurement_id']


def test_digest_mismatch_refuses_migration_without_changing_edits(tmp_path, monkeypatch):
    monkeypatch.setattr(main, 'docling_worker', None)
    path, other = tmp_path / 'source.pdf', tmp_path / 'different.pdf'
    build_report(path, [('Glucose', '145', 'mg/dL', '70-100')])
    build_report(other, [('Glucose', '195', 'mg/dL', '70-100')])
    client = TestClient(main.app)
    report = original_report(client, path)
    before = copy.deepcopy(report)
    assert migrate(client, other, report).status_code == 409
    assert report == before


def test_ambiguous_legacy_edits_are_preserved_unapplied(tmp_path, monkeypatch):
    monkeypatch.setattr(main, 'docling_worker', None)
    path = tmp_path / 'source.pdf'
    build_report(path, [('Glucose', '145', 'mg/dL', '70-100'), ('Glucose', '145', 'mg/dL', '70-100')])
    old = {'extraction_version': 3, 'review': {'confirmed': True, 'edited_lab_ids': [0]}, 'parsed_data': {'lab_values': [{'test_name': 'Glucose', 'value': '95', 'unit': 'mg/dL', 'reference_range': '70-100', 'status': 'normal'}]}, 'source_evidence': [{'lab_id': 0, 'original_fields': {'test_name': 'Glucose', 'value': '145', 'unit': 'mg/dL', 'reference_range': '70-100'}}]}
    result = migrate(TestClient(main.app), path, old)
    assert result.status_code == 200
    fresh = result.json()
    assert [r['value'] for r in json.loads(fresh['parsed_data'])['lab_values']] == ['145', '145']
    assert fresh['unapplied_corrections'][0]['reviewed_fields']['value'] == '95'


def test_photo_checks_survive_a_second_unchanged_review(tmp_path, monkeypatch):
    from test_photo_upload import report_photo
    monkeypatch.setattr(main, 'docling_worker', None)
    path = tmp_path / 'source.png'
    report_photo().save(path)
    client = TestClient(main.app)
    report = original_report(client, path)
    assert report['extraction_quality']['state'] == 'blocked'
    labs = json.loads(report['parsed_data'])['lab_values']
    unchanged = client.post('/report/review', json={'report': report, 'labs': labs, 'language': 'English'}).json()
    assert unchanged['extraction_quality']['state'] == 'blocked'
    for row in labs:
        row['source_checked_fields'] = ['test_name', 'value', 'unit']
    checked = client.post('/report/review', json={'report': unchanged, 'labs': labs, 'language': 'English'}).json()
    assert checked['extraction_quality']['eligible_count'] == 2
    repeated = client.post('/report/review', json={'report': checked, 'labs': json.loads(checked['parsed_data'])['lab_values'], 'language': 'English'}).json()
    assert repeated['extraction_quality']['eligible_count'] == 2
