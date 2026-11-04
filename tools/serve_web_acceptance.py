"""Serve an existing release build locally with its /ballwars/ base path.

For a USB-connected phone: adb reverse tcp:8334 tcp:8334, then open
http://127.0.0.1:8334/ballwars/ . No public tunnel or production deployment.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        if path.startswith('/ballwars/'):
            path = path[len('/ballwars'):]
        return super().translate_path(path)


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1] / 'build' / 'web'
    ThreadingHTTPServer(('127.0.0.1', 8334), partial(Handler, directory=str(root))).serve_forever()
