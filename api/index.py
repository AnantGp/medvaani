"""Vercel ASGI entry point for the shared Flutter /api origin."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from main import app as backend_app
from starlette.responses import JSONResponse


async def app(scope, receive, send):
    if scope['type'] != 'http':
        return await backend_app(scope, receive, send)
    scope = dict(scope)
    path = scope.get('path', '/')
    if path == '/api' or path.startswith('/api/'):
        scope['path'] = path[4:] or '/'
        scope['raw_path'] = scope['path'].encode()
    if scope.get('method') == 'POST':
        events, total = [], 0
        while True:
            event = await receive()
            if event['type'] == 'http.disconnect':
                return
            total += len(event.get('body', b''))
            if total > 4_400_000:
                return await JSONResponse({'detail': 'This request exceeds the 4 MB upload allowance.'}, status_code=413)(scope, receive, send)
            events.append(event)
            if not event.get('more_body'):
                break
        original_receive = receive
        async def replay():
            return events.pop(0) if events else await original_receive()
        receive = replay
    await backend_app(scope, receive, send)
