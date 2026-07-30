#!/usr/bin/env bash
# Installs quickgreet.
#
#   sudo ./install.sh                    install or update
#   sudo ./install.sh --uninstall        remove what it installed
#   DESTDIR=/tmp/pkg ./install.sh        stage into a package root
#
# Honours DESTDIR, PREFIX and SYSCONFDIR so distribution packaging can
# call this instead of reimplementing it. The PKGBUILD does exactly that;
# when the two were separate they drifted, and the AUR package laid files
# out differently from what this script and the README described.
#
# Deliberately does NOT touch the display manager. Installing only puts
# files in place; switching the login screen over is a separate,
# reversible step described in the README.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DESTDIR="${DESTDIR:-}"
PREFIX="${PREFIX:-/usr}"
SYSCONFDIR="${SYSCONFDIR:-/etc}"
LOCALSTATEDIR="${LOCALSTATEDIR:-/var}"

QML_DIR="$DESTDIR$PREFIX/share/quickgreet"
SCRIPT_DIR="$DESTDIR$PREFIX/lib/quickgreet"
DOC_DIR="$DESTDIR$PREFIX/share/doc/quickgreet"
CONF_DIR="$DESTDIR$SYSCONFDIR/quickgreet"
LOG_FILE="$DESTDIR$LOCALSTATEDIR/log/quickgreet.log"

# Staging into a package root needs no privileges; installing onto a live
# system does.
if [ -z "$DESTDIR" ] && [ "$(id -u)" -ne 0 ]; then
    echo "needs root: sudo $0 $*" >&2
    exit 1
fi

uninstall() {
    echo "removing quickgreet"
    rm -rf "$QML_DIR" "$SCRIPT_DIR" "$DOC_DIR"
    echo "removed $QML_DIR, $SCRIPT_DIR and $DOC_DIR"
    echo "configuration kept at $CONF_DIR; delete it by hand if unwanted"
    exit 0
}

[ "${1:-}" = "--uninstall" ] && uninstall

echo "installing quickgreet"

install -d "$QML_DIR" "$SCRIPT_DIR" "$DOC_DIR" "$CONF_DIR"

install -m 0644 "$here"/qml/*.qml "$QML_DIR/"
install -m 0755 "$here"/scripts/*.py "$here"/scripts/*.sh "$SCRIPT_DIR/"

install -m 0644 "$here/README.md" "$DOC_DIR/"
install -m 0644 "$here/contrib/polkit/10-quickgreet-power.rules" "$DOC_DIR/"

# Not installed into /etc/greetd: overwriting a working config.toml would
# lock people out of their own machine.
install -m 0644 "$here/config/greetd-config.toml" "$DOC_DIR/"

# Templates the project owns are always refreshed. Keeping a stale copy
# means fixes never reach an existing install, including fixes to the very
# files that decide whether the greeter can start. A modified copy is
# moved aside rather than destroyed.
for f in config.example.json greetd-test.toml hyprland.conf; do
    src="$here/config/$f"
    dst="$CONF_DIR/$f"

    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp -a "$dst" "$dst.bak"
        echo "  updated $dst (previous kept as $dst.bak)"
    else
        echo "  installed $dst"
    fi

    install -m 0644 "$src" "$dst"
done

# config.json is the one file that genuinely belongs to the administrator,
# so it is only ever created, never replaced.
if [ ! -e "$CONF_DIR/config.json" ]; then
    install -m 0644 "$here/config/config.example.json" "$CONF_DIR/config.json"
    echo "  installed $CONF_DIR/config.json"
else
    echo "  keeping existing $CONF_DIR/config.json"
fi

# The greeter runs unprivileged and must be able to read all of this.
chmod 0755 "$CONF_DIR"
find "$CONF_DIR" -type f -exec chmod 0644 {} +

# The compositor log has to exist and be writable by the greeter, or the
# launcher silently falls back to discarding it — which is exactly the
# case it exists to cover. Group-readable rather than world-readable: it
# carries whatever the compositor and the greeter print.
if [ -z "$DESTDIR" ]; then
    greeter_user="${QUICKGREET_USER:-greeter}"
    if id "$greeter_user" >/dev/null 2>&1; then
        install -d "$(dirname "$LOG_FILE")"
        touch "$LOG_FILE"
        chown "$greeter_user:$greeter_user" "$LOG_FILE"
        chmod 0640 "$LOG_FILE"
        echo "  created $LOG_FILE for user $greeter_user"
    else
        echo "  note: user '$greeter_user' does not exist yet;"
        echo "        create it (greetd's package usually does) and re-run"
        echo "        so the compositor log can be written"
    fi
fi

echo
echo "installed:"
echo "  QML       $QML_DIR"
echo "  scripts   $SCRIPT_DIR"
echo "  config    $CONF_DIR"
echo "  docs      $DOC_DIR"
echo
echo "next:"
echo "  1. edit $CONF_DIR/config.json (wallpaper, locale, default session)"
echo "  2. optional colour scheme from the wallpaper:"
echo "       $PREFIX/lib/quickgreet/gen-scheme.py IMAGE > $SYSCONFDIR/quickgreet/scheme.json"
echo "  3. test on a spare console, without touching your display manager:"
echo "       sudo greetd --config $SYSCONFDIR/quickgreet/greetd-test.toml"
echo "     then switch to it with Ctrl+Alt+F7"
echo "  4. if that works, see the README for making it permanent"
