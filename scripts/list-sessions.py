#!/usr/bin/env python3
"""Lists the sessions a user can log into.

Prints a JSON array of {"id", "name", "comment", "exec", "type"}.

    list-sessions.py [--locale ru] [--include-x11]

Two things here are less obvious than they look.

greetd does not exec the command array. It joins the elements with spaces
and hands the result to `sh -c "exec ..."`, so every element is exposed to
word splitting a second time. Each one is therefore shell-quoted before it
is emitted; without that, any argument containing a space silently starts
the wrong thing.

X11 sessions are excluded by default. greetd runs the command on a bare
VT with no X server, and an xsession entry assumes a display already
exists. Offering them produces a login that fails invisibly and bounces
back to the greeter — indistinguishable, on screen, from a wrong password.
Pass --include-x11 if the entries are wrapped in startx or similar.
"""

import argparse
import configparser
import json
import os
import shlex
import shutil
import sys

# Field codes defined by the Desktop Entry specification. Only these are
# stripped; an argument that merely begins with % is left alone.
FIELD_CODES = {"%f", "%F", "%u", "%U", "%i", "%c", "%k",
               "%d", "%D", "%n", "%N", "%v", "%m"}

# Escape sequences the spec defines for string values.
ESCAPES = {"s": " ", "n": "\n", "t": "\t", "r": "\r", "\\": "\\"}


def session_dirs():
    """Session directories in XDG precedence order, most specific first."""
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    parts = [d for d in data_dirs.split(":") if d]

    # Union with the conventional locations: greetd's environment is
    # minimal and often carries no XDG_DATA_DIRS at all.
    for fallback in ("/usr/local/share", "/usr/share"):
        if fallback not in parts:
            parts.append(fallback)

    out = []
    for d in parts:
        out.append((os.path.join(d, "wayland-sessions"), "wayland"))
        out.append((os.path.join(d, "xsessions"), "x11"))
    return out


def unescape(value):
    """Decodes the escape sequences the spec defines for string values."""
    out = []
    i = 0
    while i < len(value):
        ch = value[i]
        if ch == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            if nxt in ESCAPES:
                out.append(ESCAPES[nxt])
                i += 2
                continue
        out.append(ch)
        i += 1
    return "".join(out)


def localized(sec, key, locale):
    """Name/Comment honouring Name[ru_RU], then Name[ru], then Name."""
    if locale:
        lang = locale.split("_")[0]
        for variant in (f"{key}[{locale}]", f"{key}[{lang}]"):
            if variant in sec:
                return unescape(sec[variant])
    return unescape(sec.get(key, ""))


def split_exec(exec_line):
    """Desktop Entry Exec -> argv, with field codes removed."""
    try:
        argv = shlex.split(exec_line)
    except ValueError:
        argv = exec_line.split()

    out = []
    for arg in argv:
        if arg in FIELD_CODES:
            continue
        # A literal percent is written %% and must survive as one.
        out.append(arg.replace("%%", "%"))
    return out


def parse(path, kind, locale):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    # Keys are case-sensitive in the spec, and lowercasing them would hide
    # the localized Name[xx] variants entirely.
    cp.optionxform = str

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

    # TryExec names a binary whose absence means the entry is stale. Every
    # session left behind by an uninstalled desktop carries one.
    try_exec = sec.get("TryExec", "").strip()
    if try_exec and not shutil.which(try_exec):
        return None

    argv = split_exec(sec.get("Exec", "").strip())
    if not argv:
        return None

    return {
        "id": os.path.splitext(os.path.basename(path))[0],
        "name": localized(sec, "Name", locale) or os.path.basename(path),
        "comment": localized(sec, "Comment", locale),
        # Quoted because greetd re-splits the joined command through a shell.
        "exec": [shlex.quote(a) for a in argv],
        "type": kind,
    }


def main():
    ap = argparse.ArgumentParser(description="list sessions available to log into")
    ap.add_argument("--locale", default="", help="prefer Name[LOCALE] where present")
    ap.add_argument("--include-x11", action="store_true",
                    help="also list xsessions (they need an external X wrapper)")
    args = ap.parse_args()

    out = []
    seen = set()

    for directory, kind in session_dirs():
        if kind == "x11" and not args.include_x11:
            continue
        if not os.path.isdir(directory):
            continue
        for entry in sorted(os.listdir(directory)):
            if not entry.endswith(".desktop"):
                continue
            item = parse(os.path.join(directory, entry), kind, args.locale)
            # First hit wins, and directories are in precedence order, so a
            # local override beats the distribution's copy.
            if item and item["id"] not in seen:
                seen.add(item["id"])
                out.append(item)

    json.dump(out, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
