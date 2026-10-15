"""
Text-to-speech using Sarvam AI's Bulbul v3 model (official Python SDK).

Sarvam AI is purpose-built for Indian languages -- unlike ElevenLabs or
Edge TTS which adapt English/Western models, Bulbul v3 was trained from
scratch on Indian speech data. This gives correct phoneme generation,
natural intonation, and handling of code-mixed text (Hinglish etc.)

Model: bulbul:v3
- 11 languages: Hindi, Bengali, Tamil, Telugu, Gujarati, Kannada,
  Malayalam, Marathi, Punjabi, Odia, English (Indian accent)
- 39 voices, male and female
- Max 2500 characters per request (handled via chunking below)
- Returns base64-encoded WAV/MP3 audio

Speaker: anushka (clear, professional female voice -- good for medical)
Other good options: priya, neha, kavya (female), rahul, rohan (male)

Get a free API key (no credit card): https://dashboard.sarvam.ai
Add it to Render Environment as: SARVAM_API_KEY
"""

import base64
import os

from sarvamai import SarvamAI

MODEL = "bulbul:v3"
DEFAULT_SPEAKER = "priya"  # v3-compatible; anushka is v2-only

# BCP-47 language codes Sarvam expects
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
    "pa": "pa-IN",
    "or": "od-IN",   # Sarvam uses od-IN for Odia
    "as": "bn-IN",   # no Assamese; Bengali is closest
    "ur": "hi-IN",   # no Urdu; Hindi is closest
}

# bulbul:v3 allows up to 2500 chars per request.
# Keep a small margin for safety.
MAX_CHARS = 2400


class SarvamConfigError(Exception):
    """Raised when SARVAM_API_KEY is not set in the environment."""


class SarvamTtsError(Exception):
    """Raised when the Sarvam API call itself fails."""


def _get_client() -> SarvamAI:
    key = os.getenv("SARVAM_API_KEY", "").strip()
    if not key:
        raise SarvamConfigError(
            "SARVAM_API_KEY is not set. "
            "Get a free key at https://dashboard.sarvam.ai "
            "and add it to Render's Environment variables as SARVAM_API_KEY."
        )
    return SarvamAI(api_subscription_key=key)


def _split_text(text: str, max_len: int = MAX_CHARS) -> list:
    """Split at sentence boundaries so each chunk fits within the API limit."""
    text = text.strip()
    if len(text) <= max_len:
        return [text]

    chunks = []
    while len(text) > max_len:
        slice_ = text[:max_len]
        cut = max(
            slice_.rfind('. '),
            slice_.rfind('! '),
            slice_.rfind('? '),
            slice_.rfind('\n'),
        )
        cut = cut + 1 if cut > 0 else max_len
        chunks.append(text[:cut].strip())
        text = text[cut:].strip()

    if text:
        chunks.append(text)
    return chunks


def synthesize(text: str, language_code: str = "en") -> bytes:
    """
    Synthesize `text` using Sarvam Bulbul v3.
    Returns raw MP3 bytes (base64-decoded from the API response).
    Raises SarvamConfigError (no key) or SarvamTtsError (API failure).
    """
    client = _get_client()
    lang = LANGUAGE_CODE_MAP.get(language_code, "hi-IN")
    chunks = _split_text(text)

    print(f"[sarvam] synthesizing {len(text)} chars, "
          f"lang={language_code} ({lang}), model={MODEL}, "
          f"speaker={DEFAULT_SPEAKER}, chunks={len(chunks)}")

    audio_parts = []
    for i, chunk in enumerate(chunks):
        if not chunk:
            continue
        try:
            response = client.text_to_speech.convert(
                text=chunk,
                target_language_code=lang,
                speaker=DEFAULT_SPEAKER,
                model=MODEL,
                pace=1.0,
                speech_sample_rate=22050,
                enable_preprocessing=True,
                output_audio_codec="wav",
            )
            # response.audios is a list of base64-encoded audio strings.
            # Each call with a single `text` returns exactly one audio item.
            if not response.audios:
                raise SarvamTtsError("Sarvam API returned empty audios list.")

            audio_bytes = base64.b64decode(response.audios[0])
            audio_parts.append(audio_bytes)
            print(f"[sarvam] chunk {i+1}/{len(chunks)}: {len(audio_bytes)} bytes OK")

        except SarvamTtsError:
            raise
        except Exception as e:
            print(f"[sarvam] chunk {i+1}/{len(chunks)} FAILED: {e}")
            raise SarvamTtsError(f"Sarvam API error: {e}") from e

    if not audio_parts:
        raise SarvamTtsError("No audio produced.")

    total = sum(len(p) for p in audio_parts)
    print(f"[sarvam] total audio: {total} bytes ({len(audio_parts)} chunks)")
    return b"".join(audio_parts)
