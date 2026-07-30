#!/usr/bin/env python3
"""Lists the sessions a user can log into.

Parses .desktop files from the standard session directories and prints a
JSON array of {"id", "name", "comment", "exec", "type"}.

Exec is split with shell rules because greetd expects a command as an
argv array rather than a string.
"""

import configparser
import json
import os
import shlex
import sys

DIRS = [
    ("/usr/share/wayland-sessions", "wayland"),
    ("/usr/local/share/wayland-sessions", "wayland"),
    ("/usr/share/xsessions", "x11"),
    ("/usr/local/share/xsessions", "x11"),
]


def parse(path, kind):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        cp.read(path, encoding="utf-8")
    except Exception:
        return None

    if not cp.has_section("Desktop Entry"):
        return None

    sec = cp["Desktop Entry"]

    if sec.get("Hidden", "false").lower() == "true":
        return None
    if sec.get("NoDisplay", "false").lower() == "true":
        return None

    exec_line = sec.get("Exec", "").strip()
    if not exec_line:
        return None

    try:
        argv = shlex.split(exec_line)
    except ValueError:
        argv = exec_line.split()

    # Field codes such as %U or %f are meaningless for a session.
    argv = [a for a in argv if not a.startswith("%")]
    if not argv:
        return None

    return {
        "id": os.path.splitext(os.path.basename(path))[0],
        "name": sec.get("Name", os.path.basename(path)),
        "comment": sec.get("Comment", ""),
        "exec": argv,
        "type": kind,
    }


def main():
    out = []
    seen = set()

    for directory, kind in DIRS:
        if not os.path.isdir(directory):
            continue
        for entry in sorted(os.listdir(directory)):
            if not entry.endswith(".desktop"):
                continue
            item = parse(os.path.join(directory, entry), kind)
            if item and item["id"] not in seen:
                seen.add(item["id"])
                out.append(item)

    json.dump(out, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
