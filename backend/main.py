"""
Medical Report Processing API
Uses local fallback agents for report parsing and processing.
"""

from starlette.applications import Starlette
from starlette.background import BackgroundTask
from starlette.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse, StreamingResponse
from starlette.requests import Request
from starlette.routing import Route
import os
import tempfile
from starlette.datastructures import UploadFile
from typing import Optional, List, Dict
from datetime import datetime
import json
import uuid
from concurrent.futures import ThreadPoolExecutor
import threading

from ocr import extract_text, read_document
from report_quality import validate_document, report_quality, can_generate_report_output, eligible_measurements
from digital_results import extract_digital_results
from docling_adapter import extract_docling_results, reconcile_measurements
from docling_worker import DoclingWorker

docling_worker = DoclingWorker() if os.environ.get("MEDIVAANII_DOCLING_PYTHON") else None
import agents
import report_review
from db import MedicalDatabase
from mvp_report_store import ReportState
from voice_mvp import routes as voice_routes
voice_state = ReportState(os.path.join(os.path.dirname(__file__), '.local', 'voice_mvp.sqlite3'))
sync_voice_report, voice_turn = voice_routes(voice_state)

# Initialize database
db = MedicalDatabase()


# Job tracking
processing_jobs: Dict[str, Dict] = {}
job_lock = threading.Lock()

# Thread pool for background processing
executor = ThreadPoolExecutor(max_workers=4)
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
REPORT_EXTENSIONS = {".pdf", ".jpg", ".jpeg", ".png", ".webp"}

# ============== API Endpoints ==============
async def upload_report(request: Request):
    temp_path = None
    try:
        form = await request.form()
        file = form.get("file")
        if not isinstance(file, UploadFile):
            return JSONResponse({"detail": "Missing file"}, status_code=400)

        extension = os.path.splitext(file.filename or "")[1].lower()
        if extension not in REPORT_EXTENSIONS:
            await file.close()
            return JSONResponse({"detail": "Choose a PDF, JPG, PNG or WebP report."}, status_code=415)
        content = await file.read(MAX_UPLOAD_BYTES + 1)
        await file.close()
        if not content:
            return JSONResponse({"detail": "This file is empty. Choose another report."}, status_code=400)
        if len(content) > MAX_UPLOAD_BYTES:
            return JSONResponse({"detail": "This file is larger than 10 MB. Choose a smaller photo or PDF."}, status_code=413)

        patient_id = form.get("patient_id")
        language = "English"  # Voice language is selected independently; extraction uses no translation provider.

        job_id = str(uuid.uuid4())
        with tempfile.NamedTemporaryFile(prefix="medivaanii_", suffix=extension, delete=False) as buffer:
            temp_path = buffer.name
            buffer.write(content)

        with job_lock:
            processing_jobs[job_id] = {
                "status": "processing",
                "progress": 0,
                "message": "Reading original document pages...",
                "created_at": datetime.now().isoformat(),
                "temp_file": temp_path,
                "patient_id": patient_id,
                "language": language,
                "input_type": "pdf" if extension == ".pdf" else "photo",
            }

        background = BackgroundTask(process_report_async, job_id)

        return JSONResponse({
            "job_id": job_id,
            "status": "processing",
            "message": "Report processing started. Check status with GET /job/{job_id}"
        }, background=background)

    except Exception as e:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)
        return JSONResponse({"detail": str(e)}, status_code=500)


async def source_layout_report(request: Request):
    """Recover source coordinates for a previously saved local document.

    This reads the source only; it never reinterprets or replaces reviewed data.
    """
    from starlette.concurrency import run_in_threadpool
    temp_path = None
    try:
        form = await request.form()
        file = form.get('file')
        if not isinstance(file, UploadFile):
            return JSONResponse({'detail':'Choose the original report.'}, status_code=400)
        extension = os.path.splitext(file.filename or '')[1].lower()
        if extension not in REPORT_EXTENSIONS:
            await file.close()
            return JSONResponse({'detail':'Choose a PDF, JPG, PNG or WebP report.'}, status_code=415)
        content = await file.read(MAX_UPLOAD_BYTES + 1)
        await file.close()
        if not content or len(content) > MAX_UPLOAD_BYTES:
            return JSONResponse({'detail':'Choose a nonempty report up to 10 MB.'}, status_code=413 if content else 400)
        with tempfile.NamedTemporaryFile(prefix='medivaanii_source_',suffix=extension,delete=False) as buffer:
            temp_path = buffer.name
            buffer.write(content)
        layout = []
        await run_in_threadpool(extract_text,temp_path,layout=layout)
        return JSONResponse({'source_layout':layout})
    except Exception:
        return JSONResponse({'detail':'Source locations could not be read. Try a clearer photo or PDF.'},status_code=422)
    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)


