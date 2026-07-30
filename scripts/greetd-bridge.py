#!/usr/bin/env python3
"""Bridge between QML and greetd.

greetd frames its messages as a 4-byte native-endian length followed by a
JSON payload. Quickshell's QML Socket splits an incoming stream on a
delimiter and cannot read length-prefixed frames, so this process
translates: line-delimited JSON on stdin and stdout, greetd's framing on
the socket.

Nothing that has touched a password is ever written to stderr. The
greeter's output is persisted to a log file that other accounts can read,
and exception text from this layer carries byte offsets into the line
being sent — which discloses the exact length of the password.

--mock runs without greetd, simulating the protocol so the UI can be
developed inside a normal session. MOCK_SCENARIO selects which
conversation to play back; see SCENARIOS.
"""

import json
import os
import socket
import struct
import sys
import threading

HEADER = struct.Struct("=I")  # native endian, as greetd expects

# A frame larger than this is a desynchronised stream, not a message.
MAX_FRAME = 1 << 20

_out_lock = threading.Lock()


def out(obj):
    """Emit a message to the QML side. Safe to call from any thread."""
    line = json.dumps(obj) + "\n"
    with _out_lock:
        try:
            sys.stdout.write(line)
            sys.stdout.flush()
        except (BrokenPipeError, ValueError):
            os._exit(0)


def log(msg):
    """Diagnostics only. Never called with anything derived from a payload."""
    print(f"[bridge] {msg}", file=sys.stderr, flush=True)


def fail(description):
    out({"type": "error", "error_type": "error", "description": description})


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
        if length > MAX_FRAME:
            raise ValueError("frame too large")
        body = self._recv_exactly(length)
        if body is None:
            return None
        return json.loads(body)


def run_real(path):
    try:
        conn = GreetdConn(path)
    except OSError:
        # No detail: the socket path and errno end up on a login screen.
        fail("cannot connect to the login service")
        return 1

    def reader():
        while True:
            try:
                msg = conn.recv()
            except Exception:
                fail("lost connection to the login service")
                os._exit(1)
            if msg is None:
                # greetd closed the socket. Saying so and exiting is what
                # lets the UI recover; a silent return leaves this process
                # alive, so the greeter sees a healthy bridge that will
                # never answer again.
                log("greetd closed the connection")
                fail("lost connection to the login service")
                os._exit(1)
            out(msg)

    threading.Thread(target=reader, daemon=True).start()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except ValueError:
            # The exception text quotes an offset into the line, which is
            # the password's length. Report the fact, not the detail.
            log("malformed request from the UI")
            fail("internal error")
            return 1

        try:
            conn.send(request)
        except OSError:
            fail("lost connection to the login service")
            return 1

    return 0


# ────────────────────────────── mock mode ──────────────────────────────

# Conversations the mock can play back. The real deadlocks all lived in
# message kinds the old mock never produced, so it reported success on a
# greeter that could not actually be used.
SCENARIOS = {
    # password -> success
    "normal": None,
    # password, then a visible one-time code (any 6 digits accepted)
    "2fa": None,
    # password, then two secret prompts for a new one
    "expired": None,
    # an info message before the password prompt
    "info": None,
    # an error message, the kind that used to wedge the greeter
    "lockout": None,
    # never answers, to exercise the timeout
    "hang": None,
}


def run_mock():
    password = os.environ.get("MOCK_PASSWORD", "test")
    scenario = os.environ.get("MOCK_SCENARIO", "normal")
    if scenario not in SCENARIOS:
        log(f"unknown MOCK_SCENARIO {scenario!r}, using 'normal'")
        scenario = "normal"

    log(f"mock mode, scenario {scenario}")

    state = {"step": 0}

    def ask(kind, text):
        out({"type": "auth_message", "auth_message_type": kind, "auth_message": text})

    def deny():
        out({"type": "error", "error_type": "auth_error",
             "description": "Authentication failure"})

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except ValueError:
            continue

        kind = req.get("type")

        if kind == "create_session":
            state["step"] = 0
            if scenario == "hang":
                continue
            if scenario == "info":
                ask("info", "Last login: never")
                continue
            if scenario == "lockout":
                ask("error", "The account is locked due to 3 failed logins.")
                continue
            ask("secret", "Password:")

        elif kind == "post_auth_message_response":
            answer = req.get("response")
            step = state["step"]
            state["step"] = step + 1

            if scenario == "info" and step == 0:
                ask("secret", "Password:")
                continue
            if scenario == "lockout" and step == 0:
                deny()
                continue

            if step == 0:
                if answer != password:
                    deny()
                    continue
                if scenario == "2fa":
                    ask("visible", "Verification code:")
                    continue
                if scenario == "expired":
                    ask("secret", "New password:")
                    continue
                out({"type": "success"})
                continue

            if scenario == "2fa" and step == 1:
                if (answer or "").isdigit() and len(answer) == 6:
                    out({"type": "success"})
                else:
                    deny()
                continue

            if scenario == "expired":
                if step == 1:
                    ask("secret", "Retype new password:")
                else:
                    out({"type": "success"})
                continue

            out({"type": "success"})

        elif kind == "start_session":
            log("mock: would start a session")
            out({"type": "success"})

        elif kind == "cancel_session":
            state["step"] = 0
            out({"type": "success"})

    return 0


def main():
    if "--mock" in sys.argv:
        # Refuse to pretend when a real greetd is present: a mock that can
        # be activated in production is a login screen that authenticates
        # nobody while claiming success.
        if os.environ.get("GREETD_SOCK"):
            log("refusing --mock: GREETD_SOCK is set")
            return 1
        return run_mock()

    path = os.environ.get("GREETD_SOCK")
    if not path:
        fail("not running under greetd")
        return 1
    return run_real(path)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
