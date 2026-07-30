#!/usr/bin/env python3
"""Lists accounts that can log in.

Prints a JSON array of {"name", "realname", "avatar", "uid"}.

Selection covers ordinary accounts: a UID in the regular user range and a
real login shell, since accounts pointing at nologin or false cannot sign
in at all.

Avatars are looked for where AccountsService and most display managers
put them. Note that the greeter runs as its own unprivileged user, so a
file inside another user's home directory may not be readable — the paths
under /var/lib are world readable and therefore tried first.
"""

import json
import os
import pwd
import sys

UID_MIN = 1000
UID_MAX = 60000

NOLOGIN = ("/usr/bin/nologin", "/sbin/nologin", "/usr/sbin/nologin",
           "/bin/false", "/usr/bin/false")

AVATAR_CANDIDATES = (
    "/var/lib/AccountsService/icons/{name}",
    "/var/lib/kdm/faces/{name}.face.icon",
    "{home}/.face",
    "{home}/.face.icon",
)


def readable(path):
    return os.path.isfile(path) and os.access(path, os.R_OK)


def find_avatar(name, home):
    for tpl in AVATAR_CANDIDATES:
        path = tpl.format(name=name, home=home)
        if readable(path):
            return path
    return ""


def realname_of(entry):
    # GECOS is "Full Name,room,phone,..." - only the first field is a name
    full = (entry.pw_gecos or "").split(",")[0].strip()
    return full or entry.pw_name


def main():
    users = []

    for entry in pwd.getpwall():
        if not (UID_MIN <= entry.pw_uid <= UID_MAX):
            continue
        if entry.pw_shell in NOLOGIN:
            continue
        if not os.path.isdir(entry.pw_dir):
            continue

        users.append({
            "name": entry.pw_name,
            "realname": realname_of(entry),
            "avatar": find_avatar(entry.pw_name, entry.pw_dir),
            "uid": entry.pw_uid,
        })

    users.sort(key=lambda u: u["uid"])
    json.dump(users, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