async def get_job_status(request: Request):
    job_id = request.path_params.get("job_id")
    with job_lock:
        if job_id not in processing_jobs:
            return JSONResponse({"detail": "Job not found"}, status_code=404)

        job = processing_jobs[job_id]

        if job["status"] == "completed":
            return JSONResponse({
                "job_id": job_id,
                "status": "completed",
                "progress": 100,
                "message": job.get("message", "Processing complete"),
                "result": job["result"],
                "completed_at": job["completed_at"]
            })

        if job["status"] == "failed":
            return JSONResponse({
                "job_id": job_id,
                "status": "failed",
                "progress": job.get("progress", 0),
                "message": job.get("message", job.get("error", "Processing failed")),
                "error": job.get("error"),
                "failed_at": job.get("failed_at")
            })

        return JSONResponse({
            "job_id": job_id,
            "status": job["status"],
            "progress": job["progress"],
            "message": job["message"],
            "created_at": job["created_at"]
        })


def process_report_async(job_id: str):
    """Background task to process the report"""
    try:
        with job_lock:
            job = processing_jobs[job_id]

        temp_path = job["temp_file"]
        patient_id = job["patient_id"]
        language = job["language"]

        def update_progress(progress: int, message: str):
            with job_lock:
                processing_jobs[job_id]["progress"] = progress
                processing_jobs[job_id]["message"] = message

        update_progress(10, "Extracting text from document...")

        document = read_document(temp_path)
        raw_text = document['extracted_text']
        source_layout = [line for page in document['pages'] for line in page.get('lines', [])]
        if not raw_text or len(raw_text.strip()) < 10:
            raise ValueError("Could not read this document. Choose a clearer photo or PDF.")
        update_progress(15, "Checking your report...")
        is_medical, reason = agents.is_medical_document(raw_text)
        if not is_medical:
            raise ValueError(reason)
        update_progress(30, "Associating patient results with their source cells...")
        candidates, diagnostics = extract_digital_results(document['pages'], document['source_digest'])
        document['candidates'] = candidates
        document['diagnostics'].extend(diagnostics)
        _, quality = validate_document(document)
        if docling_worker is not None and quality['state'] != 'ready':
            update_progress(35, "Reading complex tables locally; this may take several minutes...")
            try:
                structured = docling_worker.convert(temp_path, [p['page'] for p in document['pages']])
                extra, problems = extract_docling_results(structured, document['source_digest'])
                ocr_pages = {p['page'] for p in document['pages'] if any(l['method'] == 'ocr' for l in p.get('lines', []))}
                for row in extra:
                    for field in row.get('source_fields', {}).values():
                        if field.get('page') in ocr_pages:
                            field['method'] = 'docling_ocr'
                document['candidates'] = reconcile_measurements(candidates, extra)
                document['diagnostics'].extend(problems)
            except Exception as error:
                document['diagnostics'].append({'code': 'worker_timeout' if isinstance(error, TimeoutError) else 'worker_failed'})
        initial_state = agents.get_default_state(raw_text, patient_id=patient_id, target_lang=language)
        result = agents.validation_agent(agents.parse_agent(initial_state, document=document))
        if job.get('input_type') == 'photo' and not result['is_valid']:
            raise ValueError("We could not read medical results from this photo. Take a clearer photo with the values in focus, or upload a PDF.")
        update_progress(50, "Checking source fields and extraction coverage...")
        result = agents.summary_agent(result)
        result = agents.simplify_agent(result)
        # Flat historical columns are not source-validated current measurements.
        result['temporal_analysis'] = ''
        result = agents.bayesian_agent(result)
        update_progress(85, "Preparing the source-validated explanation...")
        result = agents.translate_agent(result)

        update_progress(95, "Saving results...")

        if patient_id:
            db.save_report(
                patient_id=patient_id,
                report_date=result["report_date"],
                parsed_data=result["parsed_data"],
                summary=result["medical_summary"],
                simple_explanation=result["simplified_explanation"],
                translated=result["translated_explanation"],
                risk_probability=result["risk_probability"]
            )

        response = agents.format_final_response(result)
        response["extracted_text"] = raw_text
        response["input_type"] = job.get("input_type", "pdf")
        report_review.attach_review(response, raw_text, source_layout)
        response = voice_state.save(response)

        with job_lock:
            processing_jobs[job_id]["status"] = "completed"
            processing_jobs[job_id]["progress"] = 100
            processing_jobs[job_id]["message"] = "Processing complete"
            processing_jobs[job_id]["result"] = response
            processing_jobs[job_id]["completed_at"] = datetime.now().isoformat()

    except Exception as e:
        with job_lock:
            processing_jobs[job_id]["status"] = "failed"
            processing_jobs[job_id]["progress"] = processing_jobs[job_id].get("progress", 0)
            processing_jobs[job_id]["message"] = f"Processing failed: {str(e)}"
            processing_jobs[job_id]["error"] = str(e)
            processing_jobs[job_id]["failed_at"] = datetime.now().isoformat()

    finally:
        path = processing_jobs.get(job_id, {}).get('temp_file')
        if path and os.path.exists(path):
            os.remove(path)



