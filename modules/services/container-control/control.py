#!/usr/bin/env python3
"""Small HTTP panel to start/stop a whitelisted set of systemd units.

Routes:
  GET  /                            -> the control page
  GET  /api/units                   -> status of every managed unit
  GET  /api/units/<unit>            -> status of one unit (used by homepage)
  POST /api/units/<unit>/<verb>     -> start | stop | restart, then status
"""

import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("CONTROL_PORT", "8090"))
SYSTEMCTL = os.environ.get("SYSTEMCTL", "systemctl")
PAGE = os.environ["CONTROL_PAGE"]

# CONTROL_UNITS is "unit.service=Label,other.service=Other Label"
UNITS = {}
for _item in os.environ.get("CONTROL_UNITS", "").split(","):
    if not _item:
        continue
    _unit, _, _label = _item.partition("=")
    UNITS[_unit] = _label or _unit

VERBS = ("start", "stop", "restart")


def show(unit):
    props = {}
    try:
        out = subprocess.run(
            [SYSTEMCTL, "show", unit, "--property=ActiveState,SubState,ActiveEnterTimestampMonotonic"],
            capture_output=True,
            text=True,
            timeout=15,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return props
    for line in out.splitlines():
        key, _, value = line.partition("=")
        props[key] = value
    return props


def uptime(props):
    """Human uptime, derived from the monotonic clock so no date parsing is needed."""
    try:
        started = int(props.get("ActiveEnterTimestampMonotonic", "0")) / 1_000_000
        with open("/proc/uptime") as fh:
            now = float(fh.read().split()[0])
    except (ValueError, OSError):
        return ""
    if started <= 0:
        return ""
    seconds = int(now - started)
    if seconds < 0:
        return ""
    days, rest = divmod(seconds, 86400)
    hours, rest = divmod(rest, 3600)
    minutes = rest // 60
    if days:
        return f"{days}d {hours}h"
    if hours:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def status(unit):
    props = show(unit)
    state = props.get("ActiveState", "unknown")
    label = {
        "active": "Running",
        "activating": "Starting",
        "deactivating": "Stopping",
        "failed": "Failed",
    }.get(state, "Stopped")
    return {
        "unit": unit,
        "name": UNITS[unit],
        "status": label,
        "running": state == "active",
        "busy": state in ("activating", "deactivating"),
        "state": state,
        "substate": props.get("SubState", ""),
        "uptime": uptime(props) if state == "active" else "-",
    }


def act(unit, verb):
    # --no-block: pulling an image or stopping a container can take a while, and
    # the page polls the status anyway.
    result = subprocess.run(
        [SYSTEMCTL, "--no-block", verb, unit],
        capture_output=True,
        text=True,
        timeout=30,
    )
    return result.returncode, (result.stderr or result.stdout).strip()


class Handler(BaseHTTPRequestHandler):
    server_version = "container-control"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # journal already timestamps us
        print(fmt % args, flush=True)

    def _send(self, code, body, content_type):
        payload = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def _json(self, code, data):
        self._send(code, json.dumps(data), "application/json")

    def _unit(self, name):
        if name in UNITS:
            return name
        if f"{name}.service" in UNITS:
            return f"{name}.service"
        return None

    def do_GET(self):
        path = self.path.split("?", 1)[0].rstrip("/") or "/"
        if path == "/":
            try:
                with open(PAGE) as fh:
                    self._send(200, fh.read(), "text/html; charset=utf-8")
            except OSError:
                self._send(500, "control page missing", "text/plain")
            return
        if path == "/api/units":
            self._json(200, [status(unit) for unit in UNITS])
            return
        if path.startswith("/api/units/"):
            unit = self._unit(path[len("/api/units/"):])
            if unit is None:
                self._json(404, {"error": "unknown unit"})
                return
            self._json(200, status(unit))
            return
        self._send(404, "not found", "text/plain")

    def do_POST(self):
        path = self.path.split("?", 1)[0].rstrip("/")
        parts = path.strip("/").split("/")
        if len(parts) != 4 or parts[0] != "api" or parts[1] != "units":
            self._send(404, "not found", "text/plain")
            return
        unit, verb = self._unit(parts[2]), parts[3]
        if unit is None:
            self._json(404, {"error": "unknown unit"})
            return
        if verb not in VERBS:
            self._json(400, {"error": "unknown action"})
            return
        code, message = act(unit, verb)
        if code != 0:
            self._json(500, {"error": message or f"{verb} failed"})
            return
        self._json(200, status(unit))


def main():
    if not UNITS:
        raise SystemExit("CONTROL_UNITS is empty, nothing to manage")
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"listening on port {PORT}, managing {', '.join(UNITS)}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
