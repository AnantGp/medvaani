"""Four explicit neural locales; never substitute another language or basic TTS."""
import asyncio
import hashlib
import logging
import os
import subprocess
import tempfile
from pathlib import Path

from starlette.concurrency import run_in_threadpool
import edge_tts_voices

VOICES = {code: edge_tts_voices.LANGUAGE_TO_EDGE_VOICE[code] for code in ('en', 'hi', 'es', 'zh')}
_cache = {}
log = logging.getLogger(__name__)


class NeuralSpeechError(Exception):
    pass


def _sarvam_mp3(text, language):
    import sarvam_tts
    wav = sarvam_tts.synthesize(text, language)
    with tempfile.TemporaryDirectory(prefix='medivaanii_neural_') as folder:
        source, target = Path(folder) / 'voice.wav', Path(folder) / 'voice.mp3'
        source.write_bytes(wav)
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(source),
                        '-codec:a', 'libmp3lame', '-b:a', '96k', str(target)],
                       capture_output=True, check=True, timeout=30)
        return target.read_bytes()


async def synthesize(text, language, *, slower=False):
    if language not in VOICES:
        raise ValueError('Choose English, Hindi, Spanish or Mandarin.')
    if not text.strip() or len(text) > 2400:
        raise ValueError('Speak a nonempty explanation of up to 2,400 characters.')
    sarvam_configured = language in ('en', 'hi') and bool(os.getenv('SARVAM_API_KEY', '').strip())
    key = hashlib.sha256(f'{language}:{slower}:{sarvam_configured}:{text}'.encode()).hexdigest()
    if key in _cache:
        return _cache[key]
    result = None
    if sarvam_configured:
        try:
            audio = await asyncio.wait_for(run_in_threadpool(_sarvam_mp3, text, language), 60)
            result = (audio, {'tts_provider': 'sarvam', 'tts_voice': 'bulbul:v3/priya',
                              'playback_rate': .85 if slower else 1.0})
        except Exception as error:
            log.warning('Sarvam unavailable (%s); trying the same-language Edge neural voice.', type(error).__name__)
    if result is None:
        try:
            audio = await asyncio.wait_for(edge_tts_voices.synthesize(
                text, language, rate='-20%' if slower else '-8%'), 45)
            result = (audio, {'tts_provider': 'edge-tts', 'tts_voice': VOICES[language], 'playback_rate': 1.0})
        except Exception as error:
            log.warning('Neural speech unavailable for %s (%s).', language, type(error).__name__)
            raise NeuralSpeechError('The neural voice service is unavailable. Check your internet connection and try again. No substitute voice was used.') from error
    if len(_cache) >= 16:
        _cache.clear()
    _cache[key] = result
    return result