async def review_report(request: Request):
    try:
        payload = await request.json()
        if not isinstance(payload, dict):
            raise ValueError("Provide a report review object.")
        report = payload.get("report")
        if not isinstance(report, dict):
            raise ValueError("Upload a report before reviewing results.")
        if report.get('report_id'):
            report = voice_state.get(report['report_id'])
        result = report_review.apply_review(report, payload.get("labs"), agents.infer_status_from_reference, agents.parse_numeric_value)
        language = str(payload.get("language", "English"))
        result["target_language"] = language
        result = voice_state.save(result)
        return JSONResponse(result)
    except (ValueError, TypeError, KeyError) as error:
        return JSONResponse({"detail": str(error)}, status_code=400)


async def question_report(request: Request):
    try:
        payload = await request.json()
        if not isinstance(payload, dict):
            raise ValueError("Provide a report question object.")
        report = payload.get("report")
        if not isinstance(report, dict):
            raise ValueError("Upload a report before asking questions.")
        result = report_review.answer_question(report, payload.get("question"))
        language = str(payload.get("language", "English"))
        result["answer_language"] = "English"
        if result.get("supported") and language.lower() not in ("en", "english"):
            translated = agents.translate_text(result["answer"], language)
            if translated != result["answer"]:
                result["answer"] = translated
                result["answer_language"] = language
        return JSONResponse(result)
    except (ValueError, TypeError, KeyError) as error:
        return JSONResponse({"detail": str(error)}, status_code=400)


async def reextract_report(request: Request):
    from starlette.concurrency import run_in_threadpool
    import hashlib
    temp_path, job_id = None, None
    try:
        if 'multipart/form-data' not in request.headers.get('content-type', ''):
            payload = await request.json()
            return JSONResponse(report_review.reextract(payload['report'], agents.extract_lab_values))
        form = await request.form()
        old = json.loads(str(form.get('report', '{}')))
        file = form.get('file')
        if not isinstance(file, UploadFile):
            raise ValueError('Choose the original report; your saved corrections will be retained.')
        extension = os.path.splitext(file.filename or '')[1].lower()
        if extension not in REPORT_EXTENSIONS:
            raise ValueError('Choose a PDF, JPG, PNG or WebP report.')
        data = await file.read(MAX_UPLOAD_BYTES + 1)
        await file.close()
        if not data or len(data) > MAX_UPLOAD_BYTES:
            raise ValueError('Choose a nonempty report up to 10 MB.')
        parsed = report_review.parsed_report(old.get('parsed_data', {}))
        digest = parsed.get('document', {}).get('source_digest')
        if digest and digest != hashlib.sha256(data).hexdigest():
            return JSONResponse({'detail': 'This is a different source document. The saved corrections remain unchanged.'}, status_code=409)
        with tempfile.NamedTemporaryFile(prefix='medivaanii_migrate_', suffix=extension, delete=False) as buffer:
            temp_path = buffer.name
            buffer.write(data)
        job_id = str(uuid.uuid4())
        processing_jobs[job_id] = {'status': 'processing', 'progress': 0, 'temp_file': temp_path, 'patient_id': None,
                                   'language': 'English', 'input_type': 'pdf' if extension == '.pdf' else 'photo'}
        await run_in_threadpool(process_report_async, job_id)
        job = processing_jobs[job_id]
        if job['status'] != 'completed':
            raise ValueError(job.get('error', 'Source reading failed. Your saved edits remain unchanged.'))
        result = report_review.migrate_corrections(old, job['result'], agents.infer_status_from_reference, agents.parse_numeric_value)
        result['target_language'] = 'English'
        if old.get('report_id'):
            result['report_id'] = old['report_id']
        result = voice_state.save(result)
        return JSONResponse(result)
    except (ValueError, TypeError, KeyError) as error:
        return JSONResponse({'detail': str(error)}, status_code=400)
    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)
        if job_id:
            processing_jobs.pop(job_id, None)


