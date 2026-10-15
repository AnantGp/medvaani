"""Serve the built UI and proxy its /api calls to the loopback backend."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit


class LocalApp(SimpleHTTPRequestHandler):
    api_origin = "http://127.0.0.1:8001"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(Path(__file__).resolve().parents[1] / 'flutter_app' / 'build' / 'web'), **kwargs)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def _entrypoint(self, path):
        """Version local build scripts so a refresh cannot revive old UI code."""
        root = Path(self.directory)
        entrypoint = root / 'main.dart.js'
        source = root / ('index.html' if path in ('/', '/index.html') else 'flutter_bootstrap.js')
        if not source.is_file() or not entrypoint.is_file():
            return False
        version = str(entrypoint.stat().st_mtime_ns).encode()
        data = source.read_bytes()
        if source.name == 'index.html':
            data = data.replace(b'src="flutter_bootstrap.js"', b'src="flutter_bootstrap.js?v=' + version + b'"')
        else:
            data = data.replace(b'"main.dart.js"', b'"main.dart.js?v=' + version + b'"')
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8' if source.name == 'index.html' else 'text/javascript; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        return True

    def _api(self):
        length = int(self.headers.get('Content-Length', 0))
        if length > 12 * 1024 * 1024:
            self.send_error(413, 'Request is too large')
            return
        body = self.rfile.read(length) if length else None
        headers = {name: self.headers[name] for name in ('Content-Type', 'Accept') if name in self.headers}
        request = Request(self.api_origin + self.path[4:], data=body, headers=headers, method=self.command)
        try:
            response = urlopen(request, timeout=700)
        except HTTPError as error:
            response = error
        except URLError:
            self.send_error(502, 'The local report API is unavailable')
            return
        with response:
            data = response.read()
            self.send_response(response.status)
            self.send_header('Content-Type', response.headers.get('Content-Type', 'application/json'))
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith('/api/'):
            self._api()
        elif urlsplit(self.path).path in ('/', '/index.html', '/flutter_bootstrap.js') and self._entrypoint(urlsplit(self.path).path):
            pass
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith('/api/'):
            self._api()
        else:
            self.send_error(404)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=3001)
    parser.add_argument("--api-origin", default="http://127.0.0.1:8001", help="Remote API origin, including /api when hosted on Vercel")
    args = parser.parse_args()
    LocalApp.api_origin = args.api_origin.rstrip("/")
    ThreadingHTTPServer(('127.0.0.1', args.port), LocalApp).serve_forever()
