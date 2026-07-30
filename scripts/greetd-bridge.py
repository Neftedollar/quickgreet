#!/usr/bin/env python3
"""Bridge between QML and greetd.

greetd speaks a binary framing over its unix socket: a 4-byte native
endian length followed by a JSON payload. Quickshell's QML Socket splits
an incoming stream on a delimiter and cannot read length-prefixed frames,
so this process translates between the two.

Line-delimited JSON on stdin and stdout; greetd's native framing on the
socket.

--mock runs without greetd at all, simulating the protocol so the UI can
be developed inside a normal session. In mock mode the accepted password
is $MOCK_PASSWORD, defaulting to "test".
"""

import json
import os
import socket
import struct
import sys
import threading

HEADER = struct.Struct("=I")  # native endian, as greetd expects


def out(obj):
    """Emit a message to the QML side."""
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def log(msg):
    print(f"[bridge] {msg}", file=sys.stderr, flush=True)


# ───────────────────────────── real greetd ─────────────────────────────


class GreetdConn:
    def __init__(self, path):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)
        self.lock = threading.Lock()

    def send(self, obj):
        payload = json.dumps(obj).encode()
        with self.lock:
            self.sock.sendall(HEADER.pack(len(payload)) + payload)

    def _recv_exactly(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                return None
            buf += chunk
        return buf

    def recv(self):
        head = self._recv_exactly(HEADER.size)
        if head is None:
            return None
        (length,) = HEADER.unpack(head)
        body = self._recv_exactly(length)
        if body is None:
            return None
        return json.loads(body)


def run_real(path):
    try:
        conn = GreetdConn(path)
    except OSError as e:
        out({"type": "error", "error_type": "error",
             "description": f"cannot connect to greetd: {e}"})
        return 1

    def reader():
        while True:
            try:
                msg = conn.recv()
            except Exception as e:
                out({"type": "error", "error_type": "error",
                     "description": f"read failed: {e}"})
                return
            if msg is None:
                log("greetd closed the connection")
                return
            out(msg)

    threading.Thread(target=reader, daemon=True).start()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            conn.send(json.loads(line))
        except Exception as e:
            log(f"send failed: {e}")
    return 0


# ────────────────────────────── mock mode ──────────────────────────────


def run_mock():
    """Simulates greetd so the UI can be exercised without logging in."""
    password = os.environ.get("MOCK_PASSWORD", "test")
    log(f"mock mode, password: {password!r}")

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception:
            continue

        kind = req.get("type")

        if kind == "create_session":
            out({"type": "auth_message",
                 "auth_message_type": "secret",
                 "auth_message": "Password:"})

        elif kind == "post_auth_message_response":
            if req.get("response") == password:
                out({"type": "success"})
            else:
                out({"type": "error",
                     "error_type": "auth_error",
                     "description": "Authentication failure"})

        elif kind == "start_session":
            log(f"mock: would start session {req.get('cmd')}")
            out({"type": "success"})

        elif kind == "cancel_session":
            out({"type": "success"})

    return 0


def main():
    if "--mock" in sys.argv:
        return run_mock()

    path = os.environ.get("GREETD_SOCK")
    if not path:
        out({"type": "error", "error_type": "error",
             "description": "GREETD_SOCK is unset - not running under greetd"})
        return 1
    return run_real(path)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