def safe_history_report(report):
    result = dict(report)
    result['extraction_quality'] = report_quality(result)
    if not can_generate_report_output(result):
        for key in ('summary', 'medical_summary', 'simple_explanation', 'translated', 'translated_explanation'):
            result[key] = ''
    return result


async def get_patient_history(request: Request):
    patient_id = request.path_params.get("patient_id")
    limit = int(request.query_params.get("limit", 10))
    try:
        reports = db.get_patient_reports(patient_id, limit)
        return JSONResponse({
            "patient_id": patient_id,
            "report_count": len(reports),
            "reports": [safe_history_report(r) for r in reports]
        })
    except Exception as e:
        return JSONResponse({"detail": str(e)}, status_code=500)


async def get_temporal_analysis(request: Request):
    patient_id = request.path_params.get("patient_id")
    try:
        reports = db.get_patient_reports(patient_id, limit=50)

        if not reports:
            return JSONResponse({
                "patient_id": patient_id,
                "message": "No historical data available",
                "time_series": {},
                "trends": []
            })

        # Build time-series: {test_name: [{date, value, unit, ref_low, ref_high, status}]}
        import re as _re
        time_series = {}

        for report in sorted(reports, key=lambda r: r.get("report_date", "")):
            report_date = report.get("report_date", "")
            try:
                parsed = json.loads(report.get("parsed_data", "{}"))
            except Exception:
                continue

            for lab in eligible_measurements(parsed) if can_generate_report_output(report) else []:
                test_name = lab.get("test_name", "").strip()
                if not test_name:
                    continue
                try:
                    numeric_value = float(str(lab.get("value", "")).replace(",", ""))
                except Exception:
                    continue

                unit      = lab.get("unit", "")
                ref_range = lab.get("reference_range", "")
                status    = lab.get("status", "unknown")

                # Parse reference range
                ref_low = ref_high = None
                if ref_range:
                    m = _re.search(
                        r"([0-9]+(?:\.[0-9]+)?)\s*(?:–|-|to)\s*([0-9]+(?:\.[0-9]+)?)",
                        ref_range, _re.IGNORECASE
                    )
                    if m:
                        ref_low  = float(m.group(1))
                        ref_high = float(m.group(2))
                    else:
                        lt = _re.search(r"<\s*([0-9]+(?:\.[0-9]+)?)", ref_range)
                        gt = _re.search(r">\s*([0-9]+(?:\.[0-9]+)?)", ref_range)
                        if lt:
                            ref_low, ref_high = 0.0, float(lt.group(1))
                        elif gt:
                            ref_low = float(gt.group(1))

                if test_name not in time_series:
                    time_series[test_name] = []

                time_series[test_name].append({
                    "date":      report_date,
                    "value":     numeric_value,
                    "unit":      unit,
                    "ref_range": ref_range,
                    "ref_low":   ref_low,
                    "ref_high":  ref_high,
                    "status":    status,
                })

        # Only keep tests that appear in at least 1 report (show all for single report too)
        # Sort each test's data by date ascending
        for test in time_series:
            time_series[test].sort(key=lambda x: x["date"])

        # Detect trends across multiple reports
        trend_summary = []
        for test, points in time_series.items():
            if len(points) >= 2:
                first_val = points[0]["value"]
                last_val  = points[-1]["value"]
                change    = last_val - first_val
                pct_change = round((change / first_val) * 100, 1) if first_val != 0 else 0
                direction = "improving" if abs(last_val) < abs(first_val) else "worsening"
                statuses  = [p["status"] for p in points]
                if all(s in ("high", "critical") for s in statuses):
                    pattern = "persistently_high"
                elif all(s == "low" for s in statuses):
                    pattern = "persistently_low"
                elif statuses[-1] in ("high", "critical") and statuses[0] == "normal":
                    pattern = "newly_elevated"
                elif statuses[-1] == "normal" and statuses[0] in ("high", "low", "critical"):
                    pattern = "normalising"
                else:
                    pattern = "fluctuating"

                trend_summary.append({
                    "test":       test,
                    "pattern":    pattern,
                    "direction":  direction,
                    "pct_change": pct_change,
                    "first":      first_val,
                    "last":       last_val,
                    "unit":       points[-1]["unit"],
                    "count":      len(points),
                })

        return JSONResponse({
            "patient_id":   patient_id,
            "total_reports": len(reports),
            "time_series":  time_series,
            "trend_summary": trend_summary,
            "analysis_date": datetime.now().isoformat(),
        })

    except Exception as e:
        return JSONResponse({"detail": str(e)}, status_code=500)


