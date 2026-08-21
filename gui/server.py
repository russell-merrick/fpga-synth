"""
IceSugar synth control — serial bridge + static GUI.

  python gui/server.py
  python gui/server.py --port COM4

Then open http://127.0.0.1:8080
Close miniterm first (COM port is exclusive).
"""
from __future__ import annotations

import argparse
import json
import sys
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    print("pyserial required: pip install pyserial", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parent
STATIC = ROOT / "static"
DEFAULT_PORT = "COM4"
BAUD = 115200

NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# FPGA baked A-minor line (matches src/seq.v)
DEFAULT_STEPS = [
    {"note": 9, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 9, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 0, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 9, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 2, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 4, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 2, "rest": False, "accent": False, "slide": True, "high": False},
    {"note": 0, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 9, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 7, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 9, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 0, "rest": False, "accent": True, "slide": False, "high": False},
    {"note": 2, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 0, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 9, "rest": False, "accent": False, "slide": False, "high": False},
    {"note": 7, "rest": False, "accent": False, "slide": False, "high": False},
]

PARAM_KEYS = {
    "attack": "A",
    "decay": "D",
    "sustain": "S",
    "release": "R",
    "cutoff": "C",
    "res": "Q",
    "fenv": "E",
    "fdecay": "K",
    "drive": "O",
    "fm_index": "I",
    "fm_ratio": "N",
    "fold": "L",
    "bpm": "B",
    "octave": "X",
    "wave": "W",
    "play": "P",
    "length": "Y",
}


def pack_step(s: dict) -> int:
    b = int(s.get("note", 0)) & 0x0F
    if s.get("high"):
        b |= 0x10
    if s.get("slide"):
        b |= 0x20
    if s.get("accent"):
        b |= 0x40
    if s.get("rest"):
        b |= 0x80
    return b


class Bridge:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.ser: serial.Serial | None = None
        self.port = DEFAULT_PORT
        self.state = {
            "connected": False,
            "port": DEFAULT_PORT,
            "play": False,
            "bpm": 120,
            "octave": 4,
            "length": 16,
            "wave": 2,
            "attack": 80,
            "decay": 20,
            "sustain": 200,
            "release": 20,
            "cutoff": 40,
            "res": 210,
            "fenv": 255,
            "fdecay": 64,
            "drive": 96,
            "fm_index": 0,
            "fm_ratio": 2,
            "fold": 0,
            "steps": [dict(x) for x in DEFAULT_STEPS],
        }

    def ports(self) -> list[str]:
        return [p.device for p in list_ports.comports()]

    def connect(self, port: str) -> None:
        self.disconnect()
        ser = serial.Serial(port, BAUD, timeout=0.05)
        with self.lock:
            self.ser = ser
            self.port = port
            self.state["connected"] = True
            self.state["port"] = port

    def disconnect(self) -> None:
        with self.lock:
            if self.ser is not None:
                try:
                    self.ser.close()
                except Exception:
                    pass
                self.ser = None
            self.state["connected"] = False

    def send(self, data: bytes) -> None:
        with self.lock:
            if self.ser is None or not self.ser.is_open:
                raise RuntimeError("not connected")
            self.ser.write(data)
            self.ser.flush()
            # Drain FPGA help/status so the CDC buffer does not stall.
            try:
                self.ser.reset_input_buffer()
            except Exception:
                pass

    def cmd(self, letter: str, value: int) -> None:
        v = max(0, min(255, int(value)))
        self.send(f":{letter}{v:03d}\n".encode("ascii"))

    def send_pattern(self, steps: list[dict]) -> None:
        raw = "".join(f"{pack_step(s):02X}" for s in steps[:16])
        if len(raw) < 32:
            raw = raw + ("80" * ((32 - len(raw)) // 2))
        self.send(f":J{raw}\n".encode("ascii"))


BRIDGE = Bridge()


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(STATIC), **kwargs)

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _json(self, obj, code: int = 200) -> None:
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        n = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(n) if n else b"{}"
        if not raw:
            return {}
        return json.loads(raw.decode("utf-8"))

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/api/ports":
            self._json({"ports": BRIDGE.ports(), "port": BRIDGE.port})
            return
        if path == "/api/state":
            self._json(BRIDGE.state)
            return
        if path == "/":
            self.path = "/index.html"
        return super().do_GET()

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        try:
            data = self._read_json()
        except json.JSONDecodeError:
            self._json({"error": "bad json"}, 400)
            return
        try:
            if path == "/api/connect":
                BRIDGE.connect(str(data.get("port") or DEFAULT_PORT))
                self._json(BRIDGE.state)
                return
            if path == "/api/disconnect":
                BRIDGE.disconnect()
                self._json(BRIDGE.state)
                return
            if path == "/api/param":
                key = str(data.get("key", ""))
                val = int(data.get("value", 0))
                letter = PARAM_KEYS.get(key)
                if not letter:
                    self._json({"error": "unknown key"}, 400)
                    return
                if key == "play":
                    BRIDGE.state["play"] = bool(val)
                    BRIDGE.cmd("P", 1 if val else 0)
                elif key == "fm_ratio":
                    val = max(1, min(8, val))
                    BRIDGE.state[key] = val
                    BRIDGE.cmd(letter, val)
                elif key == "length":
                    val = max(1, min(16, val))
                    BRIDGE.state[key] = val
                    BRIDGE.cmd(letter, val)
                elif key == "octave":
                    val = max(0, min(7, val))
                    BRIDGE.state[key] = val
                    BRIDGE.cmd(letter, val)
                elif key == "wave":
                    val = max(0, min(3, val))
                    BRIDGE.state[key] = val
                    BRIDGE.cmd(letter, val)
                elif key == "bpm":
                    val = max(40, min(240, val))
                    BRIDGE.state[key] = val
                    BRIDGE.cmd(letter, val)
                else:
                    val = max(0, min(255, val))
                    BRIDGE.state[key] = val
                    BRIDGE.cmd(letter, val)
                self._json(BRIDGE.state)
                return
            if path == "/api/pattern":
                steps = data.get("steps") or BRIDGE.state["steps"]
                if not isinstance(steps, list) or len(steps) < 1:
                    self._json({"error": "steps"}, 400)
                    return
                padded = [dict(s) for s in steps[:16]]
                while len(padded) < 16:
                    padded.append({"note": 0, "rest": True, "accent": False,
                                   "slide": False, "high": False})
                BRIDGE.state["steps"] = padded
                if "bpm" in data:
                    BRIDGE.state["bpm"] = int(data["bpm"])
                    BRIDGE.cmd("B", BRIDGE.state["bpm"])
                if "length" in data:
                    BRIDGE.state["length"] = int(data["length"])
                    BRIDGE.cmd("Y", BRIDGE.state["length"])
                if "octave" in data:
                    BRIDGE.state["octave"] = int(data["octave"])
                    BRIDGE.cmd("X", BRIDGE.state["octave"])
                BRIDGE.send_pattern(padded)
                self._json(BRIDGE.state)
                return
        except RuntimeError as e:
            self._json({"error": str(e)}, 409)
            return
        except Exception as e:
            self._json({"error": str(e)}, 500)
            return
        self._json({"error": "not found"}, 404)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default=DEFAULT_PORT, help="serial port")
    ap.add_argument("--bind", default="127.0.0.1")
    ap.add_argument("--http", type=int, default=8080)
    ap.add_argument("--no-serial", action="store_true")
    args = ap.parse_args()
    BRIDGE.port = args.port
    BRIDGE.state["port"] = args.port
    if not args.no_serial:
        try:
            BRIDGE.connect(args.port)
            print(f"serial {args.port} @ {BAUD}")
        except Exception as e:
            print(f"serial open failed ({e}) — connect from the UI")
    httpd = ThreadingHTTPServer((args.bind, args.http), Handler)
    print(f"GUI  http://{args.bind}:{args.http}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    BRIDGE.disconnect()


if __name__ == "__main__":
    main()
