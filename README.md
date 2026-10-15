# Medivaanii

A Flutter Web and Python Starlette MVP for reading medical reports and discussing them by voice in English, Hindi, Spanish and Mandarin.

Upload a PDF or photo, inspect its extracted results beside the original document, correct a value, and ask about any test or report section. Spoken answers cite measurement IDs so the viewer can highlight the corresponding source.

## Hosted MVP

The Vercel deployment serves Flutter static files and `/api` Python functions from one origin. Groq Whisper handles speech recognition, a hosted Qwen model explains the current report, and Edge neural voices speak the answer. No local model server is needed.

See [deployment commands and operating limits](docs/DEPLOY_VERCEL.md). The previous local-model implementation is preserved on `snapshot/local-voice-mvp`; hosted changes are on `feature/groq-vercel-mvp`.

## Local development with Groq

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp backend/.env.example backend/.env.local
# Set GROQ_API_KEY in the ignored backend/.env.local file.
cd backend
../.venv/bin/uvicorn main:app --port 8001
```

In a second terminal:

```bash
cd flutter_app
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

## Data flow

Digital PDFs use pdfplumber to preserve source coordinates. When native OCR is unavailable, photos and scanned PDF pages are rendered with Pillow/PDFium and read by Groq Vision. Vision row locations are estimates and require review. Local Docling support remains optional; it is excluded from the Vercel bundle.

The browser sends a compact current report snapshot and recent conversation with each voice turn. This restores context after a serverless cold start. Corrections update SQLite immediately; the next turn sends the corrected snapshot. Vercel `/tmp` storage is temporary, not durable report storage.

Uploaded health information and questions used for voice explanations are sent to Groq; answer text is sent to Microsoft Edge speech, or Sarvam when configured. Original files and report snapshots remain in browser storage until cleared. This is a pilot, not a diagnosis or medication-prescribing service. Extraction accuracy must be checked against each source document.
