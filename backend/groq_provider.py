"""Hosted speech recognition and JSON explanations; no local ML imports."""
import json
import os
import re
import time

import httpx

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


async def chat_json(messages, *, vision=False, max_tokens=600):
    # Qwen 3 32B and Scout were retired in July 2026. Environment overrides
    # remain possible; unavailable IDs are skipped using the live catalog.
    primary = os.getenv('GROQ_VISION_MODEL' if vision else 'GROQ_LLM_MODEL', 'qwen/qwen3.8-27b')
    candidates = [primary] if vision else list(dict.fromkeys([
        primary, 'llama-3.3-70b-versatile', 'openai/gpt-oss-20b']))
    async with httpx.AsyncClient(timeout=httpx.Timeout(60, connect=10)) as client:
        active = await available_models(client)
        candidates = [model for model in candidates if active is None or model in active]
        if not candidates:
            raise GroqError('The configured AI model is no longer available. Update the model setting.')
        last_error = None
        for model in candidates:
            try:
                response = await client.post(BASE_URL + '/chat/completions', headers=headers(), json={
                    'model': model, 'messages': messages, 'temperature': .2,
                    'max_completion_tokens': max_tokens, 'response_format': {'type': 'json_object'},
                    **reasoning_options(model)})
                if not response.is_success:
                    last_error = error_for(response)
                    if response.status_code in (401, 403):
                        raise last_error
                    continue
                result = parse_json(response.json()['choices'][0]['message']['content'])
                if not isinstance(result, dict):
                    raise ValueError('Expected a JSON object')
                return result, model
            except (httpx.TimeoutException, json.JSONDecodeError, ValueError, KeyError):
                last_error = GroqError('The AI service did not return a complete answer. Please ask again.')
        raise last_error or GroqError('The AI service is temporarily unavailable.')


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
