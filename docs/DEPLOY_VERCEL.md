# Deploy Medivaanii on Vercel

## Current setup

Project: `medvaani`, scope: `anants-projects-62dcac1f`.
Source: `AnantGp/medvaani`, branch: `feature/groq-vercel-mvp`.
The previous working local MVP is on `snapshot/local-voice-mvp`.

The Groq key is a sensitive Vercel environment variable for production and preview. Never put it in Flutter, Dart defines, public JavaScript, a command argument, or Git.

## Exact CLI commands

Run from the repository root:

```bash
npm install -g vercel
vercel login
vercel link --project medvaani --scope anants-projects-62dcac1f --yes
vercel deploy --prod --yes
```

For another project or a replacement key, add it through the secure prompt:

```bash
vercel env add GROQ_API_KEY production
vercel env add GROQ_API_KEY preview
vercel deploy --prod --yes
```

The build script downloads Flutter 3.47.7, builds `flutter_app/build/web` with `API_BASE_URL=/api`, and Vercel packages `api/index.py` plus the backend with root `requirements.txt`. Python 3.12 is selected by `pyproject.toml`.

## Providers

- ASR: Groq `whisper-large-v3-turbo`, explicit selected `en`, `hi`, `es` or `zh` and medical vocabulary hints.
- Explanation and Vision: `qwen/qwen3.8-27b`, no thinking. Override with `GROQ_LLM_MODEL` and `GROQ_VISION_MODEL`.
- Explanation fallback: `llama-3.3-70b-versatile` when the account catalog offers it, otherwise `openai/gpt-oss-20b` with low hidden reasoning. The live catalog is checked before selecting models.
- The originally requested Qwen 32B and Scout models were retired in July 2026. See [Groq deprecations](https://console.groq.com/docs/deprecations).
- Edge voices: `en-IN-NeerjaNeural`, `hi-IN-SwaraNeural`, `es-MX-DaliaNeural`, `zh-CN-XiaoxiaoNeural`. Slower uses `-20%` synthesis rate. No gTTS or OS voice fallback.
- Optional `SARVAM_API_KEY`: Bulbul v3 first for Hindi and English, then the same-language Edge voice if unavailable.

## Serverless behavior and limits

Each voice/review request carries the browser's current compact report snapshot. Voice also carries the last eight conversation messages and last answer, so Repeat and Slower survive an instance change. SQLite uses `/tmp/medivaanii.db`; it is a temporary cache. The browser remains responsible for its active report and corrections.

Report uploads: under 4 MB; audio: under 2 MB and one minute; compact report snapshot: under 2 MB. The combined multipart request must remain below 4.4 MB. Vercel imposes a 4.5 MB function request/response limit. PDFs may have up to 100 pages, but cloud OCR is limited to eight scanned pages per upload to bound free API usage; unread pages are reported as incomplete. Digital PDFs do not consume Vision calls unless a page needs OCR.

Free API quotas and Vercel quotas apply. Hobby hosting is for personal, noncommercial use; a commercial launch needs an appropriate plan. Edge TTS is a best-effort online service with no service guarantee. If it fails, the app reports an error and never substitutes another language or robotic voice.

No Torch, Docling, local Whisper weights or Ollama is installed in the cloud function. PDFium is bundled as a Python wheel, so scans do not need system Tesseract or Poppler.

## Smoke check

1. Open the production URL and upload a small sample PDF or clear photo.
2. Compare the numbers and references with the source; review uncertain OCR rows.
3. Ask in all four languages. Confirm the printed number/unit and matching source highlight.
4. Test Stop, Repeat, Slower and Simpler.
5. Correct a value and ask again. The next response should use that corrected value.

The anonymous local Groq smoke test passed four-language ASR, JSON explanation, neural speech, citations, report restoration after deleting its temporary server record, live correction, photo OCR and scanned-PDF OCR. ASR plus explanation took about 0.7–1.3 seconds; total time including speech generation was about 3–11 seconds. These are sample measurements, not a latency guarantee for long reports or cold starts.
