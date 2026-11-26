"""Hosted speech recognition and JSON explanations; no local ML imports."""
import asyncio
import json
import logging
import os
import re
import time

import httpx

log = logging.getLogger('medivaanii.groq')

BASE_URL = 'https://api.groq.com/openai/v1'
_models = None
_models_at = 0


class GroqError(Exception):
    def __init__(self, message, status=503):
        super().__init__(message)
        self.status = status


def configured():
    return bool(os.getenv('GROQ_API_KEY', '').strip())


def headers():
    key = os.getenv('GROQ_API_KEY', '').strip()
    if not key:
        raise GroqError('Speech and explanations are not configured on this server.')
    return {'Authorization': 'Bearer ' + key}


def error_for(response):
    if response.status_code == 413:
        return GroqError('This report exceeds the free AI request allowance. Try a shorter report or a single clear report page.', 413)
    if response.status_code == 429:
        return GroqError('The free AI quota is busy or exhausted. Please wait and try again.', 429)
    if response.status_code in (401, 403):
        return GroqError('The AI service key or model permission needs updating.')
    return GroqError('The AI service is temporarily unavailable. Please try again.')


async def available_models(client):
    global _models, _models_at
    if _models is not None and time.monotonic() - _models_at < 600:
        return _models
    response = await client.get(BASE_URL + '/models', headers=headers())
    if response.is_success:
        _models = {item['id'] for item in response.json()['data']}
        _models_at = time.monotonic()
    return _models


def reasoning_options(model):
    if model.startswith('qwen/'):
        return {'reasoning_effort': 'none'}
    if model.startswith('openai/gpt-oss'):
        return {'reasoning_effort': 'low', 'reasoning_format': 'hidden'}
    return {}


def parse_json(content):
    content = re.sub(r'<think>.*?</think>', '', str(content), flags=re.S).strip()
    content = re.sub(r'^```(?:json)?\s*|\s*```$', '', content)
    return json.loads(content)


# Free-tier limits are per model and per minute, so each model is a separate
# pool of allowance. A model that answered 429 is skipped until Groq's own
# reset time instead of being asked again on every request.
_cooldown = {}
RETRY_WAIT_LIMIT = 20  # seconds a request may wait for a reset before giving up


def _retry_after(response):
    try:
        return max(1.0, float(response.headers.get('retry-after', '')))
    except ValueError:
        return 10.0


async def chat_json(messages, *, vision=False, max_tokens=600, temperature=.2):
    # Qwen 3 32B and Scout were retired in July 2026, and Llama 3.3 70B is no
    # longer offered to this key. Unavailable IDs are skipped using the live
    # catalog; environment overrides remain possible.
    primary = os.getenv('GROQ_VISION_MODEL' if vision else 'GROQ_LLM_MODEL', 'qwen/qwen3.8-27b')
    candidates = [primary] if vision else list(dict.fromkeys([
        primary, 'openai/gpt-oss-120b', 'openai/gpt-oss-20b', 'llama-3.3-70b-versatile']))
    async with httpx.AsyncClient(timeout=httpx.Timeout(60, connect=10)) as client:
        active = await available_models(client)
        candidates = [model for model in candidates if active is None or model in active]
        if not candidates:
            raise GroqError('The configured AI model is no longer available. Update the model setting.')
        last_error = None
        budget = max_tokens
        for attempt in range(2):
            now = time.monotonic()
            ready = [m for m in candidates if _cooldown.get(m, 0) <= now]
            if not ready:
                # Every model is inside its per-minute limit. Wait for the
                # earliest reset when it is close, rather than failing at once.
                wait = min(_cooldown[m] for m in candidates) - now
                if wait > RETRY_WAIT_LIMIT:
                    break
                await asyncio.sleep(wait + .2)
                ready = [m for m in candidates if _cooldown.get(m, 0) <= time.monotonic()]
            queue = list(ready)
            while queue:
                model = queue.pop(0)
                try:
                    response = await client.post(BASE_URL + '/chat/completions', headers=headers(), json={
                        'model': model, 'messages': messages, 'temperature': temperature,
                        'max_completion_tokens': budget, 'response_format': {'type': 'json_object'},
                        **reasoning_options(model)})
                    if not response.is_success:
                        # Groq says which limit was hit (requests or tokens, per
                        # minute or per day) and when it resets; keep it visible.
                        try:
                            detail = response.json().get('error', {})
                        except ValueError:
                            detail = {'message': response.text[:300]}
                        log.warning('groq %s %s: %s | retry-after=%s', model, response.status_code,
                                    str(detail.get('message', ''))[:400], response.headers.get('retry-after'))
                        last_error = error_for(response)
                        if response.status_code in (401, 403):
                            raise last_error
                        if response.status_code == 429:
                            _cooldown[model] = time.monotonic() + _retry_after(response)
                        elif (response.status_code == 400 and budget == max_tokens
                              and 'failed to generate json' in str(detail.get('message', '')).casefold()):
                            # A long answer (every out-of-range result, say)
                            # ran out of room before its JSON closed. Ask the
                            # same model once more with twice the room.
                            budget = min(max_tokens * 2, 900)
                            queue.insert(0, model)
                        continue
                    result = parse_json(response.json()['choices'][0]['message']['content'])
                    if not isinstance(result, dict):
                        raise ValueError('Expected a JSON object')
                    return result, model
                except (httpx.TimeoutException, json.JSONDecodeError, ValueError, KeyError):
                    last_error = GroqError('The AI service did not return a complete answer. Please ask again.')
            if not isinstance(last_error, GroqError) or last_error.status != 429:
                break
        raise last_error or GroqError('The AI service is busy. Please try again in a minute.', 429)


async def transcribe(data, language, vocabulary=(), filename='question.webm'):
    hints = {
        'en': 'A patient asks conversational questions about their medical report.',
        'hi': 'नमस्ते। मरीज अपनी जांच की रिपोर्ट के बारे में सरल हिन्दी में बात कर रहे हैं। क्या कम या ज़्यादा है? हीमोग्लोबिन, शुगर, थायरॉइड, क्रिएटिनिन।',
        'es': 'Una persona pregunta sobre los resultados de su informe médico.',
        'zh': '患者用普通话询问自己的化验报告。肌酐（Creatinine）、血红蛋白（Hemoglobin）、血糖、胆固醇、维生素D、甲状腺、TSH。',
    }
    prompt = hints[language] + ' ' + ', '.join(str(item) for item in vocabulary)[:350]
    async with httpx.AsyncClient(timeout=httpx.Timeout(45, connect=10)) as client:
        response = await client.post(BASE_URL + '/audio/transcriptions', headers=headers(),
            files={'file': (filename, data)}, data={
                'model': 'whisper-large-v3-turbo', 'language': language,
                'prompt': prompt, 'temperature': '0', 'response_format': 'verbose_json'})
    if not response.is_success:
        raise error_for(response)
    result = response.json()
    if result.get('duration', 0) > 60:
        raise ValueError('Keep each spoken question under one minute.')
    text = str(result.get('text', '')).strip()
    segments = result.get('segments') or []
    if not text or segments and all(item.get('no_speech_prob', 0) > .85 for item in segments):
        raise ValueError('I could not hear the question clearly. Please speak again or type it.')
    return text
