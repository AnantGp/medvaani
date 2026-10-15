"""
Text-to-speech using ElevenLabs Multilingual v2.

Free tier: 10,000 characters/month, no credit card required.
Get your key at: https://elevenlabs.io/app/settings/api-keys
Add it to Render's Environment as: ELEVENLABS_API_KEY

Voice selection strategy: instead of hardcoding a voice ID that may be
a "library voice" (which requires a paid plan), we dynamically fetch the
voices available in the user's account and pick the best multilingual one.
'premade' and 'generated' category voices work on all plans including free.
Falls back to Edge TTS -> gTTS if key is missing or all voices fail.
"""

import os
from elevenlabs.client import ElevenLabs
from elevenlabs import VoiceSettings

MODEL_ID = "eleven_multilingual_v2"

# Voice settings tuned for medical report narration
VOICE_SETTINGS = VoiceSettings(
    stability=0.55,
    similarity_boost=0.75,
    style=0.25,
    use_speaker_boost=True,
)

LANGUAGE_CODE_MAP = {
    "en": "en-IN",
    "hi": "hi-IN",
    "bn": "bn-IN",
    "ta": "ta-IN",
    "te": "te-IN",
    "mr": "mr-IN",
    "gu": "gu-IN",
    "kn": "kn-IN",
    "ml": "ml-IN",
    "pa": "hi-IN",
    "or": "hi-IN",
    "as": "bn-IN",
    "ur": "hi-IN",
}

MAX_CHARS = 4500

# Cache the picked voice ID so we don't re-fetch voices on every request
_cached_voice_id: str | None = None


class ElevenLabsConfigError(Exception):
    """Raised when ELEVENLABS_API_KEY is not set."""


class ElevenLabsTtsError(Exception):
    """Raised when the API call itself fails."""


def _get_client():
    key = os.getenv("ELEVENLABS_API_KEY", "").strip()
    if not key:
        raise ElevenLabsConfigError(
            "ELEVENLABS_API_KEY is not set. "
            "Get a free key at https://elevenlabs.io/app/settings/api-keys"
        )
    return ElevenLabs(api_key=key)


def _pick_voice(client: ElevenLabs) -> str:
    """Fetches voices from the user's account and returns the best voice ID
    that will work on their current plan (prefers premade/generated over
    library voices which require paid plans)."""
    global _cached_voice_id
    if _cached_voice_id:
        return _cached_voice_id

    try:
        response = client.voices.get_all()
        voices = response.voices if hasattr(response, 'voices') else []

        # Priority order: premade first (guaranteed free), then generated,
        # then anything else. Within each category prefer female voices
        # (tend to be clearer for medical content)
        def score(v):
            cat = getattr(v, 'category', '') or ''
            name = (getattr(v, 'name', '') or '').lower()
            s = 0
            if cat == 'premade':
                s += 100
            elif cat == 'generated':
                s += 80
            elif cat == 'cloned':
                s += 60
            # Prefer female/neutral-sounding voices for medical narration
            if any(w in name for w in ['rachel', 'aria', 'sarah', 'jessica',
                                        'alice', 'lily', 'grace', 'sophie',
                                        'priya', 'female', 'woman']):
                s += 10
            return s

        if voices:
            best = max(voices, key=score)
            _cached_voice_id = best.voice_id
            print(f"[elevenlabs] selected voice: {best.name} "
                  f"(id={best.voice_id}, category={getattr(best, 'category', 'unknown')})")
            return _cached_voice_id

    except Exception as e:
        print(f"[elevenlabs] could not fetch voices: {e}")

    # Absolute fallback: use the first default voice ElevenLabs assigns
    # to every new account — this always exists and is always free
    _cached_voice_id = "JBFqnCBsd6RMkjVDRZzb"  # George — ElevenLabs default
    return _cached_voice_id


def _split_text(text: str, max_len: int = MAX_CHARS) -> list:
    text = text.strip()
    if len(text) <= max_len:
        return [text]
    chunks = []
    while len(text) > max_len:
        slice_ = text[:max_len]
        cut = max(
            slice_.rfind('. '), slice_.rfind('! '),
            slice_.rfind('? '), slice_.rfind('\n'),
        )
        cut = cut + 1 if cut > 0 else max_len
        chunks.append(text[:cut].strip())
        text = text[cut:].strip()
    if text:
        chunks.append(text)
    return chunks


def synthesize(text: str, language_code: str = "en") -> bytes:
    """Synthesize text using ElevenLabs. Returns raw MP3 bytes."""
    client = _get_client()
    voice_id = _pick_voice(client)
    bcp47 = LANGUAGE_CODE_MAP.get(language_code, "hi-IN")
    chunks = _split_text(text)

    print(f"[elevenlabs] synthesizing {len(text)} chars, "
          f"lang={language_code} ({bcp47}), model={MODEL_ID}, "
          f"voice={voice_id}, chunks={len(chunks)}")

    audio_parts = []
    for i, chunk in enumerate(chunks):
        if not chunk:
            continue
        try:
            audio_iter = client.text_to_speech.convert(
                voice_id=voice_id,
                text=chunk,
                model_id=MODEL_ID,
                language_code=bcp47,
                voice_settings=VOICE_SETTINGS,
                output_format="mp3_44100_128",
                apply_text_normalization="auto",
            )
            chunk_bytes = b"".join(audio_iter)
            if chunk_bytes:
                audio_parts.append(chunk_bytes)
                print(f"[elevenlabs] chunk {i+1}/{len(chunks)}: "
                      f"{len(chunk_bytes)} bytes OK")
        except Exception as e:
            print(f"[elevenlabs] chunk {i+1}/{len(chunks)} FAILED: {e}")
            raise ElevenLabsTtsError(f"ElevenLabs API error: {e}") from e

    if not audio_parts:
        raise ElevenLabsTtsError("ElevenLabs returned no audio.")

    total = sum(len(p) for p in audio_parts)
    print(f"[elevenlabs] total audio: {total} bytes")
    return b"".join(audio_parts)
