"""Quota handling: per-model cool-downs, a short wait, and the fallback order."""
import asyncio
import json

import groq_provider as g


class Response:
    def __init__(self, status, body, headers=None):
        self.status_code, self._body, self.headers = status, body, headers or {}
        self.is_success = status == 200
        self.text = json.dumps(body)

    def json(self):
        return self._body


def fake_client(script, calls):
    """script(model, call_number) -> Response"""
    class Client:
        def __init__(self, *a, **k): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *a): return False
        async def get(self, url, headers=None):
            return Response(200, {'data': [{'id': m} for m in
                ('qwen/qwen3.8-27b', 'openai/gpt-oss-120b', 'openai/gpt-oss-20b', 'whisper-large-v3')]})
        async def post(self, url, headers=None, json=None, **k):
            calls.append(json['model'])
            return script(json['model'], len(calls))
    return Client


def ok():
    return Response(200, {'choices': [{'message': {'content': '{"spoken_answer": "fine"}'}}]})


def limited(after='30'):
    return Response(429, {'error': {'message': 'Rate limit reached'}}, {'retry-after': after})


def run(script, monkeypatch):
    calls = []
    monkeypatch.setenv('GROQ_API_KEY', 'test')
    monkeypatch.setattr(g.httpx, 'AsyncClient', fake_client(script, calls))
    monkeypatch.setattr(g, '_models', None)
    monkeypatch.setattr(g, '_cooldown', {})
    slept = []
    async def sleep(seconds):
        slept.append(seconds)
        g._cooldown.clear()
    monkeypatch.setattr(g.asyncio, 'sleep', sleep)
    try:
        result = asyncio.run(g.chat_json([{'role': 'user', 'content': 'q'}]))
    except g.GroqError as e:
        result = e
    return result, calls, slept


def test_falls_back_to_the_larger_open_model_before_the_small_one(monkeypatch):
    result, calls, _ = run(lambda m, n: limited() if m == 'qwen/qwen3.8-27b' else ok(), monkeypatch)
    assert result[1] == 'openai/gpt-oss-120b'
    assert calls == ['qwen/qwen3.8-27b', 'openai/gpt-oss-120b']


def test_a_limited_model_is_not_asked_again_until_its_reset(monkeypatch):
    calls = []
    monkeypatch.setenv('GROQ_API_KEY', 'test')
    monkeypatch.setattr(g.httpx, 'AsyncClient', fake_client(
        lambda m, n: limited() if m == 'qwen/qwen3.8-27b' else ok(), calls))
    monkeypatch.setattr(g, '_models', None)
    monkeypatch.setattr(g, '_cooldown', {})
    asyncio.run(g.chat_json([{'role': 'user', 'content': 'q'}]))
    asyncio.run(g.chat_json([{'role': 'user', 'content': 'q'}]))
    assert calls == ['qwen/qwen3.8-27b', 'openai/gpt-oss-120b', 'openai/gpt-oss-120b']


def test_waits_for_a_close_reset_when_every_model_is_busy(monkeypatch):
    result, calls, slept = run(lambda m, n: limited('5') if n <= 3 else ok(), monkeypatch)
    assert result[1] == 'qwen/qwen3.8-27b'
    assert len(slept) == 1 and slept[0] <= 6
    assert calls[:3] == ['qwen/qwen3.8-27b', 'openai/gpt-oss-120b', 'openai/gpt-oss-20b']


def test_gives_up_with_a_quota_error_when_resets_are_far_away(monkeypatch):
    result, calls, slept = run(lambda m, n: limited('50'), monkeypatch)
    assert isinstance(result, g.GroqError) and result.status == 429
    assert slept == [] and len(calls) == 3
