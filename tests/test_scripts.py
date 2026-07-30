#!/usr/bin/env python3
"""Tests for the helper scripts.

    python3 -m unittest discover tests

Covers the parts that need neither a compositor nor greetd: protocol
framing, .desktop parsing and account filtering. Every case here
corresponds to something that was wrong at some point — the framing
reassembly, the shell requoting greetd forces, TryExec, field codes,
nologin paths outside /usr/bin.

Standard library only, deliberately: a login screen should not need a
test framework installed to be checked.
"""

import importlib.util
import json
import os
import socket
import struct
import sys
import tempfile
import textwrap
import threading
import unittest

SCRIPTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts")


def load(name):
    """Imports a script by path; the filenames are not valid module names."""
    path = os.path.join(SCRIPTS, name)
    spec = importlib.util.spec_from_file_location(name.replace("-", "_").replace(".py", ""), path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


bridge = load("greetd-bridge.py")
sessions = load("list-sessions.py")
users = load("list-users.py")


class Framing(unittest.TestCase):
    """greetd frames as a 4-byte native-endian length plus JSON."""

    def setUp(self):
        self.a, self.b = socket.socketpair()
        self.conn = bridge.GreetdConn.__new__(bridge.GreetdConn)
        self.conn.sock = self.a
        self.conn.lock = threading.Lock()
        self.addCleanup(self.a.close)
        self.addCleanup(self.b.close)

    def test_round_trip(self):
        self.conn.send({"type": "create_session", "username": "someone"})
        head = self.b.recv(4)
        (length,) = struct.unpack("=I", head)
        body = self.b.recv(length)
        self.assertEqual(json.loads(body)["username"], "someone")

    def test_length_counts_bytes_not_characters(self):
        # ensure_ascii keeps the two equal even for non-ASCII usernames;
        # if that ever changes the prefix would be short and the stream
        # would desynchronise.
        self.conn.send({"username": "Ромáн"})
        (length,) = struct.unpack("=I", self.b.recv(4))
        self.assertEqual(len(self.b.recv(length)), length)

    def test_reassembles_a_split_frame(self):
        payload = json.dumps({"type": "success"}).encode()
        frame = struct.pack("=I", len(payload)) + payload
        # Delivered in two pieces, splitting the header itself.
        self.b.send(frame[:2])
        threading.Timer(0.05, lambda: self.b.send(frame[2:])).start()
        self.assertEqual(self.conn.recv(), {"type": "success"})

    def test_eof_midframe_returns_none(self):
        payload = json.dumps({"type": "success"}).encode()
        self.b.send(struct.pack("=I", len(payload)) + payload[:3])
        self.b.close()
        self.assertIsNone(self.conn.recv())

    def test_rejects_an_absurd_length(self):
        self.b.send(struct.pack("=I", bridge.MAX_FRAME + 1))
        with self.assertRaises(ValueError):
            self.conn.recv()


class DesktopEntries(unittest.TestCase):
    def parse(self, body, kind="wayland", locale="", name="test.desktop"):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, name)
            with open(path, "w", encoding="utf-8") as f:
                f.write(textwrap.dedent(body).lstrip())
            return sessions.parse(path, kind, locale)

    def test_basic(self):
        got = self.parse("""
            [Desktop Entry]
            Name=Example
            Exec=/usr/bin/example
        """)
        self.assertEqual(got["name"], "Example")
        self.assertEqual(got["exec"], ["/usr/bin/example"])

    def test_hidden_and_nodisplay_are_skipped(self):
        self.assertIsNone(self.parse("""
            [Desktop Entry]
            Name=X
            Exec=/bin/true
            Hidden=true
        """))
        self.assertIsNone(self.parse("""
            [Desktop Entry]
            Name=X
            Exec=/bin/true
            NoDisplay=true
        """))

    def test_missing_section_or_exec(self):
        self.assertIsNone(self.parse("nothing here\n"))
        self.assertIsNone(self.parse("""
            [Desktop Entry]
            Name=X
        """))

    def test_tryexec_absent_binary_is_skipped(self):
        self.assertIsNone(self.parse("""
            [Desktop Entry]
            Name=X
            Exec=/bin/true
            TryExec=/definitely/not/installed
        """))

    def test_tryexec_present_binary_is_kept(self):
        self.assertIsNotNone(self.parse("""
            [Desktop Entry]
            Name=X
            Exec=/bin/true
            TryExec=/bin/sh
        """))

    def test_field_codes_are_dropped_but_literal_percent_survives(self):
        got = self.parse("""
            [Desktop Entry]
            Name=X
            Exec=run %U %%literal
        """)
        self.assertEqual(got["exec"], ["run", "%literal"])

    def test_arguments_are_shell_quoted(self):
        # greetd joins the array and runs it through sh -c, so an argument
        # containing a space must survive that second split.
        got = self.parse("""
            [Desktop Entry]
            Name=X
            Exec="/opt/my desktop/start" --flag
        """)
        self.assertEqual(len(got["exec"]), 2)
        joined = " ".join(got["exec"])
        import shlex
        self.assertEqual(shlex.split(joined)[0], "/opt/my desktop/start")

    def test_localised_name_preferred(self):
        body = """
            [Desktop Entry]
            Name=Plasma
            Name[ru]=Плазма
            Exec=/bin/true
        """
        self.assertEqual(self.parse(body, locale="ru_RU")["name"], "Плазма")
        self.assertEqual(self.parse(body, locale="de_DE")["name"], "Plasma")
        self.assertEqual(self.parse(body)["name"], "Plasma")

    def test_escape_sequences_are_decoded(self):
        got = self.parse("""
            [Desktop Entry]
            Name=A\\sB
            Exec=/bin/true
        """)
        self.assertEqual(got["name"], "A B")

    def test_session_dirs_honour_xdg_data_dirs(self):
        os.environ["XDG_DATA_DIRS"] = "/opt/one:/opt/two"
        try:
            dirs = [d for d, _ in sessions.session_dirs()]
        finally:
            del os.environ["XDG_DATA_DIRS"]
        self.assertIn("/opt/one/wayland-sessions", dirs)
        # The conventional locations remain as a fallback, because greetd's
        # environment often carries no XDG_DATA_DIRS at all.
        self.assertIn("/usr/share/wayland-sessions", dirs)

    def test_local_share_precedes_usr_share(self):
        dirs = [d for d, _ in sessions.session_dirs()]
        self.assertLess(dirs.index("/usr/local/share/wayland-sessions"),
                        dirs.index("/usr/share/wayland-sessions"))


