#!/usr/bin/env python3
"""Lists accounts that can log in.

Prints a JSON array of {"name", "realname", "avatar", "uid"}.

Selection covers ordinary accounts: a UID inside the range the system
itself defines, and a real login shell, since accounts pointing at
nologin or false cannot sign in at all.

Avatars are only taken from system-wide locations. Home directories are
deliberately excluded: the greeter decodes whatever it finds, before
anyone has authenticated, in the process that holds the greetd socket.
A file under a user's own control there is an image decoder reachable
pre-authentication by any unprivileged account.
"""

import json
import os
import pwd
import sys

# Fallbacks only; the real values come from /etc/login.defs where present.
DEFAULT_UID_MIN = 1000
DEFAULT_UID_MAX = 60000

# Matched on the basename, because the absolute path differs per
# distribution — /usr/bin/nologin, /sbin/nologin, and on NixOS a path
# under /nix/store that no fixed list could ever contain.
NOLOGIN_NAMES = {"nologin", "false", "sync", "true", "git-shell"}

AVATAR_CANDIDATES = (
    "/var/lib/AccountsService/icons/{name}",
    "/var/lib/kdm/faces/{name}.face.icon",
)

# Homes that clearly do not exist. A home that is merely not mounted yet
# is not disqualifying: encrypted, systemd-homed and automounted homes
# appear only after login, and those accounts need the greeter most.
NONEXISTENT_HOMES = {"", "/", "/nonexistent", "/dev/null"}


def uid_range():
    lo, hi = DEFAULT_UID_MIN, DEFAULT_UID_MAX
    try:
        with open("/etc/login.defs") as f:
            for line in f:
                parts = line.split()
                if len(parts) < 2:
                    continue
                if parts[0] == "UID_MIN":
                    lo = int(parts[1])
                elif parts[0] == "UID_MAX":
                    hi = int(parts[1])
    except (OSError, ValueError):
        pass
    return lo, hi


def readable(path):
    return os.path.isfile(path) and os.access(path, os.R_OK)


def find_avatar(name):
    for tpl in AVATAR_CANDIDATES:
        path = tpl.format(name=name)
        if readable(path):
            return path
    return ""


def realname_of(entry):
    # GECOS is "Full Name,room,phone,..." - only the first field is a name
    full = (entry.pw_gecos or "").split(",")[0].strip()
    return full or entry.pw_name


def is_system_account(name):
    """AccountsService marks service accounts that should not be offered."""
    path = f"/var/lib/AccountsService/users/{name}"
    try:
        with open(path) as f:
            for line in f:
                if line.strip().replace(" ", "").lower() == "systemaccount=true":
                    return True
    except OSError:
        pass
    return False


def main():
    uid_min, uid_max = uid_range()

    # The greeter's own account can fall inside the normal UID range on
    # some distributions, and offering it as a login target is nonsense.
    # Only applied when actually running under greetd: otherwise anyone
    # running this by hand would filter themselves out of their own list.
    self_uid = os.getuid() if os.environ.get("GREETD_SOCK") else None

    users = []

    for entry in pwd.getpwall():
        if not (uid_min <= entry.pw_uid <= uid_max):
            continue
        # The greeter's own account can land inside the range on some
        # distributions; offering it as a login target is nonsense.
        if entry.pw_uid == self_uid:
            continue
        if os.path.basename(entry.pw_shell or "") in NOLOGIN_NAMES:
            continue
        if (entry.pw_dir or "") in NONEXISTENT_HOMES:
            continue
        if is_system_account(entry.pw_name):
            continue

        users.append({
            "name": entry.pw_name,
            "realname": realname_of(entry),
            "avatar": find_avatar(entry.pw_name),
            "uid": entry.pw_uid,
        })

    users.sort(key=lambda u: u["uid"])
    json.dump(users, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
