# Local voice MVP

Open **http://127.0.0.1:3000/** while the two local servers are running.

Upload a PDF or clear printed report photo, open Explanation, select English,
हिन्दी, Español or 中文, then type a question or tap the microphone. Allow
microphone access when Chrome asks. Tap Send question to finish recording.
Stop interrupts playback; Repeat, Slower and Simpler operate on the last answer
in the selected language. Selecting a source chip opens its highlighted result.

## Runtime

- Whisper multilingual `base`, through faster-whisper, transcribes locally.
- Ollama `qwen3:1.7b` generates short JSON answers with `think: false`.
- Every extracted measurement and recent conversation is supplied to the model.
  Very long supplementary text uses selected passages, disclosed in the response.
- Edge neural voices: `en-IN-NeerjaNeural`, `hi-IN-SwaraNeural`,
  `es-MX-DaliaNeural`, `zh-CN-XiaoxiaoNeural`. Slower uses `rate="-20%"`.
- If `SARVAM_API_KEY` is present in the backend process environment, English and
  Hindi try Sarvam Bulbul v3 first, then the same-language Edge voice.
- Speech synthesis needs internet and sends the answer text to the speech provider.
  Edge uses no API key. Configured Sarvam use is subject to that account's billing.
  There is no gTTS, OS voice or cross-language fallback in either speech endpoint.
- Latest reports, corrections and recent messages are saved in
  `backend/.local/voice_mvp.sqlite3`. This is a local, single-user MVP.

## Restart on this workspace

Run Ollama first: `brew services start ollama`. Ensure the model exists with
`ollama list`; if missing, run `ollama pull qwen3:1.7b`.

Backend, in a terminal:

```sh
cd /Users/anant/Documents/Codex/2026-10-09/ana/work/Medical-Translation/backend
/Users/anant/Documents/Codex/2026-10-09/ana/work/voice-mvp-venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8001
```

Frontend, in another terminal:

```sh
cd /Users/anant/Documents/Codex/2026-10-09/ana/work/Medical-Translation
/Users/anant/Documents/Codex/2026-10-09/ana/work/voice-mvp-venv/bin/python scripts/serve_local.py --port 3000
```

The frontend server serves `flutter_app/build/web` and proxies `/api/*` to port
8001. Do not use a bare static-file server, which will omit the API proxy.

After editing Flutter, rebuild from `flutter_app`:

```sh
/Users/anant/Documents/Codex/2026-10-09/ana/work/flutter-sdk/bin/flutter build web --no-pub --no-tree-shake-icons --no-wasm-dry-run --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

## Limits

The first turn can be slower while the local models load. Response time also
depends on report length and the online speech service; 1–3 seconds is not a
guaranteed end-to-end latency. This is tap-to-talk, not a continuous phone call.
The extractor currently targets printed English source reports. Handwriting,
blurred photos and unfamiliar layouts can be incomplete; four spoken languages
do not imply four-language source OCR. The model explains available extracted
content rather than guaranteeing every report was read correctly. Citation IDs
are checked against supplied measurements; generated medical explanations still
need broader evaluation. This MVP is not a diagnostic or prescribing system.

## Smoke check on 15 October 2026

Flutter web build and `flutter analyze --no-pub lib` passed. An anonymous PDF
loaded through upload and the report viewer. Generated questions completed
Whisper → Qwen → Edge speech in en/hi/es/zh, preserving 43 ng/mL after a server
correction. Repeat, slower synthesis, Simpler and an unsupported-locale rejection
were checked. The UI correction saved 43, the voice card answered with 43, and
four source-cell boxes received the voice highlight. Stop returned to Ready.

These were smoke checks, not clinical or native-speaker acceptance. Sample
end-to-end turns took 17–48 seconds. Hindi transcription was imperfect and one
live microphone attempt returned no clear speech. Generated explanations also
need stronger review: the small model can overstate what an in-range result
means. Do not represent this pilot as universally accurate or ready for release.