def analyze_temporal_trends(reports: List[dict]) -> dict:
    trends = []
    alerts = []
    test_values = {}
    for report in reports:
        try:
            parsed = json.loads(report.get("parsed_data", "{}"))
            for lab in eligible_measurements(parsed) if can_generate_report_output(report) else []:
                test_name = lab.get("test_name", "")
                if test_name not in test_values:
                    test_values[test_name] = []
                test_values[test_name].append({
                    "value": lab.get("value"),
                    "status": lab.get("status"),
                    "date": report.get("report_date")
                })
        except Exception:
            continue

    for test, values in test_values.items():
        if len(values) >= 2:
            statuses = [v["status"] for v in values]
            if all(s == "low" for s in statuses):
                trends.append({
                    "test": test,
                    "pattern": "persistently_low",
                    "occurrences": len(values),
                    "recommendation": f"Consider further investigation for {test}"
                })
            elif all(s == "high" for s in statuses):
                trends.append({
                    "test": test,
                    "pattern": "persistently_high",
                    "occurrences": len(values),
                    "recommendation": f"Monitor {test} levels closely"
                })

    return {
        "patient_id": reports[0].get("patient_id") if reports else None,
        "total_reports": len(reports),
        "trends": trends,
        "alerts": alerts,
        "analysis_date": datetime.now().isoformat()
    }


async def process_text_report(request: Request):
    try:
        form = await request.form()
        text = form.get("text")
        patient_id = form.get("patient_id")
        language = "English"  # Voice language is selected independently; extraction uses no translation provider.

        if not text:
            return JSONResponse({"detail": "Missing text field"}, status_code=400)

        state = agents.get_default_state(
            raw_text=text,
            patient_id=patient_id,
            target_lang=language
        )

        state = agents.parse_agent(state)
        state = agents.validation_agent(state)
        state = agents.summary_agent(state)
        state = agents.simplify_agent(state)
        state = agents.temporal_agent(state)
        state = agents.bayesian_agent(state)
        state = agents.translate_agent(state)

        response = agents.format_final_response(state)

        return JSONResponse(content=response)

    except Exception as e:
        return JSONResponse({"detail": str(e)}, status_code=500)


async def retranslate_report(request: Request):
    """Retranslate an already-processed report into a new language without re-uploading."""
    try:
        body = await request.json()
        if not can_generate_report_output(body):
            return JSONResponse({'detail': 'Read the original source again or check uncertain fields before translating this report.'}, status_code=409)
        parsed_data     = body.get("parsed_data", "")
        language        = body.get("language", "Hindi")
        suggestions     = body.get("suggestions", [])
        medical_summary = body.get("medical_summary", "")
        simplified      = body.get("simplified_explanation", "")
        temporal        = body.get("temporal_analysis", "")
        bayesian        = body.get("causal_analysis", "")
        risk            = body.get("risk_probability", 0.0)
        patient_id      = body.get("patient_id")
        report_date     = body.get("report_date", datetime.now().isoformat())
        disease_en      = body.get("disease_explanation_en", "")
        solution_en     = body.get("solution_plan_en", "")

        state = agents.get_default_state("", patient_id=patient_id, target_lang=language)
        state["parsed_data"]            = parsed_data
        state["medical_summary"]        = medical_summary
        state["simplified_explanation"] = simplified
        state["temporal_analysis"]      = temporal
        state["bayesian_analysis"]      = bayesian
        state["risk_probability"]       = risk
        state["suggestions"]            = suggestions
        state["target_language"]        = language
        state["report_date"]            = report_date
        state["disease_explanation_en"] = disease_en
        state["solution_plan_en"]       = solution_en

        grounded = report_review.content(report_review.parsed_report(parsed_data))
        state.update(medical_summary=grounded['medical_summary'], simplified_explanation=grounded['simple_explanation'],
                     suggestions=grounded['suggestions'], disease_explanation_en=grounded['disease_explanation_en'], solution_plan_en=grounded['solution_plan_en'])
        state = agents.translate_agent(state)
        response = agents.format_final_response(state)
        return JSONResponse(content=response)

    except Exception as e:
        return JSONResponse({"detail": str(e)}, status_code=500)


