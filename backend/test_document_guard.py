"""Focused intake/voice smoke checks; no models or patient files required."""
import asyncio
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

from starlette.testclient import TestClient
import document_guard as guard
from mvp_report_store import ReportState
from report_snapshot import resolve_report

CV = '''An Example
Experience
ML Engineer - Generative AI
Built a clinical summarization pipeline for diagnosis, medication and laboratory reports.
Developed a medical report parser for Creatinine 1.8 mg/dL and patient name fields.
Projects
Clinical NLP system and pathology report extraction.
Education
Bachelor of Technology
Technical Skills
Python, FastAPI, GitHub, LinkedIn
'''


class DocumentGuardSmoke(unittest.TestCase):
    def setUp(self):
        guard._checked.clear()

    def test_medical_resume_and_invoice_are_rejected(self):
        self.assertIs(guard.screen_document(CV), False)
        self.assertIs(guard.screen_document('Hospital invoice\nBill to: Patient\nSubtotal 500\nAmount due 500'), False)
        with self.assertRaises(guard.NonMedicalReportError):
            asyncio.run(guard.require_medical_report({'extracted_text': CV}))

    def test_lab_and_narrative_reports_remain_supported_in_four_languages(self):
        for text in (
            'Laboratory Report\nPatient Name: Example\nCreatinine 1.8 mg/dL\nReference range 0.7-1.3',
            'जांच रिपोर्ट\nमरीज: नमूना\nहीमोग्लोबिन 11.2 g/dL\nसंदर्भ सीमा 12-16',
            'Informe de laboratorio\nPaciente: Ejemplo\nGlucosa 95 mg/dL\nValores de referencia 70-100',
            '检验报告\n患者：示例\n血糖 5.1 mmol/L\n参考范围 3.9-6.1',
            'Radiology report\nPatient Name: Example\nMRI brain\nFindings: No focal abnormality.\nImpression: Review clinically.',
        ):
            with self.subTest(text=text[:25]):
                asyncio.run(guard.require_medical_report({'extracted_text': text}))

    def test_uncertain_document_requires_confident_purpose_review(self):
        report = {'extracted_text': 'An unfamiliar document with several paragraphs but no clear patient report structure.'}
        with patch.object(guard.groq_provider, 'configured', return_value=False):
            with self.assertRaisesRegex(guard.NonMedicalReportError, 'could not verify'):
                asyncio.run(guard.require_medical_report(report))
        classify = AsyncMock(return_value=({'is_patient_medical_report': True, 'confidence': 'uncertain'}, 'model'))
        with patch.object(guard.groq_provider, 'configured', return_value=True), patch.object(guard.groq_provider, 'chat_json', classify):
            with self.assertRaises(guard.NonMedicalReportError):
                asyncio.run(guard.require_medical_report(report))

    def test_cold_start_snapshot_cannot_hide_resume_behind_lab_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            store = ReportState(Path(directory) / 'reports.db')
            with self.assertRaises(guard.NonMedicalReportError):
                asyncio.run(resolve_report({'report': {
                    'extracted_text': CV,
                    'parsed_data': {'lab_values': [{'test_name': 'Creatinine', 'value': '1.8', 'unit': 'mg/dL'}]},
                }}, store))

    def test_upload_and_voice_reject_before_explaining_or_synthesizing(self):
        import main
        source = {'extracted_text': CV, 'pages': [], 'source_digest': 'synthetic-resume', 'diagnostics': []}
        with tempfile.TemporaryDirectory() as directory, patch.object(main, 'IS_VERCEL', True), patch.object(main, 'read_document', return_value=source), patch.object(main, 'extract_digital_results', side_effect=AssertionError('Rejected source reached extraction')):
            client = TestClient(main.app)
            response = client.post('/upload', files={'file': ('resume.pdf', b'%PDF-1.4 synthetic fixture')})
            self.assertEqual(response.status_code, 422)
            self.assertEqual(response.json()['code'], 'not_medical_report')
            for route, body in (
                ('/api/report/sync', {'report': {'extracted_text': CV}}),
                ('/api/voice/turn', {'report': {'extracted_text': CV}, 'language': 'hi', 'text': 'Explain my report'}),
                ('/api/voice/turn', {'report': {'extracted_text': CV}, 'language': 'en', 'action': 'repeat', 'last_answer': {'spoken_answer': 'Cached resume answer'}}),
            ):
                response = client.post(route, json=body)
                self.assertEqual(response.status_code, 422, route)
                self.assertEqual(response.json()['code'], 'not_medical_report')
                self.assertNotIn('audio_base64', response.json())


if __name__ == '__main__':
    unittest.main()
