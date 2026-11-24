import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SESSION = "session=fixture-ok"
PUBLIC_PAGES = ("/login.html", "/xframe.html", "/expired.html")
PRIVATE_PAGES = ("/app.html", "/frame.html", "/archive.html", "/probe.html", "/probe-frame.html", "/shapes.html", "/idle.html", "/enter.html", "/tabs.html", "/freeze.html")
BROKEN_PAGES = ("/known.html",)
STATE = {"fixed": False}


class Handler(BaseHTTPRequestHandler):
    root = Path(".")

    def log_message(self, fmt, *args):
        pass

    def signed_in(self):
        return SESSION in (self.headers.get("Cookie") or "") or self.headers.get("X-Session") == "fixture-ok"

    def reply(self, status, body=b"", headers=None):
        self.send_response(status)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)
        print(f"{self.command} {self.path} {status}", flush=True)

    def page(self, path, status):
        text = (self.root / path.lstrip("/")).read_text(encoding="utf-8")
        text = text.replace("__CLEAR_BUG__", "false" if STATE["fixed"] else "true")
        return self.reply(status, text.encode(), {"Content-Type": "text/html; charset=utf-8"})

    def route(self):
        path = self.path.split("?")[0]
        if path.startswith("/__destructive/"):
            return self.reply(200, b"{}", {"Content-Type": "application/json"})
        if path == "/__fixture/fix" and self.command == "POST":
            STATE["fixed"] = True
            return self.reply(200, b"{}")
        if path == "/big.html":
            return self.reply(200, b"<!doctype html><title>Sign in</title><p>Sign in</p>" + b"<!-- pad -->" * 200000, {"Content-Type": "text/html; charset=utf-8"})
        if path == "/":
            return self.reply(302, headers={"Location": "/app.html"})
        if path == "/login" and self.command == "POST":
            body = self.rfile.read(int(self.headers.get("Content-Length") or 0)).decode()
            if "password=right" in body:
                return self.reply(302, headers={"Location": "/app.html", "Set-Cookie": f"{SESSION}; Path=/"})
            return self.reply(401, b"wrong password")
        if path == "/logout":
            return self.reply(200, b"{}", {"Set-Cookie": "session=; Path=/; Max-Age=0"})
        if path in PRIVATE_PAGES + ("/api/ok", "/api/broken") and not self.signed_in():
            if path in PRIVATE_PAGES:
                return self.reply(302, headers={"Location": "/login.html"})
            return self.reply(401, b"{}")
        if path == "/api/echo" and self.command == "POST":
            body = self.rfile.read(int(self.headers.get("Content-Length") or 0)).decode()
            print(f"echo {self.path.partition('?')[2]} {self.headers.get('X-Probe')} {body}", flush=True)
            return self.reply(200, b"{}")
        if path == "/api/ok":
            return self.reply(200, b'{"ok": true}', {"Content-Type": "application/json"})
        if path in ("/api/broken", "/api/legacy"):
            return self.reply(500, b'{"error": "planted"}', {"Content-Type": "application/json"})
        if self.command == "GET" and path in PUBLIC_PAGES + PRIVATE_PAGES + BROKEN_PAGES:
            return self.page(path, 500 if path in BROKEN_PAGES else 200)
        return self.reply(404, b"<!doctype html><title>Not found</title><p>Not found</p>", {"Content-Type": "text/html; charset=utf-8"})

    do_GET = do_POST = do_DELETE = do_PUT = do_HEAD = route


if __name__ == "__main__":
    port, Handler.root = int(sys.argv[1]), Path(sys.argv[2])
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