# ============== TTS Endpoint ==============
async def synthesize_speech(request: Request):
    """Neural narration using the same explicit locales as the voice agent."""
    from neural_tts import synthesize, NeuralSpeechError
    try:
        body = await request.json()
        language = str(body.get('language', '')).strip().lower()
        aliases = {'english': 'en', 'hindi': 'hi', 'spanish': 'es', 'mandarin': 'zh',
                   'mandarin chinese': 'zh', 'chinese': 'zh'}
        language = aliases.get(language, language)
        audio, info = await synthesize(str(body.get('text', '')).strip(), language,
                                       slower=body.get('slower') is True)
        return StreamingResponse(iter([audio]), media_type='audio/mpeg',
                                 headers={'Cache-Control': 'no-store', 'X-TTS-Voice': info['tts_voice']})
    except ValueError as error:
        return JSONResponse({'detail': str(error)}, status_code=400)
    except NeuralSpeechError as error:
        return JSONResponse({'detail': str(error)}, status_code=503)


app = Starlette(debug=True, routes=[
    Route("/", lambda request: JSONResponse({
        "message": "Medical CDSS API - Clinical Decision Support System",
        "version": "2.0.0",
        "endpoints": {
            "upload": "/upload",
            "job_status": "/job/{job_id}",
            "patient_history": "/patient/{patient_id}/history",
            "temporal_analysis": "/patient/{patient_id}/temporal",
            "languages": "/languages",
            "health": "/health"
        }
    })),
    Route("/health", lambda request: JSONResponse({"status": "healthy", "timestamp": datetime.now().isoformat()})),
    Route("/languages", lambda request: JSONResponse({
        "languages": [
            {"code": "hi", "name": "Hindi", "native_name": "हिन्दी"},
            {"code": "bn", "name": "Bengali", "native_name": "বাংলা"},
            {"code": "ta", "name": "Tamil", "native_name": "தமிழ்"},
            {"code": "te", "name": "Telugu", "native_name": "తెలుగు"},
            {"code": "mr", "name": "Marathi", "native_name": "मराठी"},
            {"code": "gu", "name": "Gujarati", "native_name": "ગુજરાતી"},
            {"code": "kn", "name": "Kannada", "native_name": "ಕನ್ನಡ"},
            {"code": "ml", "name": "Malayalam", "native_name": "മലയാളം"},
            {"code": "pa", "name": "Punjabi", "native_name": "ਪੰਜਾਬੀ"},
            {"code": "or", "name": "Odia", "native_name": "ଓଡ଼ିଆ"},
            {"code": "as", "name": "Assamese", "native_name": "অসমীয়া"},
            {"code": "ur", "name": "Urdu", "native_name": "اردو"},
        ]
    })),
    Route("/upload", upload_report, methods=["POST"]),
    Route('/api/voice/turn', voice_turn, methods=['POST']),
    Route('/voice/turn', voice_turn, methods=['POST']),
    Route('/api/report/sync', sync_voice_report, methods=['POST']),
    Route('/report/sync', sync_voice_report, methods=['POST']),
    Route("/report/review", review_report, methods=["POST"]),
    Route("/report/reextract", reextract_report, methods=["POST"]),
    Route("/report/question", question_report, methods=["POST"]),
    Route("/report/source-layout", source_layout_report, methods=["POST"]),
    Route("/retranslate", retranslate_report, methods=["POST"]),
    Route("/job/{job_id}", get_job_status),
    Route("/patient/{patient_id}/history", get_patient_history),
    Route("/patient/{patient_id}/temporal", get_temporal_analysis),
    Route("/text/", process_text_report, methods=["POST"]),
    Route("/synthesize", synthesize_speech, methods=["POST"]),
])

import os as _os

# In production, set ALLOWED_ORIGINS=https://your-site.netlify.app
# Leave unset (or "*") for local development
_raw_origins = _os.getenv("ALLOWED_ORIGINS", "*")
_allow_origins = (
    [o.strip() for o in _raw_origins.split(",")]
    if _raw_origins != "*"
    else ["*"]
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, timeout_keep_alive=120)