class Accounts(unittest.TestCase):
    def test_realname_takes_the_first_gecos_field(self):
        class Entry:
            pw_gecos = "Ada Lovelace,room 1,555,555"
            pw_name = "ada"
        self.assertEqual(users.realname_of(Entry()), "Ada Lovelace")

    def test_realname_falls_back_to_the_login(self):
        class Entry:
            pw_gecos = ",,,"
            pw_name = "ada"
        self.assertEqual(users.realname_of(Entry()), "ada")

    def test_nologin_matched_by_basename(self):
        # The absolute path differs per distribution, and on NixOS it lives
        # under /nix/store where no fixed list could ever reach it.
        for shell in ("/usr/bin/nologin", "/sbin/nologin",
                      "/nix/store/abc123-shadow/bin/nologin", "/bin/false"):
            self.assertIn(os.path.basename(shell), users.NOLOGIN_NAMES, shell)
        self.assertNotIn("bash", users.NOLOGIN_NAMES)

    def test_uid_range_falls_back_when_login_defs_is_absent(self):
        lo, hi = users.uid_range()
        self.assertGreater(hi, lo)
        self.assertGreaterEqual(lo, 100)

    def test_home_directories_are_not_avatar_sources(self):
        # Reading an avatar out of a home directory hands an unprivileged
        # user an image decoder that runs before authentication.
        self.assertFalse(any("{home}" in c for c in users.AVATAR_CANDIDATES))


class SchemeVariants(unittest.TestCase):
    def test_every_variant_resolves(self):
        try:
            gen = load("gen-scheme.py")
        except ImportError:
            self.skipTest("materialyoucolor not installed")

        import importlib
        for name, (suffix, cls_name) in gen.VARIANTS.items():
            with self.subTest(variant=name):
                try:
                    module = importlib.import_module(f"materialyoucolor.scheme.scheme_{suffix}")
                except ImportError:
                    self.skipTest("materialyoucolor not installed")
                self.assertTrue(hasattr(module, cls_name),
                                f"{cls_name} missing from scheme_{suffix}")


if __name__ == "__main__":
    unittest.main()
